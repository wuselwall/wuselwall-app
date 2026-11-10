// A small GitHub API client for the repository's own automation (pr-policy.mjs,
// release.mjs): fetch only, no dependencies, and a fetcher the tests replace.
import assert from 'node:assert/strict';

export function client({ token, repository, fetcher = fetch, api = 'https://api.github.com' }) {
  assert.match(repository ?? '', /^[\w.-]+\/[\w.-]+$/, 'Invalid repository');
  assert.ok(token, 'A token is required (GH_TOKEN)');
  const [owner, name] = repository.split('/');
  const headers = {
    accept: 'application/vnd.github+json',
    authorization: `Bearer ${token}`,
    'content-type': 'application/json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
  const send = async (method, url, body) => {
    const response = await fetcher(url, {
      method, headers, body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(30_000),
    });
    const text = await response.text();
    const data = text ? JSON.parse(text) : null;
    if (!response.ok) {
      const error = new Error(`${method} ${url.replace(api, '')}: HTTP ${response.status} ${data?.message ?? ''}`.trim());
      error.status = response.status;
      throw error;
    }
    return data;
  };
  /** A REST call below repos/<owner>/<name>/. */
  const rest = (method, path, body) => send(method, `${api}/repos/${repository}/${path}`, body);
  /** Every page of a REST list. */
  const list = async (path) => {
    const all = [];
    for (let page = 1; page <= 50; page++) {
      const items = await rest('GET', `${path}${path.includes('?') ? '&' : '?'}per_page=100&page=${page}`);
      all.push(...items);
      if (items.length < 100) break;
    }
    return all;
  };
  const graphql = async (query, variables = {}) => {
    const result = await send('POST', `${api}/graphql`, { query, variables: { owner, name, ...variables } });
    assert.ok(!result.errors?.length, `GraphQL: ${result.errors?.map((e) => e.message).join('; ')}`);
    return result.data;
  };
  return { rest, list, graphql, owner, name, repository };
}

/** Appends to the job summary when there is one; always prints. */
export async function summary(markdown) {
  console.log(markdown);
  if (!process.env.GITHUB_STEP_SUMMARY) return;
  const { appendFileSync } = await import('node:fs');
  appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${markdown}\n`);
}

/** A release milestone is named like its app tag: v1.12.0. */
export const versionPattern = /^v(\d+)\.(\d+)\.(\d+)$/;
export const isVersionMilestone = (title) => versionPattern.test(title ?? '');
export const parseVersion = (text) => {
  const match = /(\d+)\.(\d+)\.(\d+)$/.exec(text ?? '');
  assert.ok(match, `Not a version: ${text}`);
  return match.slice(1).map(Number);
};
export const compareVersions = (a, b) => {
  const x = parseVersion(a);
  const y = parseVersion(b);
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] - y[i];
  return 0;
};
/** The open release milestone with the lowest version: what the next release ships. */
export const nextRelease = (milestones) =>
  milestones.filter((m) => isVersionMilestone(m.title)).sort((a, b) => compareVersions(a.title, b.title))[0] ?? null;
