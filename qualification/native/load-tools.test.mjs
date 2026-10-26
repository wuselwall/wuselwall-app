import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { spawnSync } from 'node:child_process';
const script = 'qualification/native/load-tools.sh';
async function fixture(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-native-load-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const settings = {ANDROID_HOME: `${root}/android-sdk`, ANDROID_AVD_HOME: `${root}/avd`,
    QUALIFICATION_ANDROID_PHONE_AVD: 'ww-phone', QUALIFICATION_ANDROID_TABLET_AVD: 'ww-tablet',
    QUALIFICATION_ANDROID_MIN_PHONE_AVD: 'ww-min-phone', QUALIFICATION_IOS_RUNTIME: 'com.apple.CoreSimulator.SimRuntime.iOS-27-1',
    QUALIFICATION_IOS_VERSION: '27.1', QUALIFICATION_IOS_BUILD: '24B123'};
  await fs.writeFile(path.join(root, '.wuselwall-qualification'), '');
  await fs.writeFile(path.join(root, 'environment.env'), Object.entries(settings).map(([k, v]) => `${k}=${v}\n`).join(''), {mode: 0o600});
  const out = path.join(root, 'github-env');
  const env = {...process.env, ...Object.fromEntries(Object.keys(settings).map(k => [k, ''])), QUALIFICATION_TOOLS_ROOT: root, GITHUB_ENV: out};
  return {root, out, env};
}

test('native tool loader restores persistent settings and respects explicit values', async t => {
  const {root, out, env} = await fixture(t);
  const result = spawnSync('bash', [script], {encoding: 'utf8', env: {...env, QUALIFICATION_ANDROID_PHONE_AVD: 'explicit-phone'}});
  assert.equal(result.status, 0, result.stderr);
  const data = await fs.readFile(out, 'utf8');
  assert.ok(data.includes(`ANDROID_HOME=${root}/android-sdk\n`));
  assert.ok(data.includes('QUALIFICATION_ANDROID_PHONE_AVD=explicit-phone\n'));
  assert.ok(data.includes('QUALIFICATION_IOS_RUNTIME=com.apple.CoreSimulator.SimRuntime.iOS-27-1\n'));
});

test('native tool loader treats malicious shell text as data and never executes it', async t => {
  const {root, out, env} = await fixture(t);
  const marker = path.join(root, 'executed');
  await fs.appendFile(path.join(root, 'environment.env'), `UNKNOWN=$(touch ${marker})\n`);
  const result = spawnSync('bash', [script], {encoding: 'utf8', env});
  assert.notEqual(result.status, 0);
  await assert.rejects(fs.stat(marker), {code: 'ENOENT'});
  await assert.rejects(fs.stat(out), {code: 'ENOENT'});
});

test('native tool loader rejects missing settings and symlinked environment files', async t => {
  const {root, out, env} = await fixture(t);
  await fs.rename(path.join(root, 'environment.env'), path.join(root, 'settings'));
  let result = spawnSync('bash', [script], {encoding: 'utf8', env});
  assert.notEqual(result.status, 0);
  await fs.symlink(path.join(root, 'settings'), path.join(root, 'environment.env'));
  result = spawnSync('bash', [script], {encoding: 'utf8', env});
  assert.notEqual(result.status, 0);
  await assert.rejects(fs.stat(out), {code: 'ENOENT'});
});
