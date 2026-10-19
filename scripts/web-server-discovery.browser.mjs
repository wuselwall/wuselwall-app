// Same release bundle, two independent installations; no live backend or email delivery.
// Build: (cd app && flutter build web --release --no-web-resources-cdn --dart-define=ENV=release -o build/web-live)
// Run: node scripts/web-server-discovery.browser.mjs [app/build/web-live]
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { chromium } from 'playwright';

const root = path.resolve(process.argv[2] ?? 'app/build/web-live');
assert.ok(fs.existsSync(path.join(root, 'index.html')), 'Build the backend-neutral web app first.');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.ttf': 'font/ttf', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  let file = path.join(root, new URL(req.url, 'http://localhost').pathname);
  if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(root, 'index.html');
  res.writeHead(200, { 'content-type': types[path.extname(file)] ?? 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const base = `http://localhost:${server.address().port}`;
const browser = await chromium.launch({ headless: true });
try {
  for (const family of ['one', 'two']) {
    const backend = `https://family-${family}.example.org`;
    const key = `sb_publishable_browser_fixture_${family}`;
    const context = await browser.newContext({ locale: 'en-GB', viewport: { width: 390, height: 844 } });
    try {
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', (error) => errors.push(error.message));
      let discoveryRequests = 0;
      await page.route(`${base}/.well-known/wuselwall.json`, (route) => {
        discoveryRequests++;
        return route.fulfill({ json: { wuselwall: 1, supabase_url: backend, publishable_key: key,
          api_version: 1, min_app_version: '0.0.0', household_creation: 'code', features: [] } });
      });
      const otpRequests = [];
      await page.route(`${backend}/**`, async (route) => {
        if (route.request().method() === 'OPTIONS') return route.fulfill({ status: 204,
          headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' } });
        if (route.request().url().includes('/auth/v1/otp')) {
          otpRequests.push({ url: route.request().url(), key: route.request().headers().apikey });
          return route.fulfill({ json: {}, headers: { 'access-control-allow-origin': '*' } });
        }
        return route.fulfill({ status: 401, json: { message: 'Synthetic browser fixture: signed out' },
          headers: { 'access-control-allow-origin': '*' } });
      });
      await page.goto(base);
      await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 90000 });
      await page.locator('flt-semantics-placeholder').evaluate((element) => element.click()).catch(() => {});
      await page.getByRole('button', { name: 'Continue with email', exact: true }).click({ timeout: 30000 });
      await page.locator('input').first().fill('browser-probe@example.org', { force: true });
      const sent = page.waitForResponse((response) => response.request().method() === 'POST' &&
        new URL(response.url()).pathname === '/auth/v1/otp');
      await page.getByRole('button', { name: 'Continue', exact: true }).click();
      assert.equal((await sent).status(), 200);
      await page.waitForFunction(() => document.body.innerText.includes('6-digit code'));
      assert.ok(discoveryRequests > 0, 'web app must fetch its installation discovery document');
      assert.equal(otpRequests.length, 1, 'one code request, no restart');
      assert.ok(otpRequests[0].url.startsWith(`${backend}/auth/v1/otp`));
      assert.equal(otpRequests[0].key, key, 'auth must use the installation publishable key');
      assert.deepEqual(errors, []);
      console.log(`PASS: same bundle discovers installation ${family} and sends OTP only to its configured backend/key (synthetic API).`);
    } finally { await context.close(); }
  }
} finally { await browser.close(); await new Promise((resolve) => server.close(resolve)); }
