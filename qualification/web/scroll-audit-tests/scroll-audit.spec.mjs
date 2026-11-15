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

// Flutter's shape: the row sits in a group as wide as the list, and while the row is cut by
// the list's edge the group is a box smaller than its content that no wheel moves.
const wrappedRow = (rowStyle) => `<!doctype html><html lang="en"><head><title>Fixture</title></head><body><div id="scroll" style="position:absolute;left:20px;top:100px;width:240px;height:100px;overflow-y:auto;overflow-x:hidden">
    <div style="position:relative;height:300px"><div id="group" style="position:absolute;left:0;top:90px;width:240px;height:10px;overflow:hidden">
      <button id="target" aria-label="row" style="position:absolute;top:0;height:48px;border:0;padding:0;${rowStyle}">Row</button></div></div>
  </div></body></html>`;
const growGroupOnScroll = page => page.evaluate(() => document.querySelector('#scroll').addEventListener('scroll', () => {
  // Once the row is whole, Flutter's group has the row's size and clips nothing.
  Object.assign(document.querySelector('#group').style, { height: '48px', overflow: 'visible' });
}));

test('a row as wide as its list passes once the ancestor that really scrolls moved it into view', async ({ page }) => {
  await page.setContent(wrappedRow('left:0;width:240px'));
  await growGroupOnScroll(page);
  await installAxe(page);
  const outcome = await auditWithScrollCheckpoints(page, findingFor('#target'));
  expect(outcome.checkpoints[0].skippedAncestors).toEqual([{ selector: '#group', reason: 'wheel produced no scroll movement' }]);
  expect(outcome.checkpoints[0].qualifyingAncestor).toBe('#scroll');
  expect(outcome.checkpoints[0].status).toBe('resolved');
  expect(outcome.remainingViolations).toEqual([]);
});

test('a row cut across the scrolled axis remains a failure', async ({ page }) => {
  await page.setContent(wrappedRow('left:0;width:300px'));
  await growGroupOnScroll(page);
  await installAxe(page);
  const outcome = await auditWithScrollCheckpoints(page, findingFor('#target'));
  expect(outcome.checkpoints[0].status).toBe('unresolved');
  // It never comes to lie inside the list, so the wheel runs to the list's end.
  expect(outcome.checkpoints[0].reason).toMatch(/not strictly inside|no scroll movement/);
  expect(outcome.remainingViolations).toHaveLength(1);
});

test('a sideways list whose engine reports its position as scrollTop passes when the node comes into view', async ({ page }) => {
  // Flutter's shape for a horizontal scroller: the wheel is handled by the app, which moves
  // the node and writes the new position into scrollTop.
  await page.setContent(`<!doctype html><html lang="en"><head><title>Fixture</title></head><body><div id="scroll" style="position:absolute;left:20px;top:100px;width:240px;height:100px;overflow-x:scroll;overflow-y:auto">
    <div style="position:absolute;left:0;top:0;width:600px;height:400px;pointer-events:none"></div>
    <button id="target" aria-label="cell" style="position:absolute;left:230px;top:20px;width:60px;height:48px;border:0;padding:0">Cell</button>
  </div></body></html>`);
  await page.evaluate(() => {
    const scroll = document.querySelector('#scroll');
    const target = document.querySelector('#target');
    let position = 0;
    scroll.addEventListener('wheel', event => {
      event.preventDefault();
      position += event.deltaX;
      target.style.left = `${230 - position}px`;
      target.style.top = `${20 + position}px`;
      scroll.scrollTop = position;
    }, { passive: false });
  });
  await installAxe(page);
  const outcome = await auditWithScrollCheckpoints(page, findingFor('#target'));
  expect(outcome.checkpoints[0].before.candidate.edge.axis).toBe('x');
  expect(outcome.checkpoints[0].status).toBe('resolved');
  expect(outcome.remainingViolations).toEqual([]);
});

// Flutter's shape after the audit's pointer opened and lost a tooltip: the anchor keeps an
// aria-owns reference to the overlay node that is gone.
const tooltipAnchor = owns => `<!doctype html><html lang="en"><head><title>Fixture</title></head><body><div id="scroll" style="position:absolute;left:20px;top:100px;width:240px;height:100px;overflow-y:auto">
    <div style="position:relative;height:300px"><flt-semantics id="target" role="button" tabindex="0" aria-label="cell" ${owns} style="position:absolute;left:16px;top:80px;width:120px;height:48px"></flt-semantics></div>
  </div></body></html>`;

test('a reference the pointer left on a node during scrolling is removed and recorded', async ({ page }) => {
  await page.setContent(tooltipAnchor(''));
  await page.evaluate(() => document.querySelector('#scroll').addEventListener('scroll', () => {
    document.querySelector('#target').setAttribute('aria-owns', 'flt-semantic-node-gone');
  }, { once: true }));
  await installAxe(page);
  const outcome = await auditWithScrollCheckpoints(page, findingFor('#target'));
  expect(outcome.checkpoints[0].pointerTraces).toEqual([{ selector: '#target', removed: ['flt-semantic-node-gone'] }]);
  expect(outcome.checkpoints[0].status).toBe('resolved');
  expect(outcome.remainingViolations).toEqual([]);
});

test('a reference to a missing node that the screen had before scrolling remains a failure', async ({ page }) => {
  await page.setContent(tooltipAnchor('aria-owns="flt-semantic-node-gone"'));
  await installAxe(page);
  const outcome = await auditWithScrollCheckpoints(page, findingFor('#target'));
  expect(outcome.checkpoints[0].pointerTraces).toEqual([]);
  expect(outcome.remainingViolations.map(v => v.id)).toContain('aria-valid-attr-value');
});

test('a second node the first checkpoint scrolled into view passes only as the same, whole node', async ({ page }) => {
  await page.setContent(`<!doctype html><html lang="en"><head><title>Fixture</title></head><body><div id="scroll" style="position:absolute;left:20px;top:100px;width:300px;height:100px;overflow-y:auto">
    <div style="position:relative;height:130px">
      <button id="first" aria-label="first cell" style="position:absolute;left:16px;top:80px;width:120px;height:48px">One</button>
      <button id="second" aria-label="second cell" style="position:absolute;left:160px;top:80px;width:120px;height:48px">Two</button>
      <button id="small" aria-label="small cell" style="position:absolute;left:284px;top:80px;width:12px;height:48px;padding:0">x</button></div>
  </div></body></html>`);
  await installAxe(page);
  const node = id => ({ target: [`#${id}`], html: `<button id="${id}">fixture</button>`, failureSummary: 'Fixture target-size finding' });
  const outcome = await auditWithScrollCheckpoints(page, { violations: [{ id: 'target-size', impact: 'serious',
    nodes: [node('first'), node('second'), node('small')] }] });
  const [first, second, small] = outcome.checkpoints;
  expect(first.status).toBe('resolved');
  expect(first.wheelSteps.length).toBeGreaterThan(0);
  // The list is at its end: nothing is left to scroll for the other two.
  expect(second.status).toBe('resolved');
  expect(second.resolvedBy).toContain('earlier checkpoint');
  expect(small.status).toBe('unresolved');
  expect(outcome.remainingViolations.map(v => v.selector)).toEqual(['#small']);
});
