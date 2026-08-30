-- Step: Add policy to allow users to delete their own profile
-- This migration allows users to delete their own profile row,
-- assuming they are authenticated and the row belongs to them.
-- Admin/Org roles remain protected via existing hierarchy rules.

DROP POLICY IF EXISTS "Users delete own profile" ON public.profiles;

CREATE POLICY "Users delete own profile" ON public.profiles
    FOR DELETE
    TO authenticated
    USING (auth.uid() = id AND public.caller_is_privileged() = false);
