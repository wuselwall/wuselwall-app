import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import sharp from 'sharp';
import { compareNative, digest, pixelsMatch, sealNative, verifyNative } from './baseline.mjs';

const sha = 'a'.repeat(40);
const env = {xcode: 'pinned', runtime: 'pinned', width: 390, textScale: 1};
async function fixture(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-native-baseline-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const base = path.join(root, 'baseline'), actual = path.join(root, 'actual');
  for (const directory of [base, actual]) {
    await fs.mkdir(path.join(directory, 'ios-phone'), {recursive: true});
    await sharp({create: {width: 32, height: 32, channels: 4, background: '#fff'}}).png().toFile(path.join(directory, 'ios-phone/case.png'));
    await fs.writeFile(path.join(directory, 'ios-phone/case-aria.yml'), '{"label":"stable","children":[]}\n');
  }
  await sealNative(base, sha, env);
  const hash = digest(await fs.readFile(path.join(base, 'manifest.json')));
  return {base, actual, hash};
}

test('native baseline compares decoded pixels and exact normalized semantics', async t => {
  const {base, actual, hash} = await fixture(t);
  assert.equal((await compareNative(actual, base, hash, env)).passed, true);
  await sharp({create: {width: 32, height: 32, channels: 4, background: '#fff'}}).png({compressionLevel: 0}).toFile(path.join(actual, 'ios-phone/case.png'));
  assert.equal(await pixelsMatch(path.join(actual, 'ios-phone/case.png'), path.join(base, 'ios-phone/case.png')), true);
  await fs.writeFile(path.join(actual, 'ios-phone/case-aria.yml'), '{"label":"changed"}');
  assert.deepEqual((await compareNative(actual, base, hash, env)).findings, ['ios-phone/case-aria.yml']);
});

test('native comparison rejects a one-pixel one-channel regression', async t => {
  const {base, actual, hash} = await fixture(t);
  const pixels = Buffer.alloc(32 * 32 * 4, 255);
  pixels[0] = 254;
  await sharp(pixels, {raw: {width: 32, height: 32, channels: 4}}).png().toFile(path.join(actual, 'ios-phone/case.png'));
  assert.deepEqual((await compareNative(actual, base, hash, env)).findings, ['ios-phone/case.png']);
});

test('native manifests reject tampering, changed runtime, missing/extra files and unsafe symlinks', async t => {
  const {base, hash} = await fixture(t);
  await assert.rejects(() => verifyNative(base, '0'.repeat(64), env));
  await assert.rejects(() => verifyNative(base, hash, {...env, runtime: 'different'}));
  await fs.writeFile(path.join(base, 'ios-phone/extra.png'), 'unexpected');
  await assert.rejects(() => verifyNative(base, hash, env));
  await fs.rm(path.join(base, 'ios-phone/extra.png'));
  await fs.rm(path.join(base, 'ios-phone/case.png'));
  await fs.symlink('/etc/hosts', path.join(base, 'ios-phone/case.png'));
  await assert.rejects(() => verifyNative(base, hash, env));
});

test('native baseline creation refuses empty or unpaired screenshots', async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-native-unpaired-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  await assert.rejects(() => sealNative(root, sha, env));
  await fs.mkdir(path.join(root, 'ios-phone'));
  await fs.writeFile(path.join(root, 'ios-phone/case.png'), 'not-paired');
  await assert.rejects(() => sealNative(root, sha, env));
});
