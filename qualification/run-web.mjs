import fs from 'node:fs';
import path from 'node:path';
import net from 'node:net';
import { spawn } from 'node:child_process';
import { cases, checkInventory, inventory, root } from './matrix.mjs';
import { environment, verify } from './baseline.mjs';

checkInventory();
const mode = process.env.QUALIFY_MODE || 'compare';
const args = process.argv.slice(2);
if (args.some(arg => /update-snapshots|ignore-snapshots/.test(arg))) throw new Error('Baseline updates are separate from qualification');
if (!['capture', 'compare'].includes(mode)) throw new Error('QUALIFY_MODE must be capture or compare');
if (mode === 'compare') {
  const dir = process.env.QUALIFY_BASELINE_DIR;
  if (!dir) throw new Error('Comparison requires QUALIFY_BASELINE_DIR and QUALIFY_BASELINE_SHA256');
  process.env.QUALIFY_BASELINE_DIR = path.resolve(dir);
  verify(dir, fs.readFileSync(path.join(dir, 'manifest.json')), process.env.QUALIFY_BASELINE_SHA256);
}
const out = path.join(root, 'build/qualification/web');
fs.mkdirSync(out, { recursive: true });
fs.rmSync(path.join(out, 'results.json'), { force: true });
fs.rmSync(path.join(out, 'evidence.json'), { force: true });
// Never let a partial rerun inherit snapshots from a previous capture.
if (mode === 'capture') fs.rmSync(path.join(root, 'build/qualification/capture'), { recursive: true, force: true });
const reservation = net.createServer();
await new Promise((resolve, reject) => reservation.once('error', reject).listen(0, '127.0.0.1', resolve));
const port = reservation.address().port;
await new Promise(resolve => reservation.close(resolve));
const child = spawn(process.execPath, [path.join(root, 'node_modules/playwright/cli.js'), 'test', '-c', 'qualification/playwright.config.mjs', ...args],
  { cwd: root, stdio: 'inherit', env: { ...process.env, QUALIFY_MODE: mode, QUALIFY_WEB_PORT: String(port) } });
const interrupt = () => child.kill('SIGINT');
const terminate = () => child.kill('SIGTERM');
process.once('SIGINT', interrupt);
process.once('SIGTERM', terminate);
const result = await new Promise((resolve, reject) => {
  child.once('error', reject);
  child.once('close', (status, signal) => resolve({ status, signal }));
});
process.removeListener('SIGINT', interrupt);
process.removeListener('SIGTERM', terminate);
const samples = cases(process.env.QUALIFY_MATRIX || 'canonical');
const browsers = (process.env.QUALIFY_BROWSERS || 'chromium').split(',');
const expected = browsers.reduce((count, browser) => count + 1 + samples.filter(s => browser === 'chromium' || s.native && s.tier === 'canonical').length, 0);
const reportPath = path.join(out, 'results.json');
const stats = fs.existsSync(reportPath) ? JSON.parse(fs.readFileSync(reportPath, 'utf8')).stats : null;
const executionPassed = result.status === 0 && stats?.expected === expected && !stats?.unexpected && !stats?.flaky;
fs.writeFileSync(path.join(out, 'evidence.json'), JSON.stringify({ schema: 1, mode,
  candidateSha: process.env.QUALIFY_CANDIDATE_SHA || null, environment: environment(),
  matrix: process.env.QUALIFY_MATRIX || 'canonical', expected, stats, selection: args, executionPassed,
  qualification: 'INCOMPLETE', baselineVerified: mode === 'compare', openGates: inventory.openGates,
}, null, 2));
process.exitCode = executionPassed ? 0 : 1;
