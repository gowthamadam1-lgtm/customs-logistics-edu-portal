// supabase/functions/delete-my-account/index.ts
//
// Any signed-in learner: permanently deletes THEIR OWN account (Google Play
// requires apps with sign-up to offer this). It removes the account's
// uploaded files (profile photo, KPI reports) and its login; the database
// then removes the profile, quiz progress, KPI records and the learner's own
// tickets (ON DELETE CASCADE). Staff accounts are refused here so the portal
// can never lose its admins by accident; another admin removes them instead.
//   {}  (no body needed: the account is the caller's)
//
// Deploy with: supabase functions deploy delete-my-account

import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Buckets where files live in a folder named after the user's id.
const USER_FILE_BUCKETS = ['avatars', 'kpi-presentations'];

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
    const admin = createClient(supabaseUrl, getSecretKey());

    const { data: { user }, error: userError } = await admin.auth.getUser(token);
    if (userError || !user) return jsonResponse({ error: 'Could not verify who is calling this.' }, 401);

    const { data: profile } = await admin
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .maybeSingle();

    if (profile && profile.role === 'admin') {
      return jsonResponse({ error: 'Staff accounts are removed by another admin, from the Learners page.' }, 403);
    }

    for (const bucket of USER_FILE_BUCKETS) {
      const { data: files, error: listError } = await admin.storage.from(bucket).list(user.id, { limit: 1000 });
      if (listError) return jsonResponse({ error: 'Could not remove your files: ' + listError.message }, 500);
      const paths = (files || []).map((file) => user.id + '/' + file.name);
      if (paths.length) {
        const { error: removeError } = await admin.storage.from(bucket).remove(paths);
        if (removeError) return jsonResponse({ error: 'Could not remove your files: ' + removeError.message }, 500);
      }
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) return jsonResponse({ error: deleteError.message }, 500);

    return jsonResponse({ success: true }, 200);
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
