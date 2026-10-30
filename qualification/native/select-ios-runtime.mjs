import fs from 'node:fs';
import {fileURLToPath} from 'node:url';

const runtimePattern = /^com[.]apple[.]CoreSimulator[.]SimRuntime[.]iOS-[0-9-]+$/;
const versionPattern = /^[0-9]+(?:[.][0-9]+)*$/;

export class RuntimeSelectionError extends Error {}

function supportedDevices(runtime) {
  if (!Array.isArray(runtime.supportedDeviceTypes)) return null;
  const identifiers = [];
  for (const device of runtime.supportedDeviceTypes) {
    if (!device || typeof device !== 'object' || typeof device.identifier !== 'string') return null;
    identifiers.push(device.identifier);
  }
  return identifiers;
}

function compareVersions(left, right) {
  const a = left.split('.').map(Number);
  const b = right.split('.').map(Number);
  for (let index = 0; index < Math.max(a.length, b.length); index++) {
    const difference = (a[index] ?? 0) - (b[index] ?? 0);
    if (difference !== 0) return difference;
  }
  return 0;
}

export function selectRuntime(document, requestedIdentifier, deviceIdentifier) {
  if (!document || !Array.isArray(document.runtimes)) {
    throw new RuntimeSelectionError('Simulator runtime inventory is missing or malformed.');
  }
  if (typeof deviceIdentifier !== 'string' || !deviceIdentifier) {
    throw new RuntimeSelectionError('Simulator device type is missing.');
  }

  const compatible = [];
  let requestedRuntime;
  let requestedSupportKnown = false;
  let requestedSupportsDevice = false;
  for (const runtime of document.runtimes) {
    if (!runtime || typeof runtime !== 'object') continue;
    const identifier = runtime.identifier;
    if (identifier === requestedIdentifier) requestedRuntime = runtime;
    if (typeof identifier !== 'string' || !runtimePattern.test(identifier) || runtime.isAvailable !== true) continue;
    const devices = supportedDevices(runtime);
    if (identifier === requestedIdentifier) {
      requestedSupportKnown = devices !== null;
      requestedSupportsDevice = devices !== null && devices.includes(deviceIdentifier);
    }
    if (devices === null || !devices.includes(deviceIdentifier) ||
        typeof runtime.version !== 'string' || !versionPattern.test(runtime.version) ||
        typeof runtime.buildversion !== 'string' || !runtime.buildversion) continue;
    compatible.push(runtime);
  }

  if (requestedIdentifier && requestedSupportsDevice) {
    const selected = compatible.find(runtime => runtime.identifier === requestedIdentifier);
    if (selected) return makeResult(selected, requestedIdentifier, deviceIdentifier,
      'configured-compatible', 'configured-runtime-supports-device');
  }
  if (compatible.length === 0) {
    throw new RuntimeSelectionError(`No available iOS runtime has known support for simulator device ${deviceIdentifier}.`);
  }

  compatible.sort((left, right) => compareVersions(left.version, right.version) ||
    left.identifier.localeCompare(right.identifier));
  const selected = compatible.at(-1);
  let reason;
  if (!requestedIdentifier) reason = 'no-configured-runtime';
  else if (!requestedRuntime || requestedRuntime.isAvailable !== true) reason = 'configured-runtime-not-installed-or-unavailable';
  else if (!requestedSupportKnown) reason = 'configured-runtime-support-data-unknown';
  else if (!requestedSupportsDevice) reason = 'configured-runtime-does-not-support-device';
  else reason = 'configured-runtime-metadata-incomplete';
  return makeResult(selected, requestedIdentifier, deviceIdentifier,
    'newest-compatible-diagnostic-fallback', reason);
}

function makeResult(runtime, requestedIdentifier, deviceIdentifier, selection, selectionReason) {
  return {identifier: runtime.identifier, version: runtime.version, buildversion: runtime.buildversion,
    deviceType: deviceIdentifier, requestedIdentifier: requestedIdentifier || null, selection, selectionReason};
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [requestedIdentifier = '', deviceIdentifier = ''] = process.argv.slice(2);
  try {
    const document = JSON.parse(fs.readFileSync(0, 'utf8'));
    process.stdout.write(`${JSON.stringify(selectRuntime(document, requestedIdentifier, deviceIdentifier))}\n`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
