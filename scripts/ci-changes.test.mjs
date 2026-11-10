import assert from 'node:assert/strict';
import { test } from 'node:test';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { classifyPaths, detectChecks, fullChecks } from './ci-changes.mjs';

const none = { app: false, browser: false, backend: false, edge: false };
const app = { ...none, app: true };
for (const file of ['docs/en/guide/setup.md', 'specs/20-onboarding.md', 'README.md', '.github/pull_request_template.md']) {
  test(`documentation does not start app/database builds: ${file}`, () => assert.deepEqual(classifyPaths([file]), none));
}
for (const file of ['app/lib/features/household/ui/new_family_page.dart', 'app/lib/features/calendar/ui/calendar_page.dart', 'app/lib/demo/demo_repositories.dart', 'app/l10n/app_fr.arb', 'app/assets/picture.png', 'app/test/features/layout_test.dart']) {
  test(`app presentation still gets the full Flutter suite: ${file}`, () => assert.deepEqual(classifyPaths([file]), app));
}
for (const file of ['app/lib/features/shopping/data/shopping_repository.dart', 'app/lib/features/tasks/domain/task.dart', 'app/lib/features/calendar/application/providers.dart', 'app/lib/core/supabase/api_client.dart', 'app/lib/core/cache/read_cache.dart', 'app/lib/core/server/server_info.dart', 'app/test/integration/identity_test.dart', 'app/pubspec.lock', 'app/env/ci.json']) {
  test(`client contract selects backend integration: ${file}`, () => assert.equal(classifyPaths([file]).backend, true));
}
for (const file of ['app/web/index.html', 'app/lib/main.dart', 'app/lib/core/cache/read_cache.dart', 'app/lib/app/bootstrap.dart', 'app/lib/features/setup/ui/server_choice_page.dart', 'app/lib/features/shopping/ui/shopping_page.dart', 'scripts/web-server-discovery.browser.mjs', 'specs/mockups/shopping-quick-add.html']) {
  test(`production browser smoke selects relevant inputs: ${file}`, () => assert.equal(classifyPaths([file]).browser, true));
}
test('migrations run the database; Edge Functions run the database and Deno', () => {
  assert.deepEqual(classifyPaths(['supabase/migrations/change.sql']), { ...none, app: true, backend: true });
  assert.deepEqual(classifyPaths(['supabase/functions/_shared/messages.ts']), { ...none, backend: true, edge: true });
  assert.deepEqual(classifyPaths(['supabase/templates/en/confirmation.html']), { ...none, backend: true, edge: true });
  assert.deepEqual(classifyPaths(['supabase/functions/_shared/fixtures/timetables/expected.json']), { ...none, backend: true, edge: true });
});
test('dependencies, workflow/detector changes and unknown paths run everything', () => {
  for (const file of ['package.json', 'package-lock.json', 'deno.lock', '.github/workflows/docs.yml', 'scripts/ci-changes.mjs', 'scripts/ci-gate.test.mjs', 'new-build-input/config', 'app/lib/core/new_transport/client.dart', 'app/lib/features/new_feature/service/client.dart']) {
    assert.deepEqual(classifyPaths([file]), fullChecks(), file);
  }
});
test('mixed changes accumulate checks; removals and unavailable diffs fail open', () => {
  assert.deepEqual(classifyPaths(['docs/index.md', 'supabase/functions/f/index.ts', 'app/lib/features/tasks/ui/page.dart']), { app: true, browser: false, backend: true, edge: true });
  const sha = 'a'.repeat(40);
  for (const event of ['workflow_dispatch', 'workflow_call', 'push']) assert.deepEqual(detectChecks({ event }), fullChecks());
  assert.deepEqual(detectChecks({ event: 'pull_request', base: sha, head: sha, diff: () => { throw Error('missing commit'); } }), fullChecks());
  assert.deepEqual(detectChecks({ event: 'pull_request', base: 'invalid', head: sha }), fullChecks());
  assert.deepEqual(classifyPaths([]), fullChecks());
});
test('the actual CLI includes both sides of renames and emits only booleans', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'ww-ci-selection-'));
  const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8' }).trim();
  try {
    git('init', '-q'); git('config', 'user.name', 'CI fixture'); git('config', 'user.email', 'ci@example.org');
    mkdirSync(path.join(dir, 'app/lib/features/test/data'), { recursive: true });
    writeFileSync(path.join(dir, 'app/lib/features/test/data/client.dart'), 'fixture\n');
    git('add', '.'); git('commit', '-qm', 'base'); const base = git('rev-parse', 'HEAD');
    mkdirSync(path.join(dir, 'app/lib/features/test/ui'), { recursive: true });
    git('mv', 'app/lib/features/test/data/client.dart', 'app/lib/features/test/ui/client.dart');
    git('commit', '-qm', 'move'); const head = git('rev-parse', 'HEAD');
    const output = path.join(dir, 'output'); writeFileSync(output, '');
    execFileSync(process.execPath, [new URL('./ci-changes.mjs', import.meta.url).pathname], { cwd: dir,
      env: { ...process.env, EVENT_NAME: 'pull_request', BASE_SHA: base, HEAD_SHA: head, GITHUB_OUTPUT: output } });
    assert.match(readFileSync(output, 'utf8'), /^backend=true$/m);
    assert.match(readFileSync(output, 'utf8'), /^(?:\w+=(?:true|false)\n){4}$/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('the Flutter suite covers its external dictionary/SQL inputs too', () => {
  for (const file of ['dictionary/corpus.txt', 'dictionary/shopping.txt', 'supabase/migrations/match_words.sql']) {
    assert.equal(classifyPaths([file]).app, true, file);
  }
  assert.deepEqual(classifyPaths(['app/lib/app/theme/palette.dart']), app);
});

test('reusable PR callers explicitly force full validation despite their inherited event', () => {
  assert.deepEqual(detectChecks({event: 'pull_request', full: true, base: 'a'.repeat(40), head: 'b'.repeat(40), diff: () => 'docs/index.md\0'}), fullChecks());
});

test('unrelated base-branch changes do not turn a docs-only PR into a backend build', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'ww-ci-merge-base-'));
  const git = (...args) => execFileSync('git', args, {cwd: dir, encoding: 'utf8'}).trim();
  try {
    git('init', '-q'); git('config', 'user.name', 'CI fixture'); git('config', 'user.email', 'ci@example.org');
    writeFileSync(path.join(dir, 'README.md'), 'base'); git('add', '.'); git('commit', '-qm', 'ancestor');
    const ancestor = git('rev-parse', 'HEAD');
    mkdirSync(path.join(dir, 'supabase/migrations'), {recursive: true});
    writeFileSync(path.join(dir, 'supabase/migrations/base.sql'), 'select 1;');
    git('add', '.'); git('commit', '-qm', 'base advances'); const base = git('rev-parse', 'HEAD');
    git('checkout', '-qb', 'topic', ancestor);
    mkdirSync(path.join(dir, 'docs')); writeFileSync(path.join(dir, 'docs/index.md'), 'guide');
    git('add', '.'); git('commit', '-qm', 'docs'); const head = git('rev-parse', 'HEAD');
    const output = path.join(dir, 'output'); writeFileSync(output, '');
    execFileSync(process.execPath, [new URL('./ci-changes.mjs', import.meta.url).pathname], {cwd: dir,
      env: {...process.env, EVENT_NAME: 'pull_request', FULL_CHECKS: 'false', BASE_SHA: base, HEAD_SHA: head, GITHUB_OUTPUT: output}});
    for (const key of ['app', 'browser', 'backend', 'edge']) assert.match(readFileSync(output, 'utf8'), new RegExp(`^${key}=false$`, 'm'));
  } finally { rmSync(dir, {recursive: true, force: true}); }
});
