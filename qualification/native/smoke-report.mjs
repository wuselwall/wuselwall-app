import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {nativeEvidence} from './report.mjs';

export const diagnosticProfiles = ['ios-phone', 'android-phone'];

export async function diagnosticReport(root, candidateSha, selectedProfiles = diagnosticProfiles) {
  const evidence = await nativeEvidence(root, candidateSha, true);
  const validSelection = Array.isArray(selectedProfiles) && selectedProfiles.length > 0 &&
    new Set(selectedProfiles).size === selectedProfiles.length &&
    selectedProfiles.every(profile => diagnosticProfiles.includes(profile)) &&
    JSON.stringify(selectedProfiles) === JSON.stringify(diagnosticProfiles.filter(profile => selectedProfiles.includes(profile)));
  const profiles = (validSelection ? selectedProfiles : []).map(profile => {
    const result = evidence.results.find(entry => entry.profile === profile);
    return result ? {profile, passed: result.passed, detectorsPassed: result.detectorsPassed,
      captures: result.captures, cases: result.cases, error: result.error} :
      {profile, passed: false, detectorsPassed: false, captures: 0, cases: 0, error: 'Missing native evidence result'};
  });
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
