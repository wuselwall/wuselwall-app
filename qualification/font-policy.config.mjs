import path from 'node:path';
import { defineConfig } from 'playwright/test';

const port = Number(process.env.QUALIFY_FONT_POLICY_PORT || 4179);
process.env.QUALIFY_FONT_POLICY_PORT = String(port);
const baseURL = `http://127.0.0.1:${port}`;
const output = path.join(import.meta.dirname, '../build/qualification/font-policy');

export default defineConfig({
  testDir: path.join(import.meta.dirname, 'web/font-policy-tests'),
  outputDir: path.join(output, 'results'),
  workers: 1,
  retries: 0,
  timeout: 90_000,
  reporter: [['list'], ['json', { outputFile: path.join(output, 'results.json') }]],
  use: {
    baseURL,
    browserName: 'chromium',
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1,
    timezoneId: 'Europe/Berlin',
    launchOptions: { args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] },
  },
  webServer: {
    command: `QUALIFY_WEB_PORT=${port} node qualification/serve.mjs`,
    cwd: path.join(import.meta.dirname, '..'),
    url: baseURL,
    reuseExistingServer: false,
  },
});
