import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import {expectedCases} from './report.mjs';
import {nativeEvidence} from './report.mjs';

export const diagnosticProfiles = ['ios-phone', 'android-phone'];

async function renderEvidence(root, profile, candidateSha) {
  const expected = expectedCases(profile, true);
  const directory = path.join(root, profile);
  try {
    const render = JSON.parse(await fs.readFile(path.join(directory, 'results.json'), 'utf8'));
    assert.equal(render.candidateSha, candidateSha);
    assert.equal(render.expected, expected.length);
    assert.ok(render.logicalWidth > 0 && render.logicalHeight > 0 && render.devicePixelRatio > 0);
    assert.equal(render.logicalWidth >= 600, profile.includes('tablet'));
    const entries = await fs.readdir(directory);
    const captures = await Promise.all(expected.map(async name => {
      if (!entries.includes(`${name}.png`)) return false;
      try {
        const bytes = await fs.readFile(path.join(directory, `${name}.png`));
        assert.ok(bytes.length > 24 && bytes.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')));
        const image = await sharp(bytes).metadata();
        return image.format === 'png' && image.width > 0 && image.height > 0;
      } catch {
        return false;
      }
    }));
    const count = captures.filter(Boolean).length;
    return {captures: count, passed: count === expected.length && render.captured === expected.length};
  } catch {
    return {captures: 0, passed: false};
  }
}

export async function diagnosticReport(root, candidateSha, selectedProfiles = diagnosticProfiles) {
  const evidence = await nativeEvidence(root, candidateSha, true);
  const validSelection = Array.isArray(selectedProfiles) && selectedProfiles.length > 0 &&
    new Set(selectedProfiles).size === selectedProfiles.length &&
    selectedProfiles.every(profile => diagnosticProfiles.includes(profile)) &&
    JSON.stringify(selectedProfiles) === JSON.stringify(diagnosticProfiles.filter(profile => selectedProfiles.includes(profile)));
  const profiles = (validSelection ? selectedProfiles : []).map(profile => {
    const result = evidence.results.find(entry => entry.profile === profile);
    return {profile, passed: Boolean(result?.passed), detectorsPassed: Boolean(result?.detectorsPassed),
      captures: 0, cases: result?.supported ? result.cases : 0, renderingPassed: false,
      nativeAudit: result?.supported ? 'complete' : 'incomplete', error: result?.error};
  });
  for (const profile of profiles) {
    const rendering = await renderEvidence(root, profile.profile, candidateSha);
    profile.captures = rendering.captures;
    profile.renderingPassed = rendering.passed;
    profile.passed = profile.passed && rendering.passed;
    if (!evidence.results.some(entry => entry.profile === profile.profile)) {
      profile.error = 'Missing native evidence result';
    }
  }
  const diagnosticPassed = validSelection && /^[a-f0-9]{40}$/.test(candidateSha ?? '') &&
    profiles.length === selectedProfiles.length && profiles.every(profile => profile.passed && profile.detectorsPassed);
  return {
    schemaVersion: 1,
    candidateSha,
    captureOnly: true,
    diagnosticPassed,
    qualification: {status: 'INCOMPLETE', qualified: false},
    selectedProfiles: profiles,
    message: 'Phone smoke evidence is diagnostic only. Full candidate qualification remains incomplete.',
  };
}

export async function writeDiagnosticReport(root, candidateSha) {
  const selection = process.env.QUALIFY_NATIVE_PROFILES === undefined ? diagnosticProfiles :
    process.env.QUALIFY_NATIVE_PROFILES.split(',');
  const report = await diagnosticReport(root, candidateSha, selection);
  await fs.mkdir(root, {recursive: true});
  await fs.writeFile(path.join(root, 'diagnostic.json'), `${JSON.stringify(report, null, 2)}\n`);
  return report;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const root = path.resolve('build/qualification/native');
  const report = await writeDiagnosticReport(root, process.env.QUALIFY_CANDIDATE_SHA);
  if (!report.diagnosticPassed) process.exitCode = 1;
}
