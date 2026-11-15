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
      // A sideways Flutter scroller never reports its position (see the note on the engine
      // below), so a node at its left edge may be cut by it at any reported offset.
      const sideways = ancestor.querySelector(':scope > flt-semantics-scroll-overflow')?.style.height === '1px';
      const canX = scrollRangeX || ancestor.scrollLeft > 1 || sideways;
      const canY = scrollRangeY || ancestor.scrollTop > 1;
      if (canX || canY) {
        const selectorForAncestor = ancestor.id ? `#${CSS.escape(ancestor.id)}` : null;
        const edge = scrollRangeY && rect.bottom >= bounds.bottom - 1 && ancestor.scrollTop < ancestor.scrollHeight - ancestor.clientHeight - 1
          ? { axis: 'y', direction: 1, name: 'bottom' }
          : canY && rect.top <= bounds.top + 1 && ancestor.scrollTop > 1
            ? { axis: 'y', direction: -1, name: 'top' }
              : scrollRangeX && rect.right >= bounds.right - 1 && ancestor.scrollLeft < ancestor.scrollWidth - ancestor.clientWidth - 1
              ? { axis: 'x', direction: 1, name: 'right' }
              : canX && rect.left <= bounds.left + 1 && (ancestor.scrollLeft > 1 || sideways)
                ? { axis: 'x', direction: -1, name: 'left' }
                : null;
        scrollables.push({ selector: selectorForAncestor, bounds, canX, canY,
          scrollLeft: ancestor.scrollLeft, scrollTop: ancestor.scrollTop,
          scrollWidth: ancestor.scrollWidth, scrollHeight: ancestor.scrollHeight,
          clientWidth: ancestor.clientWidth, clientHeight: ancestor.clientHeight,
          edge, sideways, tag: ancestor.tagName, id: ancestor.id });
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
      candidates: scrollables.filter(item => item.edge && item.selector),
    };
  }, { selector, targetHandle: expected?.targetHandle ?? null,
    ancestorHandle: expected?.ancestorHandle ?? null, ancestorSelector: expected?.ancestorSelector ?? null,
    meaning: expected?.meaning ?? null });
}

function wheelDelta(edge, viewport) {
  const size = edge.axis === 'y' ? viewport.bottom - viewport.top : viewport.right - viewport.left;
  return Math.max(24, Math.min(48, Math.ceil(size * 0.06)));
}

const scrollOffset = (page, selector) => page.locator(selector).evaluate(element => [element.scrollLeft, element.scrollTop]);

// Flutter's web engine writes the position of a horizontal scroller into scrollTop
// (engine/semantics/scrollable.dart sets `element.scrollTop = scrollPosition` for both axes;
// flutter/flutter#195469 mentions it) and never into scrollLeft. Where the scroller's box is
// shorter than its content the browser then shifts every child up by the sideways position,
// although Flutter already placed them where they are painted. This puts scrollTop of every
// such scroller back to 0, so that rectangles and axe see the nodes where the app paints them.
// Only a Flutter semantics node the engine marks as scrolling sideways (an extent element one
// pixel high) and whose scrollLeft is 0 is touched. The engine writes again with every update
// of the node, and the update that follows the end of a scroll comes some frames later, so
// this waits until the values have stayed put for 400 ms. A page without such a scroller
// returns at once.
async function undoSidewaysPositionsOnTheWrongAxis(page) {
  return page.evaluate(async () => {
    const frame = () => new Promise(resolve => requestAnimationFrame(resolve));
    const sideways = () => [...document.querySelectorAll('flt-semantics > flt-semantics-scroll-overflow')]
      .filter(extent => extent.style.height === '1px').map(extent => extent.parentElement)
      .filter(element => element.scrollLeft === 0);
    let corrected = 0;
    if (!sideways().length) return corrected;
    for (let quiet = 0, tries = 0; quiet < 24 && tries < 240; tries += 1) {
      const shifted = sideways().filter(element => element.scrollTop !== 0);
      for (const element of shifted) element.scrollTop = 0;
      corrected += shifted.length;
      quiet = shifted.length ? 0 : quiet + 1;
      await frame();
    }
    return corrected;
  });
}

// One wheel step towards the ancestor's edge; true when the ancestor really scrolled: its own
// scroll offset moved, or, for a sideways Flutter scroller whose offset the engine does not
// report (see above), the reported node itself moved along the wheel's axis. That the node
// ends up whole is checked from its own rectangle afterwards, never from this movement.
async function wheelMoves(page, ancestor, viewport, target) {
  const { edge, selector } = ancestor;
  const delta = wheelDelta(edge, viewport);
  const previous = await page.evaluate(({ selector, target }) => {
    const element = document.querySelector(selector);
    return { offset: [element.scrollLeft, element.scrollTop], left: document.querySelector(target).getBoundingClientRect().left };
  }, { selector, target });
  await page.mouse.wheel(edge.axis === 'x' ? edge.direction * delta : 0, edge.axis === 'y' ? edge.direction * delta : 0);
  let moved = true;
  try {
    await page.waitForFunction(({ selector, target, previous, sideways }) => {
      const element = document.querySelector(selector);
      const node = document.querySelector(target);
      if (!element || !node) return false;
      return element.scrollLeft !== previous.offset[0] || element.scrollTop !== previous.offset[1] ||
        sideways && Math.abs(node.getBoundingClientRect().left - previous.left) >= 1;
    }, { selector, target, previous, sideways: edge.axis === 'x' && ancestor.sideways }, { timeout: 1500 });
  } catch {
    moved = false;
  }
  await undoSidewaysPositionsOnTheWrongAxis(page);
  return moved;
}

const ownsBefore = page => page.evaluate(() => Object.fromEntries(
  [...document.querySelectorAll('[aria-owns][id]')].map(element => [element.id, element.getAttribute('aria-owns')])));

// The wheel needs the pointer over the list, and a pointer over a node with a tooltip opens
// the tooltip. Flutter's web engine links the tooltip's overlay node to its anchor with
// aria-owns and does not take the reference back when the overlay node is removed
// (engine/semantics/semantics.dart, _updateTraversalParent cleans up only a node that stays).
// That reference is a trace of this audit's own pointer, not of the screen it audits: it is
// removed before the next axe run and listed in the record. Only a reference to a node that
// no longer exists, and that the element did not have before the first wheel step, is
// removed; one that was there when the screen was first audited stays a finding.
async function dropOverlayReferencesLeftByThePointer(page, before) {
  return page.evaluate(before => {
    const dropped = [];
    for (const element of document.querySelectorAll('flt-semantics[aria-owns][id]')) {
      const had = new Set((before[element.id] ?? '').split(' ').filter(Boolean));
      const tokens = element.getAttribute('aria-owns').split(' ').filter(Boolean);
      const kept = tokens.filter(token => had.has(token) || document.getElementById(token));
      if (kept.length === tokens.length) continue;
      dropped.push({ selector: `#${element.id}`, removed: tokens.filter(token => !kept.includes(token)) });
      if (kept.length) element.setAttribute('aria-owns', kept.join(' '));
      else element.removeAttribute('aria-owns');
    }
    return dropped;
  }, before);
}

// Flutter reports a node's rectangle already cut by its scroller, so a node that still touches
// the scroller's edge along the scrolled axis may still be cut: there it must be strictly
// inside. Across that axis scrolling changes nothing, and a row as wide as its list touches
// both sides without being cut: there it must only not reach outside.
function withinBounds(rect, bounds, axis) {
  const along = axis === 'y'
    ? rect.top > bounds.top && rect.bottom < bounds.bottom
    : rect.left > bounds.left && rect.right < bounds.right;
  const across = axis === 'y'
    ? rect.left >= bounds.left && rect.right <= bounds.right
    : rect.top >= bounds.top && rect.bottom <= bounds.bottom;
  return along && across;
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
  // Each finding keeps the node and its meaning as they were when axe reported it, so that
  // a later look at the same selector is proven to be a look at the same node.
  const enqueue = async audit => {
    for (const node of auditNodes(audit)) {
      if (node.id !== 'target-size' || !node.selector || resolved.has(node.selector) || visited.has(node.selector)) continue;
      visited.add(node.selector);
      const locator = page.locator(node.selector);
      const reportedHandle = await locator.count() === 1 ? await locator.elementHandle() : null;
      queue.push({ ...node, reportedHandle, reported: reportedHandle ? await geometry(page, node.selector) : null });
    }
  };
  await enqueue(initialAudit);
  let scrolled = false;
  const owns = await ownsBefore(page);

  while (queue.length && checkpoints.length < maxCheckpoints) {
    const finding = queue.shift();
    const { reportedHandle, reported, ...axeNode } = finding;
    await undoSidewaysPositionsOnTheWrongAxis(page);
    const before = await geometry(page, finding.selector, reportedHandle && reported?.count === 1
      ? { targetHandle: reportedHandle, meaning: reported } : null);
    const record = { selector: finding.selector, target: finding.target, axeNode,
      before, status: 'unresolved', reason: null };
    checkpoints.push(record);
    if (before.count === 1 && before.identity === false) {
      record.reason = 'target identity or accessible meaning changed since axe reported it';
      continue;
    }
    // An earlier checkpoint's scroll may have brought this node into view with the one it
    // was scrolling for (the cells of one column). It is the node axe reported (handle and
    // meaning above); it counts only if it is whole now and axe no longer reports it. Asked
    // only where no ancestor has anything left to scroll towards the node's edge.
    const wholeSinceAnEarlierScroll = async () => {
      if (before.count !== 1 || !scrolled || !reportedHandle) return false;
      const rect = before.rect;
      const bounds = [before.viewport, ...before.clips.map(clip => ({
        left: clip.clipsX ? clip.bounds.left : -Infinity, right: clip.clipsX ? clip.bounds.right : Infinity,
        top: clip.clipsY ? clip.bounds.top : -Infinity, bottom: clip.clipsY ? clip.bounds.bottom : Infinity,
      }))];
      if (rect.width < 24 || rect.height < 24 || !bounds.every(b =>
        rect.left >= b.left && rect.right <= b.right && rect.top >= b.top && rect.bottom <= b.bottom)) return false;
      record.pointerTraces = await dropOverlayReferencesLeftByThePointer(page, owns);
      record.followupAudit = await runAxe(page);
      await enqueue(record.followupAudit);
      if (sameNodeHasTargetSize(record.followupAudit, finding.selector)) return false;
      record.status = 'resolved';
      record.reason = null;
      record.resolvedBy = 'an earlier checkpoint scrolled the same node into view';
      resolved.add(finding.selector);
      return true;
    };
    if (!before.candidate && await wholeSinceAnEarlierScroll()) continue;
    if (before.count !== 1 || !before.candidate) {
      record.reason = before.count !== 1 ? 'selector did not resolve to exactly one node' : 'no scrollable ancestor edge explains clipping';
      continue;
    }
    const coordinate = before.intersection;
    if (coordinate.right <= coordinate.left || coordinate.bottom <= coordinate.top) {
      record.reason = 'target has no visible viewport intersection for wheel input';
      continue;
    }
    const mouseX = Math.max(1, Math.min(before.viewport.right - 1, (coordinate.left + coordinate.right) / 2));
    const mouseY = Math.max(1, Math.min(before.viewport.bottom - 1, (coordinate.top + coordinate.bottom) / 2));
    await page.mouse.move(mouseX, mouseY);
    // Flutter wraps a clipped node in groups whose content is larger than their box without
    // being scrollers. The qualifying ancestor is the innermost one a wheel really moves;
    // the ones tried in vain stay in the record.
    // Both handles are taken before the first wheel step, so that the node measured after
    // scrolling is proven to be the one axe reported.
    const targetHandle = reportedHandle ?? await page.locator(finding.selector).elementHandle();
    if (!targetHandle) {
      record.reason = 'target selector is not uniquely stable';
      continue;
    }
    record.skippedAncestors = [];
    record.wheelSteps = [];
    let candidate = null;
    let ancestorHandle = null;
    for (const option of before.candidates) {
      const locator = page.locator(option.selector);
      const handle = await locator.count() === 1 ? await locator.elementHandle() : null;
      if (!handle) {
        record.skippedAncestors.push({ selector: option.selector, reason: 'selector is not unique' });
        continue;
      }
      if (await wheelMoves(page, option, before.viewport, finding.selector)) {
        candidate = option;
        ancestorHandle = handle;
        break;
      }
      record.skippedAncestors.push({ selector: option.selector, reason: 'wheel produced no scroll movement' });
    }
    if (!candidate) {
      if (await wholeSinceAnEarlierScroll()) continue;
      record.reason = 'wheel produced no scroll movement on any ancestor with a scroll edge';
      continue;
    }
    const { edge } = candidate;
    scrolled = true;
    record.qualifyingAncestor = candidate.selector;
    const delta = wheelDelta(edge, before.viewport);
    // The search above already moved this ancestor by one step.
    let moved = true;
    for (let step = 0; step < 16; step += 1) {
      const current = await scrollOffset(page, candidate.selector);
      if (step > 0 && !await wheelMoves(page, candidate, before.viewport, finding.selector)) {
        record.reason = 'wheel produced no scroll movement on the qualifying ancestor';
        break;
      }
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const position = await scrollOffset(page, candidate.selector);
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
      if (withinBounds(rect, record.after.viewport, edge.axis) && currentClipBounds.every(bounds => withinBounds(rect, bounds, edge.axis))) break;
    }
    if (record.reason) continue;
    if (!moved || !record.after) {
      record.reason ??= 'scroll checkpoint did not produce a measurable position';
      continue;
    }
    await undoSidewaysPositionsOnTheWrongAxis(page);
    record.pointerTraces = await dropOverlayReferencesLeftByThePointer(page, owns);
    record.followupAudit = await runAxe(page);
    await enqueue(record.followupAudit);
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
    if (!withinBounds(rect, record.afterAuditGeometry.viewport, edge.axis) || clippedBounds.some(bounds => !withinBounds(rect, bounds, edge.axis))) {
      record.reason = 'target rectangle is not strictly inside the viewport and all clipping ancestors along the scrolled axis, or reaches outside them across it';
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
