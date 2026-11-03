import { test, expect } from 'playwright/test';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
test('axe detects a deliberately unlabeled action', async ({ page }) => {
  await page.setContent('<html lang="en"><head><title>Detector fixture</title></head><body><main><button></button></main></body></html>');
  await page.addScriptTag({ path: require.resolve('axe-core/axe.min.js') });
  const results = await page.evaluate(() => window.axe.run(document, { runOnly: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'] }));
  expect(results.violations.some(v => v.id === 'button-name')).toBe(true);
});
