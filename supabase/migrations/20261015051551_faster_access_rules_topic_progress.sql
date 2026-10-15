-- Speed-up for many simultaneous users, part 1. Nobody's access changes.
-- Access rules called auth.uid() once for every row they checked; wrapped
-- in (select ...) Postgres works the answer out once per request instead.
-- Rules are rewritten in place (ALTER POLICY) so nothing is dropped.

alter policy "Users can view own topic progress" on public.topic_progress
  using ((select auth.uid()) = user_id);
alter policy "Users can create own topic progress" on public.topic_progress
  with check ((select auth.uid()) = user_id);
alter policy "Users can update own topic progress" on public.topic_progress
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
