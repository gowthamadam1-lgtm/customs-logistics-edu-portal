// supabase/functions/admin-manage-account/index.ts
//
// Admin-only actions, all requiring the secret key server-side:
//   { action: 'create', username, email, password }
//     -> creates a brand-new auth user + profile (role defaults to 'user';
//        auto-approved since an admin is creating it directly; promote
//        via admin-set-role afterward if it should be an admin account)
//   { action: 'update', targetUsername, newUsername?, newPassword? }
//     -> renames a learner and/or resets their password
//   { action: 'delete', targetId }
//     -> permanently deletes an account: its uploaded files (profile photo,
//        KPI reports) and its login. The database then removes the profile,
//        quiz progress, KPI records and the user's own tickets (ON DELETE
//        CASCADE); replies they wrote on other tickets stay, unattributed.
//        An admin cannot delete their own account, so one admin always remains.
//
// Deploy with:  supabase functions deploy admin-manage-account
// Call from the browser with:
//   supabase.functions.invoke('admin-manage-account', { body: { ... } })

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

function friendlyCreateError(message: string): string {
  if (/already been registered/i.test(message)) return 'That email is already registered.';
  if (/duplicate key|already exists|unique constraint/i.test(message)) return 'That username is already taken.';
  return message;
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

    // Who is calling, and are they an admin?
    const { data: { user }, error: userError } = await admin.auth.getUser(token);
    if (userError || !user) return jsonResponse({ error: 'Could not verify who is calling this.' }, 401);

    const { data: callerProfile, error: callerError } = await admin
      .from('profiles')
      .select('username, role')
      .eq('id', user.id)
      .single();

    if (callerError || !callerProfile || callerProfile.role !== 'admin') {
      return jsonResponse({ error: 'Only admins can manage other accounts.' }, 403);
    }

    const body = await req.json();
    const action = body?.action;

    if (action === 'create') {
      const { username, email, password } = body;
      if (!username || !email || !password) {
        return jsonResponse({ error: 'Provide a username, email, and password.' }, 400);
      }

      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { username },
      });

      if (createError) {
        return jsonResponse({ error: friendlyCreateError(createError.message || '') }, 400);
      }

      // The signup trigger defaults every new profile to pending, but an
      // admin creating this account directly has already vetted it.
      if (created.user?.id) {
        await admin.from('profiles').update({ status: 'approved' }).eq('id', created.user.id);
      }

      return jsonResponse({ success: true, id: created.user?.id }, 200);
    }

    if (action === 'update') {
      const { targetUsername, newUsername, newPassword } = body;
      if (!targetUsername) return jsonResponse({ error: 'Missing targetUsername.' }, 400);
      if (!newUsername && !newPassword) return jsonResponse({ error: 'Nothing to update.' }, 400);

      const { data: target, error: targetError } = await admin
        .from('profiles')
        .select('id, username')
        .eq('username', targetUsername)
        .single();

      if (targetError || !target) return jsonResponse({ error: 'Could not find that learner.' }, 404);

      if (newUsername && newUsername !== target.username) {
        const { error: usernameError } = await admin
          .from('profiles')
          .update({ username: newUsername })
          .eq('id', target.id);

        if (usernameError) {
          const message = usernameError.code === '23505'
            ? 'That username is already taken.'
            : usernameError.message;
          return jsonResponse({ error: message }, 400);
        }
      }

      if (newPassword) {
        const { error: passwordError } = await admin.auth.admin.updateUserById(target.id, { password: newPassword });
        if (passwordError) return jsonResponse({ error: passwordError.message }, 400);
      }

      return jsonResponse({ success: true }, 200);
    }

    if (action === 'delete') {
      const { targetId } = body;
      if (!targetId || typeof targetId !== 'string') return jsonResponse({ error: 'Missing targetId.' }, 400);
      if (targetId === user.id) return jsonResponse({ error: 'You cannot delete your own account.' }, 400);

      const { data: target, error: targetError } = await admin
        .from('profiles')
        .select('id, username')
        .eq('id', targetId)
        .single();

      if (targetError || !target) return jsonResponse({ error: 'Could not find that account.' }, 404);

      // Uploaded files first: nothing else points at them once the login is gone.
      let filesRemoved = 0;
      for (const bucket of USER_FILE_BUCKETS) {
        const { data: files, error: listError } = await admin.storage.from(bucket).list(targetId, { limit: 1000 });
        if (listError) return jsonResponse({ error: 'Could not remove the account\'s files: ' + listError.message }, 500);
        const paths = (files || []).map((file) => targetId + '/' + file.name);
        if (paths.length) {
          const { error: removeError } = await admin.storage.from(bucket).remove(paths);
          if (removeError) return jsonResponse({ error: 'Could not remove the account\'s files: ' + removeError.message }, 500);
          filesRemoved += paths.length;
        }
      }

      const { error: deleteError } = await admin.auth.admin.deleteUser(targetId);
      if (deleteError) return jsonResponse({ error: deleteError.message }, 500);

      return jsonResponse({ success: true, username: target.username, filesRemoved }, 200);
    }

    return jsonResponse({ error: 'Unknown action.' }, 400);
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
