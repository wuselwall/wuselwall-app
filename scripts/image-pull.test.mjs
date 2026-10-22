import assert from 'node:assert/strict';
import test from 'node:test';
import { pullImage } from './image-pull.mjs';

const digest = 'sha256:' + 'a'.repeat(64);
const image = { ref: 'ghcr.io/supabase/gotrue:v1', digest,
  mirrors: ['public.ecr.aws/supabase/gotrue', 'docker.io/supabase/gotrue'] };
const failure = (stderr) => Object.assign(new Error('Command failed'), { stderr });
const limited = () => failure('Error response from daemon: toomanyrequests: retry-after: 234.603µs, allowed: 44000/minute');

// A fake Docker CLI: `refuse(args)` returns an error to throw, or nothing to succeed.
function fakeDocker(refuse) {
  const calls = [];
  const docker = (...args) => {
    calls.push(args.join(' '));
    if (args[0] === 'image') throw failure('No such image');
    const error = refuse(args);
    if (error) throw error;
    return '';
  };
  return { docker, calls };
}
const options = (docker, warnings = []) => ({ docker, sleep: async () => {}, warn: (m) => warnings.push(m) });

test('a cached image is used without pulling', async () => {
  const calls = [];
  await pullImage(image, options((...args) => { calls.push(args.join(' ')); return '[]'; }));
  assert.deepEqual(calls, [`image inspect ${image.ref}`]);
});

test('the primary registry is pulled by digest and tagged with the canonical name', async () => {
  const { docker, calls } = fakeDocker(() => undefined);
  assert.equal(await pullImage(image, options(docker)), `ghcr.io/supabase/gotrue@${digest}`);
  assert.deepEqual(calls.slice(1), [`pull --quiet ghcr.io/supabase/gotrue@${digest}`,
    `tag ghcr.io/supabase/gotrue@${digest} ${image.ref}`]);
});

test('a registry that keeps refusing falls back to the same digest on a mirror', async () => {
  const { docker, calls } = fakeDocker((args) => (args[0] === 'pull' && args[2].startsWith('ghcr.io/') ? limited() : undefined));
  const warnings = [];
  assert.equal(await pullImage(image, options(docker, warnings)), `public.ecr.aws/supabase/gotrue@${digest}`);
  assert.equal(calls.filter((c) => c.startsWith('pull --quiet ghcr.io/')).length, 3);
  assert.equal(calls.at(-1), `tag public.ecr.aws/supabase/gotrue@${digest} ${image.ref}`);
  assert.ok(warnings.some((w) => w.includes('trying public.ecr.aws/supabase/gotrue@')));
});

test('when every registry stays limited the pull fails with the registry error', async () => {
  const { docker, calls } = fakeDocker((args) => (args[0] === 'pull' ? limited() : undefined));
  await assert.rejects(pullImage(image, options(docker)), (error) => /toomanyrequests/.test(error.stderr));
  assert.equal(calls.filter((c) => c.startsWith('pull ')).length, 9);
  assert.ok(!calls.some((c) => c.startsWith('tag ')));
});

test('any other pull error fails at once without trying a mirror', async () => {
  const { docker, calls } = fakeDocker((args) => (args[0] === 'pull' ? failure('manifest unknown') : undefined));
  await assert.rejects(pullImage(image, options(docker)), /Command failed/);
  assert.equal(calls.filter((c) => c.startsWith('pull ')).length, 1);
});

test('an unpinned image is pulled by tag and retried only on limits', async () => {
  let refusals = 2;
  const { docker, calls } = fakeDocker((args) => (args[0] === 'pull' && refusals-- > 0 ? limited() : undefined));
  assert.equal(await pullImage('postgres:15-alpine', options(docker)), 'postgres:15-alpine');
  assert.deepEqual(calls.filter((c) => c.startsWith('pull ')), Array(3).fill('pull --quiet postgres:15-alpine'));
  assert.ok(!calls.some((c) => c.startsWith('tag ')));
});

test('mirrors without a pinned digest are rejected', async () => {
  await assert.rejects(pullImage({ ref: 'x:1', mirrors: ['y'] }, options(() => '')), /pinned digest/);
});
