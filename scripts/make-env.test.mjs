import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

// make-env.mjs takes the JWT secret and the keys over from a source .env, so that an existing
// server keeps its devices signed in. Published defaults, placeholders and weak values must
// never reach a server that way (security review 2026-11-01, F8).
const root = new URL('../', import.meta.url).pathname;
const parse = (text) => Object.fromEntries(text.split('\n').flatMap((line) => {
  const match = line.match(/^([A-Z_]+)='(.*)'$/);
  return match ? [[match[1], match[2]]] : [];
}));
const fingerprint = (value) => createHash('sha256').update(value).digest('hex').slice(0, 8);
const key = (prefix) => `${prefix}${randomBytes(16).toString('base64url')}`;

function generate(source) {
  const dir = mkdtempSync(join(tmpdir(), 'ww-make-env-'));
  try {
    const src = join(dir, 'src.env');
    writeFileSync(src, source);
    return spawnSync('node', ['infra/supabase/make-env.mjs', src,
      '--api', 'https://api.example.org', '--web', 'https://web.example.org'], { cwd: root, encoding: 'utf8' });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function refused(source, reason) {
  const result = generate(source);
  assert.equal(result.status, 2, `refused: ${source}`);
  assert.equal(result.stdout, '', 'no .env is printed');
  assert.match(result.stderr, reason);
}

test('the Supabase CLI defaults are refused', () => {
  refused('WW_JWT_SECRET=super-secret-jwt-token-with-at-least-32-characters-long\n', /published default/);
  refused('WW_SECRET_KEY=sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz\n', /WW_SECRET_KEY .*published default/);
  refused('WW_PUBLISHABLE_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH\n', /published default/);
  refused('WW_JWT_SECRET="your-super-secret-jwt-token-with-at-least-32-characters-long"\n', /published default/);
});

test('every key in supabase/.env.example is refused as it stands', () => {
  const example = readFileSync(join(root, 'supabase/.env.example'), 'utf8');
  const lines = example.split('\n').filter((l) => /^WW_(JWT_SECRET|PUBLISHABLE_KEY|SECRET_KEY)=/.test(l));
  assert.equal(lines.length, 3);
  for (const line of lines) refused(`${line}\n`, /placeholder|published default/);
  assert.doesNotMatch(example, /super-secret-jwt|sb_secret_N7UND0|sb_publishable_ACJW/, 'no working public secret in the example');
});

test('demo JWTs and any JWT in place of a key are refused', () => {
  refused('WW_SECRET_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU\n',
    /published default/);
  refused(`WW_JWT_SECRET=eyJhbGciOiJIUzI1NiJ9.${randomBytes(30).toString('base64url')}.${randomBytes(32).toString('base64url')}\n`, /is a JWT/);
});

test('short, uniform or placeholder secrets are refused', () => {
  refused(`WW_JWT_SECRET=${randomBytes(15).toString('hex')}\n`, /shorter than 32/);
  refused(`WW_JWT_SECRET=${'ab'.repeat(32)}\n`, /too few characters/);
  refused(`WW_JWT_SECRET=replace-me-${randomBytes(32).toString('hex')}\n`, /placeholder/);
  refused(`WW_CRON_SECRET=${randomBytes(8).toString('hex')}\n`, /WW_CRON_SECRET .*shorter than 32/);
  refused('WW_SECRET_KEY=sb_secret_short\n', /shorter than 22/);
  refused(`WW_SECRET_KEY=${key('sb_publishable_')}\n`, /must start with sb_secret_/);
  refused(`WW_PUBLISHABLE_KEY=${key('sb_secret_')}\n`, /must start with sb_publishable_/);
});

test('keys of the server itself are kept, each named with its fingerprint', () => {
  const kept = {
    WW_JWT_SECRET: randomBytes(32).toString('hex'),
    WW_PUBLISHABLE_KEY: key('sb_publishable_'),
    WW_SECRET_KEY: key('sb_secret_'),
    WW_CRON_SECRET: randomBytes(32).toString('hex'),
  };
  const result = generate(Object.entries(kept).map(([k, v]) => `${k}=${v}`).join('\n') + '\n');
  assert.equal(result.status, 0, result.stderr);
  const env = parse(result.stdout);
  assert.equal(env.JWT_SECRET, kept.WW_JWT_SECRET);
  assert.equal(env.SUPABASE_PUBLISHABLE_KEY, kept.WW_PUBLISHABLE_KEY);
  assert.equal(env.SUPABASE_SECRET_KEY, kept.WW_SECRET_KEY);
  assert.equal(env.CRON_SECRET, kept.WW_CRON_SECRET);
  for (const [name, value] of Object.entries(kept)) {
    assert.match(result.stderr, new RegExp(`kept ${name} from .* \\(sha256 ${fingerprint(value)}\\)`));
    assert.ok(!result.stderr.includes(value), `${name} itself is never printed to stderr`);
  }
});

test('without keys in the source nothing is kept and fresh ones are generated', () => {
  const result = generate('SMTP_HOST=smtp.example.org\n');
  assert.equal(result.status, 0, result.stderr);
  assert.doesNotMatch(result.stderr, /kept/);
  const env = parse(result.stdout);
  assert.match(env.JWT_SECRET, /^[0-9a-f]{64}$/);
  assert.match(env.SUPABASE_SECRET_KEY, /^sb_secret_[\w-]{22}$/);
});

test('the keys make-env.mjs generates pass its own checks when taken over', () => {
  const first = parse(generate('\n').stdout);
  const again = generate(`WW_JWT_SECRET=${first.JWT_SECRET}\nWW_PUBLISHABLE_KEY=${first.SUPABASE_PUBLISHABLE_KEY}\n` +
    `WW_SECRET_KEY=${first.SUPABASE_SECRET_KEY}\nWW_CRON_SECRET=${first.CRON_SECRET}\n`);
  assert.equal(again.status, 0, again.stderr);
  assert.equal(parse(again.stdout).JWT_SECRET, first.JWT_SECRET);
});
