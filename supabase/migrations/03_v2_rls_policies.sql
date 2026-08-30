-- ─────────────────────────────────────────────────────────────────────────────
--  Polyticks – Migration 03 : V2 RLS Policies (Strict)
--  Target DB : Supabase (PostgreSQL 15+)
--  Author    : Senior System Architect (Antigravity)
-- ─────────────────────────────────────────────────────────────────────────────
--
--  Scope
--  ─────
--  This migration supersedes the baseline RLS policies created in migration 02
--  with a stricter, production-grade policy set:
--
--  1. DROP the permissive INSERT policies from migration 02 on both tables.
--  2. Re-enable RLS (idempotent; safe to run again).
--  3. Helper function  public.is_verified_submitter()
--       – Returns TRUE only when the calling user has BOTH is_verified = true
--         AND role IN ('verified', 'paid_org', 'admin').
--       – Marked SECURITY DEFINER so it can read profiles without exposing the
--         table to anonymous users via a public SELECT.
--       – Result is cached for the duration of the statement via STABLE.
--  4. Helper function  public.fact_check_rate_limit_ok()
--       – Returns TRUE when the calling user has submitted fewer than 5
--         fact-checks in the last 24 hours.
--       – Also SECURITY DEFINER for the same isolation reason.
--  5. Policy  fact_checks_insert_verified_only
--       – Replaces "fact_checks: verified users can insert" from migration 02.
--       – Requires is_verified_submitter() AND fact_check_rate_limit_ok().
--  6. Policy  fact_check_votes_insert_verified_only
--       – Replaces "fact_check_votes: verified users can vote" from migration 02.
--       – Requires is_verified_submitter().
--  7. Policy  fact_check_votes_update_verified_only
--       – Replaces "fact_check_votes: voter can update own vote" from migration 02.
--       – Requires is_verified_submitter() for UPDATE as well.
--
--  Idempotency notes
--  ─────────────────
--  • Policy DROP uses IF EXISTS so re-runs are safe.
--  • Function CREATE OR REPLACE is inherently idempotent.
--  • Policy CREATE is NOT idempotent by default; the script drops before
--    recreating so repeated application does not error.
--
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- ─── SECTION 1 : DROP SUPERSEDED INSERT/UPDATE POLICIES FROM MIGRATION 02 ────
--  Only the policies this migration replaces are dropped; read / delete / admin
--  policies defined in migration 02 remain in force.

DROP POLICY IF EXISTS "fact_checks: verified users can insert"
    ON public.fact_checks;

DROP POLICY IF EXISTS "fact_check_votes: verified users can vote"
    ON public.fact_check_votes;

DROP POLICY IF EXISTS "fact_check_votes: voter can update own vote"
    ON public.fact_check_votes;

-- Also drop this migration's own policies so the entire script is re-runnable.
DROP POLICY IF EXISTS fact_checks_insert_verified_only
    ON public.fact_checks;

DROP POLICY IF EXISTS fact_check_votes_insert_verified_only
    ON public.fact_check_votes;

DROP POLICY IF EXISTS fact_check_votes_update_verified_only
    ON public.fact_check_votes;


-- ─── SECTION 2 : RE-ENABLE RLS (idempotent) ──────────────────────────────────

ALTER TABLE public.fact_checks      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fact_check_votes ENABLE ROW LEVEL SECURITY;


-- ─── SECTION 3 : HELPER — is_verified_submitter() ────────────────────────────
--
--  Returns TRUE when auth.uid() maps to a profile where:
--    • is_verified  = true
--    • role         IN ('verified', 'paid_org', 'admin')
--
--  Design decisions:
--  • SECURITY DEFINER  – executes as the function owner (postgres / service-role)
--    so the profiles table does not need a public SELECT policy.
--  • STABLE             – PostgreSQL may cache the result within a single
--    statement, reducing repeated sub-selects in bulk operations.
--  • search_path locked – prevents search-path injection attacks.

CREATE OR REPLACE FUNCTION public.is_verified_submitter()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
          FROM public.profiles
         WHERE id          = auth.uid()
           AND is_verified = true
           AND role        IN ('verified_user', 'org_placeholder', 'admin')
    );
$$;

COMMENT ON FUNCTION public.is_verified_submitter() IS
    'Returns TRUE only when the calling Supabase user has is_verified = true '
    'and role IN (''verified'', ''paid_org'', ''admin''). '
    'Used as a shared gate in multiple RLS policies.';


-- ─── SECTION 4 : HELPER — fact_check_rate_limit_ok() ────────────────────────
--
--  Rate-limit: a verified user may submit at most 5 fact-checks in any
--  rolling 24-hour window (measured from now() - INTERVAL '24 hours').
--
--  Design decisions:
--  • Counts rows in fact_checks authored by auth.uid() within the window.
--  • VOLATILE (not STABLE) because it reads live fact_checks data whose result
--    changes as new rows are inserted within the same transaction.
--  • SECURITY DEFINER so it can count fact_checks rows directly, even when the
--    caller only has RLS-filtered SELECT access.
--  • The threshold constant (5) is defined inline; change here to adjust limit.

CREATE OR REPLACE FUNCTION public.fact_check_rate_limit_ok()
RETURNS boolean
LANGUAGE sql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT (
        SELECT COUNT(*)
          FROM public.fact_checks
         WHERE author_id  = auth.uid()
           AND created_at >= now() - INTERVAL '24 hours'
    ) < 5;  -- strict less-than: 5 allowed (0-4 existing = 5th insert passes)
$$;

COMMENT ON FUNCTION public.fact_check_rate_limit_ok() IS
    'Returns TRUE when auth.uid() has submitted fewer than 5 fact-checks in '
    'the last 24-hour rolling window. Used in the INSERT policy on fact_checks.';


-- ─── SECTION 5 : POLICY — fact_checks_insert_verified_only ──────────────────
--
--  Replaces "fact_checks: verified users can insert" from migration 02.
--
--  Gate conditions (ALL must hold):
--    a) author_id = auth.uid()        → prevents impersonation.
--    b) is_verified_submitter()       → role + verification gate.
--    c) fact_check_rate_limit_ok()    → 5 submissions per 24 h rolling window.

CREATE POLICY fact_checks_insert_verified_only
    ON public.fact_checks
    FOR INSERT
    WITH CHECK (
        -- (a) caller must claim authorship as themselves
        auth.uid() = author_id

        -- (b) caller must be a verified member of an allowed role tier
        AND public.is_verified_submitter()

        -- (c) caller must not have exhausted their 24-hour submission quota
        AND public.fact_check_rate_limit_ok()
    );

COMMENT ON POLICY fact_checks_insert_verified_only ON public.fact_checks IS
    'Allows INSERT only when: (1) author_id = auth.uid(), '
    '(2) profile has is_verified = true and role IN (''verified'',''paid_org'',''admin''), '
    '(3) fewer than 5 fact-checks submitted in the past 24 hours.';


-- ─── SECTION 6 : POLICY — fact_check_votes_insert_verified_only ─────────────
--
--  Replaces "fact_check_votes: verified users can vote" from migration 02.
--
--  Gate conditions:
--    a) voter_id = auth.uid()         → prevents vote stuffing as another user.
--    b) is_verified_submitter()       → unverified / basic users are denied.
--  No per-vote rate limit; the UNIQUE(fact_check_id, voter_id) constraint
--  already limits each user to one vote per fact-check row.

CREATE POLICY fact_check_votes_insert_verified_only
    ON public.fact_check_votes
    FOR INSERT
    WITH CHECK (
        -- (a) caller must record the vote as themselves
        auth.uid() = voter_id

        -- (b) caller must be verified and in an allowed role
        AND public.is_verified_submitter()
    );

COMMENT ON POLICY fact_check_votes_insert_verified_only ON public.fact_check_votes IS
    'Allows INSERT only when: (1) voter_id = auth.uid(), '
    '(2) profile has is_verified = true and role IN (''verified'',''paid_org'',''admin''). '
    'Unverified basic users are denied.';


-- ─── SECTION 7 : POLICY — fact_check_votes_update_verified_only ─────────────
--
--  Replaces "fact_check_votes: voter can update own vote" from migration 02.
--
--  Permits verified users to flip their vote (upvote ↔ downvote).
--  USING     – restricts which existing rows the caller may target.
--  WITH CHECK – re-validates identity + verification after the UPDATE.

CREATE POLICY fact_check_votes_update_verified_only
    ON public.fact_check_votes
    FOR UPDATE
    USING (
        -- caller may only target their own existing vote rows
        auth.uid() = voter_id
    )
    WITH CHECK (
        -- after the update, voter_id must still be the caller
        auth.uid() = voter_id

        -- and they must still hold a verified, permitted-role profile
        AND public.is_verified_submitter()
    );

COMMENT ON POLICY fact_check_votes_update_verified_only ON public.fact_check_votes IS
    'Allows UPDATE (vote flip) only when: (1) voter_id = auth.uid() both before '
    'and after the update, (2) profile has is_verified = true and role IN '
    '(''verified'',''paid_org'',''admin'').';


COMMIT;
-- ─────────────────────────────────────────────────────────────────────────────
--  End of migration 03_v2_rls_policies.sql
-- ─────────────────────────────────────────────────────────────────────────────
