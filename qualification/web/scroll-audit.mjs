// A viewport checkpoint for axe target-size findings caused by a scroll edge.
// All other axe findings remain in the returned failure set.

const AXE_OPTIONS = {
  runOnly: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'],
  rules: { 'color-contrast': { enabled: false } },
};

export async function runAxe(page) {
  return page.evaluate(options => window.axe.run(document, options), AXE_OPTIONS);
}

function targetSelector(node) {
  // Axe may supply multiple selector fallbacks. We require one stable selector
  // so that the exact same semantics node can be checked after scrolling.
  return node.target?.length === 1 && typeof node.target[0] === 'string' ? node.target[0] : null;
}

async function geometry(page, selector, expected = null) {
  return page.evaluate(({ selector, targetHandle, ancestorHandle, ancestorSelector, meaning: expectedMeaning }) => {
    const matches = [...document.querySelectorAll(selector)];
    if (matches.length !== 1) return { count: matches.length };
    const target = matches[0];
    const identity = (!targetHandle || target.isConnected && target === targetHandle) &&
      (!ancestorHandle || ancestorHandle.isConnected && document.querySelectorAll(ancestorSelector).length === 1 &&
        document.querySelector(ancestorSelector) === ancestorHandle && ancestorHandle.contains(target));
    if (!identity) return { count: 1, identity: false };
    const meaning = {
      tag: target.tagName,
      role: target.getAttribute('role'),
      label: target.getAttribute('aria-label'),
      text: (target.innerText ?? '').replace(/\s+/g, ' ').trim(),
    };
    if (expectedMeaning && Object.keys(meaning).some(key => meaning[key] !== expectedMeaning[key])) {
      return { count: 1, identity: false, meaning };
    }
    const rect = target.getBoundingClientRect();
    const viewport = { left: 0, top: 0, right: innerWidth, bottom: innerHeight };
    const clips = [];
    const scrollables = [];
    let ancestor = target.parentElement;
    while (ancestor) {
      const style = getComputedStyle(ancestor);
      const box = ancestor.getBoundingClientRect();
      const bounds = {
        left: box.left + ancestor.clientLeft,
        top: box.top + ancestor.clientTop,
        right: box.left + ancestor.clientLeft + ancestor.clientWidth,
        bottom: box.top + ancestor.clientTop + ancestor.clientHeight,
      };
      const clipsX = !['visible', 'unset', 'initial'].includes(style.overflowX);
      const clipsY = !['visible', 'unset', 'initial'].includes(style.overflowY);
      const scrollRangeX = ancestor.scrollWidth > ancestor.clientWidth + 1;
      const scrollRangeY = ancestor.scrollHeight > ancestor.clientHeight + 1;
      if (clipsX || clipsY) clips.push({ selector: ancestor.id ? `#${CSS.escape(ancestor.id)}` : null,
        bounds, clipsX, clipsY, overflowX: style.overflowX, overflowY: style.overflowY,
        scrollLeft: ancestor.scrollLeft, scrollTop: ancestor.scrollTop,
        scrollWidth: ancestor.scrollWidth, scrollHeight: ancestor.scrollHeight,
        clientWidth: ancestor.clientWidth, clientHeight: ancestor.clientHeight });
      // Extent and observed scroll offset are evidence candidates. The wheel
      // movement below proves that the ancestor really scrolls; overflow CSS
      // keywords alone are unreliable for Flutter's rebuilt semantics groups.
      const canX = scrollRangeX || ancestor.scrollLeft > 1;
      const canY = scrollRangeY || ancestor.scrollTop > 1;
      if (canX || canY) {
        const selectorForAncestor = ancestor.id ? `#${CSS.escape(ancestor.id)}` : null;
        const edge = scrollRangeY && rect.bottom >= bounds.bottom - 1 && ancestor.scrollTop < ancestor.scrollHeight - ancestor.clientHeight - 1
          ? { axis: 'y', direction: 1, name: 'bottom' }
          : canY && rect.top <= bounds.top + 1 && ancestor.scrollTop > 1
            ? { axis: 'y', direction: -1, name: 'top' }
              : scrollRangeX && rect.right >= bounds.right - 1 && ancestor.scrollLeft < ancestor.scrollWidth - ancestor.clientWidth - 1
              ? { axis: 'x', direction: 1, name: 'right' }
              : canX && rect.left <= bounds.left + 1 && ancestor.scrollLeft > 1
                ? { axis: 'x', direction: -1, name: 'left' }
                : null;
        scrollables.push({ selector: selectorForAncestor, bounds, canX, canY,
          scrollLeft: ancestor.scrollLeft, scrollTop: ancestor.scrollTop,
          scrollWidth: ancestor.scrollWidth, scrollHeight: ancestor.scrollHeight,
          clientWidth: ancestor.clientWidth, clientHeight: ancestor.clientHeight,
          edge, tag: ancestor.tagName, id: ancestor.id });
      }
      ancestor = ancestor.parentElement;
    }
    const intersection = {
      left: Math.max(rect.left, viewport.left), top: Math.max(rect.top, viewport.top),
      right: Math.min(rect.right, viewport.right), bottom: Math.min(rect.bottom, viewport.bottom),
    };
    for (const clip of clips) {
      if (clip.clipsX) {
        intersection.left = Math.max(intersection.left, clip.bounds.left);
        intersection.right = Math.min(intersection.right, clip.bounds.right);
      }
      if (clip.clipsY) {
        intersection.top = Math.max(intersection.top, clip.bounds.top);
        intersection.bottom = Math.min(intersection.bottom, clip.bounds.bottom);
      }
    }
    const edgeCandidate = scrollables.find(item => item.edge && item.selector);
    return {
      count: 1,
      identity: true,
      tag: target.tagName, id: target.id,
      role: target.getAttribute('role'), label: target.getAttribute('aria-label'), text: target.innerText,
      rect: { left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom,
        width: rect.width, height: rect.height },
      viewport, clips, scrollables, intersection,
      candidate: edgeCandidate ?? null,
    };
  }, { selector, targetHandle: expected?.targetHandle ?? null,
    ancestorHandle: expected?.ancestorHandle ?? null, ancestorSelector: expected?.ancestorSelector ?? null,
    meaning: expected?.meaning ?? null });
}

function withinBounds(rect, bounds) {
  return rect.left > bounds.left && rect.top > bounds.top &&
    rect.right < bounds.right && rect.bottom < bounds.bottom;
}

function sameNodeHasTargetSize(audit, selector) {
  return audit.violations.some(violation => violation.id === 'target-size' &&
    violation.nodes.some(node => targetSelector(node) === selector));
}

function auditNodes(audit) {
  return audit.violations.flatMap(violation => violation.nodes.map(node => ({
    id: violation.id, impact: violation.impact, selector: targetSelector(node),
    target: node.target, html: node.html, failureSummary: node.failureSummary,
  })));
}

/**
 * Recheck target-size findings at a real scroll checkpoint. A finding is
 * resolved only after its exact node moves, becomes at least 24x24 CSS pixels,
 * is strictly inside every clipping ancestor and the viewport, and axe no
 * longer reports target-size for that node.
 */
export async function auditWithScrollCheckpoints(page, initialAudit, { maxCheckpoints = 64 } = {}) {
  const checkpoints = [];
  const resolved = new Set();
  const visited = new Set();
  const queue = [];
  const enqueue = audit => {
    for (const node of auditNodes(audit)) {
      if (node.id !== 'target-size' || !node.selector || resolved.has(node.selector) || visited.has(node.selector)) continue;
      visited.add(node.selector);
      queue.push(node);
    }
  };
  enqueue(initialAudit);

  while (queue.length && checkpoints.length < maxCheckpoints) {
    const finding = queue.shift();
    const before = await geometry(page, finding.selector);
    const record = { selector: finding.selector, target: finding.target, axeNode: finding,
      before, status: 'unresolved', reason: null };
    checkpoints.push(record);
    const candidate = before.candidate;
    if (before.count !== 1 || !candidate) {
      record.reason = before.count !== 1 ? 'selector did not resolve to exactly one node' : 'no scrollable ancestor edge explains clipping';
      continue;
    }
    if (!candidate.selector) {
      record.reason = 'scrollable ancestor has no stable unique selector';
      continue;
    }
    const targetHandle = await page.locator(finding.selector).elementHandle();
    const ancestorLocator = page.locator(candidate.selector);
    if (!targetHandle || await ancestorLocator.count() !== 1) {
      record.reason = 'target or scrollable ancestor selector is not uniquely stable';
      continue;
    }
    const ancestorHandle = await ancestorLocator.elementHandle();
    if (!ancestorHandle) {
      record.reason = 'scrollable ancestor handle is missing';
      continue;
    }
    const { edge } = candidate;
    const coordinate = before.intersection;
    if (coordinate.right <= coordinate.left || coordinate.bottom <= coordinate.top) {
      record.reason = 'target has no visible viewport intersection for wheel input';
      continue;
    }
    const mouseX = Math.max(1, Math.min(before.viewport.right - 1, (coordinate.left + coordinate.right) / 2));
    const mouseY = Math.max(1, Math.min(before.viewport.bottom - 1, (coordinate.top + coordinate.bottom) / 2));
    await page.mouse.move(mouseX, mouseY);
    record.wheelSteps = [];
    const viewportSize = edge.axis === 'y'
      ? before.viewport.bottom - before.viewport.top
      : before.viewport.right - before.viewport.left;
    const delta = Math.max(24, Math.min(48, Math.ceil(viewportSize * 0.06)));
    let moved = false;
    for (let step = 0; step < 16; step += 1) {
      const current = await page.locator(candidate.selector).evaluate((element, axis) => axis === 'y' ? element.scrollTop : element.scrollLeft, edge.axis);
      await page.mouse.wheel(edge.axis === 'x' ? edge.direction * delta : 0,
        edge.axis === 'y' ? edge.direction * delta : 0);
      try {
        await page.waitForFunction(({ selector, axis, previous }) => {
          const element = document.querySelector(selector);
          return element && (axis === 'y' ? element.scrollTop : element.scrollLeft) !== previous;
        }, { selector: candidate.selector, axis: edge.axis, previous: current }, { timeout: 1500 });
        moved = true;
      } catch {
        record.reason = 'wheel produced no scroll movement on the qualifying ancestor';
        break;
      }
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const position = await page.locator(candidate.selector).evaluate((element, axis) => axis === 'y' ? element.scrollTop : element.scrollLeft, edge.axis);
      record.wheelSteps.push({ axis: edge.axis, direction: edge.direction, delta, from: current, to: position });
      record.after = await geometry(page, finding.selector, {
        targetHandle, ancestorHandle, ancestorSelector: candidate.selector, meaning: record.before,
      });
      if (record.after.identity === false) {
        record.reason = 'target identity or accessible meaning changed during scrolling';
        break;
      }
      if (record.after.count !== 1) {
        record.reason = 'same selector did not resolve to exactly one node after scrolling';
        break;
      }
      const rect = record.after.rect;
      const currentClipBounds = record.after.clips.map(clip => ({
        left: clip.clipsX ? clip.bounds.left : -Infinity,
        right: clip.clipsX ? clip.bounds.right : Infinity,
        top: clip.clipsY ? clip.bounds.top : -Infinity,
        bottom: clip.clipsY ? clip.bounds.bottom : Infinity,
      }));
      if (withinBounds(rect, record.after.viewport) && currentClipBounds.every(bounds => withinBounds(rect, bounds))) break;
    }
    if (record.reason) continue;
    if (!moved || !record.after) {
      record.reason ??= 'scroll checkpoint did not produce a measurable position';
      continue;
    }
    record.followupAudit = await runAxe(page);
    enqueue(record.followupAudit);
    record.afterAuditGeometry = await geometry(page, finding.selector, {
      targetHandle, ancestorHandle, ancestorSelector: candidate.selector, meaning: record.before,
    });
    if (record.afterAuditGeometry.identity === false) {
      record.reason = 'target identity, accessible meaning, or scrollable ancestor changed during or after the follow-up audit';
      continue;
    }
    if (record.afterAuditGeometry.count !== 1) {
      record.reason = 'same selector did not resolve to exactly one node after the follow-up audit';
      continue;
    }
    const rect = record.afterAuditGeometry.rect;
    if (rect.width < 24 || rect.height < 24) {
      record.reason = `visible target is below 24x24 CSS pixels (${rect.width}x${rect.height})`;
      continue;
    }
    const clippedBounds = record.afterAuditGeometry.clips.map(clip => ({
      left: clip.clipsX ? clip.bounds.left : -Infinity,
      right: clip.clipsX ? clip.bounds.right : Infinity,
      top: clip.clipsY ? clip.bounds.top : -Infinity,
      bottom: clip.clipsY ? clip.bounds.bottom : Infinity,
    }));
    if (!withinBounds(rect, record.afterAuditGeometry.viewport) || clippedBounds.some(bounds => !withinBounds(rect, bounds))) {
      record.reason = 'target rectangle is not strictly inside the viewport and all clipping ancestors';
      continue;
    }
    if (sameNodeHasTargetSize(record.followupAudit, finding.selector)) {
      record.reason = 'axe still reports target-size for the same node after scrolling';
      continue;
    }
    record.status = 'resolved';
    resolved.add(finding.selector);
  }

  if (queue.length) {
    for (const node of queue) checkpoints.push({ selector: node.selector, target: node.target,
      axeNode: node, status: 'unresolved', reason: `checkpoint limit ${maxCheckpoints} reached` });
  }

  const observed = [initialAudit, ...checkpoints.map(checkpoint => checkpoint.followupAudit).filter(Boolean)];
  const merged = new Map();
  for (const audit of observed) {
    for (const node of auditNodes(audit)) {
      if (node.id === 'target-size' && node.selector && resolved.has(node.selector)) continue;
      const key = `${node.id}|${node.selector ?? JSON.stringify(node.target)}`;
      if (!merged.has(key)) merged.set(key, node);
    }
  }
  return {
    initialAudit,
    checkpoints,
    resolved: [...resolved],
    remainingViolations: [...merged.values()],
  };
}
