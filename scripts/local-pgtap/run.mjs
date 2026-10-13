// Runs supabase/migrations and supabase/tests on a throwaway local Postgres 15 — no Docker,
// no sudo, nothing on the home server. A bare Postgres plus shim.sql (the few Supabase
// roles, auth and realtime objects the migrations touch) is not Supabase: CI's stack and
// scripts/remote-pgtap.sh stay the real check. This one is for the minutes in between.
//
//   cd scripts/local-pgtap && npm ci && node run.mjs          all migrations, all tests
//   node run.mjs 080 090                                       only tests matching an arg
//
// Exit code 1 when a migration fails or a test reports "not ok", an error or a bad plan.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import pg from 'pg';

const here = path.dirname(new URL(import.meta.url).pathname);
const bin = path.join(here, 'node_modules/@embedded-postgres/linux-x64/native/bin');
const cache = path.join(here, 'cache');
const data = path.join(cache, 'data');
const repo = path.resolve(here, '../../supabase');
const PGTAP = '1.3.3';
const PORT = 54329;
const only = process.argv.slice(2);

function sh(cmd, args) {
  return execFileSync(path.join(bin, cmd), args, { stdio: ['ignore', 'pipe', 'pipe'] }).toString();
}

fs.mkdirSync(cache, { recursive: true });
// pgTAP is plain SQL once its template is filled in; fetched once into the cache.
const pgtapSql = path.join(cache, `pgtap-${PGTAP}.sql`);
if (!fs.existsSync(pgtapSql)) {
  const tar = path.join(cache, 'pgtap.tar.gz');
  execFileSync('curl', ['-sSL', '-o', tar, `https://github.com/theory/pgtap/archive/refs/tags/v${PGTAP}.tar.gz`]);
  execFileSync('tar', ['xzf', tar, '-C', cache]);
  const template = fs.readFileSync(path.join(cache, `pgtap-${PGTAP}/sql/pgtap.sql.in`), 'utf8');
  fs.writeFileSync(pgtapSql, template
    .replaceAll('MODULE_PATHNAME', '$libdir/pgtap').replaceAll('__OS__', 'linux').replaceAll('__VERSION__', '1.33'));
}
if (!fs.existsSync(path.join(data, 'PG_VERSION'))) {
  sh('initdb', ['-D', data, '-U', 'postgres', '--auth=trust', '-E', 'UTF8', '--locale=C']);
}
try {
  sh('pg_ctl', ['-D', data, 'status']);
} catch {
  sh('pg_ctl', ['-D', data, '-o', `-p ${PORT} -c unix_socket_directories='' -c listen_addresses=127.0.0.1`, '-l', path.join(cache, 'pg.log'), '-w', 'start']);
}

const conn = (database) => new pg.Client({ host: '127.0.0.1', port: PORT, user: 'postgres', database });

const admin = conn('postgres');
await admin.connect();
await admin.query('drop database if exists wusel with (force)');
await admin.query('create database wusel');
await admin.end();

const db = conn('wusel');
await db.connect();
let failed = false;
const run = async (label, sql) => {
  try {
    await db.query(sql);
    return true;
  } catch (e) {
    failed = true;
    const pos = e.position ? Number(e.position) : null;
    const ctx = pos ? sql.slice(Math.max(0, pos - 200), pos + 100).replace(/\n/g, '\n    ') : '';
    console.log(`FAIL ${label}: ${e.message}${e.where ? `\n  where: ${e.where}` : ''}${ctx ? `\n  near:\n    ${ctx}` : ''}`);
    return false;
  }
};

await run('shim', fs.readFileSync(path.join(here, 'shim.sql'), 'utf8'));
await run('pgtap', 'set search_path = extensions;\n' + fs.readFileSync(pgtapSql, 'utf8') + '\nreset search_path;');
const migrations = fs.readdirSync(path.join(repo, 'migrations')).filter((f) => f.endsWith('.sql')).sort();
for (const m of migrations) {
  if (!(await run(`migration ${m}`, fs.readFileSync(path.join(repo, 'migrations', m), 'utf8')))) {
    console.log('Stopping: later migrations and the tests depend on this one.');
    await db.end();
    process.exit(1);
  }
}
console.log(`migrations: ${migrations.length} applied`);
await db.end();

const tests = fs.readdirSync(path.join(repo, 'tests')).filter((f) => f.endsWith('.sql')).sort()
  .filter((f) => only.length === 0 || only.some((o) => f.includes(o)));
for (const t of tests) {
  const c = conn('wusel');
  await c.connect();
  const sql = fs.readFileSync(path.join(repo, 'tests', t), 'utf8');
  let lines = [];
  try {
    const res = await c.query('set search_path to public, extensions;\n' + sql);
    for (const r of [res].flat()) for (const row of r.rows ?? []) lines.push(...Object.values(row).map(String));
    const bad = lines.filter((l) => /^not ok|Looks like you/.test(l));
    const okCount = lines.filter((l) => /^ok /.test(l)).length;
    if (bad.length) failed = true;
    console.log(`${bad.length ? 'FAIL' : 'PASS'} ${t}: ${okCount} ok, ${bad.length} problems`);
    // Show each failing assertion with the diagnostic lines that follow it.
    lines.forEach((l, i) => {
      if (/^not ok|Looks like you/.test(l)) {
        console.log('  ' + l);
        for (let j = i + 1; j < lines.length && /^#/.test(lines[j]) && j < i + 8; j++) console.log('    ' + lines[j]);
      }
    });
  } catch (e) {
    failed = true;
    const pos = e.position ? Number(e.position) - 'set search_path to public, extensions;\n'.length : null;
    const lineNo = pos ? sql.slice(0, pos).split('\n').length : null;
    console.log(`FAIL ${t}: ERROR ${e.message}${lineNo ? ` (line ${lineNo})` : ''}${e.where ? `\n  where: ${e.where}` : ''}`);
    await c.query('rollback').catch(() => {});
  }
  await c.end();
}
process.exit(failed ? 1 : 0);
