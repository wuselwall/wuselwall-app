import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

const root = new URL('../', import.meta.url).pathname;
const subjects = { de: 'Dein WuselWall-Code', en: 'Your WuselWall code', fr: 'Votre code WuselWall', es: 'Tu código de WuselWall' };
const parse = (text) => Object.fromEntries(text.split('\n').flatMap((line) => {
  const match = line.match(/^([A-Z_]+)='(.*)'$/);
  return match ? [[match[1], match[2]]] : [];
}));
const generate = (...extra) => spawnSync('node', ['infra/supabase/make-env.mjs', '--api', 'https://api.example.org', '--web', 'https://web.example.org', ...extra], { cwd: root, encoding: 'utf8' });

test('installation defaults server email language to German, not bilingual', () => {
  const result = generate();
  assert.equal(result.status, 0, result.stderr);
  const env = parse(result.stdout);
  assert.equal(env.MAIL_LANGUAGE, 'de');
  assert.equal(env.MAIL_CODE_SUBJECT, subjects.de);
});

for (const language of Object.keys(subjects)) {
  test(`installation persists ${language} email language and matching subject`, () => {
    const result = generate('--language', language);
    assert.equal(result.status, 0, result.stderr);
    const env = parse(result.stdout);
    assert.equal(env.MAIL_LANGUAGE, language);
    assert.equal(env.MAIL_CODE_SUBJECT, subjects[language]);
  });
}

test('unsupported installation email language fails before emitting configuration', () => {
  const result = generate('--language', 'it');
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /language.*de.*en.*fr.*es/);
});

for (const language of Object.keys(subjects)) {
  test(`operator can select ${language} without rotating credentials or duplicating settings`, () => {
    const dir = mkdtempSync(join(tmpdir(), 'ww-mail-language-'));
    try {
      const file = join(dir, 'stack.env');
      writeFileSync(file, "# preserve this\nJWT_SECRET='synthetic-do-not-rotate'\nMAIL_LANGUAGE='de'\nMAIL_CODE_SUBJECT='stale'\nSMTP_PASS='synthetic-password'\n");
      chmodSync(file, 0o600);
      const run = () => spawnSync('sh', ['infra/supabase/mail-language.sh', file, language], { cwd: root, encoding: 'utf8' });
      let result = run();
      assert.equal(result.status, 0, result.stderr);
      const first = readFileSync(file, 'utf8');
      assert.equal(parse(first).MAIL_LANGUAGE, language);
      assert.equal(parse(first).MAIL_CODE_SUBJECT, subjects[language]);
      assert.equal(parse(first).JWT_SECRET, 'synthetic-do-not-rotate');
      assert.equal(parse(first).SMTP_PASS, 'synthetic-password');
      assert.equal(first.match(/^MAIL_LANGUAGE=/gm).length, 1);
      assert.equal(statSync(file).mode & 0o777, 0o600);
      result = run();
      assert.equal(result.status, 0, result.stderr);
      assert.equal(readFileSync(file, 'utf8'), first);
    } finally { rmSync(dir, { recursive: true, force: true }); }
  });
}

test('updates preserve the selected language; legacy configuration defaults to German', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ww-mail-language-'));
  try {
    const file = join(dir, 'stack.env');
    for (const [initial, expected] of [["MAIL_LANGUAGE='fr'\n", 'fr'], ['', 'de']]) {
      writeFileSync(file, initial + "JWT_SECRET='synthetic-do-not-rotate'\n");
      const result = spawnSync('sh', ['infra/supabase/mail-language.sh', file], { cwd: root, encoding: 'utf8' });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(parse(readFileSync(file, 'utf8')).MAIL_LANGUAGE, expected);
    }
    const before = readFileSync(file, 'utf8');
    const result = spawnSync('sh', ['infra/supabase/mail-language.sh', file, 'it'], { cwd: root, encoding: 'utf8' });
    assert.notEqual(result.status, 0);
    assert.equal(readFileSync(file, 'utf8'), before);
    assert.doesNotMatch(result.stdout + result.stderr, /synthetic-do-not-rotate/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
