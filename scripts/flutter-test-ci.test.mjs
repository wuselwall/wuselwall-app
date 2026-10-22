import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { CRASH, assessCrash } from './flutter-test-ci.mjs';

const script = new URL('./flutter-test-ci.mjs', import.meta.url).pathname;
const A = '/work/app/test/a_test.dart';
const B = '/work/app/test/b_test.dart';

// The JSON reporter's events for files with the given test results ('success' | 'failure' |
// 'error' | 'unfinished'), in the shape flutter test --file-reporter=json writes them.
function report(files, { crashed = [], errors = [] } = {}) {
  const events = [{ type: 'start', protocolVersion: '0.1.1' }];
  let id = 0;
  const loaders = new Map();
  for (const path of Object.keys(files)) {
    const suite = id++;
    events.push({ type: 'suite', suite: { id: suite, platform: 'vm', path } });
    const loader = id++;
    loaders.set(path, loader);
    events.push({ type: 'testStart', test: { id: loader, name: `loading ${path}`, suiteID: suite, groupIDs: [] } });
    events.push({ type: 'testDone', testID: loader, result: 'success', skipped: false, hidden: true });
  }
  events.splice(1 + 3 * Object.keys(files).length, 0, { type: 'allSuites', count: Object.keys(files).length });
  for (const [path, results] of Object.entries(files)) {
    const suite = events.find((e) => e.type === 'suite' && e.suite.path === path).suite.id;
    const group = id++;
    events.push({ type: 'group', group: { id: group, suiteID: suite, parentID: null, name: '', testCount: results.length } });
    for (const result of results) {
      const t = id++;
      events.push({ type: 'testStart', test: { id: t, name: `test ${t}`, suiteID: suite, groupIDs: [group] } });
      if (result === 'failure') events.push({ type: 'error', testID: t, error: 'Expected: 1', isFailure: true });
      if (result !== 'unfinished') events.push({ type: 'testDone', testID: t, result, skipped: false, hidden: false });
    }
  }
  for (const path of crashed) events.push({ type: 'error', testID: loaders.get(path), error: CRASH, isFailure: false });
  for (const error of errors) events.push({ type: 'error', testID: loaders.get(A), error, isFailure: false });
  events.push({ type: 'done', success: crashed.length === 0 && errors.length === 0 });
  return events.map((e) => JSON.stringify(e));
}

// What flutter_tools prints for the crash (copied from a failed self-hosted run).
const crashText = (path) => `unhandled error during finalization of test:\n${path}\n${CRASH}\n` +
  '#0      FlutterTesterTestDevice.finished (package:flutter_tools/src/test/flutter_tester_device.dart:256:5)\n';

test('a crash after a file whose tests all passed is retried, for that file only', () => {
  const json = report({ [A]: ['success', 'success'], [B]: ['success'] });
  assert.deepEqual(assessCrash(`00:10 +3: All tests passed!\n${crashText(A)}`, json).files, [A]);
});

test('the crash may also reach the JSON report, on the crashed file loading step', () => {
  const json = report({ [A]: ['success'], [B]: ['success'] }, { crashed: [A] });
  assert.deepEqual(assessCrash(crashText(A), json).files, [A]);
});

test('a failing test anywhere keeps the run failed', () => {
  assert.equal(assessCrash(crashText(A), report({ [A]: ['success'], [B]: ['failure'] })).files, undefined);
  assert.equal(assessCrash(crashText(A), report({ [A]: ['success'], [B]: ['error'] })).files, undefined);
});

test('a crash before the file finished keeps the run failed', () => {
  assert.equal(assessCrash(crashText(A), report({ [A]: ['success', 'unfinished'] })).files, undefined);
  // A file that reported fewer tests than it has: the crash cut it short.
  const json = report({ [A]: ['success'] }).map((line) => line.replace('"testCount":1', '"testCount":2'));
  assert.equal(assessCrash(crashText(A), json).files, undefined);
});

test('any other error or an unseen file keeps the run failed', () => {
  const other = report({ [A]: ['success'] }, { errors: ['Failed to load "a_test.dart": compile error'] });
  assert.equal(assessCrash(crashText(A), other).files, undefined);
  const otherUnhandled = `unhandled error during test:\n${A}\nSocketException: boom\n`;
  assert.equal(assessCrash(crashText(A) + otherUnhandled, report({ [A]: ['success'] })).files, undefined);
  assert.equal(assessCrash(crashText(B), report({ [A]: ['success'] })).files, undefined);
  assert.equal(assessCrash(crashText(A), report({ [A]: ['success'] }).slice(0, -3)).files, undefined);
  assert.equal(assessCrash('Some tests failed.', report({ [A]: ['failure'] })).files, undefined);
  assert.equal(assessCrash(crashText(A), ['not json']).files, undefined);
});

// End to end with a stand-in `flutter` that plays one scripted run per call.
function run(runs) {
  const dir = mkdtempSync(join(tmpdir(), 'flutter-test-ci-'));
  try {
    const fake = join(dir, 'flutter');
    writeFileSync(join(dir, 'runs.json'), JSON.stringify(runs));
    writeFileSync(fake, `#!/usr/bin/env node
const fs = require('fs');
const dir = ${JSON.stringify(dir)};
const calls = fs.existsSync(dir + '/calls') ? JSON.parse(fs.readFileSync(dir + '/calls')) : [];
calls.push(process.argv.slice(2));
fs.writeFileSync(dir + '/calls', JSON.stringify(calls));
const run = JSON.parse(fs.readFileSync(dir + '/runs.json'))[calls.length - 1];
const report = process.argv.find((a) => a.startsWith('--file-reporter=json:')).slice(21);
fs.writeFileSync(report, run.json.join('\\n'));
process.stdout.write(run.out);
process.exit(run.status);
`);
    chmodSync(fake, 0o755);
    const result = spawnSync('node', [script], { cwd: dir, encoding: 'utf8', env: { ...process.env, PATH: `${dir}:${process.env.PATH}` } });
    return { ...result, calls: JSON.parse(readFileSync(join(dir, 'calls'), 'utf8')) };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const passed = { status: 0, out: 'All tests passed!\n', json: report({ [A]: ['success'] }) };
const crashed = { status: 1, out: crashText(A), json: report({ [A]: ['success'], [B]: ['success'] }) };

test('a clean run runs once and passes', () => {
  const result = run([passed]);
  assert.equal(result.status, 0);
  assert.equal(result.calls.length, 1);
  assert.match(result.stdout, /Runner facts/);
});

test('a crash-only failure reruns the crashed file once, with a warning, and takes its result', () => {
  const result = run([crashed, passed]);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.calls.map((args) => args.filter((a) => !a.startsWith('--file-reporter'))), [['test'], ['test', A]]);
  assert.match(result.stdout, /::warning title=flutter_tester crashed after its tests passed::\/work\/app\/test\/a_test\.dart/);
});

test('a second crash fails the job, without a third run', () => {
  const result = run([crashed, crashed]);
  assert.equal(result.status, 1);
  assert.equal(result.calls.length, 2);
});

test('a real failure fails the job with its own status and no rerun', () => {
  const result = run([{ status: 1, out: 'Some tests failed.\n', json: report({ [A]: ['failure'] }) }]);
  assert.equal(result.status, 1);
  assert.equal(result.calls.length, 1);
  assert.doesNotMatch(result.stdout, /::warning/);
});

test('a crash it will not rerun says why', () => {
  const result = run([{ status: 1, out: crashText(A), json: report({ [A]: ['success', 'unfinished'] }) }]);
  assert.equal(result.status, 1);
  assert.equal(result.calls.length, 1);
  assert.match(result.stdout, /the run stands \(a test started and never finished\)/);
  assert.match(result.stdout, /unfinished: \/work\/app\/test\/a_test\.dart: test \d+/);
});
