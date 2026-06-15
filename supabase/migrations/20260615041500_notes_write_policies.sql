-- US-011: round out RLS on `public.notes` so each user can mutate their own
-- rows while writes against another user's rows fail. With these policies in
-- place, an UPDATE or DELETE that targets a row whose `user_id` doesn't match
-- `auth.uid()` is filtered to zero affected rows by the policy's USING clause
-- (PostgREST surfaces this as an empty `return=representation` array, which
-- the Rails controller maps to "Note not found"). The `with check` on UPDATE
-- additionally prevents a permitted owner from reassigning ownership.

create policy "Users can update own notes"
  on public.notes for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete own notes"
  on public.notes for delete
  to authenticated
  using ((select auth.uid()) = user_id);
