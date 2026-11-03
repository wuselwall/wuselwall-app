import assert from 'node:assert/strict';
import { test } from 'node:test';
import { summarize, flutterCaseIds } from './summarize.mjs';
import { cases } from './matrix.mjs';
const sha = 'a'.repeat(40);
const coverage = { states: [{ id: 'fixture', route: '/', scenario: 'adult', widths: [390] }],
  locales: ['de'], shades: ['light'], pendingRoutes: {}, openGates: ['physical-device-review'] };
function complete() {
  const count = 2 * (cases('canonical', coverage).length + 2 * cases('responsive', coverage).length);
  const webCount = cases('full', coverage).length + 1;
  return { sha, coverage, matrix: 'full', mode: 'compare',
    jobs: Object.fromEntries(['prepare', 'flutter', 'web', 'native', 'production'].map(n => [n, { result: 'success' }])),
    reports: {
      flutter: { matrix: 'full', expected: count, executed: count, results: flutterCaseIds(coverage).map(id => ({ id, status: 'PASS', findings: [] })) },
      web: { candidateSha: sha, matrix: 'full', mode: 'compare', baselineVerified: true, executionPassed: true,
        expected: webCount, stats: { expected: webCount, unexpected: 0, flaky: 0, skipped: 0 } },
      native: { candidateSha: sha, profile: 'full', executionPassed: true,
        visual: { mode: 'compare', passed: true, checked: 8, manifestDigest: 'a'.repeat(64) },
        audits: Object.fromEntries(['android', 'ios'].map(n => [n, { supported: true, passed: true, detectorsPassed: true, cases: 8 }])) },
      production: { candidateSha: sha, executionPassed: true, entryPoint: 'lib/main.dart' },
    } };
}
test('complete evidence enables human review, never automatic qualification', () => {
  const result = summarize(complete());
  assert.equal(result.qualification, 'READY_FOR_REVIEW');
  assert.equal(result.automaticPass, true);
  assert.equal(result.qualified, false);
});
test('missing reports, filtered suites, failures and open implementation gates block review', () => {
  for (const mutate of [
    c => { c.matrix = 'canonical'; }, c => { c.mode = 'capture'; },
    c => { c.reports.flutter.executed--; }, c => { c.reports.flutter.results[0].status = 'FAIL'; },
    c => { c.reports.flutter.results[1].id = c.reports.flutter.results[0].id; },
    c => { c.reports.web.stats.skipped = 1; }, c => { c.reports.web.candidateSha = 'b'.repeat(40); },
    c => { c.reports.native.audits.android.detectorsPassed = false; },
    c => { c.reports.native.audits.ios.supported = false; },
    c => { c.reports.native.visual.passed = false; },
    c => { c.jobs.native.result = 'skipped'; }, c => { c.reports.production = null; },
    c => { c.coverage = { ...coverage, pendingRoutes: { missing: {} } }; },
    c => { c.coverage = { ...coverage, openGates: ['native-platform-audits'] }; },
  ]) {
    const c = complete(); mutate(c);
    assert.equal(summarize(c).automaticPass, false);
  }
});

function withReviewedFinding() {
  const c = complete();
  c.reports.native.review = {used: true, manifestSha256: 'c'.repeat(64), appliedCount: 1,
    applied: [{id: 'scroll-proxy', profile: 'ios-phone', caseId: 'today-de-light', issueSha256: 'd'.repeat(64)}]};
  c.jobs.review_approval = {result: 'success', outputs: {approved: 'true', manifest_sha256: 'c'.repeat(64)}};
  return c;
}

test('reviewed exceptions retain protected approval provenance and never automatically qualify', () => {
  const result = summarize(withReviewedFinding());
  assert.equal(result.automaticPass, true);
  assert.equal(result.qualified, false);
  assert.equal(result.accessibilityReview.appliedCount, 1);
  assert.equal(result.accessibilityReview.manifestSha256, 'c'.repeat(64));
});

test('reviewed exceptions cannot bypass missing approval, changed manifests, invalid records or failed execution', () => {
  for (const mutate of [
    c => { delete c.jobs.review_approval; },
    c => { c.jobs.review_approval.result = 'skipped'; },
    c => { c.jobs.review_approval.outputs.approved = 'false'; },
    c => { c.jobs.review_approval.outputs.manifest_sha256 = 'e'.repeat(64); },
    c => { c.reports.native.review.appliedCount = 2; },
    c => { c.reports.native.review.applied = [null]; },
    c => { c.reports.native.review.applied[0].caseId = 'detector-bad'; },
    c => { c.reports.native.review.used = false; },
    c => { delete c.reports.native.review; },
    c => { c.reports.native.executionPassed = false; },
    c => { c.jobs.native.result = 'failure'; },
  ]) {
    const c = withReviewedFinding(); mutate(c);
    assert.equal(summarize(c).automaticPass, false);
  }
});
