#!/usr/bin/env node
// Renders the shopping tiles' pictures (specs/07, "Tiles with a picture") from Noto Emoji
// (https://github.com/googlefonts/noto-emoji, Apache License 2.0), pinned to one commit so
// a rerun gives the same files:
//   node scripts/shopping-icons.mjs
// Writes app/assets/shopping/<key>.png at 48 px and the 2.0x/ and 3.0x/ variants Flutter
// picks by pixel ratio, plus the licence. The keys are the icon_key values the server's
// app.catalog_icon_for() returns; app/lib/features/shopping/ui/shopping_labels.dart lists
// the same set.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const SHA = 'e20cbc2bbec1926686be9f9bee7d1d2cfa1fea0e';
const RAW = `https://raw.githubusercontent.com/googlefonts/noto-emoji/${SHA}`;

// Stable icon key -> Unicode codepoint (lowercase hex).
const icons = {
  milk: '1f95b', cheese: '1f9c0', butter: '1f9c8', egg: '1f95a', bowl: '1f963',
  bread: '1f35e', baguette: '1f956', pretzel: '1f968', croissant: '1f950', apple: '1f34e',
  pear: '1f350', banana: '1f34c', orange: '1f34a', lemon: '1f34b', grapes: '1f347',
  strawberry: '1f353', tomato: '1f345', cucumber: '1f952', carrot: '1f955', potato: '1f954',
  onion: '1f9c5', garlic: '1f9c4', bell_pepper: '1fad1', chili: '1f336', broccoli: '1f966',
  lettuce: '1f96c', mushroom: '1f344', avocado: '1f951', corn: '1f33d', peas: '1fadb',
  beans: '1fad8', pasta: '1f35d', rice: '1f35a', salt: '1f9c2', honey: '1f36f',
  oil: '1fad2', nuts: '1f95c', chocolate: '1f36b', candy: '1f36c', cookie: '1f36a',
  cake: '1f370', ice_cream: '1f368', pizza: '1f355', fries: '1f35f', chicken: '1f357',
  meat: '1f969', sausage: '1f32d', bacon: '1f953', fish: '1f41f', coffee: '2615',
  tea: '1f375', juice: '1f9c3', water: '1f4a7', soda: '1f964', beer: '1f37a',
  wine: '1f377', tin: '1f96b', toilet_paper: '1f9fb', soap: '1f9fc', toothbrush: '1faa5',
  lotion: '1f9f4', sponge: '1f9fd', baby_bottle: '1f37c', trash: '1f5d1', battery: '1f50b',
  light_bulb: '1f4a1', plaster: '1fa79', pill: '1f48a',
};

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const outDir = path.join(root, 'app', 'assets', 'shopping');
const SIZES = [
  { dir: outDir, px: 48 },
  { dir: path.join(outDir, '2.0x'), px: 96 },
  { dir: path.join(outDir, '3.0x'), px: 144 },
];

async function fetchOk(url) {
  const res = await fetch(url);
  if (res.status !== 200) {
    throw new Error(`HTTP ${res.status} for ${url}`);
  }
  return Buffer.from(await res.arrayBuffer());
}

// Fetches the SVG for a codepoint; if the plain name 404s, tries the emoji-presentation
// selector variant (_fe0f). Returns the buffer, or throws naming the key and both URLs.
async function fetchSvg(key, codepoint) {
  const plain = `${RAW}/2D/svg/emoji_u${codepoint}.svg`;
  const res = await fetch(plain);
  if (res.status === 200) {
    return Buffer.from(await res.arrayBuffer());
  }
  if (res.status !== 404) {
    throw new Error(`${key}: HTTP ${res.status} for ${plain}`);
  }
  const withSelector = `${RAW}/2D/svg/emoji_u${codepoint}_fe0f.svg`;
  try {
    return await fetchOk(withSelector);
  } catch (err) {
    throw new Error(`${key}: no SVG for ${plain} or ${withSelector} (${err.message})`);
  }
}

async function render(svg, px) {
  return sharp(svg, { density: 384 })
    .resize(px, px, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png({ compressionLevel: 9 })
    .toBuffer();
}

for (const { dir } of SIZES) {
  await fs.mkdir(dir, { recursive: true });
}

const keys = Object.keys(icons);
for (const key of keys) {
  const svg = await fetchSvg(key, icons[key]);
  for (const { dir, px } of SIZES) {
    await fs.writeFile(path.join(dir, `${key}.png`), await render(svg, px));
  }
  console.log(`${key}`);
}

const license = await fetchOk(`${RAW}/LICENSE`);
await fs.writeFile(path.join(outDir, 'LICENSE-NotoEmoji.txt'), license);
console.log(`wrote ${keys.length} icons at 48, 96 and 144 px, and LICENSE-NotoEmoji.txt`);
