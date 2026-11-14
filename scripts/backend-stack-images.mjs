#!/usr/bin/env node
// Puts every image the Supabase CLI needs for backend CI's disposable stack (`supabase
// start`, `db reset`, `test db`) on the Docker host before the CLI runs. The CLI uses an
// image that is already present and otherwise gives up after three refused GHCR pulls, as
// on a runner whose GHCR pulls keep answering `toomanyrequests`. Here each missing image
// is pulled by its pinned digest from GHCR, then from the same digest on ECR Public or
// Docker Hub (scripts/image-pull.mjs), and tagged with the name the CLI looks for. Any other
// pull error fails the step at once.
//
// The pins must name the versions this CLI release runs: the step fails when
// `supabase services` reports another one, so a CLI bump updates them in the same change.
// The digests are the multi-arch index each registry serves for the tag.
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { pullImage } from './image-pull.mjs';

export const registry = 'ghcr.io';
const ecr = (name) => `public.ecr.aws/supabase/${name}`;
const hub = (name) => `docker.io/supabase/${name}`;
const pin = (name, tag, digest, mirrors) => ({ ref: `${registry}/supabase/${name}:${tag}`, digest, mirrors });

export const stackImages = [
  pin('postgres', '15.19.0.016', 'sha256:d70612c2e5d240926ca7c10384912da6e348108dfbf82c6ceb1abded7c3efb12',
    [ecr('postgres'), hub('postgres')]),
  pin('gotrue', 'v2.197.0', 'sha256:1736a63078f5922b198c4cbe50f80ab9a2d3b54fe8b7b6cfb2e9dc5dbbc12c6b',
    [ecr('gotrue'), hub('gotrue')]),
  pin('postgrest', 'v16.5', 'sha256:1347d7552b88f17832912c06afbf7c43209af6eeeb60834b04aae12c9bd9d5cc',
    [ecr('postgrest')]),
  pin('realtime', 'v2.151.3', 'sha256:dac44c958d0776144f0046ff0c0f8d51e0ff4f8a86c4a5e25287dd2f79fffa1e',
    [ecr('realtime'), hub('realtime')]),
  pin('storage-api', 'v1.88.0', 'sha256:dd4a100612635a8eb0d64387ddc38769fb30eb3ddd9b411d0fe3121e1cb223b3',
    [ecr('storage-api'), hub('storage-api')]),
  pin('edge-runtime', 'v1.77.9', 'sha256:6b850a2ccf0bf50ecac9accff8098095cd191c389c2a53c59b857aa0f53a8343',
    [ecr('edge-runtime'), hub('edge-runtime')]),
  pin('postgres-meta', 'v0.100.0', 'sha256:145325b7e39f8ef4931d6e8cfd3f6f4d655de09d72a2ccc96d9513542c2202bd',
    [ecr('postgres-meta'), hub('postgres-meta')]),
  // Not listed by `supabase services`; a stale pin here only means the CLI pulls the new
  // tag itself, without a mirror.
  pin('kong', '2.8.1', 'sha256:1b53405d8680a09d6f44494b7990bf7da2ea43f84a258c59717d4539abf09f6d',
    [ecr('kong')]),
  pin('mailpit', 'v1.31.3', 'sha256:ed9b00c609e77e99c79b93f1178255ebc271868920f2c69a8d166bd5634ed10d',
    [ecr('mailpit')]),
  pin('pg_prove', '3.36', 'sha256:eda7c5e68719e9c8287e78c017118407b48df904a51c935f5ab6098b8c0bc6bc',
    [ecr('pg_prove'), hub('pg_prove')]),
];

const baseName = (name) => name.split('/').pop();
const nameAndTag = (ref) => {
  const [, name, tag] = ref.match(/\/([^/:]+):([^/:]+)$/);
  return { name, tag };
};

// Pins whose tag differs from the version the installed CLI runs (`supabase services`).
export function stalePins(services, images = stackImages) {
  const local = new Map(services.map((s) => [baseName(s.name), s.local]));
  return images.flatMap(({ ref }) => {
    const { name, tag } = nameAndTag(ref);
    const wanted = local.get(name);
    return wanted && wanted !== tag ? [`${ref} (CLI runs ${wanted})`] : [];
  });
}

export async function prepareStackImages({ env = process.env, services, docker, ...options }) {
  if (env.SUPABASE_INTERNAL_IMAGE_REGISTRY !== registry) {
    throw new Error(`SUPABASE_INTERNAL_IMAGE_REGISTRY must be ${registry}; the CLI would look for other image names`);
  }
  const stale = stalePins(services);
  if (stale.length) {
    throw new Error(`Update the pins in scripts/backend-stack-images.mjs for this Supabase CLI: ${stale.join(', ')}`);
  }
  for (const image of stackImages) await pullImage(image, { docker, ...options });
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const run = (cmd, ...args) => execFileSync(cmd, args, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
  const services = JSON.parse(run('npx', '--no-install', 'supabase', 'services', '-o', 'json'));
  if (!Array.isArray(services)) throw new Error('Unexpected `supabase services -o json` output');
  await prepareStackImages({ services, docker: (...args) => run('docker', ...args) });
}
