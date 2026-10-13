// Renders the link-preview images (public/og-image.png, og-image-en.png, 1200×630) from
// the logo and the week-board screenshot, with Playwright's Chromium from the repository
// root (the docs tooling). Run after the screens or the title change:
//   node scripts/og-image.mjs
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const root = new URL('../', import.meta.url);
const file = (p) => fileURLToPath(new URL(p, root));
const logo = (await readFile(file('public/logo.svg'))).toString('base64');
const copy = {
  de: { out: 'public/og-image.png', title: 'Alles, was bei euch zuhause wuselt – an einer Wand.', sub: 'Open Source · Auf eurem eigenen Server' },
  en: { out: 'public/og-image-en.png', title: 'Everything that bustles around your home – on one wall.', sub: 'Open source · On your own server' },
};

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
for (const [lang, c] of Object.entries(copy)) {
  const shot = (await readFile(file(`src/assets/screens/${lang}/wall-board.webp`))).toString('base64');
  await page.setContent(`<!doctype html><html><body style="margin:0;width:1200px;height:630px;overflow:hidden;
    background:#f7f4ee;font-family:system-ui,'Segoe UI',Roboto,sans-serif;color:#1c1f23;position:relative">
    <div style="position:absolute;left:64px;top:64px;width:500px">
      <div style="display:flex;align-items:center;gap:16px;font-weight:700;font-size:40px">
        <img src="data:image/svg+xml;base64,${logo}" width="72" height="72">WuselWall</div>
      <div style="margin-top:40px;font-size:46px;font-weight:700;line-height:1.15;letter-spacing:-.01em">${c.title}</div>
      <div style="margin-top:28px;font-size:21px;color:#2d6a4f;font-weight:600">${c.sub}</div>
    </div>
    <div style="position:absolute;left:620px;top:90px;width:760px;background:#1c1f23;border-radius:22px;padding:12px;
      box-shadow:0 20px 50px -12px rgba(28,31,35,.35)">
      <img src="data:image/webp;base64,${shot}" style="display:block;width:100%;border-radius:10px"></div>
  </body></html>`);
  await page.screenshot({ path: file(c.out) });
  console.log('wrote', c.out);
}
await browser.close();
