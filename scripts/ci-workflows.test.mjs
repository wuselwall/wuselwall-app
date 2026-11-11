import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import { appWorkflows } from './release.mjs';
const read = file => readFileSync(new URL(`../${file}`, import.meta.url), 'utf8');
const workflow = name => read(`.github/workflows/${name}.yml`);
const job = (source, name) => {
  const body = source.split(`\n  ${name}:\n`)[1]?.split(/\n  [\w-]+:\n/)[0];
  assert.ok(body, `Missing job ${name}`); return body;
};

test('required contexts always report through tested failure-propagating gates', () => {
  for (const [file, name, dependencies, gate] of [
    ['ci', 'app', '[changes, app-checks]', 'app'],
    ['backend-ci', 'required', '[changes, edge-functions, backend]', 'backend'],
  ]) {
    const source = workflow(file); assert.match(source, /^  pull_request:$/m);
    const body = job(source, name);
    assert.ok(body.includes(`needs: ${dependencies}`));
    assert.match(body, /if: always\(\)/);
    assert.match(body, /runs-on: ubuntu-latest/);
    assert.match(body, /run: node scripts\/ci-gate.mjs/);
    assert.ok(body.includes(`GATE: ${gate}`));
    assert.match(body, /NEEDS_JSON: \$\{\{ toJSON\(needs\) \}\}/);
  }
});
test('both workflows use the tested classifier and full reusable/manual/tag runs', () => {
  for (const file of ['ci', 'backend-ci']) {
    const source = workflow(file); assert.match(source, /^  workflow_call:$/m);
    assert.match(source, /full_checks:[\s\S]*?default: true/);
    const changes = job(source, 'changes');
    assert.match(changes, /run: node scripts\/ci-changes.mjs/);
    assert.match(changes, /FULL_CHECKS: \$\{\{ inputs.full_checks \}\}/);
    assert.match(changes, /EVENT_NAME: \$\{\{ github.event_name \}\}/);
    assert.match(changes, /BASE_SHA: \$\{\{ github.event.pull_request.base.sha \}\}/);
    assert.match(changes, /HEAD_SHA: \$\{\{ github.event.pull_request.head.sha \}\}/);
    assert.match(source, /group: \$\{\{ github.workflow \}\}-/);
  }
  assert.match(job(workflow('backend-ci'), 'edge-functions'), /needs.changes.outputs.edge == 'true'/);
  assert.match(job(workflow('backend-ci'), 'backend'), /needs.changes.outputs.backend == 'true'/);
  const app = job(workflow('ci'), 'app-checks');
  assert.match(app, /!inputs.quality_only/);
  assert.match(app, /FLUTTER_TEST_CONCURRENCY: '1'/);
  for (const smoke of ['shopping-quick-add', 'web-server-discovery']) assert.match(app,
    new RegExp(`if: needs.changes.outputs.browser == 'true'\\n\\s+run: node scripts/${smoke}\\.browser\\.mjs`));
});
test('PR documentation is source-only; full images/browser checks precede publication', () => {
  const wrapper = workflow('docs');
  assert.match(wrapper, /uses: \.\/\.github\/workflows\/docs-validation.yml/);
  assert.match(wrapper, /full: \$\{\{ github.event_name != 'pull_request' \}\}/);
  const source = workflow('docs-validation');
  assert.match(source, /permissions:\n  contents: read/);
  assert.doesNotMatch(source, /pages: write|id-token: write|secrets\./);
  assert.match(source, /run: npm run docs:check:source/);
  for (const command of ['docs:screenshots', 'docs:check', 'docs:browser']) assert.match(source,
    new RegExp(`if: inputs.full\\n\\s+run: npm run ${command}(?:\\s|$)`));
  assert.match(source, /if: inputs.publish && inputs.full/);
  assert.doesNotMatch(source, /name: docs-screenshots/);
  assert.match(source, /run: node docs\/tools\/evidence.mjs/);
  assert.match(source, /QUALIFY_CANDIDATE_SHA: '\$\{\{ github.sha \}\}'/);
});
test('exact-commit qualification requires quality, backend and complete guide evidence', () => {
  const source = workflow('qualify-candidate');
  for (const name of ['quality', 'backend', 'docs']) assert.match(job(source, name), /if: inputs.matrix == 'full' && inputs.mode == 'compare'/);
  assert.match(job(source, 'quality'), /uses: \.\/\.github\/workflows\/ci.yml/);
  assert.match(job(source, 'quality'), /quality_only: true/);
  assert.match(job(source, 'backend'), /uses: \.\/\.github\/workflows\/backend-ci.yml/);
  assert.match(job(source, 'docs'), /uses: \.\/\.github\/workflows\/docs-validation.yml/);
  assert.match(job(source, 'docs'), /full: true/);
  assert.match(job(source, 'docs'), /candidate-docs-\$\{\{ github.sha \}\}-\$\{\{ github.run_attempt \}\}/);
  assert.match(job(source, 'evidence'), /needs: \[prepare, review_approval, flutter, web, native, production, quality, backend, docs\]/);
  assert.match(job(source, 'evidence'), /path: build\/qualification\/downloaded\/docs/);
  // Strict candidate Flutter and production checks own the work quality-only reuse skips.
  assert.match(job(source, 'flutter'), /run: flutter test --no-pub --concurrency=1/);
  const production = read('qualification/production-smoke.mjs');
  for (const smoke of ['shopping-quick-add', 'web-server-discovery']) assert.ok(production.includes(`scripts/${smoke}.browser.mjs`));
});

test('reusable validation never persists repository credentials for candidate code', () => {
  for (const file of ['ci', 'backend-ci', 'docs-validation']) {
    const source = workflow(file);
    for (const checkout of source.matchAll(/uses: actions\/checkout@[^\n]+\n(.*(?:\n|$))/g)) {
      assert.match(checkout[1], /persist-credentials: false/, file);
    }
  }
});

test('release orchestration starts signing after preflight instead of duplicate CI', () => {
  assert.deepEqual(appWorkflows, ['release-android.yml', 'release-ios.yml']);
  const release = workflow('release');
  assert.match(job(release, 'plan'), /run: node qualification\/promotion.mjs/);
  assert.match(job(release, 'tag'), /needs: plan/);
});
