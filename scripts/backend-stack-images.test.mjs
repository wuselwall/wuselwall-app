import assert from 'node:assert/strict';
import test from 'node:test';
import { prepareStackImages, registry, stackImages, stalePins } from './backend-stack-images.mjs';

const env = { SUPABASE_INTERNAL_IMAGE_REGISTRY: registry };
const tagOf = (ref) => ref.split(':').pop();
const nameOf = (ref) => ref.split('/').pop().split(':')[0];
// What `supabase services -o json` reports for the pinned CLI release (studio and the
// others not pinned are ignored).
const services = [
  ...stackImages.filter(({ ref }) => !['kong', 'mailpit', 'pg_prove'].includes(nameOf(ref)))
    .map(({ ref }) => ({ name: nameOf(ref) === 'postgrest' ? 'postgrest/postgrest' : `supabase/${nameOf(ref)}`,
      local: tagOf(ref), remote: '' })),
  { name: 'supabase/studio', local: '2026.10.05-sha-94b8b06', remote: '' },
];
const failure = (stderr) => Object.assign(new Error('Command failed'), { stderr });
const quiet = { sleep: async () => {}, warn: () => {} };

test('every pin names the CLI image under GHCR with a digest and at least one mirror', () => {
  for (const { ref, digest, mirrors } of stackImages) {
    assert.match(ref, /^ghcr\.io\/supabase\/[a-z_-]+:[\w.-]+$/);
    assert.match(digest, /^sha256:[0-9a-f]{64}$/);
    assert.ok(mirrors.length >= 1, ref);
    for (const mirror of mirrors) assert.equal(mirror.split('/').pop(), nameOf(ref));
  }
});

test('pins that match the CLI are not stale; a changed version is reported', () => {
  assert.deepEqual(stalePins(services), []);
  const bumped = services.map((s) => (s.name === 'supabase/gotrue' ? { ...s, local: 'v2.999.0' } : s));
  assert.deepEqual(stalePins(bumped), ['ghcr.io/supabase/gotrue:v2.197.0 (CLI runs v2.999.0)']);
});

test('a stale pin fails before anything is pulled', async () => {
  const calls = [];
  const bumped = services.map((s) => (s.name === 'postgrest/postgrest' ? { ...s, local: 'v99' } : s));
  await assert.rejects(prepareStackImages({ env, services: bumped, docker: (...a) => calls.push(a), ...quiet }),
    /Update the pins .*postgrest:v16\.4 \(CLI runs v99\)/);
  assert.deepEqual(calls, []);
});

test('another image registry for the CLI is refused', async () => {
  await assert.rejects(prepareStackImages({ env: {}, services, docker: () => '', ...quiet }),
    /SUPABASE_INTERNAL_IMAGE_REGISTRY must be ghcr\.io/);
});

test('cached images are kept; missing ones come from a mirror when GHCR refuses', async () => {
  const cached = new Set(stackImages.slice(1).map(({ ref }) => ref));
  const calls = [];
  const docker = (...args) => {
    calls.push(args.join(' '));
    if (args[0] === 'image' && !cached.has(args[2])) throw failure('No such image');
    if (args[0] === 'pull' && args[2].startsWith('ghcr.io/')) throw failure('toomanyrequests: retry-after: 81.3µs');
    return '';
  };
  await prepareStackImages({ env, services, docker, ...quiet });
  const [postgres] = stackImages;
  const mirrored = `${postgres.mirrors[0]}@${postgres.digest}`;
  assert.deepEqual(calls.filter((c) => !c.startsWith('image inspect')), [
    ...Array(3).fill(`pull --quiet ghcr.io/supabase/postgres@${postgres.digest}`),
    `pull --quiet ${mirrored}`, `tag ${mirrored} ${postgres.ref}`]);
});

test('a pull error other than a registry limit stops the step', async () => {
  const docker = (...args) => {
    if (args[0] === 'image') throw failure('No such image');
    throw failure('manifest unknown');
  };
  await assert.rejects(prepareStackImages({ env, services, docker, ...quiet }), /Command failed/);
});
