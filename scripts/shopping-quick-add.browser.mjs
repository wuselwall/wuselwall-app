// Run: node scripts/shopping-quick-add.browser.mjs
// Exercise untrusted search text, catalogue names and notes in the actual mockup.
import assert from 'node:assert/strict';
import { chromium } from 'playwright';

const mockup = new URL('../specs/mockups/shopping-quick-add.html', import.meta.url).href;
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  // The mockup needs no network access, including its optional web fonts.
  await page.route(/^https?:/, (route) => route.abort());
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto(mockup);

  // Matching search results also interpolate the query into their section heading.
  await page.locator('#q').fill('mi<!---->');
  assert.equal(await page.locator('#results .sec-label').first().textContent(), 'Treffer für „mi<!---->"');

  const name = `Probe <img src=x onerror="globalThis.injected=true"> & <svg onload='globalThis.injected=true'></svg> " ' &lt;b&gt;`;
  await page.locator('#q').fill(name);
  assert.equal(await page.locator('[data-new] .nm').textContent(), `„${name}" neu anlegen`);
  await page.locator('[data-new]').click();

  const tile = page.locator('#results [data-add]').filter({ hasText: name });
  assert.equal(await tile.count(), 1);
  assert.equal(await tile.getAttribute('data-add'), name);
  assert.equal(await tile.locator('.nm').textContent(), name);
  assert.equal(await tile.locator('[data-remove]').getAttribute('data-remove'), name);

  const row = page.locator('#drawer-body .li').filter({ hasText: name });
  assert.equal(await row.count(), 1);
  assert.equal(await row.locator('[data-drop]').getAttribute('data-drop'), name);

  // Encoded attribute values must still identify the item when removing/re-adding it.
  await tile.click();
  assert.equal(await tile.locator('.badge').textContent(), '2 ×');
  await tile.locator('[data-remove]').click();
  assert.equal(await tile.locator('.badge').textContent(), '✓');
  await page.locator('#drawer-handle').click();
  await row.locator('[data-drop]').click();
  assert.equal(await row.count(), 0);
  await page.locator('#drawer-handle').click();
  await tile.click();
  assert.equal(await row.count(), 1);

  await tile.click({ delay: 550 });
  assert.equal(await page.locator('#np-name').textContent(), name);
  const note = `<img src=x onerror="globalThis.injected=true"> & " ' <svg onload='globalThis.injected=true'></svg>`;
  await page.locator('#np-input').fill(note);
  await page.locator('#np-ok').click();
  assert.equal(await row.locator('.note').textContent(), note);

  // No user text may create elements or event-handler attributes.
  assert.equal(await page.locator('#results img, #results svg, #drawer-body img, #drawer-body svg, [onerror], [onload]').count(), 0);
  assert.equal(await page.evaluate(() => globalThis.injected), undefined);
  assert.deepEqual(errors, []);

  console.log('PASS: shopping search, catalogue names and notes remain literal text; item actions preserve their values.');
} finally {
  await browser.close();
}
