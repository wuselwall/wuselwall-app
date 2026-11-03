import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

// infra/backup/backup.sh with a stand-in for docker: the dumps are owner-only in an
// owner-only directory, and encrypted when a passphrase or an age recipient is set
// (security review 2026-11-01, F26). The restore drill reads an encrypted dump back.
const root = new URL('../', import.meta.url).pathname;
const which = (cmd) => spawnSync('sh', ['-c', `command -v ${cmd}`], { encoding: 'utf8' }).stdout.trim();

// pg_dumpall and pg_dump print a known text; pg_restore --list accepts it from stdin; any
// other call (the drill's psql and pg_restore) records its stdin and succeeds.
const DOCKER = `#!/bin/sh
case "$*" in
  *pg_dumpall*) echo "-- roles of the test" ;;
  *"pg_dump "*) echo "PGDMP test dump" ;;
  *"pg_restore --list"*) grep -q "PGDMP test dump" ;;
  *pg_restore*) cat > "$STUB_DIR/restored" ;;
  *) cat > /dev/null 2>&1 || true ;;
esac
`;

function withServer(fn) {
  const dir = mkdtempSync(join(tmpdir(), 'ww-backup-'));
  try {
    const bin = join(dir, 'bin');
    mkdirSync(bin);
    writeFileSync(join(bin, 'docker'), DOCKER);
    chmodSync(join(bin, 'docker'), 0o755);
    const env = { PATH: `${bin}:${process.env.PATH}`, HOME: dir, STUB_DIR: dir, BACKUP_DIR: join(dir, 'backups') };
    const run = (file, extra = {}, ...args) => spawnSync('bash', [join(root, file), ...args],
      { encoding: 'utf8', env: { ...env, ...extra }, input: '' });
    return fn({ dir, run, out: env.BACKUP_DIR });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
const mode = (path) => (statSync(path).mode & 0o777).toString(8);

test('plain dumps are owner-only, in an owner-only directory', () => withServer(({ run, out }) => {
  const result = run('infra/backup/backup.sh', {}, 'test');
  assert.equal(result.status, 0, result.stderr);
  assert.equal(mode(out), '700');
  const files = readdirSync(out);
  assert.equal(files.filter((f) => /^db-.*-test\.dump$/.test(f)).length, 1, files.join(' '));
  for (const f of files) assert.equal(mode(join(out, f)), '600', f);
  assert.match(result.stdout, /backup ok: .*db-.*-test\.dump/);
}));

test('an existing directory open to others is closed', () => withServer(({ run, out }) => {
  mkdirSync(out, { mode: 0o755 });
  chmodSync(out, 0o755);
  const result = run('infra/backup/backup.sh');
  assert.equal(result.status, 0, result.stderr);
  assert.equal(mode(out), '700');
  assert.match(result.stdout, /now 0700/);
}));

test('with BACKUP_PASSPHRASE every file is encrypted, nothing plain stays, and the drill reads it', () => withServer(({ dir, run, out }) => {
  const envFile = join(dir, 'backup.env');
  writeFileSync(envFile, "BACKUP_PASSPHRASE='correct horse battery staple'\n");
  const result = run('infra/backup/backup.sh', { BACKUP_ENV: envFile });
  assert.equal(result.status, 0, result.stderr);
  const files = readdirSync(out);
  assert.ok(files.some((f) => /^db-.*\.dump\.enc$/.test(f)), files.join(' '));
  assert.ok(files.some((f) => /^roles-.*\.sql\.enc$/.test(f)), files.join(' '));
  assert.ok(!files.some((f) => /\.(dump|sql)$/.test(f)), `no plain dump left: ${files.join(' ')}`);
  for (const f of files) {
    assert.equal(mode(join(out, f)), '600', f);
    assert.ok(!readFileSync(join(out, f)).includes('PGDMP'), `${f} is not readable as it stands`);
  }
  const drill = run('infra/backup/restore-drill.sh', { BACKUP_ENV: envFile });
  assert.equal(drill.status, 0, drill.stderr);
  assert.equal(readFileSync(join(dir, 'restored'), 'utf8'), 'PGDMP test dump\n', 'the drill decrypts on the way into pg_restore');
}));

test('both settings at once, or an age recipient without age, stop before any dump', () => withServer(({ run, out }) => {
  let result = run('infra/backup/backup.sh', { BACKUP_PASSPHRASE: 'x', BACKUP_AGE_RECIPIENT: 'age1example' });
  assert.equal(result.status, 2);
  if (!which('age')) {
    result = run('infra/backup/backup.sh', { BACKUP_AGE_RECIPIENT: 'age1example' });
    assert.equal(result.status, 2);
    assert.match(result.stderr, /age is not installed/);
  }
  assert.throws(() => readdirSync(out), 'nothing was written');
}));

test('with BACKUP_AGE_RECIPIENT the files are encrypted to it', { skip: (!which('age') || !which('age-keygen')) && 'age is not installed' }, () => withServer(({ dir, run, out }) => {
  const identity = join(dir, 'key.txt');
  spawnSync('age-keygen', ['-o', identity]);
  const recipient = readFileSync(identity, 'utf8').match(/public key: (age1\w+)/)[1];
  const result = run('infra/backup/backup.sh', { BACKUP_AGE_RECIPIENT: recipient });
  assert.equal(result.status, 0, result.stderr);
  const files = readdirSync(out);
  assert.ok(files.some((f) => /^db-.*\.dump\.age$/.test(f)) && !files.some((f) => /\.dump$/.test(f)), files.join(' '));
  const drill = run('infra/backup/restore-drill.sh', { BACKUP_AGE_IDENTITY: identity });
  assert.equal(drill.status, 0, drill.stderr);
  assert.equal(readFileSync(join(dir, 'restored'), 'utf8'), 'PGDMP test dump\n');
}));

// `wuselwall restore` with the same stand-in: it counts the families, backs up, and only then
// drops the database. A failed count is an error, not "no family".
const RESTORE_DOCKER = `#!/bin/sh
echo "$*" >> "$STUB_DIR/calls"
case "$*" in
  "compose ps --services") printf 'db\\nauth\\n' ;;
  compose*) ;;
  *pg_isready*) ;;
  *"from app.household"*)
    cat > /dev/null
    case "$HOUSEHOLDS" in fail) echo "psql: connection refused" >&2; exit 2 ;; *) echo "$HOUSEHOLDS" ;; esac ;;
  *pg_dumpall*) echo "-- roles" ;;
  *"pg_dump "*) echo "PGDMP live" ;;
  *"pg_restore --list"*) cat > /dev/null ;;
  *) cat > /dev/null 2>&1 || true ;;
esac
`;

function withInstall(fn) {
  const dir = mkdtempSync(join(tmpdir(), 'ww-restore-'));
  try {
    const bin = join(dir, 'bin');
    const server = join(dir, 'wuselwall');
    for (const d of [bin, join(server, 'stack'), join(server, 'backup'), join(server, 'migrations'), join(server, 'jobs')]) mkdirSync(d, { recursive: true });
    writeFileSync(join(bin, 'docker'), RESTORE_DOCKER);
    chmodSync(join(bin, 'docker'), 0o755);
    writeFileSync(join(server, 'wuselwall'), readFileSync(join(root, 'server/wuselwall')));
    writeFileSync(join(server, 'backup/backup.sh'), readFileSync(join(root, 'infra/backup/backup.sh')));
    writeFileSync(join(server, 'stack/.env'), "CRON_SECRET='x'\n");
    writeFileSync(join(server, 'migrations/20260101000000_test.sql'), 'select 1;\n');
    writeFileSync(join(server, 'jobs/schedule.sql'), 'select 1;\n');
    writeFileSync(join(dir, 'db-old.dump'), 'PGDMP old');
    const restore = (households, dump = join(dir, 'db-old.dump'), extra = {}) => {
      rmSync(join(dir, 'calls'), { force: true });
      const result = spawnSync('bash', [join(server, 'wuselwall'), 'restore', dump], {
        encoding: 'utf8', input: '',
        env: { PATH: `${bin}:${process.env.PATH}`, HOME: dir, STUB_DIR: dir, HOUSEHOLDS: households, ...extra },
      });
      let calls = [];
      try { calls = readFileSync(join(dir, 'calls'), 'utf8').trim().split('\n'); } catch { /* none */ }
      return { ...result, calls };
    };
    return fn({ dir, server, restore });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
const dropped = (calls) => calls.findIndex((c) => /drop database/.test(c));

test('restore stops when the families cannot be counted, before anything is dropped', () => withInstall(({ restore }) => {
  for (const households of ['fail', 'ERROR: relation "app.household" does not exist']) {
    const result = restore(households);
    assert.equal(result.status, 1, households);
    assert.match(result.stderr, /could not count the families|unexpected answer counting/);
    assert.equal(dropped(result.calls), -1, 'nothing was dropped');
    assert.ok(!result.calls.some((c) => /pg_dump /.test(c)), 'and no backup was needed');
  }
}));

test('restore on an empty server backs up before it drops the database', () => withInstall(({ restore, server }) => {
  const result = restore('0');
  assert.equal(result.status, 0, result.stderr);
  const backup = result.calls.findIndex((c) => /pg_dump /.test(c));
  assert.ok(backup >= 0 && backup < dropped(result.calls), 'the backup comes first');
  assert.ok(readdirSync(join(server, 'backups')).some((f) => /before-restore\.dump$/.test(f)));
}));

test('restore over a family needs WW_RESTORE_OVER_DATA=yes and still backs up first', () => withInstall(({ restore }) => {
  let result = restore('1');
  assert.equal(result.status, 1);
  assert.match(result.stderr, /WW_RESTORE_OVER_DATA=yes/);
  assert.equal(dropped(result.calls), -1);
  result = restore('1', undefined, { WW_RESTORE_OVER_DATA: 'yes' });
  assert.equal(result.status, 0, result.stderr);
  const backup = result.calls.findIndex((c) => /pg_dump /.test(c));
  assert.ok(backup >= 0 && backup < dropped(result.calls));
}));

test('restore refuses an encrypted dump with a pointer to the docs', () => withInstall(({ dir, restore }) => {
  writeFileSync(join(dir, 'db-old.dump.enc'), 'Salted__');
  const result = restore('0', join(dir, 'db-old.dump.enc'));
  assert.equal(result.status, 1);
  assert.match(result.stderr, /encrypted: decrypt it .*docs\/server\/restore/);
  assert.equal(dropped(result.calls), -1);
}));
