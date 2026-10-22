#!/usr/bin/env node
// `flutter test` for CI, run from app/. On the self-hosted runners flutter_tester sometimes
// dies of SIGSEGV after a test file has finished: every test of the file passed, then
// flutter_tools prints "unhandled error during finalization of test: <file>
// TestDeviceException(Shell subprocess crashed with segmentation fault.)" and exits 1.
// It happens with and without --coverage, on files that differ from run to run, and was
// never reproduced off those runners; the native cause is unknown.
//
// This wrapper prints the runner facts a native diagnosis needs, runs the suite once and, only
// when the sole problem is that crash after files whose tests all passed, runs those files
// once more and returns that run's status. Only a flutter exit status of 1 qualifies: a
// flutter killed by a signal, any other status, a failing, erroring or unfinished test, any
// other error, or a crash in the second run keeps the job red. Each rerun leaves a warning
// annotation; when it declines to rerun, it says why. Where gdb is installed it also lets the
// tester dump core and prints the crashing thread's backtrace.
import { spawn, spawnSync } from 'node:child_process';
import { arch, availableParallelism, constants, cpus, freemem, release, totalmem } from 'node:os';
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

export const CRASH = 'TestDeviceException(Shell subprocess crashed with segmentation fault.)';
const UNHANDLED = /unhandled error during (finalization of )?test:$/;

/**
 * Decides whether a failed run failed only because flutter_tester crashed after files whose
 * tests had all passed. Takes the console output and the JSON reporter's lines. Returns
 * { files } to run again, or { reason, events } when the run's result must stand.
 */
export function assessCrash(output, jsonLines) {
  const crashed = new Set();
  const lines = output.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    if (!UNHANDLED.test(lines[i].trim())) continue;
    if (lines[i + 2]?.trim() !== CRASH) return { reason: `another flutter_tools error: ${lines[i + 2]?.trim()}` };
    crashed.add(lines[i + 1].trim());
  }
  if (crashed.size === 0) return { reason: 'no tester crash in the output' };

  const suites = new Map(); // suite id -> test file
  const expected = new Map(); // suite id -> number of tests in the file
  const tests = new Map(); // test id -> { suiteID, name, hidden, result }
  const errors = [];
  let suiteCount;
  for (const line of jsonLines) {
    if (!line.trim()) continue;
    let event;
    try { event = JSON.parse(line); } catch { return { reason: 'the JSON report is not readable' }; }
    if (event.type === 'allSuites') suiteCount = event.count;
    if (event.type === 'suite') suites.set(event.suite.id, event.suite.path);
    if (event.type === 'group' && event.group.parentID == null) {
      expected.set(event.group.suiteID, (expected.get(event.group.suiteID) ?? 0) + event.group.testCount);
    }
    if (event.type === 'testStart') tests.set(event.test.id, { id: event.test.id, suiteID: event.test.suiteID, name: event.test.name });
    if (event.type === 'testDone') {
      const test = tests.get(event.testID);
      if (!test) return { reason: `test ${event.testID} finished without starting` };
      Object.assign(test, { hidden: event.hidden, result: event.result });
    }
    if (event.type === 'error') errors.push(event);
  }

  const crashedSuites = new Set([...suites].filter(([, path]) => crashed.has(path)).map(([id]) => id));
  if (crashedSuites.size !== crashed.size) return { reason: 'a crashed file is missing from the JSON report' };
  const isCrashLoader = (test) => test?.name.startsWith('loading ') && crashedSuites.has(test.suiteID);
  const describe = (test) => `${suites.get(test?.suiteID)}: ${test?.name}`;
  const events = [
    ...errors.map((e) => `error on ${describe(tests.get(e.testID))}: ${String(e.error).slice(0, 200)}`),
    ...[...tests.values()].filter((t) => t.result !== 'success').map((t) => `${t.result ?? 'unfinished'}: ${describe(t)}`),
  ];

  // The only error allowed is the crash itself, reported on a crashed file's loading step.
  if (errors.some((e) => !(isCrashLoader(tests.get(e.testID)) && String(e.error).trim() === CRASH))) {
    return { reason: 'the report has errors other than the crash', events };
  }
  for (const test of tests.values()) {
    if (test.result === undefined) return { reason: 'a test started and never finished', events };
    if (test.result !== 'success' && !isCrashLoader(test)) return { reason: 'a test did not pass', events };
  }
  // Every file loaded and every one of its tests finished; a crash mid-file leaves some unrun.
  if (suiteCount === undefined || suites.size !== suiteCount) {
    return { reason: `${suites.size} of ${suiteCount ?? '?'} files reported`, events };
  }
  for (const id of suites.keys()) {
    const finished = [...tests.values()].filter((t) => t.suiteID === id && !t.hidden).length;
    if (!expected.has(id) || finished !== expected.get(id)) {
      return { reason: `${suites.get(id)}: ${finished} of ${expected.get(id) ?? '?'} tests finished`, events };
    }
  }
  return { files: [...crashed].sort() };
}

const sh = (command) => spawnSync('sh', ['-c', command], { encoding: 'utf8' }).stdout?.trim() || '';
const gdb = sh('command -v gdb');

function diagnostics() {
  const read = (path) => { try { return readFileSync(path, 'utf8').trim(); } catch { return 'unreadable'; } };
  const flags = (read('/proc/cpuinfo').match(/^flags\s*:(.*)$/m)?.[1] ?? '').trim().split(/\s+/);
  const gib = (bytes) => `${(bytes / 2 ** 30).toFixed(1)} GiB`;
  console.log('::group::Runner facts (for a flutter_tester crash)');
  console.log(`kernel ${release()} ${arch()}, ${sh('getconf GNU_LIBC_VERSION') || 'unknown libc'}`);
  console.log(`CPUs ${availableParallelism()} usable of ${cpus().length}: ${cpus()[0]?.model ?? 'unknown'}`);
  console.log(`CPU features: ${['sse4_2', 'avx', 'avx2', 'fma', 'avx512f', 'hypervisor'].map((f) => `${f}=${flags.includes(f) ? 'yes' : 'no'}`).join(' ')}`);
  console.log(`memory ${gib(freemem())} free of ${gib(totalmem())}; cgroup cpu.max ${read('/sys/fs/cgroup/cpu.max')}, memory.max ${read('/sys/fs/cgroup/memory.max')}`);
  console.log(`core dumps: limit ${sh('ulimit -c')} (hard ${sh('ulimit -Hc')}), core_pattern ${read('/proc/sys/kernel/core_pattern')}; gdb ${gdb || 'not installed'}`);
  console.log('::endgroup::');
}

function flutterTest(args, report) {
  return new Promise((resolve, reject) => {
    // With gdb at hand, let a crashing tester leave a core to read a backtrace from.
    const command = `${gdb ? 'ulimit -c unlimited 2>/dev/null; ' : ''}exec flutter test "$@"`;
    const child = spawn('sh', ['-c', command, 'sh', `--file-reporter=json:${report}`, ...args], { stdio: ['inherit', 'pipe', 'pipe'] });
    let output = '';
    child.stdout.on('data', (chunk) => { process.stdout.write(chunk); output += chunk; });
    child.stderr.on('data', (chunk) => { process.stderr.write(chunk); output += chunk; });
    child.on('error', reject);
    // A child killed by a signal has no code: report it as the shell would (128 + number).
    child.on('close', (code, signal) => resolve({
      signal, status: signal ? 128 + (constants.signals[signal] ?? 0) : code ?? 1, output,
    }));
  });
}

// gdb settings that keep values out of its output: frames show "(...)" instead of argument
// values, and no entry values. Passed with -iex, so they apply before the core loads and gdb
// prints its first frame.
export const GDB_SETTINGS = ['set print frame-arguments none', 'set print entry-values no', 'set pagination off', 'set width 0'];

// gdb's lines that are printed: frames, thread numbers, the signal and the .text section
// lines (load addresses to symbolise with). Everything else is dropped, among it the
// "Core was generated by `<command line>`" banner and any source lines.
const FRAME = /^#\d+\s+(0x[0-9a-f]+ in )?\S/;
const TEXT_SECTION = /^\s*0x[0-9a-f]+ - 0x[0-9a-f]+ is \.text\b/;

/** Reduces gdb output to code addresses and symbols; a frame that still shows a value is redacted. */
export function sanitizeBacktrace(output) {
  const kept = [];
  for (const line of output.split(/\r?\n/)) {
    const thread = line.match(/^Thread \d+/);
    const signal = line.match(/^Program terminated with signal \w+/);
    if (thread) kept.push(`${thread[0]}:`);
    else if (signal) kept.push(signal[0]);
    else if (TEXT_SECTION.test(line)) kept.push(line);
    else if (FRAME.test(line)) {
      // Arguments are switched off; "=" or a quote means gdb printed a value anyway.
      kept.push(/[="'`]/.test(line) ? `${line.match(/^#\d+\s+(0x[0-9a-f]+)?/)[0].trim()} [frame withheld: it shows values]` : line);
    }
  }
  return kept.join('\n');
}

// Prints the backtrace of the first core a crashed tester left (see sanitizeBacktrace), then
// removes all of them.
function backtraces() {
  const cores = readdirSync('.').filter((name) => /^core(\.\d+)?$/.test(name));
  if (cores.length === 0) return;
  const tester = join(process.env.FLUTTER_ROOT ?? '', 'bin/cache/artifacts/engine/linux-x64/flutter_tester');
  console.log(`::group::flutter_tester backtrace (${cores.length} core file(s))`);
  const args = ['-batch', '-nx', '-q', ...GDB_SETTINGS.flatMap((setting) => ['-iex', setting]),
    '-ex', 'info files', '-ex', 'bt 40', '-ex', 'thread apply all bt 8', tester, cores[0]];
  const result = spawnSync(gdb, args, { encoding: 'utf8' });
  console.log(sanitizeBacktrace(`${result.stdout ?? ''}\n${result.stderr ?? ''}`));
  console.log('::endgroup::');
  for (const core of cores) rmSync(core, { force: true });
}

async function main() {
  diagnostics();
  mkdirSync('build', { recursive: true });
  const report = 'build/test-results.json';
  const first = await flutterTest([], report);
  if (gdb) backtraces();
  if (first.status === 0) return 0;
  // The crash makes flutter exit with 1. A signal or any other status is not that crash.
  if (first.signal || first.status !== 1) {
    const how = first.signal ? `was killed by ${first.signal}` : `exited with ${first.status}`;
    console.log(`flutter-test-ci: the run stands (flutter ${how}).`);
    return first.status;
  }
  const verdict = assessCrash(first.output, existsSync(report) ? readFileSync(report, 'utf8').split('\n') : []);
  if (!verdict.files) {
    console.log(`flutter-test-ci: the run stands (${verdict.reason}).`);
    for (const line of (verdict.events ?? []).slice(0, 30)) console.log(`  ${line}`);
    return first.status;
  }
  for (const file of verdict.files) {
    console.log(`::warning title=flutter_tester crashed after its tests passed::${file} (SIGSEGV after every test passed). Running this file once more.`);
  }
  const retry = await flutterTest(verdict.files, 'build/test-results-retry.json');
  if (gdb) backtraces();
  return retry.status;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = await main();
}
