// node --test scripts/hosted-retire-social.test.mjs
// A fake Management API stands in for a hosted project that had social sign-in configured
// before the upgrade. It shows what the script sends and checks; it is not the real API.
import assert from 'node:assert/strict';
import test from 'node:test';
import { authProblems, retire, RETIRED_AUTH } from './hosted-retire-social.mjs';

const TOKEN = 'sbp_test_token_not_real';

/** A project as it looked with Google and Apple on (the pre-removal deploy). */
function project({ applyPatch = true, deleteWorks = true, functions } = {}) {
  const state = {
    auth: {
      site_url: 'https://abcdefghijklmnopqrst.supabase.co',
      disable_signup: true,
      external_google_enabled: true,
      external_google_client_id: 'web-client.apps.googleusercontent.com',
      external_google_secret: 'google-secret',
      external_apple_enabled: true,
      external_apple_client_id: 'ch.goomba.wuselwall.signin,ch.goomba.wuselwall',
      external_apple_secret: 'apple-client-secret-jwt',
      security_manual_linking_enabled: true,
      uri_allow_list: 'ch.goomba.wuselwall://login-callback/',
    },
    functions: functions ?? ['account-delete', 'apple-token', 'server-info'],
    secrets: ['APPLE_TEAM_ID', 'APPLE_KEY_ID', 'APPLE_PRIVATE_KEY', 'APPLE_CLIENT_ID', 'APPLE_TOKEN_KEY', 'CRON_SECRET'],
  };
  const calls = [];
  const fetchFn = async (url, init) => {
    const path = url.replace('https://api.supabase.com/v1/projects/abcdefghijklmnopqrst/', '');
    calls.push({ method: init.method, path, body: init.body ? JSON.parse(init.body) : undefined });
    assert.equal(init.headers.Authorization, `Bearer ${TOKEN}`);
    const ok = (body) => new Response(body === undefined ? '' : JSON.stringify(body), { status: 200 });
    if (path === 'config/auth' && init.method === 'GET') return ok(state.auth);
    if (path === 'config/auth' && init.method === 'PATCH') {
      if (applyPatch) Object.assign(state.auth, JSON.parse(init.body));
      return ok(state.auth);
    }
    if (path === 'functions' && init.method === 'GET') return ok(state.functions.map((slug) => ({ slug })));
    if (path.startsWith('functions/') && init.method === 'DELETE') {
      if (!deleteWorks) return new Response('{}', { status: 500 });
      state.functions = state.functions.filter((s) => s !== path.slice('functions/'.length));
      return ok({});
    }
    return new Response('{}', { status: 404 });
  };
  return { state, calls, fetchFn };
}

test('an upgrade from enabled providers switches them off, clears the callback and removes apple-token', async () => {
  const p = project();
  const lines = [];
  const out = await retire({ project: 'abcdefghijklmnopqrst', token: TOKEN, fetchFn: p.fetchFn, log: (l) => lines.push(l) });

  assert.equal(p.state.auth.external_google_enabled, false);
  assert.equal(p.state.auth.external_apple_enabled, false);
  assert.equal(p.state.auth.security_manual_linking_enabled, false);
  assert.equal(p.state.auth.uri_allow_list, '');
  assert.equal(p.state.auth.external_apple_secret, '', 'the GoTrue Apple login client secret is cleared');
  assert.equal(p.state.auth.external_google_secret, '');
  assert.equal(p.state.auth.site_url, 'https://abcdefghijklmnopqrst.supabase.co', 'e-mail links keep their target');
  assert.deepEqual(p.state.functions, ['account-delete', 'server-info']);
  assert.deepEqual(out.deletedFunctions, ['apple-token']);
  assert.equal(out.switchedOff.length, 4);
  // The revocation secrets are never touched: no call goes to the secrets endpoint.
  assert.ok(!p.calls.some((c) => c.path.startsWith('secrets')));
  assert.equal(p.state.secrets.length, 6);
  // Removal is checked by reading back, not assumed from the DELETE.
  assert.deepEqual(p.calls.map((c) => `${c.method} ${c.path}`), [
    'GET config/auth', 'PATCH config/auth', 'GET config/auth',
    'GET functions', 'DELETE functions/apple-token', 'GET functions',
  ]);
  assert.deepEqual(p.calls[1].body, RETIRED_AUTH);
  // Nothing printed carries a setting value or the token.
  for (const l of lines) {
    assert.ok(!l.includes('secret-jwt') && !l.includes('google-secret') && !l.includes(TOKEN), l);
  }
});

test('a second run finds nothing left to do and still verifies', async () => {
  const p = project();
  await retire({ project: 'abcdefghijklmnopqrst', token: TOKEN, fetchFn: p.fetchFn, log: () => {} });
  const lines = [];
  const out = await retire({ project: 'abcdefghijklmnopqrst', token: TOKEN, fetchFn: p.fetchFn, log: (l) => lines.push(l) });
  assert.deepEqual(out, { switchedOff: [], deletedFunctions: [] });
  assert.ok(lines.includes('Edge Function apple-token: not deployed'));
});

test('a project that ignores the update fails the deploy', async () => {
  const p = project({ applyPatch: false });
  await assert.rejects(
    retire({ project: 'abcdefghijklmnopqrst', token: TOKEN, fetchFn: p.fetchFn, log: () => {} }),
    /Google sign-in is still enabled/,
  );
});

test('a failed function deletion fails the deploy', async () => {
  const p = project({ deleteWorks: false });
  await assert.rejects(
    retire({ project: 'abcdefghijklmnopqrst', token: TOKEN, fetchFn: p.fetchFn, log: () => {} }),
    /DELETE functions\/apple-token: HTTP 500/,
  );
});

test('authProblems names each leftover without its value', () => {
  assert.deepEqual(authProblems({ ...RETIRED_AUTH }), []);
  const problems = authProblems({ ...RETIRED_AUTH, external_apple_enabled: true, uri_allow_list: 'https://x/**,ch.goomba.wuselwall://login-callback/' });
  assert.deepEqual(problems, ['Apple sign-in is still enabled', 'the redirect allow-list still holds the native OAuth callback']);
  // A missing key is not proof of "off".
  assert.ok(authProblems({}).includes('Google sign-in is still enabled'));
});
