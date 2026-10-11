// Writes specs/brand/*.svg and app/assets/icon/*.png from the Wuselpunkte and Wuselchen
// symbols in specs/mockups/logo.html (ADR-012). Usage: node scripts/brand-assets.js, then
// `dart run flutter_launcher_icons` in app/.
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const root = path.join(__dirname, "..");
const brand = path.join(root, 'specs/brand');
const icons = path.join(root, 'app/assets/icon');
fs.mkdirSync(brand, { recursive: true });
fs.mkdirSync(icons, { recursive: true });

const paper = { tile: '#F7F4EE', m1: '#7B3FE4', m2: '#0B8793', m3: '#F29A2E', m4: '#D8336B', mb: '#2D6A4F',
  body: '#2D6A4F', sclera: '#FFFFFF', pupil: '#1C1F23', mouth: '#F7F4EE', cheek: '#FF85AE' };
const dark = { tile: '#14171A', m1: '#B39BFF', m2: '#4FCBD6', m3: '#F0A84E', m4: '#FF7FA8', mb: '#6CC79A',
  body: '#6CC79A', sclera: '#FFFFFF', pupil: '#14171A', mouth: '#14171A', cheek: '#FF85AE' };
const mono = Object.fromEntries(Object.keys(paper).map((k) => [k, '#000000']));

// Wuselpunkte: a W of nine dots, Tanne green at the centre peak, two dots flying off.
const punkte = (c) => `
    <circle cx="16" cy="25" r="9" fill="${c.m1}"/>
    <circle cx="23.5" cy="49" r="6.5" fill="${c.m2}"/>
    <circle cx="32" cy="75" r="9" fill="${c.m3}"/>
    <circle cx="41.5" cy="55" r="6.5" fill="${c.m4}"/>
    <circle cx="50" cy="37" r="9" fill="${c.mb}"/>
    <circle cx="59" cy="57" r="6.5" fill="${c.m1}"/>
    <circle cx="68" cy="76" r="9" fill="${c.m2}"/>
    <circle cx="76.5" cy="50" r="6.5" fill="${c.m3}"/>
    <circle cx="84" cy="24" r="9" fill="${c.m4}"/>
    <circle cx="92" cy="12" r="3.2" fill="${c.m4}" opacity=".55"/>
    <circle cx="96" cy="4.5" r="2" fill="${c.m4}" opacity=".35"/>`;

// Wuselchen: the mascot. Four tufts in the family colours, a "w" for a mouth.
const wuselchen = (c) => `
    <g fill="none" stroke-linecap="round" stroke-width="6.5">
      <path d="M37 32 Q31 22 33 13" stroke="${c.m1}"/>
      <path d="M46 28 Q44 18 47 9" stroke="${c.m2}"/>
      <path d="M55 28 Q58 18 57 9" stroke="${c.m3}"/>
      <path d="M64 32 Q71 23 70 14" stroke="${c.m4}"/>
    </g>
    <path d="M50 27 C75 27 88 42 88 61 C88 81 72 90 50 90 C28 90 12 81 12 61 C12 42 25 27 50 27 Z" fill="${c.body}"/>
    <ellipse cx="27" cy="70" rx="6" ry="3.6" fill="${c.cheek}" opacity=".6"/>
    <ellipse cx="73" cy="70" rx="6" ry="3.6" fill="${c.cheek}" opacity=".6"/>
    <circle cx="37" cy="56" r="9.5" fill="${c.sclera}"/>
    <circle cx="63" cy="56" r="9.5" fill="${c.sclera}"/>
    <circle cx="39" cy="54" r="5" fill="${c.pupil}"/>
    <circle cx="65" cy="54" r="5" fill="${c.pupil}"/>
    <path d="M40 71 q5 7 10 0 q5 7 10 0" fill="none" stroke="${c.mouth}" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round"/>`;

const svg = (title, body, size = 100) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="${size}" height="${size}">\n  <title>${title}</title>${body}\n</svg>\n`;
// The mark placed inside a canvas: offset and size in viewBox units.
const placed = (mark, at, size) => `\n  <g transform="translate(${at} ${at}) scale(${size / 100})">${mark}\n  </g>`;
// App icons are full squares: iOS and Android apply their own corner masks.
const tile = (c, mark) => `\n  <rect width="100" height="100" fill="${c.tile}"/>${placed(mark, 12, 76)}`;

const files = {
  'wuselwall-mark.svg': svg('WuselWall', punkte(paper)),
  'wuselwall-mark-dark.svg': svg('WuselWall', punkte(dark)),
  'wuselwall-icon.svg': svg('WuselWall', tile(paper, punkte(paper)), 1024),
  'wuselwall-icon-dark.svg': svg('WuselWall', tile(dark, punkte(dark)), 1024),
  // Android adaptive layers: flutter_launcher_icons insets them by 16 %, which keeps the
  // mark inside the 66 % safe zone, so they carry no padding of their own.
  'wuselwall-adaptive-foreground.svg': svg('WuselWall', punkte(paper), 1024),
  'wuselwall-monochrome.svg': svg('WuselWall', punkte(mono), 1024),
  'wuselchen.svg': svg('Wuselchen', wuselchen(paper)),
  'wuselchen-dark.svg': svg('Wuselchen', wuselchen(dark)),
};
for (const [name, text] of Object.entries(files)) fs.writeFileSync(path.join(brand, name), text);

const png = (name, out, size = 1024) =>
  sharp(Buffer.from(files[name]), { density: 72 * size / 100 }).resize(size, size).png().toFile(path.join(icons, out));

(async () => {
  await png('wuselwall-icon.svg', 'icon.png');
  await png('wuselwall-icon-dark.svg', 'icon-dark.png');
  await png('wuselwall-adaptive-foreground.svg', 'adaptive-foreground.png');
  await png('wuselwall-monochrome.svg', 'monochrome.png');
  // iOS rejects an app icon with an alpha channel.
  await sharp(path.join(icons, 'icon.png')).flatten({ background: paper.tile }).removeAlpha()
    .toFile(path.join(icons, 'icon-ios.png'));
  console.log(fs.readdirSync(brand).join(' '), '|', fs.readdirSync(icons).join(' '));
})();
