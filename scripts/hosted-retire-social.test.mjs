// node --test scripts/hosted-retire-social.test.mjs
// A fake Management API stands in for a hosted project that had social sign-in configured
// before the upgrade. It shows what the script sends and checks; it is not the real API.
import assert from 'node:assert/strict';
import test from 'node:test';
import { authProblems, retainedRedirects, retire, RETIRED_AUTH, retirementPatch } from './hosted-retire-social.mjs';

const TOKEN = 'sbp_test_token_not_real';

/** A project as it looked with Google and Apple on (the pre-removal deploy). */
function project({ applyPatch = true, deleteWorks = true, functions, uriAllowList, dropsList = false, secretsDeleteWorks = true } = {}) {
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
      uri_allow_list: uriAllowList ?? 'ch.goomba.wuselwall://login-callback/',
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
      // A misbehaving API that empties the list whatever it was sent.
      if (dropsList) state.auth.uri_allow_list = '';
      return ok(state.auth);
    }
    if (path === 'functions' && init.method === 'GET') return ok(state.functions.map((slug) => ({ slug })));
    if (path === 'secrets' && init.method === 'GET') return ok(state.secrets.map((name) => ({ name, value: 'digest' })));
    if (path === 'secrets' && init.method === 'DELETE') {
      if (secretsDeleteWorks) state.secrets = state.secrets.filter((n) => !JSON.parse(init.body).includes(n));
      return ok({});
    }
    if (path.startsWith('functions/') && init.method === 'DELETE') {
      if (!deleteWorks) return new Response('{}', { status: 500 });
      state.functions = state.functions.filter((s) => s !== path.slice('functions/'.length));
      return ok({});
    }
    return new Response('{}', { status: 404 });
  };
  return { state, calls, fetchFn };
}

test('an upgrade from enabled providers switches them off, clears the callback, removes apple-token and the Apple secrets', async () => {
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
  // Only the Apple values go; any other secret stays.
  assert.deepEqual(p.state.secrets, ['CRON_SECRET']);
  assert.deepEqual(out.deletedSecrets, ['APPLE_TEAM_ID', 'APPLE_KEY_ID', 'APPLE_PRIVATE_KEY', 'APPLE_CLIENT_ID', 'APPLE_TOKEN_KEY']);
  assert.deepEqual(p.calls.find((c) => c.method === 'DELETE' && c.path === 'secrets').body, out.deletedSecrets);
  // Removal is checked by reading back, not assumed from the DELETE.
  assert.deepEqual(p.calls.map((c) => `${c.method} ${c.path}`), [
    'GET config/auth', 'PATCH config/auth', 'GET config/auth',
    'GET functions', 'DELETE functions/apple-token', 'GET functions',
    'GET secrets', 'DELETE secrets', 'GET secrets',
  ]);
  assert.deepEqual(p.calls[1].body, { ...RETIRED_AUTH, uri_allow_list: '' });
  // Nothing printed carries a setting value or the token.
  for (const l of lines) {
    assert.ok(!l.includes('secret-jwt') && !l.includes('google-secret') && !l.includes('digest') && !l.includes(TOKEN), l);
  }
});

test('a second run finds nothing left to do and still verifies', async () => {
  const p = project();
  await retire({ project: 'abcdefghijklmnopqrst', token: TOKEN, fetchFn: p.fetchFn, log: () => {} });
  const lines = [];
  const out = await retire({ project: 'abcdefghijklmnopqrst', token: TOKEN, fetchFn: p.fetchFn, log: (l) => lines.push(l) });
  assert.deepEqual(out, { switchedOff: [], keptRedirects: 0, deletedFunctions: [], deletedSecrets: [] });
  assert.ok(lines.includes('Edge Function apple-token: not deployed'));
  assert.ok(lines.includes('Edge Function secrets: no Apple values set'));
  assert.ok(!p.calls.slice(9).some((c) => c.method === 'DELETE'), 'nothing deleted twice');
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

test('a secret deletion that does not stick fails the deploy', async () => {
  const p = project({ secretsDeleteWorks: false });
  await assert.rejects(
    retire({ project: 'abcdefghijklmnopqrst', token: TOKEN, fetchFn: p.fetchFn, log: () => {} }),
    /secrets still set: APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, APPLE_CLIENT_ID, APPLE_TOKEN_KEY/,
  );
});

test('authProblems names each leftover without its value', () => {
  assert.deepEqual(authProblems({ ...RETIRED_AUTH }), []);
  const problems = authProblems({ ...RETIRED_AUTH, external_apple_enabled: true, uri_allow_list: 'https://x/**,ch.goomba.wuselwall://login-callback/' });
  assert.deepEqual(problems, ['Apple sign-in is still enabled', 'the redirect allow-list still holds the native OAuth callback']);
  // A missing key is not proof of "off".
  assert.ok(authProblems({}).includes('Google sign-in is still enabled'));
});

// Only the obsolete OAuth callback goes; invitation, pairing and any other destination an
// operator added stays, in its order.
const MIXED = [
  'https://example.org/invite/**',
  'ch.goomba.wuselwall://login-callback/',
  'https://example.org/pair/**',
  ' https://family.example.org/** ',
  'ch.goomba.wuselwall.dev://login-callback',
  'https://example.org/docs/login-callback-help',
].join(',');
const MIXED_KEPT = [
  'https://example.org/invite/**',
  'https://example.org/pair/**',
  'https://family.example.org/**',
  'https://example.org/docs/login-callback-help',
];

test('a mixed allow-list keeps invitation, pairing and other entries and loses only the callback', async () => {
  const p = project({ uriAllowList: MIXED });
  const lines = [];
  const out = await retire({ project: 'abcdefghijklmnopqrst', token: TOKEN, fetchFn: p.fetchFn, log: (l) => lines.push(l) });
  assert.equal(p.calls[1].body.uri_allow_list, MIXED_KEPT.join(','));
  assert.equal(p.state.auth.uri_allow_list, MIXED_KEPT.join(','), 'read back from the project');
  assert.equal(out.keptRedirects, 4);
  assert.ok(lines.includes('Auth: 4 other redirect allow-list entries kept'));
  // Check the complete output: no setting value, on any host, may be printed.
  assert.deepEqual(lines, [
    'Auth: switched off (Google sign-in is still enabled; Apple sign-in is still enabled; manual identity linking is still enabled; the redirect allow-list still holds the native OAuth callback)',
    'Auth: 4 other redirect allow-list entries kept',
    'Edge Function apple-token: deleted',
    'Edge Function secrets deleted: APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, APPLE_CLIENT_ID, APPLE_TOKEN_KEY',
  ]);
});

test('a mixed list is idempotent: the second run sends no allow-list and changes nothing', async () => {
  const p = project({ uriAllowList: MIXED });
  await retire({ project: 'abcdefghijklmnopqrst', token: TOKEN, fetchFn: p.fetchFn, log: () => {} });
  const firstCalls = p.calls.length;
  const out = await retire({ project: 'abcdefghijklmnopqrst', token: TOKEN, fetchFn: p.fetchFn, log: () => {} });
  const patch = p.calls.slice(firstCalls).find((c) => c.method === 'PATCH');
  assert.ok(!('uri_allow_list' in patch.body), 'a list without the callback is not rewritten');
  assert.equal(p.state.auth.uri_allow_list, MIXED_KEPT.join(','));
  assert.deepEqual(out, { switchedOff: [], keptRedirects: 4, deletedFunctions: [], deletedSecrets: [] });
});

test('a project without the callback keeps its allow-list untouched', async () => {
  const list = 'https://example.org/invite/**,https://example.org/pair/**';
  const p = project({ uriAllowList: list });
  await retire({ project: 'abcdefghijklmnopqrst', token: TOKEN, fetchFn: p.fetchFn, log: () => {} });
  assert.ok(!('uri_allow_list' in p.calls[1].body));
  assert.equal(p.state.auth.uri_allow_list, list);
});

test('a read-back that lost a retained entry fails the deploy', async () => {
  const p = project({ uriAllowList: MIXED, dropsList: true });
  await assert.rejects(
    retire({ project: 'abcdefghijklmnopqrst', token: TOKEN, fetchFn: p.fetchFn, log: () => {} }),
    /4 redirect allow-list entries to keep went missing/,
  );
});

test('retainedRedirects and retirementPatch', () => {
  assert.deepEqual(retainedRedirects(MIXED), MIXED_KEPT);
  assert.deepEqual(retainedRedirects(''), []);
  assert.deepEqual(retainedRedirects(undefined), []);
  assert.deepEqual(retirementPatch({ uri_allow_list: 'ch.goomba.wuselwall://login-callback/' }),
    { ...RETIRED_AUTH, uri_allow_list: '' });
  assert.deepEqual(retirementPatch({}), { ...RETIRED_AUTH });
});
