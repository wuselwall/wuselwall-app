import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import sharp from 'sharp';
import { nativeEvidence, profiles, expectedCases } from './report.mjs';

const sha = 'a'.repeat(40);
const png = await sharp({create: {width: 32, height: 32, channels: 4, background: '#fff'}}).png().toBuffer();
async function fixture(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-native-evidence-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  await fs.writeFile(path.join(root, 'profiles.txt'), profiles.map(p => `${p}: PASS`).join('\n'));
  for (const profile of profiles) {
    const out = path.join(root, profile);
    await fs.mkdir(out);
    const cases = expectedCases(profile, true);
    await fs.writeFile(path.join(out, 'audit.json'), JSON.stringify({schemaVersion: 1, done: true,
      candidateSha: sha, expected: cases.length + 2, results: [...cases, 'detector-bad', 'detector-keyboard']
        .map(id => ({id, passed: true, frameworkErrors: [], textScale: profile.endsWith('-large') ? 2 : 1}))}));
    await fs.writeFile(path.join(out, 'results.json'), JSON.stringify({candidateSha: sha, expected: cases.length, captured: cases.length, logicalWidth: profile.includes('tablet') ? 820 : 390, logicalHeight: 844, devicePixelRatio: 2}));
    await Promise.all(cases.map(id => fs.writeFile(path.join(out, `${id}.png`), png)));
  }
  return root;
}

test('native evidence requires complete platform, detector, rendering and enlarged-text results', async t => {
  const root = await fixture(t);
  const evidence = await nativeEvidence(root, sha, true);
  assert.equal(evidence.executionPassed, true);
  assert.equal(evidence.profile, 'smoke');
  assert.ok(evidence.captures > 0);
  assert.equal(evidence.audits.ios.detectorsPassed, true);
  assert.equal(evidence.audits.android.passed, true);
});

test('native evidence rejects missing screenshots even with passing audit JSON', async t => {
  const root = await fixture(t);
  await fs.rm(path.join(root, profiles[0], `${expectedCases(profiles[0], true)[0]}.png`));
  assert.equal((await nativeEvidence(root, sha, true)).executionPassed, false);
});

test('native evidence rejects unsuccessful subprocesses, ineffective font changes and detector misses', async t => {
  const root = await fixture(t);
  await fs.appendFile(path.join(root, 'profiles.txt'), `\n${profiles[0]}: FAIL\n`);
  const location = path.join(root, 'ios-phone-large/audit.json');
  const report = JSON.parse(await fs.readFile(location, 'utf8'));
  report.results.forEach(r => r.textScale = 1);
  report.results.find(r => r.id === 'detector-bad').passed = false;
  await fs.writeFile(location, JSON.stringify(report));
  const evidence = await nativeEvidence(root, sha, true);
  assert.equal(evidence.executionPassed, false);
  assert.equal(evidence.audits.ios.detectorsPassed, false);
  assert.equal(evidence.results.find(r => r.profile === 'ios-phone-large').largeTextPassed, false);
});

test('native evidence rejects stale candidate results and repeated cases', async t => {
  const root = await fixture(t);
  const location = path.join(root, profiles[0], 'audit.json');
  const report = JSON.parse(await fs.readFile(location, 'utf8'));
  report.candidateSha = 'b'.repeat(40);
  report.results[0] = report.results[1];
  await fs.writeFile(location, JSON.stringify(report));
  assert.equal((await nativeEvidence(root, sha, true)).executionPassed, false);
});
