import path from 'node:path';
import { defineConfig } from 'playwright/test';

export default defineConfig({
  testDir: path.join(import.meta.dirname, 'web/scroll-audit-tests'),
  outputDir: path.join(import.meta.dirname, '../build/qualification/scroll-audit/results'),
  workers: 1,
  retries: 0,
  reporter: [['list'], ['json', { outputFile: path.join(import.meta.dirname, '../build/qualification/scroll-audit/results.json') }]],
  use: {
    browserName: 'chromium',
    viewport: { width: 640, height: 480 },
    launchOptions: { args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] },
  },
});
