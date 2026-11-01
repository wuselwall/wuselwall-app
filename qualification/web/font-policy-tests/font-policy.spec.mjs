import { test, expect } from 'playwright/test';

test('Emoji and CJK font fallback is served from this origin', async ({ page }, info) => {
  const origin = new URL(info.project.use.baseURL).origin;
  const fallbackRequests = [];
  const fallbackResponses = [];
  const externalRequests = [];
  const pageErrors = [];
  const consoleErrors = [];
  const badResponses = [];

  await page.route('**/*', route => {
    const url = new URL(route.request().url());
    if (['data:', 'blob:'].includes(url.protocol) || url.origin === origin) return route.continue();
    externalRequests.push(url.href);
    return route.abort();
  });
  page.on('request', request => {
    const url = new URL(request.url());
    if (url.origin === origin && url.pathname.startsWith('/font-fallback/')) {
      fallbackRequests.push({ url: url.href, type: request.resourceType() });
    }
  });
  page.on('response', response => {
    const url = new URL(response.url());
    if (url.origin === origin && url.pathname.startsWith('/font-fallback/')) {
      fallbackResponses.push({ url: url.href, status: response.status(), contentType: response.headers()['content-type'] ?? null });
    }
    if (response.status() >= 400) badResponses.push({ url: url.href, status: response.status() });
  });
  page.on('pageerror', error => pageErrors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error') consoleErrors.push({ text: message.text(), url: message.location().url });
  });

  const query = new URLSearchParams({ scenario: 'setup', locale: 'de', shade: 'light',
    state: 'password-sign-in', destination: 'PasswordSignInPage', tab: 'today', advanced: '0' });
  await page.goto(`/?${query}#/setup/sign-in`);
  await expect(page.locator('body[data-qualification-ready="password-sign-in"]')).toBeAttached();
  const fields = page.getByRole('textbox');
  await expect(fields.first()).toBeAttached();
  await fields.first().fill('漢字𠮷𠀋 🍕');
  await page.keyboard.press('Tab');
  await expect.poll(() => fallbackRequests.length, {
    message: 'CJK input should request at least one Flutter font fallback shard',
    timeout: 15_000,
  }).toBeGreaterThan(0);
  await expect.poll(() => fallbackResponses.length, {
    message: 'Fallback requests should settle before policy evidence is captured',
    timeout: 15_000,
  }).toBeGreaterThan(0);
  await page.waitForLoadState('networkidle', { timeout: 15_000 });

  const evidence = {
    fallbackRequests,
    fallbackResponses,
    externalRequests,
    pageErrors,
    consoleErrors,
    badResponses,
  };
  await info.attach('font-policy-evidence', {
    body: JSON.stringify(evidence, null, 2),
    contentType: 'application/json',
  });

  expect(fallbackRequests.length, 'At least one fallback request must be observed').toBeGreaterThan(0);
  expect(fallbackRequests.every(request => {
    const url = new URL(request.url);
    return url.origin === origin && url.pathname.startsWith('/font-fallback/');
  }), 'Every fallback request must use this origin and the dedicated fallback path').toBe(true);
  expect(externalRequests, 'No request may escape to an external origin').toEqual([]);
  expect(pageErrors, 'Font fallback must not create page errors').toEqual([]);
  expect(fallbackRequests.some(request => request.url.includes('/notocoloremoji/')),
    'The emoji must request a Noto Color Emoji shard').toBe(true);
  expect(fallbackResponses.every(response => response.status === 200 && response.contentType === 'font/woff2'),
    'Every fallback shard must be served (scripts/web-font-fallback.sh fills the build)').toBe(true);
  expect(badResponses, 'No resource may fail').toEqual([]);
  expect(consoleErrors, 'Font fallback must not log errors').toEqual([]);
});
