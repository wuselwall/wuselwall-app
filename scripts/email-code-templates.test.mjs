import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import test from 'node:test';

const root = resolve(import.meta.dirname, '..');
const read = (path) => readFileSync(resolve(root, path), 'utf8');

test('release archive includes the exact canonical OTP templates', () => {
  const archive = resolve(root, 'dist/wuselwall-server-0.0.987.tar.gz');
  try {
    execFileSync('bash', ['scripts/build-server-release.sh', '0.0.987', '--skip-web'], { cwd: root });
    for (const file of ['confirmation', 'magic_link']) {
      const packaged = execFileSync('tar', ['-xOzf', archive,
        `wuselwall/stack/volumes/mail-templates/${file}.html`], { encoding: 'utf8' });
      assert.equal(packaged, read(`supabase/templates/${file}.html`));
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
      '--api', 'https://api.example.org', '--web', 'https://app.example.org'], { cwd: root }));
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
  for (const [kind, file] of [['CONFIRMATION', 'confirmation'], ['MAGIC_LINK', 'magic_link']]) {
    assert.equal(auth.environment[`GOTRUE_MAILER_TEMPLATES_${kind}`], `http://mail-templates/${file}.html`);
    assert.equal(auth.environment[`GOTRUE_MAILER_SUBJECTS_${kind}`], 'Dein WuselWall-Code / Your WuselWall code');
    const html = read(`supabase/templates/${file}.html`);
    assert.match(html, /{{\s*\.Token\s*}}/);
    assert.doesNotMatch(html, /ConfirmationURL|TokenHash|href\s*=/i);
    assert.match(html, /Code/);
    assert.match(html, /code/);
  }
  const host = config.services['mail-templates'];
  assert.ok(host, 'template host is included even without Caddy or Studio');
  assert.equal(host.ports?.length ?? 0, 0, 'templates need no public port');
  assert.ok(host.volumes.some((v) => v.target === '/usr/share/nginx/html' && v.read_only));
  assert.equal(auth.depends_on['mail-templates'].condition, 'service_healthy');
});
