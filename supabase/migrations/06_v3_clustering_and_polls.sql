-- ─────────────────────────────────────────────────────────────────────────────
--  Polyticks – Migration 06 : V3 Hyper-Local Clustering & Polls Infrastructure
--  Target DB : Supabase (PostgreSQL 15+)
--  Author    : Backend / Database Admin (Antigravity)
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- ── 1. COMMUNITIES & WARDS INFRASTRUCTURE ───────────────────────────────────

CREATE TABLE IF NOT EXISTS public.communities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    state TEXT NOT NULL,
    postal_code TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.wards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    ward_number INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ── 2. CLAIM STATUS ENUM & PROFILE / POST UPDATES ───────────────────────────

DO $$ BEGIN
    CREATE TYPE claim_status_type AS ENUM ('unclaimed', 'claim_pending', 'claimed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TABLE public.profiles 
    ADD COLUMN IF NOT EXISTS community_id UUID REFERENCES public.communities(id),
    ADD COLUMN IF NOT EXISTS ward_id UUID REFERENCES public.wards(id),
    ADD COLUMN IF NOT EXISTS claim_status claim_status_type DEFAULT 'unclaimed',
    ADD COLUMN IF NOT EXISTS official_email TEXT;

ALTER TABLE public.posts 
    ADD COLUMN IF NOT EXISTS community_id UUID REFERENCES public.communities(id),
    ADD COLUMN IF NOT EXISTS ward_id UUID REFERENCES public.wards(id);

-- ── 3. POLLING ENGINE SCHEMA ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.polls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    question TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.poll_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    option_text TEXT NOT NULL,
    vote_count INTEGER DEFAULT 0 NOT NULL
);

CREATE TABLE IF NOT EXISTS public.poll_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    option_id UUID NOT NULL REFERENCES public.poll_options(id) ON DELETE CASCADE,
    voter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT unique_user_poll_vote UNIQUE (poll_id, voter_id)
);

-- ── 4. ROW-LEVEL SECURITY (RLS) POLICIES ────────────────────────────────────

ALTER TABLE public.communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to allow clean re-execution
DROP POLICY IF EXISTS "Communities viewable by everyone" ON public.communities;
DROP POLICY IF EXISTS "Wards viewable by everyone" ON public.wards;
DROP POLICY IF EXISTS "Polls viewable by everyone" ON public.polls;
DROP POLICY IF EXISTS "Poll options viewable by everyone" ON public.poll_options;
DROP POLICY IF EXISTS "Poll votes viewable by everyone" ON public.poll_votes;
DROP POLICY IF EXISTS "Verified community members can vote" ON public.poll_votes;
DROP POLICY IF EXISTS "Users can delete own votes" ON public.poll_votes;

CREATE POLICY "Communities viewable by everyone" ON public.communities FOR SELECT USING (true);
CREATE POLICY "Wards viewable by everyone" ON public.wards FOR SELECT USING (true);
CREATE POLICY "Polls viewable by everyone" ON public.polls FOR SELECT USING (true);
CREATE POLICY "Poll options viewable by everyone" ON public.poll_options FOR SELECT USING (true);
CREATE POLICY "Poll votes viewable by everyone" ON public.poll_votes FOR SELECT USING (true);

CREATE POLICY "Verified community members can vote" ON public.poll_votes 
FOR INSERT WITH CHECK (
    auth.uid() = voter_id
    AND EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() AND is_verified = true
    )
    AND (
        (SELECT community_id FROM public.posts WHERE id = (SELECT post_id FROM public.polls WHERE id = poll_id)) IS NULL
        OR
        (SELECT community_id FROM public.profiles WHERE id = auth.uid()) = 
        (SELECT community_id FROM public.posts WHERE id = (SELECT post_id FROM public.polls WHERE id = poll_id))
    )
);

-- Members may retract their own vote (trigger auto-decrements vote_count).
CREATE POLICY "Users can delete own votes" ON public.poll_votes
FOR DELETE USING (auth.uid() = voter_id);

-- ── 5. VOTE COUNT REAL-TIME TRIGGER ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_poll_vote_change()
RETURNS trigger AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.poll_options 
        SET vote_count = vote_count + 1 
        WHERE id = NEW.option_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.poll_options 
        SET vote_count = GREATEST(0, vote_count - 1) 
        WHERE id = OLD.option_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_poll_vote_inserted_or_deleted ON public.poll_votes;
CREATE TRIGGER on_poll_vote_inserted_or_deleted
    AFTER INSERT OR DELETE ON public.poll_votes
    FOR EACH ROW EXECUTE FUNCTION public.handle_poll_vote_change();

COMMIT;
