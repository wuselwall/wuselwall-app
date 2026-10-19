// Takes the user documentation's screenshots from the Flutter web demo build
// (app/lib/main_demo.dart, in-memory data, no backend):
//   npm run docs:screenshots
// To take only some shots while debugging, pass their names (both languages and themes):
//   node docs/tools/screenshots.mjs today meals-suggest
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
  de: { grandma: 'Oma Ruth', newList: 'Neue Liste', name: 'Name', save: 'Speichern', search: 'Suchen oder hinzufügen', settings: 'Einstellungen', oldCode: 'Code für ein älteres Gerät erzeugen', deviceName: 'Gerätename', createCode: 'Code erzeugen', addMember: 'Mitglied hinzufügen', history: 'Verlauf', trolley: 'Im Wagen', household: 'Neue Familie anlegen', signIn: 'Mit E-Mail fortfahren', enrol: 'Mit Code verbinden', papa: 'Thomas', daughter: 'Emma', wholemeal: /Vollkorn/, kitchenTablet: 'Küchen-Tablet', close: 'Schließen', shopping: 'Einkauf', kidShopping: 'Einkaufen', calendar: 'Kalender', week: 'Woche', newEvent: 'Neuer Termin', schedule: 'Stundenplan', tasks: 'Aufgaben', meals: 'Essen', householdSettings: 'Haushalt einstellen', today: 'Heute', editSchool: 'Schule bearbeiten', region: 'Region', importHolidays: 'Ferien übernehmen', addMeal: 'Mahlzeit hinzufügen', pairFront: 'Familien-Tablet oder Wanddisplay verbinden', pairConnect: 'Gerät verbinden', pairCode: 'Code vom neuen Gerät', next: 'Weiter', inviteAdult: 'Erwachsene Person einladen', inviteName: 'Name', inviteCreate: 'Einladung erstellen', reminders: 'Erinnerungen', advanced: 'Erweitert', setPassword: 'Passwort festlegen' },
  en: { grandma: 'Grandma Ruth', newList: 'New list', name: 'Name', save: 'Save', search: 'Search or add', settings: 'Settings', oldCode: 'Create a code for an older device', deviceName: 'Device name', createCode: 'Create code', addMember: 'Add member', history: 'History', trolley: 'In the trolley', household: 'Start a new family', signIn: 'Continue with email', enrol: 'Connect with a code', papa: 'David', daughter: 'Olivia', wholemeal: /Wholemeal/, kitchenTablet: 'Kitchen tablet', close: 'Close', shopping: 'Shopping', kidShopping: 'Shopping', calendar: 'Calendar', week: 'Week', newEvent: 'New event', schedule: 'Timetable', tasks: 'Tasks', meals: 'Meals', householdSettings: 'Household settings', today: 'Today', editSchool: 'Edit school', region: 'Region', importHolidays: 'Import school holidays', addMeal: 'Add meal', pairFront: 'Connect a family tablet or wall display', pairConnect: 'Connect device', pairCode: 'Code from the new device', next: 'Next', inviteAdult: 'Invite an adult', inviteName: 'Name', inviteCreate: 'Create invitation', reminders: 'Reminders', advanced: 'Advanced', setPassword: 'Set password' },
};

async function open(page, scenario, route = '') {
  await page.goto(`${base}/?scenario=${scenario}${route ? `#${route}` : ''}`);
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
// and by aria-label when the role is missing. A substring match tolerates a suffix such as "Tab 2 of 5",
// but it also matches cards that mention the name (the Today card "Warmes Essen … Einkaufsliste"),
// so an exact match always wins and the substring is only the fallback, on buttons and tabs.
const tapAny = async (page, name, { exact = true } = {}) => {
  const find = (ex) => page.getByRole('button', { name, exact: ex }).or(page.getByRole('tab', { name, exact: ex }))
    .or(page.locator(`flt-semantics[aria-label${ex ? '=' : '*='}"${name}"]`));
  const target = (await find(true).count()) ? find(true) : find(exact);
  await target.first().dispatchEvent('click');
  await settle(page);
};
// Settings open in the Basic view; shots of an Advanced row switch first. The segment's
// role differs between Flutter versions, so match it by name in each.
const showAdvanced = async (page, t) => {
  const name = t.advanced;
  await page.getByRole('button', { name, exact: true }).or(page.getByRole('radio', { name, exact: true }))
    .or(page.locator(`flt-semantics[aria-label="${name}"]`)).first().dispatchEvent('click');
  await settle(page);
};
const scrollDown = async (page, px = 600) => {
  const vp = page.viewportSize();
  await page.mouse.move(vp.width / 2, vp.height * 0.6);
  await page.mouse.wheel(0, px);
  await settle(page);
};
// Long lists build their semantics lazily: scroll in steps until the control is in the tree.
const scrollUntil = async (page, name, role = 'button') => {
  const loc = page.getByRole(role, { name, exact: true });
  for (let i = 0; i < 30 && !(await loc.count()); i++) await scrollDown(page, 600);
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
  { name: 'setup-server', scenario: 'server', viewport: PHONE },
  { name: 'setup-start', scenario: 'setup', viewport: PHONE },
  { name: 'setup-sign-in', scenario: 'setup', viewport: PHONE, steps: async (p, t) => press(p, t.signIn) },
  // The adult home opens on the calendar, so the shopping shots first press its nav destination.
  { name: 'shopping-phone', scenario: 'adult', viewport: PHONE, steps: async (p, t) => tapAny(p, t.shopping, { exact: false }) },
  { name: 'shopping-search', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await p.getByRole('textbox', { name: t.search }).fill('mil'); await settle(p); } },
  { name: 'shopping-new-list', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await tapNode(p, 'checkbox', t.newList); } },
  { name: 'shopping-laptop', scenario: 'adult', viewport: TABLET, steps: async (p, t) => tapAny(p, t.shopping, { exact: false }) },
  { name: 'shopping-edit-item', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await longPress(p, p.getByRole('checkbox', { name: t.wholemeal }).first()); } },
  { name: 'shopping-trolley', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await scrollDown(p, 1500); await tapAny(p, t.trolley, { exact: false }); await scrollDown(p, 3000); } },
  { name: 'shopping-history', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await press(p, t.history); await p.getByRole('button', { name: /14/ }).first().click().catch(() => {}); await settle(p); } },
  // Calendar, timetable, tasks, meals and household settings.
  { name: 'calendar-week', scenario: 'adult', viewport: TABLET, steps: async (p, t) => { await tapAny(p, t.calendar); await tapAny(p, t.week); } },
  { name: 'calendar-phone', scenario: 'adult', viewport: PHONE, steps: async (p, t) => tapAny(p, t.calendar) },
  { name: 'calendar-editor', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.calendar); await tapAny(p, t.newEvent); } },
  { name: 'school-week', scenario: 'adult', viewport: TABLET, steps: async (p, t) => tapAny(p, t.schedule, { exact: false }) },
  // The adult home opens on Today, the first destination.
  { name: 'today', scenario: 'adult', viewport: PHONE, steps: async (p, t) => tapAny(p, t.today) },
  // The school page's settings icon opens the school form; the region field opens the picker.
  { name: 'region-picker', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.schedule, { exact: false }); await tapAny(p, t.editSchool); await tapAny(p, t.region, { exact: false }); } },
  { name: 'holiday-import', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.schedule); await tapAny(p, t.editSchool); await scrollUntil(p, t.importHolidays); await tapNode(p, 'button', t.importHolidays); } },
  // The add action is a popup on each day: its name doubles the tooltip, so match it loosely,
  // then pick the first free slot, which opens the meal editor with the suggestions.
  { name: 'meals-suggest', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.meals); await press(p, t.addMeal, { exact: false }); await p.getByRole('menuitem').first().click(); await settle(p, 1200); } },
  { name: 'tasks-today', scenario: 'adult', viewport: TABLET, steps: async (p, t) => tapAny(p, t.tasks, { exact: false }) },
  { name: 'meals-week', scenario: 'adult', viewport: TABLET, steps: async (p, t) => tapAny(p, t.meals, { exact: false }) },
  { name: 'settings-household', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await tapAny(p, t.householdSettings, { exact: false }); } },
  { name: 'kid-who', scenario: 'kid', viewport: TABLET },
  { name: 'kid-shopping', scenario: 'kid', viewport: TABLET, steps: async (p, t) => { await press(p, t.daughter); await tapAny(p, t.kidShopping, { exact: false }); } },
  { name: 'wall-board', scenario: 'kiosk', viewport: WALL },
  { name: 'wall-child-week', scenario: 'kiosk', viewport: WALL, steps: async (p, t) => press(p, new RegExp(`^${t.daughter},`)) },
  { name: 'wall-day', scenario: 'kiosk', viewport: WALL, steps: async (p) => { await p.getByRole('button', { name: /^(Mittwoch|Wednesday)/ }).first().click(); await settle(p); } },
  // The board has no avatars: open the footer's shopping list first, then tap the name in its bar.
  { name: 'wall-shopping', scenario: 'kiosk', viewport: WALL, steps: async (p, t) => { await p.getByRole('button', { name: t.shopping }).first().click(); await settle(p); await p.getByRole('button', { name: t.daughter, exact: true }).last().click(); await settle(p); } },
  { name: 'settings-phone', scenario: 'adult', viewport: PHONE, steps: async (p, t) => press(p, t.settings) },
  { name: 'settings-sign-in', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await showAdvanced(p, t); await scrollUntil(p, t.setPassword); await scrollDown(p, -450); } },
  // A guardian's phone approves new devices (pair-approve); the code is the way for an older device.
  { name: 'settings-code', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await showAdvanced(p, t); await scrollUntil(p, t.oldCode); await tapAny(p, t.oldCode); await p.getByRole('textbox', { name: t.deviceName }).fill(t.kitchenTablet); await press(p, t.createCode); } },
  { name: 'new-family', scenario: 'newfamily', viewport: PHONE },
  // The new device's pairing screen, reached from the front door.
  { name: 'pair-device', scenario: 'setup', viewport: PHONE, steps: async (p, t) => press(p, t.pairFront) },
  // A guardian's phone: enter the code the new device shows, then review it before approving.
    // Opened at the pairing route (the Settings → Devices button is far down the list in English).
  { name: 'pair-approve', scenario: 'adult', viewport: PHONE, route: '/settings/devices/pair', steps: async (p, t) => { await p.getByRole('textbox', { name: t.pairCode }).fill('K7QM3XRP'); await press(p, t.next); } },
  // Inviting an adult: the name, then the result sheet with the code, QR code and share action.
  { name: 'invite-sheet', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await scrollUntil(p, t.inviteAdult); await tapAny(p, t.inviteAdult, { exact: false }); await p.getByRole('textbox', { name: t.inviteName }).fill(t.grandma); await press(p, t.inviteCreate); } },
  { name: 'reminders', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await tapAny(p, t.reminders, { exact: false }); } },
  // Siri and Shortcuts: the keys of the family, one in use and one not yet.
  { name: 'shortcuts', scenario: 'adult', viewport: PHONE, route: '/settings/shortcuts' },
];

const only = process.argv.slice(2);
const SHOT_TIMEOUT = 120_000;
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
      await open(page, shot.scenario, shot.route);
      if (shot.steps) await shot.steps(page, T[lang]);
    } catch (e) {
      failed++;
      console.warn(`! ${lang}/${shot.name}: ${e.message.split('\n')[0]}`);
    }
    // Software-rendered wall shots (2x, SwiftShader) can exceed Playwright's 30 s default
    // on a busy shared runner; the capture itself is not a failure signal.
    await page.screenshot({ path: path.join(out, lang, `${shot.name}.png`), timeout: SHOT_TIMEOUT });
    // The app follows the browser's scheme live, so the same state is shot again in dark.
    await page.emulateMedia({ colorScheme: 'dark' });
    await settle(page, 1000);
    await page.screenshot({ path: path.join(out, lang, `${shot.name}-dark.png`), timeout: SHOT_TIMEOUT });
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
