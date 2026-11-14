// The pull request policy and the release plan (CONTRIBUTING.md); no network.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { client, nextRelease } from './github-api.mjs';
import { checkIssue, checkPullRequest, evaluate, statusContext, typeLabels, typeOfBranch } from './pr-policy.mjs';
import { appWorkflows, bump, plan, serverWorkflows, afterWorkflows } from './release.mjs';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const milestones = [{ number: 7, title: 'v1.13.0' }, { number: 6, title: 'v1.12.0' }, { number: 3, title: '3 · Family Alpha' }];
const open = (number, title) => ({ number, title, state: 'OPEN' });
const pr = (over = {}) => ({ base: 'main', head: 'feat/quick-add', labels: [], milestone: null, state: 'OPEN', merged: false, ...over });
const check = (over, issues = []) => evaluate({ pr: pr(over), issues, milestones, defaultBranch: 'main' });

test('the branch prefix gives the type', () => {
  assert.equal(typeOfBranch('feat/quick-add'), 'enhancement');
  assert.equal(typeOfBranch('fix/220-tag'), 'bug');
  assert.equal(typeOfBranch('docs/family-guide-clarity'), 'documentation');
  assert.equal(typeOfBranch('dependabot/pub/app/x'), 'dependencies');
  assert.equal(typeOfBranch('wt/t_ad1fcc57'), null);
});

test('a feature without an issue fails, and still gets its label', () => {
  const result = check({});
  assert.equal(result.state, 'failure');
  assert.deepEqual(result.addLabels, ['enhancement']);
  assert.match(result.description, /needs an issue/);
});

test('a feature whose issue has no release milestone fails', () => {
  for (const milestone of [null, open(3, '3 · Family Alpha'), { number: 5, title: 'v1.11.0', state: 'CLOSED' }]) {
    const result = check({}, [{ number: 12, milestone }]);
    assert.equal(result.state, 'failure');
    assert.match(result.description, /#12 has no open release milestone/);
  }
});

test('a feature takes the milestone of its issue', () => {
  const result = check({ labels: ['enhancement'] }, [{ number: 12, milestone: open(7, 'v1.13.0') }]);
  assert.equal(result.state, 'success');
  assert.deepEqual(result.addLabels, []);
  assert.equal(result.milestone, 7);
  assert.equal(result.description, 'enhancement: closes #12 in v1.13.0');
  assert.equal(check({ labels: ['bug'], milestone: { number: 7, title: 'v1.13.0' } }, [{ number: 12, milestone: open(7, 'v1.13.0') }]).milestone, undefined);
});

test('documentation, chores, CI and dependencies need no issue and join the next release', () => {
  for (const head of ['docs/guide', 'chore/tidy', 'ci/cache', 'dependabot/npm/x']) {
    const result = check({ head });
    assert.equal(result.state, 'success', head);
    assert.equal(result.milestone, 6, head);
  }
  // A milestone someone chose stays.
  assert.equal(check({ head: 'docs/guide', milestone: { number: 7, title: 'v1.13.0' } }).milestone, undefined);
});

test('a label decides before the branch name; an unknown branch needs a label', () => {
  assert.equal(check({ head: 'feat/x', labels: ['documentation'] }).state, 'success');
  const result = check({ head: 'wt/t_ad1fcc57' });
  assert.equal(result.state, 'failure');
  assert.match(result.description, /No type/);
  assert.ok(result.description.length <= 140);
});

test('what merges ships with the next release, whatever was planned', () => {
  const result = check({ merged: true, state: 'MERGED', labels: ['enhancement'], milestone: { number: 7, title: 'v1.13.0' } },
    [{ number: 12, milestone: open(7, 'v1.13.0') }]);
  assert.equal(result.milestone, 6);
  assert.equal(result.issueMilestone, 6);
});

test('a pull request to another branch is not checked', () => {
  const result = check({ base: 'feat/stack' });
  assert.equal(result.state, 'success');
  assert.deepEqual(result.addLabels, []);
  assert.equal(result.milestone, undefined);
});

// A GitHub that answers from a table and records what was written.
function fake(answers) {
  const calls = [];
  const fetcher = async (url, { method, body }) => {
    const path = url.replace('https://api.github.com/', '');
    calls.push(`${method} ${path}${body && path !== 'graphql' ? ` ${body}` : ''}`);
    const answer = path === 'graphql' ? answers.graphql(JSON.parse(body)) : (answers[`${method} ${path}`] ?? {});
    const status = answer === 404 ? 404 : 200;
    return { ok: status === 200, status, text: async () => JSON.stringify(status === 200 ? answer : { message: 'Not Found' }) };
  };
  return { github: client({ token: 't', repository: 'o/r', fetcher }), calls };
}
const repositoryAnswer = (pullRequest) => ({ data: { repository: {
  nameWithOwner: 'o/r', defaultBranchRef: { name: 'main' },
  milestones: { nodes: milestones }, pullRequest,
} } });

test('checking a pull request labels it, sets the milestone and reports the status on its head', async () => {
  const { github, calls } = fake({ graphql: () => repositoryAnswer({
    number: 9, state: 'OPEN', merged: false, baseRefName: 'main', headRefName: 'fix/tag', headRefOid: 'abc',
    labels: { nodes: [] }, milestone: null,
    closingIssuesReferences: { nodes: [
      { number: 4, repository: { nameWithOwner: 'o/r' }, milestone: open(6, 'v1.12.0') },
      { number: 5, repository: { nameWithOwner: 'other/repo' }, milestone: open(1, 'v9.0.0') },
    ] },
  }) });
  const result = await checkPullRequest(github, 9);
  assert.equal(result.state, 'success');
  assert.deepEqual(calls.slice(1, 3), [
    'POST repos/o/r/issues/9/labels {"labels":["bug"]}',
    'PATCH repos/o/r/issues/9 {"milestone":6}',
  ]);
  assert.match(calls[3], /^POST repos\/o\/r\/statuses\/abc \{"state":"success","context":"pr-policy"/);
  assert.equal(calls.length, 4);
});

test('a merged pull request moves its issues and reports no status', async () => {
  const { github, calls } = fake({ graphql: () => repositoryAnswer({
    number: 9, state: 'MERGED', merged: true, baseRefName: 'main', headRefName: 'feat/x', headRefOid: 'abc',
    labels: { nodes: [{ name: 'enhancement' }] }, milestone: { number: 7, title: 'v1.13.0', state: 'OPEN' },
    closingIssuesReferences: { nodes: [{ number: 4, repository: { nameWithOwner: 'o/r' }, milestone: open(7, 'v1.13.0') }] },
  }) });
  await checkPullRequest(github, 9);
  assert.deepEqual(calls.slice(1), ['PATCH repos/o/r/issues/9 {"milestone":6}', 'PATCH repos/o/r/issues/4 {"milestone":6}']);
});

test('an issue waits in needs-triage until it has a milestone', async () => {
  const issue = (over) => ({ data: { repository: { issue: {
    number: 4, state: 'OPEN', labels: { nodes: [] }, milestone: null, closedByPullRequestsReferences: { nodes: [] }, ...over,
  } } } });
  let run = fake({ graphql: () => issue({}) });
  await checkIssue(run.github, 4);
  assert.deepEqual(run.calls.slice(1), ['POST repos/o/r/issues/4/labels {"labels":["needs-triage"]}']);
  run = fake({ graphql: () => issue({ labels: { nodes: [{ name: 'needs-triage' }] }, milestone: { number: 6, title: 'v1.12.0' } }) });
  await checkIssue(run.github, 4);
  assert.deepEqual(run.calls.slice(1), ['DELETE repos/o/r/issues/4/labels/needs-triage']);
  run = fake({ graphql: () => issue({ milestone: { number: 6, title: 'v1.12.0' } }) });
  await checkIssue(run.github, 4);
  assert.equal(run.calls.length, 1);
});

// A GitHub whose answers to one call come in turn: a status number, 'reset' (no answer), or a body.
function flaky(script, { graphql } = {}) {
  const calls = [];
  const waits = [];
  const fetcher = async (url, { method, body }) => {
    const path = url.replace('https://api.github.com/', '');
    const key = `${method} ${path}`;
    calls.push(path === 'graphql' ? key : `${key}${body ? ` ${body}` : ''}`);
    const turn = path === 'graphql' && !script[key] ? graphql(JSON.parse(body)) : (script[key]?.shift() ?? {});
    if (turn === 'reset') throw new TypeError('fetch failed');
    if (typeof turn === 'number') {
      const html = turn === 502;
      return { ok: false, status: turn, headers: new Headers(turn === 429 ? { 'retry-after': '120' } : {}),
        text: async () => (html ? '<html>Bad gateway</html>' : JSON.stringify({ message: `Status ${turn}` })) };
    }
    return { ok: true, status: 200, headers: new Headers(), text: async () => JSON.stringify(turn) };
  };
  const github = client({ token: 't', repository: 'o/r', fetcher, sleep: async (ms) => { waits.push(ms); } });
  return { github, calls, waits };
}
const openPullRequest = () => repositoryAnswer({
  number: 9, state: 'OPEN', merged: false, baseRefName: 'main', headRefName: 'docs/x', headRefOid: 'abc',
  labels: { nodes: [] }, milestone: null, closingIssuesReferences: { nodes: [] },
});
const statuses = (calls) => calls.filter((call) => call.startsWith('POST repos/o/r/statuses/abc'))
  .map((call) => JSON.parse(call.slice(call.indexOf('{'))).state);

test('a transient server error on the milestone is asked again, and the policy completes', async () => {
  const run = flaky({ 'PATCH repos/o/r/issues/9': [500, 502, {}] }, { graphql: openPullRequest });
  const result = await checkPullRequest(run.github, 9);
  assert.equal(result.state, 'success');
  assert.equal(run.calls.filter((call) => call.startsWith('PATCH repos/o/r/issues/9')).length, 3);
  assert.deepEqual(run.waits, [2000, 4000]);
  assert.deepEqual(statuses(run.calls), ['success']);
});

test('when the retries run out the check fails and reports an error status, never success', async () => {
  const run = flaky({ 'PATCH repos/o/r/issues/9': [500, 500, 500, {}] }, { graphql: openPullRequest });
  await assert.rejects(checkPullRequest(run.github, 9), (error) => {
    assert.equal(error.status, 500);
    assert.match(error.message, /^PATCH \/repos\/o\/r\/issues\/9: HTTP 500 Status 500 \(after 3 attempts\)$/);
    return true;
  });
  assert.equal(run.calls.filter((call) => call.startsWith('PATCH')).length, 3);
  assert.deepEqual(statuses(run.calls), ['error']);
  const description = JSON.parse(run.calls.at(-1).slice(run.calls.at(-1).indexOf('{'))).description;
  assert.match(description, /^Not applied, run triage again: PATCH .* HTTP 500/);
  assert.ok(description.length <= 140);
});

test('authentication and validation failures are not asked again', async () => {
  for (const status of [401, 403, 404, 422]) {
    const run = flaky({ 'PATCH repos/o/r/issues/9': [status, {}] }, { graphql: openPullRequest });
    await assert.rejects(checkPullRequest(run.github, 9), (error) => error.status === status && !/attempts/.test(error.message));
    assert.equal(run.calls.filter((call) => call.startsWith('PATCH')).length, 1, `${status}`);
    assert.deepEqual(run.waits, [], `${status}`);
    assert.deepEqual(statuses(run.calls), ['error'], `${status}`);
  }
});

test('a failing error status does not hide the original failure', async () => {
  const run = flaky({ 'PATCH repos/o/r/issues/9': [422], 'POST repos/o/r/statuses/abc': [500, 500, 500] }, { graphql: openPullRequest });
  await assert.rejects(checkPullRequest(run.github, 9), (error) => error.status === 422);
  assert.equal(statuses(run.calls).length, 3);
});

test('only requests that are safe to repeat are repeated', async () => {
  // A POST that creates something (a tag, a release, a dispatch) is asked once.
  let run = flaky({ 'POST repos/o/r/git/tags': [500, {}] });
  await assert.rejects(run.github.rest('POST', 'git/tags', {}), (error) => error.status === 500);
  assert.equal(run.calls.length, 1);
  // A POST whose caller says it may be repeated, and GET, are asked again: no answer, the rate limit.
  run = flaky({ 'POST repos/o/r/statuses/abc': ['reset', 503, { id: 1 }], 'GET repos/o/r/milestones': [429, []] });
  assert.deepEqual(await run.github.rest('POST', 'statuses/abc', {}, { retry: true }), { id: 1 });
  assert.deepEqual(await run.github.rest('GET', 'milestones'), []);
  assert.deepEqual(run.waits, [2000, 4000, 30_000]); // Retry-After 120 s, held to 30 s
  // A GraphQL query reads and is asked again; a mutation is not.
  run = flaky({ 'POST graphql': [504, { data: { ok: 1 } }] });
  assert.deepEqual(await run.github.graphql('query { ok }'), { ok: 1 });
  run = flaky({ 'POST graphql': [504, { data: { ok: 1 } }] });
  await assert.rejects(run.github.graphql('mutation { ok }'), (error) => error.status === 504);
  assert.equal(run.calls.length, 1);
});

test('the policy script exits nonzero when it could not apply the policy', () => {
  const dir = mkdtempSync(join(tmpdir(), 'pr-policy-'));
  const event = join(dir, 'event.json');
  writeFileSync(event, JSON.stringify({ pull_request: { number: 9 } }));
  // Replaces fetch before the script runs: GitHub answers the query, refuses the milestone.
  const preload = join(dir, 'fake-fetch.mjs');
  writeFileSync(preload, `globalThis.fetch = async (url, { method, body }) => {
    console.error('CALL', method, url, body ?? '');
    if (url.endsWith('/graphql')) return new Response(JSON.stringify(${JSON.stringify(openPullRequest())}));
    if (method === 'PATCH') return new Response(JSON.stringify({ message: 'Validation Failed' }), { status: 422 });
    return new Response('{}');
  };`);
  const run = spawnSync(process.execPath, ['--import', pathToFileURL(preload).href, fileURLToPath(new URL('./pr-policy.mjs', import.meta.url))], {
    env: { ...process.env, GH_TOKEN: 't', GITHUB_REPOSITORY: 'o/r', GITHUB_EVENT_PATH: event, GITHUB_STEP_SUMMARY: '' },
    encoding: 'utf8',
  });
  assert.notEqual(run.status, 0, run.stderr);
  assert.match(run.stderr, /HTTP 422 Validation Failed/);
  assert.match(run.stderr, /CALL POST https:\/\/api\.github\.com\/repos\/o\/r\/statuses\/abc \{"state":"error"/);
  assert.doesNotMatch(run.stderr, /"state":"success"/);
});

const tags = ['v1.9.0', 'v1.10.0', 'v1.11.0', 'server-v0.9.0', 'server-v0.12.0', 'ui-baseline-3'];

test('the release plan takes the next milestone and counts the server on', () => {
  assert.equal(nextRelease(milestones).title, 'v1.12.0');
  assert.deepEqual(plan({ tags, milestones }), {
    app: { version: '1.12.0', tag: 'v1.12.0', previous: 'v1.11.0' },
    server: { version: '0.13.0', tag: 'server-v0.13.0', previous: 'server-v0.12.0' },
    milestone: { number: 6, title: 'v1.12.0' },
    next: 'v1.13.0',
  });
  assert.equal(plan({ tags, milestones, server: 'patch' }).server.tag, 'server-v0.12.1');
  assert.equal(plan({ tags, milestones, server: 'none' }).server, null);
  assert.equal(bump('1.9.3', 'major'), '2.0.0');
});

test('a version without a milestone is released; the next milestone follows it', () => {
  const result = plan({ tags, milestones: [], version: 'v1.11.1' });
  assert.equal(result.app.tag, 'v1.11.1');
  assert.equal(result.milestone, null);
  assert.equal(result.next, 'v1.12.0');
});

test('the release plan refuses what cannot be a release', () => {
  assert.throws(() => plan({ tags, milestones: [{ number: 3, title: '3 · Family Alpha' }] }), /no open release milestone/);
  assert.throws(() => plan({ tags, milestones, version: '1.11.0' }), /exists already/);
  assert.throws(() => plan({ tags, milestones, version: '1.10.5' }), /not newer/);
  assert.throws(() => plan({ tags, milestones, version: '1.13.0' }), /earlier milestone first: v1.12.0/);
  assert.throws(() => plan({ tags, milestones, version: 'next' }), /must look like/);
  assert.throws(() => plan({ tags, milestones, server: 'huge' }), /server must be/);
});

test('every workflow the release starts can be started, and the required checks exist', () => {
  for (const file of [...appWorkflows, ...serverWorkflows, ...afterWorkflows]) {
    assert.match(read(`.github/workflows/${file}`), /^  workflow_dispatch:/m, file);
  }
  const ruleset = JSON.parse(read('.github/rulesets/main.json'));
  const required = ruleset.rules.find((rule) => rule.type === 'required_status_checks')
    .parameters.required_status_checks.map((status) => status.context);
  assert.ok(required.includes(statusContext));
  const jobs = `${read('.github/workflows/ci.yml')}\n${read('.github/workflows/backend-ci.yml')}`;
  for (const context of required.filter((name) => name !== statusContext)) {
    assert.match(jobs, new RegExp(`^  ${context}:$`, 'm'), `${context} is a job of ci.yml or backend-ci.yml`);
  }
  assert.deepEqual(ruleset.rules.find((rule) => rule.type === 'pull_request').parameters.allowed_merge_methods, ['squash']);
  assert.deepEqual(ruleset.bypass_actors, []);
});

test('triage never checks out a pull request', () => {
  const workflow = read('.github/workflows/triage.yml');
  assert.match(workflow, /pull_request_target:/);
  assert.match(workflow, /ref: \$\{\{ github\.event\.repository\.default_branch \}\}/);
  assert.doesNotMatch(workflow, /head\.(sha|ref)|refs\/pull/);
  assert.match(workflow, /^permissions: \{\}$/m);
});

test('the release notes and the settings know every type label', () => {
  const notes = read('.github/release.yml');
  const settings = read('scripts/github-settings.sh');
  for (const label of typeLabels) {
    assert.match(notes, new RegExp(`\\b${label}\\b`), `release.yml: ${label}`);
    assert.match(settings, new RegExp(`^  label ${label} `, 'm'), `github-settings.sh: ${label}`);
  }
});
