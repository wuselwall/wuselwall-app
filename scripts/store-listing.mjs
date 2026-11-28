// Renders the store listings' images from the app icon and the docs screenshots, into
// fastlane's layouts next to the listing texts; store-listing.yml uploads them:
//   npm run docs:screenshots   # the guide shots this script frames
//   node docs/tools/screenshots.mjs today-event calendar-picture kid-school-day-phone
//   npm run store:listing
// Set SHOT_OUT to the same directory used by the capture script for exported shots.
// Google Play (supply, app/android/fastlane/metadata/android/<locale>/images), per locale:
// icon.png (512×512), featureGraphic.png (1024×500), phone screenshots (1080×1920) and
// tablet screenshots (1920×1080, used for both 7- and 10-inch).
// App Store (deliver, app/ios/fastlane/screenshots/<locale>), per locale: iPhone 6.9″
// (1320×2868) and iPad 13″ (2752×2064) screenshots, the two sizes App Store Connect
// requires; it scales them down for the smaller devices.
// The stores want screenshots without alpha, so every image is flattened onto the paper
// colour. Screenshots are named <locale>_<device>_<n>_<shot>.png (de_DE_phone_1_today.png),
// underscores only, so a file is recognisable outside its folder; the number keeps the
// store's order. icon.png and featureGraphic.png keep the names fastlane supply expects.
import { access, mkdir, readFile, rm } from 'node:fs/promises';
import path from 'node:path';
import { chromium } from 'playwright';
import sharp from 'sharp';

const root = path.resolve('.');
const shots = path.resolve(process.env.SHOT_OUT || 'docs/public/screenshots');
const meta = path.join(root, 'app/android/fastlane/metadata/android');
const appStoreShots = path.join(root, 'app/ios/fastlane/screenshots');
const font = (f) => readFile(path.join(root, 'app/assets/fonts', f)).then((b) => b.toString('base64'));
const fonts = `
  @font-face { font-family: Atkinson; font-weight: 400; src: url(data:font/ttf;base64,${await font('AtkinsonHyperlegibleNext-Regular.ttf')}); }
  @font-face { font-family: Atkinson; font-weight: 600; src: url(data:font/ttf;base64,${await font('AtkinsonHyperlegibleNext-SemiBold.ttf')}); }
  @font-face { font-family: Atkinson; font-weight: 800; src: url(data:font/ttf;base64,${await font('AtkinsonHyperlegibleNext-ExtraBold.ttf')}); }`;
const logo = (await readFile(path.join(root, 'docs/public/logo.svg'))).toString('base64');
// The ground, ink and accent of the app's standard light theme (Palette.frisch, specs/17).
const paper = '#f5f9f5', ink = '#1c1f23', tanne = '#177148';

/** Captions per locale; the shot names are those of docs/tools/screenshots.mjs. */
const copy = {
  'de-DE': {
    lang: 'de',
    feature: { title: 'Alles, was bei euch zuhause wuselt – an einer Wand.', sub: 'Open Source · Auf eurem eigenen Server' },
    phone: [
      ['today-event', 'Der Tag auf einen Blick', 'Termine, Familienpläne und Einkaufsliste'],
      ['calendar-picture', 'Termine mit Bildern', 'Beim Tippen schlägt WuselWall ein passendes Bild vor'],
      ['search', 'Schnell gefunden', 'Termine, Rezepte, Aufgaben, Einkäufe und Einstellungen'],
      ['kid-school-day-phone', 'Meine nächsten Tage', 'Schule, Termine und Packliste für Kinder unter zwölf'],
      ['shopping-phone', 'Eine Einkaufsliste für alle', 'Nach Abteilungen sortiert, auch ohne Netz'],
      ['meals-suggest', 'Was gibt es diese Woche?', 'Vorschläge aus dem, was ihr schon gekocht habt'],
      ['settings-code', 'Das Küchen-Tablet verbinden', 'Ein neues Gerät per Kopplungscode hinzufügen'],
      ['setup-server', 'Auf eurem eigenen Server', 'Oder ohne Server mit einer Beispielfamilie ausprobieren'],
    ],
    tablet: [
      ['wall-board', 'Die Woche an der Küchenwand', 'Wer ist wo, was steht an, was gibt es zu essen'],
      ['wall-child-week', 'Stundenpläne mit Vertretungen', 'Ein Tipp auf ein Kind zeigt seine Woche'],
      ['tasks-today', 'Aufgaben mit Punkten', 'Belohnungen statt Strafen, keine Rangliste'],
      ['meals-week', 'Der Essensplan der Woche', 'Die Zutaten landen auf der Einkaufsliste'],
      ['calendar-week', 'Der Familienkalender', 'Jede Person in ihrer Farbe'],
      ['kid-shopping', 'Eine Ansicht für die Kinder', 'Große Knöpfe, kein Konto, keine E-Mail'],
    ],
  },
  'en-US': {
    lang: 'en',
    feature: { title: 'Everything that bustles around your home – on one wall.', sub: 'Open source · On your own server' },
    phone: [
      ['today-event', 'Your day at a glance', 'Events, family plans and the shopping list'],
      ['calendar-picture', 'Give events a picture', 'WuselWall suggests a picture as you type a title'],
      ['search', 'Find it in one search', 'Events, recipes, chores, shopping items and settings'],
      ['kid-school-day-phone', 'My next few days', 'School, events and what to pack for children under 12'],
      ['shopping-phone', 'One shopping list for everyone', 'Sorted by aisle, works offline'],
      ['meals-suggest', "What's for dinner this week?", "Suggestions from what you've cooked before"],
      ['settings-code', 'Connect the kitchen tablet', 'Add a new device with a pairing code'],
      ['setup-server', 'On your own server', 'Or try it without one, with a sample family'],
    ],
    tablet: [
      ['wall-board', 'The week on the kitchen wall', "Who is where, what's coming up, what's for dinner"],
      ['wall-child-week', 'Timetables with substitutions', "Tap a child to see their week"],
      ['tasks-today', 'Chores with points', 'Rewards instead of penalties, no leaderboard'],
      ['meals-week', "The week's meal plan", 'Ingredients go straight to the shopping list'],
      ['calendar-week', 'The family calendar', 'Every person in their own colour'],
      ['kid-shopping', 'A view for the children', 'Big buttons, no account, no email'],
    ],
  },
  'fr-FR': {
    lang: 'fr',
    feature: { title: 'Toute la vie de la maison, sur un seul mur.', sub: 'Open source · Sur votre propre serveur' },
    phone: [
      ['today-event', 'La journée d’un coup d’œil', 'Rendez-vous, projets de famille et liste de courses'],
      ['calendar-picture', 'Des rendez-vous en images', 'WuselWall propose une image pendant la saisie du titre'],
      ['search', 'Tout retrouver au même endroit', 'Rendez-vous, recettes, tâches, courses et paramètres'],
      ['kid-school-day-phone', 'Mes prochains jours', 'École, rendez-vous et affaires à prévoir pour les moins de 12 ans'],
      ['shopping-phone', 'Une liste de courses pour tous', 'Classée par rayon, même sans connexion'],
      ['meals-suggest', 'On mange quoi cette semaine ?', 'Des idées tirées de ce que vous avez déjà cuisiné'],
      ['settings-code', 'Connectez la tablette de la cuisine', 'Ajoutez un appareil grâce à un code de jumelage'],
      ['setup-server', 'Sur votre propre serveur', 'Ou essayez sans serveur, avec une famille d’exemple'],
    ],
    tablet: [
      ['wall-board', 'La semaine sur le mur de la cuisine', 'Qui est où, ce qui arrive, ce qu’on mange'],
      ['wall-child-week', 'Emplois du temps avec remplacements', 'Touchez un enfant pour voir sa semaine'],
      ['tasks-today', 'Des tâches et des points', 'Des récompenses plutôt que des punitions, sans classement'],
      ['meals-week', 'Les menus de la semaine', 'Les ingrédients rejoignent la liste de courses'],
      ['calendar-week', 'Le calendrier familial', 'Chaque personne a sa couleur'],
      ['kid-shopping', 'Une vue pour les enfants', 'De grands boutons, ni compte ni e-mail'],
    ],
  },
  'es-ES': {
    lang: 'es',
    feature: { title: 'Todo lo que se mueve en casa, en una sola pared.', sub: 'Código abierto · En vuestro propio servidor' },
    phone: [
      ['today-event', 'El día de un vistazo', 'Citas, planes familiares y lista de la compra'],
      ['calendar-picture', 'Citas con imágenes', 'WuselWall sugiere una imagen al escribir el título'],
      ['search', 'Todo en una búsqueda', 'Citas, recetas, tareas, productos de la compra y ajustes'],
      ['kid-school-day-phone', 'Mis próximos días', 'Colegio, citas y qué llevar para menores de 12 años'],
      ['shopping-phone', 'Una lista de la compra para todos', 'Ordenada por secciones, también sin conexión'],
      ['meals-suggest', '¿Qué comemos esta semana?', 'Sugerencias a partir de lo que ya habéis cocinado'],
      ['settings-code', 'Conectad la tableta de la cocina', 'Añadid un dispositivo con un código de vinculación'],
      ['setup-server', 'En vuestro propio servidor', 'O probadla sin servidor, con una familia de ejemplo'],
    ],
    tablet: [
      ['wall-board', 'La semana en la pared de la cocina', 'Quién está dónde, qué viene, qué hay de comer'],
      ['wall-child-week', 'Horarios con suplencias', 'Al tocar a un niño se ve su semana'],
      ['tasks-today', 'Tareas con puntos', 'Recompensas en lugar de castigos, sin clasificación'],
      ['meals-week', 'El plan de comidas de la semana', 'Los ingredientes pasan a la lista de la compra'],
      ['calendar-week', 'El calendario familiar', 'Cada persona con su color'],
      ['kid-shopping', 'Una vista para los niños', 'Botones grandes, sin cuenta ni correo'],
    ],
  },
};

const shotPath = (lang, name) => path.join(shots, lang, `${name}.png`);
const shot = async (lang, name) => (await readFile(shotPath(lang, name))).toString('base64');

// Check all inputs before replacing any of the committed store images.
for (const c of Object.values(copy)) {
  for (const [name] of [...c.phone, ...c.tablet]) {
    const input = shotPath(c.lang, name);
    try {
      await access(input);
    } catch (cause) {
      throw new Error(`Could not read ${input}. Run npm run docs:screenshots or set SHOT_OUT to your capture directory.`, { cause });
    }
  }
}
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
const page = (w, h, body) => `<!doctype html><html><head><style>${fonts}
  * { box-sizing: border-box; } body { margin: 0; width: ${w}px; height: ${h}px; overflow: hidden; background: ${paper};
  font-family: Atkinson, sans-serif; color: ${ink}; }</style></head><body>${body}</body></html>`;

/** A caption band above a framed screenshot, scaled (up, if need be) to fit the space below. */
const framed = (w, h, img, title, sub, { pad, titleSize, frame }) => page(w, h, `
  <div style="height:100%;display:flex;flex-direction:column;align-items:center;padding:${pad}px ${pad}px 0">
    <div style="font-size:${titleSize}px;font-weight:800;line-height:1.15;text-align:center;letter-spacing:-.01em">${esc(title)}</div>
    <div style="margin-top:${titleSize * 0.35}px;font-size:${titleSize * 0.52}px;font-weight:600;color:${tanne};text-align:center">${esc(sub)}</div>
    <div style="flex:1;min-height:0;display:flex;align-items:flex-start;justify-content:center;margin-top:${pad * 0.8}px;width:100%">
      <img src="data:image/png;base64,${img}" onload="const b = this.parentElement;
        const s = Math.min((b.clientWidth - ${2 * frame}) / this.naturalWidth, b.clientHeight / this.naturalHeight);
        this.style.width = this.naturalWidth * s + ${2 * frame} + 'px'" style="display:block;
        border:${frame}px solid ${ink};border-bottom:0;border-radius:${frame * 3}px ${frame * 3}px 0 0;
        box-shadow:0 24px 60px -16px rgba(28,31,35,.35)">
    </div>
  </div>`);

const shotFile = (locale, device, i, name) => `${locale}_${device}_${i + 1}_${name}.png`.replaceAll('-', '_');

const flatten = (buf, file) => sharp(buf).flatten({ background: paper }).removeAlpha().png().toFile(file);

const browser = await chromium.launch();
const tab = await browser.newPage();
const render = async (w, h, html, file) => {
  await tab.setViewportSize({ width: w, height: h });
  await tab.setContent(html, { waitUntil: 'load' });
  await tab.evaluate(() => document.fonts.ready);
  await flatten(await tab.screenshot(), file);
};

for (const [locale, c] of Object.entries(copy)) {
  const out = path.join(meta, locale, 'images');
  await rm(out, { recursive: true, force: true });
  for (const d of ['phoneScreenshots', 'sevenInchScreenshots', 'tenInchScreenshots']) await mkdir(path.join(out, d), { recursive: true });

  // The launcher icon, full-bleed: Play rounds the corners itself.
  await sharp(path.join(root, 'app/assets/icon/icon.png')).resize(512, 512).png().toFile(path.join(out, 'icon.png'));

  // The feature graphic: Play may crop it and lay its own play button on top, so the
  // text keeps to the left and nothing important touches the edges.
  const board = await shot(c.lang, 'wall-board');
  await render(1024, 500, page(1024, 500, `
    <div style="position:absolute;left:56px;top:0;bottom:0;width:430px;display:flex;flex-direction:column;justify-content:center">
      <div style="display:flex;align-items:center;gap:14px;font-weight:800;font-size:36px">
        <img src="data:image/svg+xml;base64,${logo}" width="60" height="60">WuselWall</div>
      <div style="margin-top:26px;font-size:34px;font-weight:800;line-height:1.15;letter-spacing:-.01em">${esc(c.feature.title)}</div>
      <div style="margin-top:20px;font-size:19px;color:${tanne};font-weight:600">${esc(c.feature.sub)}</div>
    </div>
    <div style="position:absolute;left:530px;top:70px;width:620px;background:${ink};border-radius:20px;padding:10px;
      box-shadow:0 20px 50px -12px rgba(28,31,35,.35)">
      <img src="data:image/png;base64,${board}" style="display:block;width:100%;border-radius:10px"></div>`),
    path.join(out, 'featureGraphic.png'));

  for (const [i, [name, title, sub]] of c.phone.entries()) {
    await render(1080, 1920, framed(1080, 1920, await shot(c.lang, name), title, sub, { pad: 96, titleSize: 68, frame: 18 }),
      path.join(out, 'phoneScreenshots', shotFile(locale, 'phone', i, name)));
  }
  for (const [i, [name, title, sub]] of c.tablet.entries()) {
    const file = path.join(out, 'tenInchScreenshots', shotFile(locale, 'tablet_10in', i, name));
    await render(1920, 1080, framed(1920, 1080, await shot(c.lang, name), title, sub, { pad: 64, titleSize: 56, frame: 16 }), file);
    await sharp(file).toFile(path.join(out, 'sevenInchScreenshots', shotFile(locale, 'tablet_7in', i, name)));
  }
  console.log('wrote', path.relative(root, out));

  // The same captions at Apple's sizes: the iPhone is taller than Play's 9:16, the iPad 4:3.
  const ios = path.join(appStoreShots, locale);
  await rm(ios, { recursive: true, force: true });
  await mkdir(ios, { recursive: true });
  for (const [i, [name, title, sub]] of c.phone.entries()) {
    await render(1320, 2868, framed(1320, 2868, await shot(c.lang, name), title, sub, { pad: 70, titleSize: 83, frame: 22 }),
      path.join(ios, shotFile(locale, 'iphone', i, name)));
  }
  for (const [i, [name, title, sub]] of c.tablet.entries()) {
    await render(2752, 2064, framed(2752, 2064, await shot(c.lang, name), title, sub, { pad: 92, titleSize: 80, frame: 23 }),
      path.join(ios, shotFile(locale, 'ipad', i, name)));
  }
  console.log('wrote', path.relative(root, ios));
}
await browser.close();
