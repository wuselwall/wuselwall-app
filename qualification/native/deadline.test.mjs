import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {spawn, spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const python = process.env.PYTHON ?? 'python3';
const deadline = fileURLToPath(new URL('./deadline.py', import.meta.url));

test('deadline preserves successful output and a nonzero child exit status', () => {
  const success = spawnSync(python, [deadline, '1', 'quick-success', '--', python, '-c', 'print("child-output")'], {encoding: 'utf8'});
  assert.equal(success.status, 0, success.stderr);
  assert.match(success.stdout, /child-output/);
  assert.match(success.stderr, /NATIVE PHASE BEGIN quick-success/);

  const failure = spawnSync(python, [deadline, '1', 'quick-failure', '--', python, '-c', 'raise SystemExit(7)'], {encoding: 'utf8'});
  assert.equal(failure.status, 7);
});

test('invalid timeout limits are rejected before the child can run', async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-deadline-invalid-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const marker = path.join(root, 'ran');
  const result = spawnSync(python, [deadline, '0', 'invalid-limit', '--', python, '-c',
    'import pathlib,sys; pathlib.Path(sys.argv[1]).touch()', marker], {encoding: 'utf8'});
  assert.equal(result.status, 2);
  await assert.rejects(fs.stat(marker), {code: 'ENOENT'});
});

test('timeout terminates the child process group, including a descendant', async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-deadline-timeout-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const marker = path.join(root, 'descendant-terminated');
  const childFile = path.join(root, 'child.py');
  const parentFile = path.join(root, 'parent.py');
  await fs.writeFile(childFile, [
    'import pathlib,signal,time',
    `marker=pathlib.Path(${JSON.stringify(marker)})`,
    'def stopped(_sig,_frame):',
    '    marker.write_text("terminated")',
    '    raise SystemExit(0)',
    'signal.signal(signal.SIGTERM, stopped)',
    'while True: time.sleep(0.01)',
  ].join('\n'));
  await fs.writeFile(parentFile, [
    'import subprocess,sys,time',
    `subprocess.Popen([sys.executable,${JSON.stringify(childFile)}])`,
    'while True: time.sleep(0.01)',
  ].join('\n'));
  const result = spawnSync(python, [deadline, '1', 'descendant-timeout', '--', python, parentFile], {encoding: 'utf8'});
  assert.equal(result.status, 124, result.stderr);
  assert.match(result.stderr, /NATIVE PHASE TIMEOUT descendant-timeout/);
  assert.equal(await fs.readFile(marker, 'utf8'), 'terminated');
});

test('external TERM is forwarded to the phase process group', async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-deadline-signal-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const ready = path.join(root, 'ready');
  const marker = path.join(root, 'descendant-term');
  const childFile = path.join(root, 'child.py');
  const parentFile = path.join(root, 'parent.py');
  await fs.writeFile(childFile, [
    'import pathlib,signal,time',
    `ready=pathlib.Path(${JSON.stringify(ready)})`,
    `marker=pathlib.Path(${JSON.stringify(marker)})`,
    'def stopped(_sig,_frame):',
    '    marker.write_text("forwarded")',
    '    raise SystemExit(0)',
    'signal.signal(signal.SIGTERM, stopped)',
    'ready.write_text("ready")',
    'while True: time.sleep(0.01)',
  ].join('\n'));
  await fs.writeFile(parentFile, [
    'import subprocess,sys,time',
    `subprocess.Popen([sys.executable,${JSON.stringify(childFile)}])`,
    'while True: time.sleep(0.01)',
  ].join('\n'));
  const process = spawn(python, [deadline, '5', 'external-term', '--', python, parentFile], {stdio: 'ignore'});
  const exit = new Promise(resolve => process.once('exit', (code, signal) => resolve({code, signal})));
  const readyBy = Date.now() + 2000;
  while (Date.now() < readyBy) {
    try { await fs.access(ready); break; } catch { await new Promise(resolve => setTimeout(resolve, 10)); }
  }
  await fs.access(ready);
  process.kill('SIGTERM');
  assert.deepEqual(await exit, {code: 143, signal: null});
  assert.equal(await fs.readFile(marker, 'utf8'), 'forwarded');
});
