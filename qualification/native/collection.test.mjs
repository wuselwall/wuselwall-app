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
