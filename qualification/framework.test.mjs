import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import { cases, checkInventory, inventory } from './matrix.mjs';
import { seal, sha256, verify } from './baseline.mjs';

test('matrix is unique, locale-complete, includes breakpoint boundaries and true night', () => {
  assert.ok(checkInventory().states >= 25);
  const full = cases('full');
  assert.equal(new Set(full.map(c => c.caseId)).size, full.length);
  for (const s of inventory.states) {
    for (const lang of inventory.locales) assert.ok(full.some(c => c.id === s.id && c.locale === lang));
  }
  for (const width of [599, 600, 601]) assert.ok(full.some(c => c.id === 'calendar' && c.width === width));
  assert.ok(full.some(c => c.id === 'wall' && c.shade === 'night'));
  assert.ok(full.some(c => c.id === 'wall' && c.width === 1920 && c.height === 1080));
  assert.throws(() => cases('typo'));
});

test('new routes and duplicate or empty states cannot silently disappear', () => {
  assert.throws(() => checkInventory({ ...inventory, pendingRoutes: {} }), /Unaccounted route/);
  assert.throws(() => checkInventory({ ...inventory, states: [] }), /empty inventory/);
  assert.throws(() => checkInventory({ ...inventory, states: [...inventory.states, inventory.states[0]] }), /Duplicate/);
});

test('reviewed baseline checksum rejects changed, missing, added and cross-environment files', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ww-baseline-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  fs.mkdirSync(path.join(dir, 'chromium'));
  const image = path.join(dir, 'chromium/screen.png');
  fs.writeFileSync(image, 'test image bytes');
  fs.writeFileSync(path.join(dir, 'chromium/screen-aria.yml'), '- button "Save"');
  const env = { platform: 'test' };
  seal(dir, 'a'.repeat(40), env);
  const manifest = fs.readFileSync(path.join(dir, 'manifest.json'));
  const digest = sha256(manifest);
  assert.equal(verify(dir, manifest, digest, env).sourceSha, 'a'.repeat(40));
  assert.throws(() => verify(dir, manifest, 'b'.repeat(64), env), /checksum/);
  assert.throws(() => verify(dir, manifest, digest, { platform: 'other' }), /environment/);
  fs.writeFileSync(image, 'changed bytes');
  assert.throws(() => verify(dir, manifest, digest, env), /checksum/);
  fs.unlinkSync(image);
  assert.throws(() => verify(dir, manifest, digest, env), /files differ/);
  fs.writeFileSync(image, 'test image bytes');
  fs.writeFileSync(path.join(dir, 'chromium/extra.png'), 'extra');
  assert.throws(() => verify(dir, manifest, digest, env), /files differ/);
});

test('empty or unpaired captures cannot become baseline bundles', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ww-baseline-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  assert.throws(() => seal(dir, 'a'.repeat(40), {}), /nonempty/);
  fs.mkdirSync(path.join(dir, 'chromium'));
  fs.writeFileSync(path.join(dir, 'chromium/screen.png'), 'image');
  assert.throws(() => seal(dir, 'a'.repeat(40), {}), /pairs/);
});
