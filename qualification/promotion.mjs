// Read-only release authorization. A green status alone is not qualification evidence.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export const promotionEnvironment = 'release-promotion';
const workflowPath = '.github/workflows/qualify-candidate.yml';
export function validateRun(run, { sha, repository, branch, workflowId }) {
  assert.equal(run.head_sha, sha, 'Qualification tested a different commit');
  assert.equal(run.head_repository?.full_name, repository, 'Wrong source repository');
  assert.equal(run.workflow_id, workflowId, 'Wrong qualification workflow');
  assert.equal(run.path, workflowPath, 'Unexpected workflow source');
  assert.equal(run.head_branch, branch, 'Qualification must run from the default branch');
  assert.equal(run.event, 'workflow_dispatch', 'Qualification must be explicitly dispatched');
  assert.equal(run.status, 'completed', 'Qualification is unfinished');
  assert.equal(run.conclusion, 'success', 'Qualification did not pass');
}

export function validateReviewApproval(review, jobs) {
  const approval = jobs?.review_approval;
  if (approval) assert.ok(['success', 'skipped'].includes(approval.result), 'Accessibility review approval did not complete');
  if (review === undefined) {
    assert.notEqual(approval?.outputs?.approved, 'true', 'Approved review provenance is missing');
    return; // Older evidence cannot contain adjudications.
  }
  assert.equal(typeof review.required, 'boolean', 'Missing accessibility review requirement');
  assert.ok(Number.isSafeInteger(review.appliedCount) && review.appliedCount >= 0, 'Invalid reviewed-exception count');
  assert.ok(Array.isArray(review.applied), 'Missing reviewed-exception records');
  assert.equal(review.applied.length, review.appliedCount, 'Reviewed-exception records differ from their count');
  if (!review.required) {
    assert.equal(review.appliedCount, 0, 'Exceptions lack approval provenance');
    assert.equal(review.manifestSha256, null, 'Unapproved review manifest');
    assert.notEqual(approval?.outputs?.approved, 'true', 'Approved review provenance was omitted');
    return;
  }
  assert.match(review.manifestSha256 ?? '', /^[a-f0-9]{64}$/, 'Missing approved review digest');
  assert.equal(approval?.result, 'success', 'Accessibility exceptions require protected approval');
  assert.equal(approval?.outputs?.approved, 'true', 'Accessibility approval was not recorded');
  assert.equal(approval?.outputs?.manifest_sha256, review.manifestSha256, 'Protected approval belongs to a different review manifest');
  const ids = new Set();
  for (const entry of review.applied) {
    assert.ok(typeof entry.id === 'string' && entry.id.length > 0 && !ids.has(entry.id), 'Invalid or duplicate reviewed-exception ID');
    ids.add(entry.id);
    assert.match(entry.profile ?? '', /^ios-(?:phone|tablet)(?:-large)?$/, 'Unexpected reviewed platform');
    assert.match(entry.caseId ?? '', /^[a-z0-9-]+-(?:de|en|fr|es)-(?:light|dark)$/, 'Invalid or detector review case');
    assert.match(entry.issueSha256 ?? '', /^[a-f0-9]{64}$/, 'Missing reviewed finding fingerprint');
  }
}

export function validateSummary(summary, sha) {
  assert.equal(summary.schema, 2, 'Unsupported evidence schema');
  assert.equal(summary.candidateSha, sha, 'Evidence belongs to a different commit');
  assert.equal(summary.qualification, 'READY_FOR_REVIEW', 'Candidate is not ready for release review');
  assert.equal(summary.automaticPass, true, 'Automatic qualification is incomplete');
  assert.equal(summary.matrix, 'full', 'Only a full matrix can authorize promotion');
  assert.equal(summary.mode, 'compare', 'Captures cannot authorize promotion');
  assert.equal(summary.baselineVerified, true, 'A reviewed baseline is required');
  assert.deepEqual(summary.pendingRoutes, {}, 'Screen coverage is incomplete');
  assert.ok(Array.isArray(summary.openGates), 'Missing gate inventory');
  assert.ok(summary.openGates.every(g => ['physical-device-review', 'approved-baseline-review'].includes(g)),
    'Implementation gates remain open');
  for (const name of ['prepare', 'flutter', 'web', 'native', 'production']) {
    assert.equal(summary.jobs?.[name]?.result, 'success', `${name} evidence did not pass`);
  }
  assert.ok(summary.evidence?.flutter && summary.evidence?.web && summary.evidence?.native && summary.evidence?.production,
    'Missing evidence checksums');
  validateReviewApproval(summary.accessibilityReview, summary.jobs);
}

export function validateEnvironment(environment) {
  assert.equal(environment.name, promotionEnvironment, 'Wrong release environment');
  const reviewers = environment.protection_rules?.find(r => r.type === 'required_reviewers');
  assert.ok(reviewers?.reviewers?.length, 'Configure required reviewers on release-promotion before publishing');
  assert.equal(environment.can_admins_bypass, false, 'Disable administrator bypass on release-promotion');
}

export function validateArtifact(artifact, run, sha) {
  assert.equal(artifact.name, `candidate-summary-${run.id}-${run.run_attempt}`, 'Wrong evidence artifact');
  assert.equal(artifact.expired, false, 'Qualification evidence has expired; qualify again');
  assert.equal(artifact.workflow_run?.head_sha, sha, 'Artifact commit differs');
  assert.equal(artifact.workflow_run?.id, run.id, 'Artifact run differs');
  assert.match(artifact.digest ?? '', /^sha256:[a-f0-9]{64}$/, 'Missing artifact digest');
  assert.ok(Date.parse(artifact.created_at) >= Date.parse(run.run_started_at), 'Artifact predates this run attempt');
}

export async function authorize({ sha, repository, token, fetcher = fetch, api = 'https://api.github.com' }) {
  assert.match(sha ?? '', /^[a-f0-9]{40}$/, 'A full release commit SHA is required');
  assert.match(repository ?? '', /^[\w.-]+\/[\w.-]+$/, 'Invalid repository');
  const request = async (suffix, binary = false) => {
    const response = await fetcher(`${api}/repos/${repository}/${suffix}`, {
      headers: { accept: 'application/vnd.github+json', authorization: `Bearer ${token}`,
        'X-GitHub-Api-Version': '2022-11-28' }, signal: AbortSignal.timeout(30_000),
    });
    assert.ok(response.ok, `Cannot read release evidence: HTTP ${response.status}`);
    if (!binary) return response.json();
    assert.ok(Number(response.headers.get('content-length') || 0) < 16 * 1024 ** 2, 'Summary archive is too large');
    const bytes = Buffer.from(await response.arrayBuffer());
    assert.ok(bytes.length < 16 * 1024 ** 2, 'Summary archive is too large');
    return bytes;
  };
  const repo = await request('');
  const environment = await request(`environments/${promotionEnvironment}`);
  validateEnvironment(environment);
  const workflow = await request('actions/workflows/qualify-candidate.yml');
  const listing = await request(`actions/workflows/${workflow.id}/runs?head_sha=${sha}&event=workflow_dispatch&status=success&per_page=100`);
  const runs = listing.workflow_runs.filter(run => {
    try { validateRun(run, { sha, repository, branch: repo.default_branch, workflowId: workflow.id }); return true; }
    catch { return false; }
  });
  for (const run of runs) {
    const artifacts = await request(`actions/runs/${run.id}/artifacts?per_page=100`);
    const artifact = artifacts.artifacts.find(a => a.name === `candidate-summary-${run.id}-${run.run_attempt}`);
    if (!artifact) continue;
    // Do not silently fall back to older evidence when a purported passing run is corrupt.
    validateArtifact(artifact, run, sha);
    const bytes = await request(`actions/artifacts/${artifact.id}/zip`, true);
    assert.equal(`sha256:${createHash('sha256').update(bytes).digest('hex')}`, artifact.digest, 'Artifact checksum mismatch');
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ww-promotion-'));
    try {
      const zip = path.join(dir, 'summary.zip');
      fs.writeFileSync(zip, bytes);
      const read = spawnSync('python3', ['-c',
        'import sys,zipfile\nwith zipfile.ZipFile(sys.argv[1]) as z:\n e=z.infolist()\n assert len(e)==1 and e[0].filename=="summary.json" and e[0].file_size<1048576, "Invalid summary archive"\n sys.stdout.buffer.write(z.read(e[0]))', zip],
      { encoding: 'utf8', maxBuffer: 1024 ** 2 });
      assert.equal(read.status, 0, 'Cannot read qualification summary');
      const summary = JSON.parse(read.stdout);
      validateSummary(summary, sha);
      return { candidateSha: sha, runId: run.id, artifactId: artifact.id, digest: artifact.digest, environment: promotionEnvironment,
        accessibilityReview: summary.accessibilityReview ?? null };
    } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  }
  throw new Error('No successful full comparison qualification exists for this exact commit');
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const result = await authorize({ sha: process.env.GITHUB_SHA, repository: process.env.GITHUB_REPOSITORY, token: process.env.GH_TOKEN });
  console.log(`Verified candidate ${result.candidateSha}; review qualification run ${result.runId} before approving ${result.environment}.`);
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,
    `## Release review required\n\nCommit: \`${result.candidateSha}\`\n\n[Qualification evidence](https://github.com/${process.env.GITHUB_REPOSITORY}/actions/runs/${result.runId})\n\n`
    + (result.accessibilityReview?.required ? `Accessibility review manifest: \`${result.accessibilityReview.manifestSha256}\`; ${result.accessibilityReview.appliedCount} explicitly reviewed finding(s).\n\n` : '')
    + 'Review screenshot changes, accepted accessibility exceptions, baseline acceptance and physical-device checks before approving the release environment.\n');
}
