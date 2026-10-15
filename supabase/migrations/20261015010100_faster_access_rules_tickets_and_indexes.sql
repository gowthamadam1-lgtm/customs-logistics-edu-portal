-- Part 2 of the speed-up (see 20261015010000): same change for KPI
-- reports, support tickets and ticket messages, plus indexes.

-- ---------- kpi_presentations ----------
drop policy "kpi: learners delete own" on public.kpi_presentations;
drop policy "kpi: learners insert own" on public.kpi_presentations;
drop policy "kpi: read own or admin" on public.kpi_presentations;
create policy "kpi: learners delete own" on public.kpi_presentations
  for delete to authenticated using (user_id = (select auth.uid()));
create policy "kpi: learners insert own" on public.kpi_presentations
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "kpi: read own or admin" on public.kpi_presentations
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin((select auth.uid()))));

-- ---------- support_tickets ----------
drop policy "tickets: admins delete" on public.support_tickets;
drop policy "tickets: learners create own" on public.support_tickets;
drop policy "tickets: read public, own or admin" on public.support_tickets;
drop policy "tickets: update own or admin" on public.support_tickets;
create policy "tickets: admins delete" on public.support_tickets
  for delete to authenticated using ((select public.is_admin((select auth.uid()))));
create policy "tickets: learners create own" on public.support_tickets
  for insert to authenticated
  with check (user_id = (select auth.uid()) and (assigned_to is null or public.is_admin(assigned_to)));
create policy "tickets: read public, own or admin" on public.support_tickets
  for select to authenticated
  using ((not is_private) or user_id = (select auth.uid()) or (select public.is_admin((select auth.uid()))));
create policy "tickets: update own or admin" on public.support_tickets
  for update to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin((select auth.uid()))))
  with check (user_id = (select auth.uid()) or (select public.is_admin((select auth.uid()))));

-- ---------- ticket_messages ----------
drop policy "messages: read visible tickets" on public.ticket_messages;
drop policy "messages: write on open own ticket or admin" on public.ticket_messages;
create policy "messages: read visible tickets" on public.ticket_messages
  for select to authenticated
  using (exists (
    select 1 from public.support_tickets t
    where t.id = ticket_messages.ticket_id
      and ((not t.is_private) or t.user_id = (select auth.uid()) or (select public.is_admin((select auth.uid()))))
  ));
create policy "messages: write on open own ticket or admin" on public.ticket_messages
  for insert to authenticated
  with check (exists (
    select 1 from public.support_tickets t
    where t.id = ticket_messages.ticket_id
      and t.status <> 'closed'
      and (t.user_id = (select auth.uid()) or (select public.is_admin((select auth.uid()))))
  ));

-- ---------- indexes ----------
create index if not exists course_topics_course_id_idx on public.course_topics (course_id);
create index if not exists topic_questions_topic_id_idx on public.topic_questions (topic_id);
create index if not exists topic_progress_topic_id_idx on public.topic_progress (topic_id);
create index if not exists support_tickets_topic_id_idx on public.support_tickets (topic_id);
create index if not exists support_tickets_last_message_at_idx on public.support_tickets (last_message_at desc);
create index if not exists ticket_messages_author_id_idx on public.ticket_messages (author_id);

