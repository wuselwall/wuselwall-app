// Pulls a pinned image for a disposable test stack. An image already on this Docker host
// (self-hosted runner, developer machine) is used as is. Anonymous registry limits are
// retried; when one registry keeps refusing, the same manifest digest is pulled from a
// mirror and tagged with the canonical name, so the test runs the identical image.
// Any other pull error fails at once.
const limitPattern = /toomanyrequests|rate limit|data limit exceeded/i;
export const isRegistryLimit = (error) => limitPattern.test(String(error?.stderr ?? error?.message ?? error));

const repository = (ref) => ref.replace(/:[^/:]+$/, '');

export async function pullImage(image, {
  docker, sleep = (ms) => new Promise((r) => setTimeout(r, ms)), warn = console.warn,
  attempts = 3, backoffMs = 15000,
} = {}) {
  const { ref, digest, mirrors = [] } = typeof image === 'string' ? { ref: image } : image;
  if (mirrors.length && !digest) throw new Error(`${ref}: mirrors need a pinned digest`);
  try { docker('image', 'inspect', ref); return ref; } catch { /* not cached */ }
  const sources = digest ? [repository(ref), ...mirrors].map((repo) => `${repo}@${digest}`) : [ref];
  let lastError;
  for (const [index, source] of sources.entries()) {
    for (let attempt = 1; attempt <= attempts; attempt++) {
      try {
        docker('pull', '--quiet', source);
        if (source !== ref) docker('tag', source, ref);
        return source;
      } catch (error) {
        if (!isRegistryLimit(error)) throw error;
        lastError = error;
        if (attempt < attempts) {
          warn(`Registry limit while pulling ${source}; retrying (${attempt}/${attempts - 1})`);
          await sleep(attempt * backoffMs);
        }
      }
    }
    if (index < sources.length - 1) warn(`Registry limit persists for ${source}; trying ${sources[index + 1]}`);
  }
  throw lastError;
}
