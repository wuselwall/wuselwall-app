#!/usr/bin/env node
// Renders the starter catalogue (issue #197) from its human-written source:
//   node scripts/starter.mjs build     (from the repo root)
//   node scripts/starter.mjs check     exits 1 if the committed JSON is stale or the source invalid
//   node scripts/starter.mjs stats     names per list kind and tag, and the names without a picture
// Reads dictionary/starter/catalogue.txt (format: see its header and dictionary/README.md "Starter catalogue")
// and writes app/assets/matching/starter.json, which the app uses to fill a new list's tiles and
// search suggestions, and as a name -> icon map for catalogue entries the server gave no picture.
//
// Each name gets its picture from the shopping dictionary with the same rule as the server
// (app.catalog_icon_for): the whole name, then its last word, then the longest known word the last
// word ends with (at least 3 letters). Names are compared the way the dictionary compares words
// (normalize: folded, everything but letters and digits collapsed to one space). `icon` is null
// when no dictionary word matches; build prints a warning for each such name.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { CATEGORIES, TAGS, normalize, parseSource, renderDomain } from './dictionary.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const sourceFile = path.join(root, 'dictionary/starter/catalogue.txt');
export const outputFile = path.join(root, 'app/assets/matching/starter.json');

// The categories app.shopping_seed_categories seeds for each list kind,
// in walking order. scripts/starter.test.mjs compares this with the latest migration.
export const KINDS = {
  supermarket: ['produce', 'bakery', 'dairy', 'meat_fish', 'pantry', 'snacks', 'frozen', 'drinks', 'household', 'other'],
  drugstore: ['care', 'baby', 'cleaning', 'health', 'other'],
  hardware: ['tools', 'screws', 'electrical', 'garden', 'other'],
};
export const REGIONAL = ['de-CH', 'de-AT'];
const REQUIRED = ['de', 'en'];

// Parses the source into [{ kind, sections: [{ category, line, tags: { tag: { line, entries } } }] }].
// An entry of de-CH/de-AT is { base, regional } (override), { add } (`+ Name`); everything else is a
// plain name string. Throws on the first problem, with `file:line`.
export function parseStarter(text, file = 'dictionary/starter/catalogue.txt') {
  const kinds = [];
  let kind = null;
  let section = null;
  const fail = (line, message) => {
    throw new Error(`${file}:${line}: ${message}`);
  };
  text.split(/\r?\n/).forEach((raw, index) => {
    const line = index + 1;
    const body = raw.replace(/(^|\s)#.*$/, '').trim();
    if (body === '') return;
    let m = body.match(/^\[([a-z_]+)\]$/);
    if (m) {
      if (!(m[1] in KINDS)) fail(line, `unknown list kind "${m[1]}" (${Object.keys(KINDS).join(', ')})`);
      if (kinds.some((k) => k.kind === m[1])) fail(line, `duplicate list kind "${m[1]}"`);
      kind = { kind: m[1], line, sections: [] };
      kinds.push(kind);
      section = null;
      return;
    }
    m = body.match(/^([A-Za-z_-]+)\s*:(.*)$/);
    if (!m) fail(line, `not a section or tag line: "${body}"`);
    const [, key, rest] = m;
    if (CATEGORIES.includes(key) && !TAGS.includes(key)) {
      if (!kind) fail(line, `section "${key}" before any [kind]`);
      if (rest.trim() !== '') fail(line, `section "${key}:" takes no names on its line`);
      if (!KINDS[kind.kind].includes(key)) fail(line, `"${key}" is not a seeded category of ${kind.kind} (${KINDS[kind.kind].join(', ')})`);
      const seen = kind.sections.find((s) => s.category === key);
      if (seen) fail(line, `duplicate section "${key}" in ${kind.kind} (first at line ${seen.line})`);
      const last = kind.sections.at(-1);
      if (last && KINDS[kind.kind].indexOf(key) < KINDS[kind.kind].indexOf(last.category)) {
        fail(line, `section "${key}" is out of walking order in ${kind.kind} (after "${last.category}"; expected ${KINDS[kind.kind].join(', ')})`);
      }
      section = { category: key, line, tags: {} };
      kind.sections.push(section);
      return;
    }
    if (!TAGS.includes(key)) fail(line, `unknown tag or category "${key}"`);
    if (!section) fail(line, `tag line "${key}" before any section`);
    if (key in section.tags) fail(line, `duplicate "${key}" line in section "${section.category}"`);
    const parts = rest.split(',').map((p) => p.trim());
    if (parts.some((p) => p === '')) fail(line, `empty name in "${key}" of section "${section.category}"`);
    const regional = REGIONAL.includes(key);
    const entries = parts.map((part) => {
      if (!regional) {
        if (part.startsWith('+') || part.includes('=')) fail(line, `"${part}": only ${REGIONAL.join(' and ')} take overrides`);
        return part;
      }
      if (part.startsWith('+')) {
        const add = part.slice(1).trim();
        if (add === '' || add.includes('=')) fail(line, `bad addition "${part}" in ${key}`);
        return { add };
      }
      const eq = part.split('=').map((s) => s.trim());
      if (eq.length !== 2 || eq[0] === '' || eq[1] === '') {
        fail(line, `${key} takes "base = regional" or "+ Name", not a plain name: "${part}"`);
      }
      return { base: eq[0], regional: eq[1] };
    });
    section.tags[key] = { line, entries };
  });
  for (const k of kinds) {
    if (k.sections.length === 0) fail(k.line, `list kind "${k.kind}" has no sections`);
    for (const s of k.sections) {
      for (const tag of REQUIRED) {
        if (!(tag in s.tags)) fail(s.line, `section "${s.category}" of ${k.kind} has no "${tag}" line`);
      }
      for (const tag of REGIONAL) {
        const entries = s.tags[tag]?.entries ?? [];
        const bases = new Set();
        for (const e of entries) {
          if (!e.base) continue;
          const baseNames = s.tags.de.entries;
          if (!baseNames.some((n) => normalize(n) === normalize(e.base))) {
            fail(s.tags[tag].line, `${tag}: "${e.base}" is not a name in the de list of section "${s.category}"`);
          }
          if (bases.has(normalize(e.base))) fail(s.tags[tag].line, `${tag}: "${e.base}" is overridden twice`);
          bases.add(normalize(e.base));
        }
      }
    }
  }
  return kinds;
}

// Names of one section for one tag, with the regional overrides applied to the de list.
export function sectionNames(section, tag) {
  if (!REGIONAL.includes(tag)) return section.tags[tag]?.entries ?? [];
  const names = [...section.tags.de.entries];
  const entries = section.tags[tag]?.entries ?? [];
  for (const e of entries) {
    if (!e.base) continue;
    names[names.findIndex((n) => normalize(n) === normalize(e.base))] = e.regional;
  }
  for (const e of entries) if (e.add) names.push(e.add);
  return names;
}

// Throws when a name appears twice in one kind and tag (after the overrides are applied).
export function checkDuplicates(kinds, file = 'dictionary/starter/catalogue.txt') {
  const problems = [];
  for (const k of kinds) {
    for (const tag of TAGS) {
      const seen = new Map();
      for (const s of k.sections) {
        for (const name of sectionNames(s, tag)) {
          const key = normalize(name);
          if (key === '') problems.push(`${file}: [${k.kind}] ${s.category} ${tag}: "${name}" normalises to nothing`);
          else if (seen.has(key)) {
            problems.push(`${file}:${s.tags[tag]?.line ?? s.tags.de.line}: [${k.kind}] ${tag}: "${name}" appears twice (${seen.get(key)} and ${s.category})`);
          } else seen.set(key, s.category);
        }
      }
    }
  }
  if (problems.length > 0) throw new Error(problems.join('\n'));
}

// The shopping domain on its own (pictures are the dictionary's business, not checked here).
export function loadShopping(file = path.join(root, 'dictionary/shopping.txt')) {
  const blocks = parseSource(fs.readFileSync(file, 'utf8'), 'shopping', 'dictionary/shopping.txt');
  return { domains: { shopping: renderDomain(blocks, 'shopping', 'dictionary/shopping.txt') } };
}

// normalised word -> icon key, for the shopping domain of a loaded dictionary.
export function wordMap(dictionaryJson) {
  const map = new Map();
  for (const entry of dictionaryJson.domains.shopping.entries) {
    for (const word of entry.words) map.set(word, entry.key);
  }
  return map;
}

// The server's rule (app.catalog_icon_for): the whole name, then its last word, then the longest
// known word (3 letters or more) the last word ends with. null when nothing matches.
export function iconFor(name, words) {
  const whole = normalize(name);
  if (whole === '') return null;
  if (words.has(whole)) return words.get(whole);
  const last = whole.slice(whole.lastIndexOf(' ') + 1);
  if (words.has(last)) return words.get(last);
  let best = null;
  for (const word of words.keys()) {
    if (word.length >= 3 && last.endsWith(word) && (best === null || word.length > best.length)) best = word;
  }
  return best === null ? null : words.get(best);
}

export function render(kinds, words) {
  const out = { version: 1, source: 'dictionary/starter/catalogue.txt, rendered by scripts/starter.mjs', kinds: {} };
  const unmatched = [];
  for (const k of kinds) {
    const items = {};
    for (const tag of TAGS) {
      items[tag] = [];
      for (const s of k.sections) {
        for (const name of sectionNames(s, tag)) {
          // A key starting with @ names no picture (category-only words, e.g. cereals): no icon, and
          // not a gap to fill either.
          let icon = iconFor(name, words);
          if (icon !== null && icon.startsWith('@')) icon = undefined;
          if (icon === null && !unmatched.some((u) => u.kind === k.kind && u.name === name && u.tag === tag)) {
            unmatched.push({ kind: k.kind, tag, category: s.category, name });
          }
          items[tag].push({ name, category: s.category, icon: icon === undefined ? null : icon });
        }
      }
    }
    out.kinds[k.kind] = { categories: k.sections.map((s) => s.category), items };
  }
  return { json: out, unmatched };
}

// One item per line keeps the committed file diffable.
export function renderJson(json) {
  const lines = ['{', ` "version": ${json.version},`, ` "source": ${JSON.stringify(json.source)},`, ' "kinds": {'];
  const kindNames = Object.keys(json.kinds);
  kindNames.forEach((kn, ki) => {
    const k = json.kinds[kn];
    lines.push(`  ${JSON.stringify(kn)}: {`, `   "categories": ${JSON.stringify(k.categories)},`, '   "items": {');
    const tags = Object.keys(k.items);
    tags.forEach((tag, ti) => {
      lines.push(`    ${JSON.stringify(tag)}: [`);
      k.items[tag].forEach((item, i) => {
        lines.push(`     ${JSON.stringify(item)}${i < k.items[tag].length - 1 ? ',' : ''}`);
      });
      lines.push(`    ]${ti < tags.length - 1 ? ',' : ''}`);
    });
    lines.push('   }', `  }${ki < kindNames.length - 1 ? ',' : ''}`);
  });
  lines.push(' }', '}');
  return `${lines.join('\n')}\n`;
}

export function load({ source = sourceFile } = {}) {
  const kinds = parseStarter(fs.readFileSync(source, 'utf8'));
  checkDuplicates(kinds);
  return { kinds, ...render(kinds, wordMap(loadShopping())) };
}

export function stats({ kinds, json, unmatched }) {
  const lines = [];
  for (const k of kinds) {
    lines.push(`${k.kind}: ${k.sections.map((s) => `${s.category} ${s.tags.de.entries.length}`).join(', ')}`);
    for (const tag of TAGS) lines.push(`  ${tag.padEnd(6)} ${String(json.kinds[k.kind].items[tag].length).padStart(4)}`);
  }
  lines.push(`without a picture: ${unmatched.length} (${unmatched.filter((u) => !REGIONAL.includes(u.tag)).length} in de/en/fr/es)`);
  return lines.join('\n');
}

function main(argv) {
  const command = argv[0];
  if (!['build', 'check', 'stats'].includes(command)) {
    console.error('usage: node scripts/starter.mjs build | check | stats');
    return 1;
  }
  let loaded;
  try {
    loaded = load();
  } catch (e) {
    console.error(e.message);
    return 1;
  }
  const warn = () => {
    for (const u of loaded.unmatched) console.warn(`no picture: [${u.kind}] ${u.category} ${u.tag}: ${u.name}`);
  };
  const text = renderJson(loaded.json);
  switch (command) {
    case 'build':
      fs.mkdirSync(path.dirname(outputFile), { recursive: true });
      fs.writeFileSync(outputFile, text);
      warn();
      console.log(stats(loaded));
      return 0;
    case 'check': {
      const committed = fs.existsSync(outputFile) ? fs.readFileSync(outputFile, 'utf8') : null;
      if (committed !== text) {
        console.error('app/assets/matching/starter.json is stale; run: node scripts/starter.mjs build');
        return 1;
      }
      console.log(`starter.json is up to date\n${stats(loaded)}`);
      return 0;
    }
    default:
      warn();
      console.log(stats(loaded));
      return 0;
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
