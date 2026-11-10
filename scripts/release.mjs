// Cuts a release, for .github/workflows/release.yml (CONTRIBUTING.md "Releases"):
//
//   node scripts/release.mjs plan       what would be released; writes the job outputs
//   node scripts/release.mjs tag        the two annotated tags, the app's GitHub release
//                                       with generated notes, and the build workflows
//   node scripts/release.mjs rollover   closes the milestone, opens the next one and moves
//                                       what is still open into it
//
// An app release is the tag v<version>, a server release the tag server-v<version>; their
// numbers are independent (specs/10). A tag made with the workflow's own token starts no
// workflow, so `tag` starts each one on the tag by workflow_dispatch; they then run exactly
// as for a pushed tag, behind the same qualification and release-promotion approval.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { client, compareVersions, isVersionMilestone, nextRelease, parseVersion, summary } from './github-api.mjs';

export const appWorkflows = ['ci.yml', 'backend-ci.yml', 'release-android.yml', 'release-ios.yml'];
export const serverWorkflows = ['server-release.yml'];
/** Rebuilt on the default branch afterwards: its compatibility table reads the tags. */
export const afterWorkflows = ['docs.yml'];
export const bumps = ['minor', 'patch', 'major', 'none'];

const newest = (tags, pattern) =>
  tags.filter((tag) => pattern.test(tag)).sort((a, b) => compareVersions(a, b)).at(-1) ?? null;

export function bump(version, kind) {
  const [major, minor, patch] = parseVersion(version);
  if (kind === 'major') return `${major + 1}.0.0`;
  if (kind === 'minor') return `${major}.${minor + 1}.0`;
  if (kind === 'patch') return `${major}.${minor}.${patch + 1}`;
  throw new Error(`Unknown bump: ${kind}`);
}

/**
 * tags: every tag name; milestones: the open milestones [{ number, title }];
 * version: the app version asked for ('' = the next release milestone's);
 * server: how the server version moves (minor, patch, major, none).
 */
export function plan({ tags, milestones, version = '', server = 'minor' }) {
  assert.ok(bumps.includes(server), `server must be one of ${bumps.join(', ')}`);
  const previousApp = newest(tags, /^v\d+\.\d+\.\d+$/);
  const previousServer = newest(tags, /^server-v\d+\.\d+\.\d+$/);
  const open = milestones.filter((m) => isVersionMilestone(m.title));
  let appVersion = version.trim().replace(/^v/, '');
  if (!appVersion) {
    const next = nextRelease(open);
    assert.ok(next, 'No version given and no open release milestone (like v1.12.0) to take it from');
    appVersion = next.title.slice(1);
  }
  assert.match(appVersion, /^\d+\.\d+\.\d+$/, 'The app version must look like 1.12.0');
  const appTag = `v${appVersion}`;
  assert.ok(!tags.includes(appTag), `${appTag} exists already`);
  if (previousApp) assert.ok(compareVersions(appTag, previousApp) > 0, `${appTag} is not newer than ${previousApp}`);
  const milestone = open.find((m) => m.title === appTag) ?? null;
  const earlier = open.filter((m) => compareVersions(m.title, appTag) < 0).map((m) => m.title);
  assert.equal(earlier.length, 0, `Release or close the earlier milestone first: ${earlier.join(', ')}`);
  const later = nextRelease(open.filter((m) => compareVersions(m.title, appTag) > 0));
  let serverTag = null;
  if (server !== 'none') {
    assert.ok(previousServer, 'No earlier server-v tag to count from');
    serverTag = `server-v${bump(previousServer, server)}`;
    assert.ok(!tags.includes(serverTag), `${serverTag} exists already`);
  }
  return {
    app: { version: appVersion, tag: appTag, previous: previousApp },
    server: serverTag ? { version: serverTag.slice('server-v'.length), tag: serverTag, previous: previousServer } : null,
    milestone,
    next: later ? later.title : `v${bump(appVersion, 'minor')}`,
  };
}

const tagNames = async (github) =>
  (await github.list('git/matching-refs/tags/')).map((ref) => ref.ref.replace('refs/tags/', ''));
const openMilestones = (github) => github.list('milestones?state=open');
const openItems = (github, milestone) => github.list(`issues?state=open&milestone=${milestone}`);
const output = (values) => {
  const text = Object.entries(values).map(([key, value]) => `${key}=${value ?? ''}`).join('\n');
  if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, `${text}\n`);
};

async function runPlan(github, env) {
  const result = plan({
    tags: await tagNames(github), milestones: await openMilestones(github),
    version: env.RELEASE_VERSION ?? '', server: env.RELEASE_SERVER || 'minor',
  });
  const moving = result.milestone ? await openItems(github, result.milestone.number) : [];
  output({
    app_tag: result.app.tag, app_previous: result.app.previous,
    server_tag: result.server?.tag, server_previous: result.server?.previous,
    milestone: result.milestone?.number, next: result.next,
  });
  await summary([
    `## Release plan for \`${env.GITHUB_SHA}\``,
    `- App: **${result.app.tag}** (after ${result.app.previous ?? 'no earlier release'})`,
    `- Server: ${result.server ? `**${result.server.tag}** (after ${result.server.previous})` : 'no server release'}`,
    `- Milestone: ${result.milestone ? `closes ${result.milestone.title}` : `none is named ${result.app.tag}`}; the next one is ${result.next}`,
    moving.length > 0 ? `- Still open, moved to ${result.next}:` : '- Nothing open is left in the milestone',
    ...moving.map((item) => `  - #${item.number} ${item.title}`),
  ].join('\n'));
  return result;
}

async function createTag(github, { tag, sha, message }) {
  const existing = await github.rest('GET', `git/ref/tags/${tag}`).catch((error) => {
    if (error.status === 404) return null;
    throw error;
  });
  if (existing) {
    // A second attempt of the same run: the tag may stand, but only on this commit.
    const target = existing.object.type === 'tag'
      ? (await github.rest('GET', `git/tags/${existing.object.sha}`)).object.sha : existing.object.sha;
    assert.equal(target, sha, `${tag} exists on another commit`);
    return;
  }
  const object = await github.rest('POST', 'git/tags', { tag, message, object: sha, type: 'commit' });
  await github.rest('POST', 'git/refs', { ref: `refs/tags/${tag}`, sha: object.sha });
}

async function runTag(github, env) {
  const sha = env.GITHUB_SHA;
  const about = env.RELEASE_SUMMARY?.trim();
  const appTag = env.APP_TAG;
  const serverTag = env.SERVER_TAG || null;
  assert.match(appTag ?? '', /^v\d+\.\d+\.\d+$/, 'APP_TAG is missing');
  const appVersion = appTag.slice(1);
  await createTag(github, { tag: appTag, sha, message: `WuselWall app ${appVersion}${about ? `: ${about}` : ''}` });
  if (serverTag) {
    await createTag(github, { tag: serverTag, sha, message: `WuselWall server ${serverTag.slice('server-v'.length)}${about ? `: ${about}` : ''}` });
  }
  const released = await github.rest('GET', `releases/tags/${appTag}`).catch((error) => {
    if (error.status === 404) return null;
    throw error;
  });
  if (!released) {
    const notes = await github.rest('POST', 'releases/generate-notes', {
      tag_name: appTag, target_commitish: sha, ...(env.APP_PREVIOUS ? { previous_tag_name: env.APP_PREVIOUS } : {}),
    });
    const lead = [
      about ? `${about}\n` : null,
      serverTag ? `Released together with [${serverTag}](https://github.com/${github.repository}/releases/tag/${serverTag}).` : null,
      'The signed Android APK is attached once its build is approved; the stores get the same build.',
    ].filter(Boolean).join('\n');
    // The server release stays "latest": it is the download a family's server needs.
    await github.rest('POST', 'releases', {
      tag_name: appTag, name: `WuselWall ${appVersion}`, body: `${lead}\n\n${notes.body}`, make_latest: 'false',
    });
  }
  const started = [];
  for (const workflow of appWorkflows) {
    await github.rest('POST', `actions/workflows/${workflow}/dispatches`, { ref: appTag });
    started.push(`${workflow} on ${appTag}`);
  }
  for (const workflow of serverTag ? serverWorkflows : []) {
    await github.rest('POST', `actions/workflows/${workflow}/dispatches`, { ref: serverTag });
    started.push(`${workflow} on ${serverTag}`);
  }
  for (const workflow of afterWorkflows) {
    await github.rest('POST', `actions/workflows/${workflow}/dispatches`, { ref: env.GITHUB_REF_NAME });
    started.push(`${workflow} on ${env.GITHUB_REF_NAME}`);
  }
  await summary(['## Tagged and started', ...started.map((line) => `- ${line}`),
    '', 'The builds wait for the approval of the `release-promotion` environment.'].join('\n'));
}

async function runRollover(github, env) {
  const milestones = await openMilestones(github);
  const title = env.NEXT_MILESTONE;
  assert.ok(isVersionMilestone(title), 'NEXT_MILESTONE is missing');
  const next = milestones.find((m) => m.title === title)
    ?? await github.rest('POST', 'milestones', { title, description: 'The next release. Planned work lives here; what merges ships with it.' });
  const lines = [`## Milestones`, `- ${title} is the next release`];
  if (env.MILESTONE) {
    const number = Number(env.MILESTONE);
    const moved = await openItems(github, number);
    for (const item of moved) await github.rest('PATCH', `issues/${item.number}`, { milestone: next.number });
    await github.rest('PATCH', `milestones/${number}`, { state: 'closed' });
    lines.push(`- ${env.APP_TAG} closed`, ...moved.map((item) => `- moved #${item.number} ${item.title}`));
  }
  await summary(lines.join('\n'));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const github = client({ token: process.env.GH_TOKEN, repository: process.env.GITHUB_REPOSITORY });
  const commands = { plan: runPlan, tag: runTag, rollover: runRollover };
  const command = commands[process.argv[2]];
  assert.ok(command, `usage: release.mjs ${Object.keys(commands).join('|')}`);
  await command(github, process.env);
}
