-- Learners read quiz questions through topic_questions_public, which leaves
-- out correct_option. The view was security_invoker, so it applied the
-- caller's row rules on topic_questions, where only admins have a rule:
-- learners got no questions. Running the view as its owner lets it return
-- the questions of published topics (its own WHERE clause) without ever
-- exposing the answers. Signed-out visitors have no reason to read it.
alter view public.topic_questions_public set (security_invoker = false);
revoke all on public.topic_questions_public from anon;
revoke insert, update, delete, truncate, references, trigger on public.topic_questions_public from authenticated;
grant select on public.topic_questions_public to authenticated;
