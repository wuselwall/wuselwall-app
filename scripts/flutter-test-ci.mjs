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
// once more and returns that run's status. A failing, erroring, skipped-by-crash or unfinished
// test, any other error, or a crash in the second run keeps the job red. Each retried crash
// leaves a warning annotation on the run.
import { spawn, spawnSync } from 'node:child_process';
import { arch, availableParallelism, cpus, freemem, release, totalmem } from 'node:os';
import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export const CRASH = 'TestDeviceException(Shell subprocess crashed with segmentation fault.)';
const UNHANDLED = /unhandled error during (finalization of )?test:$/;

/**
 * Decides whether a failed run failed only because flutter_tester crashed after files whose
 * tests had all passed. Takes the console output and the JSON reporter's lines; returns the
 * crashed test files to run again, or null to keep the run's result.
 */
export function retryableCrashes(output, jsonLines) {
  const crashed = new Set();
  const lines = output.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    if (!UNHANDLED.test(lines[i].trim())) continue;
    if (lines[i + 2]?.trim() !== CRASH) return null; // some other flutter_tools error
    crashed.add(lines[i + 1].trim());
  }
  if (crashed.size === 0) return null;

  const suites = new Map(); // suite id -> test file
  const expected = new Map(); // suite id -> number of tests in the file
  const tests = new Map(); // test id -> { suiteID, name, hidden, result }
  const errors = [];
  let suiteCount;
  for (const line of jsonLines) {
    if (!line.trim()) continue;
    let event;
    try { event = JSON.parse(line); } catch { return null; }
    if (event.type === 'allSuites') suiteCount = event.count;
    if (event.type === 'suite') suites.set(event.suite.id, event.suite.path);
    if (event.type === 'group' && event.group.parentID == null) {
      expected.set(event.group.suiteID, (expected.get(event.group.suiteID) ?? 0) + event.group.testCount);
    }
    if (event.type === 'testStart') tests.set(event.test.id, { suiteID: event.test.suiteID, name: event.test.name });
    if (event.type === 'testDone') {
      const test = tests.get(event.testID);
      if (!test) return null;
      Object.assign(test, { hidden: event.hidden, result: event.result });
    }
    if (event.type === 'error') errors.push(event);
  }

  const crashedSuites = new Set([...suites].filter(([, path]) => crashed.has(path)).map(([id]) => id));
  if (crashedSuites.size !== crashed.size) return null; // a crashed file the reporter never saw
  const isCrashLoader = (test) => test?.name.startsWith('loading ') && crashedSuites.has(test.suiteID);

  // The only error allowed is the crash itself, reported on a crashed file's loading step.
  if (errors.some((e) => !(isCrashLoader(tests.get(e.testID)) && String(e.error).trim() === CRASH))) return null;
  for (const test of tests.values()) {
    if (test.result === undefined) return null; // started, never finished
    if (test.result !== 'success' && !isCrashLoader(test)) return null;
  }
  // Every file loaded and every one of its tests finished; a crash mid-file leaves some unrun.
  if (suiteCount === undefined || suites.size !== suiteCount) return null;
  for (const id of suites.keys()) {
    const finished = [...tests.values()].filter((t) => t.suiteID === id && !t.hidden).length;
    if (!expected.has(id) || finished !== expected.get(id)) return null;
  }
  return [...crashed].sort();
}

function diagnostics() {
  const read = (path) => { try { return readFileSync(path, 'utf8').trim(); } catch { return 'unreadable'; } };
  const sh = (command) => spawnSync('sh', ['-c', command], { encoding: 'utf8' }).stdout?.trim() || 'unknown';
  const flags = (read('/proc/cpuinfo').match(/^flags\s*:(.*)$/m)?.[1] ?? '').trim().split(/\s+/);
  const gib = (bytes) => `${(bytes / 2 ** 30).toFixed(1)} GiB`;
  console.log('::group::Runner facts (for a flutter_tester crash)');
  console.log(`kernel ${release()} ${arch()}, ${sh('getconf GNU_LIBC_VERSION')}`);
  console.log(`CPUs ${availableParallelism()} usable of ${cpus().length}: ${cpus()[0]?.model ?? 'unknown'}`);
  console.log(`CPU features: ${['sse4_2', 'avx', 'avx2', 'fma', 'avx512f', 'hypervisor'].map((f) => `${f}=${flags.includes(f) ? 'yes' : 'no'}`).join(' ')}`);
  console.log(`memory ${gib(freemem())} free of ${gib(totalmem())}; cgroup cpu.max ${read('/sys/fs/cgroup/cpu.max')}, memory.max ${read('/sys/fs/cgroup/memory.max')}`);
  console.log(`core dumps: size limit ${sh('ulimit -c')}, core_pattern ${read('/proc/sys/kernel/core_pattern')}`);
  console.log('::endgroup::');
}

function flutterTest(args, report) {
  return new Promise((resolve, reject) => {
    const child = spawn('flutter', ['test', `--file-reporter=json:${report}`, ...args], { stdio: ['inherit', 'pipe', 'pipe'] });
    let output = '';
    child.stdout.on('data', (chunk) => { process.stdout.write(chunk); output += chunk; });
    child.stderr.on('data', (chunk) => { process.stderr.write(chunk); output += chunk; });
    child.on('error', reject);
    child.on('close', (code) => resolve({ status: code ?? 1, output }));
  });
}

async function main() {
  diagnostics();
  mkdirSync('build', { recursive: true });
  const report = 'build/test-results.json';
  const first = await flutterTest([], report);
  if (first.status === 0) return 0;
  const files = retryableCrashes(first.output, existsSync(report) ? readFileSync(report, 'utf8').split('\n') : []);
  if (!files) return first.status;
  for (const file of files) {
    console.log(`::warning title=flutter_tester crashed after its tests passed::${file} (SIGSEGV after every test passed). Running this file once more.`);
  }
  return (await flutterTest(files, 'build/test-results-retry.json')).status;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = await main();
}
