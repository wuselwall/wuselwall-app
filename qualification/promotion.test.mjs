import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { validateRun, validateSummary, validateArtifact, validateEnvironment, authorize } from './promotion.mjs';

const sha = 'a'.repeat(40);
const run = { id: 12, run_attempt: 1, workflow_id: 4, head_sha: sha, head_repository: { full_name: 'test/app' },
  path: '.github/workflows/qualify-candidate.yml', head_branch: 'main', event: 'workflow_dispatch',
  status: 'completed', conclusion: 'success', run_started_at: '2026-10-25T12:00:00Z' };
const context = { sha, repository: 'test/app', branch: 'main', workflowId: 4 };
const summary = { schema: 2, candidateSha: sha, qualification: 'READY_FOR_REVIEW', automaticPass: true,
  matrix: 'full', mode: 'compare', baselineVerified: true, pendingRoutes: {},
  openGates: ['physical-device-review', 'approved-baseline-review'],
  jobs: Object.fromEntries(['prepare', 'flutter', 'web', 'native', 'production'].map(n => [n, { result: 'success' }])),
  evidence: { flutter: sha, web: sha, native: sha, production: sha } };

test('promotion rejects other commits, forks, triggers, workflow identities and failed runs', () => {
  validateRun(run, context);
  for (const change of [{ head_sha: 'b'.repeat(40) }, { head_repository: { full_name: 'fork/app' } },
    { event: 'pull_request' }, { head_branch: 'feature' }, { workflow_id: 5 }, { path: 'other.yml' },
    { status: 'in_progress' }, { conclusion: 'failure' }]) assert.throws(() => validateRun({ ...run, ...change }, context));
});

test('promotion rejects captures, partial coverage, missing evidence and skipped or failed jobs', () => {
  validateSummary(summary, sha);
  for (const change of [{ schema: 1 }, { candidateSha: 'b'.repeat(40) }, { automaticPass: false },
    { qualification: 'INCOMPLETE' }, { matrix: 'smoke' }, { mode: 'capture' }, { baselineVerified: false },
    { pendingRoutes: { signIn: {} } }, { openGates: ['native-platform-audits'] }, { evidence: {} },
    { jobs: { ...summary.jobs, native: { result: 'skipped' } } },
    { jobs: { ...summary.jobs, web: { result: 'failure' } } }]) assert.throws(() => validateSummary({ ...summary, ...change }, sha));
});

test('human review must be configured and artifacts must be current, immutable and commit-bound', () => {
  const environment = { name: 'release-promotion', can_admins_bypass: false,
    protection_rules: [{ type: 'required_reviewers', reviewers: [{ type: 'User' }] }] };
  validateEnvironment(environment);
  assert.throws(() => validateEnvironment({ ...environment, protection_rules: [] }));
  assert.throws(() => validateEnvironment({ ...environment, can_admins_bypass: true }));
  const artifact = { name: 'candidate-summary-12-1', expired: false, workflow_run: { id: 12, head_sha: sha },
    created_at: '2026-10-25T12:01:00Z', digest: `sha256:${'c'.repeat(64)}` };
  validateArtifact(artifact, run, sha);
  for (const change of [{ expired: true }, { digest: '' }, { name: 'other' },
    { created_at: '2026-10-25T11:00:00Z' }, { workflow_run: { id: 1, head_sha: sha } }]) {
    assert.throws(() => validateArtifact({ ...artifact, ...change }, run, sha));
  }
});

test('an API error never turns missing qualification into authorization', async () => {
  await assert.rejects(authorize({ sha, repository: 'test/app', token: 'test',
    fetcher: async () => ({ ok: false, status: 403 }) }), /HTTP 403/);
});

test('authorization checks downloaded ZIP bytes and the contained evidence before allowing review', async () => {
  const zip = (data, name = 'summary.json') => {
    const result = spawnSync('python3', ['-c',
      'import io,sys,zipfile\nb=io.BytesIO()\nwith zipfile.ZipFile(b,"w") as z: z.writestr(sys.argv[1],sys.stdin.buffer.read())\nsys.stdout.buffer.write(b.getvalue())', name],
    { input: JSON.stringify(data) });
    assert.equal(result.status, 0);
    return result.stdout;
  };
  const attempt = async (bytes, digest = createHash('sha256').update(bytes).digest('hex')) => {
    const fetcher = async url => {
      const suffix = new URL(url).pathname.replace('/repos/test/app/', '');
      const values = {
        '': { default_branch: 'main' },
        'environments/release-promotion': { name: 'release-promotion', can_admins_bypass: false,
          protection_rules: [{ type: 'required_reviewers', reviewers: [{ type: 'User' }] }] },
        'actions/workflows/qualify-candidate.yml': { id: 4 },
        'actions/workflows/4/runs': { workflow_runs: [run] },
        'actions/runs/12/artifacts': { artifacts: [{ id: 10, name: 'candidate-summary-12-1', expired: false,
          created_at: '2026-10-25T12:01:00Z', workflow_run: { id: 12, head_sha: sha }, digest: `sha256:${digest}` }] },
      };
      if (suffix === 'actions/artifacts/10/zip') return new Response(bytes);
      assert.ok(suffix in values, `Unexpected request: ${url}`);
      return Response.json(values[suffix]);
    };
    return authorize({ sha, repository: 'test/app', token: 'test', fetcher });
  };
  assert.equal((await attempt(zip(summary))).runId, 12);
  await assert.rejects(attempt(zip(summary), 'b'.repeat(64)), /checksum/);
  await assert.rejects(attempt(zip({ ...summary, candidateSha: 'b'.repeat(40) })), /different commit/);
  await assert.rejects(attempt(zip(summary, '../summary.json')), /Cannot read qualification summary/);
});
