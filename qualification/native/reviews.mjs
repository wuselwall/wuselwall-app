import {createHash} from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const bundleKeys = ['candidateSha', 'entries', 'kind', 'schemaVersion'];
const entryKeys = [
  'candidateSha', 'caseId', 'disposition', 'environmentSha256', 'id', 'issueSha256',
  'profile', 'rationale', 'reviewedAt', 'reviewer', 'screenshotSha256', 'semanticsSha256',
];
const issueKeys = ['auditType', 'description', 'detail', 'element', 'identifier', 'type'];
const elementKeys = ['debugDescription', 'frame', 'identifier', 'label', 'type'];
const frameKeys = ['height', 'width', 'x', 'y'];
const acceptedDisposition = 'framework-false-positive';
const maxBundleBytes = 1024 * 1024;
const maxEntries = 1000;
const reviewableIosProfiles = new Set([
  'ios-phone', 'ios-tablet', 'ios-phone-large', 'ios-tablet-large',
]);
const parsedBundles = new WeakSet();

function fail(message) {
  throw new Error(message);
}

function assertRecord(value, name) {
  if (value === null || typeof value !== 'object' || Array.isArray(value) || Object.getPrototypeOf(value) !== Object.prototype) {
    fail(`${name} must be a plain object`);
  }
}

function assertExactKeys(value, keys, name) {
  assertRecord(value, name);
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  if (actual.length !== expected.length || actual.some((key, index) => key !== expected[index])) {
    fail(`${name} has missing or unknown fields`);
  }
}

function nonemptyString(value, name) {
  if (typeof value !== 'string' || value.trim().length === 0) fail(`${name} must be a nonempty string`);
  return value;
}

function assertSha256(value, name) {
  if (typeof value !== 'string' || !/^[a-f0-9]{64}$/.test(value)) fail(`${name} must be a lowercase SHA-256 hex digest`);
}

function assertCandidateSha(value, name = 'candidateSha') {
  if (typeof value !== 'string' || !/^[a-f0-9]{40}$/.test(value)) fail(`${name} must be a full lowercase 40-character commit SHA`);
}

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function isJsonScalar(value) {
  return value === null || typeof value === 'string' || typeof value === 'boolean' ||
    (typeof value === 'number' && Number.isFinite(value));
}

function canonicalize(value, seen = new Set()) {
  if (isJsonScalar(value)) return value;
  if (typeof value !== 'object' || value === undefined) fail('Evidence must contain only finite JSON values');
  if (seen.has(value)) fail('Evidence must not contain cycles');
  seen.add(value);
  let result;
  if (Array.isArray(value)) {
    result = value.map(item => canonicalize(item, seen));
  } else {
    assertRecord(value, 'Evidence object');
    result = Object.create(null);
    for (const key of Object.keys(value).sort()) {
      if (value[key] === undefined) fail('Evidence must not contain undefined values');
      result[key] = canonicalize(value[key], seen);
    }
  }
  seen.delete(value);
  return result;
}

export function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function hashCanonical(value) {
  return sha256(Buffer.from(canonicalJson(value), 'utf8'));
}

function validIsoTimestamp(value) {
  if (typeof value !== 'string') return false;
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?(Z|[+-](\d{2}):(\d{2}))$/);
  if (!match || !Number.isFinite(Date.parse(value))) return false;
  const [, year, month, day, hour, minute, second, zone, offsetHour, offsetMinute] = match;
  const date = new Date(0);
  date.setUTCFullYear(Number(year), Number(month) - 1, Number(day));
  date.setUTCHours(Number(hour), Number(minute), Number(second), 0);
  if (date.getUTCFullYear() !== Number(year) || date.getUTCMonth() !== Number(month) - 1 ||
      date.getUTCDate() !== Number(day) || Number(hour) > 23 || Number(minute) > 59 || Number(second) > 59) return false;
  if (zone !== 'Z' && (Number(offsetHour) > 23 || Number(offsetMinute) > 59)) return false;
  return true;
}

function deepFreeze(value) {
  if (value !== null && typeof value === 'object' && !Object.isFrozen(value)) {
    for (const child of Object.values(value)) deepFreeze(child);
    Object.freeze(value);
  }
  return value;
}

function validateEntry(entry, bundleCandidateSha) {
  assertExactKeys(entry, entryKeys, 'Review entry');
  nonemptyString(entry.id, 'Review entry id');
  if (!/^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(entry.id)) fail('Review entry id has invalid characters');
  nonemptyString(entry.profile, 'Review entry profile');
  if (!reviewableIosProfiles.has(entry.profile)) fail('Review entry profile must be a supported iOS profile');
  nonemptyString(entry.caseId, 'Review entry caseId');
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(entry.caseId) || /^detector-/i.test(entry.caseId)) {
    fail('Review entry caseId is invalid or belongs to a detector control');
  }
  assertCandidateSha(entry.candidateSha, 'Review entry candidateSha');
  if (entry.candidateSha !== bundleCandidateSha) fail('Review entry candidateSha differs from bundle candidateSha');
  for (const field of ['environmentSha256', 'screenshotSha256', 'semanticsSha256', 'issueSha256']) {
    assertSha256(entry[field], `Review entry ${field}`);
  }
  if (entry.disposition !== acceptedDisposition) fail('Only framework-false-positive entries are accepted');
  nonemptyString(entry.rationale, 'Review entry rationale');
  nonemptyString(entry.reviewer, 'Review entry reviewer');
  if (!validIsoTimestamp(entry.reviewedAt)) fail('Review entry reviewedAt must be a valid ISO timestamp');
}

export function issueFingerprint(issue) {
  assertExactKeys(issue, issueKeys, 'Accessibility issue');
  assertExactKeys(issue.element, elementKeys, 'Accessibility issue element');
  const {debugDescription: _debugDescription, ...stableElement} = issue.element;
  return hashCanonical({...issue, element: stableElement});
}

function supportedIssue(issue) {
  try {
    assertExactKeys(issue, issueKeys, 'Accessibility issue');
    if (issue.type !== 'ERROR' || issue.auditType !== 8 || issue.description !== 'Element has no description') return false;
    if (typeof issue.detail !== 'string' || !issue.detail.includes('FlutterSemanticsScrollView')) return false;
    assertExactKeys(issue.element, elementKeys, 'Accessibility issue element');
    const element = issue.element;
    if (element.type !== 46 || element.label !== '' || element.identifier === null || typeof element.identifier !== 'string') return false;
    if (typeof element.debugDescription !== 'string' || element.debugDescription.length === 0) return false;
    assertExactKeys(element.frame, frameKeys, 'Accessibility issue frame');
    const {x, y, width, height} = element.frame;
    return [x, y, width, height].every(Number.isFinite) && width > 0 && height > 0;
  } catch {
    return false;
  }
}

function validateContext({candidateSha, profile, caseId, environment, screenshot, semantics}) {
  assertCandidateSha(candidateSha);
  nonemptyString(profile, 'profile');
  nonemptyString(caseId, 'caseId');
  assertRecord(environment, 'environment');
  if (Object.keys(environment).length === 0) fail('environment must not be empty');
  if (!Buffer.isBuffer(screenshot) && !(screenshot instanceof Uint8Array)) fail('screenshot must be bytes');
  if (screenshot.byteLength === 0) fail('screenshot must not be empty');
  assertRecord(semantics, 'semantics');
  if (Object.keys(semantics).length === 0) fail('semantics must not be empty');
  return {
    candidateSha,
    profile,
    caseId,
    environmentSha256: hashCanonical(environment),
    screenshotSha256: sha256(screenshot),
    semanticsSha256: hashCanonical(semantics),
  };
}

export function parseReviewBundle(bytes, expectedDigest, candidateSha, approved) {
  if (!Buffer.isBuffer(bytes) && !(bytes instanceof Uint8Array)) fail('Review bundle must be bytes');
  if (bytes.byteLength > maxBundleBytes) fail(`Review bundle exceeds ${maxBundleBytes} bytes`);
  assertSha256(expectedDigest, 'expectedDigest');
  assertCandidateSha(candidateSha);
  if (sha256(bytes) !== expectedDigest) fail('Review bundle SHA-256 does not match expected digest');
  let bundle;
  try {
    const decoded = new TextDecoder('utf-8', {fatal: true}).decode(bytes);
    bundle = JSON.parse(decoded);
  } catch (error) {
    fail(`Review bundle is not valid UTF-8 JSON: ${error.message}`);
  }
  assertExactKeys(bundle, bundleKeys, 'Review bundle');
  if (bundle.schemaVersion !== 1 || bundle.kind !== 'native-accessibility-reviews') fail('Unsupported review bundle schema or kind');
  assertCandidateSha(bundle.candidateSha, 'Bundle candidateSha');
  if (bundle.candidateSha !== candidateSha) fail('Review bundle candidateSha does not match candidate');
  if (!Array.isArray(bundle.entries)) fail('Review bundle entries must be an array');
  if (bundle.entries.length > maxEntries) fail(`Review bundle exceeds ${maxEntries} entries`);
  if (bundle.entries.length > 0 && approved !== true) fail('Active review entries require explicit approval');

  const ids = new Set();
  const targets = new Set();
  for (const entry of bundle.entries) {
    validateEntry(entry, candidateSha);
    if (ids.has(entry.id)) fail(`Duplicate review entry id: ${entry.id}`);
    ids.add(entry.id);
    const target = `${entry.profile}\0${entry.caseId}\0${entry.issueSha256}`;
    if (targets.has(target)) fail(`Duplicate review target: ${entry.profile}/${entry.caseId}`);
    targets.add(target);
  }
  bundle.manifestSha256 = expectedDigest;
  deepFreeze(bundle);
  parsedBundles.add(bundle);
  return bundle;
}

function assertParsedBundle(bundle) {
  if (bundle === null || typeof bundle !== 'object' || !parsedBundles.has(bundle)) {
    fail('Review bundle must be parsed by parseReviewBundle in this process');
  }
}

function sameBinding(entry, binding) {
  return entry.candidateSha === binding.candidateSha && entry.profile === binding.profile &&
    entry.caseId === binding.caseId && entry.environmentSha256 === binding.environmentSha256 &&
    entry.screenshotSha256 === binding.screenshotSha256 && entry.semanticsSha256 === binding.semanticsSha256;
}

export function reviewCase({bundle, candidateSha, profile, caseId, environment, screenshot, semantics, issues}) {
  assertParsedBundle(bundle);
  const binding = validateContext({candidateSha, profile, caseId, environment, screenshot, semantics});
  if (bundle.candidateSha !== candidateSha) fail('Review bundle does not match candidate');
  if (!Array.isArray(issues)) fail('issues must be an array');

  const applied = [];
  const consumed = new Set();
  const unresolvedIssues = [];
  issues.forEach((issue, issueIndex) => {
    if (!supportedIssue(issue)) {
      unresolvedIssues.push(issue);
      return;
    }
    const issueSha256 = issueFingerprint(issue);
    const match = bundle.entries.find(entry => sameBinding(entry, binding) && entry.issueSha256 === issueSha256);
    if (!match) {
      unresolvedIssues.push(issue);
      return;
    }
    if (consumed.has(match.id)) fail(`Review entry matched more than one issue: ${match.id}`);
    consumed.add(match.id);
    applied.push({...match, issueIndex, issueSha256});
  });
  return {binding, applied, unresolvedIssues};
}

export function assertReviewConsumption(bundle, appliedEntries) {
  assertParsedBundle(bundle);
  if (!Array.isArray(appliedEntries)) fail('appliedEntries must be an array');
  const byId = new Map(bundle.entries.map(entry => [entry.id, entry]));
  const consumed = new Set();
  for (const applied of appliedEntries) {
    assertRecord(applied, 'Applied review entry');
    const entry = byId.get(applied.id);
    if (!entry) fail(`Applied review entry is not in bundle: ${applied.id ?? '<missing id>'}`);
    if (consumed.has(applied.id)) fail(`Review entry consumed more than once: ${applied.id}`);
    const {issueIndex, ...candidateEntry} = applied;
    if (!Number.isInteger(issueIndex) || issueIndex < 0) fail(`Applied review entry has invalid issue index: ${applied.id}`);
    if (canonicalJson(candidateEntry) !== canonicalJson(entry)) fail(`Applied review entry changed after parsing: ${applied.id}`);
    consumed.add(applied.id);
  }
  const unused = bundle.entries.filter(entry => !consumed.has(entry.id));
  if (unused.length > 0) fail(`Unused review entries: ${unused.map(entry => entry.id).join(', ')}`);
  return true;
}

export function pendingEntry(context, issue, issueIndex) {
  if (!Number.isInteger(issueIndex) || issueIndex < 0) fail('issueIndex must be a nonnegative integer');
  if (!supportedIssue(issue)) fail('Only the supported FlutterSemanticsScrollView issue can be recorded for review');
  if (!reviewableIosProfiles.has(context?.profile)) fail('Pending accessibility reviews are restricted to supported iOS profiles');
  const binding = validateContext(context);
  const issueSha256 = issueFingerprint(issue);
  const idSeed = hashCanonical({binding, issueIndex, issueSha256});
  return {
    id: `pending-${idSeed.slice(0, 48)}`,
    profile: binding.profile,
    caseId: binding.caseId,
    candidateSha: binding.candidateSha,
    environmentSha256: binding.environmentSha256,
    screenshotSha256: binding.screenshotSha256,
    semanticsSha256: binding.semanticsSha256,
    issueSha256,
    disposition: 'pending',
    rationale: null,
    reviewer: null,
    reviewedAt: null,
  };
}

export async function validateReviewFile(file, digest, candidateSha, approved) {
  const bytes = await fs.readFile(path.resolve(file));
  const bundle = parseReviewBundle(bytes, digest, candidateSha, approved);
  return {valid: true, candidateSha: bundle.candidateSha, manifestSha256: bundle.manifestSha256, entries: bundle.entries.length};
}

async function cli(argv) {
  const [command, file, digest, candidateSha, approval, ...rest] = argv;
  if (command !== 'validate' || !file || !digest || !candidateSha || rest.length > 0 || (approval && approval !== '--approved')) {
    fail('Usage: node reviews.mjs validate <bundle.json> <sha256> <candidate-sha> [--approved]');
  }
  const result = await validateReviewFile(file, digest, candidateSha, approval === '--approved');
  process.stdout.write(`${JSON.stringify(result)}\n`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  cli(process.argv.slice(2)).catch(error => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
