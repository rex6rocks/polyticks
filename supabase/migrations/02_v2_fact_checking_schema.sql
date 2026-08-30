-- ─────────────────────────────────────────────────────────────────────────────
--  Polyticks – Migration 02 : V2 Fact-Checking Schema (Idempotent)
--  Target DB : Supabase (PostgreSQL 15+)
--  Author    : Senior System Architect (Antigravity)
-- ─────────────────────────────────────────────────────────────────────────────
--
--  Scope
--  ─────
--  1. Create or migrate the `fact_check_status` ENUM with canonical v2 values.
--  2. Ensure `posts.fact_check_status` column is added / typed correctly.
--  3. Create `fact_checks` table with CASCADE delete rules.
--  4. Create `fact_check_votes` table with UNIQUE(fact_check_id, voter_id).
--  5. Vote-sync trigger for upvote / downvote denormalised counters.
--  6. Baseline Row-Level Security policies & performance indexes.
--
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- ─── SECTION 1 : ENUM & POSTS COLUMN MIGRATION ──────────────────────────────

-- Step 1a: Create the ENUM type if it does not exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_type t 
        JOIN pg_namespace n ON n.oid = t.typnamespace 
        WHERE t.typname = 'fact_check_status' AND n.nspname = 'public'
    ) THEN
        CREATE TYPE public.fact_check_status AS ENUM (
            'none',
            'under_review',
            'verified_context',
            'disputed',
            'auto_hidden'
        );
    END IF;
END$$;

-- Step 1b: Ensure posts table has fact_check_status column
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name   = 'posts' 
          AND column_name  = 'fact_check_status'
    ) THEN
        ALTER TABLE public.posts 
            ADD COLUMN fact_check_status public.fact_check_status NOT NULL DEFAULT 'none';
    ELSE
        -- If it already exists with an older definition, ensure default and type match
        ALTER TABLE public.posts 
            ALTER COLUMN fact_check_status SET DEFAULT 'none',
            ALTER COLUMN fact_check_status TYPE public.fact_check_status 
            USING fact_check_status::text::public.fact_check_status;
    END IF;
END$$;


-- ─── SECTION 2 : fact_checks TABLE ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.fact_checks (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Which post this fact-check annotates.
    post_id         UUID        NOT NULL
                    REFERENCES  public.posts(id) ON DELETE CASCADE,

    -- The verified user who authored the fact-check.
    author_id       UUID        NOT NULL
                    REFERENCES  public.profiles(id) ON DELETE CASCADE,

    -- The human-readable context / correction note. Must be non-empty.
    context_note    TEXT        NOT NULL
                    CHECK (char_length(context_note) >= 1),

    -- Optional array of URL strings backing the fact-check.
    source_links    TEXT[]      DEFAULT '{}',

    -- Denormalised vote counts kept in sync by trigger (Section 4).
    upvotes         INTEGER     NOT NULL DEFAULT 0
                    CHECK (upvotes   >= 0),
    downvotes       INTEGER     NOT NULL DEFAULT 0
                    CHECK (downvotes >= 0),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  public.fact_checks IS
    'Verified-user annotations that add context or dispute a post.';
COMMENT ON COLUMN public.fact_checks.source_links IS
    'Array of URLs that substantiate the context_note.';


-- ─── SECTION 3 : fact_check_votes TABLE ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.fact_check_votes (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- The fact-check being voted on.
    fact_check_id   UUID        NOT NULL
                    REFERENCES  public.fact_checks(id) ON DELETE CASCADE,

    -- The verified user casting the vote.
    voter_id        UUID        NOT NULL
                    REFERENCES  public.profiles(id) ON DELETE CASCADE,

    -- Exactly one of the two allowed values.
    vote_type       TEXT        NOT NULL
                    CHECK (vote_type IN ('upvote', 'downvote')),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Core integrity constraint: one vote per user per fact-check.
    CONSTRAINT uq_one_vote_per_user_per_fact_check
        UNIQUE (fact_check_id, voter_id)
);

COMMENT ON TABLE public.fact_check_votes IS
    'One-vote-per-verified-user record for each fact_check row.';


-- ─── SECTION 4 : VOTE-SYNC TRIGGER ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_fact_check_vote_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- ── INSERT ──────────────────────────────────────────────────────────────
    IF TG_OP = 'INSERT' THEN
        IF NEW.vote_type = 'upvote' THEN
            UPDATE public.fact_checks
               SET upvotes   = upvotes   + 1
             WHERE id = NEW.fact_check_id;
        ELSE
            UPDATE public.fact_checks
               SET downvotes = downvotes + 1
             WHERE id = NEW.fact_check_id;
        END IF;

    -- ── DELETE ──────────────────────────────────────────────────────────────
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.vote_type = 'upvote' THEN
            UPDATE public.fact_checks
               SET upvotes   = GREATEST(0, upvotes   - 1)
             WHERE id = OLD.fact_check_id;
        ELSE
            UPDATE public.fact_checks
               SET downvotes = GREATEST(0, downvotes - 1)
             WHERE id = OLD.fact_check_id;
        END IF;

    -- ── UPDATE (vote flip) ───────────────────────────────────────────────────
    ELSIF TG_OP = 'UPDATE' AND OLD.vote_type IS DISTINCT FROM NEW.vote_type THEN
        IF NEW.vote_type = 'upvote' THEN
            -- flipped downvote to upvote
            UPDATE public.fact_checks
               SET upvotes   = upvotes   + 1,
                   downvotes = GREATEST(0, downvotes - 1)
             WHERE id = NEW.fact_check_id;
        ELSE
            -- flipped upvote to downvote
            UPDATE public.fact_checks
               SET downvotes = downvotes + 1,
                   upvotes   = GREATEST(0, upvotes   - 1)
             WHERE id = NEW.fact_check_id;
        END IF;
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS on_fact_check_vote_change ON public.fact_check_votes;

CREATE TRIGGER on_fact_check_vote_change
    AFTER INSERT OR UPDATE OR DELETE
    ON public.fact_check_votes
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_fact_check_vote_change();


-- ─── SECTION 5 : ROW-LEVEL SECURITY ─────────────────────────────────────────

ALTER TABLE public.fact_checks      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fact_check_votes ENABLE ROW LEVEL SECURITY;

-- ── fact_checks policies ─────────────────────────────────────────────────────

DROP POLICY IF EXISTS "fact_checks: public read" ON public.fact_checks;
CREATE POLICY "fact_checks: public read"
    ON public.fact_checks FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "fact_checks: verified users can insert" ON public.fact_checks;
CREATE POLICY "fact_checks: verified users can insert"
    ON public.fact_checks FOR INSERT
    WITH CHECK (
        auth.uid() = author_id
        AND EXISTS (
            SELECT 1
              FROM public.profiles
             WHERE id   = auth.uid()
               AND role IN ('verified_user', 'admin')
        )
    );

DROP POLICY IF EXISTS "fact_checks: authors and admins can update" ON public.fact_checks;
CREATE POLICY "fact_checks: authors and admins can update"
    ON public.fact_checks FOR UPDATE
    USING (
        auth.uid() = author_id
        OR EXISTS (
            SELECT 1
              FROM public.profiles
             WHERE id   = auth.uid()
               AND role = 'admin'
        )
    );

DROP POLICY IF EXISTS "fact_checks: authors and admins can delete" ON public.fact_checks;
CREATE POLICY "fact_checks: authors and admins can delete"
    ON public.fact_checks FOR DELETE
    USING (
        auth.uid() = author_id
        OR EXISTS (
            SELECT 1
              FROM public.profiles
             WHERE id   = auth.uid()
               AND role = 'admin'
        )
    );

-- ── fact_check_votes policies ─────────────────────────────────────────────────

DROP POLICY IF EXISTS "fact_check_votes: public read" ON public.fact_check_votes;
CREATE POLICY "fact_check_votes: public read"
    ON public.fact_check_votes FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "fact_check_votes: verified users can vote" ON public.fact_check_votes;
CREATE POLICY "fact_check_votes: verified users can vote"
    ON public.fact_check_votes FOR INSERT
    WITH CHECK (
        auth.uid() = voter_id
        AND EXISTS (
            SELECT 1
              FROM public.profiles
             WHERE id   = auth.uid()
               AND role IN ('verified_user', 'admin')
        )
    );

DROP POLICY IF EXISTS "fact_check_votes: voter can update own vote" ON public.fact_check_votes;
CREATE POLICY "fact_check_votes: voter can update own vote"
    ON public.fact_check_votes FOR UPDATE
    USING  (auth.uid() = voter_id)
    WITH CHECK (
        auth.uid() = voter_id
        AND EXISTS (
            SELECT 1
              FROM public.profiles
             WHERE id   = auth.uid()
               AND role IN ('verified_user', 'admin')
        )
    );

DROP POLICY IF EXISTS "fact_check_votes: voter can delete own vote" ON public.fact_check_votes;
CREATE POLICY "fact_check_votes: voter can delete own vote"
    ON public.fact_check_votes FOR DELETE
    USING (auth.uid() = voter_id);

DROP POLICY IF EXISTS "fact_check_votes: admins full access" ON public.fact_check_votes;
CREATE POLICY "fact_check_votes: admins full access"
    ON public.fact_check_votes FOR ALL
    USING (
        EXISTS (
            SELECT 1
              FROM public.profiles
             WHERE id   = auth.uid()
               AND role = 'admin'
        )
    );


-- ─── SECTION 6 : PERFORMANCE INDEXES ────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_fact_checks_post_id
    ON public.fact_checks (post_id);

CREATE INDEX IF NOT EXISTS idx_fact_checks_author_id
    ON public.fact_checks (author_id);

CREATE INDEX IF NOT EXISTS idx_fact_check_votes_fact_check_id
    ON public.fact_check_votes (fact_check_id);

CREATE INDEX IF NOT EXISTS idx_fact_check_votes_voter_id
    ON public.fact_check_votes (voter_id);

COMMIT;
