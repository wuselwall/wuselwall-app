// Every <Shot name="…"> in the docs has its light and dark image in the page's language:
//   npm run docs:check   (after npm run docs:screenshots)
// VitePress cannot see these paths (the component builds them at runtime), so without
// this a renamed or forgotten shot would publish a broken image.
import fs from 'node:fs';
import path from 'node:path';

const docs = path.resolve('docs');
const shots = path.join(docs, 'public/screenshots');
const pages = fs.readdirSync(docs, { recursive: true })
  .filter((f) => f.endsWith('.md') && !f.split(path.sep).some((p) => p.startsWith('.') || p === 'node_modules'));

const defined = new Set([...fs.readFileSync(path.join(docs, 'tools/screenshots.mjs'), 'utf8').matchAll(/name: '([\w-]+)'/g)].map((m) => m[1]));
const missing = [];
const languages = ['de', 'en', 'fr', 'es'];
const used = Object.fromEntries(languages.map((lang) => [lang, new Set()]));
for (const page of pages) {
  const lang = languages.slice(1).find((lang) => page.startsWith(`${lang}${path.sep}`)) ?? 'de';
  const text = fs.readFileSync(path.join(docs, page), 'utf8');
  if (text.includes('/screenshots/')) missing.push(`${page}: a plain image link to /screenshots/ — use <Shot name="…" alt="…" />`);
  for (const [, name] of text.matchAll(/<Shot\s+name="([\w-]+)"/g)) {
    used[lang].add(name);
    if (!defined.has(name)) missing.push(`${page}: ${name} has no capture in screenshots.mjs`);
    for (const file of [`${name}.png`, `${name}-dark.png`]) {
      if (!fs.existsSync(path.join(shots, lang, file))) missing.push(`${page}: ${lang}/${file}`);
    }
  }
}

for (const lang of languages) {
  const dir = path.join(shots, lang);
  const taken = fs.existsSync(dir) ? fs.readdirSync(dir) : [];
  for (const file of taken) {
    const name = file.replace(/(-dark)?\.png$/, '');
    if (!file.endsWith('-dark.png') && !used[lang].has(name)) console.warn(`unused: ${lang}/${file}`);
  }
}

if (missing.length) {
  console.error(`Screenshot problems (a missing one goes into docs/tools/screenshots.mjs, then npm run docs:screenshots):\n  ${missing.join('\n  ')}`);
  process.exit(1);
}
console.log(`${Object.values(used).reduce((sum, names) => sum + names.size, 0)} screenshots in use, all present in light and dark.`);
