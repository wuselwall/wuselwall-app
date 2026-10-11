// Takes the user documentation's screenshots from the Flutter web demo build
// (app/lib/main_demo.dart, in-memory data, no backend):
//   npm run docs:screenshots
// Each shot is rendered in German and English, in the light theme unless stated.
// Flutter draws to a canvas, so the script switches on the accessibility tree
// (Flutter's semantics) and drives the page by the same labels a screen reader gets.
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve('app/build/web-demo');
const out = path.resolve('docs/public/screenshots');
if (!fs.existsSync(root)) {
  console.log('Building the demo first …');
  execFileSync('flutter', ['build', 'web', '-t', 'lib/main_demo.dart', '--release', '-o', 'build/web-demo'], {
    cwd: 'app', stdio: 'inherit', env: { ...process.env, PATH: `${process.env.HOME}/flutter/bin:${process.env.PATH}` },
  });
}

const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf', '.css': 'text/css', '.ico': 'image/x-icon' };
const server = http.createServer((req, res) => {
  let p = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!p.startsWith(root) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) p = path.join(root, 'index.html');
  res.writeHead(200, { 'content-type': types[path.extname(p)] ?? 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
}).listen(0);
const base = `http://localhost:${server.address().port}`;

const PHONE = { width: 390, height: 844 };
const TABLET = { width: 1024, height: 768 };
const WALL = { width: 1280, height: 720 };

/** Labels differ per language; the steps look them up here. */
const T = {
  de: { newList: 'Neue Liste', name: 'Name', save: 'Speichern', search: 'Suchen oder hinzufügen', settings: 'Einstellungen', addDevice: 'Gerät hinzufügen', deviceName: 'Gerätename', createCode: 'Code erzeugen', addMember: 'Mitglied hinzufügen', history: 'Verlauf', trolley: 'Im Wagen', household: 'Neuen Haushalt einrichten', signIn: 'Als Erziehungsberechtigter anmelden', enrol: 'Dieses Gerät mit Code einrichten', lukas: 'Lukas', lotta: 'Lotta', close: 'Schließen' },
  en: { newList: 'New list', name: 'Name', save: 'Save', search: 'Search or add', settings: 'Settings', addDevice: 'Add device', deviceName: 'Device name', createCode: 'Create code', addMember: 'Add member', history: 'History', trolley: 'In the trolley', household: 'Set up a new household', signIn: 'Sign in as guardian', enrol: 'Set up this device with a code', lukas: 'Lukas', lotta: 'Lotta', close: 'Close' },
};

async function open(page, scenario) {
  await page.goto(`${base}/?scenario=${scenario}`);
  await page.waitForSelector('flt-glass-pane', { timeout: 90000 });
  await page.locator('flt-semantics-placeholder').evaluate((e) => e.click()).catch(() => {});
  await page.waitForSelector('flt-semantics', { timeout: 30000 });
  await page.waitForTimeout(1500);
}
const settle = (page, ms = 700) => page.waitForTimeout(ms);
const press = async (page, name, opts = {}) => {
  await page.getByRole(opts.role ?? 'button', { name, exact: opts.exact ?? false }).first().click();
  await settle(page);
};
const longPress = async (page, locator) => {
  const box = await locator.boundingBox();
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.waitForTimeout(700);
  await page.mouse.up();
  await settle(page);
};

/**
 * name: file name · scenario · viewport · scheme · steps(page, t)
 * Steps that fail log a warning and the shot is still taken, so one fragile step does
 * not lose the others.
 */
const shots = [
  { name: 'setup-start', scenario: 'setup', viewport: PHONE },
  { name: 'setup-household', scenario: 'setup', viewport: PHONE, steps: async (p, t) => press(p, t.household) },
  { name: 'setup-enrol', scenario: 'setup', viewport: PHONE, steps: async (p, t) => press(p, t.enrol) },
  { name: 'setup-sign-in', scenario: 'setup', viewport: PHONE, steps: async (p, t) => press(p, t.signIn) },
  { name: 'shopping-phone', scenario: 'adult', viewport: PHONE },
  { name: 'shopping-phone-dark', scenario: 'adult', viewport: PHONE, scheme: 'dark' },
  { name: 'shopping-search', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await p.getByRole('textbox', { name: t.search }).fill('mil'); await settle(p); } },
  { name: 'shopping-new-list', scenario: 'adult', viewport: PHONE, steps: async (p, t) => press(p, t.newList) },
  { name: 'shopping-laptop', scenario: 'adult', viewport: TABLET },
  { name: 'shopping-edit-item', scenario: 'adult', viewport: PHONE, steps: async (p) => longPress(p, p.getByText('Vollkorn').or(p.getByText('Brot')).first()) },
  { name: 'shopping-trolley', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await p.getByText(t.trolley).first().scrollIntoViewIfNeeded(); await press(p, t.trolley); } },
  { name: 'shopping-history', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.history); await p.getByText('14').first().click().catch(() => {}); await settle(p); } },
  { name: 'kid-who', scenario: 'kid', viewport: TABLET },
  { name: 'kid-shopping', scenario: 'kid', viewport: TABLET, steps: async (p, t) => { await press(p, t.lotta); } },
  { name: 'wall-shopping', scenario: 'kiosk', viewport: WALL, steps: async (p, t) => { await press(p, t.lotta); } },
  { name: 'settings-phone', scenario: 'adult', viewport: PHONE, steps: async (p, t) => press(p, t.settings) },
  { name: 'settings-add-device', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await press(p, t.addDevice); } },
  { name: 'settings-code', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await press(p, t.addDevice); await p.getByRole('textbox', { name: t.deviceName }).fill('Küchen-Tablet'); await press(p, t.createCode); } },
];

const only = process.argv.slice(2);
const browser = await chromium.launch();
let failed = 0;
for (const lang of ['de', 'en']) {
  fs.mkdirSync(path.join(out, lang), { recursive: true });
  for (const shot of shots) {
    if (only.length && !only.includes(shot.name)) continue;
    const ctx = await browser.newContext({
      viewport: shot.viewport, deviceScaleFactor: 2, locale: lang === 'de' ? 'de-DE' : 'en-US',
      colorScheme: shot.scheme ?? 'light', timezoneId: 'Europe/Berlin',
    });
    const page = await ctx.newPage();
    try {
      await open(page, shot.scenario);
      if (shot.steps) await shot.steps(page, T[lang]);
    } catch (e) {
      failed++;
      console.warn(`! ${lang}/${shot.name}: ${e.message.split('\n')[0]}`);
    }
    await page.screenshot({ path: path.join(out, lang, `${shot.name}.png`) });
    console.log(`${lang}/${shot.name}`);
    await ctx.close();
  }
}
await browser.close();
server.close();
if (failed) console.warn(`${failed} step(s) failed — check the images above before committing.`);
