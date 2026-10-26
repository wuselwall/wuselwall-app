import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
const script = 'qualification/native/provision.sh';

test('native provisioning dry-run is offline and creates no dedicated directory', async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-provision-plan-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const tools = path.join(root, 'absent-tools');
  const result = spawnSync('bash', [script, '--dry-run'], {encoding: 'utf8', env: {...process.env, QUALIFICATION_TOOLS_ROOT: tools}});
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /system-images;android-24;google_apis;arm64-v8a/);
  assert.match(result.stdout, /system-images;android-36;google_apis;arm64-v8a/);
  assert.match(result.stdout, /SHA-256 verified/);
  await assert.rejects(fs.stat(tools), {code: 'ENOENT'});
});

test('native provisioning refuses invalid disk limits, paths and floating runtime strings before writes', async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-provision-invalid-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  for (const overrides of [
    {QUALIFICATION_MIN_FREE_GIB: '0'}, {QUALIFICATION_MIN_FREE_GIB: '501'},
    {QUALIFICATION_TOOLS_ROOT: 'relative/tools'}, {QUALIFICATION_IOS_BUILD: 'latest;download'},
    {QUALIFICATION_IOS_RUNTIME: 'arbitrary-runtime'},
  ]) {
    const result = spawnSync('bash', [script, '--dry-run'], {encoding: 'utf8', env: {...process.env, QUALIFICATION_TOOLS_ROOT: path.join(root, 'absent-tools'), ...overrides}});
    assert.notEqual(result.status, 0);
  }
  assert.deepEqual(await fs.readdir(root), []);
});

test('native toolchain pins both supported API endpoints and ARM64 CI-only devices', async () => {
  const config = JSON.parse(await fs.readFile('qualification/native/toolchain.json', 'utf8'));
  assert.match(config.commandLineTools.archive, /^commandlinetools-mac_arm64-\d+_latest\.zip$/);
  assert.match(config.commandLineTools.sha256, /^[a-f0-9]{64}$/);
  assert.equal(new Set(config.packages.map(p => p.path)).size, config.packages.length);
  assert.ok(config.packages.some(p => p.path === 'system-images;android-24;google_apis;arm64-v8a'));
  assert.ok(config.packages.some(p => p.path === 'system-images;android-36;google_apis;arm64-v8a'));
  assert.equal(config.avds.length, 3);
  for (const avd of config.avds) {
    assert.match(avd.name, /^ww-qualification-/);
    assert.ok(avd.image.endsWith(';arm64-v8a'));
    assert.ok(config.packages.some(p => p.path === avd.image));
  }
});
