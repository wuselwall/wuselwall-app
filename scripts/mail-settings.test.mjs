import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

// Mail is optional (specs/20, Q48): make-env.mjs and mail-settings.sh autoconfirm addresses
// exactly when the server sends no mail.
const root = new URL('../', import.meta.url).pathname;
const parse = (text) => Object.fromEntries(text.split('\n').flatMap((line) => {
  const match = line.match(/^([A-Z_]+)='(.*)'$/);
  return match ? [[match[1], match[2]]] : [];
}));
const generate = (src, ...extra) => spawnSync('node', ['infra/supabase/make-env.mjs', ...(src ? [src] : []),
  '--api', 'https://api.example.org', '--web', 'https://web.example.org', ...extra], { cwd: root, encoding: 'utf8' });

function withDir(fn) {
  const dir = mkdtempSync(join(tmpdir(), 'ww-mail-settings-'));
  try { return fn(dir); } finally { rmSync(dir, { recursive: true, force: true }); }
}

const mailSettings = (file, action, env = {}) => spawnSync('sh', ['infra/supabase/mail-settings.sh', file, action],
  { cwd: root, encoding: 'utf8', env: { PATH: process.env.PATH, ...env } });

test('a new server without mail settings sends no mail and autoconfirms', () => {
  const result = generate();
  assert.equal(result.status, 0, result.stderr);
  const env = parse(result.stdout);
  assert.equal(env.ENABLE_EMAIL_AUTOCONFIRM, 'true');
  assert.equal(env.SMTP_HOST, '');
  assert.match(env.SMTP_PORT, /^\d+$/, 'Auth refuses to start with an empty port');
  assert.equal(env.SEND_EMAIL_HOOK_ENABLED, 'false');
  assert.equal(env.DISABLE_SIGNUP, 'false');
});

test('SMTP from the source settings is taken over and turns autoconfirm off', () => withDir((dir) => {
  const src = join(dir, 'src.env');
  writeFileSync(src, 'SMTP_HOST=smtp.gmail.com\nSMTP_PORT=587\nSMTP_USER=family@gmail.com\n' +
    'SMTP_PASS=abcd efgh ijkl mnop\nSMTP_SENDER=family@gmail.com\n');
  const result = generate(src);
  assert.equal(result.status, 0, result.stderr);
  const env = parse(result.stdout);
  assert.equal(env.ENABLE_EMAIL_AUTOCONFIRM, 'false');
  assert.equal(env.SMTP_HOST, 'smtp.gmail.com');
  assert.equal(env.SMTP_PORT, '587');
  assert.equal(env.SMTP_USER, 'family@gmail.com');
  assert.equal(env.SMTP_PASS, 'abcd efgh ijkl mnop');
  assert.equal(env.SMTP_ADMIN_EMAIL, 'family@gmail.com');
}));

test('the Scaleway hook counts as mail', () => withDir((dir) => {
  const src = join(dir, 'src.env');
  writeFileSync(src, 'SCW_SECRET_KEY=synthetic\nSCW_PROJECT_ID=synthetic\nMAIL_FROM=noreply@example.org\n');
  const env = parse(generate(src).stdout);
  assert.equal(env.SEND_EMAIL_HOOK_ENABLED, 'true');
  assert.equal(env.ENABLE_EMAIL_AUTOCONFIRM, 'false');
}));

test('a value that would break the quoted .env is refused', () => withDir((dir) => {
  const src = join(dir, 'src.env');
  writeFileSync(src, "SMTP_HOST=smtp.example.org\nSMTP_USER=u\nSMTP_PASS=it's\n");
  const result = generate(src);
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, '');
}));

const installedBefore = "# keep me\nJWT_SECRET='synthetic-do-not-rotate'\nSMTP_ADMIN_EMAIL='wuselwall@web.example.org'\n" +
  "SMTP_HOST='localhost'\nSMTP_PORT='25'\nSMTP_USER=''\nSMTP_PASS=''\nSMTP_SENDER_NAME='WuselWall'\n" +
  "SEND_EMAIL_HOOK_ENABLED='false'\nSEND_EMAIL_HOOK_URI=''\nENABLE_EMAIL_AUTOCONFIRM='false'\n";

test('status flags a server installed before mail was optional, and off repairs it', () => withDir((dir) => {
  const file = join(dir, 'stack.env');
  writeFileSync(file, installedBefore);
  chmodSync(file, 0o600);
  let result = mailSettings(file, 'status');
  assert.equal(result.status, 3);
  assert.match(result.stdout, /Mail: off/);
  assert.match(result.stdout, /nobody can sign up/);

  result = mailSettings(file, 'off');
  assert.equal(result.status, 0, result.stderr);
  const env = parse(readFileSync(file, 'utf8'));
  assert.equal(env.ENABLE_EMAIL_AUTOCONFIRM, 'true');
  assert.equal(env.SMTP_HOST, '');
  assert.equal(env.SMTP_PORT, '25');
  assert.equal(env.JWT_SECRET, 'synthetic-do-not-rotate');
  assert.match(readFileSync(file, 'utf8'), /^# keep me$/m);
  assert.equal(readFileSync(file, 'utf8').match(/^ENABLE_EMAIL_AUTOCONFIRM=/gm).length, 1);
  assert.equal(statSync(file).mode & 0o777, 0o600);
  assert.equal(mailSettings(file, 'status').status, 0);
}));

test('smtp writes the server, turns autoconfirm and the hook off, and keeps the password out of argv', () => withDir((dir) => {
  const file = join(dir, 'stack.env');
  writeFileSync(file, installedBefore.replace("SEND_EMAIL_HOOK_ENABLED='false'", "SEND_EMAIL_HOOK_ENABLED='true'"));
  const result = mailSettings(file, 'smtp', {
    SMTP_HOST: 'smtp.gmail.com', SMTP_USER: 'family@gmail.com', SMTP_PASS: 'abcd efgh ijkl mnop|$x',
  });
  assert.equal(result.status, 0, result.stderr);
  const env = parse(readFileSync(file, 'utf8'));
  assert.equal(env.SMTP_HOST, 'smtp.gmail.com');
  assert.equal(env.SMTP_PORT, '587', 'the submission port by default');
  assert.equal(env.SMTP_USER, 'family@gmail.com');
  assert.equal(env.SMTP_PASS, 'abcd efgh ijkl mnop|$x', 'the password is written verbatim');
  assert.equal(env.SMTP_ADMIN_EMAIL, 'family@gmail.com', 'the sender defaults to the account');
  assert.equal(env.SEND_EMAIL_HOOK_ENABLED, 'false');
  assert.equal(env.ENABLE_EMAIL_AUTOCONFIRM, 'false');
  assert.equal(env.JWT_SECRET, 'synthetic-do-not-rotate');
  const status = mailSettings(file, 'status');
  assert.equal(status.status, 0);
  assert.match(status.stdout, /SMTP smtp\.gmail\.com:587 as family@gmail\.com/);
  assert.doesNotMatch(status.stdout, /abcd/, 'status never prints the password');
}));

test('smtp refuses incomplete or unsafe values and leaves the file alone', () => withDir((dir) => {
  const file = join(dir, 'stack.env');
  writeFileSync(file, installedBefore);
  const ok = { SMTP_HOST: 'smtp.example.org', SMTP_USER: 'u@example.org', SMTP_PASS: 'secret' };
  for (const bad of [{ SMTP_HOST: '' }, { SMTP_HOST: 'localhost' }, { SMTP_HOST: 'smtp.example.org; rm -rf /' },
    { SMTP_PORT: 'abc' }, { SMTP_PASS: '' }, { SMTP_PASS: "it's" }, { SMTP_USER: '' },
    { SMTP_SENDER: 'not-an-address' }]) {
    const result = mailSettings(file, 'smtp', { ...ok, ...bad });
    assert.equal(result.status, 2, JSON.stringify(bad));
    assert.equal(readFileSync(file, 'utf8'), installedBefore, JSON.stringify(bad));
  }
}));

test('status flags mail configured while addresses are still autoconfirmed', () => withDir((dir) => {
  const file = join(dir, 'stack.env');
  writeFileSync(file, "SMTP_HOST='smtp.example.org'\nSMTP_PORT='587'\nENABLE_EMAIL_AUTOCONFIRM='true'\n");
  const result = mailSettings(file, 'status');
  assert.equal(result.status, 3);
  assert.match(result.stdout, /autoconfirmed/);
}));
