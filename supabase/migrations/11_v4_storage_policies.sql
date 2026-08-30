-- ─────────────────────────────────────────────────────────────────────────────
--  Polyticks – Migration 11 : Storage policies for `id-verifications`
--  Fixes: 403 "new row violates row level security policy" on ID upload.
--
--  The bucket was created manually without policies, so ALL client storage
--  operations were rejected. These policies allow:
--    * users to upload/read/delete files ONLY inside their own folder
--      (<auth.uid>/…), enforced via the first path segment;
--    * admins the same via caller_is_privileged();
--    * service_role bypasses RLS entirely (purge edge function).
--
--  Upload path convention: `<user_id>/id_verification.jpg` (see V4 code).
-- ─────────────────────────────────────────────────────────────────────────────

-- Users may upload only into their own folder.
CREATE POLICY "Users upload own ID docs" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'id-verifications'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Users may read their own document (e.g. preview); admins see all.
CREATE POLICY "Users read own ID docs" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'id-verifications'
  AND ((storage.foldername(name))[1] = auth.uid()::text
       OR public.caller_is_privileged())
);

-- Zero-retention purge: users may delete their own; admins any.
CREATE POLICY "Users delete own ID docs" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'id-verifications'
  AND ((storage.foldername(name))[1] = auth.uid()::text
       OR public.caller_is_privileged())
);
