import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import sharp from 'sharp';
import { fileURLToPath } from 'node:url';
import { inventory } from '../matrix.mjs';
import { parseReviewBundle, reviewCase, assertReviewConsumption, pendingEntry } from './reviews.mjs';

export const profiles = ['ios-phone', 'ios-tablet', 'android-phone', 'android-tablet',
  'ios-phone-large', 'ios-tablet-large', 'android-phone-large', 'android-tablet-large', 'android-min-phone'];
export function expectedCases(profile, smoke = false) {
  return inventory.states.filter(s => s.native && (profile.includes('tablet') || !['kid', 'kiosk'].includes(s.scenario)))
    .flatMap(s => (smoke ? ['de'] : inventory.locales).flatMap(locale =>
      (smoke ? ['light'] : ['light', 'dark']).map(shade => `${s.id}-${locale}-${shade}`)));
}
export function hasReviewConfiguration(env) {
  return ['QUALIFY_NATIVE_REVIEW_FILE', 'QUALIFY_NATIVE_REVIEW_SHA256', 'QUALIFY_NATIVE_REVIEW_APPROVED']
    .some(key => env[key] !== undefined && env[key] !== null && env[key] !== '');
}
async function loadReview(root, candidateSha, smoke, env) {
  const file = env.QUALIFY_NATIVE_REVIEW_FILE;
  const digest = env.QUALIFY_NATIVE_REVIEW_SHA256;
  const approved = env.QUALIFY_NATIVE_REVIEW_APPROVED === 'true';
  const configured = hasReviewConfiguration(env);
  const state = {used: configured, manifestSha256: null, applied: [], unresolvedCount: 0,
    bundle: null, environment: null, error: null};
  if (!configured) return state;
  try {
    assert.ok(file && digest && env.QUALIFY_NATIVE_REVIEW_APPROVED !== undefined,
      'Native review file, digest and approval state must be supplied together');
    assert.ok(!smoke, 'Native accessibility reviews are restricted to full qualification');
    const bytes = await fs.readFile(file);
    state.bundle = parseReviewBundle(bytes, digest, candidateSha, approved);
    state.manifestSha256 = state.bundle.manifestSha256;
    if (state.bundle.entries.length > 0) {
      const manifest = JSON.parse(await fs.readFile(path.join(root, 'capture', 'manifest.json'), 'utf8'));
      assert.equal(manifest.schema, 1);
      assert.equal(manifest.kind, 'native');
      assert.equal(manifest.sourceSha, candidateSha);
      assert.ok(manifest.environment && typeof manifest.environment === 'object' && !Array.isArray(manifest.environment));
      state.environment = manifest.environment;
    }
  } catch (error) {
    state.error = String(error);
    state.bundle = null;
  }
  return state;
}

export async function nativeEvidence(root, candidateSha, smoke = false, reviewEnv = process.env) {
  const review = await loadReview(root, candidateSha, smoke, reviewEnv);
  const appliedEntries = [];
  const unresolvedAll = [];
  const results = [];
  const statuses = await fs.readFile(path.join(root, 'profiles.txt'), 'utf8').catch(() => '');
  for (const profile of profiles) {
    try {
      const expected = expectedCases(profile, smoke);
      const report = JSON.parse(await fs.readFile(path.join(root, profile, 'audit.json'), 'utf8'));
      const render = JSON.parse(await fs.readFile(path.join(root, profile, 'results.json'), 'utf8'));
      assert.equal(report.schemaVersion, 1);
      assert.equal(report.candidateSha, candidateSha);
      assert.equal(render.candidateSha, candidateSha);
      assert.equal(report.done, true);
      assert.equal(report.expected, expected.length + 2);
      assert.equal(report.results.length, report.expected);
      assert.equal(new Set(report.results.map(r => r.id)).size, report.expected);
      assert.deepEqual(report.results.map(r => r.id).sort(), [...expected, 'detector-bad', 'detector-keyboard'].sort());
      const detectorsPassed = ['detector-bad', 'detector-keyboard'].every(id => {
        const result = report.results.find(r => r.id === id);
        return result?.passed === true && Array.isArray(result.frameworkErrors) && result.frameworkErrors.length === 0;
      });
      assert.ok(render.logicalWidth > 0 && render.logicalHeight > 0 && render.devicePixelRatio > 0, 'Missing native render geometry');
      assert.equal(render.logicalWidth >= 600, profile.includes('tablet'), 'Native phone/tablet geometry differs from its profile');
      assert.equal(render.expected, expected.length);
      assert.equal(render.captured, expected.length);
      const pngs = (await fs.readdir(path.join(root, profile))).filter(p => p.endsWith('.png'));
      assert.deepEqual(pngs.sort(), expected.map(id => `${id}.png`).sort());
      for (const name of pngs) {
        const bytes = await fs.readFile(path.join(root, profile, name));
        assert.ok(bytes.length > 24 && bytes.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')), `Invalid PNG: ${name}`);
        const image = await sharp(bytes).metadata();
        assert.ok(image.format === 'png' && image.width > 0 && image.height > 0, `Invalid PNG geometry: ${name}`);
      }
      const largeTextPassed = !profile.endsWith('-large') || report.results.every(r => typeof r.textScale === 'number' && r.textScale >= 1.5);
      const executionPassed = statuses.split('\n').filter(line => line === `${profile}: PASS`).length === 1 &&
        !statuses.split('\n').includes(`${profile}: FAIL`);
      const reviewedExceptions = [];
      const unresolvedIssues = [];
      let rawCasesPassed = true;
      let casesPassed = true;
      for (const id of expected) {
        const sample = report.results.find(r => r.id === id);
        assert.ok(Array.isArray(sample.frameworkErrors), `Missing framework error evidence: ${profile}/${id}`);
        assert.ok(Array.isArray(sample.issues), `Missing native issues: ${profile}/${id}`);
        assert.ok(sample.semantics && typeof sample.semantics === 'object' && !Array.isArray(sample.semantics) &&
          Object.keys(sample.semantics).length > 0, `Missing native semantic snapshot: ${profile}/${id}`);
        const issues = sample.issues;
        assert.ok(Array.isArray(issues), `Invalid native issues: ${profile}/${id}`);
        const isNonblocking = issue => ['INFO', 'WARNING', 'NOT_RUN'].includes(issue?.type);
        const blockingIssues = issues.filter(issue => !isNonblocking(issue));
        const rawPassed = sample.passed === true && sample.frameworkErrors.length === 0 && blockingIssues.length === 0;
        let casePassed = rawPassed;
        let caseApplied = [];
        let remaining = issues;
        if (review.bundle && review.bundle.entries.length > 0) {
          try {
            const context = await reviewCase({bundle: review.bundle, candidateSha, profile, caseId: id,
              environment: review.environment, screenshot: await fs.readFile(path.join(root, profile, `${id}.png`)),
              semantics: sample.semantics, issues});
            caseApplied = context.applied;
            remaining = context.unresolvedIssues;
            const unresolvedBlocking = remaining.filter(issue => !isNonblocking(issue));
            const appliedIndexes = new Set(caseApplied.map(entry => entry.issueIndex));
            const fullyReviewed = blockingIssues.length > 0 && blockingIssues.every(issue => issue?.type === 'ERROR') &&
              caseApplied.length === blockingIssues.length && appliedIndexes.size === blockingIssues.length &&
              unresolvedBlocking.length === 0;
            if (fullyReviewed && sample.frameworkErrors.length === 0 && sample.passed === false) casePassed = true;
            appliedEntries.push(...caseApplied);
            reviewedExceptions.push(...caseApplied);
          } catch (error) {
            review.error ??= `${profile}/${id}: ${String(error)}`;
            remaining = issues;
          }
        }
        if (!review.bundle || review.bundle.entries.length === 0) remaining = issues;
        rawCasesPassed &&= rawPassed;
        casesPassed &&= casePassed;
        for (const issue of remaining) unresolvedIssues.push({caseId: id, issue});
      }
      unresolvedAll.push(...unresolvedIssues.map(item => ({profile, ...item})));
      const rawPassed = executionPassed && largeTextPassed && detectorsPassed && rawCasesPassed;
      const passed = executionPassed && largeTextPassed && detectorsPassed && casesPassed && !review.error;
      const frameworkErrors = report.results.reduce((count, result) =>
        count + (Array.isArray(result.frameworkErrors) ? result.frameworkErrors.length : 1), 0);
      results.push({profile, supported: true, collectionPassed: executionPassed, rawPassed, passed,
        detectorsPassed, largeTextPassed, frameworkErrors,
        reviewedExceptions, unresolvedIssues, captures: pngs.length, cases: report.expected, report});
    } catch (error) {
      results.push({profile, supported: false, collectionPassed: false, rawPassed: false, passed: false,
        detectorsPassed: false, largeTextPassed: false, frameworkErrors: 1, captures: 0, cases: 0,
        reviewedExceptions: [], unresolvedIssues: [], error: String(error)});
    }
  }
  if (review.bundle) {
    try {
      assertReviewConsumption(review.bundle, appliedEntries);
    } catch (error) {
      review.error ??= String(error);
    }
  }
  if (review.error) for (const result of results) result.passed = false;
  const aggregate = platform => {
    const entries = results.filter(r => r.profile.startsWith(platform));
    return {supported: entries.every(r => r.supported), detectorsPassed: entries.every(r => r.detectorsPassed),
      passed: entries.every(r => r.passed), cases: entries.reduce((n, r) => n + r.cases, 0)};
  };
  const visual = await fs.readFile(path.join(root, 'visual.json'), 'utf8').then(JSON.parse).catch(error => ({passed: false, error: String(error)}));
  if (visual.candidateSha !== candidateSha) visual.passed = false;
  const reviewMetadata = {used: review.used, manifestSha256: review.manifestSha256,
    appliedCount: appliedEntries.length, applied: appliedEntries, unresolvedCount: unresolvedAll.length};
  return {schemaVersion: 1, candidateSha, visual, profile: smoke ? 'smoke' : 'full', review: reviewMetadata,
    ...(review.error ? {reviewError: review.error} : {}),
    executionPassed: results.every(r => r.passed), captures: results.reduce((n, r) => n + r.captures, 0),
    audits: {android: aggregate('android'), ios: aggregate('ios')}, results,
    limitations: ['Native automated audit results require VoiceOver/TalkBack physical-device review.',
      'Native visual comparison uses exact RGBA equality until native raster noise is measured and a reviewed policy is approved.',
      'iOS Display Zoom and assistive-technology interaction require physical-device review.',
      'ATF contrast results may be NOT_RUN for Flutter virtual nodes; Flutter contrast and browser image checks remain separate required gates.']};
}

export async function pendingReviewCandidates(root, evidence, candidateSha) {
  if (evidence.profile !== 'full' || evidence.results.length !== profiles.length ||
      evidence.results.some(result => !result.supported || !result.collectionPassed || !result.detectorsPassed ||
        !result.largeTextPassed || result.frameworkErrors !== 0)) return null;
  const manifestBytes = await fs.readFile(path.join(root, 'capture', 'manifest.json'));
  const manifest = JSON.parse(manifestBytes);
  assert.equal(manifest.schema, 1);
  assert.equal(manifest.kind, 'native');
  assert.equal(manifest.sourceSha, candidateSha);
  assert.ok(manifest.environment && typeof manifest.environment === 'object' && !Array.isArray(manifest.environment));
  const entries = [];
  for (const result of evidence.results) {
    for (const caseId of expectedCases(result.profile, false)) {
      const sample = result.report.results.find(item => item.id === caseId);
      if (!sample || !sample.semantics || !Array.isArray(sample.issues)) continue;
      const screenshot = await fs.readFile(path.join(root, result.profile, `${caseId}.png`));
      for (let issueIndex = 0; issueIndex < sample.issues.length; issueIndex++) {
        try {
          entries.push(pendingEntry({candidateSha, profile: result.profile, caseId,
            environment: manifest.environment, screenshot, semantics: sample.semantics}, sample.issues[issueIndex], issueIndex));
        } catch {
          // Only the review module's explicitly supported finding shape is eligible.
        }
      }
    }
  }
  return {schemaVersion: 1, kind: 'native-accessibility-review-candidates', candidateSha,
    nativeManifestSha256: createHash('sha256').update(manifestBytes).digest('hex'),
    environment: manifest.environment, entries};
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const root = path.resolve('build/qualification/native');
  const evidence = await nativeEvidence(root, process.env.QUALIFY_CANDIDATE_SHA, process.env.QUALIFY_NATIVE_SMOKE === 'true');
  await fs.mkdir(root, {recursive: true});
  await fs.writeFile(path.join(root, 'evidence.json'), `${JSON.stringify(evidence, null, 2)}\n`);
  const reviewConfigured = hasReviewConfiguration(process.env);
  if (!reviewConfigured && process.env.QUALIFY_NATIVE_SMOKE !== 'true') {
    const candidates = await pendingReviewCandidates(root, evidence, process.env.QUALIFY_CANDIDATE_SHA).catch(() => null);
    const candidatePath = path.join(root, 'native-review-candidates.json');
    if (candidates) await fs.writeFile(candidatePath, `${JSON.stringify(candidates, null, 2)}\n`);
    else await fs.rm(candidatePath, {force: true});
  }
  if (!evidence.executionPassed) process.exitCode = 1;
}
