import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import sharp from 'sharp';
import {expectedCases} from './report.mjs';
import {diagnosticProfiles, diagnosticReport, writeDiagnosticReport} from './smoke-report.mjs';

const sha = 'a'.repeat(40);
const png = await sharp({create: {width: 32, height: 32, channels: 4, background: '#fff'}}).png().toBuffer();

async function fixture(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-native-smoke-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  await fs.writeFile(path.join(root, 'profiles.txt'), diagnosticProfiles.map(profile => `${profile}: PASS`).join('\n'));
  for (const profile of diagnosticProfiles) {
    const out = path.join(root, profile);
    await fs.mkdir(out);
    const cases = expectedCases(profile, true);
    await fs.writeFile(path.join(out, 'audit.json'), JSON.stringify({schemaVersion: 1, done: true,
      candidateSha: sha, expected: cases.length + 2, results: [...cases, 'detector-bad', 'detector-keyboard']
        .map(id => ({id, passed: true, frameworkErrors: []}))}));
    await fs.writeFile(path.join(out, 'results.json'), JSON.stringify({candidateSha: sha, expected: cases.length,
      captured: cases.length, logicalWidth: 390, logicalHeight: 844, devicePixelRatio: 2}));
    await Promise.all(cases.map(id => fs.writeFile(path.join(out, `${id}.png`), png)));
  }
  return root;
}

test('two passing phone profiles produce diagnostic evidence that remains unqualified', async t => {
  const root = await fixture(t);
  const report = await writeDiagnosticReport(root, sha);
  assert.equal(report.diagnosticPassed, true);
  assert.deepEqual(report.selectedProfiles.map(profile => profile.profile), diagnosticProfiles);
  assert.ok(report.selectedProfiles.every(profile => profile.passed && profile.detectorsPassed && profile.captures > 0));
  assert.deepEqual(report.qualification, {status: 'INCOMPLETE', qualified: false});
  assert.equal(JSON.parse(await fs.readFile(path.join(root, 'diagnostic.json'), 'utf8')).diagnosticPassed, true);
});

test('a missing selected report fails closed while other full-matrix profiles remain unnecessary', async t => {
  const root = await fixture(t);
  await fs.rm(path.join(root, 'android-phone', 'audit.json'));
  const report = await diagnosticReport(root, sha);
  assert.equal(report.diagnosticPassed, false);
  assert.equal(report.selectedProfiles.find(profile => profile.profile === 'ios-phone').passed, true);
  assert.equal(report.selectedProfiles.find(profile => profile.profile === 'android-phone').passed, false);
  assert.equal(report.qualification.qualified, false);
});

test('rendering captures remain counted when the native audit report is missing', async t => {
  const root = await fixture(t);
  await fs.rm(path.join(root, 'ios-phone', 'audit.json'));
  const report = await diagnosticReport(root, sha, ['ios-phone']);
  const [profile] = report.selectedProfiles;
  assert.equal(profile.captures, 5);
  assert.equal(profile.renderingPassed, true);
  assert.equal(profile.cases, 0);
  assert.equal(profile.nativeAudit, 'incomplete');
  assert.equal(profile.passed, false);
  assert.equal(report.diagnosticPassed, false);
  assert.deepEqual(report.qualification, {status: 'INCOMPLETE', qualified: false});
});

test('rendering captures remain counted when the native audit is incomplete', async t => {
  const root = await fixture(t);
  await fs.writeFile(path.join(root, 'ios-phone', 'audit.json'), JSON.stringify({schemaVersion: 1,
    candidateSha: sha, expected: 7, done: false, ready: false,
    results: [{id: 'detector-bad', passed: true}]}));
  const report = await diagnosticReport(root, sha, ['ios-phone']);
  const [profile] = report.selectedProfiles;
  assert.equal(profile.captures, 5);
  assert.equal(profile.renderingPassed, true);
  assert.equal(profile.cases, 0);
  assert.equal(profile.nativeAudit, 'incomplete');
  assert.equal(profile.passed, false);
  assert.equal(report.diagnosticPassed, false);
  assert.equal(report.qualification.qualified, false);
});

test('a diagnostic may select only the fixed iOS phone profile without Android evidence', async t => {
  const root = await fixture(t);
  await fs.rm(path.join(root, 'android-phone'), {recursive: true});
  await fs.writeFile(path.join(root, 'profiles.txt'), 'ios-phone: PASS\n');
  const report = await diagnosticReport(root, sha, ['ios-phone']);
  assert.equal(report.diagnosticPassed, true);
  assert.deepEqual(report.selectedProfiles.map(profile => profile.profile), ['ios-phone']);
  assert.equal(report.qualification.qualified, false);
});

test('diagnostic profile selection rejects unsupported, duplicate and reordered values', async t => {
  const root = await fixture(t);
  for (const selection of [[], ['android-tablet'], ['ios-phone', 'ios-phone'], ['android-phone', 'ios-phone']]) {
    assert.equal((await diagnosticReport(root, sha, selection)).diagnosticPassed, false);
  }
});

test('Android-only diagnostics do not require iOS evidence', async t => {
  const root = await fixture(t);
  await fs.rm(path.join(root, 'ios-phone'), {recursive: true});
  await fs.writeFile(path.join(root, 'profiles.txt'), 'android-phone: PASS\n');
  const report = await diagnosticReport(root, sha, ['android-phone']);
  assert.equal(report.diagnosticPassed, true);
  assert.deepEqual(report.selectedProfiles.map(profile => profile.profile), ['android-phone']);
  assert.equal(report.qualification.qualified, false);
});

test('stale candidates, failed profile commands and absent screenshots fail closed', async t => {
  const root = await fixture(t);
  await fs.writeFile(path.join(root, 'profiles.txt'), 'ios-phone: PASS\nandroid-phone: FAIL\n');
  await fs.rm(path.join(root, 'ios-phone', `${expectedCases('ios-phone', true)[0]}.png`));
  assert.equal((await diagnosticReport(root, sha)).diagnosticPassed, false);
  assert.equal((await diagnosticReport(root, 'b'.repeat(40))).diagnosticPassed, false);
  assert.equal((await diagnosticReport(root, 'invalid-sha')).diagnosticPassed, false);
});

test('workflow keeps smoke and runner diagnostics outside promotion and signing', async () => {
  const workflow = await fs.readFile(new URL('../../.github/workflows/release-ios.yml', import.meta.url), 'utf8');
  assert.match(workflow, /native_smoke_only/);
  assert.match(workflow, /DIAGNOSTICS_ONLY: \$\{\{ inputs\.diagnostics_only \}\}/);
  assert.match(workflow, /NATIVE_SMOKE_ONLY: \$\{\{ inputs\.native_smoke_only \}\}/);
  assert.match(workflow, /github\.event_name == 'workflow_dispatch' && inputs\.native_smoke_only && !inputs\.diagnostics_only/);
  assert.match(workflow, /inputs\.diagnostics_only != true && inputs\.native_smoke_only != true/);
  assert.match(workflow, /qualification\.result == 'success'/);
  assert.match(workflow, /environment: release-promotion/);
  assert.match(workflow, /both\) profiles=\(ios-phone android-phone\)/);
  assert.match(workflow, /QUALIFY_NATIVE_SMOKE: 'true'/);
  assert.match(workflow, /options: \[both, ios, android\]/);
  const native = await fs.readFile(new URL('../native.sh', import.meta.url), 'utf8');
  assert.match(native, /platform" == ios && "\$\{QUALIFY_NATIVE_SMOKE:-false\}" == true && "\$\{QUALIFICATION_IOS_DIAGNOSTIC_RUNTIME_FALLBACK:-false\}" == true/);
  const preflight = await fs.readFile(new URL('./preflight.sh', import.meta.url), 'utf8');
  assert.match(preflight, /\[\[ "\$platform" == all \|\| "\$platform" == ios \]\]/);
});
