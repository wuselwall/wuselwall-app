#!/usr/bin/env node
// The pictures of a pull request that changes a screen live in pr-screenshots/<branch>/,
// outside every build input (pr-screenshots/README.md). This prints the Markdown that
// shows them in the pull request's description:
//   node scripts/pr-screenshots.mjs          the Markdown for the current branch's pictures
//   node scripts/pr-screenshots.mjs --dir    only the folder the current branch uses
// A description cannot use relative paths, and a link to the branch dies when the branch is
// deleted on merge. The links therefore name the pushed commit: it stays reachable through
// the pull request after the merge, even when the folder is pruned from main later.
import { execFileSync } from 'node:child_process';
import { statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = 'pr-screenshots';
const IMAGE = /\.(png|jpe?g|webp|gif)$/i;
const LARGE = 500 * 1024;

/** feat/289-pack-items → pr-screenshots/289-pack-items; the type prefix is dropped. */
export function folderFor(branch) {
  const slug = (branch || '').replace(/^[^/]+\//, '').toLowerCase().replace(/[^a-z0-9._-]+/g, '-').replace(/^[-.]+|[-.]+$/g, '');
  if (!slug) throw new Error(`No folder for the branch "${branch || ''}": check out the pull request's branch.`);
  if (slug === 'main') throw new Error('main has no pull request: work in a branch.');
  return `${ROOT}/${slug}`;
}

/** owner/name of a github.com remote, in any of the forms git accepts. */
export function repositoryFrom(remote) {
  const match = /github\.com[:/]+([^/\s]+)\/([^/\s]+?)(?:\.git)?\/?$/.exec((remote || '').trim());
  if (!match) throw new Error(`Not a github.com remote: ${remote}`);
  return `${match[1]}/${match[2]}`;
}

const title = (name) => {
  const text = name.replace(IMAGE, '').replace(/[-_]+/g, ' ').trim();
  return text.charAt(0).toUpperCase() + text.slice(1);
};

/**
 * before-<name> and after-<name> become one row of a Before/After table; every other
 * picture stands alone under its file name. `files` are paths from the repository root.
 */
export function markdown({ repository, sha, files }) {
  const url = (file) => `https://github.com/${repository}/blob/${sha}/${file.split('/').map(encodeURIComponent).join('/')}?raw=true`;
  const image = (file, alt) => `![${alt}](${url(file)})`;
  const images = files.filter((file) => IMAGE.test(file)).sort();
  const byName = new Map(images.map((file) => [path.posix.basename(file), file]));
  const pairs = [];
  const single = [];
  for (const file of images) {
    const name = path.posix.basename(file);
    const before = /^before-(.+)$/.exec(name);
    const after = /^after-(.+)$/.exec(name);
    if (before && byName.has(`after-${before[1]}`)) pairs.push([title(before[1]), file, byName.get(`after-${before[1]}`)]);
    else if (!(after && byName.has(`before-${after[1]}`))) single.push(file);
  }
  const blocks = [];
  if (pairs.length) {
    blocks.push(['| | Before | After |', '|---|---|---|',
      ...pairs.map(([name, before, after]) => `| ${name} | ${image(before, `${name}, before`)} | ${image(after, `${name}, after`)} |`)].join('\n'));
  }
  for (const file of single) {
    const name = title(path.posix.basename(file));
    blocks.push(`**${name}**\n\n${image(file, name)}`);
  }
  return blocks.join('\n\n') + (blocks.length ? '\n' : '');
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const git = (...args) => execFileSync('git', args, { encoding: 'utf8' }).trim();
  try {
    const top = git('rev-parse', '--show-toplevel');
    process.chdir(top);
    const folder = folderFor(git('branch', '--show-current'));
    if (process.argv.includes('--dir')) {
      console.log(folder);
    } else {
      if (git('status', '--porcelain', '--', folder)) throw new Error(`${folder} has uncommitted pictures: commit them first.`);
      const files = git('ls-tree', '-r', '--name-only', 'HEAD', '--', folder).split('\n').filter((file) => IMAGE.test(file));
      if (!files.length) throw new Error(`No pictures in ${folder}.`);
      const sha = git('rev-parse', 'HEAD');
      if (!git('branch', '--remotes', '--contains', sha)) throw new Error('This commit is not pushed: push the branch first, the links name the commit.');
      for (const file of files) {
        const size = statSync(file).size;
        if (size > LARGE) console.error(`Large picture (${Math.round(size / 1024)} KB), crop or compress it: ${file}`);
      }
      process.stdout.write(markdown({ repository: repositoryFrom(git('remote', 'get-url', 'origin')), sha, files }));
    }
  } catch (error) {
    console.error(error.stderr?.toString().trim() || error.message);
    process.exit(1);
  }
}
