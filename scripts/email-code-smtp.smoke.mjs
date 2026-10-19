#!/usr/bin/env node
// Disposable SMTP smoke test. No ports published, no operator configuration read,
// no household stack touched. Requires Docker; all named resources removed in finally.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';

const prefix = `ww-mail-smoke-${randomBytes(5).toString('hex')}`;
const names = ['db', 'mailpit', 'templates', 'auth'].map((n) => `${prefix}-${n}`);
const [db, mailpit, templates, auth] = names;
const docker = (...args) => execFileSync('docker', args, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
const delay = () => new Promise((r) => setTimeout(r, 500));
const images = ['postgres:15-alpine', 'public.ecr.aws/supabase/mailpit:v1.31.3',
  'nginx:1.28.0-alpine', 'ghcr.io/supabase/gotrue:v2.197.0'];
// Shared CI egress can briefly hit anonymous registry limits. Retry only those.
async function pull(image) {
  for (let attempt = 1; ; attempt++) {
    try { docker('pull', '--quiet', image); return; } catch (error) {
      const limited = /toomanyrequests|rate limit|data limit exceeded/i.test(String(error.stderr ?? error.message));
      if (!limited || attempt === 4) throw error;
      console.warn(`Registry limit while pulling ${image}; retrying (${attempt}/3)`);
      await new Promise((r) => setTimeout(r, attempt * 15000));
    }
  }
}
async function until(fn) {
  let error;
  for (let n = 0; n < 120; n++) {
    try { return fn(); } catch (e) { error = e; await delay(); }
  }
  throw error;
}
function request(host, path, body) {
  const args = ['exec', templates, 'wget', '-qO-', '--header=Content-Type: application/json'];
  if (body) args.push(`--post-data=${JSON.stringify(body)}`);
  return JSON.parse(docker(...args, `http://${host}${path}`));
}
try {
  for (const image of images) await pull(image);
  docker('network', 'create', prefix);
  docker('run', '-d', '--name', db, '--network', prefix, '--network-alias', 'db',
    '-e', 'POSTGRES_PASSWORD=throwaway-mail-test', 'postgres:15-alpine');
  await until(() => docker('exec', db, 'pg_isready', '-U', 'postgres'));
  // The image briefly runs a bootstrap postmaster before its final start.
  await until(() => docker('exec', db, 'psql', '-h', '127.0.0.1', '-U', 'postgres',
    '-c', 'create schema if not exists auth;'));
  docker('run', '-d', '--name', mailpit, '--network', prefix, '--network-alias', 'mailpit',
    'public.ecr.aws/supabase/mailpit:v1.31.3');
  docker('run', '-d', '--name', templates, '--network', prefix, '--network-alias', 'mail-templates',
    'nginx:1.28.0-alpine');
  for (const kind of ['confirmation', 'magic_link']) {
    docker('cp', new URL(`../supabase/templates/${kind}.html`, import.meta.url).pathname,
      `${templates}:/usr/share/nginx/html/${kind}.html`);
  }
  const env = {
    GOTRUE_API_HOST: '0.0.0.0', PORT: '9999', API_EXTERNAL_URL: 'http://auth:9999',
    GOTRUE_SITE_URL: 'https://app.example.org/', GOTRUE_DB_DRIVER: 'postgres',
    GOTRUE_DB_DATABASE_URL: 'postgres://postgres:throwaway-mail-test@db:5432/postgres?search_path=auth',
    GOTRUE_JWT_SECRET: randomBytes(32).toString('hex'), GOTRUE_SMTP_HOST: 'mailpit',
    GOTRUE_SMTP_PORT: '1025', GOTRUE_SMTP_ADMIN_EMAIL: 'noreply@example.org',
    GOTRUE_SMTP_SENDER_NAME: 'WuselWall', GOTRUE_SMTP_MAX_FREQUENCY: '0s',
    GOTRUE_DISABLE_SIGNUP: 'false', GOTRUE_EXTERNAL_EMAIL_ENABLED: 'true',
    GOTRUE_MAILER_AUTOCONFIRM: 'false', GOTRUE_MAILER_OTP_LENGTH: '6', GOTRUE_MAILER_OTP_EXP: '600',
    GOTRUE_HOOK_SEND_EMAIL_ENABLED: 'false',
    GOTRUE_MAILER_TEMPLATES_CONFIRMATION: 'http://mail-templates/confirmation.html',
    GOTRUE_MAILER_TEMPLATES_MAGIC_LINK: 'http://mail-templates/magic_link.html',
    GOTRUE_MAILER_SUBJECTS_CONFIRMATION: 'Dein WuselWall-Code / Your WuselWall code',
    GOTRUE_MAILER_SUBJECTS_MAGIC_LINK: 'Dein WuselWall-Code / Your WuselWall code',
  };
  // Keep smoke settings aligned with the shipped Compose mail configuration.
  const compose = readFileSync(new URL('../infra/supabase/docker-compose.wuselwall.yml', import.meta.url), 'utf8');
  for (const key of Object.keys(env).filter((k) => /MAILER_(TEMPLATES|SUBJECTS)/.test(k))) {
    assert.ok(compose.includes(`${key}: ${env[key]}`));
  }
  docker('run', '-d', '--name', auth, '--network', prefix, '--network-alias', 'auth',
    ...Object.entries(env).flatMap(([k, v]) => ['-e', `${k}=${v}`]), 'ghcr.io/supabase/gotrue:v2.197.0');
  await until(() => request('auth:9999', '/health'));
  const email = 'otp-smoke@example.org';
  for (const [index, marker] of ['Welcome to WuselWall!', 'Here is your code to sign in'].entries()) {
    request('auth:9999', '/otp', { email, create_user: true });
    const message = await until(() => {
      const messages = request('mailpit:8025', '/api/v1/messages');
      assert.equal(messages.total, index + 1);
      return request('mailpit:8025', `/api/v1/message/${messages.messages[0].ID}`);
    });
    assert.equal(message.Subject, 'Dein WuselWall-Code / Your WuselWall code');
    assert.ok(message.Text.includes(marker), `wrong mail kind for ${index === 0 ? 'signup' : 'sign-in'}`);
    assert.doesNotMatch(message.HTML, /href\s*=|ConfirmationURL|{{/i);
    const code = message.Text.match(/\b\d{6}\b/)?.[0];
    assert.ok(code, 'SMTP message must contain a six-digit code');
    const verified = request('auth:9999', '/verify', { email, token: code, type: 'email' });
    assert.ok(verified.access_token, 'the mailed code must establish a session');
    console.log(`${index === 0 ? 'Signup confirmation' : 'Returning email sign-in'}: bilingual SMTP code received and verified`);
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  for (const name of [...names].reverse()) {
    try { docker('rm', '-fv', name); } catch { /* not created */ }
  }
  try { docker('network', 'rm', prefix); } catch { /* not created */ }
}
