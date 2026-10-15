-- Speed-up part 3: same rewrite for KPI reports, tickets and messages,
-- plus indexes for the columns pages filter, join and sort on.

alter policy "kpi: learners delete own" on public.kpi_presentations
  using (user_id = (select auth.uid()));
alter policy "kpi: learners insert own" on public.kpi_presentations
  with check (user_id = (select auth.uid()));
alter policy "kpi: read own or admin" on public.kpi_presentations
  using (user_id = (select auth.uid()) or (select public.is_admin((select auth.uid()))));

alter policy "tickets: admins delete" on public.support_tickets
  using ((select public.is_admin((select auth.uid()))));
alter policy "tickets: learners create own" on public.support_tickets
  with check (user_id = (select auth.uid()) and (assigned_to is null or public.is_admin(assigned_to)));
alter policy "tickets: read public, own or admin" on public.support_tickets
  using ((not is_private) or user_id = (select auth.uid()) or (select public.is_admin((select auth.uid()))));
alter policy "tickets: update own or admin" on public.support_tickets
  using (user_id = (select auth.uid()) or (select public.is_admin((select auth.uid()))))
  with check (user_id = (select auth.uid()) or (select public.is_admin((select auth.uid()))));

alter policy "messages: read visible tickets" on public.ticket_messages
  using (exists (
    select 1 from public.support_tickets t
    where t.id = ticket_messages.ticket_id
      and ((not t.is_private) or t.user_id = (select auth.uid()) or (select public.is_admin((select auth.uid()))))
  ));
alter policy "messages: write on open own ticket or admin" on public.ticket_messages
  with check (exists (
    select 1 from public.support_tickets t
    where t.id = ticket_messages.ticket_id
      and t.status <> 'closed'
      and (t.user_id = (select auth.uid()) or (select public.is_admin((select auth.uid()))))
  ));

create index if not exists course_topics_course_id_idx on public.course_topics (course_id);
create index if not exists topic_questions_topic_id_idx on public.topic_questions (topic_id);
create index if not exists topic_progress_topic_id_idx on public.topic_progress (topic_id);
create index if not exists support_tickets_topic_id_idx on public.support_tickets (topic_id);
create index if not exists support_tickets_last_message_at_idx on public.support_tickets (last_message_at desc);
create index if not exists ticket_messages_author_id_idx on public.ticket_messages (author_id);
