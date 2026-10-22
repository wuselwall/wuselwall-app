// Verify the built guide at its configured mount, without contacting any family server.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdtemp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { chromium } from 'playwright';

const base = process.env.DOCS_BASE ?? '/';
assert.ok(base.startsWith('/') && base.endsWith('/'), 'DOCS_BASE must begin and end with /');
const origin = 'http://127.0.0.1:4174';
const server = spawn(process.execPath, ['node_modules/vitepress/bin/vitepress.js', 'preview', 'docs', '--host', '127.0.0.1', '--port', '4174'], { stdio: 'inherit', env: process.env });
const output = await mkdtemp(join(tmpdir(), 'wuselwall-docs-preview-'));
let browser;
try {
  let ready = false;
  for (let i = 0; i < 100; i++) {
    if (server.exitCode !== null) throw new Error('Guide preview exited');
    try { ready = (await fetch(`${origin}${base}fr/`)).ok; } catch { /* starting */ }
    if (ready) break;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  assert.ok(ready, 'local guide ready');
  browser = await chromium.launch();
  for (const [lang, search, text] of [['fr', 'Rechercher', 'cartable'], ['es', 'Buscar', 'mochila']]) {
    const context = await browser.newContext({ locale: `${lang}-${lang.toUpperCase()}`, viewport: { width: 1280, height: 900 }, colorScheme: 'light' });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (error) => errors.push(error.message));
    await page.goto(`${origin}${base}${lang}/school/`);
    assert.equal(await page.locator('html').getAttribute('lang'), lang);
    await page.waitForFunction((code) => [...document.querySelectorAll('img.shot')].every((img) => img.src.includes(`/screenshots/${code}/`)), lang);
    assert.equal(await page.locator('img.shot-light').count(), 4);
    for (const img of await page.locator('img.shot').all()) {
      const src = await img.getAttribute('src');
      assert.ok(src.startsWith(`${base}screenshots/${lang}/`), `mounted ${lang} screenshot URL`);
      assert.equal((await page.request.get(origin + src)).status(), 200);
    }
    // Search is scoped to the selected locale and its controls are translated.
    await page.locator('.DocSearch-Button').or(page.locator('.VPNavBarSearch button')).first().click();
    const input = page.locator('#localsearch-input');
    assert.equal(await input.getAttribute('placeholder'), search);
    await input.fill(text);
    await page.locator('.VPContent').waitFor();
    await page.waitForFunction((prefix) => [...document.querySelectorAll('#localsearch-list a')].some((a) => a.getAttribute('href')?.startsWith(prefix)), `${base}${lang}/`);
    for (const href of await page.locator('#localsearch-list a').evaluateAll((links) => links.map((a) => a.getAttribute('href')))) {
      assert.ok(href.startsWith(`${base}${lang}/`), `${lang} search remains localized`);
    }
    await page.keyboard.press('Escape');
    // Language changes preserve the corresponding guide route.
    const other = lang === 'fr' ? 'es' : 'fr';
    await page.locator('.VPNavBarTranslations button').click();
    await page.locator(`.VPNavBarTranslations a[href="${base}${other}/school/"]`).click();
    await page.waitForURL(`${origin}${base}${other}/school/`);
    await page.waitForFunction((code) => document.documentElement.lang === code, other);
    await page.goto(`${origin}${base}${lang}/school/`);
    for (const dark of [false, true]) {
      const isDark = () => page.locator('html').evaluate((el) => el.classList.contains('dark'));
      if ((await isDark()) !== dark) await page.locator('.VPNavBarAppearance button').click();
      await page.waitForFunction((expected) => document.documentElement.classList.contains('dark') === expected, dark);
      assert.equal(await isDark(), dark);
      assert.equal(await page.locator('img.shot-dark').first().isVisible(), dark);
      assert.equal(await page.locator('img.shot-light').first().isVisible(), !dark);
      await page.screenshot({ path: join(output, `${lang}-${dark ? 'dark' : 'light'}.png`) });
    }
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(`${origin}${base}${lang}/guide/setup`);
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `${lang} phone layout`);
    await page.locator('.VPLocalNav .menu').click();
    const sideLink = page.locator(`.VPSidebar a[href="${base}${lang}/settings/security"]`).first();
    await sideLink.click();
    await page.waitForURL(`${origin}${base}${lang}/settings/security`);
    assert.deepEqual(errors, [], `${lang} has no runtime errors`);
    await context.close();
  }
  console.log(`Guide browser checks passed at ${base}: FR/ES pages, search, language switching, both themes, screenshots and mobile navigation. Previews: ${output}`);
} finally {
  await browser?.close();
  if (server.exitCode === null) {
    const closed = once(server, 'close'); server.kill('SIGTERM'); await closed;
  }
}
