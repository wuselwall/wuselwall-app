import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import path from 'node:path';
import { tmpdir } from 'node:os';
import { checkShots, captureNames } from './check-shots.mjs';

test('source validation needs definitions and <Shot>, never existing PNGs', () => {
  const root = fs.mkdtempSync(path.join(tmpdir(), 'ww-guide-source-'));
  try {
    fs.mkdirSync(path.join(root, 'tools'));
    fs.writeFileSync(path.join(root, 'tools/screenshots.mjs'), "const shots = [\n  { name: 'home' },\n];\n");
    fs.writeFileSync(path.join(root, 'index.md'), '<Shot name="home" alt="Home" />');
    assert.deepEqual(checkShots(root, { definitionsOnly: true }).problems, []);
    assert.equal(checkShots(root).problems.length, 2);
    fs.writeFileSync(path.join(root, 'index.md'), '<Shot name="missing" alt="Missing" />');
    assert.match(checkShots(root, { definitionsOnly: true }).problems.join(), /no capture/);
    fs.writeFileSync(path.join(root, 'index.md'), '![](/screenshots/de/home.png)');
    assert.match(checkShots(root, { definitionsOnly: true }).problems.join(), /plain screenshot/);
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});
test('capture definitions cannot silently include unrelated role names or duplicates', () => {
  assert.deepEqual(captureNames("const button = { name: 'outside' };\nconst shots = [\n { name: 'home' },\n];\n"), ['home']);
  assert.throws(() => captureNames('no inventory'));
  assert.throws(() => captureNames("const shots = [\n { name: 'a' },\n { name: 'a' },\n];\n"));
});
