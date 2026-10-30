import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import { fileURLToPath } from 'node:url';
import { inventory } from '../matrix.mjs';

export const profiles = ['ios-phone', 'ios-tablet', 'android-phone', 'android-tablet',
  'ios-phone-large', 'ios-tablet-large', 'android-phone-large', 'android-tablet-large', 'android-min-phone'];
export function expectedCases(profile, smoke = false) {
  return inventory.states.filter(s => s.native && (profile.includes('tablet') || !['kid', 'kiosk'].includes(s.scenario)))
    .flatMap(s => (smoke ? ['de'] : inventory.locales).flatMap(locale =>
      (smoke ? ['light'] : ['light', 'dark']).map(shade => `${s.id}-${locale}-${shade}`)));
}
export async function nativeEvidence(root, candidateSha, smoke = false) {
  const results = [];
  const statuses = await fs.readFile(path.join(root, 'profiles.txt'), 'utf8').catch(() => '');
  for (const profile of profiles) {
    try {
      const expected = expectedCases(profile, smoke);
      const report = JSON.parse(await fs.readFile(path.join(root, profile, 'audit.json'), 'utf8'));
      const render = JSON.parse(await fs.readFile(path.join(root, profile, 'results.json'), 'utf8'));
      assert.equal(report.schemaVersion, 1);
      assert.equal(report.candidateSha, candidateSha);
      assert.equal(render.candidateSha, candidateSha);
      assert.equal(report.done, true);
      assert.equal(report.expected, expected.length + 2);
      assert.equal(report.results.length, report.expected);
      assert.equal(new Set(report.results.map(r => r.id)).size, report.expected);
      assert.deepEqual(report.results.map(r => r.id).sort(), [...expected, 'detector-bad', 'detector-keyboard'].sort());
      const detectorsPassed = ['detector-bad', 'detector-keyboard'].every(id => report.results.find(r => r.id === id)?.passed === true);
      assert.ok(render.logicalWidth > 0 && render.logicalHeight > 0 && render.devicePixelRatio > 0, 'Missing native render geometry');
      assert.equal(render.logicalWidth >= 600, profile.includes('tablet'), 'Native phone/tablet geometry differs from its profile');
      assert.equal(render.expected, expected.length);
      assert.equal(render.captured, expected.length);
      const pngs = (await fs.readdir(path.join(root, profile))).filter(p => p.endsWith('.png'));
      assert.deepEqual(pngs.sort(), expected.map(id => `${id}.png`).sort());
      for (const name of pngs) {
        const bytes = await fs.readFile(path.join(root, profile, name));
        assert.ok(bytes.length > 24 && bytes.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')), `Invalid PNG: ${name}`);
        const image = await sharp(bytes).metadata();
        assert.ok(image.format === 'png' && image.width > 0 && image.height > 0, `Invalid PNG geometry: ${name}`);
      }
      const largeTextPassed = !profile.endsWith('-large') || report.results.every(r => typeof r.textScale === 'number' && r.textScale >= 1.5);
      const executionPassed = statuses.split('\n').filter(line => line === `${profile}: PASS`).length === 1 &&
        !statuses.split('\n').includes(`${profile}: FAIL`);
      results.push({profile, supported: true, detectorsPassed, largeTextPassed,
        passed: executionPassed && largeTextPassed && detectorsPassed && report.results.every(r => r.passed === true && r.frameworkErrors?.length === 0),
        captures: pngs.length, cases: report.expected, report});
    } catch (error) {
      results.push({profile, supported: false, passed: false, detectorsPassed: false, largeTextPassed: false, captures: 0, cases: 0, error: String(error)});
    }
  }
  const aggregate = platform => {
    const entries = results.filter(r => r.profile.startsWith(platform));
    return {supported: entries.every(r => r.supported), detectorsPassed: entries.every(r => r.detectorsPassed),
      passed: entries.every(r => r.passed), cases: entries.reduce((n, r) => n + r.cases, 0)};
  };
  const visual = await fs.readFile(path.join(root, 'visual.json'), 'utf8').then(JSON.parse).catch(error => ({passed: false, error: String(error)}));
  if (visual.candidateSha !== candidateSha) visual.passed = false;
  return {schemaVersion: 1, candidateSha, visual, profile: smoke ? 'smoke' : 'full',
    executionPassed: results.every(r => r.passed), captures: results.reduce((n, r) => n + r.captures, 0),
    audits: {android: aggregate('android'), ios: aggregate('ios')}, results,
    limitations: ['Native automated audit results require VoiceOver/TalkBack physical-device review.',
      'Native visual comparison uses exact RGBA equality until native raster noise is measured and a reviewed policy is approved.',
      'iOS Display Zoom and assistive-technology interaction require physical-device review.',
      'ATF contrast results may be NOT_RUN for Flutter virtual nodes; Flutter contrast and browser image checks remain separate required gates.']};
}
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const root = path.resolve('build/qualification/native');
  const evidence = await nativeEvidence(root, process.env.QUALIFY_CANDIDATE_SHA, process.env.QUALIFY_NATIVE_SMOKE === 'true');
  await fs.mkdir(root, {recursive: true});
  await fs.writeFile(path.join(root, 'evidence.json'), `${JSON.stringify(evidence, null, 2)}\n`);
  if (!evidence.executionPassed) process.exitCode = 1;
}
