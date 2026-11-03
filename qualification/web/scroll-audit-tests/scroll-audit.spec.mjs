import { test, expect } from 'playwright/test';
import { auditWithScrollCheckpoints } from '../scroll-audit.mjs';

function findingFor(selector) {
  return {
    violations: [{ id: 'target-size', impact: 'serious', nodes: [{
      target: [selector], html: `<button id="${selector.slice(1)}">fixture</button>`,
      failureSummary: 'Fixture target-size finding',
    }] }],
  };
}

async function installAxe(page) {
  await page.addScriptTag({ path: 'node_modules/axe-core/axe.min.js' });
}

test('a clipped button in a real scroll container passes after its checkpoint', async ({ page }) => {
  await page.setContent(`<!doctype html><html lang="en"><head><title>Fixture</title></head><body><div id="scroll" style="position:absolute;left:20px;top:100px;width:240px;height:100px;overflow-y:auto">
    <div style="position:relative;height:300px"><button id="target" aria-label="scrollable control" style="position:absolute;left:16px;top:80px;width:120px;height:48px">Continue</button></div>
  </div></body></html>`);
  await installAxe(page);
  const outcome = await auditWithScrollCheckpoints(page, findingFor('#target'));
  expect(outcome.checkpoints).toHaveLength(1);
  expect(outcome.checkpoints[0].before.rect.height).toBe(48);
  expect(outcome.checkpoints[0].status).toBe('resolved');
  expect(outcome.checkpoints[0].after.rect.height).toBeGreaterThanOrEqual(24);
  expect(outcome.checkpoints[0].wheelSteps.length).toBeGreaterThan(0);
  expect(outcome.remainingViolations).toEqual([]);
});

test('a genuinely small button remains a failure after scrolling', async ({ page }) => {
  await page.setContent(`<!doctype html><html lang="en"><head><title>Fixture</title></head><body><div id="scroll" style="position:absolute;left:20px;top:100px;width:240px;height:100px;overflow-y:auto">
    <div style="position:relative;height:300px"><button id="target" aria-label="small control" style="position:absolute;left:16px;top:90px;width:18px;height:18px">x</button></div>
  </div></body></html>`);
  await installAxe(page);
  const outcome = await auditWithScrollCheckpoints(page, findingFor('#target'));
  expect(outcome.checkpoints[0].status).toBe('unresolved');
  expect(outcome.checkpoints[0].reason).toContain('below 24x24');
  expect(outcome.remainingViolations).toHaveLength(1);
  expect(outcome.remainingViolations[0].id).toBe('target-size');
});

test('a clipped button without effective scrolling remains a failure', async ({ page }) => {
  await page.setContent(`<!doctype html><html lang="en"><head><title>Fixture</title></head><body><div id="clip" style="position:absolute;left:20px;top:100px;width:240px;height:100px;overflow:hidden">
    <div style="position:relative;height:100px"><button id="target" aria-label="non-scrollable control" style="position:absolute;left:16px;top:90px;width:120px;height:48px">Continue</button></div>
  </div></body></html>`);
  await installAxe(page);
  const outcome = await auditWithScrollCheckpoints(page, findingFor('#target'));
  expect(outcome.checkpoints[0].status).toBe('unresolved');
  expect(outcome.checkpoints[0].reason).toMatch(/no scrollable ancestor|no scroll movement/);
  expect(outcome.remainingViolations).toHaveLength(1);
  expect(outcome.remainingViolations[0].id).toBe('target-size');
});

test('overflow-hidden content with excess scroll extent fails without real wheel movement', async ({ page }) => {
  await page.setContent(`<!doctype html><html lang="en"><head><title>Fixture</title></head><body><div id="clip" style="position:absolute;left:20px;top:100px;width:240px;height:100px;overflow:hidden">
    <div style="position:relative;height:300px"><button id="target" aria-label="hidden overflow control" style="position:absolute;left:16px;top:80px;width:120px;height:48px">Continue</button></div>
  </div></body></html>`);
  await installAxe(page);
  const outcome = await auditWithScrollCheckpoints(page, findingFor('#target'));
  expect(outcome.checkpoints[0].status).toBe('unresolved');
  expect(outcome.checkpoints[0].reason).toContain('no scroll movement');
  expect(outcome.checkpoints[0].wheelSteps).toEqual([]);
  expect(outcome.remainingViolations).toHaveLength(1);
  expect(outcome.remainingViolations[0].id).toBe('target-size');
});

test('a replacement node with the same selector remains a failure', async ({ page }) => {
  await page.setContent(`<!doctype html><html lang="en"><head><title>Fixture</title></head><body><div id="scroll" style="position:absolute;left:20px;top:100px;width:240px;height:100px;overflow-y:auto">
    <div style="position:relative;height:300px"><button id="target" aria-label="replaceable control" style="position:absolute;left:16px;top:80px;width:120px;height:48px">Continue</button></div>
  </div></body></html>`);
  await page.evaluate(() => document.querySelector('#scroll').addEventListener('scroll', () => {
    const oldNode = document.querySelector('#target');
    oldNode.replaceWith(oldNode.cloneNode(true));
  }, { once: true }));
  await installAxe(page);
  const outcome = await auditWithScrollCheckpoints(page, findingFor('#target'));
  expect(outcome.checkpoints[0].status).toBe('unresolved');
  expect(outcome.checkpoints[0].reason).toContain('identity or accessible meaning changed');
  expect(outcome.remainingViolations).toHaveLength(1);
  expect(outcome.remainingViolations[0].id).toBe('target-size');
});

test('a same-id node replaced during the follow-up audit remains a failure', async ({ page }) => {
  await page.setContent(`<!doctype html><html lang="en"><head><title>Fixture</title></head><body><div id="scroll" style="position:absolute;left:20px;top:100px;width:240px;height:100px;overflow-y:auto">
    <div style="position:relative;height:300px"><button id="target" aria-label="delayed replacement" style="position:absolute;left:16px;top:80px;width:120px;height:48px">Continue</button></div>
  </div></body></html>`);
  await installAxe(page);
  await page.evaluate(() => {
    const originalRun = window.axe.run.bind(window.axe);
    window.axe.run = (...args) => originalRun(...args).then(report => new Promise(resolve => requestAnimationFrame(() => {
      const oldNode = document.querySelector('#target');
      if (oldNode) oldNode.replaceWith(oldNode.cloneNode(true));
      resolve(report);
    })));
  });
  const outcome = await auditWithScrollCheckpoints(page, findingFor('#target'));
  expect(outcome.checkpoints[0].status).toBe('unresolved');
  expect(outcome.checkpoints[0].reason).toContain('accessible meaning, or scrollable ancestor changed');
  expect(outcome.remainingViolations).toHaveLength(1);
  expect(outcome.remainingViolations[0].id).toBe('target-size');
});

test('a same node whose accessible meaning changes while scrolling remains a failure', async ({ page }) => {
  await page.setContent(`<!doctype html><html lang="en"><head><title>Fixture</title></head><body><div id="scroll" style="position:absolute;left:20px;top:100px;width:240px;height:100px;overflow-y:auto">
    <div style="position:relative;height:300px"><button id="target" aria-label="original meaning" style="position:absolute;left:16px;top:80px;width:120px;height:48px">Continue</button></div>
  </div></body></html>`);
  await page.evaluate(() => document.querySelector('#scroll').addEventListener('scroll', () => {
    document.querySelector('#target').setAttribute('aria-label', 'different control');
  }, { once: true }));
  await installAxe(page);
  const outcome = await auditWithScrollCheckpoints(page, findingFor('#target'));
  expect(outcome.checkpoints[0].status).toBe('unresolved');
  expect(outcome.checkpoints[0].reason).toContain('identity or accessible meaning changed');
  expect(outcome.remainingViolations).toHaveLength(1);
  expect(outcome.remainingViolations[0].id).toBe('target-size');
});
