// server/cloud-init.yaml installs a WuselWall server on a rented VPS at its first boot
// (docs/server/home-server). No third-party dependencies, so the checks are textual.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const file = readFileSync(new URL('../server/cloud-init.yaml', import.meta.url), 'utf8');

test('it is a cloud-config with one line to change', () => {
  assert.ok(file.startsWith('#cloud-config\n'));
  const change = [...file.matchAll(/^  # CHANGE .*\n  - \[sh, -c, "(.+)"\]$/gm)];
  assert.equal(change.length, 1, 'exactly one line is marked CHANGE');
  const [, command] = change[0];
  for (const name of ['WW_VERSION=1.0.0', 'WW_API=https://api.example.org', 'WW_WEB=https://web.example.org', 'WW_LANGUAGE=de']) {
    assert.ok(command.includes(name), name);
  }
  assert.ok(command.endsWith(' /usr/local/sbin/wuselwall-first-boot'));
});

test('the first-boot script installs the release the same way the docs do', () => {
  const script = file.split('    content: |\n')[1].split('\nruncmd:')[0];
  assert.match(script, /^      #!\/bin\/sh$/m);
  assert.match(script, /set -eu/);
  // The release archive server/wuselwall itself updates from.
  assert.match(script, /releases\/download\/server-v\$WW_VERSION\/wuselwall-server-\$WW_VERSION\.tar\.gz/);
  assert.match(script, /\.\/wuselwall install --api "\$WW_API" --web "\$WW_WEB" --language "\$WW_LANGUAGE" --caddy > install\.log 2>&1/);
  assert.match(script, /umask 077/, 'the log with the setup code is root-only');
  assert.match(script, /ufw allow OpenSSH/);
  assert.match(script, /ufw --force enable/);
});

test('Docker comes from its signed repository, not from a script piped into a shell', () => {
  assert.match(file, /download\.docker\.com\/linux\/ubuntu \$RELEASE stable/);
  assert.match(file, /keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88/);
  assert.doesNotMatch(file, /get\.docker\.com/);
  assert.doesNotMatch(file, /\| *sh\b(?!.*wuselwall-first-boot)/m);
  for (const pkg of ['docker-ce', 'docker-compose-plugin', 'containerd.io']) assert.match(file, new RegExp(`^  - ${pkg.replace('.', '\\.')}$`, 'm'));
});

test('no operator server, only example addresses', () => {
  assert.doesNotMatch(file, /goomba|unraid|\b\d{1,3}(\.\d{1,3}){3}\b/);
  assert.match(file, /example\.org/);
});
