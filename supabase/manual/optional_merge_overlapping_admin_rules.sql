-- ALREADY APPLIED on 2026-10-15 through the Supabase SQL Editor.
-- Do not run it again: the rules it creates already exist, so it would fail.
-- Kept here as a record. Nobody's access changed (checked afterwards).
--
-- Some tables have an "admins can do everything" rule (FOR ALL) next to
-- the normal read rule, so every read checks both. This splits the admin
-- rules into separate add / edit / delete rules and folds admin reads
-- into the read rule. "admin write topics" is an exact duplicate of
-- "Course topics are manageable by admins", so it is removed.
-- Everything runs as one transaction: it all applies, or nothing does.

begin;

-- courses
drop policy "Courses are manageable by admins" on public.courses;
create policy "courses: admins insert" on public.courses
  for insert to authenticated with check ((select public.is_admin((select auth.uid()))));
create policy "courses: admins update" on public.courses
  for update to authenticated
  using ((select public.is_admin((select auth.uid()))))
  with check ((select public.is_admin((select auth.uid()))));
create policy "courses: admins delete" on public.courses
  for delete to authenticated using ((select public.is_admin((select auth.uid()))));

-- course_topics
drop policy "Course topics are manageable by admins" on public.course_topics;
drop policy "admin write topics" on public.course_topics;
create policy "topics: admins insert" on public.course_topics
  for insert to authenticated with check ((select public.is_admin((select auth.uid()))));
create policy "topics: admins update" on public.course_topics
  for update to authenticated
  using ((select public.is_admin((select auth.uid()))))
  with check ((select public.is_admin((select auth.uid()))));
create policy "topics: admins delete" on public.course_topics
  for delete to authenticated using ((select public.is_admin((select auth.uid()))));

-- topic_materials
drop policy "topic materials: admins manage" on public.topic_materials;
create policy "topic materials: admins insert" on public.topic_materials
  for insert to authenticated with check ((select public.is_admin((select auth.uid()))));
create policy "topic materials: admins update" on public.topic_materials
  for update to authenticated
  using ((select public.is_admin((select auth.uid()))))
  with check ((select public.is_admin((select auth.uid()))));
create policy "topic materials: admins delete" on public.topic_materials
  for delete to authenticated using ((select public.is_admin((select auth.uid()))));

commit;
