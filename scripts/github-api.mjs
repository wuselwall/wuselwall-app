// A small GitHub API client for the repository's own automation (pr-policy.mjs,
// release.mjs): fetch only, no dependencies, and a fetcher the tests replace.
import assert from 'node:assert/strict';

/** Answers worth asking again: GitHub's own server errors and its rate limit. */
export const transientStatuses = new Set([429, 500, 502, 503, 504]);
/** Methods whose repetition leaves the same result (RFC 9110); a POST is retried only when the caller says so. */
const idempotentMethods = new Set(['GET', 'HEAD', 'PUT', 'PATCH', 'DELETE']);
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export function client({ token, repository, fetcher = fetch, api = 'https://api.github.com', attempts = 3, sleep = pause }) {
  assert.match(repository ?? '', /^[\w.-]+\/[\w.-]+$/, 'Invalid repository');
  assert.ok(token, 'A token is required (GH_TOKEN)');
  const [owner, name] = repository.split('/');
  const headers = {
    accept: 'application/vnd.github+json',
    authorization: `Bearer ${token}`,
    'content-type': 'application/json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
  const once = async (method, url, body) => {
    let response;
    try {
      response = await fetcher(url, {
        method, headers, body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(30_000),
      });
    } catch (cause) {
      // No answer (network, timeout): the request may or may not have arrived.
      const error = new Error(`${method} ${url.replace(api, '')}: ${cause.message}`, { cause });
      error.transient = true;
      throw error;
    }
    const text = await response.text();
    if (!response.ok) {
      // A proxy in front of GitHub answers a 502 with HTML: keep the status, not a JSON error.
      let message = '';
      try { message = JSON.parse(text)?.message ?? ''; } catch { message = ''; }
      const error = new Error(`${method} ${url.replace(api, '')}: HTTP ${response.status} ${message}`.trim());
      error.status = response.status;
      error.transient = transientStatuses.has(response.status);
      const after = Number(response.headers?.get?.('retry-after'));
      if (Number.isFinite(after) && after > 0) error.retryAfter = after;
      throw error;
    }
    return text ? JSON.parse(text) : null;
  };
  /**
   * One call, asked again after a transient failure when repeating it is safe: an idempotent
   * method, or `retry: true` from a caller whose POST leaves the same state when repeated.
   * Anything else (401, 403, 404, 422, the last attempt) is thrown to the caller.
   */
  const send = async (method, url, body, { retry = idempotentMethods.has(method) } = {}) => {
    for (let attempt = 1; ; attempt++) {
      try {
        return await once(method, url, body);
      } catch (error) {
        if (!retry || !error.transient || attempt >= attempts) {
          if (attempt > 1) error.message += ` (after ${attempt} attempts)`;
          throw error;
        }
        const wait = Math.min(error.retryAfter ? error.retryAfter * 1000 : 2000 * 2 ** (attempt - 1), 30_000);
        console.warn(`${error.message}; asking again in ${wait / 1000} s`);
        await sleep(wait);
      }
    }
  };
  /** A REST call below repos/<owner>/<name>/. */
  const rest = (method, path, body, options) => send(method, `${api}/repos/${repository}/${path}`, body, options);
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
    // A query only reads; a mutation is not asked twice.
    const reads = /^\s*query\b/.test(query);
    const result = await send('POST', `${api}/graphql`, { query, variables: { owner, name, ...variables } }, { retry: reads });
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
