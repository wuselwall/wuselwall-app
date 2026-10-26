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
  pin('postgres', '15.19.0.004', 'sha256:1d141ea194ba9c8d14c64cb93e72704887cd4b011732f122ace1576d29635c17',
    [ecr('postgres'), hub('postgres')]),
  pin('gotrue', 'v2.197.0', 'sha256:1736a63078f5922b198c4cbe50f80ab9a2d3b54fe8b7b6cfb2e9dc5dbbc12c6b',
    [ecr('gotrue'), hub('gotrue')]),
  pin('postgrest', 'v16.4', 'sha256:d155c6718ed9a9f990d159a2ab7c0a3f16944dbb6d0a0344557421042acfe0df',
    [ecr('postgrest')]),
  pin('realtime', 'v2.143.4', 'sha256:35e99d3f1cbba5aa5585e8ac3cf70ecc54909ee4aee0626effed93c60fb41439',
    [ecr('realtime'), hub('realtime')]),
  pin('storage-api', 'v1.82.1', 'sha256:ec2ad41411eac8fc2b769b4bb00d1af32ae37eca3745c15bdb329db27d218934',
    [ecr('storage-api'), hub('storage-api')]),
  pin('edge-runtime', 'v1.77.4', 'sha256:ad45164b7548bf5820ed7be714789c17ac2865edce79a09cfb4c3756c3d365a8',
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
