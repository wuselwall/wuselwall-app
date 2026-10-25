// Baseline creation is explicit and separate from comparison. No network writes.
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { inventory, root } from './matrix.mjs';

export const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
export function environment() {
  return { platform: process.platform, arch: process.arch, osRelease: os.release(),
    flutter: fs.readFileSync(path.join(root, 'app/pubspec.yaml'), 'utf8').match(/^  flutter: ([\d.]+)$/m)?.[1],
    playwright: JSON.parse(fs.readFileSync(path.join(root, 'node_modules/playwright/package.json'), 'utf8')).version,
    inventory: sha256(fs.readFileSync(path.join(root, 'qualification/inventory.json'))),
    renderer: 'CanvasKit/SwiftShader; deviceScaleFactor=1', clock: inventory.clock,
  };
}

function safeFile(dir, name) {
  if (!/^[a-z0-9-]+\/[a-z0-9.-]+\.(png|aria\.yml)$/.test(name)) throw new Error(`Invalid baseline path: ${name}`);
  const resolved = path.resolve(dir, name);
  if (!resolved.startsWith(`${path.resolve(dir)}${path.sep}`) || fs.lstatSync(resolved).isSymbolicLink()) throw new Error('Unsafe baseline file');
  if (!fs.realpathSync(resolved).startsWith(`${fs.realpathSync(dir)}${path.sep}`)) throw new Error('Baseline path escapes its directory');
  return resolved;
}

export function seal(dir, sourceSha, env = environment()) {
  if (!/^[a-f0-9]{40}$/.test(sourceSha)) throw new Error('A full source commit SHA is required');
  const files = {};
  for (const name of fs.readdirSync(dir, { recursive: true }).sort()) {
    if (!name.endsWith('.png') && !name.endsWith('.aria.yml')) continue;
    files[name] = sha256(fs.readFileSync(safeFile(dir, name)));
  }
  const names = Object.keys(files);
  if (!names.length || names.some(name => name.endsWith('.png') && !files[name.replace(/\.png$/, '.aria.yml')])) {
    throw new Error('A baseline needs nonempty image/semantics pairs');
  }
  for (const name of names.filter(n => n.endsWith('.aria.yml'))) {
    if (!files[name.replace(/\.aria\.yml$/, '.png')]) throw new Error('Missing image for semantic snapshot');
  }
  const manifest = { schema: 1, sourceSha, environment: env, files };
  fs.writeFileSync(path.join(dir, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
  return manifest;
}

export function verify(dir, manifestBytes, expectedDigest, env = environment()) {
  if (!/^[a-f0-9]{64}$/.test(expectedDigest) || sha256(manifestBytes) !== expectedDigest) throw new Error('Baseline manifest checksum mismatch');
  const manifest = JSON.parse(manifestBytes);
  if (manifest.schema !== 1 || !/^[a-f0-9]{40}$/.test(manifest.sourceSha) || !Object.keys(manifest.files || {}).length) throw new Error('Invalid baseline manifest');
  if (JSON.stringify(manifest.environment) !== JSON.stringify(env)) throw new Error('Baseline capture environment or inventory differs');
  const files = fs.readdirSync(dir, { recursive: true }).filter(n => n.endsWith('.png') || n.endsWith('.aria.yml')).sort();
  if (JSON.stringify(files) !== JSON.stringify(Object.keys(manifest.files).sort())) throw new Error('Baseline files differ from its manifest');
  for (const [name, digest] of Object.entries(manifest.files)) {
    if (sha256(fs.readFileSync(safeFile(dir, name))) !== digest) throw new Error(`Baseline file checksum mismatch: ${name}`);
  }
  return manifest;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [command, dir, value] = process.argv.slice(2);
  if (command === 'seal') {
    seal(dir, value);
    console.log(`UNAPPROVED bundle manifest SHA-256: ${sha256(fs.readFileSync(path.join(dir, 'manifest.json')))}`);
  } else if (command === 'verify') {
    verify(dir, fs.readFileSync(path.join(dir, 'manifest.json')), value);
    console.log('Baseline checksums and capture environment verified');
  } else throw new Error('Usage: baseline.mjs seal DIRECTORY SOURCE_SHA | verify DIRECTORY MANIFEST_SHA256');
}
