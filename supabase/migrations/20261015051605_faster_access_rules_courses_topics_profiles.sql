-- Speed-up part 2: same rewrite for courses, topics, materials, questions
-- and profiles. "admin write topics" checked profiles.role = 'admin'
-- directly, which is what is_admin() does, so it now uses is_admin().

alter policy "Courses are manageable by admins" on public.courses
  using ((select public.is_admin((select auth.uid()))))
  with check ((select public.is_admin((select auth.uid()))));

alter policy "Course topics are manageable by admins" on public.course_topics
  using ((select public.is_admin((select auth.uid()))))
  with check ((select public.is_admin((select auth.uid()))));
alter policy "admin write topics" on public.course_topics
  using ((select public.is_admin((select auth.uid()))))
  with check ((select public.is_admin((select auth.uid()))));
alter policy "topics: read published or admin" on public.course_topics
  using (published or (select public.is_admin((select auth.uid()))));

alter policy "topic materials: admins manage" on public.topic_materials
  using ((select public.is_admin((select auth.uid()))))
  with check ((select public.is_admin((select auth.uid()))));
alter policy "topic materials: read published or admin" on public.topic_materials
  using (exists (
    select 1 from public.course_topics t
    where t.id = topic_materials.topic_id
      and (t.published or (select public.is_admin((select auth.uid()))))
  ));

alter policy "Topic questions are manageable by admins" on public.topic_questions
  using ((select public.is_admin((select auth.uid()))))
  with check ((select public.is_admin((select auth.uid()))));

alter policy "Profiles are editable by owner" on public.profiles
  using ((select auth.uid()) = id)
  with check (
    (select auth.uid()) = id
    and role = (select p.role from public.profiles p where p.id = (select auth.uid()))
    and status = (select p.status from public.profiles p where p.id = (select auth.uid()))
  );
