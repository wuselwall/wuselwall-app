// Written only after the full capture, image checks, build and browser checks pass.
// Promotion validates the exact candidate and the complete screenshot inventory.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { captureNames, screenshotPaths } from './check-shots.mjs';

export function docsEvidence(docs, sha) {
  assert.match(sha ?? '', /^[a-f0-9]{40}$/, 'A full candidate SHA is required');
  const files = screenshotPaths(captureNames(fs.readFileSync(path.join(docs, 'tools/screenshots.mjs'), 'utf8')));
  return { candidateSha: sha, matrix: 'full', executionPassed: true,
    screenshots: files.map(file => ({ file, sha256: createHash('sha256').update(fs.readFileSync(path.join(docs, 'public/screenshots', file))).digest('hex') })) };
}

export function validateDocsEvidence(report, sha, names) {
  assert.equal(report?.candidateSha, sha, 'Guide evidence belongs to another commit');
  assert.equal(report?.matrix, 'full', 'The full guide matrix is required');
  assert.equal(report?.executionPassed, true, 'Guide validation did not pass');
  const files = screenshotPaths(names).sort();
  assert.ok(Array.isArray(report?.screenshots), 'Missing guide screenshots');
  assert.deepEqual(report.screenshots.map(s => s?.file).sort(), files, 'Guide screenshots are missing, duplicated or unexpected');
  for (const shot of report.screenshots) assert.match(shot.sha256 ?? '', /^[a-f0-9]{64}$/, `Missing checksum: ${shot.file}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const result = docsEvidence(path.resolve('docs'), process.env.QUALIFY_CANDIDATE_SHA);
  fs.mkdirSync('build/qualification/docs', { recursive: true });
  fs.writeFileSync('build/qualification/docs/evidence.json', JSON.stringify(result, null, 2));
  console.log(`Guide evidence: ${result.screenshots.length} screenshots for ${result.candidateSha}`);
}
