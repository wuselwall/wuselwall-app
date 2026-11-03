import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createHash, generateKeyPairSync, randomBytes, sign } from 'node:crypto';
import { tmpdir } from 'node:os';
import { delimiter, dirname, join } from 'node:path';
import { after, before, test } from 'node:test';

// server/wuselwall checks a release before it unpacks it and runs the new script as root
// (security review 2026-11-01, F9): the minisign signature of SHA256SUMS, then the archive's
// checksum. The signatures here are made with node's Ed25519 in minisign's format, so the
// test runs without minisign; when minisign is installed (or MINISIGN names it), it must
// accept the same signatures, and the script is also checked with minisign on its PATH.
const root = new URL('../', import.meta.url).pathname;
const script = join(root, 'server/wuselwall');
const which = (cmd) => spawnSync('sh', ['-c', `command -v ${cmd}`], { encoding: 'utf8' }).stdout.trim();
const minisign = process.env.MINISIGN || which('minisign');
const opensslVerifies = spawnSync('bash', ['-c',
  'openssl list -digest-algorithms | grep -i blake2b512 >/dev/null && openssl pkeyutl -help 2>&1 | grep -e -rawin >/dev/null']).status === 0;
const version = '9.8.7';
const archiveName = `wuselwall-server-${version}.tar.gz`;
// PATH without any minisign, so the script falls back to OpenSSL.
const plainPath = process.env.PATH.split(delimiter).filter((d) => !which('minisign') || d !== dirname(which('minisign'))).join(delimiter);

let dir;
let archive;

// A minisign key pair: the public key line and a signer for the .minisig format.
function keyPair() {
  const { publicKey, privateKey } = generateKeyPairSync('ed25519');
  const keyId = randomBytes(8);
  const raw = Buffer.from(publicKey.export({ format: 'jwk' }).x, 'base64url');
  const pub = Buffer.concat([Buffer.from('Ed'), keyId, raw]).toString('base64');
  // `legacy` makes minisign's old "Ed" signature over the data itself, which the script refuses.
  const minisig = (data, comment, { legacy = false } = {}) => {
    const signed = legacy ? Buffer.from(data) : createHash('blake2b512').update(data).digest();
    const signature = sign(null, signed, privateKey);
    const global = sign(null, Buffer.concat([signature, Buffer.from(comment)]), privateKey);
    return `untrusted comment: test signature\n${Buffer.concat([Buffer.from(legacy ? 'Ed' : 'ED'), keyId, signature]).toString('base64')}\n` +
      `trusted comment: ${comment}\n${global.toString('base64')}\n`;
  };
  return { pub, minisig };
}

// A release directory: the archive, SHA256SUMS, and optionally SHA256SUMS.minisig.
function release(name, { sums, signer, comment = `wuselwall-server ${version} SHA256SUMS`, file = archive, legacy = false } = {}) {
  const d = join(dir, name);
  mkdirSync(d);
  copyFileSync(file, join(d, archiveName));
  const text = sums ?? `${createHash('sha256').update(readFileSync(file)).digest('hex')}  ${archiveName}\n`;
  writeFileSync(join(d, 'SHA256SUMS'), text);
  if (signer) writeFileSync(join(d, 'SHA256SUMS.minisig'), signer.minisig(text, comment, { legacy }));
  return join(d, archiveName);
}

const verify = (file, env = {}) => spawnSync('bash', [script, 'verify', file],
  { encoding: 'utf8', env: { PATH: process.env.PATH, HOME: process.env.HOME, ...env } });

// The script's functions with a command after them, as server/test_setup_link.py loads them.
// The shipped script pins the real release key; the checksum-only tests ask for the
// placeholder explicitly, as a checkout before the key was generated behaved.
const PLACEHOLDER = 'REPLACE-WITH-THE-RELEASE-PUBLIC-KEY';
const functions = readFileSync(script, 'utf8').split('case "${1:-}" in')[0];
// ROOT is the working directory then (the script reads its VERSION there).
const run = (command, env = {}, cwd = undefined) => spawnSync('bash', [], {
  input: `${functions}\n${command}`, encoding: 'utf8', cwd, env: { PATH: process.env.PATH, HOME: process.env.HOME, ...env },
});

before(() => {
  dir = mkdtempSync(join(tmpdir(), 'ww-server-release-'));
  const build = spawnSync('bash', ['scripts/build-server-release.sh', version, '--skip-web'],
    { cwd: root, encoding: 'utf8', env: { ...process.env, DIST_DIR: join(dir, 'dist') } });
  assert.equal(build.status, 0, build.stderr);
  archive = join(dir, 'dist', archiveName);
});
after(() => rmSync(dir, { recursive: true, force: true }));

test('the build writes the archive into DIST_DIR', () => {
  const list = spawnSync('tar', ['-tzf', archive], { encoding: 'utf8' }).stdout.split('\n');
  for (const entry of ['wuselwall/wuselwall', 'wuselwall/VERSION', 'wuselwall/backup/backup.sh']) assert.ok(list.includes(entry), entry);
});

test('while the release key is the placeholder, the checksum is checked with a warning', () => {
  const file = release('placeholder');
  const result = verify(file, { WW_RELEASE_PUBKEY: PLACEHOLDER });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /WARNING: this wuselwall has no release key pinned/);
  assert.match(result.stderr, /checksum matches \(signature not checked\)/);
  assert.match(result.stdout, new RegExp(`${archiveName}: sha256 [0-9a-f]{64}`));
  const strict = verify(file, { WW_RELEASE_PUBKEY: PLACEHOLDER, WW_REQUIRE_SIGNATURE: '1' });
  assert.equal(strict.status, 1);
  assert.match(strict.stderr, /WW_REQUIRE_SIGNATURE=1/);
});

test('an altered archive fails the checksum', () => {
  const altered = join(dir, 'altered.tar.gz');
  writeFileSync(altered, Buffer.concat([readFileSync(archive), Buffer.from('x')]));
  const good = `${createHash('sha256').update(readFileSync(archive)).digest('hex')}  ${archiveName}\n`;
  const result = verify(release('altered', { sums: good, file: altered }), { WW_RELEASE_PUBKEY: PLACEHOLDER });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /does not match SHA256SUMS/);
});

test('a file without SHA256SUMS beside it is unpacked only with a warning, never under WW_REQUIRE_SIGNATURE=1', () => {
  mkdirSync(join(dir, 'bare'));
  const file = join(dir, 'bare', archiveName);
  copyFileSync(archive, file);
  const result = verify(file);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /no SHA256SUMS next to/);
  assert.equal(verify(file, { WW_REQUIRE_SIGNATURE: '1' }).status, 1);
});

test('a signed release passes with OpenSSL alone', { skip: !opensslVerifies && 'OpenSSL 3 is missing' }, () => {
  const key = keyPair();
  const result = verify(release('signed-openssl', { signer: key }), { WW_RELEASE_PUBKEY: key.pub, WW_REQUIRE_SIGNATURE: '1', PATH: plainPath });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, new RegExp(`Release ${version}: the signature and the checksum match`));
});

test('another key, an altered SHA256SUMS or a missing signature is refused', { skip: !opensslVerifies && 'OpenSSL 3 is missing' }, () => {
  const key = keyPair();
  const other = keyPair();
  const env = { WW_RELEASE_PUBKEY: key.pub, PATH: plainPath };
  let result = verify(release('other-key', { signer: other }), env);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /does not match the release key/);

  const file = release('altered-sums', { signer: key });
  const sums = join(dirname(file), 'SHA256SUMS');
  writeFileSync(sums, readFileSync(sums, 'utf8') + `${'0'.repeat(64)}  wuselwall-server-9.9.9.tar.gz\n`);
  result = verify(file, env);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /does not match the release key/);

  result = verify(release('unsigned', {}), env);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /not signed/);
});

test('the signed comment binds the version', { skip: !opensslVerifies && 'OpenSSL 3 is missing' }, () => {
  const key = keyPair();
  const env = { WW_RELEASE_PUBKEY: key.pub, PATH: plainPath };
  // An old release's signed SHA256SUMS offered as a newer version (the download path).
  const file = release('rollback', { signer: key });
  const d = dirname(file);
  let result = run(`verify_release '${file}' '${d}/SHA256SUMS' '${d}/SHA256SUMS.minisig' 9.9.9`, env);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /signature is for release 9\.8\.7, not 9\.9\.9/);
  result = run(`verify_release '${file}' '${d}/SHA256SUMS' '${d}/SHA256SUMS.minisig' ${version}`, env);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), `${version} signed`);
  // A comment that names another version than the file in SHA256SUMS.
  result = verify(release('mismatch', { signer: key, comment: 'wuselwall-server 1.0.0 SHA256SUMS' }), env);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /lists this file as wuselwall-server-9\.8\.7\.tar\.gz, not as release 1\.0\.0/);
  result = verify(release('foreign', { signer: key, comment: 'something else' }), env);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /not a WuselWall server release/);
});

test('without minisign and OpenSSL 3 the checksum is checked with a warning, or refused when required', () => {
  const key = keyPair();
  const file = release('no-verifier', { signer: key });
  const command = `openssl_can_verify() { return 1; }\ncheck_release '${file}' /nonexistent`;
  let result = run(command, { WW_RELEASE_PUBKEY: key.pub, PATH: plainPath });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /apt install minisign/);
  assert.match(result.stderr, /neither minisign nor OpenSSL 3 is here/);
  assert.equal(result.stdout.trim(), file);
  result = run(command, { WW_RELEASE_PUBKEY: key.pub, PATH: plainPath, WW_REQUIRE_SIGNATURE: '1' });
  assert.equal(result.status, 1);
});

test('minisign accepts these signatures, and the script checks with minisign', { skip: !minisign && 'minisign is not installed' }, () => {
  const key = keyPair();
  const file = release('signed-minisign', { signer: key });
  const d = dirname(file);
  const own = spawnSync(minisign, ['-V', '-Q', '-m', join(d, 'SHA256SUMS'), '-P', key.pub], { encoding: 'utf8' });
  assert.equal(own.status, 0, own.stderr);
  assert.equal(own.stdout.trim(), `wuselwall-server ${version} SHA256SUMS`);
  const bin = join(dir, 'bin');
  mkdirSync(bin, { recursive: true });
  copyFileSync(minisign, join(bin, 'minisign'));
  spawnSync('chmod', ['755', join(bin, 'minisign')]);
  const result = verify(file, { WW_RELEASE_PUBKEY: key.pub, WW_REQUIRE_SIGNATURE: '1', PATH: `${bin}${delimiter}${plainPath}` });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /the signature and the checksum match/);
  const other = keyPair();
  const refused = verify(file, { WW_RELEASE_PUBKEY: other.pub, PATH: `${bin}${delimiter}${plainPath}` });
  assert.equal(refused.status, 1);
});

test('a key pair made by minisign itself verifies through OpenSSL', { skip: (!minisign || !opensslVerifies) && 'minisign or OpenSSL 3 is missing' }, () => {
  const keys = join(dir, 'minisign-keys');
  mkdirSync(keys);
  const gen = spawnSync(minisign, ['-G', '-W', '-p', join(keys, 'k.pub'), '-s', join(keys, 'k.key')], { encoding: 'utf8' });
  assert.equal(gen.status, 0, gen.stderr);
  const file = release('minisign-made');
  const d = dirname(file);
  const signed = spawnSync(minisign, ['-S', '-s', join(keys, 'k.key'), '-m', join(d, 'SHA256SUMS'),
    '-t', `wuselwall-server ${version} SHA256SUMS`], { encoding: 'utf8' });
  assert.equal(signed.status, 0, signed.stderr);
  const pub = readFileSync(join(keys, 'k.pub'), 'utf8').split('\n')[1];
  const result = verify(file, { WW_RELEASE_PUBKEY: pub, WW_REQUIRE_SIGNATURE: '1', PATH: plainPath });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /the signature and the checksum match/);
});

test('an .env with a published default key is recognised (install --env refuses it)', () => {
  const d = join(dir, 'envs');
  mkdirSync(d);
  writeFileSync(join(d, 'public.env'), "JWT_SECRET='super-secret-jwt-token-with-at-least-32-characters-long'\nSUPABASE_SECRET_KEY='sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz'\n");
  writeFileSync(join(d, 'own.env'), `JWT_SECRET='${randomBytes(32).toString('hex')}'\n`);
  let result = run(`public_keys_in '${join(d, 'public.env')}'`);
  assert.equal(result.status, 0);
  assert.deepEqual(result.stdout.trim().split('\n').sort(), ['JWT_SECRET', 'SUPABASE_SECRET_KEY']);
  assert.ok(!result.stdout.includes('super-secret'), 'names only, never values');
  result = run(`public_keys_in '${join(d, 'own.env')}'`);
  assert.equal(result.status, 1);
  assert.equal(result.stdout, '');
});

test('a legacy (Ed) signature is refused, even when it is valid', () => {
  const key = keyPair();
  const file = release('legacy', { signer: key, legacy: true });
  const result = verify(file, { WW_RELEASE_PUBKEY: key.pub, PATH: plainPath });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /not a prehashed \(ED\) minisign signature/);
  if (minisign) {
    // minisign itself accepts it; the script refuses it before asking minisign.
    const d = dirname(file);
    assert.equal(spawnSync(minisign, ['-V', '-q', '-m', join(d, 'SHA256SUMS'), '-P', key.pub]).status, 0);
    const bin = join(dir, 'bin-legacy');
    mkdirSync(bin);
    copyFileSync(minisign, join(bin, 'minisign'));
    spawnSync('chmod', ['755', join(bin, 'minisign')]);
    const withMinisign = verify(file, { WW_RELEASE_PUBKEY: key.pub, PATH: `${bin}${delimiter}${plainPath}` });
    assert.equal(withMinisign.status, 1);
    assert.match(withMinisign.stderr, /not a prehashed/);
  }
  // The OpenSSL verifier alone refuses it too.
  const d = dirname(file);
  const own = run(`WW_RELEASE_PUBKEY='${key.pub}'; minisign_openssl '${d}/SHA256SUMS' '${d}/SHA256SUMS.minisig'`);
  assert.equal(own.status, 1);
});

test('an older release than the installed one needs --allow-downgrade', () => {
  const installed = join(dir, 'installed');
  mkdirSync(installed);
  writeFileSync(join(installed, 'VERSION'), '9.10.0\n');
  let result = run('refuse_downgrade 9.9.9', {}, installed);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /release 9\.9\.9 is older than the installed 9\.10\.0.*--allow-downgrade/);
  result = run('refuse_downgrade 9.9.9 --allow-downgrade', {}, installed);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /going back from 9\.10\.0 to 9\.9\.9/);
  for (const newer of ['9.10.0', '9.10.1', '10.0.0']) assert.equal(run(`refuse_downgrade ${newer}`, {}, installed).status, 0, newer);
});

test('unpack refuses an older archive after checking it, before extracting anything', () => {
  const installed = join(dir, 'installed-unpack');
  mkdirSync(join(installed, 'stack', 'volumes', 'functions'), { recursive: true });
  writeFileSync(join(installed, 'VERSION'), '10.0.0\n');
  const file = release('older-file');
  let result = run(`STACK='${installed}/stack'; unpack '${file}'`, { WW_RELEASE_PUBKEY: PLACEHOLDER }, installed);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /release 9\.8\.7 is older than the installed 10\.0\.0/);
  assert.equal(readFileSync(join(installed, 'VERSION'), 'utf8'), '10.0.0\n', 'nothing was unpacked');
  assert.ok(spawnSync('test', ['-d', join(installed, 'stack', 'volumes', 'functions')]).status === 0, 'the functions stay');
  result = run(`STACK='${installed}/stack'; unpack '${file}' --allow-downgrade`, { WW_RELEASE_PUBKEY: PLACEHOLDER }, installed);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(join(installed, 'VERSION'), 'utf8'), `${version}\n`);
});
