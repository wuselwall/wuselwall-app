import test from 'node:test';
import assert from 'node:assert/strict';
import {RuntimeSelectionError, selectRuntime} from './select-ios-runtime.mjs';

const phone = 'com.apple.CoreSimulator.SimDeviceType.iPhone-Future';
const tablet = 'com.apple.CoreSimulator.SimDeviceType.iPad-Future';
const duo = 'com.apple.CoreSimulator.SimDeviceType.iPhone-Duo-Future';
const runtime = (version, build, supportedDeviceTypes, overrides = {}) => ({
  identifier: `com.apple.CoreSimulator.SimRuntime.iOS-${version.replaceAll('.', '-')}`,
  version,
  buildversion: build,
  isAvailable: true,
  supportedDeviceTypes: supportedDeviceTypes.map(identifier => ({identifier})),
  ...overrides,
});
test('preserves a configured runtime when it supports the selected device', () => {
  const configured = runtime('27.0', 'FUTURE-27A', [phone, tablet]);
  const newest = runtime('27.2', 'FUTURE-27C', [phone]);
  const result = selectRuntime({runtimes: [configured, newest]}, configured.identifier, phone);
  assert.deepEqual(result, {
    identifier: configured.identifier,
    version: '27.0',
    buildversion: 'FUTURE-27A',
    deviceType: phone,
    requestedIdentifier: configured.identifier,
    selection: 'configured-compatible',
    selectionReason: 'configured-runtime-supports-device',
  });
});

test('fallback skips newer runtimes that do not support the selected device', () => {
  const phoneRuntime = runtime('27.0', 'FUTURE-27A', [phone, tablet]);
  const tabletOnly = runtime('27.1', 'FUTURE-27B', [tablet]);
  const duoOnly = runtime('27.2', 'FUTURE-27C', [duo]);
  const selected = selectRuntime({runtimes: [phoneRuntime, tabletOnly, duoOnly]}, tabletOnly.identifier, phone);
  assert.equal(selected.identifier, phoneRuntime.identifier);
  assert.equal(selected.selection, 'newest-compatible-diagnostic-fallback');
  assert.equal(selected.selectionReason, 'configured-runtime-does-not-support-device');
  assert.equal(selected.deviceType, phone);
});

test('unknown or malformed support metadata is never treated as compatible', () => {
  const unknown = runtime('27.3', 'FUTURE-27D', [], {supportedDeviceTypes: null});
  const malformed = runtime('27.2', 'FUTURE-27C', [], {supportedDeviceTypes: [{name: 'phone'}]});
  assert.throws(() => selectRuntime({runtimes: [unknown, malformed]}, '', phone),
    error => error instanceof RuntimeSelectionError && /No available iOS runtime has known support/.test(error.message));
});

test('unavailable or unknown-support configured runtimes fall back with a reason', () => {
  const configured = runtime('27.0', 'FUTURE-27A', [], {supportedDeviceTypes: null});
  const available = runtime('26.9', 'FUTURE-26Z', [phone]);
  const selected = selectRuntime({runtimes: [configured, available]}, configured.identifier, phone);
  assert.equal(selected.identifier, available.identifier);
  assert.equal(selected.selectionReason, 'configured-runtime-support-data-unknown');
});

test('runtime inventory must be a runtimes array', () => {
  assert.throws(() => selectRuntime({devices: []}, '', phone),
    error => error instanceof RuntimeSelectionError && /inventory is missing or malformed/.test(error.message));
});
