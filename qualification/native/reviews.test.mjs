import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {
  assertReviewConsumption,
  canonicalJson,
  issueFingerprint,
  parseReviewBundle,
  pendingEntry,
  reviewCase,
  validateReviewFile,
} from './reviews.mjs';

const candidateSha = 'a'.repeat(40);
const context = {
  candidateSha,
  profile: 'ios-phone',
  caseId: 'wall-en-dark',
  environment: {os: 'iOS 27.0', runtime: 'iPhone 17', toolchain: 'xcode-27.0'},
  screenshot: Buffer.from('PNG fixture bytes'),
  semantics: {type: 0, label: '', children: [{type: 46, label: ''}]},
};

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function issue(overrides = {}) {
  return {
    type: 'ERROR',
    auditType: 8,
    description: 'Element has no description',
    detail: 'FlutterSemanticsScrollView has no accessibility label.',
    identifier: '',
    element: {
      type: 46,
      identifier: '',
      label: '',
      frame: {x: 12, y: 24, width: 360, height: 720},
      debugDescription: 'volatile XCTest object dump',
    },
    ...overrides,
  };
}

function entryFor(evidence = context, finding = issue(), overrides = {}) {
  return {
    id: 'review-wall-en-dark-scroll',
    profile: evidence.profile,
    caseId: evidence.caseId,
    candidateSha: evidence.candidateSha,
    environmentSha256: sha256(Buffer.from(canonicalJson(evidence.environment))),
    screenshotSha256: sha256(evidence.screenshot),
    semanticsSha256: sha256(Buffer.from(canonicalJson(evidence.semantics))),
    issueSha256: issueFingerprint(finding),
    disposition: 'framework-false-positive',
    rationale: 'The flagged node is Flutter’s generated iOS accessibility scroll proxy; its child controls remain separately exposed.',
    reviewer: 'Accessibility reviewer',
    reviewedAt: '2026-10-31T12:00:00Z',
    ...overrides,
  };
}

function bundleBytes(entries, overrides = {}) {
  return Buffer.from(JSON.stringify({
    schemaVersion: 1,
    kind: 'native-accessibility-reviews',
    candidateSha,
    entries,
    ...overrides,
  }));
}

function parse(bytes, {approved = true, candidate = candidateSha, digest = sha256(bytes)} = {}) {
  return parseReviewBundle(bytes, digest, candidate, approved);
}

function review(bundle, evidence = context, issues = [issue()]) {
  return reviewCase({bundle, ...evidence, issues});
}

test('canonical JSON sorts object keys recursively without changing array order', () => {
  assert.equal(canonicalJson({z: 1, nested: {b: 2, a: 1}, a: 3}), '{"a":3,"nested":{"a":1,"b":2},"z":1}');
  assert.notEqual(canonicalJson([1, 2]), canonicalJson([2, 1]));
  const specialKeys = JSON.parse('{"__proto__":{"z":1,"a":2},"constructor":"ctor","prototype":"proto"}');
  assert.equal(
    canonicalJson(specialKeys),
    '{"__proto__":{"a":2,"z":1},"constructor":"ctor","prototype":"proto"}',
  );
});

test('approved bundle binds the exact source, environment, pixels, semantics and issue', () => {
  const finding = issue();
  const original = structuredClone(finding);
  const bytes = bundleBytes([entryFor(context, finding)]);
  const parsed = parse(bytes);
  const result = review(parsed, context, [finding]);

  assert.equal(parsed.manifestSha256, sha256(bytes));
  assert.equal(result.applied.length, 1);
  assert.equal(result.applied[0].issueIndex, 0);
  assert.equal(result.applied[0].issueSha256, issueFingerprint(finding));
  assert.deepEqual(result.unresolvedIssues, []);
  assert.deepEqual(finding, original, 'applying a review must not mutate raw findings');
  assert.equal(assertReviewConsumption(parsed, result.applied), true);
});

test('volatile debugDescription is excluded, while labels, geometry and issue fields stay bound', () => {
  const finding = issue();
  const parsed = parse(bundleBytes([entryFor(context, finding)]));
  const onlyDebugTextChanged = issue({element: {...finding.element, debugDescription: 'new volatile dump'}});
  assert.equal(issueFingerprint(finding), issueFingerprint(onlyDebugTextChanged));
  assert.equal(review(parsed, context, [onlyDebugTextChanged]).applied.length, 1);

  for (const changed of [
    issue({element: {...finding.element, label: 'List'}}),
    issue({element: {...finding.element, type: 47}}),
    issue({element: {...finding.element, frame: {...finding.element.frame, width: 361}}}),
    issue({detail: `${finding.detail} Changed.`}),
    issue({auditType: 7}),
  ]) {
    const result = review(parsed, context, [changed]);
    assert.equal(result.applied.length, 0);
    assert.equal(result.unresolvedIssues[0], changed);
  }
});

test('source, environment, screenshot and semantics changes prevent a review from applying', () => {
  const finding = issue();
  const parsed = parse(bundleBytes([entryFor(context, finding)]));
  const cases = [
    {...context, environment: {...context.environment, toolchain: 'xcode-next'}},
    {...context, screenshot: Buffer.from('different screenshot bytes')},
    {...context, semantics: {...context.semantics, children: [{type: 46, label: 'Changed'}]}},
  ];
  for (const evidence of cases) {
    const result = review(parsed, evidence, [finding]);
    assert.equal(result.applied.length, 0);
    assert.deepEqual(result.unresolvedIssues, [finding]);
  }
  assert.throws(() => review(parsed, {...context, candidateSha: 'b'.repeat(40)}, [finding]), /does not match candidate/);
});

test('only the explicitly supported iOS scroll-proxy description issue can be reviewed', () => {
  const supported = issue();
  const parsed = parse(bundleBytes([entryFor(context, supported)]));
  const detector = {...supported, type: 'DETECTOR'};
  const unknownAudit = {...supported, auditType: 3};
  const differentDescription = {...supported, description: 'Button has no label'};
  const missingElement = {...supported, element: null};
  const badFrame = {...supported, element: {...supported.element, frame: {...supported.element.frame, width: 0}}};
  const result = review(parsed, context, [detector, unknownAudit, differentDescription, missingElement, badFrame]);
  assert.deepEqual(result.applied, []);
  assert.deepEqual(result.unresolvedIssues, [detector, unknownAudit, differentDescription, missingElement, badFrame]);
  assert.throws(() => issueFingerprint({...supported, unknown: 'field'}), /unknown fields/);
});

test('iOS review entries cannot approve Android findings or be generated for Android', () => {
  const finding = issue();
  const parsed = parse(bundleBytes([entryFor(context, finding)]));
  const androidContext = {...context, profile: 'android-phone'};
  const result = review(parsed, androidContext, [finding]);
  assert.deepEqual(result.applied, []);
  assert.deepEqual(result.unresolvedIssues, [finding]);
  assert.throws(() => pendingEntry(androidContext, finding, 0), /restricted to supported iOS profiles/);
  assert.throws(() => parse(bundleBytes([entryFor(androidContext, finding)])), /must be a supported iOS profile/);
  assert.throws(() => parse(bundleBytes([entryFor({...context, profile: 'ios-*'}, finding)])), /must be a supported iOS profile/);
});

test('review application requires complete context and evidence', () => {
  const finding = issue();
  const parsed = parse(bundleBytes([entryFor(context, finding)]));
  assert.throws(() => review(parsed, {...context, environment: {}}, [finding]), /environment must not be empty/);
  assert.throws(() => review(parsed, {...context, screenshot: Buffer.alloc(0)}, [finding]), /screenshot must not be empty/);
  assert.throws(() => review(parsed, {...context, semantics: {}}, [finding]), /semantics must not be empty/);
});

test('pending entries are useful records but never valid approved bundle entries', () => {
  const pending = pendingEntry(context, issue(), 2);
  assert.equal(pending.disposition, 'pending');
  assert.equal(pending.issueSha256, issueFingerprint(issue()));
  assert.equal(pending.reviewer, null);
  assert.throws(() => parse(bundleBytes([pending])), /Only framework-false-positive entries are accepted/);
  assert.throws(() => pendingEntry(context, {...issue(), auditType: 2}, 0), /Only the supported/);
});

test('pending IDs are unique by full case binding and both reviewed cases can be validated', () => {
  const firstPending = pendingEntry(context, issue(), 0);
  const secondContext = {...context, profile: 'ios-tablet', caseId: 'calendar-en-dark'};
  const secondPending = pendingEntry(secondContext, issue(), 0);
  assert.notEqual(firstPending.id, secondPending.id);
  const entries = [firstPending, secondPending].map(pending => ({
    ...pending,
    disposition: 'framework-false-positive',
    rationale: 'Reviewed scroll proxy finding.',
    reviewer: 'Accessibility reviewer',
    reviewedAt: '2026-10-31T12:00:00Z',
  }));
  assert.equal(parse(bundleBytes(entries)).entries.length, 2);
});

test('bundle parsing rejects unapproved entries, wrong digests, stale source and malformed schemas', () => {
  const bytes = bundleBytes([entryFor()]);
  assert.throws(() => parse(bytes, {approved: false}), /explicit approval/);
  assert.throws(() => parse(bytes, {digest: '0'.repeat(64)}), /does not match expected digest/);
  assert.throws(() => parse(bytes, {candidate: 'b'.repeat(40)}), /does not match candidate/);
  assert.throws(() => parse(Buffer.from('null')), /Review bundle must be a plain object/);
  assert.throws(() => parse(bundleBytes([], {kind: 'unknown'})), /Unsupported review bundle schema or kind/);
  assert.throws(() => parse(bundleBytes([entryFor()], {unexpected: true})), /missing or unknown fields/);
});

test('bundle parsing rejects duplicate IDs, duplicate targets, unknown entry fields and invalid timestamps', () => {
  const first = entryFor();
  assert.throws(() => parse(bundleBytes([first, {...first}])), /Duplicate review entry id/);
  assert.throws(() => parse(bundleBytes([first, {...first, id: 'another-id'}])), /Duplicate review target/);
  assert.throws(() => parse(bundleBytes([{...first, extra: true}])), /missing or unknown fields/);
  assert.throws(() => parse(bundleBytes([{...first, reviewedAt: 'not-a-date'}])), /valid ISO timestamp/);
  assert.throws(() => parse(bundleBytes([{...first, reviewedAt: '2026-02-31T12:00:00Z'}])), /valid ISO timestamp/);
  assert.throws(() => parse(bundleBytes([{...first, profile: 'ios-*'}])), /must be a supported iOS profile/);
  assert.throws(() => parse(bundleBytes([{...first, caseId: 'detector-bad'}])), /detector control/);
});

test('bundle byte and entry caps are checked before entry processing', () => {
  const oversized = Buffer.alloc(1024 * 1024 + 1);
  assert.throws(() => parseReviewBundle(oversized, sha256(oversized), candidateSha, true), /exceeds 1048576 bytes/);
  const tooManyEntries = bundleBytes(Array.from({length: 1001}, (_, index) => entryFor(context, issue(), {id: `review-${index}`})));
  assert.ok(tooManyEntries.byteLength < 1024 * 1024);
  assert.throws(() => parse(tooManyEntries), /exceeds 1000 entries/);
});

test('consumption rejects stale, unused, duplicate and modified applied entries', () => {
  const finding = issue();
  const parsed = parse(bundleBytes([entryFor(context, finding)]));
  const applied = review(parsed).applied;
  assert.throws(() => assertReviewConsumption(parsed, []), /Unused review entries/);
  assert.throws(() => assertReviewConsumption(parsed, [...applied, ...applied]), /consumed more than once/);
  assert.throws(() => assertReviewConsumption(parsed, [{...applied[0], issueIndex: -1}]), /invalid issue index/);
  assert.throws(() => assertReviewConsumption(parsed, [{...applied[0], rationale: 'edited'}]), /changed after parsing/);
  assert.throws(() => assertReviewConsumption(parsed, [{...applied[0], id: 'stale'}]), /not in bundle/);
});

test('file validation requires explicit approval and reports the verified manifest digest', async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-native-review-cli-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const bytes = bundleBytes([entryFor()]);
  const file = path.join(root, 'reviews.json');
  await fs.writeFile(file, bytes);
  const digest = sha256(bytes);
  await assert.rejects(validateReviewFile(file, digest, candidateSha, false), /explicit approval/);
  assert.deepEqual(await validateReviewFile(file, digest, candidateSha, true), {
    valid: true,
    candidateSha,
    manifestSha256: digest,
    entries: 1,
  });
});
