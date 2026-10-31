// Takes the user documentation's screenshots from the Flutter web demo build
// (app/lib/main_demo.dart, in-memory data, no backend):
//   npm run docs:screenshots
// To take only some shots while debugging, pass their names (all languages and both themes):
//   node docs/tools/screenshots.mjs today meals-suggest
// Each shot is rendered in German, English, French and Spanish, in both the light
// (name.png) and dark (name-dark.png) theme. <Shot> follows the reader’s language/theme.
// To restrict the languages or export elsewhere (for the marketing website):
//   SHOT_LANGS=fr,es SHOT_OUT=/abs/dir node docs/tools/screenshots.mjs wall-board
// SHOT_LANGS is a comma-separated list of de, en, fr, es (default de,en,fr,es); SHOT_OUT is where the
// <lang>/ folders are written (default docs/public/screenshots). The demo takes its language,
// names and sample data from the browser's locale, which the script sets per language.
// Flutter draws to a canvas, so the script switches on the accessibility tree
// (Flutter's semantics) and drives the page by the same labels a screen reader gets.
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve('app/build/web-demo');
const out = path.resolve(process.env.SHOT_OUT || 'docs/public/screenshots');
const LOCALES = { de: 'de-DE', en: 'en-US', fr: 'fr-FR', es: 'es-ES' };
const langs = [...new Set((process.env.SHOT_LANGS || 'de,en,fr,es').split(',').map((l) => l.trim()).filter(Boolean))];
if (!langs.length || langs.some((lang) => !Object.hasOwn(LOCALES, lang))) {
  throw new Error('SHOT_LANGS must contain one or more of de,en,fr,es');
}

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
  de: { startShopping: 'Einkaufen gehen', addInStore: 'Hinzufügen', editList: 'Liste bearbeiten', grandma: 'Oma Ruth', newList: 'Neue Liste', name: 'Name', save: 'Speichern', search: 'Suchen oder hinzufügen', settings: 'Einstellungen', oldCode: 'Code für ein älteres Gerät erzeugen', deviceName: 'Gerätename', createCode: 'Code erzeugen', addMember: 'Mitglied hinzufügen', history: 'Verlauf', trolley: 'Im Wagen', household: 'Neue Familie anlegen', signIn: 'Mit E-Mail fortfahren', enrol: 'Mit Code verbinden', papa: 'Thomas', daughter: 'Emma', wholemeal: /Vollkorn/, kitchenTablet: 'Küchen-Tablet', close: 'Schließen', shopping: 'Einkauf', kidShopping: 'Einkaufen', calendar: 'Kalender', week: 'Woche', newEvent: 'Neuer Termin', schedule: 'Stundenplan', scheduleNav: 'Schule', showMenu: 'Menü anzeigen', tasks: 'Aufgaben', meals: 'Essen', today: 'Heute', editSchool: 'Schule bearbeiten', region: 'Region', importHolidays: 'Ferien übernehmen', addMeal: 'Mahlzeit hinzufügen', pairFront: 'Familien-Tablet oder Wanddisplay verbinden', pairConnect: 'Gerät verbinden', pairCode: 'Code vom neuen Gerät', next: 'Weiter', inviteAdult: 'Erwachsene Person einladen', inviteName: 'Name', inviteCreate: 'Einladung erstellen', reminders: 'Erinnerungen', advanced: 'Erweitert', setPassword: 'Passwort festlegen', editTimetable: "Stundenplan bearbeiten", editorSchool: "Gemeinschaftsschule am Park", searchQuery: "mil", month: 'Monat' },
  en: { startShopping: 'Go shopping', addInStore: 'Add', editList: 'Edit list', grandma: 'Grandma Ruth', newList: 'New list', name: 'Name', save: 'Save', search: 'Search or add', settings: 'Settings', oldCode: 'Create a code for an older device', deviceName: 'Device name', createCode: 'Create code', addMember: 'Add member', history: 'History', trolley: 'In the trolley', household: 'Start a new family', signIn: 'Continue with email', enrol: 'Connect with a code', papa: 'David', daughter: 'Olivia', wholemeal: /Wholemeal/, kitchenTablet: 'Kitchen tablet', close: 'Close', shopping: 'Shopping', kidShopping: 'Shopping', calendar: 'Calendar', week: 'Week', newEvent: 'New event', schedule: 'Timetable', scheduleNav: 'School', showMenu: 'Show menu', tasks: 'Tasks', meals: 'Meals', today: 'Today', editSchool: 'Edit school', region: 'Region', importHolidays: 'Import school holidays', addMeal: 'Add meal', pairFront: 'Connect a family tablet or wall display', pairConnect: 'Connect device', pairCode: 'Code from the new device', next: 'Next', inviteAdult: 'Invite an adult', inviteName: 'Name', inviteCreate: 'Create invitation', reminders: 'Reminders', advanced: 'Advanced', setPassword: 'Set password', editTimetable: "Edit timetable", editorSchool: "Parkside School", searchQuery: "mil", month: 'Month' },
  fr: { startShopping: 'Aller faire les courses', addInStore: 'Ajouter', editList: 'Modifier la liste', grandma: "Mamie Ruth", newList: "Nouvelle liste", name: "Nom", save: "Enregistrer", search: "Rechercher ou ajouter", settings: "Paramètres", oldCode: "Créer un code pour un ancien appareil", deviceName: "Nom de l’appareil", createCode: "Créer un code", addMember: "Ajouter un membre", history: "Historique", trolley: "Dans le chariot", household: "Créer une nouvelle famille", signIn: "Continuer par e-mail", papa: "Thomas", daughter: "Emma", wholemeal: /Complet/, kitchenTablet: "Tablette de cuisine", close: "Fermer", shopping: "Courses", kidShopping: "Courses", calendar: "Calendrier", week: "Semaine", newEvent: "Nouvel événement", schedule: "Emploi du temps", scheduleNav: 'École', showMenu: 'Afficher le menu', tasks: "Tâches", meals: "Repas", today: "Aujourd’hui", editSchool: "Modifier l’école", region: "Région", importHolidays: "Importer les vacances scolaires", addMeal: "Ajouter un repas", pairFront: "Connecter une tablette familiale ou un écran mural", pairConnect: "Connecter un appareil", pairCode: "Code du nouvel appareil", next: "Suivant", inviteAdult: "Inviter un adulte", inviteName: "Prénom", inviteCreate: "Créer l’invitation", reminders: "Rappels", advanced: "Avancés", setPassword: "Définir un mot de passe" , enrol: "Connecter avec un code", editTimetable: "Modifier l’emploi du temps", editorSchool: "École du parc", searchQuery: "lai", month: 'Mois' },
  es: { startShopping: 'Ir a comprar', addInStore: 'Añadir', editList: 'Editar lista', grandma: "Abuela Ruth", newList: "Nueva lista", name: "Nombre", save: "Guardar", search: "Buscar o añadir", settings: "Ajustes", oldCode: "Crear un código para un dispositivo antiguo", deviceName: "Nombre del dispositivo", createCode: "Crear código", addMember: "Añadir miembro", history: "Historial", trolley: "En el carrito", household: "Crear una familia nueva", signIn: "Continuar con correo electrónico", papa: "David", daughter: "Olivia", wholemeal: /Integral/, kitchenTablet: "Tableta de la cocina", close: "Cerrar", shopping: "Compra", kidShopping: "Compra", calendar: "Calendario", week: "Semana", newEvent: "Nuevo evento", schedule: "Horario escolar", scheduleNav: 'Colegio', showMenu: 'Mostrar menú', tasks: "Tareas", meals: "Comidas", today: "Hoy", editSchool: "Editar colegio", region: "Región", importHolidays: "Importar vacaciones escolares", addMeal: "Añadir comida", pairFront: "Conectar una tableta familiar o pantalla de pared", pairConnect: "Conectar un dispositivo", pairCode: "Código del nuevo dispositivo", next: "Siguiente", inviteAdult: "Invitar a un adulto", inviteName: "Nombre", inviteCreate: "Crear invitación", reminders: "Recordatorios", advanced: "Avanzados", setPassword: "Establecer contraseña" , enrol: "Conectar con un código", editTimetable: "Editar horario", editorSchool: "Colegio del parque", searchQuery: "lec", month: 'Mes' },
};
// The school setup and the timetable import (specs/24): the first school, the import menu,
// the scan sheet and the structured-text import preview.
const SCHOOL_IMPORT = {
  de: { setupSchool: 'Schule einrichten', schoolName: 'Name der Schule', firstSchool: 'Grundschule Lindenhof', importAction: 'Einlesen…', importFromPhoto: 'Foto scannen', newSubjects: 'Neue Fächer', country: 'Deutschland', state: 'Berlin' },
  en: { setupSchool: 'Set up school', schoolName: 'Name of the school', firstSchool: 'Hollybrook Primary', importAction: 'Read in…', importFromPhoto: 'Scan a photo', newSubjects: 'New subjects', country: 'Germany', state: 'Berlin' },
  fr: { setupSchool: 'Configurer l’école', schoolName: 'Nom de l’école', firstSchool: 'École primaire du Linde', importAction: 'Importer…', importFromPhoto: 'Scanner une photo', newSubjects: 'Nouvelles matières', country: 'Allemagne', state: 'Berlin' },
  es: { setupSchool: 'Configurar colegio', schoolName: 'Nombre del colegio', firstSchool: 'Primaria del tilo', importAction: 'Importar…', importFromPhoto: 'Escanear una foto', newSubjects: 'Asignaturas nuevas', country: 'Alemania', state: 'Berlín' },
};
for (const [lang, labels] of Object.entries(SCHOOL_IMPORT)) Object.assign(T[lang], labels);

// The groups of Einstellungen (the top page) and the rows inside them.
const SETTINGS_GROUPS = {
  de: { gPersonal: 'Persönlich', gFamily: 'Familie', gTasks: 'Aufgaben & Belohnungen', gRituals: 'Rituale', gDevices: 'Geräte', gAccount: 'Konto & Sicherheit', gHelp: 'Hilfe & Info', members: 'Mitglieder', familyProfile: 'Familienprofil' },
  en: { gPersonal: 'Personal', gFamily: 'Family', gTasks: 'Tasks & rewards', gRituals: 'Rituals', gDevices: 'Devices', gAccount: 'Account & security', gHelp: 'Help & about', members: 'Members', familyProfile: 'Family profile' },
  fr: { gPersonal: 'Personnel', gFamily: 'Famille', gTasks: 'Tâches et récompenses', gRituals: 'Rituels', gDevices: 'Appareils', gAccount: 'Compte et sécurité', gHelp: 'Aide et infos', members: 'Membres', familyProfile: 'Profil de la famille' },
  es: { gPersonal: 'Personal', gFamily: 'Familia', gTasks: 'Tareas y recompensas', gRituals: 'Rituales', gDevices: 'Dispositivos', gAccount: 'Cuenta y seguridad', gHelp: 'Ayuda e información', members: 'Miembros', familyProfile: 'Perfil de la familia' },
};
for (const [lang, labels] of Object.entries(SETTINGS_GROUPS)) Object.assign(T[lang], labels);
// The calendar bar's view menu (its tooltip), where the bar has no room for the view buttons.
const CALENDAR_VIEW = { de: 'Kalenderansicht', en: 'Calendar view', fr: 'Vue du calendrier', es: 'Vista del calendario' };
for (const [lang, chooseView] of Object.entries(CALENDAR_VIEW)) T[lang].chooseView = chooseView;

async function open(page, scenario, route = '') {
  // still=1: nothing moves and Wusel's words are fixed, so every run gives the same picture.
  await page.goto(`${base}/?scenario=${scenario}&still=1${route ? `#${route}` : ''}`);
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
const anyNamed = (page, name, exact) => page.getByRole('button', { name, exact }).or(page.getByRole('tab', { name, exact }))
  .or(page.locator(`flt-semantics[aria-label${exact ? '=' : '*='}"${name}"]`));
const tapAny = async (page, name, { exact = true } = {}) => {
  const target = (await anyNamed(page, name, true).count()) ? anyNamed(page, name, true) : anyNamed(page, name, exact);
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
// The Stundenplan in the bottom bar: its full name where it fits, the short one ("Schule") on a phone.
const openSchedule = async (page, t) => {
  await tapAny(page, (await anyNamed(page, t.schedule, true).count()) ? t.schedule : t.scheduleNav);
};
// A school action: a button where the bar has room, an item of the ⋮ menu on a phone.
const schoolAction = async (page, t, name) => {
  const button = anyNamed(page, name, false);
  if (await button.count()) {
    await button.first().dispatchEvent('click');
  } else {
    await page.getByRole('button', { name: t.showMenu, exact: true }).first().dispatchEvent('click');
    await settle(page);
    await page.getByRole('menuitem', { name }).first().click();
  }
  await settle(page);
};
// Reading a timetable in: "Einlesen…" and its menu where the bar has room, the ⋮ menu on a phone.
const importVia = async (page, t, item) => {
  if (await anyNamed(page, t.importAction, true).count()) {
    await tapAny(page, t.importAction);
  } else {
    await page.getByRole('button', { name: t.showMenu, exact: true }).first().dispatchEvent('click');
    await settle(page);
  }
  await page.getByRole('menuitem', { name: item }).first().click();
  await settle(page, 1200);
};
// Opens a group of the Einstellungen top page by its title (a tile with a subtitle, so a substring).
const openGroup = (page, name) => tapAny(page, name, { exact: false });
// The calendar bar (CalendarToolbar) shows the views as buttons where it has room and
// in a menu where it has not, which depends on the viewport and the language. Choose the
// view in whichever the bar shows, then check that it is the selected one: a segment
// reports aria-current, a menu item aria-checked (read by opening the menu once more).
const chooseView = async (page, t, name) => {
  const segment = page.getByRole('banner').getByRole('button', { name, exact: true });
  const menu = page.getByRole('button', { name: t.chooseView, exact: true });
  await segment.or(menu).first().waitFor();
  if (await segment.count()) {
    await segment.first().dispatchEvent('click');
    await settle(page);
    const current = await segment.first().getAttribute('aria-current');
    if (current !== 'true') throw new Error(`calendar view "${name}" is not selected (aria-current=${current})`);
    return;
  }
  const item = page.getByRole('menuitemcheckbox', { name, exact: true });
  await menu.first().dispatchEvent('click');
  await settle(page);
  // A menu item's semantics node is not tappable on the web (no flt-tappable), so it
  // takes a real pointer click; the menu is on screen, unlike a scrolled-away widget.
  await item.first().click();
  await settle(page);
  await menu.first().dispatchEvent('click');
  await settle(page);
  const checked = await item.first().getAttribute('aria-checked');
  // Close it by choosing the view again, not with Escape: a key press switches Flutter to
  // keyboard focus highlights, which would ring the menu button in the picture.
  await item.first().click();
  await page.mouse.move(0, 0);
  await settle(page);
  if (checked !== 'true') throw new Error(`calendar view "${name}" is not selected (aria-checked=${checked})`);
  if (await item.count()) throw new Error('the calendar view menu is still open');
};
const scrollDown = async (page, px = 600) => {
  const vp = page.viewportSize();
  await page.mouse.move(vp.width / 2, vp.height * 0.6);
  await page.mouse.wheel(0, px);
  await settle(page);
};
// Scrolls until a heading is on screen, then brings it near the top. The semantics tree
// keeps nodes that are scrolled away, so the test is the heading's box, not its presence.
// The wheel turns at the left edge, where no control (a stepper, a time field) takes it,
// and the pointer stays there, so no control shows a hover.
const scrollToHeading = async (page, text, top = 90) => {
  const vp = page.viewportSize();
  const heading = page.getByText(text, { exact: true }).first();
  const box = async () => heading.boundingBox({ timeout: 2000 }).catch(() => null);
  const wheel = async (px) => { await page.mouse.move(4, vp.height * 0.6); await page.mouse.wheel(0, px); await settle(page); };
  for (let i = 0; i < 60; i++) {
    const b = await box();
    if (b && b.y >= 0 && b.y < vp.height * 0.8) break;
    await wheel(b && b.y < 0 ? -300 : 600);
  }
  // The wheel does not move the list by exactly its delta, so align in a few steps.
  for (let i = 0; i < 10; i++) {
    const b = await box();
    if (!b || Math.abs(b.y - top) < 30) break;
    await wheel(b.y - top);
  }
};
// Long lists build their semantics lazily: scroll in steps until the control is in the tree.
// `any` looks the way tapAny does (buttons, tabs and plain labels, as a substring), for a
// list tile without a button role.
const scrollUntil = async (page, name, { role = 'button', any = false } = {}) => {
  const loc = any ? anyNamed(page, name, false) : page.getByRole(role, { name, exact: true });
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
const openTimetablePreview = async (p, t) => {
  await openSchedule(p, t);
  await importVia(p, t, t.importFromText);
  // Focus the real editing element before inserting: a fill on a newly created
  // Flutter semantics field can precede its text-input connection.
  await p.getByRole('textbox', { name: t.importPasteHint }).click();
  await settle(p);
  await p.keyboard.insertText(t.timetablePayload);
  await settle(p);
  await press(p, t.importRead, { exact: true });
  await settle(p, 1200);
};

const shots = [
  { name: 'setup-server', scenario: 'server', viewport: PHONE },
  { name: 'setup-start', scenario: 'setup', viewport: PHONE },
  { name: 'setup-sign-in', scenario: 'setup', viewport: PHONE, steps: async (p, t) => press(p, t.signIn) },
  // The adult home opens on the calendar, so the shopping shots first press its nav destination.
  // The list opens in planning (the demo's mode store starts there, though the list has a
  // ticked item); the store shots press "Einkaufen gehen", which opens the trip page.
  { name: 'shopping-phone', scenario: 'adult', viewport: PHONE, steps: async (p, t) => tapAny(p, t.shopping, { exact: false }) },
  { name: 'shopping-store', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await tapAny(p, t.startShopping); } },
  { name: 'shopping-store-add', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await tapAny(p, t.startShopping); await press(p, t.addInStore); await p.mouse.move(0, 0); await settle(p); } },
  { name: 'shopping-search', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await p.getByRole('textbox', { name: t.search }).fill(t.searchQuery); await settle(p); } },
  { name: 'shopping-new-list', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await tapNode(p, 'checkbox', t.newList); } },
  { name: 'shopping-laptop', scenario: 'adult', viewport: TABLET, steps: async (p, t) => tapAny(p, t.shopping, { exact: false }) },
  { name: 'shopping-edit-list', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await press(p, t.editList); await showAdvanced(p, t); } },
  // The item sheet: a tap on a plain row in planning; a long press on a tick row opens it in the trip.
  { name: 'shopping-item-sheet', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await tapAny(p, t.wholemeal, { exact: false }); } },
  // The tick rows (and so the long press on one) are the trip's.
  { name: 'shopping-edit-item', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await tapAny(p, t.startShopping); await longPress(p, p.getByRole('checkbox', { name: t.wholemeal }).first()); } },
  { name: 'shopping-trolley', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await tapAny(p, t.startShopping); await scrollDown(p, 1500); await tapAny(p, t.trolley, { exact: false }); await scrollDown(p, 3000); } },
  { name: 'shopping-history', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.shopping, { exact: false }); await press(p, t.history); await p.getByRole('button', { name: /14/ }).first().click().catch(() => {}); await settle(p); } },
  // Calendar, timetable, tasks, meals and household settings.
  { name: 'calendar-week', scenario: 'adult', viewport: TABLET, steps: async (p, t) => { await tapAny(p, t.calendar); await chooseView(p, t, t.week); } },
  { name: 'calendar-phone', scenario: 'adult', viewport: PHONE, steps: async (p, t) => tapAny(p, t.calendar) },
  // The month view (specs/05 "Views"): wide enough for the bar's view buttons. The demo has
  // the month's public holidays, a birthday and one stretch of Ferien (lib/demo/demo_holidays.dart).
  { name: 'calendar-month', scenario: 'adult', viewport: WALL, steps: async (p, t) => { await tapAny(p, t.calendar); await chooseView(p, t, t.month); } },
  // Neuer Termin opens its tiles first (specs/28); Ohne Vorlage opens the empty editor.
  { name: 'calendar-templates', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.calendar); await tapAny(p, t.newEvent); } },
  { name: 'calendar-editor', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.calendar); await tapAny(p, t.newEvent); await tapAny(p, t.blankEvent, { exact: false }); } },
  { name: 'school-week', scenario: 'adult', viewport: TABLET, steps: async (p, t) => tapAny(p, t.schedule, { exact: false }) },
  { name: 'school-editor', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await openSchedule(p, t); await schoolAction(p, t, t.editTimetable); await press(p, t.editorSchool); await p.mouse.move(2, 2); await settle(p, 1200); } },
  // The adult home opens on Today, the first destination.
  { name: 'today', scenario: 'adult', viewport: PHONE, steps: async (p, t) => tapAny(p, t.today) },
  // The school page's settings icon opens the school form; the region field opens the picker.
  { name: 'region-picker', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await openSchedule(p, t); await schoolAction(p, t, t.editSchool); await tapAny(p, t.region, { exact: false }); } },
  { name: 'holiday-import', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await openSchedule(p, t); await schoolAction(p, t, t.editSchool); await scrollUntil(p, t.importHolidays); await tapNode(p, 'button', t.importHolidays); } },
  // A family without a school (scenario noschool): the first school asks for name and region only.
  { name: 'school-first', scenario: 'noschool', viewport: PHONE, steps: async (p, t) => { await openSchedule(p, t); await tapAny(p, t.setupSchool); await p.getByRole('textbox', { name: t.schoolName }).fill(t.firstSchool); await settle(p); await tapAny(p, t.region, { exact: false }); await tapAny(p, t.country, { exact: false }); await settle(p, 1200); await tapAny(p, t.state, { exact: false }); await settle(p, 1200); } },
  // "Read in…" above the timetable, then "Scan a photo": the sheet with its three choices.
  { name: 'timetable-scan', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await openSchedule(p, t); await importVia(p, t, t.importFromPhoto); } },
  // Structured text opens the preview that the photo scan uses too.
  // The tablet is wide enough for each subject's name under its short name.
  { name: 'timetable-import', scenario: 'adult', viewport: TABLET, steps: openTimetablePreview },
  // The same preview on a phone, scrolled to the new subjects and their take-as list.
  { name: 'timetable-import-subjects', scenario: 'adult', viewport: PHONE, steps: async (p, t) => {
    await openTimetablePreview(p, t);
    const heading = p.getByText(t.newSubjects, { exact: true });
    for (let i = 0; i < 10 && !(await heading.count()); i++) await scrollDown(p, 500);
    for (let i = 0; i < 3; i++) {
      const box = await heading.first().boundingBox();
      if (!box || box.y < 120) break;
      await scrollDown(p, box.y - 72);
    }
  } },
  // The add action is a popup on each day: its name doubles the tooltip, so match it loosely,
  // then pick the first free slot, which opens the meal editor with the suggestions.
  { name: 'meals-suggest', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.meals); await press(p, t.addMeal, { exact: false }); await p.getByRole('menuitem').first().click(); await settle(p, 1200); } },
  { name: 'tasks-today', scenario: 'adult', viewport: TABLET, steps: async (p, t) => tapAny(p, t.tasks, { exact: false }) },
  { name: 'meals-week', scenario: 'adult', viewport: TABLET, steps: async (p, t) => tapAny(p, t.meals, { exact: false }) },
  { name: 'settings-tasks', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await openGroup(p, t.gTasks); } },
  { name: 'kid-who', scenario: 'kid', viewport: TABLET },
  { name: 'kid-shopping', scenario: 'kid', viewport: TABLET, steps: async (p, t) => { await press(p, t.daughter); await tapAny(p, t.kidShopping, { exact: false }); } },
  { name: 'wall-board', scenario: 'kiosk', viewport: WALL },
  { name: 'wall-child-week', scenario: 'kiosk', viewport: WALL, steps: async (p, t) => press(p, new RegExp(`^${t.daughter},`)) },
  { name: 'wall-day', scenario: 'kiosk', viewport: WALL, steps: async (p) => { await p.getByRole('button', { name: /^(Mittwoch|Wednesday|mercredi|miércoles)/i }).first().click(); await settle(p); } },
  // The board has no avatars: open the footer's shopping list first, then tap the name in its bar.
  { name: 'wall-shopping', scenario: 'kiosk', viewport: WALL, steps: async (p, t) => { await p.getByRole('button', { name: t.shopping }).first().click(); await settle(p); await p.getByRole('button', { name: t.daughter, exact: true }).last().click(); await settle(p); } },
  { name: 'settings-phone', scenario: 'adult', viewport: PHONE, steps: async (p, t) => press(p, t.settings) },
  // A member's page (Family, Members, the daughter's row) and the family profile, the latter in the Advanced view.
  { name: 'settings-member', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await openGroup(p, t.gFamily); await tapAny(p, t.members, { exact: false }); await scrollUntil(p, t.daughter, { any: true }); await tapAny(p, t.daughter, { exact: false }); } },
  { name: 'settings-family', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await showAdvanced(p, t); await openGroup(p, t.gFamily); await tapAny(p, t.familyProfile, { exact: false }); } },
  { name: 'settings-sign-in', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await showAdvanced(p, t); await openGroup(p, t.gAccount); await scrollUntil(p, t.setPassword); } },
  // A guardian's phone approves new devices (pair-approve); the code is the way for an older device.
  { name: 'settings-code', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await showAdvanced(p, t); await openGroup(p, t.gDevices); await scrollUntil(p, t.oldCode); await tapAny(p, t.oldCode); await p.getByRole('textbox', { name: t.deviceName }).fill(t.kitchenTablet); await press(p, t.createCode); } },
  { name: 'new-family', scenario: 'newfamily', viewport: PHONE },
  // The new device's pairing screen, reached from the front door.
  { name: 'pair-device', scenario: 'setup', viewport: PHONE, steps: async (p, t) => press(p, t.pairFront) },
  // A guardian's phone: enter the code the new device shows, then review it before approving.
    // Opened at the pairing route (the Settings → Devices button is far down the list in English).
  { name: 'pair-approve', scenario: 'adult', viewport: PHONE, route: '/settings/devices/pair', steps: async (p, t) => { await p.getByRole('textbox', { name: t.pairCode }).fill('K7QM3XRP'); await press(p, t.next); } },
  // Inviting an adult: the name, then the result sheet with the code, QR code and share action.
  { name: 'invite-sheet', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await openGroup(p, t.gFamily); await tapAny(p, t.members, { exact: false }); await scrollUntil(p, t.inviteAdult); await tapAny(p, t.inviteAdult, { exact: false }); await p.getByRole('textbox', { name: t.inviteName }).fill(t.grandma); await press(p, t.inviteCreate); } },
  // Reminders sit in the Personal group, under Notifications.
  { name: 'reminders', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await press(p, t.settings); await openGroup(p, t.gPersonal); await scrollUntil(p, t.reminders, { any: true }); await tapAny(p, t.reminders, { exact: false }); } },
  // Siri and Shortcuts: the keys of the family, one in use and one not yet.
  { name: 'shortcuts', scenario: 'adult', viewport: PHONE, route: '/settings/shortcuts' },
  // A lighter day (specs/25–27). still=1 fixes Wusel's words. The Tischfrage and the
  // Wochenrückblick depend on the time of day, so no shot waits for them.
  // The daughter's day on the kid tablet: Wusel's greeting, her countdowns and her meal wish.
  { name: 'kid-today', scenario: 'kid', viewport: TABLET, steps: async (p, t) => press(p, t.daughter) },
  // The meal plan with the children's wishes above the week.
  { name: 'meals-wishes', scenario: 'adult', viewport: PHONE, steps: async (p, t) => tapAny(p, t.meals) },
  // The event editor's last fields: the picture, "looking forward" and the family tradition.
  { name: 'calendar-rituals', scenario: 'adult', viewport: PHONE, steps: async (p, t) => {
    await tapAny(p, t.calendar); await tapAny(p, t.newEvent); await tapAny(p, t.blankEvent, { exact: false });
    await scrollUntil(p, t.tradition, { any: true }); await tapAny(p, t.tradition, { exact: false });
    await scrollDown(p, 3000); await p.mouse.move(386, 840); await settle(p);
  } },
  // Kalender → Neue Tradition: the six starters and the family's own.
  { name: 'calendar-tradition', scenario: 'adult', viewport: PHONE, steps: async (p, t) => { await tapAny(p, t.calendar); await tapAny(p, t.newEvent); await tapAny(p, t.newTradition, { exact: false }); } },
  // Further down the kid's day: her meal wish card.
  { name: 'kid-wish', scenario: 'kid', viewport: TABLET, steps: async (p, t) => { await press(p, t.daughter); await scrollToHeading(p, t.wishTitle, 360); } },
  // The Rituals group of the Einstellungen, Advanced: the table question and its times.
  { name: 'settings-rituals', scenario: 'adult', viewport: PHONE, steps: async (p, t) => {
    await press(p, t.settings); await showAdvanced(p, t); await openGroup(p, t.gRituals);
  } },
  // The Personal group: Wusel and the outfit picker.
  { name: 'settings-wusel', scenario: 'adult', viewport: PHONE, steps: async (p, t) => {
    await press(p, t.settings); await showAdvanced(p, t); await openGroup(p, t.gPersonal);
  } },
];
const RITUALS = {
  de: { tradition: 'Familientradition', newTradition: 'Neue Tradition', wishTitle: 'Dein Wunschessen', blankEvent: 'Ohne Vorlage' },
  en: { tradition: 'Family tradition', newTradition: 'New tradition', wishTitle: 'Your meal wish', blankEvent: 'Start blank' },
  fr: { tradition: 'Tradition familiale', newTradition: 'Nouvelle tradition', wishTitle: 'Ton repas préféré', blankEvent: 'Sans modèle' },
  es: { tradition: 'Tradición familiar', newTradition: 'Nueva tradición', wishTitle: 'Tu comida favorita', blankEvent: 'Sin plantilla' },
};
for (const [lang, labels] of Object.entries(RITUALS)) Object.assign(T[lang], labels);

// Preview fixtures enter through the same paste sheet as a family's structured text.
const IMPORT_SAMPLES = {
  de: { member: 'Paul', codes: ['D', 'Ma', 'Mu', 'Sp', 'Sw', 'Ku', 'SU'], other: ['HSU', 'Heimat- und Sachunterricht'], added: ['E', 'Englisch'], care: 'Hort' },
  en: { member: 'Jack', codes: ['En', 'Ma', 'Mu', 'PE', 'Sw', 'Art', 'Top'], other: ['Geo', 'Geography'], added: ['Fr', 'French'], care: 'After-school club' },
  fr: { member: 'Paul', codes: ['Al', 'Ma', 'Mus', 'EPS', 'Nat', 'Arts', 'Déc'], other: ['QLM', 'Questionner le monde'], added: ['Ang', 'Anglais'], care: 'Accueil périscolaire' },
  es: { member: 'Pablo', codes: ['Ale', 'Mat', 'Mús', 'EF', 'Nat', 'Plás', 'Con'], other: ['CM', 'Conocimiento del Medio'], added: ['Ing', 'Inglés'], care: 'Cuidado extraescolar' },
};
for (const [lang, sample] of Object.entries(IMPORT_SAMPLES)) {
  const l10n = JSON.parse(fs.readFileSync(`app/l10n/app_${lang}.arb`, 'utf8'));
  const [d, ma, mu, sport, swim, art, topic] = sample.codes;
  const other = { subject: sample.other[0], name: sample.other[1], like: topic };
  const added = { subject: sample.added[0], name: sample.added[1] };
  Object.assign(T[lang], {
    importFromText: l10n.schoolImportFromText,
    importPasteHint: l10n.schoolImportPasteHint,
    importRead: l10n.schoolImportRead,
    timetablePayload: JSON.stringify({
      format: 'wuselwall-timetable/1', member: sample.member, school: T[lang].firstSchool,
      week_cycle: 'weekly',
      grid: { 1: [d, ma, other, sport], 2: [ma, d, mu, added, other], 3: [swim, swim, d, ma], 4: [d, ma, other, mu, sport], 5: [ma, d, art, art, added] },
      care: [{ title: sample.care, days: [1, 2, 4], starts: '12:45', ends: '15:00' }],
    }),
  });
}

const only = process.argv.slice(2);
const SHOT_TIMEOUT = 120_000;
// Software GL: headless Chromium has no GPU here, and CanvasKit needs WebGL.
const browser = await chromium.launch({
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
let failed = 0;
for (const lang of langs) {
  fs.mkdirSync(path.join(out, lang), { recursive: true });
  for (const shot of shots) {
    if (only.length && !only.includes(shot.name)) continue;
    const ctx = await browser.newContext({
      viewport: shot.viewport, deviceScaleFactor: 2, locale: LOCALES[lang],
      colorScheme: 'light', timezoneId: 'Europe/Berlin',
    });
    const page = await ctx.newPage();
    try {
      await open(page, shot.scenario, shot.route);
      if (shot.steps) await shot.steps(page, T[lang]);
    } catch (e) {
      failed++;
      console.warn(`! ${lang}/${shot.name}: ${e.message}`);
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
  // A failed step must never look like a successful screenshot export.
  process.exitCode = 1;
}
