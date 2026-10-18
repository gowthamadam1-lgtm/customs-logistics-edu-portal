-- Grade a quiz in a single database call (replaces the submit-quiz edge
-- function, removing its cold-start delay). Returns the score, points, and a
-- per-question breakdown so learners can review which answers were wrong.
-- Security (verified adversarially):
--   * identity is auth.uid(), never client input;
--   * SECURITY DEFINER so it can write quiz_score/points that the browser cannot;
--   * first completion is claimed atomically, so points are awarded once;
--   * only a PUBLISHED topic (or an admin) can be graded, so draft quizzes and
--     their answer key never leak through this function;
--   * EXECUTE is granted to signed-in users only.
create or replace function public.grade_quiz(p_topic_id uuid, p_answers jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_total int;
  v_correct int;
  v_claimed int;
  v_points int := 0;
  v_breakdown jsonb;
  v_allowed boolean;
begin
  if v_uid is null then
    raise exception 'You must be signed in to submit a quiz.';
  end if;
  if p_topic_id is null or p_answers is null then
    raise exception 'A topic and answers are required.';
  end if;

  -- Only a published topic (or an admin testing it) may be graded.
  select (t.published or public.is_admin(v_uid))
    into v_allowed
    from public.course_topics t
   where t.id = p_topic_id;
  if v_allowed is not true then
    raise exception 'This quiz is not available.';
  end if;

  -- Grade against the real answer key and build the per-question breakdown.
  select
    count(*)::int,
    count(*) filter (where lower(coalesce(p_answers ->> q.id::text, '')) = lower(q.correct_option))::int,
    jsonb_agg(jsonb_build_object(
      'id', q.id,
      'question', q.question,
      'your_answer', p_answers ->> q.id::text,
      'correct_option', q.correct_option,
      'is_correct', lower(coalesce(p_answers ->> q.id::text, '')) = lower(q.correct_option),
      'options', jsonb_build_object('a', q.option_a, 'b', q.option_b, 'c', q.option_c, 'd', q.option_d)
    ) order by q.order_index)
    into v_total, v_correct, v_breakdown
    from public.topic_questions q
   where q.topic_id = p_topic_id;

  if v_total is null or v_total = 0 then
    raise exception 'This topic has no quiz questions.';
  end if;

  -- Make sure a progress row exists, then claim the first completion atomically
  -- (only a not-yet-completed row matches), so points are awarded exactly once.
  insert into public.topic_progress (user_id, topic_id)
    values (v_uid, p_topic_id)
    on conflict (user_id, topic_id) do nothing;

  update public.topic_progress
     set material_completed = true,
         quiz_completed = true,
         quiz_score = v_correct,
         completed_at = now(),
         updated_at = now()
   where user_id = v_uid and topic_id = p_topic_id
     and (quiz_completed is null or quiz_completed = false);
  get diagnostics v_claimed = row_count;

  if v_claimed > 0 then
    update public.profiles set points = coalesce(points, 0) + v_correct where id = v_uid;
    v_points := v_correct;
  end if;

  return jsonb_build_object(
    'correctCount', v_correct,
    'total', v_total,
    'pointsAwarded', v_points,
    'isPractice', v_claimed = 0,
    'questions', v_breakdown
  );
end;
$fn$;

revoke all on function public.grade_quiz(uuid, jsonb) from public, anon;
grant execute on function public.grade_quiz(uuid, jsonb) to authenticated;
