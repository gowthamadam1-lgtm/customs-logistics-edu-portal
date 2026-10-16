-- Announcements: short notices from staff, shown at the top of the
-- learner Home page. Every signed-in user can read them; only admins can
-- post or delete them. Signed-out visitors get nothing.
create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 3 and 120),
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index announcements_created_at_idx on public.announcements (created_at desc);
create index announcements_created_by_idx on public.announcements (created_by);

alter table public.announcements enable row level security;

create policy "announcements: signed-in users read" on public.announcements
  for select to authenticated using (true);

create policy "announcements: admins post" on public.announcements
  for insert to authenticated
  with check ((select public.is_admin((select auth.uid()))) and created_by = (select auth.uid()));

create policy "announcements: admins delete" on public.announcements
  for delete to authenticated using ((select public.is_admin((select auth.uid()))));

revoke all on public.announcements from anon, authenticated;
grant select, insert, delete on public.announcements to authenticated;
