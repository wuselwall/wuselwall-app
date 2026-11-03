// server/cloud-init.yaml installs a WuselWall server on a rented VPS at its first boot
// (docs/server/home-server). No third-party dependencies, so the checks are textual.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash, generateKeyPairSync, randomBytes, sign } from 'node:crypto';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

const root = new URL('../', import.meta.url).pathname;
const file = readFileSync(join(root, 'server/cloud-init.yaml'), 'utf8');
const script = file.split('    content: |\n')[1].split('\nruncmd:')[0];
// The release key server/wuselwall trusts; everything that checks a release by hand or at
// the first boot must name the same one (security review 2026-11-01, F9).
const releaseKey = readFileSync(join(root, 'server/wuselwall'), 'utf8')
  .match(/^WW_RELEASE_PUBKEY=\$\{WW_RELEASE_PUBKEY:-(.+)\}$/m)[1];
const which = (cmd) => spawnSync('sh', ['-c', `command -v ${cmd}`], { encoding: 'utf8' }).stdout.trim();
const minisign = process.env.MINISIGN || which('minisign');

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
  assert.match(script, /^      #!\/bin\/sh$/m);
  assert.match(script, /set -eu/);
  // The release archive server/wuselwall itself updates from, with its checksums and signature.
  assert.match(script, /^      archive=wuselwall-server-\$WW_VERSION\.tar\.gz$/m);
  assert.match(script, /^      base=https:\/\/github\.com\/wuselwall\/wuselwall-app\/releases\/download\/server-v\$WW_VERSION$/m);
  assert.match(script, /for f in "\$archive" SHA256SUMS SHA256SUMS\.minisig; do curl -fsSLO "\$base\/\$f"; done/);
  assert.match(script, /\.\/wuselwall install --api "\$WW_API" --web "\$WW_WEB" --language "\$WW_LANGUAGE" --caddy; \} > install\.log 2>&1/);
  assert.match(script, /umask 077/, 'the log with the setup code is root-only');
  assert.match(script, /ufw allow OpenSSH/);
  assert.match(script, /ufw --force enable/);
});

test('the release is checked before it is unpacked, never piped into tar', () => {
  assert.doesNotMatch(script, /\|\s*tar\b/);
  const order = ['minisign -V -Q -m SHA256SUMS -P "$key"', 'sha256sum -c -', 'tar -xzf "$archive"', './wuselwall install'];
  const at = order.map((step) => script.indexOf(step));
  assert.ok(at.every((i) => i >= 0), `every step is there: ${at}`);
  assert.deepEqual([...at].sort((a, b) => a - b), at, 'signature, checksum, unpack, install: in this order');
  assert.ok(script.includes('[ "$comment" = "wuselwall-server $WW_VERSION SHA256SUMS" ]'), 'the signed comment names the release');
  assert.ok(script.includes('base64 -d | head -c 2)" = ED ]'), 'only prehashed signatures');
  assert.match(file, /^  - minisign$/m, 'minisign comes from Ubuntu');
});

test('cloud-init, the docs and server/wuselwall trust the same release key', () => {
  assert.equal(script.match(/^      key=(.+)$/m)?.[1], releaseKey);
  for (const lang of ['', 'en/', 'fr/', 'es/']) {
    const page = readFileSync(join(root, `docs/${lang}server/rented-server.md`), 'utf8');
    const keys = [...page.matchAll(/-P (\S+)/g)].map((m) => m[1]);
    assert.ok(keys.length > 0, `docs/${lang}server/rented-server.md shows how to check a download`);
    for (const key of keys) assert.equal(key, releaseKey, `docs/${lang}server/rented-server.md`);
  }
});

// The first-boot script's download and check, run against a local copy of a release
// (file:// instead of GitHub), up to the unpacking.
function firstBootCheck(dir, key, path = process.env.PATH) {
  const check = script.split('\n').map((l) => l.slice(6))
    .join('\n').split('\nkey=')[1].split('\nmkdir -p /srv')[0];
  return spawnSync('sh', ['-c', `set -eu\nWW_VERSION=9.8.7\nkey=${check
    .replace(/^.*$/m, key)
    .replace(/^base=.*$/m, `base=file://${dir}`)}\necho "$checked"`], { encoding: 'utf8', cwd: dir, env: { PATH: path } });
}

function fakeRelease(dir, { signedBy, comment = 'wuselwall-server 9.8.7 SHA256SUMS', tamper = false, legacy = false } = {}) {
  mkdirSync(dir, { recursive: true });
  const archive = randomBytes(64);
  writeFileSync(join(dir, 'wuselwall-server-9.8.7.tar.gz'), tamper ? Buffer.concat([archive, Buffer.from('x')]) : archive);
  const sums = `${createHash('sha256').update(archive).digest('hex')}  wuselwall-server-9.8.7.tar.gz\n`;
  writeFileSync(join(dir, 'SHA256SUMS'), sums);
  writeFileSync(join(dir, 'SHA256SUMS.minisig'), signedBy ? signedBy.minisig(sums, comment, legacy) : 'unsigned\n');
}

function keyPair() {
  const { publicKey, privateKey } = generateKeyPairSync('ed25519');
  const keyId = randomBytes(8);
  const raw = Buffer.from(publicKey.export({ format: 'jwk' }).x, 'base64url');
  return {
    pub: Buffer.concat([Buffer.from('Ed'), keyId, raw]).toString('base64'),
    // legacy: minisign's old "Ed" signature over the data itself, which the first boot refuses.
    minisig(data, tc, legacy = false) {
      const signature = sign(null, legacy ? Buffer.from(data) : createHash('blake2b512').update(data).digest(), privateKey);
      const global = sign(null, Buffer.concat([signature, Buffer.from(tc)]), privateKey);
      return `untrusted comment: test\n${Buffer.concat([Buffer.from(legacy ? 'Ed' : 'ED'), keyId, signature]).toString('base64')}\n` +
        `trusted comment: ${tc}\n${global.toString('base64')}\n`;
    },
  };
}

test('at the first boot, the placeholder key checks the checksum and says so', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ww-cloud-init-'));
  try {
    fakeRelease(join(dir, 'ok'));
    let result = firstBootCheck(join(dir, 'ok'), 'REPLACE-WITH-THE-RELEASE-PUBLIC-KEY');
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /WARNING: this cloud-init file has no release key/);
    fakeRelease(join(dir, 'bad'), { tamper: true });
    result = firstBootCheck(join(dir, 'bad'), 'REPLACE-WITH-THE-RELEASE-PUBLIC-KEY');
    assert.notEqual(result.status, 0, 'an altered archive stops the first boot');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('at the first boot, a signed release passes and a foreign or older one stops', { skip: !minisign && 'minisign is not installed' }, () => {
  const dir = mkdtempSync(join(tmpdir(), 'ww-cloud-init-'));
  try {
    const bin = join(dir, 'bin');
    mkdirSync(bin);
    copyFileSync(minisign, join(bin, 'minisign'));
    spawnSync('chmod', ['755', join(bin, 'minisign')]);
    const withMinisign = (d, key) => firstBootCheck(d, key, `${bin}:${process.env.PATH}`);
    const key = keyPair();
    fakeRelease(join(dir, 'ok'), { signedBy: key });
    let result = withMinisign(join(dir, 'ok'), key.pub);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /Release 9\.8\.7: the signature and the checksum match/);
    fakeRelease(join(dir, 'foreign'), { signedBy: keyPair() });
    assert.notEqual(withMinisign(join(dir, 'foreign'), key.pub).status, 0);
    fakeRelease(join(dir, 'older'), { signedBy: key, comment: 'wuselwall-server 9.8.6 SHA256SUMS' });
    result = withMinisign(join(dir, 'older'), key.pub);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /signed for another release/);
    fakeRelease(join(dir, 'legacy'), { signedBy: key, legacy: true });
    result = withMinisign(join(dir, 'legacy'), key.pub);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /not a prehashed \(ED\) signature/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
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
