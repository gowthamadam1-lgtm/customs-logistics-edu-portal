-- DL Logitalk is a third place courses can live, alongside Home and Other Courses.
alter table public.courses
  drop constraint if exists courses_section_check,
  add constraint courses_section_check check (section = any (array['home'::text, 'other'::text, 'dl'::text]));
