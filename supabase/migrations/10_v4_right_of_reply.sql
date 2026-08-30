-- ─────────────────────────────────────────────────────────────────────────────
--  Polyticks – Migration 10 : V4.0 Right-of-Reply Portal (B11)
--  Target DB : Supabase (PostgreSQL 15+)   |   Tier target : FREE (Pro-ready)
--
--  Official statements from paid organizations on disputed content
--  (blueprint §2: "Right-of-Reply Fact-Check Portal" — a paid-tier perk).
--
--  Rules:
--    * One reply per (org, post); orgs may revise or withdraw their own.
--    * INSERT/UPDATE requires an ACTIVE subscription via active_org_tier()
--      (trialing counts; basic/expired does not).
--    * Published replies are public; drafts visible to the org only.
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- ─── SECTION 1 : ENUM ───────────────────────────────────────────────────────

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'right_of_reply_status') THEN
        CREATE TYPE public.right_of_reply_status AS ENUM ('draft', 'published', 'withdrawn');
    END IF;
END$$;

-- ─── SECTION 2 : TABLE ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.right_of_replies (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id             UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    official_statement  TEXT NOT NULL CHECK (char_length(official_statement) BETWEEN 20 AND 2000),
    status              public.right_of_reply_status NOT NULL DEFAULT 'draft',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT unique_reply_per_org_post UNIQUE (org_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_right_of_replies_post
    ON public.right_of_replies (post_id, status);


-- ─── SECTION 3 : RLS ────────────────────────────────────────────────────────

ALTER TABLE public.right_of_replies ENABLE ROW LEVEL SECURITY;

-- Everyone sees published replies (rendered under the fact-check banner);
-- orgs additionally see their own drafts/withdrawn rows; admins see all.
DROP POLICY IF EXISTS "Published replies are public" ON public.right_of_replies;
CREATE POLICY "Published replies are public" ON public.right_of_replies
    FOR SELECT USING (
        status = 'published'
        OR auth.uid() = org_id
        OR public.caller_is_privileged()
    );

-- Write gate: PAID tier required. active_org_tier() returns NULL for basic,
-- expired, or missing subscriptions — this is the monetization enforcement.
-- Orgs may only write their own rows, and only on their own content.
DROP POLICY IF EXISTS "Paid orgs reply to own posts" ON public.right_of_replies;
CREATE POLICY "Paid orgs reply to own posts" ON public.right_of_replies
    FOR INSERT WITH CHECK (
        auth.uid() = org_id
        AND public.active_org_tier(org_id) IS NOT NULL
        AND EXISTS (
            SELECT 1 FROM public.posts p
            WHERE p.id = post_id AND p.author_id = org_id
        )
    );

DROP POLICY IF EXISTS "Orgs revise own replies" ON public.right_of_replies;
CREATE POLICY "Orgs revise own replies" ON public.right_of_replies
    FOR UPDATE USING (
        auth.uid() = org_id
        AND public.active_org_tier(org_id) IS NOT NULL
    );

DROP POLICY IF EXISTS "Admins manage all replies" ON public.right_of_replies;
CREATE POLICY "Admins manage all replies" ON public.right_of_replies
    FOR ALL USING (public.caller_is_privileged());

-- ─── SECTION 4 : TOUCH TRIGGER ──────────────────────────────────────────────

DROP TRIGGER IF EXISTS trg_right_of_replies_touch ON public.right_of_replies;
CREATE TRIGGER trg_right_of_replies_touch
    BEFORE UPDATE ON public.right_of_replies
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

COMMIT;
