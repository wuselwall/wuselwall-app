import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import test from 'node:test';
import { TAGS } from './dictionary.mjs';
import {
  KINDS,
  checkDuplicates,
  iconFor,
  load,
  parseStarter,
  render,
  renderJson,
  sectionNames,
} from './starter.mjs';

const root = new URL('../', import.meta.url);
const read = (file) => readFileSync(new URL(file, root), 'utf8');

const SAMPLE = `
# a comment
[supermarket]   # the kind
produce:
  de: Bananen, Äpfel, Karotten, Paprika, Tomaten
  de-CH: Karotten = Rüebli, Paprika = Peperoni, + Nüsslisalat
  de-AT: Tomaten = Paradeiser
  en: bananas, apples
dairy:
  de: Milch, Butter
  de-CH: Butter = Anke
  en: milk, butter
  fr: lait, beurre
`;
const words = new Map([
  ['banane', 'banana'], ['bananen', 'banana'], ['milch', 'milk'], ['milk', 'milk'], ['jus d orange', 'juice'],
  ['saft', 'juice'], ['rueebli', 'carrot'], ['karotten', 'carrot'], ['milchreis', 'rice'], ['reis', 'rice'],
  ['ei', 'egg'], ['eier', 'egg'],
]);

test('parses kinds, sections in order, tags and comments', () => {
  const [kind] = parseStarter(SAMPLE);
  assert.equal(kind.kind, 'supermarket');
  assert.deepEqual(kind.sections.map((s) => s.category), ['produce', 'dairy']);
  assert.deepEqual(kind.sections[0].tags.de.entries, ['Bananen', 'Äpfel', 'Karotten', 'Paprika', 'Tomaten']);
  assert.deepEqual(kind.sections[0].tags['de-CH'].entries, [
    { base: 'Karotten', regional: 'Rüebli' },
    { base: 'Paprika', regional: 'Peperoni' },
    { add: 'Nüsslisalat' },
  ]);
  assert.equal(kind.sections[1].tags.fr.entries[1], 'beurre');
});

test('overrides replace in place, additions append, the other regional list follows de', () => {
  const [kind] = parseStarter(SAMPLE);
  const produce = kind.sections[0];
  assert.deepEqual(sectionNames(produce, 'de-CH'), ['Bananen', 'Äpfel', 'Rüebli', 'Peperoni', 'Tomaten', 'Nüsslisalat']);
  assert.deepEqual(sectionNames(produce, 'de-AT'), ['Bananen', 'Äpfel', 'Karotten', 'Paprika', 'Paradeiser']);
  assert.deepEqual(sectionNames(kind.sections[1], 'de-AT'), ['Milch', 'Butter']);
  assert.deepEqual(sectionNames(kind.sections[1], 'es'), []);
});

test('rejects invalid sources with file:line', () => {
  const cases = [
    ['[garage]\nother:\n de: a\n en: a', /unknown list kind "garage"/],
    ['[drugstore]\nproduce:\n de: a\n en: a', /"produce" is not a seeded category of drugstore/],
    ['[supermarket]\ndairy:\n de: a\n en: a\nproduce:\n de: b\n en: b', /out of walking order/],
    ['[supermarket]\nproduce:\n de: a\n en: a\nproduce:\n de: b\n en: b', /duplicate section "produce"/],
    ['[supermarket]\nproduce:\n de: a\n fr: a', /no "en" line/],
    ['[supermarket]\nproduce:\n en: a\n de: a\n xx: b', /unknown tag or category "xx"/],
    ['[supermarket]\nproduce:\n de: a, , b\n en: a', /empty name/],
    ['[supermarket]\nproduce:\n de: a\n de: b\n en: a', /duplicate "de" line/],
    ['[supermarket]\nproduce:\n de: a\n en: a = b', /only de-CH and de-AT take overrides/],
    ['[supermarket]\nproduce:\n de: a\n de-CH: b\n en: a', /takes "base = regional"/],
    ['[supermarket]\nproduce:\n de: a\n de-CH: x = y\n en: a', /"x" is not a name in the de list/],
    ['[supermarket]\nproduce:\n de: a\n de-CH: a = b, a = c\n en: a', /overridden twice/],
    ['de: a', /before any section/],
  ];
  for (const [text, message] of cases) {
    assert.throws(() => parseStarter(text, 't.txt'), message, text);
  }
  assert.throws(() => parseStarter('[supermarket]\nbad line', 't.txt'), /t\.txt:2: not a section or tag line/);
});

test('a name is allowed once per kind and tag, also after the overrides', () => {
  const dup = (de) => parseStarter(`[supermarket]\nproduce:\n  de: ${de}\n  en: a, b\ndairy:\n  de: Milch\n  en: milk\n`);
  assert.doesNotThrow(() => checkDuplicates(dup('Brot, Apfel')));
  assert.throws(() => checkDuplicates(dup('Brot, brot')), /"brot" appears twice|"brot".*twice/i);
  assert.throws(() => checkDuplicates(dup('Brot, Milch')), /"Milch" appears twice \(produce and dairy\)/);
  const clash = parseStarter('[supermarket]\nproduce:\n  de: Eis, Glace\n  de-CH: Eis = Glace\n  en: ice, glaze');
  assert.throws(() => checkDuplicates(clash), /de-CH: "Glace" appears twice/);
});

test('icon rule: whole phrase, then last word, then the longest known word the last word ends with', () => {
  assert.equal(iconFor('Jus d\'orange', words), 'juice');
  assert.equal(iconFor('Milch', words), 'milk');
  assert.equal(iconFor('Bio-Milch', words), 'milk');
  assert.equal(iconFor('Rüebli', words), 'carrot');
  assert.equal(iconFor('Vollmilch', words), 'milk');
  assert.equal(iconFor('Milchreis', words), 'rice', 'the whole name wins over its suffix');
  assert.equal(iconFor('Hafermilchreis', words), 'rice', 'longest suffix: reis, not ei');
  assert.equal(iconFor('Freilandeier', words), 'egg');
  assert.equal(iconFor('zz', words), null, 'under three letters never matches by suffix');
  assert.equal(iconFor('Kleiderbügel', words), null);
  assert.equal(iconFor('', words), null);
});

test('rendered JSON has the documented shape', () => {
  const kinds = parseStarter(SAMPLE);
  const { json, unmatched } = render(kinds, words);
  assert.deepEqual(Object.keys(json), ['version', 'source', 'kinds']);
  assert.equal(json.version, 1);
  const supermarket = json.kinds.supermarket;
  assert.deepEqual(supermarket.categories, ['produce', 'dairy']);
  assert.deepEqual(Object.keys(supermarket.items), TAGS);
  assert.deepEqual(supermarket.items.de[0], { name: 'Bananen', category: 'produce', icon: 'banana' });
  assert.deepEqual(supermarket.items['de-CH'][2], { name: 'Rüebli', category: 'produce', icon: 'carrot' });
  assert.equal(supermarket.items.de.at(-1).category, 'dairy');
  assert.deepEqual(supermarket.items.fr, [
    { name: 'lait', category: 'dairy', icon: null },
    { name: 'beurre', category: 'dairy', icon: null },
  ]);
  assert.ok(unmatched.some((u) => u.name === 'Äpfel' && u.tag === 'de'));
  assert.deepEqual(JSON.parse(renderJson(json)), json);
  assert.ok(renderJson(json).endsWith('}\n'));
});

test('the real source parses and every rendered category is a seeded category in walking order', () => {
  const { kinds, json } = load();
  assert.deepEqual(Object.keys(json.kinds).sort(), Object.keys(KINDS).sort());
  for (const [kind, rendered] of Object.entries(json.kinds)) {
    const seeded = KINDS[kind];
    let last = -1;
    for (const c of rendered.categories) {
      const at = seeded.indexOf(c);
      assert.ok(at > last, `${kind}: ${c} is not in walking order ${seeded}`);
      last = at;
    }
    for (const tag of TAGS) {
      assert.ok(rendered.items[tag].length > 0, `${kind} ${tag} is empty`);
      let previous = -1;
      for (const item of rendered.items[tag]) {
        const at = rendered.categories.indexOf(item.category);
        assert.ok(at >= previous, `${kind} ${tag}: ${item.name} is out of category order`);
        previous = at;
        assert.ok(item.icon === null || typeof item.icon === 'string');
      }
    }
  }
  for (const k of kinds) {
    const de = json.kinds[k.kind].items.de.length;
    assert.equal(json.kinds[k.kind].items['de-CH'].length, de + k.sections.reduce((n, s) => n + (s.tags['de-CH']?.entries.filter((e) => e.add).length ?? 0), 0));
    assert.equal(json.kinds[k.kind].items['de-AT'].length, de);
  }
});

test('the kinds seeded here are the ones the latest migration seeds', () => {
  const dir = new URL('supabase/migrations/', root);
  const files = readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();
  const latest = files.reverse().find((f) => /create (or replace )?function app\.shopping_seed_categories/.test(readFileSync(new URL(f, dir), 'utf8')));
  assert.ok(latest, 'a migration defines app.shopping_seed_categories');
  const sql = readFileSync(new URL(latest, dir), 'utf8');
  const seeded = {};
  for (const m of sql.matchAll(/when '([a-z_]+)'\s+then array\[([^\]]*)\]/g)) {
    seeded[m[1]] = [...m[2].matchAll(/'([a-z_]+)'/g)].map((x) => x[1]);
  }
  assert.deepEqual(seeded, KINDS);
});

test('the committed source stays inside the size the catalogue is meant to have', () => {
  const { json } = load();
  const count = (kind) => json.kinds[kind].items.de.length;
  assert.ok(count('supermarket') >= 280 && count('supermarket') <= 340, `supermarket ${count('supermarket')}`);
  assert.ok(count('drugstore') >= 50 && count('drugstore') <= 80, `drugstore ${count('drugstore')}`);
  assert.ok(count('hardware') >= 50 && count('hardware') <= 80, `hardware ${count('hardware')}`);
  assert.ok(read('dictionary/starter/catalogue.txt').includes('[supermarket]'));
});
