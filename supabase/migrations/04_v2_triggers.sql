-- ─────────────────────────────────────────────────────────────────────────────
--  Polyticks – Migration 04 : V2 Autonomous Trigger Functions
--  Target DB : Supabase (PostgreSQL 15+)
--  Author    : Senior System Architect (Antigravity)
-- ─────────────────────────────────────────────────────────────────────────────
--
--  Scope
--  ─────
--  1. evaluate_post_dislike_threshold()
--       Fires AFTER INSERT OR UPDATE on public.reactions.
--       If the post accumulates >= 25 total votes AND the dislike ratio
--       exceeds 60 %, the post's fact_check_status is escalated to
--       'under_review' automatically -- no client-side logic required.
--
--  2. recalculate_fact_check_votes()
--       Fires AFTER INSERT OR DELETE on public.fact_check_votes.
--       Performs a full COUNT(*) recount (idempotent / race-condition-safe)
--       and writes canonical upvote / downvote totals back to fact_checks.
--       If the net score (upvotes - downvotes) reaches >= 10, the parent
--       post is promoted to 'verified_context'.
--
--  Design notes
--  ────────────
--  * Both functions are SECURITY DEFINER with a pinned search_path to
--    prevent privilege-escalation and search-path injection.
--  * Guard clauses skip redundant writes (no-op when status already set).
--  * recalculate_fact_check_votes uses full recount rather than delta
--    arithmetic to stay consistent even under concurrent writes.
--  * The existing handle_fact_check_vote_change() trigger (migration 02)
--    handles delta sync on fact_checks.upvotes / downvotes.
--    This trigger sits one level higher: it re-reads those counters and
--    decides whether the post should be promoted.
--
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- ─── TRIGGER 1 : evaluate_post_dislike_threshold ─────────────────────────────
--  Fires : AFTER INSERT OR UPDATE ON public.reactions
--  Goal  : Automatically set posts.fact_check_status = 'under_review' when
--          the dislike ratio of a post crosses the escalation threshold.
--
--  Implementation strategy
--  ───────────────────────
--  The existing reaction-sync trigger (schema.sql) already keeps
--  posts.like_count and posts.dislike_count up-to-date.  We read those
--  denormalised counters directly -- one indexed PK lookup -- rather than
--  issuing an aggregate query over reactions, which avoids a full table
--  scan and is safe because the counter update and this trigger fire in
--  the same transaction (statement ordering guarantees the counters are
--  current when we read them).
--
--  Threshold rules
--  ───────────────
--    total_votes   = like_count + dislike_count
--    dislike_ratio = dislike_count / total_votes
--
--    Escalate when: total_votes >= 25 AND dislike_ratio > 0.60
--
--  Guard clause
--  ────────────
--  Skip the UPDATE entirely if fact_check_status is already 'under_review'
--  (or any status that supersedes it: 'verified_context', 'disputed',
--  'auto_hidden').  This avoids unnecessary row churn and prevents the
--  trigger from overwriting a human or higher-priority status.

CREATE OR REPLACE FUNCTION public.evaluate_post_dislike_threshold()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_post_id        UUID;
    v_like_count     INTEGER;
    v_dislike_count  INTEGER;
    v_total_votes    INTEGER;
    v_current_status public.fact_check_status;
BEGIN
    -- ── Resolve the affected post_id ─────────────────────────────────────────
    -- For INSERT the new row carries the post reference; for UPDATE we use
    -- NEW (the post_id cannot change due to the schema's FK constraints).
    v_post_id := NEW.post_id;

    -- ── Read denormalised counters and current status in one PK lookup ───────
    SELECT like_count,
           dislike_count,
           fact_check_status
      INTO v_like_count,
           v_dislike_count,
           v_current_status
      FROM public.posts
     WHERE id = v_post_id;

    -- ── Guard: skip if status is already at a higher-priority state ──────────
    -- 'under_review', 'verified_context', 'disputed', and 'auto_hidden' are
    -- all considered >= under_review; we must not downgrade them.
    IF v_current_status IN ('under_review', 'verified_context', 'disputed', 'auto_hidden') THEN
        RETURN NULL;
    END IF;

    -- ── Compute total votes ───────────────────────────────────────────────────
    v_total_votes := COALESCE(v_like_count, 0) + COALESCE(v_dislike_count, 0);

    -- ── Evaluate threshold ────────────────────────────────────────────────────
    -- Require at least 25 votes to prevent tiny-sample false positives.
    -- Use integer arithmetic (dislike_count * 100 / total_votes > 60) to
    -- avoid floating-point precision issues with the division operator.
    IF v_total_votes >= 25
       AND (v_dislike_count * 100 / v_total_votes) > 60
    THEN
        UPDATE public.posts
           SET fact_check_status = 'under_review'
         WHERE id = v_post_id;
    END IF;

    RETURN NULL; -- AFTER trigger; return value ignored for row triggers
END;
$$;

COMMENT ON FUNCTION public.evaluate_post_dislike_threshold() IS
    'AFTER INSERT OR UPDATE on reactions: escalates posts.fact_check_status '
    'to ''under_review'' when total_votes >= 25 AND dislike_ratio > 60%.';

-- Bind the trigger to the reactions table.
-- DROP ... IF EXISTS first so this migration is safely re-runnable.
DROP TRIGGER IF EXISTS trg_evaluate_post_dislike_threshold
    ON public.reactions;

CREATE TRIGGER trg_evaluate_post_dislike_threshold
    AFTER INSERT OR UPDATE
    ON public.reactions
    FOR EACH ROW
    EXECUTE FUNCTION public.evaluate_post_dislike_threshold();


-- ─── TRIGGER 2 : recalculate_fact_check_votes ────────────────────────────────
--  Fires : AFTER INSERT OR DELETE ON public.fact_check_votes
--  Goal  : Recount upvotes / downvotes on the targeted fact_checks row and,
--          if the net score (upvotes - downvotes) reaches >= 10, promote the
--          parent post to 'verified_context'.
--
--  Full-recount strategy
--  ─────────────────────
--  We use COUNT(*) FILTER rather than delta arithmetic for two reasons:
--    a) Idempotency - re-running the trigger always converges to the correct
--       value regardless of prior state or partial failures.
--    b) Race-condition safety - concurrent inserts/deletes cannot produce
--       a negative count or an off-by-one that persists across transactions.
--
--  Relationship with handle_fact_check_vote_change (migration 02)
--  ──────────────────────────────────────────────────────────────
--  Migration 02 keeps fact_checks.upvotes / downvotes in sync via delta
--  increments.  This trigger also fires AFTER INSERT OR DELETE on the same
--  table.  PostgreSQL fires multiple triggers in alphabetical order, so
--  'handle_fact_check_vote_change' fires before 'recalculate_fact_check_votes'.
--  By the time our function runs, the delta is already applied; our full
--  COUNT(*) recount then acts as a self-healing correctness layer and
--  applies the promotion logic on top.

CREATE OR REPLACE FUNCTION public.recalculate_fact_check_votes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_fact_check_id  UUID;
    v_post_id        UUID;
    v_upvotes        INTEGER;
    v_downvotes      INTEGER;
    v_current_status public.fact_check_status;
BEGIN
    -- ── Resolve the affected fact_check_id ───────────────────────────────────
    -- On INSERT use NEW; on DELETE the row is gone so use OLD.
    IF TG_OP = 'INSERT' THEN
        v_fact_check_id := NEW.fact_check_id;
    ELSE -- DELETE
        v_fact_check_id := OLD.fact_check_id;
    END IF;

    -- ── Full recount from the source table ───────────────────────────────────
    SELECT COUNT(*) FILTER (WHERE vote_type = 'upvote'),
           COUNT(*) FILTER (WHERE vote_type = 'downvote')
      INTO v_upvotes,
           v_downvotes
      FROM public.fact_check_votes
     WHERE fact_check_id = v_fact_check_id;

    -- ── Write canonical counts back to fact_checks ───────────────────────────
    UPDATE public.fact_checks
       SET upvotes   = COALESCE(v_upvotes,   0),
           downvotes = COALESCE(v_downvotes, 0)
     WHERE id = v_fact_check_id
    RETURNING post_id INTO v_post_id;

    -- ── Promotion logic: verified_context ────────────────────────────────────
    -- Only promote when net score >= 10 AND the post is not already at a
    -- terminal status ('disputed', 'auto_hidden') requiring admin action.
    IF (COALESCE(v_upvotes, 0) - COALESCE(v_downvotes, 0)) >= 10 THEN

        -- Read current status to avoid redundant / downgrading writes.
        SELECT fact_check_status
          INTO v_current_status
          FROM public.posts
         WHERE id = v_post_id;

        -- Only promote from 'none' or 'under_review'.  Never overwrite
        -- 'disputed' or 'auto_hidden' which require explicit admin action.
        IF v_current_status IN ('none', 'under_review') THEN
            UPDATE public.posts
               SET fact_check_status = 'verified_context'
             WHERE id = v_post_id;
        END IF;

    END IF;

    RETURN NULL; -- AFTER trigger; return value ignored for row triggers
END;
$$;

COMMENT ON FUNCTION public.recalculate_fact_check_votes() IS
    'AFTER INSERT OR DELETE on fact_check_votes: full-recount of upvotes / '
    'downvotes on the fact_checks row and promotes the parent post to '
    '''verified_context'' when net score (upvotes - downvotes) >= 10.';

-- Bind the trigger to fact_check_votes.
DROP TRIGGER IF EXISTS trg_recalculate_fact_check_votes
    ON public.fact_check_votes;

CREATE TRIGGER trg_recalculate_fact_check_votes
    AFTER INSERT OR DELETE
    ON public.fact_check_votes
    FOR EACH ROW
    EXECUTE FUNCTION public.recalculate_fact_check_votes();


COMMIT;
-- ─────────────────────────────────────────────────────────────────────────────
--  End of migration 04_v2_triggers.sql
-- ─────────────────────────────────────────────────────────────────────────────
