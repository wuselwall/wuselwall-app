import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {createHash} from 'node:crypto';
import sharp from 'sharp';
import { nativeEvidence, profiles, expectedCases, pendingReviewCandidates } from './report.mjs';
import { pendingEntry, parseReviewBundle } from './reviews.mjs';

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
        .map(id => ({id, passed: true, frameworkErrors: [], issues: [], semantics: {label: id},
          textScale: profile.endsWith('-large') ? 2 : 1}))}));
    await fs.writeFile(path.join(out, 'results.json'), JSON.stringify({candidateSha: sha, expected: cases.length, captured: cases.length, logicalWidth: profile.includes('tablet') ? 820 : 390, logicalHeight: 844, devicePixelRatio: 2}));
    await Promise.all(cases.map(id => fs.writeFile(path.join(out, `${id}.png`), png)));
  }
  return root;
}

const issue = {
  type: 'ERROR', auditType: 8, description: 'Element has no description',
  detail: 'An element of type FlutterSemanticsScrollView had no description.', identifier: '',
  element: {type: 46, identifier: '', label: '', frame: {x: 0, y: 10, width: 390, height: 700}, debugDescription: 'FlutterSemanticsScrollView'},
};
const reviewEnvironment = {flutter: {frameworkVersion: '3.47.7'}, ios: {version: '27.0'}};

async function reviewedFixture(t) {
  const root = await fixture(t);
  for (const profile of profiles) {
    const expected = expectedCases(profile, false);
    const location = path.join(root, profile);
    const previous = JSON.parse(await fs.readFile(path.join(location, 'audit.json'), 'utf8'));
    const previousRender = JSON.parse(await fs.readFile(path.join(location, 'results.json'), 'utf8'));
    await fs.writeFile(path.join(location, 'audit.json'), JSON.stringify({schemaVersion: 1, done: true,
      candidateSha: sha, expected: expected.length + 2, results: [...expected, 'detector-bad', 'detector-keyboard']
        .map(id => ({id, passed: true, frameworkErrors: [], textScale: profile.endsWith('-large') ? 2 : 1,
          issues: [], semantics: {label: id, children: []}}))}));
    await fs.writeFile(path.join(location, 'results.json'), JSON.stringify({...previousRender,
      expected: expected.length, captured: expected.length}));
    for (const name of await fs.readdir(location)) if (name.endsWith('.png')) await fs.rm(path.join(location, name));
    await Promise.all(expected.map(id => fs.writeFile(path.join(location, `${id}.png`), png)));
    assert.equal(previous.done, true);
  }
  const profile = profiles[0];
  const caseId = expectedCases(profile, false)[0];
  const reportPath = path.join(root, profile, 'audit.json');
  const report = JSON.parse(await fs.readFile(reportPath, 'utf8'));
  const sample = report.results.find(result => result.id === caseId);
  sample.passed = false;
  sample.issues = [issue];
  sample.semantics = {label: 'Today', children: []};
  await fs.writeFile(reportPath, JSON.stringify(report));
  await fs.mkdir(path.join(root, 'capture'), {recursive: true});
  await fs.writeFile(path.join(root, 'capture', 'manifest.json'), JSON.stringify({schema: 1, kind: 'native',
    sourceSha: sha, environment: reviewEnvironment, files: {}}));
  const context = {candidateSha: sha, profile, caseId, environment: reviewEnvironment,
    screenshot: await fs.readFile(path.join(root, profile, `${caseId}.png`)), semantics: sample.semantics};
  const entry = pendingEntry(context, issue, 0);
  Object.assign(entry, {disposition: 'framework-false-positive', rationale: 'Verified against native snapshot.',
    reviewer: 'release-review', reviewedAt: '2026-10-30T12:00:00Z'});
  const bundle = {schemaVersion: 1, kind: 'native-accessibility-reviews', candidateSha: sha, entries: [entry]};
  const bytes = Buffer.from(`${JSON.stringify(bundle)}\n`);
  const digest = createHash('sha256').update(bytes).digest('hex');
  const file = path.join(root, 'native-review.json');
  await fs.writeFile(file, bytes);
  return {root, profile, caseId, file, digest, env: {QUALIFY_NATIVE_REVIEW_FILE: file,
    QUALIFY_NATIVE_REVIEW_SHA256: digest, QUALIFY_NATIVE_REVIEW_APPROVED: 'true'}};
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

test('blank workflow review outputs are treated as no review configuration', async t => {
  const root = await fixture(t);
  const evidence = await nativeEvidence(root, sha, true, {
    QUALIFY_NATIVE_REVIEW_SHA256: '', QUALIFY_NATIVE_REVIEW_APPROVED: '',
  });
  assert.equal(evidence.executionPassed, true);
  assert.equal(evidence.review.used, false);
  assert.equal(evidence.review.manifestSha256, null);
  assert.equal(evidence.review.appliedCount, 0);
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

test('native evidence fails closed when a case has no semantic snapshot', async t => {
  const root = await fixture(t);
  const location = path.join(root, profiles[0], 'audit.json');
  const report = JSON.parse(await fs.readFile(location, 'utf8'));
  delete report.results[0].semantics;
  await fs.writeFile(location, JSON.stringify(report));
  const evidence = await nativeEvidence(root, sha, true);
  assert.equal(evidence.executionPassed, false);
  assert.match(evidence.results.find(result => result.profile === profiles[0]).error, /semantic snapshot/);
});

test('an approved hash-bound review accepts only the matching full evidence finding', async t => {
  const f = await reviewedFixture(t);
  const evidence = await nativeEvidence(f.root, sha, false, f.env);
  const profile = evidence.results.find(result => result.profile === f.profile);
  assert.equal(evidence.executionPassed, true);
  assert.equal(profile.rawPassed, false);
  assert.equal(profile.passed, true);
  assert.equal(profile.reviewedExceptions.length, 1);
  assert.equal(profile.unresolvedIssues.length, 0);
  assert.equal(profile.report.results.find(result => result.id === f.caseId).passed, false);
  assert.deepEqual(evidence.review, {used: true, manifestSha256: f.digest, appliedCount: 1,
    applied: profile.reviewedExceptions, unresolvedCount: 0});
});

test('a review without approval cannot waive an accessibility finding', async t => {
  const f = await reviewedFixture(t);
  f.env.QUALIFY_NATIVE_REVIEW_APPROVED = 'false';
  const evidence = await nativeEvidence(f.root, sha, false, f.env);
  assert.equal(evidence.executionPassed, false);
  assert.match(evidence.reviewError, /explicit approval/);
  const profile = evidence.results.find(result => result.profile === f.profile);
  assert.equal(profile.rawPassed, false);
  assert.equal(profile.passed, false);
  assert.equal(profile.reviewedExceptions.length, 0);
  assert.equal(profile.unresolvedIssues.length, 1);
});

test('a stale review digest cannot waive an accessibility finding', async t => {
  const f = await reviewedFixture(t);
  f.env.QUALIFY_NATIVE_REVIEW_SHA256 = 'b'.repeat(64);
  const evidence = await nativeEvidence(f.root, sha, false, f.env);
  assert.equal(evidence.executionPassed, false);
  assert.match(evidence.reviewError, /SHA-256/);
});

test('review exceptions cannot be applied in smoke mode', async t => {
  const f = await reviewedFixture(t);
  const evidence = await nativeEvidence(f.root, sha, true, f.env);
  assert.equal(evidence.executionPassed, false);
  assert.match(evidence.reviewError, /full qualification/);
});

test('review entries fail closed when the capture manifest context is absent', async t => {
  const f = await reviewedFixture(t);
  await fs.rm(path.join(f.root, 'capture', 'manifest.json'));
  const evidence = await nativeEvidence(f.root, sha, false, f.env);
  assert.equal(evidence.executionPassed, false);
  assert.match(evidence.reviewError, /manifest.json/);
});

test('a review does not bypass framework errors in the same case', async t => {
  const f = await reviewedFixture(t);
  const reportPath = path.join(f.root, f.profile, 'audit.json');
  const report = JSON.parse(await fs.readFile(reportPath, 'utf8'));
  report.results.find(result => result.id === f.caseId).frameworkErrors = ['Flutter framework exception'];
  await fs.writeFile(reportPath, JSON.stringify(report));
  const evidence = await nativeEvidence(f.root, sha, false, f.env);
  const profile = evidence.results.find(result => result.profile === f.profile);
  assert.equal(evidence.executionPassed, false);
  assert.equal(profile.rawPassed, false);
  assert.equal(profile.passed, false);
  assert.equal(profile.report.results.find(result => result.id === f.caseId).frameworkErrors.length, 1);
});

test('a review bound to changed screenshot, semantics or issue remains unused', async t => {
  for (const changed of ['screenshot', 'semantics', 'issue']) {
    const f = await reviewedFixture(t);
    const reportPath = path.join(f.root, f.profile, 'audit.json');
    const report = JSON.parse(await fs.readFile(reportPath, 'utf8'));
    const sample = report.results.find(result => result.id === f.caseId);
    if (changed === 'screenshot') {
      await fs.writeFile(path.join(f.root, f.profile, `${f.caseId}.png`),
        await sharp({create: {width: 31, height: 32, channels: 4, background: '#fff'}}).png().toBuffer());
    } else if (changed === 'semantics') sample.semantics = {label: 'Different page', children: []};
    else sample.issues = [{...issue, detail: `${issue.detail} changed`}];
    await fs.writeFile(reportPath, JSON.stringify(report));
    const evidence = await nativeEvidence(f.root, sha, false, f.env);
    assert.equal(evidence.executionPassed, false, changed);
    assert.match(evidence.reviewError, /Unused review entries/, changed);
    assert.equal(evidence.review.appliedCount, 0, changed);
  }
});

test('an approved ERROR cannot hide an unknown blocking issue in the same case', async t => {
  const f = await reviewedFixture(t);
  const reportPath = path.join(f.root, f.profile, 'audit.json');
  const report = JSON.parse(await fs.readFile(reportPath, 'utf8'));
  report.results.find(result => result.id === f.caseId).issues.push({type: 'UNKNOWN', description: 'Unclassified native failure'});
  await fs.writeFile(reportPath, JSON.stringify(report));
  const evidence = await nativeEvidence(f.root, sha, false, f.env);
  const profile = evidence.results.find(result => result.profile === f.profile);
  assert.equal(evidence.executionPassed, false);
  assert.equal(profile.rawPassed, false);
  assert.equal(profile.passed, false);
  assert.equal(profile.reviewedExceptions.length, 1);
  assert.equal(profile.unresolvedIssues.length, 1);
  assert.equal(profile.unresolvedIssues[0].issue.type, 'UNKNOWN');
});

test('explicit warning findings do not fail a native profile', async t => {
  const root = await fixture(t);
  const location = path.join(root, profiles[0], 'audit.json');
  const report = JSON.parse(await fs.readFile(location, 'utf8'));
  report.results[0].issues = [{type: 'WARNING', description: 'Advisory finding'}];
  await fs.writeFile(location, JSON.stringify(report));
  const evidence = await nativeEvidence(root, sha, true);
  assert.equal(evidence.executionPassed, true);
  const profile = evidence.results.find(result => result.profile === profiles[0]);
  assert.equal(profile.rawPassed, true);
  assert.equal(profile.passed, true);
  assert.equal(profile.unresolvedIssues.length, 1);
});

test('findings remain unresolved and block evidence when no review is configured', async t => {
  const f = await reviewedFixture(t);
  const evidence = await nativeEvidence(f.root, sha);
  const profile = evidence.results.find(result => result.profile === f.profile);
  assert.equal(evidence.executionPassed, false);
  assert.equal(evidence.review.used, false);
  assert.equal(profile.rawPassed, false);
  assert.equal(profile.passed, false);
  assert.equal(profile.unresolvedIssues.length, 1);
  assert.equal(evidence.review.unresolvedCount, 1);
});

test('complete full collection emits a pending candidate that cannot be consumed as an approved bundle', async t => {
  const f = await reviewedFixture(t);
  const evidence = await nativeEvidence(f.root, sha);
  const candidates = await pendingReviewCandidates(f.root, evidence, sha);
  assert.equal(candidates.entries.length, 1);
  assert.equal(candidates.kind, 'native-accessibility-review-candidates');
  assert.equal(candidates.entries[0].disposition, 'pending');
  const bytes = Buffer.from(JSON.stringify(candidates));
  const digest = createHash('sha256').update(bytes).digest('hex');
  assert.throws(() => parseReviewBundle(bytes, digest, sha, true), /Review bundle/);
});

test('pending candidates are not emitted from an incomplete collection or framework failure', async t => {
  const f = await reviewedFixture(t);
  const evidence = await nativeEvidence(f.root, sha);
  evidence.results[0].collectionPassed = false;
  assert.equal(await pendingReviewCandidates(f.root, evidence, sha), null);
  evidence.results[0].collectionPassed = true;
  evidence.results[0].frameworkErrors = 1;
  assert.equal(await pendingReviewCandidates(f.root, evidence, sha), null);
});
