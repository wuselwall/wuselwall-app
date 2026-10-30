import path from 'node:path';
import { defineConfig } from 'playwright/test';
import { root } from './matrix.mjs';
import { visualPolicy } from './visual-policy.mjs';

const baseURL = `http://127.0.0.1:${process.env.QUALIFY_WEB_PORT || 4178}`;
export default defineConfig({
  testDir: path.join(root, 'qualification/web'),
  testMatch: ['**/screens.spec.mjs', '**/detector.spec.mjs'],
  outputDir: path.join(root, 'build/qualification/web/results'),
  snapshotPathTemplate: path.join(process.env.QUALIFY_BASELINE_DIR || path.join(root, 'build/qualification/baseline'), '{projectName}/{arg}{ext}'),
  updateSnapshots: 'none',
  forbidOnly: true, workers: 1, retries: 0, timeout: 90_000,
  expect: { timeout: 15_000, toHaveScreenshot: visualPolicy },
  reporter: [['list'], ['html', { outputFolder: path.join(root, 'build/qualification/web/html'), open: 'never' }],
    ['json', { outputFile: path.join(root, 'build/qualification/web/results.json') }]],
  use: { baseURL, timezoneId: 'Europe/Berlin', deviceScaleFactor: 1,
    reducedMotion: 'reduce', trace: 'retain-on-failure', screenshot: 'only-on-failure' },
  webServer: { command: 'node qualification/serve.mjs', cwd: root, url: baseURL, reuseExistingServer: false },
  projects: (process.env.QUALIFY_BROWSERS || 'chromium').split(',').map(name => ({ name, use: { browserName: name,
    ...(name === 'chromium' ? { launchOptions: { args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] } } : {}) } })),
});
