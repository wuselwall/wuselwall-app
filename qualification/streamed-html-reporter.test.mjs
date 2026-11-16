import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import StreamedHtmlReporter from './streamed-html-reporter.mjs';

function tmp() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'ww-html-report-'));
}

// A minimal fake of the Playwright suite tree, shaped like the full matrix: many
// specs in one file suite, each with axe-style text attachments and, for
// failures, binary screenshot/trace attachments.
function fakeSuite(caseCount, failedCount) {
  const project = { id: 'chromium', name: 'chromium' };
  const specs = [];
  for (let i = 0; i < caseCount; i++) {
    const failed = i < failedCount;
    specs.push({
      type: 'test', title: `case-${i}-de-light-390x844-canonical`, id: `id-${i}`,
      location: { file: '/r/qualification/web/screens.spec.mjs', line: 15, column: 3 },
      tags: ['#a11y'], timeout: 90_000, annotations: [], expectedStatus: 'passed',
      ok: () => !failed, outcome: () => (failed ? 'unexpected' : 'expected'),
      results: [{
        workerIndex: 0, parallelIndex: 0, status: failed ? 'unexpected' : 'expected', duration: 5000,
        errors: failed ? [{ message: 'expect failed', location: { file: '/r/qualification/web/screens.spec.mjs', line: 55, column: 7 } }] : [],
        stdout: [{ text: 'out' }], stderr: [], retry: 0, startTime: new Date(0), annotations: [],
        steps: [{ category: 'test.step', title: 'step', duration: 1, startTime: new Date(0), steps: [], attachments: [] }],
        attachments: [
          { name: 'axe-report', contentType: 'application/json', body: Buffer.from(`{"violations":[],"n":${i}}`) },
          ...(failed ? [
            { name: 'screenshot', contentType: 'image/png', body: Buffer.alloc(150_000, 3) },
            { name: 'trace', contentType: 'application/zip', body: Buffer.alloc(500_000, 9) },
          ] : []),
        ],
      }],
    });
  }
  const fileSuite = { type: 'suite', title: 'screens.spec.mjs', location: { file: '/r/qualification/web/screens.spec.mjs', line: 1, column: 1 }, entries: () => specs, project: () => project };
  return { suites: [{ suites: [fileSuite], project: () => project }] };
}

// Extracts the inlined base64 zip from index.html and returns its entries as
// a Map of name -> Buffer, using the same yauzl bundle the HTML viewer relies on.
async function readInlinedZip(indexFile) {
  const html = fs.readFileSync(indexFile, 'utf8');
  const match = html.match(/<template id="playwrightReportBase64">data:application\/zip;base64,([^<]*)<\/template>/);
  assert.ok(match, 'index.html must carry the inlined base64 zip template');
  const { yauzl } = await import('playwright-core/lib/utilsBundle').then((m) => m.default ?? m);
  const zipBuffer = Buffer.from(match[1], 'base64');
  return await new Promise((resolve, reject) => {
    yauzl.fromBuffer(zipBuffer, { lazyEntries: true }, (err, zipfile) => {
      if (err) return reject(err);
      const entries = new Map();
      zipfile.on('entry', (entry) => {
        if (/\/$/.test(entry.fileName)) { zipfile.readEntry(); return; }
        zipfile.openReadStream(entry, (streamErr, readStream) => {
          if (streamErr) return reject(streamErr);
          const chunks = [];
          readStream.on('data', (c) => chunks.push(c));
          readStream.on('end', () => {
            entries.set(entry.fileName, Buffer.concat(chunks));
            zipfile.readEntry();
          });
        });
      });
      zipfile.on('end', () => resolve(entries));
      zipfile.on('error', reject);
      zipfile.readEntry();
    });
  });
}

test('streamed html reporter writes a viewer-loadable report on a full-matrix-sized run', async (t) => {
  const dir = tmp();
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const out = path.join(dir, 'html');
  const health = path.join(dir, 'health.json');
  const reporter = new StreamedHtmlReporter({ outputFolder: out, healthFile: health });
  reporter.onConfigure({ rootDir: '/r', metadata: { 'playwright-version': '1.65.0' }, projects: [] });
  reporter.onBegin(fakeSuite(2693, 61));
  await reporter.onEnd({ startTime: new Date(0), duration: 5_000_000, status: 'failed' });

  // Health file records success.
  assert.deepEqual(JSON.parse(fs.readFileSync(health, 'utf8')).ok, true);

  const indexFile = path.join(out, 'index.html');
  assert.ok(fs.statSync(indexFile).size > 0, 'index.html written');
  const entries = await readInlinedZip(indexFile);
  const report = JSON.parse(entries.get('report.json').toString('utf8'));
  assert.equal(report.stats.total, 2693);
  assert.equal(report.stats.expected, 2632);
  assert.equal(report.stats.unexpected, 61);
  assert.equal(report.files.length, 1);
  assert.equal(report.files[0].tests.length, 2693);
  // Per-spec entry exists, parses, and keeps case IDs plus failure detail.
  const fileEntry = JSON.parse(entries.get(report.files[0].fileId + '.json').toString('utf8'));
  assert.equal(fileEntry.tests.length, 2693);
  const failed = fileEntry.tests[0];
  assert.equal(failed.testId, 'id-0');
  assert.equal(failed.outcome, 'unexpected');
  assert.equal(failed.results[0].status, 'unexpected');
  const shot = failed.results[0].attachments.find((a) => a.name === 'screenshot');
  assert.ok(shot.path.startsWith('data/'), 'binary attachment referenced under data/');
  // Binary bodies landed on disk under data/ with the referenced names.
  assert.equal(fs.statSync(path.join(out, shot.path)).size, 150_000);
  const trace = failed.results[0].attachments.find((a) => a.name === 'trace');
  assert.equal(fs.statSync(path.join(out, trace.path)).size, 500_000);
  // Trace viewer assets copied because a trace attachment exists.
  assert.ok(fs.existsSync(path.join(out, 'trace', 'index.html')));
  // Text attachments stay inlined in the JSON.
  const axe = failed.results[0].attachments.find((a) => a.name === 'axe-report');
  assert.ok(typeof axe.body === 'string' && axe.body.includes('"n":0'));
});

test('streamed html reporter success path and health failure path', async (t) => {
  const dir = tmp();
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const out = path.join(dir, 'html');
  const health = path.join(dir, 'health.json');
  const reporter = new StreamedHtmlReporter({ outputFolder: out, healthFile: health });
  reporter.onConfigure({ rootDir: '/r', metadata: {}, projects: [] });
  reporter.onBegin(fakeSuite(3, 0));
  const build = await reporter.onEnd({ startTime: new Date(0), duration: 10, status: 'passed' });
  assert.equal(build.ok, true);
  assert.equal(JSON.parse(fs.readFileSync(health, 'utf8')).ok, true);
  const entries = await readInlinedZip(path.join(out, 'index.html'));
  const report = JSON.parse(entries.get('report.json').toString('utf8'));
  assert.equal(report.stats.total, 3);
  assert.equal(report.stats.unexpected, 0);
  assert.ok(!fs.existsSync(path.join(out, 'trace')), 'no trace viewer without traces');

  // A failing build records ok:false with the error and rethrows (the
  // dispatcher then flags the run via hasReporterErrors).
  const blocker = path.join(dir, 'blocker');
  fs.writeFileSync(blocker, 'not a directory');
  const bad = new StreamedHtmlReporter({ outputFolder: path.join(blocker, 'html'), healthFile: health });
  bad.onConfigure({ rootDir: '/r', metadata: {}, projects: [] });
  bad.onBegin(fakeSuite(1, 0));
  await assert.rejects(() => bad.onEnd({ startTime: new Date(0), duration: 1, status: 'passed' }));
  const healthRecord = JSON.parse(fs.readFileSync(health, 'utf8'));
  assert.equal(healthRecord.ok, false);
  assert.ok(healthRecord.error.length > 0);
});

test('reporter without healthFile still works (health reporting is optional)', async (t) => {
  const dir = tmp();
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const reporter = new StreamedHtmlReporter({ outputFolder: path.join(dir, 'html') });
  assert.equal(reporter.printsToStdio(), false);
  assert.equal(reporter.version(), 'v2');
  reporter.onConfigure({ rootDir: '/r', metadata: {}, projects: [] });
  reporter.onBegin(fakeSuite(2, 0));
  await reporter.onEnd({ startTime: new Date(0), duration: 1, status: 'passed' });
  assert.ok(fs.existsSync(path.join(dir, 'html', 'index.html')));
});
