import assert from 'node:assert/strict';
import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import { matchingRuns, planRelease, releasePolicy } from './release-checks.mjs';

const sha = 'a'.repeat(40);
const context = { sha, repository: 'test/app', branch: 'main', workflowId: 1, workflow: 'ci' };
const run = { head_sha: sha, head_repository: { full_name: 'test/app' }, head_branch: 'main',
  workflow_id: 1, path: '.github/workflows/ci.yml', event: 'push', run_number: 12, run_attempt: 1,
  status: 'completed', conclusion: 'success', html_url: 'https://example.org/run/12' };

test('only explicit alpha relaxes qualification; beta/live retain protected promotion', () => {
  assert.equal(releasePolicy({ schema: 1, stage: 'alpha' }).environment, 'alpha-release');
  for (const stage of ['beta', 'live']) {
    assert.equal(releasePolicy({ schema: 1, stage }).environment, 'release-promotion');
  }
  for (const policy of [{}, { schema: 1 }, { schema: 2, stage: 'alpha' }, { schema: 1, stage: 'preview' }]) {
    assert.throws(() => releasePolicy(policy));
  }
});

test('CI reuse rejects PRs, forks, other commits, branches and workflow identities', () => {
  assert.deepEqual(matchingRuns([run], context), [run]);
  for (const change of [{ head_sha: 'b'.repeat(40) }, { head_repository: { full_name: 'fork/app' } },
    { head_branch: 'feature' }, { workflow_id: 2 }, { path: 'other.yml' }, { event: 'pull_request' }]) {
    assert.deepEqual(matchingRuns([{ ...run, ...change }], context), []);
  }
  const newer = { ...run, run_number: 13, conclusion: 'failure' };
  assert.equal(matchingRuns([run, newer], context)[0], newer, 'A newer failure must not fall back to old success');
});

function fakeApi({ ci = [run], backend = [], status = 'identical', fail = false } = {}) {
  const requests = [];
  const fetcher = async url => {
    requests.push(url);
    if (fail) return new Response('', { status: 403 });
    const suffix = new URL(url).pathname.replace(/^\/repos\/test\/app\/?/, '');
    const values = {
      '': { default_branch: 'main' },
      [`compare/${sha}...main`]: { status },
      'actions/workflows/ci.yml': { id: 1, path: '.github/workflows/ci.yml' },
      'actions/workflows/backend-ci.yml': { id: 2, path: '.github/workflows/backend-ci.yml' },
      'actions/workflows/1/runs': { workflow_runs: ci },
      'actions/workflows/2/runs': { workflow_runs: backend },
    };
    assert.ok(suffix in values, `Unexpected request ${url}`);
    if (suffix === 'actions/workflows/1/runs' && typeof ci === 'function') {
      return Response.json({ workflow_runs: ci() });
    }
    return Response.json(values[suffix]);
  };
  return { fetcher, requests };
}
const plan = (api, options = {}) => planRelease({ sha, repository: 'test/app', token: 'test',
  policy: { schema: 1, stage: 'alpha' }, fetcher: api.fetcher, ...options });

test('successful exact-commit CI is reused and missing backend checks run in the release', async () => {
  const result = await plan(fakeApi());
  assert.deepEqual(result.checks, { ci: { reuse: true, url: run.html_url }, 'backend-ci': { reuse: false } });
  const backend = { ...run, workflow_id: 2, path: '.github/workflows/backend-ci.yml' };
  assert.equal((await plan(fakeApi({ backend: [backend] }))).checks['backend-ci'].reuse, true);
});

test('failed/cancelled/skipped checks, API failures and off-branch commits block release', async () => {
  for (const conclusion of ['failure', 'cancelled', 'skipped', 'timed_out', 'neutral']) {
    await assert.rejects(plan(fakeApi({ ci: [{ ...run, conclusion }] })), /ci did not pass/);
  }
  await assert.rejects(plan(fakeApi({ fail: true })), /HTTP 403/);
  for (const status of ['behind', 'diverged']) {
    await assert.rejects(plan(fakeApi({ status })), /default branch/);
  }
});

test('active CI is awaited and a timeout never counts as passing evidence', async () => {
  let polls = 0;
  let sleeps = 0;
  const active = { ...run, status: 'in_progress', conclusion: null };
  const api = fakeApi({ ci: () => ++polls < 2 ? [active] : [run] });
  const result = await plan(api, { sleep: async ms => { assert.equal(ms, 15_000); sleeps++; } });
  assert.equal(result.checks.ci.reuse, true);
  assert.equal(sleeps, 1);
  await assert.rejects(plan(fakeApi({ ci: [active] }), { now: () => 0, waitMs: 0 }), /Timed out/);
});

test('all publishing paths share the stage-aware gate and signing waits for it', () => {
  for (const file of ['release-android', 'release-ios', 'server-release']) {
    const workflow = fs.readFileSync(`.github/workflows/${file}.yml`, 'utf8');
    assert.match(workflow, /qualification:\n(?:    [^\n]*\n)*?    uses: \.\/\.github\/workflows\/release-checks.yml/);
    assert.match(workflow, /environment: \$\{\{ needs.qualification.outputs.environment \}\}/);
  }
  const shared = fs.readFileSync('.github/workflows/release-checks.yml', 'utf8');
  assert.match(shared, /if: needs.plan.outputs.stage != 'alpha'\n        run: node qualification\/promotion.mjs/);
  assert.match(shared, /needs: \[plan, ci, backend\]/);
  assert.match(shared, /"\$CI" == skipped && "\$REUSE_CI" == true/);
  assert.match(shared, /"\$BACKEND" == skipped && "\$REUSE_BACKEND" == true/);
  for (const name of ['ci', 'backend-ci']) {
    const workflow = fs.readFileSync(`.github/workflows/${name}.yml`, 'utf8');
    assert.match(workflow, /workflow_call:/);
    assert.match(workflow, /branches: \[main\]/);
    assert.doesNotMatch(workflow, /tags: \['v/);
  }
});

test('release aggregation accepts reused or newly passed checks and rejects every other result', () => {
  const workflow = fs.readFileSync('.github/workflows/release-checks.yml', 'utf8');
  const script = workflow.split('        run: |\n')[1].split('\n      - uses:')[0];
  assert.ok(script);
  const outcomes = ['success', 'skipped', 'failure', 'cancelled'];
  for (const ci of outcomes) for (const backend of outcomes) {
    for (const reuseCi of ['true', 'false']) for (const reuseBackend of ['true', 'false']) {
      const expected = (ci === 'success' || (ci === 'skipped' && reuseCi === 'true')) &&
        (backend === 'success' || (backend === 'skipped' && reuseBackend === 'true'));
      const result = spawnSync('bash', ['-c', script], { env: { PLAN: 'success', CI: ci, BACKEND: backend,
        REUSE_CI: reuseCi, REUSE_BACKEND: reuseBackend } });
      assert.equal(result.status === 0, expected, JSON.stringify({ ci, backend, reuseCi, reuseBackend }));
    }
  }
  const failedPlan = spawnSync('bash', ['-c', script], { env: { PLAN: 'failure', CI: 'skipped', BACKEND: 'skipped',
    REUSE_CI: 'true', REUSE_BACKEND: 'true' } });
  assert.notEqual(failedPlan.status, 0);
});
