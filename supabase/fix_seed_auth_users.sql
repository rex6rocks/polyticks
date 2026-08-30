DROP POLICY IF EXISTS "Users can delete own votes" ON public.poll_votes;
CREATE POLICY "Users can delete own votes" ON public.poll_votes
FOR DELETE USING (auth.uid() = voter_id);
