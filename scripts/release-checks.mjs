// Shared app/server release planning. Reuse only exact-commit, same-repository CI
// from the default branch; PR checks and similarly named workflows are not evidence.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

export function releasePolicy(policy) {
  assert.equal(policy.schema, 1, 'Unsupported release policy');
  assert.ok(['alpha', 'beta', 'live'].includes(policy.stage), 'Unknown release stage');
  return { stage: policy.stage, environment: policy.stage === 'alpha' ? 'alpha-release' : 'release-promotion' };
}

export function matchingRuns(runs, { sha, repository, branch, workflowId, workflow }) {
  return runs.filter(run => run.head_sha === sha && run.head_repository?.full_name === repository &&
    run.workflow_id === workflowId && run.path === `.github/workflows/${workflow}.yml` &&
    run.head_branch === branch && ['push', 'workflow_dispatch'].includes(run.event))
    .sort((a, b) => b.run_number - a.run_number || b.run_attempt - a.run_attempt);
}

export async function planRelease({ sha, repository, token, policy, fetcher = fetch,
  now = Date.now, sleep = ms => new Promise(resolve => setTimeout(resolve, ms)), waitMs = 50 * 60_000 }) {
  const result = releasePolicy(policy);
  assert.match(sha ?? '', /^[a-f0-9]{40}$/, 'A full release commit SHA is required');
  assert.match(repository ?? '', /^[\w.-]+\/[\w.-]+$/, 'Invalid repository');
  const request = async suffix => {
    const response = await fetcher(`https://api.github.com/repos/${repository}${suffix ? `/${suffix}` : ''}`, {
      headers: { accept: 'application/vnd.github+json', authorization: `Bearer ${token}`,
        'X-GitHub-Api-Version': '2022-11-28' }, signal: AbortSignal.timeout(30_000),
    });
    assert.ok(response.ok, `Cannot read release checks: HTTP ${response.status}`);
    return response.json();
  };
  const repo = await request('');
  // Release branches/tags must point to reviewed default-branch history. No force
  // push or tag naming convention can silently choose a weaker release stage.
  const comparison = await request(`compare/${sha}...${encodeURIComponent(repo.default_branch)}`);
  assert.ok(['ahead', 'identical'].includes(comparison.status), 'Release commit must belong to the default branch');
  const checks = await Promise.all(['ci', 'backend-ci'].map(async workflow => {
    const definition = await request(`actions/workflows/${workflow}.yml`);
    assert.equal(definition.path, `.github/workflows/${workflow}.yml`, 'Unexpected CI workflow source');
    const context = { sha, repository, branch: repo.default_branch, workflowId: definition.id, workflow };
    const deadline = now() + waitMs;
    while (true) {
      const listing = await request(`actions/workflows/${definition.id}/runs?head_sha=${sha}&per_page=100`);
      const run = matchingRuns(listing.workflow_runs, context)[0];
      if (!run) return [workflow, { reuse: false }];
      if (run.status === 'completed') {
        assert.equal(run.conclusion, 'success', `${workflow} did not pass: ${run.html_url}; rerun the failed check before releasing`);
        return [workflow, { reuse: true, url: run.html_url }];
      }
      assert.ok(now() < deadline, `Timed out waiting for ${workflow}: ${run.html_url}`);
      await sleep(15_000);
    }
  }));
  return { ...result, sha, checks: Object.fromEntries(checks) };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const policy = JSON.parse(fs.readFileSync(new URL('../qualification/release-policy.json', import.meta.url), 'utf8'));
  const plan = await planRelease({ sha: process.env.GITHUB_SHA, repository: process.env.GITHUB_REPOSITORY,
    token: process.env.GH_TOKEN, policy });
  fs.appendFileSync(process.env.GITHUB_OUTPUT,
    `stage=${plan.stage}\nenvironment=${plan.environment}\nci=${plan.checks.ci.reuse}\nbackend=${plan.checks['backend-ci'].reuse}\n`);
  const lines = Object.entries(plan.checks).map(([name, check]) =>
    `- ${name}: ${check.reuse ? `[reuse passing run](${check.url})` : 'run missing checks in this release'}`);
  fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,
    `## ${plan.stage} release checks\n\nCommit: \`${plan.sha}\`\n\n${lines.join('\n')}\n\n` +
    (plan.stage === 'alpha' ? 'Full UI/native qualification is optional during alpha.\n' : 'Full comparison and protected review are required before signing.\n'));
}
