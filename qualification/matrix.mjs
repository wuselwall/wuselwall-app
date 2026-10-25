import fs from 'node:fs';
import path from 'node:path';

export const root = path.resolve(import.meta.dirname, '..');
export const inventory = JSON.parse(fs.readFileSync(path.join(root, 'qualification/inventory.json'), 'utf8'));

export function cases(profile = 'canonical', data = inventory) {
  if (!['smoke', 'canonical', 'responsive', 'full'].includes(profile)) throw new Error(`Unknown matrix: ${profile}`);
  const result = [];
  for (const state of data.states) {
    if (profile === 'smoke' && !['today', 'shopping', 'settings'].includes(state.id)) continue;
    for (const locale of profile === 'smoke' ? ['de'] : data.locales) {
      const primary = state.scenario === 'kiosk' ? 1280 : state.scenario === 'kid' ? 820 : 390;
      const add = (tier, width, shade) => {
        const height = width === 1920 ? 1080 : state.scenario === 'kiosk' ? 800 : width >= 768 ? 1024 : 844;
        result.push({ ...state, locale, shade, width, height, tier,
          caseId: `${state.id}-${locale}-${shade}-${width}x${height}-${tier}` });
      };
      if (profile !== 'responsive') {
        for (const shade of profile === 'smoke' ? ['light'] :
          state.scenario === 'kiosk' ? [...data.shades, 'night'] : data.shades) add('canonical', primary, shade);
      }
      if (['responsive', 'full'].includes(profile)) {
        for (const width of state.widths) add('responsive', width, 'light');
      }
    }
  }
  return result;
}

export function checkInventory(data = inventory) {
  const ids = data.states.map(s => s.id);
  if (new Set(ids).size !== ids.length || !ids.length) throw new Error('Duplicate or empty inventory');
  for (const s of data.states) {
    if (!/^[a-z][a-z0-9-]*$/.test(s.id) || !s.widget || !s.widths?.length || !s.route?.startsWith('/')) {
      throw new Error(`Invalid inventory state: ${s.id}`);
    }
    for (const lang of data.locales) {
      const arb = JSON.parse(fs.readFileSync(path.join(root, `app/l10n/app_${lang}.arb`), 'utf8'));
      if (s.titleKey && typeof arb[s.titleKey] !== 'string') throw new Error(`${s.id}: missing ${lang}/${s.titleKey}`);
    }
  }
  const routes = [...fs.readFileSync(path.join(root, 'app/lib/app/router.dart'), 'utf8')
    .split('static bool isSetup')[0].matchAll(/static const (\w+) = '([^']+)';/g)];
  for (const [, name, route] of routes) {
    if (data.states.some(s => s.route === route)) continue;
    if (data.pendingRoutes[name]?.route !== route || !data.pendingRoutes[name]?.reason) {
      throw new Error(`Unaccounted route: ${name} (${route})`);
    }
  }
  return { states: ids.length, cases: cases('full', data).length, pendingRoutes: Object.keys(data.pendingRoutes).length };
}

if (process.argv[1] === path.join(import.meta.dirname, 'matrix.mjs')) console.log(checkInventory(), cases(process.argv[2]).length);
