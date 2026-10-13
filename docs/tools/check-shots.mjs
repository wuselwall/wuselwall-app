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

const missing = [];
const used = { de: new Set(), en: new Set() };
for (const page of pages) {
  const lang = page.startsWith(`en${path.sep}`) ? 'en' : 'de';
  const text = fs.readFileSync(path.join(docs, page), 'utf8');
  if (text.includes('/screenshots/')) missing.push(`${page}: a plain image link to /screenshots/ — use <Shot name="…" alt="…" />`);
  for (const [, name] of text.matchAll(/<Shot\s+name="([\w-]+)"/g)) {
    used[lang].add(name);
    for (const file of [`${name}.png`, `${name}-dark.png`]) {
      if (!fs.existsSync(path.join(shots, lang, file))) missing.push(`${page}: ${lang}/${file}`);
    }
  }
}

for (const lang of ['de', 'en']) {
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
console.log(`${used.de.size + used.en.size} screenshots in use, all present in light and dark.`);
