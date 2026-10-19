import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import test from 'node:test';

const root = resolve(import.meta.dirname, '..');
const read = (path) => readFileSync(resolve(root, path), 'utf8');

const MAIL_KINDS = ['confirmation', 'magic_link', 'recovery', 'email_change', 'reauthentication', 'invite'];
const MAIL_LOCALES = ['de', 'en', 'fr', 'es'];

test('all canonical SMTP template languages and kinds are committed', () => {
  for (const file of MAIL_KINDS) {
    const rootFile = `supabase/templates/${file}.html`;
    assert.ok(existsSync(resolve(root, rootFile)), `missing German root ${file}`);
    assert.equal(read(rootFile), read(`supabase/templates/de/${file}.html`));
    for (const language of MAIL_LOCALES) {
      const localized = read(`supabase/templates/${language}/${file}.html`);
      assert.match(localized, /{{\s*\.Token\s*}}/);
      assert.doesNotMatch(localized, /ConfirmationURL|TokenHash|href\s*=/i);
      assert.match(localized, new RegExp(`<html lang="${language}">`, 'i'));
    }
  }
});

test('release archive includes every language and kind the selected server needs', () => {
  const archive = resolve(root, 'dist/wuselwall-server-0.0.987.tar.gz');
  try {
    execFileSync('bash', ['scripts/build-server-release.sh', '0.0.987', '--skip-web'], { cwd: root });
    for (const language of MAIL_LOCALES) {
      for (const file of MAIL_KINDS) {
        const packaged = execFileSync('tar', ['-xOzf', archive,
          `wuselwall/stack/volumes/mail-templates/${language}/${file}.html`], { encoding: 'utf8' });
        assert.equal(packaged, read(`supabase/templates/${language}/${file}.html`));
      }
    }
  } finally {
    rmSync(archive, { force: true });
  }
});

test('checkout deployment copies the canonical templates before starting Auth', () => {
  const script = read('scripts/remote-stack.sh');
  assert.match(script, /supabase\/templates\/.*\$HOST:\$DIR\/volumes\/mail-templates\//);
  assert.ok(script.indexOf('supabase/templates/') < script.indexOf('docker compose up -d'));
});

// Exercise Compose interpolation without reading any operator .env or starting services.
function compose() {
  const dir = mkdtempSync(`${process.env.TMPDIR || tmpdir()}/ww-mail-test-`);
  try {
    writeFileSync(`${dir}/env`, execFileSync('node', ['infra/supabase/make-env.mjs',
      '--api', 'https://api.example.org', '--web', 'https://app.example.org', '--language', 'fr'], { cwd: root }));
    return JSON.parse(execFileSync('docker', ['compose', '--env-file', `${dir}/env`,
      '-f', 'infra/supabase/docker-compose.yml', '-f', 'infra/supabase/docker-compose.wuselwall.yml',
      '-f', 'infra/supabase/docker-compose.lean.yml', 'config', '--format', 'json'], { cwd: root }));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('SMTP fallback serves signup and returning sign-in codes on an internal-only template host', () => {
  const config = compose();
  const auth = config.services.auth;
  assert.equal(auth.environment.GOTRUE_HOOK_SEND_EMAIL_ENABLED, 'false');
  for (const kind of ['CONFIRMATION', 'MAGIC_LINK', 'RECOVERY', 'EMAIL_CHANGE', 'REAUTHENTICATION', 'INVITE']) {
    const file = kind.toLowerCase();
    assert.equal(auth.environment[`GOTRUE_MAILER_TEMPLATES_${kind}`], `http://mail-templates/fr/${file}.html`);
    assert.equal(auth.environment[`GOTRUE_MAILER_SUBJECTS_${kind}`], 'Votre code WuselWall');
    const html = read(`supabase/templates/fr/${file}.html`);
    assert.match(html, /{{\s*\.Token\s*}}/);
    assert.doesNotMatch(html, /ConfirmationURL|TokenHash|href\s*=/i);
    assert.match(html, /code/i);
  }
  const host = config.services['mail-templates'];
  assert.ok(host, 'template host is included even without Caddy or Studio');
  assert.equal(host.ports?.length ?? 0, 0, 'templates need no public port');
  assert.ok(host.volumes.some((v) => v.target === '/usr/share/nginx/html' && v.read_only));
  assert.equal(auth.depends_on['mail-templates'].condition, 'service_healthy');
});

test('legacy German configuration remains valid for stacks without MAIL_LANGUAGE', () => {
  const dir = mkdtempSync(`${process.env.TMPDIR || tmpdir()}/ww-mail-test-`);
  try {
    writeFileSync(`${dir}/env`, execFileSync('node', ['infra/supabase/make-env.mjs',
      '--api', 'https://api.example.org', '--web', 'https://app.example.org'], { cwd: root, encoding: 'utf8' }).replace(/^MAIL_LANGUAGE=.*$/m, ''));
    const config = JSON.parse(execFileSync('docker', ['compose', '--env-file', `${dir}/env`,
      '-f', 'infra/supabase/docker-compose.yml', '-f', 'infra/supabase/docker-compose.wuselwall.yml',
      '-f', 'infra/supabase/docker-compose.lean.yml', 'config', '--format', 'json'], { cwd: root }));
    assert.equal(config.services.auth.environment.GOTRUE_MAILER_TEMPLATES_CONFIRMATION, 'http://mail-templates/de/confirmation.html');
    assert.equal(config.services.functions.environment.MAIL_LANGUAGE, 'de');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
