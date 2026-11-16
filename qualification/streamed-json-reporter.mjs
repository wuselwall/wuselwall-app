// Streamed, bounded-memory replacement for Playwright's built-in JSON reporter.
//
// Why this exists: the built-in JSON reporter builds the entire report object
// (every attachment of every test base64-encoded in memory) and then calls
// JSON.stringify(report, undefined, 2), producing one string. On the full
// qualification matrix (2,693 browser cases, each attaching axe/scroll JSON and
// failures attaching screenshots and traces) that single string exceeds V8's
// ~512 MB string limit and the run dies with `RangeError: Invalid string length`
// after the tests finished, losing results.json and therefore evidence.json.
//
// This reporter writes the same Playwright v2 JSON document incrementally with a
// write stream, so peak memory stays proportional to one test result. Binary
// attachment bodies are written to a sibling `report-data/` directory and
// referenced by `bodyFile`; text attachments keep `body`. `stats` keeps the exact
// built-in semantics (expected/skipped/unexpected/flaky counted from outcomes).
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const sha1 = (buffer) => crypto.createHash('sha1').update(buffer).digest('hex');

export default class StreamedJsonReporter {
  constructor(options = {}) {
    this._outputFile = options.outputFile ? path.resolve(options.outputFile) : null;
    this._healthFile = options.healthFile ? path.resolve(options.healthFile) : null;
    this._errors = [];
  }

  version() { return 'v2'; }
  printsToStdio() { return !this._outputFile; }
  onConfigure(config) { this._config = config; }
  onBegin(suite) { this._suite = suite; }
  onError(error) { this._errors.push(error); }

  _writeHealth(ok, error) {
    if (!this._healthFile) return;
    try {
      fs.writeFileSync(this._healthFile, JSON.stringify({
        reporter: 'streamed-json', ok,
        error: error ? String(error?.message ?? error) : null,
        at: new Date().toISOString(),
      }));
    } catch { /* health reporting must never mask the real outcome */ }
  }

  async onEnd(result) {
    try {
      await this._write(result);
      this._writeHealth(true, null);
    } catch (error) {
      this._writeHealth(false, error);
      throw error;
    }
  }

  async _write(result) {
    if (!this._outputFile) throw new Error('StreamedJsonReporter requires an outputFile');
    const dir = path.dirname(this._outputFile);
    fs.rmSync(path.join(dir, 'report-data'), { recursive: true, force: true });
    fs.mkdirSync(path.join(dir, 'report-data'), { recursive: true });
    const stream = fs.createWriteStream(this._outputFile);
    const write = (chunk) => new Promise((resolve, reject) => {
      stream.write(chunk, (err) => (err ? reject(err) : resolve()));
    });

    const stats = { startTime: result.startTime.toISOString(), duration: result.duration, expected: 0, skipped: 0, unexpected: 0, flaky: 0 };
    const bump = (outcome) => { stats[outcome] = (stats[outcome] || 0) + 1; };

    await write('{\n"config":');
    await write(JSON.stringify(this._config ? {
      rootDir: this._config.rootDir,
      projects: (this._config.projects || []).map((p) => ({ id: p.id, name: p.name, outputDir: p.outputDir, repeatEach: p.repeatEach, retries: p.retries, metadata: p.metadata, testDir: p.testDir, timeout: p.timeout })),
    } : {}));
    await write(',\n"suites":[');

    let fileFirst = true;
    const serializeAttachments = (attachments) => (attachments || []).map((a) => {
      if (a.body instanceof Buffer) {
        const name = sha1(a.body) + (path.extname(a.name || '') || '.bin');
        fs.writeFileSync(path.join(dir, 'report-data', name), a.body);
        return { name: a.name, contentType: a.contentType, bodyFile: `report-data/${name}` };
      }
      return { name: a.name, contentType: a.contentType, path: a.path, body: typeof a.body === 'string' ? a.body : a.body?.toString('base64') };
    });

    for (const projectSuite of this._suite.suites || []) {
      const project = projectSuite.project?.() || {};
      for (const fileSuite of projectSuite.suites || []) {
        const tests = (fileSuite.entries ? fileSuite.entries() : []).filter((e) => e.type === 'test');
        if (!tests.length) continue;
        if (!fileFirst) await write(',');
        fileFirst = false;
        await write('\n{"title":' + JSON.stringify(fileSuite.title) + ',"file":' + JSON.stringify(fileSuite.location?.file ?? '') +
          ',"line":' + (fileSuite.location?.line ?? 0) + ',"column":' + (fileSuite.location?.column ?? 0) + ',"specs":[');
        let specFirst = true;
        for (const test of tests) {
          if (!specFirst) await write(',');
          specFirst = false;
          bump(test.outcome());
          await write('\n{"title":' + JSON.stringify(test.title) + ',"ok":' + test.ok() + ',"tags":' + JSON.stringify((test.tags || []).map((t) => t.substring(1))) +
            ',"id":' + JSON.stringify(test.id) + ',"file":' + JSON.stringify(test.location?.file ?? '') + ',"line":' + (test.location?.line ?? 0) + ',"column":' + (test.location?.column ?? 0) + ',"tests":[{' +
            '"timeout":' + (test.timeout ?? 0) + ',"annotations":' + JSON.stringify(test.annotations || []) + ',"expectedStatus":' + JSON.stringify(test.expectedStatus) +
            ',"projectId":' + JSON.stringify(project.id ?? project.name ?? '') + ',"projectName":' + JSON.stringify(project.name ?? '') + ',"status":' + JSON.stringify(test.outcome()) + ',"results":[');
          let resFirst = true;
          for (const r of test.results || []) {
            if (!resFirst) await write(',');
            resFirst = false;
            const jsonResult = {
              workerIndex: r.workerIndex, parallelIndex: r.parallelIndex, status: r.status, duration: r.duration,
              error: r.error ?? null, errors: r.errors || [], stdout: r.stdout || [], stderr: r.stderr || [], retry: r.retry,
              startTime: r.startTime.toISOString(), annotations: r.annotations || [],
              steps: (r.steps || []).filter((s) => s.category === 'test.step'),
              attachments: serializeAttachments(r.attachments),
            };
            await write('\n' + JSON.stringify(jsonResult));
          }
          await write(']}]}');
        }
        await write(']}');
      }
    }

    await write('\n],"errors":' + JSON.stringify(this._errors) + ',\n"stats":' + JSON.stringify(stats) + '}\n');
    await new Promise((resolve, reject) => stream.end((err) => (err ? reject(err) : resolve())));
  }
}
