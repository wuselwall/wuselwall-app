// Repository boundary and Pages opt-in regressions; no third-party dependencies.
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { test } from 'node:test';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

test('marketing source and deployment are not app build inputs', () => {
  for (const path of ['website', 'infra/web', 'scripts/remote-web.sh']) {
    assert.equal(existsSync(new URL(`../${path}`, import.meta.url)), false, path);
  }
  const ci = read('.github/workflows/ci.yml');
  assert.doesNotMatch(ci, /^  website:/m);
  assert.doesNotMatch(ci, /website\/package-lock|working-directory: website/);
  const listing = read('scripts/play-listing.mjs');
  assert.doesNotMatch(listing, /website\//);
  assert.ok(existsSync(new URL('../docs/public/logo.svg', import.meta.url)));
});

test('Pages custom domain is built at the root with all four languages retained', () => {
  assert.equal(read('docs/public/CNAME').trim(), 'docs.wuselwall.app');
  const config = read('docs/.vitepress/config.mts');
  assert.match(config, /DOCS_BASE \?\? '\/'/);
  assert.match(config, /hostname: 'https:\/\/docs\.wuselwall\.app'/);
  assert.ok(existsSync(new URL('../docs/index.md', import.meta.url)));
  for (const lang of ['en', 'fr', 'es']) assert.ok(existsSync(new URL(`../docs/${lang}/index.md`, import.meta.url)));
});

test('docs builds are unprivileged; publishing requires main AND explicit opt-in', () => {
  const workflow = read('.github/workflows/docs.yml');
  assert.doesNotMatch(workflow, /DOCS_DEPLOY_|\$\{\{\s*secrets\./);
  assert.match(workflow, /npm_config_cache=\$RUNNER_TEMP\/npm-cache/);
  assert.doesNotMatch(workflow, /cache: npm/);
  assert.match(workflow, /pages: write/);
  assert.match(workflow, /id-token: write/);
  assert.match(workflow, /name: github-pages/);
  const deploy = workflow.split('\n  deploy:\n')[1];
  assert.ok(deploy, 'explicit deploy job');
  const condition = deploy.match(/^    if: (.+)$/m)?.[1];
  assert.equal(condition, "github.ref == 'refs/heads/main' && github.event_name != 'pull_request' && vars.DOCS_PAGES_ENABLED == 'true'");
  assert.match(workflow, /actions\/upload-pages-artifact@[0-9a-f]{40}/);
  assert.match(deploy, /actions\/configure-pages@[0-9a-f]{40}/);
  assert.match(deploy, /actions\/deploy-pages@[0-9a-f]{40}/);
  // Verify the actual condition over PR, non-main, opted-out and opted-in events.
  function allowed(ref, event, enabled) {
    const terms = {
      "github.ref == 'refs/heads/main'": ref === 'refs/heads/main',
      "github.event_name != 'pull_request'": event !== 'pull_request',
      "vars.DOCS_PAGES_ENABLED == 'true'": enabled === 'true',
    };
    return condition.split(' && ').every(term => {
      assert.ok(Object.hasOwn(terms, term));
      return terms[term];
    });
  }
  for (const event of ['push', 'workflow_dispatch', 'pull_request']) {
    for (const ref of ['refs/heads/main', 'refs/heads/feature', 'refs/pull/1/merge']) {
      for (const enabled of ['', 'false', 'true']) {
        assert.equal(allowed(ref, event, enabled), ref === 'refs/heads/main' && event !== 'pull_request' && enabled === 'true');
      }
    }
  }
});

test('every workflow job uses a self-hosted runner, except the deploy a family runs in its fork', () => {
  const dir = new URL('../.github/workflows/', import.meta.url);
  for (const file of readdirSync(dir).filter((name) => /\.ya?ml$/.test(name))) {
    const workflow = readFileSync(new URL(file, dir), 'utf8');
    const runners = [...workflow.matchAll(/^\s+runs-on:\s*(.+)$/gm)];
    assert.ok(runners.length > 0, `${file}: declares job runners`);
    for (const [, runner] of runners) {
      // deploy-supabase.yml runs in a family's fork, which has no runner of its own
      // (docs/server/supabase-cloud): GitHub's runners, free for a public fork.
      if (file === 'deploy-supabase.yml') assert.match(runner, /^ubuntu-latest$/, `${file}: ${runner}`);
      else assert.match(runner, /self-hosted/, `${file}: ${runner}`);
    }
  }
});

test('the reusable backend runner serializes and removes its disposable stack', () => {
  const workflow = read('.github/workflows/backend-ci.yml');
  const backend = workflow.split('\n  backend:\n')[1].split('\n  required:\n')[0];
  assert.match(backend, /group: backend-ci-local-stack/);
  assert.match(backend, /cancel-in-progress: false/);
  // Without a queue, a second pull request's pending backend job cancels the first one's.
  assert.match(backend, /group: backend-ci-local-stack\n\s+cancel-in-progress: false\n\s+queue: max\n/);
  assert.match(backend, /name: Stop the disposable backend\n\s+if: always\(\)/);
  assert.match(backend, /npx --no-install supabase stop --no-backup/);
});
