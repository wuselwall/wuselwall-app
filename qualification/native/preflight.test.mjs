import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const script = new URL('./preflight.sh', import.meta.url);

async function fixture(t, {flutter = false, avds = 'ww-phone\n', acceleration = true} = {}) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-native-preflight-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const bin = path.join(root, 'bin');
  const sdk = path.join(root, 'android-sdk');
  const output = path.join(root, 'output');
  await fs.mkdir(bin);
  await fs.mkdir(path.join(sdk, 'emulator'), {recursive: true});
  const command = async (name, body) => fs.writeFile(path.join(bin, name), `#!/bin/sh\n${body}\n`, {mode: 0o755});
  await command('uname', 'if [ "$1" = -m ]; then echo arm64; else echo Darwin; fi');
  await command('sysctl', 'if [ "$2" = hw.optional.arm64 ]; then echo 1; else echo 0; fi');
  await command('sw_vers', 'echo 15.0');
  await command('java', 'exit 0');
  await fs.writeFile(path.join(sdk, 'emulator', 'emulator'),
    `#!/bin/sh\nif [ "$1" = -list-avds ]; then printf '%s'; else exit ${acceleration ? '0' : '1'}; fi\n`
      .replace('%s', avds.replaceAll("'", "'\\''")), {mode: 0o755});
  if (flutter) await command('flutter', 'echo \'{"frameworkVersion":"test"}\'');
  return {root, bin, sdk, output, env: {...process.env, PATH: `${bin}:/usr/bin:/bin`, ANDROID_HOME: sdk,
    QUALIFICATION_TOOLS_ROOT: path.join(root, 'tools')}};
}

function run(fixture, ...args) {
  return spawnSync('/bin/bash', [script.pathname, fixture.output, 'android', ...args], {
    encoding: 'utf8', env: fixture.env,
  });
}

test('device-tools mode records Flutter bootstrap requirement but validates Android tools', async t => {
  const f = await fixture(t);
  const result = run(f, 'device-tools');
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(await fs.readFile(path.join(f.output, 'flutter-status.json'), 'utf8')),
    {status: 'WORKFLOW_BOOTSTRAP_REQUIRED', tool: 'flutter', requiredVersion: '3.47.7'});
});

test('default full mode remains strict when Flutter is absent', async t => {
  const f = await fixture(t);
  const result = run(f);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Unavailable probe: flutter\.json/);
});

test('device-tools mode still fails when Android SDK is not configured', async t => {
  const f = await fixture(t);
  delete f.env.ANDROID_HOME;
  const result = run(f, 'device-tools');
  assert.equal(result.status, 1);
  assert.match(await fs.readFile(path.join(f.output, 'android-sdk.txt'), 'utf8'), /ANDROID_HOME is not configured/);
});

test('device-tools mode still fails when no Android AVD is available', async t => {
  const f = await fixture(t, {avds: ''});
  const result = run(f, 'device-tools');
  assert.equal(result.status, 1);
  assert.match(result.stderr, /No Android AVDs are available/);
});

test('device-tools mode still fails when Android acceleration is unavailable', async t => {
  const f = await fixture(t, {acceleration: false});
  const result = run(f, 'device-tools');
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Unavailable probe: android-acceleration\.txt/);
});
