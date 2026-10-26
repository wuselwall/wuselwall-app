import { test, expect } from 'playwright/test';

test('CJK font fallback requests stay on this origin', async ({ page }, info) => {
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
  await fields.first().fill('漢字𠮷𠀋');
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

  const unexpectedConsoleErrors = consoleErrors.filter(error => {
    if (!/404/.test(error.text)) return true;
    try {
      const url = new URL(error.url);
      return url.origin !== origin || !url.pathname.startsWith('/font-fallback/');
    } catch {
      return true;
    }
  });

  const evidence = {
    fallbackRequests,
    fallbackResponses,
    externalRequests,
    pageErrors,
    consoleErrors,
    badResponses,
    unexpectedConsoleErrors,
    coverageNote: 'This verifies request routing only; missing fallback files may still leave unsupported glyphs unavailable.',
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
  expect(badResponses.every(response => {
    const url = new URL(response.url);
    return url.origin === origin && url.pathname.startsWith('/font-fallback/');
  }), 'Any failed resource must be inside the expected local font-fallback namespace').toBe(true);
  expect(unexpectedConsoleErrors, 'Only expected local missing-font 404 messages may be present').toEqual([]);
});
