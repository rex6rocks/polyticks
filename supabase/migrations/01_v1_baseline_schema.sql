-- ─────────────────────────────────────────────────────────────────────────────
--  Polyticks – Migration 01 : V1.0 Baseline Schema
--  Target DB : Supabase (PostgreSQL 15+)
--  Author    : Senior System Architect (Antigravity)
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- ─── SECTION 1 : CUSTOM ENUMS ───────────────────────────────────────────────

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE public.user_role AS ENUM ('basic', 'verified_user', 'org_placeholder', 'admin');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_status') THEN
        CREATE TYPE public.verification_status AS ENUM ('unverified', 'pending', 'approved', 'rejected');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'channel_type') THEN
        CREATE TYPE public.channel_type AS ENUM ('local', 'broader');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'reaction_type') THEN
        CREATE TYPE public.reaction_type AS ENUM ('like', 'dislike');
    END IF;
END$$;


-- ─── SECTION 2 : CORE TABLES ────────────────────────────────────────────────

-- Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id                  UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone_number        TEXT UNIQUE,
    username            TEXT UNIQUE,
    is_verified         BOOLEAN DEFAULT false,
    verification_status public.verification_status DEFAULT 'unverified',
    role                public.user_role DEFAULT 'basic',
    community_id        UUID,
    avatar_color        TEXT DEFAULT '#4ECDC4',
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Posts Table
CREATE TABLE IF NOT EXISTS public.posts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id           UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    channel_type        public.channel_type DEFAULT 'broader'::public.channel_type NOT NULL,
    community_id        UUID,
    content             TEXT NOT NULL,
    media_url           TEXT,
    like_count          INTEGER DEFAULT 0 NOT NULL,
    dislike_count       INTEGER DEFAULT 0 NOT NULL,
    is_hidden           BOOLEAN DEFAULT false NOT NULL,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Reactions Table
CREATE TABLE IF NOT EXISTS public.reactions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id             UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    type                public.reaction_type NOT NULL,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT unique_user_post_reaction UNIQUE (user_id, post_id)
);

-- Reports Table
CREATE TABLE IF NOT EXISTS public.reports (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id             UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    reason              TEXT NOT NULL,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);


-- ─── SECTION 3 : ROW-LEVEL SECURITY ─────────────────────────────────────────

ALTER TABLE public.profiles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports   ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
DROP POLICY IF EXISTS "Profiles viewable by everyone" ON public.profiles;
CREATE POLICY "Profiles viewable by everyone" ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Posts Policies
DROP POLICY IF EXISTS "Unhidden posts viewable by everyone" ON public.posts;
CREATE POLICY "Unhidden posts viewable by everyone" ON public.posts FOR SELECT USING (is_hidden = false);

DROP POLICY IF EXISTS "Verified users can insert posts" ON public.posts;
CREATE POLICY "Verified users can insert posts" ON public.posts FOR INSERT WITH CHECK (
    auth.uid() = author_id AND EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND (role = 'verified_user' OR role = 'admin' OR role = 'org_placeholder')
    )
);

DROP POLICY IF EXISTS "Authors/admins can delete posts" ON public.posts;
CREATE POLICY "Authors/admins can delete posts" ON public.posts FOR DELETE USING (
    auth.uid() = author_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Reactions Policies
DROP POLICY IF EXISTS "Reactions viewable by everyone" ON public.reactions;
CREATE POLICY "Reactions viewable by everyone" ON public.reactions FOR SELECT USING (true);

DROP POLICY IF EXISTS "Auth users can react" ON public.reactions;
CREATE POLICY "Auth users can react" ON public.reactions FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own reaction" ON public.reactions;
CREATE POLICY "Users can delete own reaction" ON public.reactions FOR ALL USING (auth.uid() = user_id);

-- Reports Policies
DROP POLICY IF EXISTS "Admins can view reports" ON public.reports;
CREATE POLICY "Admins can view reports" ON public.reports FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

DROP POLICY IF EXISTS "Auth users can report" ON public.reports;
CREATE POLICY "Auth users can report" ON public.reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);


-- ─── SECTION 4 : BASELINE TRIGGERS ──────────────────────────────────────────

-- Trigger: auto-profile creation on auth signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, phone_number, username, role, is_verified, verification_status)
  VALUES (
    new.id,
    new.phone,
    'user_' || substring(md5(random()::text) from 1 for 8),
    'basic',
    false,
    'unverified'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger: reaction counts sync
CREATE OR REPLACE FUNCTION public.handle_reaction_change()
RETURNS trigger AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    IF (NEW.type = 'like') THEN
      UPDATE public.posts SET like_count = like_count + 1 WHERE id = NEW.post_id;
    ELSIF (NEW.type = 'dislike') THEN
      UPDATE public.posts SET dislike_count = dislike_count + 1 WHERE id = NEW.post_id;
    END IF;
  ELSIF (TG_OP = 'DELETE') THEN
    IF (OLD.type = 'like') THEN
      UPDATE public.posts SET like_count = GREATEST(0, like_count - 1) WHERE id = OLD.post_id;
    ELSIF (OLD.type = 'dislike') THEN
      UPDATE public.posts SET dislike_count = GREATEST(0, dislike_count - 1) WHERE id = OLD.post_id;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_reaction_inserted_or_deleted ON public.reactions;
CREATE TRIGGER on_reaction_inserted_or_deleted
  AFTER INSERT OR DELETE ON public.reactions
  FOR EACH ROW EXECUTE FUNCTION public.handle_reaction_change();

COMMIT;
