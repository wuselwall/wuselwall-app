// Source checks run on PRs without rendering PNGs. Full validation additionally
// verifies every localized image before guide publication and release qualification.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const languages = ['de', 'en', 'fr', 'es'];
export const themes = ['light', 'dark'];

export function captureNames(source) {
  const inventory = source.match(/^const shots = \[([\s\S]*?)^\];/m)?.[1];
  if (!inventory) throw new Error('Missing screenshot capture inventory');
  const names = [...inventory.matchAll(/^\s*\{ name: '([\w-]+)'/gm)].map(m => m[1]);
  if (!names.length || new Set(names).size !== names.length) throw new Error('Empty or duplicate screenshot capture names');
  return names;
}

export function screenshotPaths(names) {
  return names.flatMap(name => languages.flatMap(lang => themes.map(theme =>
    `${lang}/${name}${theme === 'dark' ? '-dark' : ''}.png`)));
}

export function checkShots(docs, { definitionsOnly = false } = {}) {
  const images = path.join(docs, 'public/screenshots');
  const pages = fs.readdirSync(docs, { recursive: true })
    .filter(file => file.endsWith('.md') && !file.split(path.sep).some(p => p.startsWith('.') || ['node_modules', 'tools'].includes(p)));
  const defined = new Set(captureNames(fs.readFileSync(path.join(docs, 'tools/screenshots.mjs'), 'utf8')));
  const problems = [];
  let references = 0;
  for (const page of pages) {
    const lang = languages.slice(1).find(lang => page.startsWith(`${lang}${path.sep}`)) ?? 'de';
    const text = fs.readFileSync(path.join(docs, page), 'utf8');
    if (text.includes('/screenshots/')) problems.push(`${page}: use <Shot> instead of a plain screenshot link`);
    for (const [, name] of text.matchAll(/<Shot\s+name="([\w-]+)"/g)) {
      references++;
      if (!defined.has(name)) problems.push(`${page}: ${name} has no capture in screenshots.mjs`);
      if (!definitionsOnly) for (const suffix of ['', '-dark']) {
        const image = `${lang}/${name}${suffix}.png`;
        if (!fs.existsSync(path.join(images, image))) problems.push(`${page}: ${image}`);
      }
    }
  }
  return { problems, references };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const definitionsOnly = process.argv.includes('--definitions-only');
  const result = checkShots(path.resolve('docs'), { definitionsOnly });
  if (result.problems.length) {
    console.error(`Screenshot problems:\n  ${result.problems.join('\n  ')}`);
    process.exitCode = 1;
  } else console.log(`${result.references} screenshot references checked (${definitionsOnly ? 'capture definitions' : 'definitions and localized light/dark images'}).`);
}
