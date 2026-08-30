-- ─────────────────────────────────────────────────────────────────────────────
--  Polyticks – Migration 05 : Add Flagged Reason to Posts (Idempotent)
--  Target DB : Supabase (PostgreSQL 15+)
--  Author    : Mid-Level Integrator (Cline)
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- Step 1: Ensure posts table has flagged_reason column
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name   = 'posts' 
          AND column_name  = 'flagged_reason'
    ) THEN
        ALTER TABLE public.posts 
            ADD COLUMN flagged_reason TEXT;
    END IF;
END$$;

COMMENT ON COLUMN public.posts.flagged_reason IS
    'Stores the reason why a post was flagged/hidden (e.g. ai_prescreen).';

COMMIT;
