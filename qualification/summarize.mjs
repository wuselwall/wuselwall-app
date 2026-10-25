import fs from 'node:fs';
import path from 'node:path';
import { inventory, root } from './matrix.mjs';

const jobs = JSON.parse(process.env.QUALIFY_JOBS || '{}');
const result = {
  schema: 1, candidateSha: process.env.QUALIFY_CANDIDATE_SHA || null,
  qualification: 'INCOMPLETE', qualified: false,
  scope: 'Initial candidate evidence; promotion enforcement is not enabled',
  jobs, openGates: inventory.openGates,
  pendingRoutes: inventory.pendingRoutes,
};
const dir = path.join(root, 'build/qualification');
fs.mkdirSync(dir, { recursive: true });
fs.writeFileSync(path.join(dir, 'summary.json'), JSON.stringify(result, null, 2));
const summary = `## Candidate evidence: INCOMPLETE\n\nCommit: \`${result.candidateSha || 'unknown'}\`\n\n`
  + Object.entries(jobs).map(([name, value]) => `- ${name}: ${value.result}`).join('\n')
  + `\n\n${Object.keys(inventory.pendingRoutes).length} routes remain pending. Open gates:\n\n`
  + inventory.openGates.map(gate => `- ${gate}`).join('\n')
  + '\n\nThis run does not authorize release promotion. Captures require separate baseline review.\n';
if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, summary);
console.log(summary);
if (!Object.keys(jobs).length || Object.values(jobs).some(job => job.result !== 'success')) process.exitCode = 1;
