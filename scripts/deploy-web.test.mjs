// Execute deploy-web with disposable build/SSH fixtures, never operator configuration.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

const script = readFileSync(new URL('./deploy-web.sh', import.meta.url), 'utf8');
test('checkout web deployment discovers its backend, without developer backend settings', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ww-web-deploy-'));
  try {
    for (const path of ['scripts', 'app/env', 'home/flutter/bin', 'bin']) mkdirSync(join(dir, path), { recursive: true });
    writeFileSync(join(dir, 'scripts/deploy-web.sh'), script);
    // Stale developer configuration exists but must never be a publish input.
    writeFileSync(join(dir, 'app/env/dev.json'), JSON.stringify({ SUPABASE_URL: 'https://stale.example.org', SUPABASE_PUBLISHABLE_KEY: 'stale-public-key' }));
    writeFileSync(join(dir, 'scripts/remote.env'), 'WW_HOST=deploy@example.org\nWW_WEB_DIR=/srv/example/web\n');
    const executable = (path, body) => {
      writeFileSync(join(dir, path), `#!/usr/bin/env bash\nset -eu\n${body}\n`);
      chmodSync(join(dir, path), 0o755);
    };
    executable('home/flutter/bin/flutter', `printf '%s\\n' "$@" > "$BUILD_ARGS"
mkdir -p build/web-live
printf 'backend-neutral web build' > build/web-live/index.html`);
    executable('bin/ssh', 'printf "%s\\n" "$@" > "$SSH_ARGS"; cat > "$UPLOAD"');
    const result = spawnSync('bash', ['scripts/deploy-web.sh'], {
      cwd: dir, encoding: 'utf8', env: { ...process.env, HOME: join(dir, 'home'), PATH: `${join(dir, 'bin')}:${process.env.PATH}`,
        BUILD_ARGS: join(dir, 'build-args'), SSH_ARGS: join(dir, 'ssh-args'), UPLOAD: join(dir, 'upload.tar.gz') },
    });
    assert.equal(result.status, 0, result.stderr);
    const args = readFileSync(join(dir, 'build-args'), 'utf8');
    assert.doesNotMatch(args, /dart-define-from-file|SUPABASE_URL|SUPABASE_PUBLISHABLE_KEY|env\/dev/);
    assert.match(args, /--dart-define=ENV=release/);
    assert.match(args, /--no-web-resources-cdn/);
    const archive = spawnSync('tar', ['-xOzf', join(dir, 'upload.tar.gz'), './index.html'], { encoding: 'utf8' });
    assert.equal(archive.status, 0, archive.stderr);
    assert.equal(archive.stdout, 'backend-neutral web build');
    assert.match(readFileSync(join(dir, 'ssh-args'), 'utf8'), /deploy@example.org/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('server release also builds the same backend-neutral web app', () => {
  const release = readFileSync(new URL('./build-server-release.sh', import.meta.url), 'utf8');
  assert.match(release, /--dart-define=ENV=release/);
  assert.doesNotMatch(release, /dart-define-from-file|SUPABASE_URL=/);
});
