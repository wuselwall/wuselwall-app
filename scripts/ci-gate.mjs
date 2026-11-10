// Preserve required context names while skipping irrelevant work. A missing, failed,
// cancelled or unexpectedly skipped selected job must never become a green aggregate.
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

export function checkGate(needs, gate, qualityOnly = false) {
  assert.equal(needs.changes?.result, 'success', 'Change detection failed');
  const flag = name => {
    const value = needs.changes.outputs?.[name];
    assert.ok(['true', 'false'].includes(value), `Missing selection: ${name}`);
    return value === 'true';
  };
  const work = gate === 'app' ? [['app-checks', [flag('app'), flag('browser')].some(Boolean) && !qualityOnly]]
    : gate === 'backend' ? [['backend', flag('backend')], ['edge-functions', flag('edge')]] : null;
  assert.ok(work, 'Unknown gate');
  for (const [name, selected] of work) {
    const result = needs[name]?.result;
    assert.ok(selected ? result === 'success' : ['success', 'skipped'].includes(result), `${name}: ${result ?? 'missing'} (selected: ${selected})`);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  checkGate(JSON.parse(process.env.NEEDS_JSON), process.env.GATE, process.env.QUALITY_ONLY === 'true');
  console.log(`${process.env.GATE}: every selected check passed`);
}
