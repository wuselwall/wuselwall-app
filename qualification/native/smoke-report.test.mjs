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
        .map(id => ({id, passed: true, frameworkErrors: [], issues: [],
          semantics: {type: 1, label: id, children: []}}))}));
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
  assert.equal(profile.captures, expectedCases('ios-phone', true).length);
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
    candidateSha: sha, expected: expectedCases('ios-phone', true).length + 2, done: false, ready: false,
    results: [{id: 'detector-bad', passed: true}]}));
  const report = await diagnosticReport(root, sha, ['ios-phone']);
  const [profile] = report.selectedProfiles;
  assert.equal(profile.captures, expectedCases('ios-phone', true).length);
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
  for (const selection of [[], ['android-watch'], ['ios-phone', 'ios-phone'], ['android-phone', 'ios-phone']]) {
    const report = await diagnosticReport(root, sha, selection);
    assert.equal(report.diagnosticPassed, false);
    assert.deepEqual(report.selectedProfiles, []);
  }
});

// One profile's evidence as native.sh leaves it, for any profile and either set of cases.
async function profileEvidence(root, profile, smoke, mutate = () => {}) {
  const out = path.join(root, profile);
  await fs.mkdir(out, {recursive: true});
  const cases = expectedCases(profile, smoke);
  const report = {schemaVersion: 1, done: true, candidateSha: sha, expected: cases.length + 2,
    results: [...cases, 'detector-bad', 'detector-keyboard'].map(id => ({id, passed: true, frameworkErrors: [],
      issues: [], semantics: {type: 1, label: id, children: []}}))};
  mutate(report);
  await fs.writeFile(path.join(out, 'audit.json'), JSON.stringify(report));
  await fs.writeFile(path.join(out, 'results.json'), JSON.stringify({candidateSha: sha, expected: cases.length,
    captured: cases.length, logicalWidth: profile.includes('tablet') ? 1280 : 390, logicalHeight: 844, devicePixelRatio: 2}));
  await Promise.all(cases.map(id => fs.writeFile(path.join(out, `${id}.png`), png)));
}

test('any native profile can be diagnosed, with the full cases, and stays unqualified', async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-native-diagnostic-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const selection = ['android-tablet', 'android-min-phone'];
  await fs.writeFile(path.join(root, 'profiles.txt'), selection.map(profile => `${profile}: PASS`).join('\n'));
  for (const profile of selection) await profileEvidence(root, profile, false);
  assert.ok(expectedCases('android-tablet', false).length > expectedCases('android-min-phone', false).length,
    'the tablet also audits the children\'s home and the wall');
  const report = await diagnosticReport(root, sha, selection, false);
  assert.equal(report.cases, 'full');
  assert.equal(report.diagnosticPassed, true);
  assert.deepEqual(report.selectedProfiles.map(profile => [profile.profile, profile.nativeAudit, profile.cases, profile.findings]),
    selection.map(profile => [profile, 'complete', expectedCases(profile, false).length + 2, 0]));
  assert.deepEqual(report.qualification, {status: 'INCOMPLETE', qualified: false});
  // The same evidence is not the smoke cases' evidence.
  assert.equal((await diagnosticReport(root, sha, selection, true)).diagnosticPassed, false);
});

test('a complete report with a finding is told apart from a report that was never collected', async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-native-diagnostic-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const selection = ['android-tablet', 'android-min-phone'];
  await fs.writeFile(path.join(root, 'profiles.txt'), 'android-tablet: FAIL\nandroid-min-phone: PASS\n');
  await fs.mkdir(path.join(root, 'android-tablet'));
  await fs.writeFile(path.join(root, 'android-tablet/run.log'), [
    'NATIVE INSTRUMENTATION FAILED android-tablet: org.junit.ComparisonFailure: Active window of wall-de-light is not the app\'s',
    'NATIVE REPORT MISSING android-tablet: no audit report on the device'].join('\n'));
  await profileEvidence(root, 'android-min-phone', true, report => {
    const sample = report.results.find(result => result.id === 'shopping-de-light');
    sample.passed = false;
    sample.issues = [{check: 'SpeakableTextPresentCheck', type: 'ERROR'}, {check: 'TextContrastCheck', type: 'NOT_RUN'}];
  });
  const report = await diagnosticReport(root, sha, selection);
  assert.equal(report.diagnosticPassed, false);
  const [tablet, minimum] = report.selectedProfiles;
  assert.deepEqual([tablet.nativeAudit, tablet.collectionPassed, tablet.findings, tablet.cases], ['incomplete', false, null, 0]);
  assert.deepEqual(tablet.origin.markers.map(marker => marker.split(':')[0]),
    ['NATIVE INSTRUMENTATION FAILED android-tablet', 'NATIVE REPORT MISSING android-tablet']);
  assert.deepEqual([minimum.nativeAudit, minimum.collectionPassed, minimum.frameworkErrors, minimum.findings, minimum.passed],
    ['complete', true, 0, 1, false]);
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
  assert.match(workflow, /inputs\.native_smoke_platform == 'android' && 'android-phone' \|\| 'ios-phone,android-phone'/);
  assert.match(workflow, /QUALIFY_NATIVE_SMOKE: \$\{\{ inputs\.native_smoke_cases == 'full' && 'false' \|\| 'true' \}\}/);
  assert.match(workflow, /options: \[both, ios, android\]/);
  assert.match(workflow, /options: \[smoke, full\]\n\s+default: smoke/);
  // A selected profile is an input: it reaches the script as data, is matched against the
  // platform whose tools were installed, and only then names a directory.
  assert.match(workflow, /QUALIFY_NATIVE_PROFILES: \$\{\{ inputs\.native_smoke_profiles != '' && inputs\.native_smoke_profiles \|\| /);
  const smokeJob = workflow.slice(workflow.indexOf('\n  native_smoke:'), workflow.indexOf('\n  qualification:'));
  const script = smokeJob.slice(smokeJob.indexOf('Run the selected diagnostic profiles')).match(/\n        run: \|\n([^]*?)\n      - /)[1];
  assert.match(script, /IFS=, read -r -a profiles <<< "\$QUALIFY_NATIVE_PROFILES"/);
  assert.equal(script.includes('${{'), false);
  assert.match(smokeJob, /\{ echo 'Native profile selection differs from its platform\.' >&2; exit 1; \}\n\s+rm -rf "build\/qualification\/native\/\$profile"/);
  assert.equal(/secrets\.|environment:/.test(smokeJob), false, 'the diagnostic signs nothing and promotes nothing');
  const native = await fs.readFile(new URL('../native.sh', import.meta.url), 'utf8');
  assert.match(native, /platform" == ios && "\$\{QUALIFY_NATIVE_SMOKE:-false\}" == true && "\$\{QUALIFICATION_IOS_DIAGNOSTIC_RUNTIME_FALLBACK:-false\}" == true/);
  const preflight = await fs.readFile(new URL('./preflight.sh', import.meta.url), 'utf8');
  assert.match(preflight, /\[\[ "\$platform" == all \|\| "\$platform" == ios \]\]/);
});
