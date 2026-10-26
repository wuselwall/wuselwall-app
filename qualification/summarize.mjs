import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { cases, inventory, root } from './matrix.mjs';
import { sha256 } from './baseline.mjs';

export function summarize({ sha, jobs, matrix, mode, reports, coverage = inventory }) {
  const failures = [];
  const require = (condition, reason) => { if (!condition) failures.push(reason); };
  require(/^[a-f0-9]{40}$/.test(sha || ''), 'Missing candidate SHA');
  require(matrix === 'full', 'Only the full matrix is eligible');
  require(mode === 'compare', 'Capture output is unapproved');
  for (const name of ['prepare', 'flutter', 'web', 'native', 'production']) {
    require(jobs[name]?.result === 'success', `${name} job did not succeed`);
  }
  const flutter = reports.flutter;
  const flutterExpected = 2 * (cases('canonical', coverage).length + 2 * cases('responsive', coverage).length);
  require(flutter?.matrix === 'full' && flutter?.expected === flutterExpected && flutter?.executed === flutterExpected,
    'Flutter matrix is incomplete');
  require(flutter?.results?.length === flutterExpected && flutter.results.every(r => r.status === 'PASS' && !r.findings?.length && !r.error),
    'Flutter findings remain or results are missing');
  const web = reports.web;
  const webExpected = cases('full', coverage).length + 1;
  require(web?.candidateSha === sha && web?.matrix === 'full' && web?.mode === 'compare' && web?.baselineVerified === true && web?.executionPassed === true,
    'Browser comparison did not pass for this commit');
  require(web?.expected === webExpected && web?.stats?.expected === webExpected && !web?.stats?.unexpected && !web?.stats?.skipped && !web?.stats?.flaky,
    'Browser matrix has missing, failed, skipped or flaky cases');
  const native = reports.native;
  require(native?.candidateSha === sha && native?.profile === 'full' && native?.executionPassed === true,
    'Native execution is incomplete');
  require(native?.visual?.mode === 'compare' && native?.visual?.passed === true && native?.visual?.checked > 0 &&
    /^[a-f0-9]{64}$/.test(native?.visual?.manifestDigest || ''), 'Native baseline comparison is incomplete');
  for (const platform of ['android', 'ios']) {
    const audit = native?.audits?.[platform];
    require(audit?.supported === true && audit?.detectorsPassed === true && audit?.passed === true && audit?.cases > 0,
      `${platform} audit or its detector is incomplete`);
  }
  const production = reports.production;
  require(production?.candidateSha === sha && production?.executionPassed === true && production?.entryPoint === 'lib/main.dart',
    'Production entry-point smoke is incomplete');
  require(Object.keys(coverage.pendingRoutes).length === 0, 'Routes remain pending');
  const manual = ['physical-device-review', 'approved-baseline-review'];
  require(coverage.openGates.every(g => manual.includes(g)), 'Implementation gates remain open');
  return { schema: 2, candidateSha: sha || null, matrix, mode, jobs,
    automaticPass: failures.length === 0, qualified: false,
    qualification: failures.length ? 'INCOMPLETE' : 'READY_FOR_REVIEW',
    baselineVerified: web?.baselineVerified === true,
    failures, openGates: coverage.openGates, pendingRoutes: coverage.pendingRoutes,
    evidence: Object.fromEntries(Object.entries(reports).map(([key, report]) => [key, report ? sha256(JSON.stringify(report)) : null])),
    scope: 'Automatic evidence; physical-device and baseline acceptance require the protected release environment',
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const dir = path.join(root, 'build/qualification');
  const inputs = process.env.QUALIFY_EVIDENCE_DIR || path.join(dir, 'downloaded');
  const read = file => { try { return JSON.parse(fs.readFileSync(path.join(inputs, file), 'utf8')); } catch { return null; } };
  const result = summarize({ sha: process.env.QUALIFY_CANDIDATE_SHA,
    jobs: JSON.parse(process.env.QUALIFY_JOBS || '{}'), matrix: process.env.QUALIFY_MATRIX, mode: process.env.QUALIFY_MODE,
    reports: { flutter: read('flutter/full/results.json'), web: read('web/web/evidence.json'),
      native: read('native/evidence.json'), production: read('production/evidence.json') } });
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'summary.json'), JSON.stringify(result, null, 2));
  const summary = `## Candidate evidence: ${result.qualification}\n\nCommit: \`${result.candidateSha || 'unknown'}\`\n\n`
    + Object.entries(result.jobs).map(([name, value]) => `- ${name}: ${value.result}`).join('\n')
    + '\n\n' + result.failures.map(f => `- ${f}`).join('\n')
    + '\n\nHuman review is required in the protected release environment before promotion.\n';
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, summary);
  console.log(summary);
  if (!result.automaticPass) process.exitCode = 1;
}
