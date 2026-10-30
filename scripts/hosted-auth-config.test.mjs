// node --test scripts/hosted-auth-config.test.mjs
import assert from 'node:assert/strict';
import test from 'node:test';
import { authPatch, configureAuth, mailFromEnv, problems, SECRET_KEYS } from './hosted-auth-config.mjs';

const PROJECT = 'abcdefghijklmnopqrst';
const SMTP = { SMTP_HOST: 'smtp.example.org', SMTP_PORT: '587', SMTP_USER: 'u', SMTP_PASS: 'p', SMTP_SENDER: 'codes@example.org' };
const HOOK = { SEND_EMAIL_HOOK_SECRET: 'v1,whsec_c2VjcmV0c2VjcmV0c2VjcmV0c2VjcmV0' };

/** A Management API that stores what it is sent and echoes it, without the secret values. */
function api({ applies = true } = {}) {
  const state = { disable_signup: true, external_google_enabled: true };
  const calls = [];
  const fetchFn = async (url, init) => {
    calls.push({ method: init.method, body: init.body ? JSON.parse(init.body) : undefined });
    assert.equal(url, `https://api.supabase.com/v1/projects/${PROJECT}/config/auth`);
    assert.equal(init.headers.Authorization, 'Bearer sbp_test');
    if (init.method === 'PATCH' && applies) Object.assign(state, JSON.parse(init.body));
    const shown = { ...state };
    for (const key of SECRET_KEYS) delete shown[key];
    return new Response(JSON.stringify(shown), { status: 200 });
  };
  return { fetchFn, calls, state };
}

test('mail is optional; what is given must be complete', () => {
  assert.deepEqual(mailFromEnv({}), {});
  assert.throws(() => mailFromEnv({ SMTP_HOST: 'h' }), /SMTP_PORT is needed/);
  assert.throws(() => mailFromEnv({ ...SMTP, SMTP_PORT: 'x' }), /SMTP_PORT must be a number/);
  assert.throws(() => mailFromEnv({ SEND_EMAIL_HOOK_SECRET: 'whsec_x' }), /v1,whsec_/);
  assert.equal(mailFromEnv(SMTP).smtp.senderName, 'WuselWall');
  assert.equal(mailFromEnv({ ...SMTP, SMTP_SENDER_NAME: 'Familie' }).smtp.senderName, 'Familie');
  assert.ok(mailFromEnv(HOOK).hook);
  const both = mailFromEnv({ ...SMTP, ...HOOK });
  assert.ok(both.smtp && both.hook);
});

test('the patch turns sign-up on and mirrors the compose overlay', () => {
  const patch = authPatch({ project: PROJECT, mail: {} });
  assert.equal(patch.disable_signup, false);
  // No mail: addresses are autoconfirmed, so sign-up with a password works.
  assert.equal(patch.mailer_autoconfirm, true);
  assert.equal(patch.hook_custom_access_token_uri, 'pg-functions://postgres/app/custom_access_token_hook');
  // The claim gate (specs/20): the Before User Created hook, a Postgres function, no secret.
  assert.equal(patch.hook_before_user_created_enabled, true);
  assert.equal(patch.hook_before_user_created_uri, 'pg-functions://postgres/app/before_user_created_hook');
  assert.equal('hook_before_user_created_secrets' in patch, false);
  assert.equal(patch.password_min_length, 10);
  assert.equal(patch.rate_limit_otp, 30);
  assert.equal(patch.smtp_max_frequency, 60);
  assert.equal(patch.hook_send_email_enabled, false);
  assert.equal(patch.site_url, `https://${PROJECT}.supabase.co`);
  // Without a mail provider the built-in mailer's limit is left alone (the API refuses more).
  assert.equal('rate_limit_email_sent' in patch, false);
  assert.equal('smtp_host' in patch, false);
  assert.throws(() => authPatch({ project: 'short', mail: {} }), /20-letter/);
});

test('SMTP and the hook are configured as GoTrue expects', () => {
  const smtp = authPatch({ project: PROJECT, mail: mailFromEnv(SMTP) });
  assert.equal(smtp.smtp_host, 'smtp.example.org');
  assert.equal(smtp.smtp_port, '587');
  assert.equal(smtp.smtp_admin_email, 'codes@example.org');
  assert.equal(smtp.rate_limit_email_sent, 30);
  assert.equal(smtp.hook_send_email_enabled, false);
  assert.equal(smtp.mailer_autoconfirm, false, 'with mail, the code confirms the address');
  const hook = authPatch({ project: PROJECT, mail: mailFromEnv(HOOK) });
  assert.equal(hook.hook_send_email_enabled, true);
  assert.equal(hook.hook_send_email_uri, `https://${PROJECT}.supabase.co/functions/v1/send-email`);
  assert.equal(hook.hook_send_email_secrets, HOOK.SEND_EMAIL_HOOK_SECRET);
  assert.equal(hook.rate_limit_email_sent, 30);
  assert.equal(hook.mailer_autoconfirm, false);
});

test('readback ignores secrets the API does not echo and names what differs', () => {
  const patch = authPatch({ project: PROJECT, mail: mailFromEnv({ ...SMTP, ...HOOK }) });
  const echoed = { ...patch };
  for (const key of SECRET_KEYS) delete echoed[key];
  assert.deepEqual(problems(echoed, patch), []);
  assert.deepEqual(problems({ ...echoed, disable_signup: true, smtp_host: '' }, patch), ['disable_signup', 'smtp_host']);
});

test('configureAuth patches, reads back and logs names only', async () => {
  const { fetchFn, calls, state } = api();
  const lines = [];
  await configureAuth({ project: PROJECT, token: 'sbp_test', env: SMTP, fetchFn, log: (l) => lines.push(l) });
  assert.deepEqual(calls.map((c) => c.method), ['PATCH', 'GET']);
  assert.equal(state.disable_signup, false);
  assert.equal(state.external_google_enabled, true, 'keys it does not name stay as they were');
  assert.match(lines.join('\n'), /codes through SMTP/);
  assert.doesNotMatch(lines.join('\n'), /smtp\.example\.org|codes@|\bp\b/);
});

test('configureAuth fails when the API did not apply a setting', async () => {
  await assert.rejects(
    configureAuth({ project: PROJECT, token: 'sbp_test', env: SMTP, fetchFn: api({ applies: false }).fetchFn, log: () => {} }),
    /not applied: .*disable_signup/,
  );
  await assert.rejects(configureAuth({ project: '', token: 'sbp_test' }), /required/);
});

test('configureAuth without mail autoconfirms and says so', async () => {
  const { fetchFn, state } = api();
  const lines = [];
  await configureAuth({ project: PROJECT, token: 'sbp_test', env: {}, fetchFn, log: (l) => lines.push(l) });
  assert.equal(state.mailer_autoconfirm, true);
  assert.match(lines.join('\n'), /no mail: sign-in with email and password/);
});
