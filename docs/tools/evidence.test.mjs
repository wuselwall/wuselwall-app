import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import path from 'node:path';
import { tmpdir } from 'node:os';
import { docsEvidence, validateDocsEvidence } from './evidence.mjs';
import { screenshotPaths } from './check-shots.mjs';
const sha = 'a'.repeat(40);
test('full guide evidence covers every locale/theme and is commit-bound', () => {
  const root = fs.mkdtempSync(path.join(tmpdir(), 'ww-guide-evidence-'));
  try {
    fs.mkdirSync(path.join(root, 'tools'));
    fs.writeFileSync(path.join(root, 'tools/screenshots.mjs'), "const shots = [\n { name: 'home' },\n];\n");
    for (const file of screenshotPaths(['home'])) {
      const target = path.join(root, 'public/screenshots', file);
      fs.mkdirSync(path.dirname(target), { recursive: true }); fs.writeFileSync(target, file);
    }
    const report = docsEvidence(root, sha); validateDocsEvidence(report, sha, ['home']);
    for (const mutate of [r => { r.candidateSha = 'b'.repeat(40); }, r => { r.matrix = 'smoke'; },
      r => { r.executionPassed = false; }, r => { r.screenshots.pop(); },
      r => { r.screenshots[0].file = r.screenshots[1].file; }, r => { r.screenshots[0].sha256 = ''; }]) {
      const changed = structuredClone(report); mutate(changed); assert.throws(() => validateDocsEvidence(changed, sha, ['home']));
    }
    fs.unlinkSync(path.join(root, 'public/screenshots/fr/home-dark.png'));
    assert.throws(() => docsEvidence(root, sha), /ENOENT/);
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});
