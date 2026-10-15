// supabase/functions/submit-quiz/index.ts
//
// Any signed-in learner: grades a quiz attempt server-side (so the
// answer key never has to be sent to the browser), records the topic as
// completed in topic_progress, and adds the correct-answer count to the
// learner's points -- but only the FIRST time a given topic's quiz is
// completed. Any retake after that is treated as a practice attempt: it
// is still graded and returned to the caller, but it does not touch the
// learner's points or recorded score again.
//   { topic_id, answers: { [question_id]: 'a' | 'b' | 'c' | 'd' } }
//
// Completion is written here (not by the browser) so learners cannot
// mark quizzes as passed or edit their score from the browser console.
//
// Deploy with: supabase functions deploy submit-quiz

import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function getSecretKey(): string {
  const secretKeys = Deno.env.get('SUPABASE_SECRET_KEYS');
  if (secretKeys) {
    try {
      const parsed = JSON.parse(secretKeys);
      const key = parsed.default ?? Object.values(parsed)[0];
      if (typeof key === 'string' && key) return key;
    } catch (_err) {
      // fall through to the legacy variable below
    }
  }
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (legacy) return legacy;
  throw new Error('No secret key is configured for this function.');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return jsonResponse({ error: 'Missing Authorization header.' }, 401);
    const token = authHeader.replace('Bearer ', '');

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const secretKey = getSecretKey();
    const admin = createClient(supabaseUrl, secretKey);

    const { data: { user }, error: userError } = await admin.auth.getUser(token);
    if (userError || !user) return jsonResponse({ error: 'Could not verify who is calling this.' }, 401);

    const { topic_id, answers } = await req.json();
    if (!topic_id || !answers || typeof answers !== 'object') {
      return jsonResponse({ error: 'Provide topic_id and answers.' }, 400);
    }

    const { data: questions, error: questionsError } = await admin
      .from('topic_questions')
      .select('id, correct_option')
      .eq('topic_id', topic_id);

    if (questionsError) return jsonResponse({ error: questionsError.message }, 500);
    if (!questions || questions.length === 0) return jsonResponse({ error: 'This topic has no quiz questions.' }, 404);

    let correctCount = 0;
    questions.forEach((q) => {
      if (answers[q.id] && answers[q.id] === q.correct_option) correctCount += 1;
    });
    const total = questions.length;

    // Make sure a progress row exists, without overwriting an existing one.
    const { error: ensureError } = await admin
      .from('topic_progress')
      .upsert(
        { user_id: user.id, topic_id: topic_id },
        { onConflict: 'user_id,topic_id', ignoreDuplicates: true },
      );
    if (ensureError) return jsonResponse({ error: ensureError.message }, 500);

    // Claim the first completion. Only a row that is not yet completed
    // matches, so if two attempts arrive at once just one of them wins and
    // the other is treated as practice -- points can't be awarded twice.
    const now = new Date().toISOString();
    const { data: claimed, error: claimError } = await admin
      .from('topic_progress')
      .update({
        material_completed: true,
        quiz_completed: true,
        quiz_score: correctCount,
        completed_at: now,
        updated_at: now,
      })
      .eq('user_id', user.id)
      .eq('topic_id', topic_id)
      .or('quiz_completed.is.null,quiz_completed.eq.false')
      .select('id');
    if (claimError) return jsonResponse({ error: claimError.message }, 500);

    if (!claimed || claimed.length === 0) {
      return jsonResponse({
        success: true,
        correctCount: correctCount,
        total: total,
        pointsAwarded: 0,
        isPractice: true,
      }, 200);
    }

    const { data: profile, error: profileError } = await admin
      .from('profiles')
      .select('points')
      .eq('id', user.id)
      .single();
    if (profileError || !profile) return jsonResponse({ error: 'Could not load your profile.' }, 500);

    const { error: updateError } = await admin
      .from('profiles')
      .update({ points: (profile.points || 0) + correctCount })
      .eq('id', user.id);
    if (updateError) return jsonResponse({ error: updateError.message }, 500);

    return jsonResponse({
      success: true,
      correctCount: correctCount,
      total: total,
      pointsAwarded: correctCount,
      isPractice: false,
    }, 200);
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
