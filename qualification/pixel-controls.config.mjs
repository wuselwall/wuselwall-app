import path from 'node:path';
import { defineConfig } from 'playwright/test';
import { root } from './matrix.mjs';
import { visualPolicy } from './visual-policy.mjs';

export default defineConfig({
  testDir: path.join(root, 'qualification/pixel-controls'),
  outputDir: path.join(root, 'build/qualification/pixel-controls/results'),
  snapshotPathTemplate: path.join(root, 'build/qualification/pixel-controls/fixtures/{arg}{ext}'),
  updateSnapshots: 'none', workers: 1, retries: 0, forbidOnly: true,
  expect: { timeout: 1000, toHaveScreenshot: visualPolicy },
  reporter: [['list'], ['json', { outputFile: path.join(root, 'build/qualification/pixel-controls/results.json') }]],
  use: { browserName: 'chromium', viewport: { width: 32, height: 32 }, deviceScaleFactor: 1 },
});
