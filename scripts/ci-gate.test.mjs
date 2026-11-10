import assert from 'node:assert/strict';
import { test } from 'node:test';
import { checkGate } from './ci-gate.mjs';
const fixture = () => ({ changes: { result: 'success', outputs: { app: 'false', browser: 'false', backend: 'false', edge: 'false' } },
  'app-checks': { result: 'skipped' }, backend: { result: 'skipped' }, 'edge-functions': { result: 'skipped' } });
test('irrelevant work terminates both stable contexts successfully', () => {
  checkGate(fixture(), 'app'); checkGate(fixture(), 'backend');
});
test('selected work must pass, including browser-only changes', () => {
  for (const [flag, gate, job] of [['app', 'app', 'app-checks'], ['browser', 'app', 'app-checks'], ['backend', 'backend', 'backend'], ['edge', 'backend', 'edge-functions']]) {
    const needs = fixture(); needs.changes.outputs[flag] = 'true';
    for (const result of ['skipped', 'failure', 'cancelled', undefined]) {
      needs[job].result = result; assert.throws(() => checkGate(needs, gate), /selected: true/);
    }
    needs[job].result = 'success'; checkGate(needs, gate);
  }
});
test('missing detector output and failed/cancelled detection cannot turn green', () => {
  for (const result of ['failure', 'cancelled', 'skipped', undefined]) {
    const needs = fixture(); needs.changes.result = result;
    assert.throws(() => checkGate(needs, 'app')); assert.throws(() => checkGate(needs, 'backend'));
  }
  const needs = fixture(); delete needs.changes.outputs.app;
  assert.throws(() => checkGate(needs, 'app'));
  needs.changes.outputs.app = 'true'; delete needs.changes.outputs.browser;
  assert.throws(() => checkGate(needs, 'app'));
});
test('candidate quality-only reuse still rejects failed jobs', () => {
  const needs = fixture(); needs.changes.outputs.app = 'true';
  checkGate(needs, 'app', true);
  needs['app-checks'].result = 'failure'; assert.throws(() => checkGate(needs, 'app', true));
});
