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
  assert.match(result.stdout, /SHA-256 will be verified on download/);
  assert.match(result.stdout, /Plan only: no downloads or installation performed/);
  assert.doesNotMatch(result.stdout, /SHA-256 verified/);
  await assert.rejects(fs.stat(tools), {code: 'ENOENT'});
});

async function fakeDarwinArm64(t, {systemPath = true, javaMode = 'missing'} = {}) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-provision-preflight-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const bin = path.join(root, 'bin');
  const tools = path.join(root, 'absent-tools');
  const javaHome = path.join(root, 'jdk');
  const javaBin = path.join(javaHome, 'bin');
  const networkMarker = path.join(root, 'curl-was-run');
  await fs.mkdir(bin);
  await fs.mkdir(javaBin, {recursive: true});
  await fs.writeFile(path.join(bin, 'uname'), '#!/bin/sh\ncase "$1" in -s) echo Darwin ;; -m) echo arm64 ;; esac\n');
  await fs.chmod(path.join(bin, 'uname'), 0o755);
  if (systemPath) {
    const curl = path.join(bin, 'curl');
    await fs.writeFile(curl, `#!/bin/sh\nprintf 'called\\n' > '${networkMarker}'\nexit 88\n`);
    await fs.chmod(curl, 0o755);
    for (const tool of ['xcodebuild', 'xcrun']) {
      const command = path.join(bin, tool);
      await fs.writeFile(command, '#!/bin/sh\nexit 0\n');
      await fs.chmod(command, 0o755);
    }
  } else {
    // A deliberately small PATH verifies a useful error for an unavailable required tool.
    for (const tool of ['python3', 'dirname']) {
      await fs.symlink(`/usr/bin/${tool}`, path.join(bin, tool));
    }
    for (const tool of ['unzip', 'shasum', 'xcodebuild']) {
      const command = path.join(bin, tool);
      await fs.writeFile(command, '#!/bin/sh\nexit 0\n');
      await fs.chmod(command, 0o755);
    }
    const curl = path.join(bin, 'curl');
    await fs.writeFile(curl, `#!/bin/sh\nprintf 'called\\n' > '${networkMarker}'\nexit 88\n`);
    await fs.chmod(curl, 0o755);
  }
  if (javaMode === 'failure') {
    await fs.writeFile(path.join(javaBin, 'java'), '#!/bin/sh\nprintf "fake JVM startup failure detail\\n" >&2\nexit 42\n');
  } else if (javaMode === 'valid') {
    await fs.writeFile(path.join(javaBin, 'java'), '#!/bin/sh\nprintf \'openjdk version "17.0.1"\\n\' >&2\n');
  }
  if (javaMode !== 'missing') await fs.chmod(path.join(javaBin, 'java'), 0o755);
  return {root, bin, tools, javaHome, javaBin, networkMarker, path: systemPath ? `${bin}:${process.env.PATH}` : bin};
}

function applyWithFakeMac(fixture, overrides = {}) {
  return spawnSync('/bin/bash', [script, '--apply'], {
    encoding: 'utf8',
    timeout: 10_000,
    env: {
      ...process.env,
      PATH: fixture.path,
      JAVA_HOME: fixture.javaHome,
      QUALIFICATION_TOOLS_ROOT: fixture.tools,
      QUALIFICATION_MIN_FREE_GIB: '30',
      QUALIFICATION_IOS_VERSION: '99.0',
      QUALIFICATION_IOS_BUILD: 'F00',
      QUALIFICATION_IOS_RUNTIME: 'com.apple.CoreSimulator.SimRuntime.iOS-99-0',
      ...overrides,
    },
  });
}

test('native apply explains missing JAVA_HOME/bin/java before creating SDK directories', async t => {
  const fixture = await fakeDarwinArm64(t);
  const result = applyWithFakeMac(fixture);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /JAVA_HOME must point to a JDK with an executable bin\/java/);
  await assert.rejects(fs.stat(fixture.tools), {code: 'ENOENT'});
  await assert.rejects(fs.stat(fixture.networkMarker), {code: 'ENOENT'});
});

test('native apply reports a captured JVM startup error before creating SDK directories', async t => {
  const fixture = await fakeDarwinArm64(t, {javaMode: 'failure'});
  const result = applyWithFakeMac(fixture);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Failed to run .*\/jdk\/bin\/java -version/);
  assert.match(result.stderr, /fake JVM startup failure detail/);
  await assert.rejects(fs.stat(fixture.tools), {code: 'ENOENT'});
  await assert.rejects(fs.stat(fixture.networkMarker), {code: 'ENOENT'});
});

test('native apply names a missing required tool before creating SDK directories', async t => {
  const fixture = await fakeDarwinArm64(t, {systemPath: false, javaMode: 'valid'});
  const result = applyWithFakeMac(fixture);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Required tool 'xcrun' was not found on PATH/);
  await assert.rejects(fs.stat(fixture.tools), {code: 'ENOENT'});
  await assert.rejects(fs.stat(fixture.networkMarker), {code: 'ENOENT'});
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

test('command-tools archive build maps to its verified archive revision and digest', async () => {
  const config = JSON.parse(await fs.readFile('qualification/native/toolchain.json', 'utf8'));
  assert.deepEqual(config.commandLineTools, {
    build: '15859902',
    revision: '22.0',
    archive: 'commandlinetools-mac_arm64-15859902_latest.zip',
    sha256: '835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e',
  });
});

async function preseededCommandTools(t, revision) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-provision-retry-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const bin = path.join(root, 'bin');
  const toolsRoot = path.join(root, 'owned-tools');
  const javaHome = path.join(root, 'jdk');
  const config = JSON.parse(await fs.readFile('qualification/native/toolchain.json', 'utf8'));
  const sdkManagerCalls = path.join(root, 'sdkmanager-calls');
  const curlMarker = path.join(root, 'curl-was-run');
  const sdkManagerPath = path.join(
    toolsRoot,
    'android-sdk',
    'cmdline-tools',
    config.commandLineTools.build,
    'bin',
    'sdkmanager',
  );
  const commandTools = path.dirname(path.dirname(sdkManagerPath));
  const androidHome = path.join(toolsRoot, 'android-sdk');
  const avdSentinel = path.join(toolsRoot, 'avd', 'keep.avd', 'keep.txt');
  const packageSentinel = path.join(androidHome, 'platform-tools', 'keep.txt');

  await fs.mkdir(bin, {recursive: true});
  await fs.mkdir(path.dirname(sdkManagerPath), {recursive: true});
  await fs.mkdir(path.dirname(avdSentinel), {recursive: true});
  await fs.mkdir(path.dirname(packageSentinel), {recursive: true});
  await fs.mkdir(path.join(javaHome, 'bin'), {recursive: true});
  await fs.writeFile(path.join(toolsRoot, '.wuselwall-qualification'), 'owned\n');
  await fs.writeFile(path.join(commandTools, 'source.properties'), `Pkg.Revision=${revision}\n`);
  await fs.writeFile(avdSentinel, 'keep this AVD\n');
  await fs.writeFile(packageSentinel, 'keep this package tree\n');
  await fs.writeFile(path.join(bin, 'uname'), '#!/bin/sh\ncase "$1" in -s) echo Darwin ;; -m) echo arm64 ;; esac\n');
  await fs.writeFile(path.join(javaHome, 'bin', 'java'), '#!/bin/sh\nprintf \'openjdk version "17.0.1"\\n\' >&2\n');
  await fs.writeFile(path.join(bin, 'curl'), `#!/bin/sh\nprintf 'called\\n' > '${curlMarker}'\nexit 88\n`);
  for (const tool of ['xcodebuild', 'xcrun', 'unzip', 'shasum']) {
    await fs.writeFile(path.join(bin, tool), '#!/bin/sh\nexit 0\n');
  }
  await fs.writeFile(
    sdkManagerPath,
    `#!/bin/sh\nprintf '%s\\n' "$*" >> '${sdkManagerCalls}'\nexit 89\n`,
  );
  for (const file of [path.join(bin, 'uname'), path.join(javaHome, 'bin', 'java'), path.join(bin, 'curl'), ...['xcodebuild', 'xcrun', 'unzip', 'shasum'].map(tool => path.join(bin, tool)), sdkManagerPath]) {
    await fs.chmod(file, 0o755);
  }
  return {
    root,
    toolsRoot,
    javaHome,
    sdkManagerCalls,
    curlMarker,
    avdSentinel,
    packageSentinel,
    path: `${bin}:${process.env.PATH}`,
  };
}

test('valid preseeded command tools reach sdkmanager on retry without deleting SDK or AVD files', async t => {
  const config = JSON.parse(await fs.readFile('qualification/native/toolchain.json', 'utf8'));
  const fixture = await preseededCommandTools(t, config.commandLineTools.revision);

  for (let attempt = 0; attempt < 2; attempt++) {
    const result = applyWithFakeMac(fixture, {
      QUALIFICATION_TOOLS_ROOT: fixture.toolsRoot,
      QUALIFICATION_ACCEPT_ANDROID_LICENSES: 'false',
    });
    assert.equal(result.status, 89, `${result.stdout}\n${result.stderr}`);
  }

  const expectedCall = `--sdk_root=${path.join(fixture.toolsRoot, 'android-sdk')} --list --channel=0\n`;
  assert.equal(await fs.readFile(fixture.sdkManagerCalls, 'utf8'), expectedCall.repeat(2));
  await assert.rejects(fs.stat(fixture.curlMarker), {code: 'ENOENT'});
  assert.equal(await fs.readFile(fixture.avdSentinel, 'utf8'), 'keep this AVD\n');
  assert.equal(await fs.readFile(fixture.packageSentinel, 'utf8'), 'keep this package tree\n');
  assert.equal(await fs.readFile(path.join(fixture.toolsRoot, '.wuselwall-qualification'), 'utf8'), 'owned\n');
});

test('mismatched preseeded command-tools revision reports expected and found without deleting files', async t => {
  const config = JSON.parse(await fs.readFile('qualification/native/toolchain.json', 'utf8'));
  const fixture = await preseededCommandTools(t, '23.0');
  const result = applyWithFakeMac(fixture, {
    QUALIFICATION_TOOLS_ROOT: fixture.toolsRoot,
    QUALIFICATION_ACCEPT_ANDROID_LICENSES: 'false',
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, new RegExp(`Command-tools revision mismatch: expected ${config.commandLineTools.revision}, found 23\\.0`));
  await assert.rejects(fs.stat(fixture.sdkManagerCalls), {code: 'ENOENT'});
  await assert.rejects(fs.stat(fixture.curlMarker), {code: 'ENOENT'});
  assert.equal(await fs.readFile(fixture.avdSentinel, 'utf8'), 'keep this AVD\n');
  assert.equal(await fs.readFile(fixture.packageSentinel, 'utf8'), 'keep this package tree\n');
  assert.equal(await fs.readFile(path.join(fixture.toolsRoot, '.wuselwall-qualification'), 'utf8'), 'owned\n');
});
