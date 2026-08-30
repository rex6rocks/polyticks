-- ─────────────────────────────────────────────────────────────────────────────
--  Polyticks – Migration 12 : Fix ID-upload storage RLS (403 on retries)
--
--  Problem: the client uploads with upsert:true to the same path
--  (<auth.uid>/id_verification.jpg). When the object already exists,
--  Supabase Storage performs an UPDATE — but migration 11 defined only
--  INSERT/SELECT/DELETE policies, so retries failed with:
--    403 "new row violates row-level security policy"
--
--  Fix: add an UPDATE policy scoped like the others. All statements are
--  idempotent (DROP POLICY IF EXISTS) so this can be re-run safely and
--  will never fail with 42710 "policy ... already exists".
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Users upload own ID docs" ON storage.objects;
CREATE POLICY "Users upload own ID docs" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'id-verifications'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- NEW: required because upsert:true issues UPDATE for pre-existing objects.
DROP POLICY IF EXISTS "Users update own ID docs" ON storage.objects;
CREATE POLICY "Users update own ID docs" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'id-verifications'
  AND ((storage.foldername(name))[1] = auth.uid()::text
       OR public.caller_is_privileged())
)
WITH CHECK (
  bucket_id = 'id-verifications'
  AND ((storage.foldername(name))[1] = auth.uid()::text
       OR public.caller_is_privileged())
);

DROP POLICY IF EXISTS "Users read own ID docs" ON storage.objects;
CREATE POLICY "Users read own ID docs" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'id-verifications'
  AND ((storage.foldername(name))[1] = auth.uid()::text
       OR public.caller_is_privileged())
);

DROP POLICY IF EXISTS "Users delete own ID docs" ON storage.objects;
CREATE POLICY "Users delete own ID docs" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'id-verifications'
  AND ((storage.foldername(name))[1] = auth.uid()::text
       OR public.caller_is_privileged())
);