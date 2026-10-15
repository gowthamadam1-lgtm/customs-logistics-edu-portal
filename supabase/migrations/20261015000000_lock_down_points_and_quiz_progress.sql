-- Learners could previously edit their own `points` (profiles) and set
-- `quiz_completed` / `quiz_score` (topic_progress) straight from the
-- browser console, because the row-level policies only check *which row*
-- is being changed, not *which columns*. Column privileges close that gap.
--
-- Deploy the updated submit-quiz function BEFORE running this, because
-- after this runs only the server can mark a quiz as completed.

-- profiles: learners may change only their username and avatar.
revoke insert, update on public.profiles from anon, authenticated;
grant update (username, avatar_url) on public.profiles to authenticated;

-- topic_progress: learners may only record that they finished the
-- learning material. Quiz completion and score are written by submit-quiz.
revoke insert, update on public.topic_progress from anon, authenticated;
grant insert (user_id, topic_id, material_completed, updated_at)
  on public.topic_progress to authenticated;
grant update (material_completed, updated_at)
  on public.topic_progress to authenticated;
