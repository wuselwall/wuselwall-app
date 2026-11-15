import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

// native.sh needs macOS; its collection helpers are exercised here on their own.
const native = await fs.readFile(new URL('../native.sh', import.meta.url), 'utf8');

test('a collected report counts only when it is a finished audit', async t => {
  const helper = native.match(/^report_complete\(\) \{\n[\s\S]*?\nPY\n\}$/m)?.[0];
  assert.ok(helper, 'native.sh defines report_complete');
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-native-collect-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const check = async (name, body) => {
    const file = path.join(root, name, 'audit.json');
    await fs.mkdir(path.dirname(file), {recursive: true});
    if (body !== null) await fs.writeFile(file, body);
    return spawnSync('bash', ['-c', `${helper}\nreport_complete "$1"`, 'check', file], {encoding: 'utf8'});
  };
  assert.equal((await check('finished', JSON.stringify({schemaVersion: 1, done: true}))).status, 0);
  const printedError = await check('android-tablet-large', 'cat: files/qualification-native-audit.json: No such file or directory\n');
  assert.notEqual(printedError.status, 0);
  assert.match(printedError.stderr, /^NATIVE REPORT INVALID android-tablet-large: JSONDecodeError$/m);
  const unfinished = await check('android-min-phone', JSON.stringify({schemaVersion: 1, done: false}));
  assert.match(unfinished.stderr, /NATIVE REPORT INVALID android-min-phone: not a finished audit report/);
  assert.notEqual((await check('android-phone', null)).status, 0);
  assert.equal(printedError.stderr.includes(root), false, 'the marker names the profile, not the runner path');
});

test('every profile run keeps its own log and validates its collected report', () => {
  assert.match(native, /bash "\$0" "\$profile" 2>&1 \| tee "\$output\/\$profile\/run\.log"/);
  assert.match(native, /set -euo pipefail/, 'the profile status is the run, not tee');
  assert.match(native, /> "\$output\/android-\$kind\/audit\.json" \|\| failed=1\n\s+report_complete "\$output\/android-\$kind\/audit\.json" \|\| failed=1/);
  assert.match(native, /"\$output\/ios-\$kind\/audit\.json" \|\| failed=1\n\s+report_complete "\$output\/ios-\$kind\/audit\.json" \|\| failed=1/);
});

test('the instrumentation counts by its own verdict, not by the exit status of adb', async t => {
  const helper = native.match(/^instrumentation_passed\(\) \{\n[\s\S]*?\nPY\n\}$/m)?.[0];
  assert.ok(helper, 'native.sh defines instrumentation_passed');
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ww-native-instrument-'));
  t.after(() => fs.rm(root, {recursive: true, force: true}));
  const check = async (profile, body) => {
    const file = path.join(root, `${profile}.log`);
    if (body !== null) await fs.writeFile(file, body);
    return spawnSync('bash', ['-c', `${helper}\ninstrumentation_passed "$1" "$2"`, 'check', file, profile], {encoding: 'utf8'});
  };
  const passed = await check('android-phone', 'INSTRUMENTATION_STATUS_CODE: 0\nINSTRUMENTATION_RESULT: stream=\n\nTime: 75.58\n\nOK (1 test)\n\n\nINSTRUMENTATION_CODE: -1\n');
  assert.equal(passed.status, 0, passed.stderr);
  // Both are outputs of `adb shell am instrument` that ended with exit status 0.
  const foreignWindow = await check('android-tablet', [
    'INSTRUMENTATION_STATUS: stack=java.lang.AssertionError: Active window of wall-de-light belongs to com.android.systemui, not to the app; windows: Viewing full screen (com.android.systemui, type 3, active, focused), WuselWall (ch.goomba.wuselwall, type 1)',
    '\tat org.junit.Assert.fail(Assert.java:89)', '', 'FAILURES!!!', 'Tests run: 1,  Failures: 1', '', 'INSTRUMENTATION_CODE: -1', ''].join('\n'));
  assert.notEqual(foreignWindow.status, 0);
  assert.match(foreignWindow.stderr,
    /^NATIVE INSTRUMENTATION FAILED android-tablet: java\.lang\.AssertionError: Active window of wall-de-light belongs to com\.android\.systemui, not to the app; windows: Viewing full screen \(com\.android\.systemui, type 3, active, focused\), WuselWall \(ch\.goomba\.wuselwall, type 1\)$/m);
  const crashed = await check('android-min-phone', 'INSTRUMENTATION_STATUS_CODE: 1\nINSTRUMENTATION_RESULT: shortMsg=Process crashed.\nINSTRUMENTATION_CODE: 0\n');
  assert.match(crashed.stderr, /^NATIVE INSTRUMENTATION FAILED android-min-phone: Process crashed\.$/m);
  const silent = await check('android-phone-large', 'NATIVE PHASE TIMEOUT android-instrumentation-phone-large after 1800s\n');
  assert.match(silent.stderr, /^NATIVE INSTRUMENTATION FAILED android-phone-large: no test verdict in its output$/m);
  assert.notEqual((await check('android-tablet-large', null)).status, 0, 'an absent log is not a pass');
  const contradictory = await check('android-phone', 'OK (1 test)\nFAILURES!!!\n');
  assert.notEqual(contradictory.status, 0);
  for (const result of [foreignWindow, crashed, silent]) assert.equal(result.stderr.includes(root), false);
});

test('a report that is not on the device fails its own phase and is never pulled', () => {
  const helper = native.match(/^android_report_present\(\) \{\n[\s\S]*?\n\}$/m)?.[0];
  assert.ok(helper, 'native.sh defines android_report_present');
  const check = listing => spawnSync('bash', ['-c', `${helper}\nandroid_report_present "$1" "$2"`, 'check', 'android-tablet', listing], {encoding: 'utf8'});
  assert.equal(check('files/qualification-native-audit.json').status, 0);
  // What `adb shell run-as … ls` prints for a missing file, an unknown package and a lost device.
  for (const listing of ['ls: files/qualification-native-audit.json: No such file or directory',
    'run-as: unknown package: ch.goomba.wuselwall', '']) {
    const missing = check(listing);
    assert.notEqual(missing.status, 0);
    assert.equal(missing.stderr, 'NATIVE REPORT MISSING android-tablet: no audit report on the device\n');
  }
  const collection = native.slice(native.indexOf('android-instrumentation-$kind'), native.indexOf('kill "$emulator_pid"'));
  assert.match(collection, /if ! instrumentation_passed "\$output\/android-\$kind\/audits\.log" "android-\$kind"; then\n\s+failed=1\n/);
  assert.match(collection, /if android_report_present "android-\$kind" "\$report_listing"; then\n\s+run_deadline 60 "android-report-pull-\$kind"[\s\S]*?report_complete[^\n]*\n\s+else\n\s+failed=1\n\s+fi\n\s+\[\[ "\$failed" == 0 \]\] \|\| return 1/);
  assert.equal(collection.match(/exec-out run-as/g).length, 1, 'the report is pulled in one place, after the probe');
});

test('a device explains full screen before the audit, not during it', () => {
  const setup = native.slice(native.indexOf('run_android() {'), native.indexOf('run_app emulator-5580'));
  assert.match(setup, /settings put secure immersive_mode_confirmations confirmed\n/);
  assert.match(setup, /immersive=\$\(.*settings get secure immersive_mode_confirmations \| tr -d '\\r'\)\n\s+\[\[ "\$immersive" == confirmed \]\] \|\| \{[^}]*return 1; \}/);
});
