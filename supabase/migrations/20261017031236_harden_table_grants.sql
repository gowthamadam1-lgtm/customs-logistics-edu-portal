-- Defense-in-depth: remove the broad default grants on the older tables so the
-- row-level rules are no longer the only thing standing between a signed-out
-- visitor (anon) and the data. anon is left with no access to any app table;
-- signed-in users (authenticated) get only what each screen needs. The newer
-- announcements and help_contacts tables were already set up this way.
revoke all on public.courses, public.course_topics, public.topic_materials,
               public.topic_questions, public.kpi_presentations, public.profiles,
               public.support_tickets, public.ticket_messages, public.topic_progress
  from anon, authenticated;

-- Content: learners read; admins write (RLS still enforces admin-only writes).
grant select, insert, update, delete on public.courses to authenticated;
grant select, insert, update, delete on public.course_topics to authenticated;
grant select, insert, update, delete on public.topic_materials to authenticated;
grant select, insert, update, delete on public.topic_questions to authenticated;

-- KPI reports: create, read and delete your own (no update).
grant select, insert, delete on public.kpi_presentations to authenticated;

-- Profiles: read all; change only your own username and photo.
grant select on public.profiles to authenticated;
grant update (username, avatar_url) on public.profiles to authenticated;

-- Tickets: learners create/read/update; admins delete (RLS).
grant select, insert, update, delete on public.support_tickets to authenticated;

-- Ticket replies: read and write only.
grant select, insert on public.ticket_messages to authenticated;

-- Progress: read own; mark material as read only. Score and pass are written
-- only by the submit-quiz server function, never from the browser.
grant select on public.topic_progress to authenticated;
grant insert (user_id, topic_id, material_completed, updated_at) on public.topic_progress to authenticated;
grant update (material_completed, updated_at) on public.topic_progress to authenticated;
