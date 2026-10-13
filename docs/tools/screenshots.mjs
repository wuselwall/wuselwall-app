// Takes the user documentation's screenshots from the Flutter web demo build
// (app/lib/main_demo.dart, in-memory data, no backend):
//   npm run docs:screenshots
// Each shot is rendered in German and English, and in the light (name.png) and dark
// (name-dark.png) theme: the docs' <Shot> component shows the one matching the reader's.
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
const WALL = { width: 1280, height: 800 }; // the recommended wall resolution

/** Labels differ per language; the steps look them up here. */
const T = {
  de: { newList: 'Neue Liste', name: 'Name', save: 'Speichern', search: 'Suchen oder hinzufügen', settings: 'Einstellungen', addDevice: 'Gerät hinzufügen', deviceName: 'Gerätename', createCode: 'Code erzeugen', addMember: 'Mitglied hinzufügen', history: 'Verlauf', trolley: 'Im Wagen', household: 'Neue Familie anlegen', signIn: 'Mit E-Mail fortfahren', enrol: 'Mit Code verbinden', lukas: 'Lukas', lotta: 'Lotta', close: 'Schließen', shopping: 'Einkaufsliste', calendar: 'Kalender', week: 'Woche', newEvent: 'Neuer Termin', schedule: 'Stundenplan', tasks: 'Aufgaben', meals: 'Essen', householdSettings: 'Haushalt einstellen' },
  en: { newList: 'New list', name: 'Name', save: 'Save', search: 'Search or add', settings: 'Settings', addDevice: 'Add device', deviceName: 'Device name', createCode: 'Create code', addMember: 'Add member', history: 'History', trolley: 'In the trolley', household: 'Start a new family', signIn: 'Continue with email', enrol: 'Connect with a code', lukas: 'Lukas', lotta: 'Lotta', close: 'Close', shopping: 'Shopping list', calendar: 'Calendar', week: 'Week', newEvent: 'New event', schedule: 'Timetable', tasks: 'Tasks', meals: 'Meals', householdSettings: 'Household settings' },
};

async function open(page, scenario) {
  await page.goto(`${base}/?scenario=${scenario}`);
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 90000 });
  await page.locator('flt-semantics-placeholder').evaluate((e) => e.click()).catch(() => {});
  await page.waitForSelector('flt-semantics', { state: 'attached', timeout: 30000 });
  await page.waitForTimeout(1500);
}
const settle = (page, ms = 700) => page.waitForTimeout(ms);
const press = async (page, name, opts = {}) => {
  await page.getByRole(opts.role ?? 'button', { name, exact: opts.exact ?? true }).first().click();
  await settle(page);
};
// A click on the semantics node itself: works for widgets scrolled out of view (Flutter
// performs the tap action), where a pointer click would miss.
const tapNode = async (page, role, name) => {
  await page.getByRole(role, { name, exact: true }).first().dispatchEvent('click');
  await settle(page);
};
// Adult navigation destinations are in the bottom bar (a NavigationBar, role depends on the
// Flutter version), and list tiles may have no button role: match by name in both roles,
// and by aria-label when the role is missing. A substring match tolerates a suffix such as "Tab 2 of 5".
const tapAny = async (page, name, { exact = true } = {}) => {
  const byLabel = page.locator(`flt-semantics[aria-label${exact ? '=' : '*='}"${name}"]`);
  await page.getByRole('button', { name, exact }).or(page.getByRole('tab', { name, exact })).or(byLabel).first().dispatchEvent('click');
  await settle(page);
};
const scrollDown = async (page, px = 600) => {
  const vp = page.viewportSize();
  await page.mouse.move(vp.width / 2, vp.height * 0.6);
  await page.mouse.wheel(0, px);
  await settle(page);
};
// The semantics layer turns any pointer press into a tap, so for a long press the
// pointer goes straight to Flutter's canvas.
const longPress = async (page, locator) => {
  const box = await locator.boundingBox();
  await page.addStyleTag({ content: 'flt-semantics, flt-semantics-container, flt-semantics-host { pointer-events: none !important; }' });
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.waitForTimeout(700);
  await page.mouse.up();
  await settle(page);
};

/**
 * name: file name · scenario · viewport · steps(page, t)
 * Steps that fail log a warning and the shot is still taken, so one fragile step does
 * not lose the others.
 */
const shots = [
  { name: 'setup-start', scenario: 'setup', viewport: PHONE },
  { name: 'setup-household', scenario: 'setup', viewport: PHONE, steps: async (p, t) => press(p, t.household) },
  { name: 'setup-enrol', scenario: 'setup', viewport: PHONE, steps: async (p, t) => press(p, t.enrol) },
  { name: 'setup-sign-in', scenario: 'setup', viewport: PHONE, steps: async (p, t) => press(p, t.signIn) },
  // The adult home opens on the calendar, so the shopping shots first press its nav destination.
  { name: 'shopping-phone', scenario: 'adult', viewport: PHONE, steps: async (p, t) => tapAny(p, t.shopping, { exact: false }) },
  { name: 'shopping-search', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await p.getByRole('textbox', { name: t.search }).fill('mil'); await settle(p); } },
  { name: 'shopping-new-list', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await tapNode(p, 'checkbox', t.newList); } },
  { name: 'shopping-laptop', scenario: 'adult', viewport: TABLET, steps: async (p, t) => tapAny(p, t.shopping, { exact: false }) },
  { name: 'shopping-edit-item', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await longPress(p, p.getByRole('checkbox', { name: /Vollkorn/ }).first()); } },
  { name: 'shopping-trolley', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await scrollDown(p, 1500); await tapAny(p, t.trolley, { exact: false }); await scrollDown(p, 3000); } },
  { name: 'shopping-history', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await press(p, t.history); await p.getByRole('button', { name: /14/ }).first().click().catch(() => {}); await settle(p); } },
  // Calendar, timetable, tasks, meals and household settings.
  { name: 'calendar-week', scenario: 'adult', viewport: TABLET, steps: async (p, t) => tapAny(p, t.week) },
  { name: 'calendar-editor', scenario: 'adult', viewport: PHONE, steps: async (p, t) => tapAny(p, t.newEvent) },
  { name: 'school-week', scenario: 'adult', viewport: TABLET, steps: async (p, t) => tapAny(p, t.schedule, { exact: false }) },
  { name: 'tasks-today', scenario: 'adult', viewport: TABLET, steps: async (p, t) => tapAny(p, t.tasks, { exact: false }) },
  { name: 'meals-week', scenario: 'adult', viewport: TABLET, steps: async (p, t) => tapAny(p, t.meals, { exact: false }) },
  { name: 'settings-household', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await tapAny(p, t.householdSettings, { exact: false }); } },
  { name: 'kid-who', scenario: 'kid', viewport: TABLET },
  { name: 'kid-shopping', scenario: 'kid', viewport: TABLET, steps: async (p, t) => { await press(p, t.lotta); } },
  { name: 'wall-board', scenario: 'kiosk', viewport: WALL },
  { name: 'wall-child-week', scenario: 'kiosk', viewport: WALL, steps: async (p, t) => press(p, t.lotta) },
  { name: 'wall-day', scenario: 'kiosk', viewport: WALL, steps: async (p) => { await p.getByRole('button', { name: /^(Mittwoch|Wednesday)/ }).first().click(); await settle(p); } },
  // The board has no avatars: open the footer's shopping list first, then tap the name in its bar.
  { name: 'wall-shopping', scenario: 'kiosk', viewport: WALL, steps: async (p, t) => { await p.getByRole('button', { name: t.shopping }).first().click(); await settle(p); await p.getByRole('button', { name: t.lotta, exact: true }).last().click(); await settle(p); } },
  { name: 'settings-phone', scenario: 'adult', viewport: PHONE, steps: async (p, t) => press(p, t.settings) },
  { name: 'settings-add-device', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await press(p, t.addDevice); } },
  { name: 'settings-sign-in', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await scrollDown(p, 700); } },
  { name: 'settings-code', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await press(p, t.addDevice); await p.getByRole('textbox', { name: t.deviceName }).fill('Küchen-Tablet'); await press(p, t.createCode); } },
];

const only = process.argv.slice(2);
// Software GL: headless Chromium has no GPU here, and CanvasKit needs WebGL.
const browser = await chromium.launch({
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
let failed = 0;
for (const lang of ['de', 'en']) {
  fs.mkdirSync(path.join(out, lang), { recursive: true });
  for (const shot of shots) {
    if (only.length && !only.includes(shot.name)) continue;
    const ctx = await browser.newContext({
      viewport: shot.viewport, deviceScaleFactor: 2, locale: lang === 'de' ? 'de-DE' : 'en-US',
      colorScheme: 'light', timezoneId: 'Europe/Berlin',
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
    // The app follows the browser's scheme live, so the same state is shot again in dark.
    await page.emulateMedia({ colorScheme: 'dark' });
    await settle(page, 1000);
    await page.screenshot({ path: path.join(out, lang, `${shot.name}-dark.png`) });
    console.log(`${lang}/${shot.name}`);
    await ctx.close();
  }
}
await browser.close();
server.close();
if (failed) {
  console.warn(`${failed} step(s) failed — check the images above.`);
  // In CI a failed step would publish a wrong picture.
  if (process.env.CI) process.exit(1);
}
