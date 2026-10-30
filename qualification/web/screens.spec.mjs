import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { test, expect } from 'playwright/test';
import { cases, checkInventory, root } from '../matrix.mjs';
import { auditWithScrollCheckpoints, runAxe } from './scroll-audit.mjs';

const require = createRequire(import.meta.url);
checkInventory();
const capture = process.env.QUALIFY_MODE === 'capture';
if (!['capture', 'compare'].includes(process.env.QUALIFY_MODE || 'compare')) throw new Error('QUALIFY_MODE must be capture or compare');

for (const sample of cases(process.env.QUALIFY_MATRIX || 'canonical')) {
  test(sample.caseId, async ({ page, browserName }, info) => {
    // Chromium covers the broad matrix; other engines cover essential native-marked states.
    test.skip(browserName !== 'chromium' && (!sample.native || sample.tier !== 'canonical'), 'Focused browser compatibility coverage');
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    const blocked = [];
    await page.route('**/*', route => {
      const url = new URL(route.request().url());
      if (['data:', 'blob:'].includes(url.protocol) || url.origin === new URL(info.project.use.baseURL).origin) return route.continue();
      blocked.push(url.origin); return route.abort();
    });
    await page.setViewportSize({ width: sample.width, height: sample.height });
    await page.emulateMedia({ colorScheme: sample.shade === 'light' ? 'light' : 'dark' });
    const query = new URLSearchParams({ scenario: sample.scenario, locale: sample.locale, shade: sample.shade,
      state: sample.id, destination: sample.widget, tab: sample.tab || 'today', advanced: sample.advanced ? '1' : '0' });
    await page.goto(`/?${query}#${sample.route}`);
    // The test entry point enables semantics before autofocus fields connect.
    await expect(page.locator('flt-semantics').first()).toBeAttached({ timeout: 60_000 });
    await expect(page.locator(`body[data-qualification-ready="${sample.id}"]`)).toBeAttached();
    await expect(page.getByRole('button').first()).toBeAttached();
    const semantics = await page.locator('flt-semantics-host').ariaSnapshot();
    expect(semantics.trim().length, 'The audit must inspect a populated semantics tree').toBeGreaterThan(50);
    if (capture) {
      // Staging only. Approval is a separate, reviewed baseline operation.
      const folder = path.join(root, 'build/qualification/capture', browserName);
      fs.mkdirSync(folder, { recursive: true });
      let previous;
      let stable;
      await expect.poll(async () => {
        const current = await page.screenshot({ animations: 'disabled' });
        const equal = previous?.equals(current) ?? false;
        previous = current;
        if (equal) stable = current;
        return equal;
      }, { message: 'Wait for two identical rendered captures' }).toBe(true);
      fs.writeFileSync(path.join(folder, `${sample.caseId}.png`), stable);
      fs.writeFileSync(path.join(folder, `${sample.caseId}-aria.yml`), semantics);
      await info.attach('capture-status', { body: 'UNAPPROVED CAPTURE; NOT QUALIFIED', contentType: 'text/plain' });
    } else {
      await expect.soft(page).toHaveScreenshot(`${sample.caseId}.png`);
      expect.soft(semantics).toMatchSnapshot(`${sample.caseId}-aria.yml`);
    }
    await page.addScriptTag({ path: require.resolve('axe-core/axe.min.js') });
    const audit = await runAxe(page);
    const scrollAudit = await auditWithScrollCheckpoints(page, audit);
    await info.attach('axe-report', { body: JSON.stringify({ ...audit,
      unsupported: ['Canvas-painted colour contrast: covered by Flutter checks and review'],
    }, null, 2), contentType: 'application/json' });
    await info.attach('axe-scroll-checkpoints', { body: JSON.stringify({
      checkpoints: scrollAudit.checkpoints,
      resolved: scrollAudit.resolved,
      remainingViolations: scrollAudit.remainingViolations,
    }, null, 2), contentType: 'application/json' });
    expect.soft(scrollAudit.remainingViolations, 'DOM/ARIA audit findings after verified scroll checkpoints').toEqual([]);
    expect.soft(blocked, 'Hermetic captures must never contact an external service').toEqual([]);
    expect.soft(errors, 'Flutter/browser errors are qualification failures').toEqual([]);
  });
}
