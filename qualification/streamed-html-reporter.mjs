// Streamed, bounded-memory replacement for Playwright's built-in HTML reporter.
//
// Why this exists: the built-in HTML reporter (HtmlBuilder in
// playwright/lib/runner/index.js) accumulates every spec file into a single zip
// entry via `JSON.stringify(testFile)`. The qualification matrix concentrates all
// ~2,693 browser cases in two spec files (screens.spec.mjs, detector.spec.mjs),
// each case attaching axe/scroll JSON and failures attaching screenshots and
// traces, so that one string exceeds V8's ~512 MB string limit and the run dies
// with `RangeError: Invalid string length` after the tests finished, losing the
// human-browsable report and forcing a nonzero exit via hasReporterErrors().
//
// This reporter produces the exact same report folder layout (index.html with an
// inlined base64 zip, optional trace viewer assets, and binary attachments under
// data/), but every zip entry is streamed: each spec file's `<fileId>.json` is
// written test-by-test from a Readable (one case stringified at a time, then
// discarded), and the zip bytes are piped through a chunked base64 encoder
// straight into index.html. Peak memory stays proportional to one test result.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { Readable, Transform } from 'node:stream';

const require = createRequire(import.meta.url);
// Bundled inside playwright-core, so no new dependency: yazl writes the zip and
// coreBundle.utils.calculateSha1 names attachment files exactly like the
// built-in reporter.
const coreBundle = require('playwright-core/lib/coreBundle');
const utilsBundle = require('playwright-core/lib/utilsBundle');
const { yazl } = utilsBundle;
const sha1 = (buffer) => coreBundle.utils.calculateSha1(buffer);

const isTextContentType = (contentType) => contentType.startsWith('text/') || contentType.startsWith('application/json');

// Chunked base64 (same encoding as playwright's Base64Encoder): never holds more
// than one chunk's worth of encoded output in memory.
class Base64Encoder extends Transform {
  _transform(chunk, _encoding, callback) {
    if (this._remainder) {
      chunk = Buffer.concat([this._remainder, chunk]);
      this._remainder = undefined;
    }
    const remaining = chunk.length % 3;
    if (remaining) {
      this._remainder = chunk.subarray(chunk.length - remaining);
      chunk = chunk.subarray(0, chunk.length - remaining);
    }
    if (chunk.length) this.push(Buffer.from(chunk.toString('base64')));
    callback();
  }
  _flush(callback) {
    if (this._remainder) this.push(Buffer.from(this._remainder.toString('base64')));
    callback();
  }
}

const emptyStats = () => ({ total: 0, expected: 0, unexpected: 0, flaky: 0, skipped: 0, ok: true });
const addStats = (stats, delta) => {
  stats.total += delta.total;
  stats.skipped += delta.skipped;
  stats.expected += delta.expected;
  stats.unexpected += delta.unexpected;
  stats.flaky += delta.flaky;
  stats.ok = stats.ok && delta.ok;
  return stats;
};
const toPosix = (p) => p.split(path.sep).join('/');

function dedupeSteps(steps) {
  const result = [];
  let lastResult;
  for (const step of steps) {
    const canDedupe = !step.error && step.duration >= 0 && step.location?.file && !step.steps.length;
    const lastStep = lastResult?.step;
    if (canDedupe && lastResult && lastStep && step.category === lastStep.category && step.title === lastStep.title &&
        step.subtitle === lastStep.subtitle && step.location?.file === lastStep.location?.file &&
        step.location?.line === lastStep.location?.line && step.location?.column === lastStep.location?.column) {
      ++lastResult.count;
      lastResult.duration += step.duration;
      continue;
    }
    lastResult = { step, count: 1, duration: step.duration };
    result.push(lastResult);
    if (!canDedupe) lastResult = undefined;
  }
  return result;
}

const stdioAttachment = (chunk, type) => ({ name: type, contentType: 'text/plain', body: typeof chunk === 'string' ? chunk : chunk.toString('utf-8') });
const stripAnsiEscapes = (s) => s.replace(/\x1b\[[0-9;]*m/g, '');

// Streams one spec file's zip entry (`<fileId>.json` = {fileId, fileName, tests}),
// stringifying one test case per pull so no whole-file string ever exists.
class TestFileStream extends Readable {
  constructor(fileId, fileName, tests, builder, projectName) {
    super();
    this._header = `{"fileId":${JSON.stringify(fileId)},"fileName":${JSON.stringify(fileName)},"tests":[`;
    this._tests = tests;
    this._projectName = projectName;
    this._builder = builder;
    this._i = 0;
    this._sentHeader = false;
  }
  _read() {
    if (!this._sentHeader) {
      this._sentHeader = true;
      this.push(this._header);
      return;
    }
    if (this._i < this._tests.length) {
      const test = this._tests[this._i++];
      const titlePath = test.titlePath ? test.titlePath().slice(1) : [];
      const { testCase } = this._builder.createTestEntry(test, this._projectName, titlePath);
      this.push((this._i === 1 ? '' : ',') + JSON.stringify(testCase));
      return;
    }
    this.push(']}');
    this.push(null);
  }
}

export default class StreamedHtmlReporter {
  constructor(options = {}) {
    this._options = options;
    this._healthFile = options.healthFile ? path.resolve(options.healthFile) : null;
    this._topLevelErrors = [];
    this._machines = [];
  }

  version() { return 'v2'; }
  printsToStdio() { return false; }
  onConfigure(config) { this._config = config; }
  onBegin(suite) { this._suite = suite; }
  onError(error) { this._topLevelErrors.push(error); }
  onReportConfigure(params) { (this._reportConfigs ??= new Map()).set(params.reportPath, params.config); }
  onReportEnd(params) {
    const config = this._reportConfigs?.get(params.reportPath);
    if (config) this._machines.push({ config, result: params.result, reportPath: params.reportPath });
  }

  _writeHealth(ok, error) {
    if (!this._healthFile) return;
    try {
      fs.writeFileSync(this._healthFile, JSON.stringify({
        reporter: 'streamed-html', ok,
        error: error ? String(error?.message ?? error) : null,
        at: new Date().toISOString(),
      }));
    } catch { /* health reporting must never mask the real outcome */ }
  }

  async onEnd(result) {
    try {
      const buildResult = await this._build(result);
      this._writeHealth(true, null);
      return buildResult;
    } catch (error) {
      this._writeHealth(false, error);
      throw error;
    }
  }

  async _build(result) {
    const outputFolder = this._options.outputFolder ? path.resolve(this._options.outputFolder) : path.resolve(this._options.configDir ?? process.cwd(), 'playwright-report');
    const attachmentsBaseURL = this._options.attachmentsBaseURL || 'data/';
    fs.rmSync(outputFolder, { recursive: true, force: true });
    fs.mkdirSync(outputFolder, { recursive: true });

    const zip = new yazl.ZipFile();
    const builder = new HtmlBuilder(this._config, outputFolder, attachmentsBaseURL);

    // Collect per-file entries (raw test references + small summaries only).
    const files = [];
    for (const projectSuite of this._suite.suites ?? []) {
      const projectName = projectSuite.project().name;
      for (const fileSuite of projectSuite.suites ?? []) {
        const fileName = builder.relativeLocation(fileSuite.location).file;
        const fileId = sha1(Buffer.from(fileName)).slice(0, 20);
        const tests = [];
        collectTests(fileSuite, tests);
        files.push({ fileId, fileName, projectName, tests, summaryTests: [], stats: emptyStats() });
      }
    }

    // Stream each spec file's zip entry; one test case is stringified per pull.
    for (const file of files) {
      zip.addReadStream(new TestFileStream(file.fileId, file.fileName, file.tests, builder, file.projectName), `${file.fileId}.json`);
    }

    let ok = true;
    for (const file of files) {
      for (const test of file.tests) {
        const outcome = test.outcome();
        if (outcome === 'expected') ++file.stats.expected;
        if (outcome === 'skipped') ++file.stats.skipped;
        if (outcome === 'unexpected') ++file.stats.unexpected;
        if (outcome === 'flaky') ++file.stats.flaky;
        ++file.stats.total;
        file.summaryTests.push(builder.createTestSummary(test, file.projectName));
      }
      file.stats.ok = file.stats.unexpected + file.stats.flaky === 0;
      if (!file.stats.ok) ok = false;
      file.summaryTests.sort((t1, t2) =>
        ((t2.outcome === 'unexpected' ? 1000 : 0) + (t2.outcome === 'flaky' ? 1 : 0)) -
        ((t1.outcome === 'unexpected' ? 1000 : 0) + (t1.outcome === 'flaky' ? 1 : 0)));
    }

    const htmlReport = {
      metadata: { ...(this._config.metadata ?? {}) },
      startTime: result.startTime.getTime(),
      duration: result.duration,
      files: files.map((f) => ({ fileId: f.fileId, fileName: f.fileName, tests: f.summaryTests, stats: f.stats })),
      projectNames: (this._suite.suites ?? []).map((r) => r.project().name),
      stats: { ...files.reduce((a, f) => addStats(a, f.stats), emptyStats()) },
      errors: this._topLevelErrors.map((error) => error?.message ?? String(error)),
      options: { title: this._options.title, noSnippets: this._options.noSnippets, noCopyPrompt: this._options.noCopyPrompt, mergeFiles: this._options.mergeFiles },
      machines: this._machines.map((machine) => ({
        duration: machine.result.duration,
        startTime: machine.result.startTime.getTime(),
        tag: machine.config.tags,
        shardIndex: machine.config.shard?.current,
      })),
    };
    htmlReport.files.sort((f1, f2) => f2.stats.unexpected * 1000 + f2.stats.flaky - (f1.stats.unexpected * 1000 + f1.stats.flaky));
    zip.addBuffer(Buffer.from(JSON.stringify(htmlReport)), 'report.json');

    // index.html with inlined assets, then the base64 zip appended — streamed,
    // so the final string never exists in memory at once.
    const appFolder = path.join(path.dirname(require.resolve('playwright-core/package.json')), 'lib', 'vite', 'htmlReport');
    const indexFile = path.join(outputFolder, 'index.html');
    const html = await fs.promises.readFile(path.join(appFolder, 'index.html'), 'utf-8');
    const js = await fs.promises.readFile(path.join(appFolder, 'report.js'), 'utf-8');
    const css = await fs.promises.readFile(path.join(appFolder, 'report.css'), 'utf-8');
    const inlined = html
      .replace(/<script type="module"[^>]*><\/script>/, () => `<script type="module">${js}</script>`)
      .replace(/<link rel="stylesheet"[^>]*>/, () => `<style type='text/css'>${css}</style>`);
    await fs.promises.writeFile(indexFile, inlined + '<template id="playwrightReportBase64">data:application/zip;base64,');
    await new Promise((resolve, reject) => {
      zip.end(undefined, () => {
        zip.outputStream.pipe(new Base64Encoder()).pipe(fs.createWriteStream(indexFile, { flags: 'a' }))
          .on('close', resolve).on('error', reject);
      });
    });
    await fs.promises.appendFile(indexFile, '</template>');

    if (builder.hasTraces) {
      const traceViewerFolder = path.join(path.dirname(require.resolve('playwright-core/package.json')), 'lib', 'vite', 'traceViewer');
      const target = path.join(outputFolder, 'trace');
      fs.mkdirSync(path.join(target, 'assets'), { recursive: true });
      for (const file of fs.readdirSync(traceViewerFolder)) {
        if (file.endsWith('.map') || file.includes('watch') || file.includes('assets')) continue;
        fs.copyFileSync(path.join(traceViewerFolder, file), path.join(target, file));
      }
      for (const file of fs.readdirSync(path.join(traceViewerFolder, 'assets'))) {
        if (file.endsWith('.map') || file.includes('xtermModule')) continue;
        fs.copyFileSync(path.join(traceViewerFolder, 'assets', file), path.join(target, 'assets', file));
      }
    }
    return { ok };
  }
}

function collectTests(suite, out) {
  for (const entry of suite.entries ? suite.entries() : []) {
    if (entry.type === 'test') out.push(entry);
    else collectTests(entry, out);
  }
}

// Mirrors HtmlBuilder's per-test serialization (runner/index.js), writing binary
// attachment bodies to data/ and referencing them by sha1 file name.
class HtmlBuilder {
  constructor(config, reportFolder, attachmentsBaseURL) {
    this._config = config;
    this._reportFolder = reportFolder;
    this._attachmentsBaseURL = attachmentsBaseURL;
    this.hasTraces = false;
  }

  relativeLocation(location) {
    if (!location) return location;
    return { file: toPosix(path.relative(this._config.rootDir, location.file)), line: location.line, column: location.column };
  }

  createTestEntry(test, projectName, titlePath) {
    const duration = test.results.reduce((a, r) => a + r.duration, 0);
    const location = this.relativeLocation(test.location);
    const pathSegments = (titlePath ?? []).filter((t) => t && t.length > 0);
    const results = test.results.map((r) => this.createTestResult(test, r));
    const outcome = test.outcome();
    return {
      testCase: {
        testId: test.id, title: test.title, projectName, location, duration,
        annotations: test.annotations || [], tags: [...new Set(test.tags || [])],
        outcome, path: pathSegments, results,
        repeatEachIndex: test.repeatEachIndex || undefined,
        ok: outcome === 'expected' || outcome === 'flaky',
      },
      testCaseSummary: this.createTestSummary(test, projectName, location, duration, pathSegments, results, outcome),
    };
  }

  createTestSummary(test, projectName, location = this.relativeLocation(test.location), duration = test.results.reduce((a, r) => a + r.duration, 0), pathSegments = (test.titlePath ? test.titlePath().slice(1) : []).filter((t) => t && t.length > 0), results = test.results.map((r) => this.createTestResult(test, r)), outcome = test.outcome()) {
    return {
      testId: test.id, title: test.title, projectName, location, duration,
      annotations: test.annotations || [], tags: [...new Set(test.tags || [])],
      outcome, path: pathSegments,
      ok: outcome === 'expected' || outcome === 'flaky',
      repeatEachIndex: test.repeatEachIndex || undefined,
      results: results.map((result) => ({
        attachments: result.attachments.map((a) => ({ name: a.name, contentType: a.contentType, path: a.path })),
        startTime: result.startTime,
        workerIndex: result.workerIndex,
      })),
    };
  }

  serializeAttachments(attachments) {
    let lastAttachment;
    return attachments.map((a) => {
      if (a.name === 'trace') this.hasTraces = true;
      if ((a.name === 'stdout' || a.name === 'stderr') && a.contentType === 'text/plain' && typeof a.body === 'string') {
        if (lastAttachment && lastAttachment.name === a.name && lastAttachment.contentType === a.contentType) {
          lastAttachment.body += stripAnsiEscapes(a.body);
          return null;
        }
        a.body = stripAnsiEscapes(a.body);
        lastAttachment = a;
        return a;
      }
      if (a.path) {
        let fileName = a.path;
        try {
          const buffer = fs.readFileSync(a.path);
          const name = sha1(buffer) + path.extname(a.path);
          fileName = this._attachmentsBaseURL + name;
          fs.mkdirSync(path.join(this._reportFolder, 'data'), { recursive: true });
          fs.writeFileSync(path.join(this._reportFolder, 'data', name), buffer);
        } catch { /* keep the original path */ }
        return { name: a.name, contentType: a.contentType, path: fileName, body: a.body };
      }
      if (a.body instanceof Buffer) {
        if (isTextContentType(a.contentType)) {
          const charset = a.contentType.match(/charset=(.*)/)?.[1];
          try {
            return { name: a.name, contentType: a.contentType, body: a.body.toString(charset || 'utf-8') };
          } catch { /* fall through to binary */ }
        }
        fs.mkdirSync(path.join(this._reportFolder, 'data'), { recursive: true });
        const extension = path.extname(a.name || '').replace(/^\./, '') || 'dat';
        const name = sha1(a.body) + '.' + extension;
        fs.writeFileSync(path.join(this._reportFolder, 'data', name), a.body);
        return { name: a.name, contentType: a.contentType, path: this._attachmentsBaseURL + name };
      }
      return { name: a.name, contentType: a.contentType, body: a.body };
    }).filter(Boolean);
  }

  createTestResult(test, result) {
    return {
      duration: result.duration,
      startTime: result.startTime.toISOString(),
      retry: result.retry,
      steps: dedupeSteps(result.steps || []).map((s) => this.createTestStep(s, result)),
      errors: (result.errors || []).map((error) => ({ message: error.message, location: error.location ? this.relativeLocation(error.location) : undefined })),
      status: result.status,
      annotations: result.annotations || [],
      attachments: this.serializeAttachments([
        ...(result.attachments || []),
        ...(result.stdout || []).map((m) => stdioAttachment(m, 'stdout')),
        ...(result.stderr || []).map((m) => stdioAttachment(m, 'stderr')),
      ]),
      workerIndex: result.workerIndex,
    };
  }

  createTestStep(dedupedStep, result) {
    const { step, duration, count } = dedupedStep;
    const skipped = step.annotations?.find((a) => a.type === 'skip');
    let title = step.title;
    if (skipped) title = `${title} (skipped${skipped.description ? `: ${skipped.description}` : ''})`;
    return {
      title,
      subtitle: step.subtitle,
      startTime: step.startTime.toISOString(),
      duration,
      steps: dedupeSteps(step.steps || []).map((s) => this.createTestStep(s, result)),
      attachments: (step.attachments || []).map((s) => {
        const index = (result.attachments || []).indexOf(s);
        if (index === -1) throw new Error('Unexpected, attachment not found');
        return index;
      }),
      location: this.relativeLocation(step.location),
      error: step.error?.message,
      count,
      skipped: !!skipped,
    };
  }
}
