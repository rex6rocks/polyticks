-- ─────────────────────────────────────────────────────────────────────────────
--  Polyticks – Migration 08 : V4.0 Monetization & Automated Verification
--  Target DB : Supabase (PostgreSQL 15+)   |   Tier target : FREE (Pro-ready)
--
--  Adds:
--    * Org subscription tiers + statuses (Razorpay-backed, test-mode first)
--    * Idempotent payment webhook event log (survives free-tier project pause)
--    * DigiLocker verification request state machine
--    * Partition-ready analytics events with retention policy
--    * Role-based registration locks (paid/admin roles only via service_role)
--
--  PRO UPGRADE NOTE: nothing here requires Supabase Pro. See docs/V4_SPEC.md
--  § "Pro Upgrade Runbook" for the post-release update checklist.
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- ─── SECTION 1 : CUSTOM ENUMS ───────────────────────────────────────────────

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'org_subscription_tier') THEN
        CREATE TYPE public.org_subscription_tier AS ENUM ('basic', 'gold', 'platinum');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status') THEN
        CREATE TYPE public.subscription_status AS ENUM (
            'trialing', 'active', 'past_due', 'canceled', 'expired');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_method') THEN
        CREATE TYPE public.verification_method AS ENUM ('digilocker', 'manual_web');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'digilocker_request_status') THEN
        CREATE TYPE public.digilocker_request_status AS ENUM (
            'initiated', 'otp_sent', 'docs_fetched', 'verified', 'failed');
    END IF;
END$$;


-- ─── SECTION 2 : CORE TABLES ────────────────────────────────────────────────

-- Org subscriptions. Written ONLY by service_role (payment webhook /
-- edge functions). Clients may read their own org's row.
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    tier                public.org_subscription_tier NOT NULL DEFAULT 'basic',
    status              public.subscription_status NOT NULL DEFAULT 'trialing',
    provider            TEXT NOT NULL DEFAULT 'razorpay',
    provider_ref        TEXT,                       -- Razorpay subscription id
    trial_ends_at       TIMESTAMPTZ,                -- 14-day free trial per roadmap
    current_period_end  TIMESTAMPTZ,
    canceled_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT unique_active_subscription_per_org UNIQUE (org_id)
);

-- Idempotent webhook delivery log. Every payment-provider callback is recorded
-- BEFORE processing; duplicate event_ids are skipped by the handler.
-- This is what makes a missed delivery during a free-tier project pause
-- self-healing: Razorpay retries and the dedupe key absorbs replays.
CREATE TABLE IF NOT EXISTS public.webhook_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider        TEXT NOT NULL DEFAULT 'razorpay',
    event_id        TEXT NOT NULL,
    event_type      TEXT,
    payload         JSONB NOT NULL DEFAULT '{}'::jsonb,
    processed_at    TIMESTAMPTZ,                    -- NULL = pending/failed
    process_error   TEXT,
    received_at     TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE (provider, event_id)
);

-- DigiLocker verification state machine. Rows created by the
-- `digilocker-initiate` edge function (service_role). No PII documents are
-- stored here — only statuses and provider request ids.
CREATE TABLE IF NOT EXISTS public.verification_requests (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    method              public.verification_method NOT NULL DEFAULT 'digilocker',
    status              public.digilocker_request_status NOT NULL DEFAULT 'initiated',
    provider_request_id TEXT,                       -- DigiLocker txn id
    failure_reason      TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
CREATE INDEX IF NOT EXISTS idx_verification_requests_user
    ON public.verification_requests (user_id, created_at DESC);

-- B2B analytics events. Partition-ready shape: high-volume raw rows are
-- purged by purge_old_analytics_events(); rollup views (Phase 4) are the
-- durable layer. Retention is configurable via app.settings.
CREATE TABLE IF NOT EXISTS public.analytics_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id         UUID REFERENCES public.posts(id) ON DELETE SET NULL,
    event_type      TEXT NOT NULL,                  -- e.g. 'post_view','reaction','note'
    actor_id        UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
CREATE INDEX IF NOT EXISTS idx_analytics_events_org_time
    ON public.analytics_events (org_id, created_at DESC);


-- ─── SECTION 3 : HELPER FUNCTIONS (search_path hardened) ────────────────────

-- Active tier for an org; NULL when no live subscription.
-- Gold badge / paid gating in the client derives from this, NOT from
-- profiles.role, so a Pro upgrade or plan change never needs role surgery.
CREATE OR REPLACE FUNCTION public.active_org_tier(p_org_id UUID)
RETURNS public.org_subscription_tier
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT s.tier FROM public.subscriptions s
    WHERE s.org_id = p_org_id
      AND s.status IN ('trialing', 'active')
      AND (s.current_period_end IS NULL OR s.current_period_end > now())
    LIMIT 1;
$$;

-- True when the caller is an admin or the service_role key is in use.
CREATE OR REPLACE FUNCTION public.caller_is_privileged()
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_jwt_role TEXT;
BEGIN
    v_jwt_role := COALESCE(
        current_setting('request.jwt.claims', true)::json ->> 'role', '');
    IF v_jwt_role = 'service_role' THEN
        RETURN true;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$;


-- ─── SECTION 4 : ROW-LEVEL SECURITY ─────────────────────────────────────────
--  Default stance: RLS enabled + NO policies = fully client-denied.
--  service_role bypasses RLS, so edge functions / webhooks keep full access.

ALTER TABLE public.subscriptions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhook_events       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_events     ENABLE ROW LEVEL SECURITY;

-- Subscriptions: orgs read their own row (badge/feature gating); admins all.
DROP POLICY IF EXISTS "Orgs view own subscription" ON public.subscriptions;
CREATE POLICY "Orgs view own subscription" ON public.subscriptions
    FOR SELECT USING (
        auth.uid() = org_id OR public.caller_is_privileged()
    );
-- No INSERT/UPDATE/DELETE policies → writes only via service_role webhook.

-- Webhook events: zero client policies. Audit-only, service_role access.

-- Verification requests: user sees own request status; admins see all.
DROP POLICY IF EXISTS "Users view own verification requests" ON public.verification_requests;
CREATE POLICY "Users view own verification requests" ON public.verification_requests
    FOR SELECT USING (
        auth.uid() = user_id OR public.caller_is_privileged()
    );
-- Writes only via service_role edge functions (digilocker-initiate/callback).

-- Analytics events: orgs read their own aggregates source rows; admins all.
DROP POLICY IF EXISTS "Orgs view own analytics events" ON public.analytics_events;
CREATE POLICY "Orgs view own analytics events" ON public.analytics_events
    FOR SELECT USING (
        auth.uid() = org_id OR public.caller_is_privileged()
    );
-- Writes only via service_role aggregation functions.

-- ─── SECTION 5 : REGISTRATION LOCKS (role escalation guard) ─────────────────
--  Client SDK must never be able to write sensitive role columns.
--  This trigger enforces it server-side regardless of policy mistakes:
--  privileged roles may only be granted by service_role or an existing admin.

CREATE OR REPLACE FUNCTION public.guard_role_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    -- Migrations / seed scripts run as the DB owner: always allowed.
    IF current_user IN ('postgres', 'supabase_admin') THEN
        RETURN NEW;
    END IF;
    IF TG_OP = 'INSERT' THEN
        IF NEW.role IN ('admin', 'org_placeholder') AND NOT public.caller_is_privileged() THEN
            RAISE EXCEPTION 'Registration lock: role % cannot be set at signup', NEW.role;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.role IS DISTINCT FROM OLD.role
           AND NEW.role IN ('admin', 'org_placeholder')
           AND NOT public.caller_is_privileged() THEN
            RAISE EXCEPTION 'Registration lock: role change to % requires privilege escalation path', NEW.role;
        END IF;
        -- Verified status is also admin/service-controlled (pre-prod audit item).
        IF NEW.is_verified IS DISTINCT FROM OLD.is_verified
           AND NOT public.caller_is_privileged() THEN
            RAISE EXCEPTION 'Registration lock: is_verified is service-controlled';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_role_escalation ON public.profiles;
CREATE TRIGGER trg_guard_role_escalation
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.guard_role_escalation();


-- ─── SECTION 6 : ANALYTICS RETENTION (free-tier DB-size control) ────────────
--  Raw events older than app.analytics_retention_days (default 30) are purged.
--  PRO UPGRADE: just raise the setting — no code change.
--    ALTER DATABASE postgres SET app.analytics_retention_days = '365';

CREATE OR REPLACE FUNCTION public.purge_old_analytics_events()
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_days INT;
    v_deleted INT;
BEGIN
    BEGIN
        v_days := current_setting('app.analytics_retention_days')::INT;
    EXCEPTION WHEN undefined_object THEN
        v_days := 30;
    END;
    DELETE FROM public.analytics_events
    WHERE created_at < now() - make_interval(days => v_days);
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$;

-- ─── SECTION 7 : UPDATED_AT TOUCH TRIGGERS ──────────────────────────────────

CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_subscriptions_touch ON public.subscriptions;
CREATE TRIGGER trg_subscriptions_touch
    BEFORE UPDATE ON public.subscriptions
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS trg_verification_requests_touch ON public.verification_requests;
CREATE TRIGGER trg_verification_requests_touch
    BEFORE UPDATE ON public.verification_requests
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

COMMIT;
