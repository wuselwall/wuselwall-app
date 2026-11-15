import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import StreamedJsonReporter from './streamed-json-reporter.mjs';
import { readReportStats } from './report-stats.mjs';

function tmp() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'ww-report-'));
}

// A minimal fake of the Playwright suite tree, shaped like the full matrix:
// many specs, each with one result carrying text and binary attachments.
function fakeSuite(caseCount, failedCount) {
  const project = { id: 'chromium', name: 'chromium', outputDir: '/tmp/o', repeatEach: 1, retries: 0, metadata: {}, testDir: '/r', timeout: 90_000 };
  const specs = [];
  for (let i = 0; i < caseCount; i++) {
    const failed = i < failedCount;
    specs.push({
      type: 'test', title: `case-${i}-de-light-390x844-canonical`, id: `id-${i}`,
      location: { file: '/r/qualification/web/screens.spec.mjs', line: 15, column: 3 },
      tags: [], timeout: 90_000, annotations: [], expectedStatus: 'passed',
      ok: () => !failed, outcome: () => (failed ? 'unexpected' : 'expected'),
      results: [{
        workerIndex: 0, parallelIndex: 0, status: failed ? 'unexpected' : 'expected', duration: 5000,
        error: failed ? { message: 'expect failed', stack: 'Error\n  at x' } : null,
        errors: failed ? [{ message: 'expect failed' }] : [],
        stdout: [{ text: 'out' }], stderr: [], retry: 0, startTime: new Date(0), annotations: [],
        steps: [{ category: 'test.step', title: 'step', duration: 1 }],
        attachments: [
          { name: 'axe-report', contentType: 'application/json', body: Buffer.from(`{"violations":[],"n":${i}}`) },
          ...(failed ? [
            { name: 'screenshot', contentType: 'image/png', path: 'test-failed-1.png', body: Buffer.alloc(150_000, 3) },
            { name: 'trace', contentType: 'application/zip', path: 'trace.zip', body: Buffer.alloc(500_000, 9) },
          ] : []),
        ],
      }],
    });
  }
  const fileSuite = { type: 'suite', title: 'screens.spec.mjs', location: { file: '/r/qualification/web/screens.spec.mjs', line: 1, column: 1 }, entries: () => specs, project: () => project };
  return { suites: [{ suites: [fileSuite], project: () => project }] };
}

test('streamed reporter emits complete valid JSON with bounded memory on a full-matrix-sized report', async (t) => {
  const dir = tmp();
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const out = path.join(dir, 'results.json');
  const reporter = new StreamedJsonReporter({ outputFile: out });
  reporter.onConfigure({ rootDir: '/r', projects: [{ id: 'chromium', name: 'chromium' }] });
  reporter.onBegin(fakeSuite(2693, 61));
  await reporter.onEnd({ startTime: new Date(0), duration: 5_000_000 });

  // The whole document must parse (proof it is valid JSON), while the reporter
  // itself never built a single giant string: binary bodies went to report-data/.
  const parsed = JSON.parse(fs.readFileSync(out, 'utf8'));
  assert.equal(parsed.stats.expected, 2693 - 61);
  assert.equal(parsed.stats.unexpected, 61);
  assert.equal(parsed.stats.skipped, 0);
  assert.equal(parsed.stats.flaky, 0);
  const specs = parsed.suites[0].specs;
  assert.equal(specs.length, 2693);
  // Case IDs and statuses are preserved, failures distinguishable from passes.
  assert.equal(specs[0].tests[0].status, 'unexpected');
  assert.equal(specs[0].tests[0].results[0].attachments.find(a => a.name === 'screenshot').bodyFile.startsWith('report-data/'), true);
  assert.equal(specs[0].tests[0].results[0].attachments.find(a => a.name === 'trace').bodyFile.startsWith('report-data/'), true);
  assert.equal(specs[2692].tests[0].status, 'expected');
  // The referenced binary bodies exist and match the original bytes.
  const shot = parsed.suites[0].specs[0].tests[0].results[0].attachments.find(a => a.name === 'screenshot');
  assert.equal(fs.statSync(path.join(dir, shot.bodyFile)).size, 150_000);
  // readReportStats recovers exactly the stats block from the big file.
  assert.deepEqual(readReportStats(out), parsed.stats);
});

test('streamed reporter handles the success path (zero failures, no attachments on disk beyond axe bodies)', async (t) => {
  const dir = tmp();
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const out = path.join(dir, 'results.json');
  const reporter = new StreamedJsonReporter({ outputFile: out });
  reporter.onConfigure({ rootDir: '/r', projects: [] });
  reporter.onBegin(fakeSuite(3, 0));
  await reporter.onEnd({ startTime: new Date(0), duration: 10 });
  const parsed = JSON.parse(fs.readFileSync(out, 'utf8'));
  assert.equal(parsed.stats.expected, 3);
  assert.equal(parsed.stats.unexpected, 0);
  assert.equal(parsed.suites[0].specs.length, 3);
  assert.deepEqual(readReportStats(out), parsed.stats);
});

test('readReportStats returns null for missing, truncated or stat-less files and never loads the file whole', (t) => {
  const dir = tmp();
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  assert.equal(readReportStats(path.join(dir, 'missing.json')), null);
  const noStats = path.join(dir, 'nostats.json');
  fs.writeFileSync(noStats, '{"suites":[]}');
  assert.equal(readReportStats(noStats), null);
  const truncated = path.join(dir, 'truncated.json');
  fs.writeFileSync(truncated, '{"stats":{"expected":5,'); // cut mid-object
  assert.equal(readReportStats(truncated), null);
  // A report larger than the 64 KiB tail still yields its stats.
  const big = path.join(dir, 'big.json');
  const padding = '"x":"' + 'a'.repeat(4 * 1024 * 1024) + '",';
  fs.writeFileSync(big, '{"suites":[' + padding + '],"errors":[],"stats":{"expected":2632,"skipped":0,"unexpected":61,"flaky":0}}');
  assert.deepEqual(readReportStats(big), { expected: 2632, skipped: 0, unexpected: 61, flaky: 0 });
});

test('reporter requires an outputFile (stdio mode is not used by the qualification runner)', () => {
  const reporter = new StreamedJsonReporter({});
  assert.equal(reporter.printsToStdio(), true);
  assert.equal(reporter.version(), 'v2');
});

test('streamed reporter records health ok:true on success and ok:false with the error on failure', async (t) => {
  const dir = tmp();
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const health = path.join(dir, 'health.json');
  const out = path.join(dir, 'results.json');
  const reporter = new StreamedJsonReporter({ outputFile: out, healthFile: health });
  reporter.onConfigure({ rootDir: '/r', projects: [] });
  reporter.onBegin(fakeSuite(3, 0));
  await reporter.onEnd({ startTime: new Date(0), duration: 10 });
  assert.equal(JSON.parse(fs.readFileSync(health, 'utf8')).ok, true);

  const blocker = path.join(dir, 'blocker');
  fs.writeFileSync(blocker, 'not a directory');
  const bad = new StreamedJsonReporter({ outputFile: path.join(blocker, 'results.json'), healthFile: health });
  bad.onConfigure({ rootDir: '/r', projects: [] });
  bad.onBegin(fakeSuite(1, 0));
  await assert.rejects(() => bad.onEnd({ startTime: new Date(0), duration: 1 }));
  const record = JSON.parse(fs.readFileSync(health, 'utf8'));
  assert.equal(record.ok, false);
  assert.ok(record.error.length > 0);
});
