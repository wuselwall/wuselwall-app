import assert from 'node:assert/strict';
import { test } from 'node:test';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { folderFor, markdown, repositoryFrom } from './pr-screenshots.mjs';

test('the folder is the branch without its type prefix', () => {
  assert.equal(folderFor('feat/289-pack-items'), 'pr-screenshots/289-pack-items');
  assert.equal(folderFor('fix/267/Last Row'), 'pr-screenshots/267-last-row');
  assert.equal(folderFor('compact-nav-bar'), 'pr-screenshots/compact-nav-bar');
  for (const branch of ['', 'main', 'feat/', 'feat/..']) assert.throws(() => folderFor(branch), branch);
});

test('every form of a github.com remote names the repository', () => {
  for (const remote of ['git@github.com:family/wall.git', 'https://github.com/family/wall', 'https://github.com/family/wall.git\n', 'ssh://git@github.com/family/wall.git']) {
    assert.equal(repositoryFrom(remote), 'family/wall', remote);
  }
  assert.throws(() => repositoryFrom('https://example.org/family/wall.git'));
});

test('before and after share a row, other pictures stand alone, links name the commit', () => {
  const sha = 'a'.repeat(40);
  const text = markdown({ repository: 'family/wall', sha, files: [
    'pr-screenshots/289-pack-items/after-my-day.png',
    'pr-screenshots/289-pack-items/before-my-day.png',
    'pr-screenshots/289-pack-items/after-new sheet.png',
    'pr-screenshots/289-pack-items/wall-dark.png',
    'pr-screenshots/289-pack-items/notes.md',
  ] });
  const link = (file) => `https://github.com/family/wall/blob/${sha}/pr-screenshots/289-pack-items/${file}?raw=true`;
  assert.equal(text, [
    '| | Before | After |',
    '|---|---|---|',
    `| My day | ![My day, before](${link('before-my-day.png')}) | ![My day, after](${link('after-my-day.png')}) |`,
    '',
    '**After new sheet**',
    '',
    `![After new sheet](${link('after-new%20sheet.png')})`,
    '',
    '**Wall dark**',
    '',
    `![Wall dark](${link('wall-dark.png')})`,
    '',
  ].join('\n'));
  assert.equal(markdown({ repository: 'family/wall', sha, files: ['pr-screenshots/x/notes.md'] }), '');
});

test('the CLI refuses uncommitted and unpushed pictures, then prints the pushed commit', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'ww-pr-screenshots-'));
  const script = new URL('./pr-screenshots.mjs', import.meta.url).pathname;
  try {
    const remote = path.join(dir, 'remote.git');
    const work = path.join(dir, 'work');
    const git = (...args) => execFileSync('git', args, { cwd: work, encoding: 'utf8' }).trim();
    const run = (...args) => spawnSync(process.execPath, [script, ...args], { cwd: work, encoding: 'utf8' });
    execFileSync('git', ['init', '-q', '--bare', remote]);
    mkdirSync(work);
    git('init', '-q'); git('config', 'user.name', 'CI fixture'); git('config', 'user.email', 'ci@example.org');
    git('checkout', '-q', '-b', 'feat/12-wheel');
    assert.equal(run('--dir').stdout.trim(), 'pr-screenshots/12-wheel');
    mkdirSync(path.join(work, 'pr-screenshots/12-wheel'), { recursive: true });
    writeFileSync(path.join(work, 'pr-screenshots/12-wheel/after-wheel.png'), 'fixture');
    assert.match(run().stderr, /uncommitted pictures/);
    git('add', '.'); git('commit', '-qm', 'pictures');
    git('remote', 'add', 'origin', remote);
    assert.match(run().stderr, /not pushed/);
    git('push', '-q', 'origin', 'feat/12-wheel');
    git('remote', 'set-url', 'origin', 'git@github.com:family/wall.git');
    const result = run();
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, new RegExp(`^\\*\\*After wheel\\*\\*\\n\\n!\\[After wheel\\]\\(https://github\\.com/family/wall/blob/${git('rev-parse', 'HEAD')}/pr-screenshots/12-wheel/after-wheel\\.png\\?raw=true\\)\\n$`));
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
