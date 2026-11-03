// Exercise the distributable web entry point, separately from synthetic widget captures.
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { root } from './matrix.mjs';
const steps = [
  { command: 'flutter', args: ['build', 'web', '--release', '--no-web-resources-cdn', '--dart-define-from-file=env/store.json', '-o', 'build/web-live'], cwd: path.join(root, 'app') },
  { command: process.execPath, args: ['scripts/web-server-discovery.browser.mjs'], cwd: root },
  { command: process.execPath, args: ['scripts/shopping-quick-add.browser.mjs'], cwd: root },
];
const results = [];
try {
  for (const step of steps) {
    const status = await new Promise((resolve, reject) => {
      const child = spawn(step.command, step.args, { cwd: step.cwd, stdio: 'inherit' });
      child.once('error', reject);
      child.once('close', (code, signal) => resolve({ code, signal }));
    });
    results.push({ command: [path.basename(step.command), ...step.args].join(' '), ...status });
    if (status.code !== 0) break;
  }
} finally {
  const executionPassed = results.length === steps.length && results.every(r => r.code === 0 && !r.signal);
  const dir = path.join(root, 'build/qualification/production');
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'evidence.json'), JSON.stringify({ schema: 1,
    candidateSha: process.env.QUALIFY_CANDIDATE_SHA || null, entryPoint: 'lib/main.dart',
    platform: 'web', scope: 'Release web bundle, server discovery, encrypted-storage migration and shopping journey with intercepted APIs',
    executionPassed, results }, null, 2));
  if (!executionPassed) process.exitCode = 1;
}
