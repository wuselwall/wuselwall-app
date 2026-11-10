// The pull request policy (CONTRIBUTING.md), run by .github/workflows/triage.yml:
//
// - every pull request to the default branch has a type label, set here from the branch
//   prefix when it has none;
// - a feature or a fix closes an issue that sits in a release milestone (v1.12.0);
// - the pull request takes its issue's milestone, anything else the next release's;
// - once merged, the pull request and its issues move to the release that ships them;
// - a new issue without a milestone is marked needs-triage until it gets one.
//
// The verdict is the commit status "pr-policy" on the pull request's head, which the main
// ruleset requires. It is a status rather than the job's result so that an event on the
// issue (a milestone set later) can turn it green without a new push.
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { client, isVersionMilestone, nextRelease, summary } from './github-api.mjs';

export const statusContext = 'pr-policy';
export const typeLabels = ['enhancement', 'bug', 'documentation', 'chore', 'ci', 'dependencies'];
/** Types that change what a family gets: they need an issue in a release milestone. */
export const needsIssue = new Set(['enhancement', 'bug']);
export const triageLabel = 'needs-triage';
const prefixes = {
  feat: 'enhancement', feature: 'enhancement',
  fix: 'bug', bugfix: 'bug', hotfix: 'bug',
  docs: 'documentation', doc: 'documentation',
  ci: 'ci',
  chore: 'chore', refactor: 'chore', test: 'chore', build: 'chore', perf: 'chore',
  deps: 'dependencies', dependabot: 'dependencies',
};

export const typeOfBranch = (branch) => prefixes[(branch ?? '').split('/')[0].toLowerCase()] ?? null;

/**
 * What the policy says about one pull request. Pure: the caller applies the result.
 * pr: { base, head, labels: [name], milestone: {number,title}|null, state, merged }
 * issues: the issues the pull request closes, [{ number, milestone: {number,title,state}|null }]
 * milestones: the repository's open milestones, [{ number, title }]
 */
export function evaluate({ pr, issues, milestones, defaultBranch }) {
  const result = { state: 'success', description: '', problems: [], addLabels: [], milestone: undefined, issueMilestone: undefined };
  if (pr.base !== defaultBranch) {
    result.description = `Not checked: the base is not ${defaultBranch}`;
    return result;
  }
  const types = pr.labels.filter((label) => typeLabels.includes(label));
  if (types.length === 0) {
    const inferred = typeOfBranch(pr.head);
    if (inferred) {
      types.push(inferred);
      result.addLabels.push(inferred);
    } else {
      result.problems.push(`No type: add one label of ${typeLabels.join(', ')}, or name the branch feat/…, fix/…, docs/…, chore/… or ci/…`);
    }
  }
  const shipping = nextRelease(milestones);
  const required = types.some((type) => needsIssue.has(type));
  const planned = issues.filter((issue) => issue.milestone?.state === 'OPEN' && isVersionMilestone(issue.milestone.title));
  if (pr.merged) {
    // What merged is what ships: the next release, whatever the plan said.
    if (shipping) {
      if (pr.milestone?.number !== shipping.number) result.milestone = shipping.number;
      result.issueMilestone = shipping.number;
    }
    result.description = 'Merged';
    return result;
  }
  if (required) {
    if (issues.length === 0) {
      result.problems.push('A feature or a fix needs an issue: write "Closes #<number>" in the description');
    } else if (planned.length === 0) {
      result.problems.push(`${issues.map((issue) => `#${issue.number}`).join(', ')} has no open release milestone (like v1.12.0)`);
    }
  }
  const target = required && planned.length > 0 ? planned[0].milestone : pr.milestone ? null : shipping;
  if (target && pr.milestone?.number !== target.number) result.milestone = target.number;
  if (result.problems.length > 0) {
    result.state = 'failure';
    result.description = result.problems[0];
  } else {
    const closes = required ? `closes ${planned.map((issue) => `#${issue.number}`).join(', ')} in ${planned[0].milestone.title}` : 'no issue needed';
    result.description = `${types.join(', ')}: ${closes}`;
  }
  // GitHub refuses a status description over 140 characters.
  if (result.description.length > 140) result.description = `${result.description.slice(0, 139)}…`;
  return result;
}

const pullRequestQuery = `query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    nameWithOwner
    defaultBranchRef { name }
    milestones(first: 100, states: OPEN) { nodes { number title } }
    pullRequest(number: $number) {
      number state merged baseRefName headRefName headRefOid
      labels(first: 50) { nodes { name } }
      milestone { number title state }
      closingIssuesReferences(first: 20) {
        nodes { number repository { nameWithOwner } milestone { number title state } }
      }
    }
  }
}`;

const issueQuery = `query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) {
      number state
      labels(first: 50) { nodes { name } }
      milestone { number title }
      closedByPullRequestsReferences(first: 20) { nodes { number state } }
    }
  }
}`;

export async function checkPullRequest(github, number) {
  const { repository } = await github.graphql(pullRequestQuery, { number });
  const found = repository.pullRequest;
  const pr = {
    number, base: found.baseRefName, head: found.headRefName, sha: found.headRefOid,
    labels: found.labels.nodes.map((label) => label.name), milestone: found.milestone,
    state: found.state, merged: found.merged,
  };
  if (pr.state === 'CLOSED') return null; // closed without a merge: nothing to say
  const issues = found.closingIssuesReferences.nodes.filter((issue) => issue.repository.nameWithOwner === repository.nameWithOwner);
  const result = evaluate({ pr, issues, milestones: repository.milestones.nodes, defaultBranch: repository.defaultBranchRef.name });
  if (result.addLabels.length > 0) await github.rest('POST', `issues/${number}/labels`, { labels: result.addLabels });
  if (result.milestone !== undefined) await github.rest('PATCH', `issues/${number}`, { milestone: result.milestone });
  if (result.issueMilestone !== undefined) {
    for (const issue of issues) {
      if (issue.milestone?.number !== result.issueMilestone) await github.rest('PATCH', `issues/${issue.number}`, { milestone: result.issueMilestone });
    }
  }
  if (!pr.merged) {
    await github.rest('POST', `statuses/${pr.sha}`, {
      state: result.state, context: statusContext, description: result.description,
      target_url: `https://github.com/${github.repository}/blob/${repository.defaultBranchRef.name}/CONTRIBUTING.md#pull-requests`,
    });
  }
  await summary([`### #${number}: ${result.state}`, result.description, ...result.problems.map((problem) => `- ${problem}`)].join('\n'));
  return result;
}

/** A new issue waits in needs-triage until it has a milestone; its pull requests are checked again. */
export async function checkIssue(github, number) {
  const { repository } = await github.graphql(issueQuery, { number });
  const issue = repository.issue;
  const marked = issue.labels.nodes.some((label) => label.name === triageLabel);
  const waiting = issue.state === 'OPEN' && !issue.milestone;
  if (waiting && !marked) await github.rest('POST', `issues/${number}/labels`, { labels: [triageLabel] });
  if (!waiting && marked) await github.rest('DELETE', `issues/${number}/labels/${encodeURIComponent(triageLabel)}`);
  for (const pr of issue.closedByPullRequestsReferences.nodes) {
    if (pr.state === 'OPEN') await checkPullRequest(github, pr.number);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const github = client({ token: process.env.GH_TOKEN, repository: process.env.GITHUB_REPOSITORY });
  const event = JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  if (event.pull_request) await checkPullRequest(github, event.pull_request.number);
  else if (event.issue && !event.issue.pull_request) await checkIssue(github, event.issue.number);
  else throw new Error('Neither a pull request nor an issue event');
}
