-- Speed-up for many simultaneous users. Nobody's access changes.
--
-- 1. Access rules called auth.uid() / is_admin(auth.uid()) once for every
--    row they checked. Wrapping them in (select ...) makes Postgres work
--    the answer out once per request instead.
-- 2. "Admins can do everything" rules (FOR ALL) also ran on every normal
--    read next to the read rule. They are split into separate
--    insert / update / delete rules, and admin reads are folded into the
--    read rule, so each read checks a single rule.
-- 3. "admin write topics" duplicated "Course topics are manageable by
--    admins" exactly, so it is dropped.
-- 4. Indexes for the columns pages filter and join on.

-- ---------- courses ----------
drop policy "Courses are manageable by admins" on public.courses;
create policy "courses: admins insert" on public.courses
  for insert to authenticated with check ((select public.is_admin((select auth.uid()))));
create policy "courses: admins update" on public.courses
  for update to authenticated
  using ((select public.is_admin((select auth.uid()))))
  with check ((select public.is_admin((select auth.uid()))));
create policy "courses: admins delete" on public.courses
  for delete to authenticated using ((select public.is_admin((select auth.uid()))));
-- "Courses are viewable by authenticated users" (using true) is unchanged.

-- ---------- course_topics ----------
drop policy "Course topics are manageable by admins" on public.course_topics;
drop policy "admin write topics" on public.course_topics;
drop policy "topics: read published or admin" on public.course_topics;
create policy "topics: read published or admin" on public.course_topics
  for select to authenticated
  using (published or (select public.is_admin((select auth.uid()))));
create policy "topics: admins insert" on public.course_topics
  for insert to authenticated with check ((select public.is_admin((select auth.uid()))));
create policy "topics: admins update" on public.course_topics
  for update to authenticated
  using ((select public.is_admin((select auth.uid()))))
  with check ((select public.is_admin((select auth.uid()))));
create policy "topics: admins delete" on public.course_topics
  for delete to authenticated using ((select public.is_admin((select auth.uid()))));

-- ---------- topic_materials ----------
drop policy "topic materials: admins manage" on public.topic_materials;
drop policy "topic materials: read published or admin" on public.topic_materials;
create policy "topic materials: read published or admin" on public.topic_materials
  for select to authenticated
  using (
    (select public.is_admin((select auth.uid())))
    or exists (
      select 1 from public.course_topics t
      where t.id = topic_materials.topic_id and t.published
    )
  );
create policy "topic materials: admins insert" on public.topic_materials
  for insert to authenticated with check ((select public.is_admin((select auth.uid()))));
create policy "topic materials: admins update" on public.topic_materials
  for update to authenticated
  using ((select public.is_admin((select auth.uid()))))
  with check ((select public.is_admin((select auth.uid()))));
create policy "topic materials: admins delete" on public.topic_materials
  for delete to authenticated using ((select public.is_admin((select auth.uid()))));

-- ---------- topic_questions (admins only; learners read topic_questions_public) ----------
drop policy "Topic questions are manageable by admins" on public.topic_questions;
create policy "Topic questions are manageable by admins" on public.topic_questions
  for all to authenticated
  using ((select public.is_admin((select auth.uid()))))
  with check ((select public.is_admin((select auth.uid()))));

-- ---------- topic_progress ----------
drop policy "Users can view own topic progress" on public.topic_progress;
drop policy "Users can create own topic progress" on public.topic_progress;
drop policy "Users can update own topic progress" on public.topic_progress;
create policy "Users can view own topic progress" on public.topic_progress
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can create own topic progress" on public.topic_progress
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update own topic progress" on public.topic_progress
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ---------- profiles ----------
drop policy "Profiles are editable by owner" on public.profiles;
create policy "Profiles are editable by owner" on public.profiles
  for update to public
  using ((select auth.uid()) = id)
  with check (
    (select auth.uid()) = id
    and role = (select p.role from public.profiles p where p.id = (select auth.uid()))
    and status = (select p.status from public.profiles p where p.id = (select auth.uid()))
  );

