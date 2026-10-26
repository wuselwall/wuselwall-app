// The Edge Functions called without a user JWT are named in two places that must agree:
// supabase/config.toml ([functions.<name>] verify_jwt = false, read by `supabase functions
// deploy` and so by a hosted project's gateway) and the compose stack's router
// (NO_USER_FUNCTIONS in infra/supabase/volumes/functions/main/index.ts). A name missing
// from config.toml is answered 401 on a hosted project before the function runs: the daily
// purge was, until 2026-10-25. No third-party dependencies.
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { test } from 'node:test';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

/** The functions config.toml deploys with verify_jwt = false. */
export function configNoUserFunctions(toml = read('supabase/config.toml')) {
  const names = new Set();
  for (const [, name] of toml.matchAll(/^\[functions\.([a-z0-9-]+)\]\s*\n(?:\s*#.*\n)*\s*verify_jwt\s*=\s*false/gm)) {
    names.add(name);
  }
  return names;
}

/** The functions the compose router passes without a user JWT. */
export function routerNoUserFunctions(source = read('infra/supabase/volumes/functions/main/index.ts')) {
  const block = source.match(/NO_USER_FUNCTIONS = new Set\(\[([\s\S]*?)\]\)/)?.[1];
  assert.ok(block, 'the router declares NO_USER_FUNCTIONS');
  return new Set([...block.matchAll(/'([a-z0-9-]+)'/g)].map((m) => m[1]));
}

/** The functions infra/jobs/schedule.sql calls with the cron secret. */
export function scheduledFunctions(sql = read('infra/jobs/schedule.sql')) {
  return new Set([...sql.matchAll(/:'functions_url' \|\| '\/([a-z0-9-]+)'/g)].map((m) => m[1]));
}

test('config.toml and the compose router agree on the functions called without a user', () => {
  const config = [...configNoUserFunctions()].sort();
  const router = [...routerNoUserFunctions()].sort();
  assert.ok(config.length >= 8, `config.toml lists the no-user functions (${config.length})`);
  assert.deepEqual(config, router);
});

test('every scheduled job is callable without a user, on either kind of server', () => {
  const jobs = scheduledFunctions();
  assert.equal(jobs.size, 4, 'four scheduled jobs');
  const config = configNoUserFunctions();
  for (const name of jobs) assert.ok(config.has(name), `${name}: verify_jwt = false in config.toml`);
});

test('every function named this way exists', () => {
  for (const name of new Set([...configNoUserFunctions(), ...routerNoUserFunctions()])) {
    assert.ok(existsSync(new URL(`../supabase/functions/${name}/index.ts`, import.meta.url)), name);
  }
});

test('the parsers read the shapes the files use', () => {
  assert.deepEqual([...configNoUserFunctions(
    '[functions.a]\nverify_jwt = false\n\n# note\n[functions.b]\n# why\nverify_jwt = false\n\n[functions.c]\nverify_jwt = true\n',
  )], ['a', 'b']);
  assert.deepEqual([...routerNoUserFunctions("const NO_USER_FUNCTIONS = new Set([\n  'a', 'b',\n  'c-d',\n])")], ['a', 'b', 'c-d']);
  assert.deepEqual([...scheduledFunctions("$$, :'functions_url' || '/x-y', :'cron_secret'));")], ['x-y']);
});
