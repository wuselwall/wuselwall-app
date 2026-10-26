import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import { profiles, expectedCases } from './report.mjs';

export const digest = bytes => createHash('sha256').update(bytes).digest('hex');
export const policy = {channels: 'RGBA', maxChangedPixels: 0, channelTolerance: 0};
const root = path.resolve('build/qualification/native');
export async function pixelsMatch(actual, baseline) {
  const a = await sharp(actual).ensureAlpha().raw().toBuffer({resolveWithObject: true});
  const b = await sharp(baseline).ensureAlpha().raw().toBuffer({resolveWithObject: true});
  return a.info.width === b.info.width && a.info.height === b.info.height && a.data.equals(b.data);
}
async function safeFile(dir, name) {
  assert.match(name, /^[a-z0-9-]+\/[a-z0-9-]+(?:\.png|-aria\.yml)$/);
  const resolved = path.resolve(dir, name);
  assert.ok(resolved.startsWith(`${path.resolve(dir)}${path.sep}`));
  assert.equal((await fs.lstat(resolved)).isSymbolicLink(), false);
  assert.ok((await fs.realpath(resolved)).startsWith(`${await fs.realpath(dir)}${path.sep}`));
  return resolved;
}
async function snapshotNames(dir) {
  return (await fs.readdir(dir, {recursive: true})).filter(n => n.endsWith('.png') || n.endsWith('-aria.yml')).sort();
}
export async function sealNative(dir, sourceSha, environment) {
  assert.match(sourceSha, /^[a-f0-9]{40}$/);
  const names = await snapshotNames(dir);
  assert.ok(names.length > 0 && names.every(n => names.includes(n.endsWith('.png') ? n.replace(/\.png$/, '-aria.yml') : n.replace(/-aria\.yml$/, '.png'))));
  const files = {};
  for (const name of names) files[name] = digest(await fs.readFile(await safeFile(dir, name)));
  const manifest = {schema: 1, kind: 'native', sourceSha, environment, policy, files};
  await fs.writeFile(path.join(dir, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
  return manifest;
}
export async function verifyNative(dir, manifestDigest, environment) {
  assert.match(manifestDigest, /^[a-f0-9]{64}$/);
  const bytes = await fs.readFile(path.join(dir, 'manifest.json'));
  assert.equal(digest(bytes), manifestDigest, 'Native baseline manifest checksum differs');
  const manifest = JSON.parse(bytes);
  assert.equal(manifest.schema, 1);
  assert.equal(manifest.kind, 'native');
  assert.match(manifest.sourceSha, /^[a-f0-9]{40}$/);
  assert.deepEqual(manifest.environment, environment, 'Native toolchain/runtime/display environment differs');
  assert.deepEqual(manifest.policy, policy);
  assert.deepEqual(await snapshotNames(dir), Object.keys(manifest.files).sort());
  assert.ok(Object.keys(manifest.files).length > 0);
  for (const [name, hash] of Object.entries(manifest.files)) {
    assert.equal(digest(await fs.readFile(await safeFile(dir, name))), hash, `Native baseline file differs: ${name}`);
  }
  return manifest;
}
export async function compareNative(actual, baseline, expectedDigest, environment) {
  const manifest = await verifyNative(baseline, expectedDigest, environment);
  assert.deepEqual(await snapshotNames(actual), Object.keys(manifest.files).sort());
  const findings = [];
  for (const name of Object.keys(manifest.files)) {
    const a = await safeFile(actual, name), b = await safeFile(baseline, name);
    const matches = name.endsWith('.png') ? await pixelsMatch(a, b) :
      (await fs.readFile(a)).equals(await fs.readFile(b));
    if (!matches) findings.push(name);
  }
  return {passed: findings.length === 0, checked: Object.keys(manifest.files).length, findings, manifestDigest: expectedDigest};
}
async function environment() {
  const read = name => fs.readFile(path.join(root, name), 'utf8');
  const flutter = JSON.parse(await read('flutter.json'));
  const byProfile = {};
  const runtimes = JSON.parse(await fs.readFile('build/qualification/native-preflight/runtimes.json', 'utf8')).runtimes;
  const selected = runtimes.find(r => r.identifier === process.env.QUALIFICATION_IOS_RUNTIME);
  assert.ok(selected?.isAvailable, 'Pinned iOS runtime not available');
  for (const profile of profiles) {
    const report = JSON.parse(await read(`${profile}/audit.json`));
    assert.ok(report.physicalWidth > 0 && report.physicalHeight > 0 && report.devicePixelRatio > 0 && report.textScale > 0, `Missing native display metrics: ${profile}`);
    byProfile[profile] = {physicalWidth: report.physicalWidth, physicalHeight: report.physicalHeight,
      devicePixelRatio: report.devicePixelRatio, textScale: report.textScale};
    if (profile.startsWith('android')) byProfile[profile].image = (await read(`${profile}/device.txt`)).trim();
  }
  assert.ok(flutter.frameworkVersion && flutter.frameworkRevision && flutter.engineRevision && flutter.dartSdkVersion, 'Incomplete Flutter environment');
  assert.ok(selected.version && selected.buildversion, 'Incomplete iOS runtime environment');
  return {flutter: {frameworkVersion: flutter.frameworkVersion, frameworkRevision: flutter.frameworkRevision,
    engineRevision: flutter.engineRevision, dartSdkVersion: flutter.dartSdkVersion},
    xcode: (await read('xcode.txt')).trim(), macOS: (await read('macos.txt')).trim(),
    ios: {identifier: selected.identifier, version: selected.version, buildversion: selected.buildversion},
    emulator: (await read('emulator.txt')).split('\n').find(l => l.includes('Android emulator version')),
    inventory: digest(await fs.readFile('qualification/inventory.json')), byProfile};
}
async function run() {
  const mode = process.env.QUALIFY_MODE;
  assert.ok(['capture', 'compare'].includes(mode));
  const capture = path.join(root, 'capture');
  await fs.rm(capture, {recursive: true, force: true});
  await fs.mkdir(capture, {recursive: true});
  for (const profile of profiles) {
    const out = path.join(capture, profile);
    await fs.mkdir(out);
    const report = JSON.parse(await fs.readFile(path.join(root, profile, 'audit.json'), 'utf8'));
    for (const id of expectedCases(profile, process.env.QUALIFY_NATIVE_SMOKE === 'true')) {
      const sample = report.results.find(r => r.id === id);
      assert.ok(sample?.semantics, `Missing native semantic snapshot: ${profile}/${id}`);
      await fs.copyFile(path.join(root, profile, `${id}.png`), path.join(out, `${id}.png`));
      await fs.writeFile(path.join(out, `${id}-aria.yml`), `${JSON.stringify(sample.semantics, null, 2)}\n`);
    }
  }
  const env = await environment();
  const sourceSha = process.env.QUALIFY_CANDIDATE_SHA;
  await sealNative(capture, sourceSha, env);
  const result = mode === 'compare' ? await compareNative(capture, process.env.QUALIFY_NATIVE_BASELINE_DIR,
    process.env.QUALIFY_NATIVE_BASELINE_SHA256, env) : {passed: false, checked: 0, findings: ['Capture requires visual review and an approved baseline.']};
  await fs.writeFile(path.join(root, 'visual.json'), `${JSON.stringify({schemaVersion: 1, candidateSha: sourceSha, mode, ...result}, null, 2)}\n`);
  if (mode === 'compare' && !result.passed) process.exitCode = 1;
}
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [command, dir, sha] = process.argv.slice(2);
  if (command === 'seal') {
    const env = JSON.parse(await fs.readFile(path.join(dir, 'manifest.json'), 'utf8')).environment;
    await sealNative(dir, sha, env);
    console.log(`UNAPPROVED native manifest SHA-256: ${digest(await fs.readFile(path.join(dir, 'manifest.json')))}`);
  } else await run();
}
