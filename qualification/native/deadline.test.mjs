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

// macOS (XNU killpg1) answers EPERM, not ESRCH, when every remaining member of a
// process group is a zombie. Linux signals zombies, so the shim reproduces the macOS
// answer from /proc; on macOS the real kernel answers. WW_DENY_SIGNALS emulates a
// member the runner may not signal at all.
const xnuShim = [
  'import os, runpy, sys',
  'real_killpg = os.killpg',
  'def states(pgid):',
  '    found = []',
  '    for entry in os.listdir("/proc"):',
  '        if not entry.isdigit(): continue',
  '        try: stat = open(f"/proc/{entry}/stat").read()',
  '        except OSError: continue',
  '        fields = stat[stat.rindex(")") + 2:].split()',
  '        if int(fields[2]) == pgid: found.append(fields[0])',
  '    return found',
  'def killpg(pgid, sig):',
  '    found = states(pgid)',
  '    if not found: raise ProcessLookupError(3, "No such process")',
  '    if os.environ.get("WW_DENY_SIGNALS") == "1" or all(s == "Z" for s in found):',
  '        raise PermissionError(1, "Operation not permitted")',
  '    return real_killpg(pgid, sig)',
  'if os.path.isdir("/proc"): os.killpg = killpg',
  'sys.argv = sys.argv[1:]',
  'runpy.run_path(sys.argv[0], run_name="__main__")',
].join('\n');

const alive = pid => { try { process.kill(pid, 0); return true; } catch { return false; } };

async function waitForFile(file, ms = 3000) {
  const by = Date.now() + ms;
  while (Date.now() < by) {
    try { return await fs.readFile(file, 'utf8'); } catch { await new Promise(resolve => setTimeout(resolve, 10)); }
  }
  return fs.readFile(file, 'utf8');
}

test('timeout cleanup tolerates the macOS zombie-group EPERM and leaves an escaped daemon alone', async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-deadline-eperm-'));
  const shim = path.join(root, 'xnu.py');
  const starter = path.join(root, 'start-server.py');
  const daemonPid = path.join(root, 'daemon.pid');
  await fs.writeFile(shim, xnuShim);
  // Like `adb start-server`: a daemon leaves the group with setsid, the client waits for it.
  await fs.writeFile(starter, [
    'import os, pathlib, signal, sys, time',
    'if os.fork() == 0:',
    '    os.setsid()',
    '    devnull = os.open(os.devnull, os.O_RDWR)',
    '    for fd in (0, 1, 2): os.dup2(devnull, fd)',
    `    pathlib.Path(${JSON.stringify(daemonPid)}).write_text(str(os.getpid()))`,
    '    time.sleep(30)',
    '    os._exit(0)',
    'signal.signal(signal.SIGTERM, lambda *_: os._exit(143))',
    'while True: time.sleep(0.01)',
  ].join('\n'));
  const unrelated = spawn(python, ['-c', 'import time; time.sleep(30)'], {detached: true, stdio: 'ignore'});
  let daemon;
  t.after(async () => {
    for (const pid of [daemon, unrelated.pid]) if (pid && alive(pid)) process.kill(pid, 'SIGKILL');
    await fs.rm(root, {recursive: true, force: true});
  });
  const result = spawnSync(python, [shim, deadline, '0.5', 'adb-like-timeout', '--', python, starter], {encoding: 'utf8'});
  daemon = Number(await waitForFile(daemonPid));
  assert.equal(result.status, 124, result.stderr);
  assert.match(result.stderr, /NATIVE PHASE TIMEOUT adb-like-timeout after 0.5s/);
  assert.doesNotMatch(result.stderr, /Traceback|PermissionError|CLEANUP INCOMPLETE/);
  assert.equal(alive(daemon), true, 'a process that left the phase group is not owned by the phase');
  assert.equal(alive(unrelated.pid), true, 'an unrelated process group is never signalled');
});

test('a group member that refuses signals bounds cleanup and is reported', {skip: process.platform !== 'linux'}, async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-deadline-denied-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const shim = path.join(root, 'xnu.py');
  await fs.writeFile(shim, xnuShim);
  const started = Date.now();
  const result = spawnSync(python, [shim, deadline, '0.3', 'denied-timeout', '--', python, '-c', 'import time; time.sleep(7)'],
    {encoding: 'utf8', env: {...process.env, WW_DENY_SIGNALS: '1'}, timeout: 20000});
  assert.equal(result.status, 124, result.stderr);
  assert.match(result.stderr, /NATIVE PHASE CLEANUP INCOMPLETE denied-timeout: a process group member refused signals/);
  assert.doesNotMatch(result.stderr, /Traceback/);
  assert.ok(Date.now() - started < 15000, 'cleanup stays within its grace periods');
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
