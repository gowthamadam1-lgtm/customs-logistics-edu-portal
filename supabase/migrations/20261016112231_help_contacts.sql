-- Help contacts: the staff people learners can reach, listed under Contacts
-- on the learner Help page. Every signed-in user can read them; only admins
-- add, edit or remove them. Signed-out visitors get nothing.
create table public.help_contacts (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 80),
  role text not null check (char_length(btrim(role)) between 2 and 80),
  email text check (email is null or (char_length(email) <= 254 and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  phone text check (phone is null or phone ~ '^\+?[0-9 ()-]{7,20}$'),
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint help_contacts_reachable check (email is not null or phone is not null)
);

create index help_contacts_created_at_idx on public.help_contacts (created_at);
create index help_contacts_created_by_idx on public.help_contacts (created_by);

alter table public.help_contacts enable row level security;

create policy "help contacts: signed-in users read" on public.help_contacts
  for select to authenticated using (true);

create policy "help contacts: admins add" on public.help_contacts
  for insert to authenticated
  with check ((select public.is_admin((select auth.uid()))) and created_by = (select auth.uid()));

create policy "help contacts: admins edit" on public.help_contacts
  for update to authenticated
  using ((select public.is_admin((select auth.uid()))))
  with check ((select public.is_admin((select auth.uid()))));

create policy "help contacts: admins remove" on public.help_contacts
  for delete to authenticated using ((select public.is_admin((select auth.uid()))));

-- Only the four contact fields can ever be changed after a contact is added.
revoke all on public.help_contacts from anon, authenticated;
grant select, insert, delete on public.help_contacts to authenticated;
grant update (name, role, email, phone) on public.help_contacts to authenticated;
