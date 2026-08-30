-- ─────────────────────────────────────────────────────────────────────────────
--  Polyticks – Migration 07 : V2 24-Hour Moderation SLA Auto-Hide
--  Target DB : Supabase (PostgreSQL 15+)
-- ─────────────────────────────────────────────────────────────────────────────
--
--  Scope
--  ─────
--  1. reports.status column (pending | resolved | rejected) so the SLA sweep
--     can distinguish live reports from handled ones. Backfill existing rows
--     to 'pending'.
--
--  2. evaluate_report_surge()
--       Fires AFTER INSERT ON public.reports.
--       When a post accumulates >= 5 reports within a rolling 24h window,
--       the post is hidden (posts.is_hidden = true) and stamped
--       fact_check_status = 'auto_hidden'.
--       Guards: skip when already hidden; never overwrite a terminal status
--       ('verified_context', 'disputed', 'auto_hidden'); never un-hide.
--
--  3. sla_unhide_stale_reports()
--       Scheduled sweep (pg_cron or Edge Function on schedule). Per blueprint,
--       auto-hidden posts stay hidden until an explicit admin decision, so this
--       sweep does NOT un-hide anything. It records an SLA-breach event when a
--       post hidden solely by report-surge has had ALL of its surge-window
--       reports resolved/rejected for more than 24h without an admin decision
--       on the post itself. Breaches are surfaced through the
--       admin_sla_breaches view for the admin queue.
--
--  Design notes
--  ────────────
--  * SECURITY DEFINER with pinned search_path (same pattern as migration 04).
--  * Idempotent: guard clauses prevent redundant writes; CREATE IF NOT EXISTS
--    / DROP IF EXISTS throughout.
--  * Cross-trigger safety: the dislike-threshold trigger (migration 04) never
--    escalates past statuses >= 'under_review'; this trigger only writes
--    'auto_hidden' from 'none' / 'under_review', and migration 04's promotion
--    logic never overwrites 'auto_hidden'. The two triggers cannot interfere.
--
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- ─── 1. reports.status column ────────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name   = 'reports'
           AND column_name  = 'status'
    ) THEN
        ALTER TABLE public.reports
            ADD COLUMN status TEXT NOT NULL DEFAULT 'pending';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname = 'reports_status_check'
           AND conrelid = 'public.reports'::regclass
    ) THEN
        ALTER TABLE public.reports
            ADD CONSTRAINT reports_status_check
            CHECK (status IN ('pending', 'resolved', 'rejected'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_reports_post_created
    ON public.reports (post_id, created_at DESC);

-- ─── 2. SLA event audit log ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.sla_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id     UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    event_type  TEXT NOT NULL CHECK (event_type IN ('auto_hidden', 'sla_breach')),
    detail      TEXT,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.sla_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view sla_events" ON public.sla_events;
CREATE POLICY "Admins can view sla_events" ON public.sla_events FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ─── 3. TRIGGER : evaluate_report_surge ──────────────────────────────────────
--  Fires : AFTER INSERT ON public.reports
--  Goal  : Auto-hide a post once it accumulates >= 5 reports within 24h.
--
--  Threshold rules
--  ───────────────
--    surge_count = COUNT(reports for post WHERE created_at > now() - 24h)
--    Hide when   : surge_count >= 5
--
--  Guards
--  ──────
--    * Already hidden        -> no-op (idempotent).
--    * Terminal status       -> never downgrade 'verified_context', 'disputed'
--                               or 'auto_hidden'.
--    * Never un-hide         -> this function only ever sets is_hidden = true.
CREATE OR REPLACE FUNCTION public.evaluate_report_surge()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_surge_count    INTEGER;
    v_is_hidden      BOOLEAN;
    v_current_status public.fact_check_status;
BEGIN
    -- Rolling 24h report count for the affected post.
    SELECT COUNT(*)
      INTO v_surge_count
      FROM public.reports
     WHERE post_id = NEW.post_id
       AND created_at > timezone('utc'::text, now()) - INTERVAL '24 hours';

    IF v_surge_count < 5 THEN
        RETURN NULL; -- below threshold; nothing to do
    END IF;

    SELECT is_hidden, fact_check_status
      INTO v_is_hidden, v_current_status
      FROM public.posts
     WHERE id = NEW.post_id;

    IF NOT FOUND THEN
        RETURN NULL; -- post gone (race with delete)
    END IF;

    -- Guard: skip if already hidden (idempotent) or at a terminal status.
    IF v_is_hidden THEN
        RETURN NULL;
    END IF;
    IF v_current_status IN ('verified_context', 'disputed', 'auto_hidden') THEN
        RETURN NULL;
    END IF;

    UPDATE public.posts
       SET is_hidden         = true,
           fact_check_status = 'auto_hidden',
           flagged_reason    = COALESCE(
               flagged_reason,
               'Auto-hidden: ' || v_surge_count || ' reports within 24h')
     WHERE id = NEW.post_id;

    INSERT INTO public.sla_events (post_id, event_type, detail)
    VALUES (NEW.post_id, 'auto_hidden',
            'Report surge: ' || v_surge_count || ' reports within 24h');

    RETURN NULL; -- AFTER trigger; return value ignored
END;
$$;

COMMENT ON FUNCTION public.evaluate_report_surge() IS
    'AFTER INSERT on reports: hides the post and stamps fact_check_status = '
    '''auto_hidden'' when >= 5 reports accumulate within a rolling 24h window. '
    'Idempotent; never un-hides; never overwrites terminal statuses.';

DROP TRIGGER IF EXISTS trg_evaluate_report_surge ON public.reports;

CREATE TRIGGER trg_evaluate_report_surge
    AFTER INSERT
    ON public.reports
    FOR EACH ROW
    EXECUTE FUNCTION public.evaluate_report_surge();

-- ─── 4. SCHEDULED SWEEP : sla_unhide_stale_reports ───────────────────────────
--  Per blueprint, auto-hidden posts stay hidden until an explicit admin
--  decision. This sweep therefore does NOT un-hide; it detects SLA breaches:
--  posts hidden by surge whose surge-window reports are ALL resolved/rejected
--  for more than 24h without an admin decision on the post. Breaches are
--  recorded once in sla_events and exposed via admin_sla_breaches.
CREATE OR REPLACE FUNCTION public.sla_unhide_stale_reports()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_breached  UUID[];
    v_count     INTEGER := 0;
BEGIN
    WITH surge_hidden AS (
        SELECT p.id AS post_id,
               MAX(se.created_at) AS hidden_at
          FROM public.posts p
          JOIN public.sla_events se
            ON se.post_id = p.id AND se.event_type = 'auto_hidden'
         WHERE p.is_hidden = true
           AND p.fact_check_status = 'auto_hidden'
         GROUP BY p.id
    )
    SELECT ARRAY(
        SELECT sh.post_id
          FROM surge_hidden sh
         WHERE NOT EXISTS (
                   SELECT 1 FROM public.reports r
                    WHERE r.post_id = sh.post_id
                      AND r.status = 'pending'
               )
           AND EXISTS (
                   SELECT 1 FROM public.reports r
                    WHERE r.post_id = sh.post_id
                      AND r.created_at > sh.hidden_at - INTERVAL '24 hours'
               )
           AND NOT EXISTS (
                   SELECT 1 FROM public.sla_events e
                    WHERE e.post_id = sh.post_id
                      AND e.event_type = 'sla_breach'
               )
    )
      INTO v_breached;

    IF COALESCE(array_length(v_breached, 1), 0) > 0 THEN
        INSERT INTO public.sla_events (post_id, event_type, detail)
        SELECT unnest(v_breached), 'sla_breach',
               'All surge reports handled >24h ago without admin decision';
        GET DIAGNOSTICS v_count = ROW_COUNT;
    END IF;

    RETURN v_count;
END;
$$;

COMMENT ON FUNCTION public.sla_unhide_stale_reports() IS
    'Scheduled sweep: records SLA-breach events for auto-hidden posts whose '
    'reports were all resolved/rejected >24h without an admin decision. '
    'Never un-hides automatically.';

-- ─── 5. ADMIN-VISIBLE BREACH QUEUE VIEW ──────────────────────────────────────
CREATE OR REPLACE VIEW public.admin_sla_breaches AS
SELECT p.id            AS post_id,
       p.content,
       p.flagged_reason,
       p.fact_check_status,
       p.is_hidden,
       breach.created_at AS breach_detected_at,
       (SELECT COUNT(*) FROM public.reports r
         WHERE r.post_id = p.id) AS total_report_count
  FROM public.posts p
  JOIN public.sla_events breach
    ON breach.post_id = p.id AND breach.event_type = 'sla_breach';

COMMIT;
-- ─────────────────────────────────────────────────────────────────────────────
--  End of migration 07_v2_sla_auto_hide.sql
-- ─────────────────────────────────────────────────────────────────────────────
