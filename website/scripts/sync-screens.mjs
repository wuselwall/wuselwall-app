// Copies the app screenshots the home page shows from the documentation's Playwright
// output (docs/public/screenshots, `npm run docs:screenshots` at the repository root)
// into src/assets/screens as WebP, in both languages and both themes. The copies are
// committed, so the website builds on its own (its Docker context is website/ only).
// Run `npm run sync-screens` after the screens change.
import { mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const from = fileURLToPath(new URL('../../docs/public/screenshots/', import.meta.url));
const to = fileURLToPath(new URL('../src/assets/screens/', import.meta.url));

// name → the widest the page ever needs (2× its largest CSS size).
const shots = { 'wall-board': 1600, 'wall-child-week': 1200, 'shopping-phone': 600, 'kid-shopping': 1200 };

let missing = 0;
for (const lang of ['de', 'en']) {
  await mkdir(`${to}${lang}`, { recursive: true });
  for (const [name, width] of Object.entries(shots)) {
    for (const suffix of ['', '-dark']) {
      const src = `${from}${lang}/${name}${suffix}.png`;
      if (!existsSync(src)) { console.error(`missing ${src}`); missing++; continue; }
      await sharp(src)
        .resize({ width, withoutEnlargement: true })
        .webp({ quality: 82 })
        .toFile(`${to}${lang}/${name}${suffix}.webp`);
    }
  }
}
if (missing) {
  console.error('Run `npm run docs:screenshots` at the repository root first.');
  process.exit(1);
}
console.log(`screens written to ${to}`);
