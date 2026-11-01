#!/usr/bin/env node
// Renders the matching dictionary (specs/29) from its human-written source:
//   node scripts/dictionary.mjs build        (from the repo root)
//   node scripts/dictionary.mjs check        exits 1 if the committed JSON is stale or the source invalid
//   node scripts/dictionary.mjs sql          prints the migration that fills app.match_word (all domains)
//   node scripts/dictionary.mjs stats        words per domain and per language tag
// Reads dictionary/<domain>.txt (every .txt there except corpus.txt; the file name is the domain:
// shopping, meals, events, tasks) and writes app/assets/matching/dictionary.json, which the app
// loads for matching typed text to icons and categories without a server round trip.
//
// Source format: `#` starts a comment line. A block starts at column 0 with `<icon_key>`,
// optionally followed by ` -> cat1, cat2` (seeded shopping category keys, most likely first;
// shopping only). A key starting with `@` (`@tools -> tools`) names no picture: the words only
// get a category, and the tile shows the category's icon, as a name nobody knows does. Such a
// block needs the arrow. A picture may head several blocks when its words differ in category:
// `fries -> snacks, frozen` (crisps) and `fries.frozen -> frozen, snacks` (chips); the part after
// the dot only tells the blocks apart. Indented lines inside a block are `<tag>: word, word, two words` with
// the tag one of de, de-CH, de-AT, en, fr, es. Words are written naturally (umlauts, accents,
// capitals).
//
// normalize() is the contract with the Dart side; fold() mirrors app.fold in
// supabase/migrations/20261011160000_shopping_m11.sql. Keep the three in step.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourceDir = path.join(root, 'dictionary');
const outputFile = path.join(root, 'app/assets/matching/dictionary.json');

export const TAGS = ['de', 'de-CH', 'de-AT', 'en', 'fr', 'es'];
export const CATEGORIES = [
  'produce', 'bakery', 'dairy', 'meat_fish', 'pantry', 'frozen', 'drinks', 'household', 'snacks',
  'other', 'care', 'baby', 'cleaning', 'health', 'tools', 'screws', 'electrical', 'garden',
];
const SKIP = new Set(['corpus.txt']);

const FROM = 'áàâéèêíìîóòôúùûñç';
const TO = 'aaaeeeiiiooouuunc';

export function fold(text) {
  let out = '';
  for (const ch of text.toLowerCase()) {
    if (ch === 'ä') out += 'ae';
    else if (ch === 'ö') out += 'oe';
    else if (ch === 'ü') out += 'ue';
    else if (ch === 'ß') out += 'ss';
    else {
      const i = FROM.indexOf(ch);
      out += i >= 0 ? TO[i] : ch;
    }
  }
  return out;
}

export function normalize(text) {
  return fold(text).replace(/[^a-z0-9]+/g, ' ').trim();
}

// Parses one source file into [{ key, categories, tags: {tag: [word]}, line }]. `file` is only
// used in error messages (`file:line`).
export function parseSource(text, domain, file = `${domain}.txt`) {
  const blocks = [];
  const seen = new Map();
  let current = null;
  const fail = (line, message) => {
    throw new Error(`${file}:${line}: ${message}`);
  };
  const lines = text.split(/\r?\n/);
  lines.forEach((raw, index) => {
    const line = index + 1;
    if (raw.trim() === '' || raw.trimStart().startsWith('#')) return;
    if (!/^\s/.test(raw)) {
      const match = raw.trim().match(/^(@?[a-z][a-z0-9_]*)(\.[a-z][a-z0-9_]*)?(?:\s*->\s*(.*))?$/);
      if (!match) fail(line, `not a block header: "${raw.trim()}"`);
      const key = match[1];
      const id = key + (match[2] ?? '');
      match[2] = match[3];
      const categories = match[2] === undefined ? [] : match[2].split(',').map((c) => c.trim());
      if (key.startsWith('@') && match[2] === undefined) fail(line, `block "${key}" has no picture, so it needs categories (-> …)`);
      if (match[2] !== undefined) {
        if (domain !== 'shopping') fail(line, `categories are only allowed in the shopping domain ("${key}")`);
        for (const c of categories) {
          if (!CATEGORIES.includes(c)) fail(line, `unknown category "${c}" in block "${key}"`);
        }
        if (categories.length === 0 || categories.some((c) => c === '')) fail(line, `empty category in block "${key}"`);
      }
      if (seen.has(id)) fail(line, `duplicate block "${id}" (first at line ${seen.get(id)})`);
      seen.set(id, line);
      current = { key, id, categories, tags: {}, line };
      blocks.push(current);
      return;
    }
    if (!current) fail(line, 'word line before any block');
    const match = raw.trim().match(/^([A-Za-z-]+)\s*:(.*)$/);
    if (!match) fail(line, `not a word line: "${raw.trim()}"`);
    const tag = match[1];
    if (!TAGS.includes(tag)) fail(line, `unknown tag "${tag}" in block "${current.key}"`);
    const words = match[2].split(',').map((w) => w.trim());
    if (words.some((w) => w === '') || words.length === 0) fail(line, `empty word in block "${current.key}" (${tag})`);
    (current.tags[tag] ??= []).push(...words);
  });
  for (const block of blocks) {
    if (Object.keys(block.tags).length === 0) fail(block.line, `block "${block.key}" has no words`);
  }
  return blocks;
}

// Turns parsed blocks into the rendered entries; throws when one normalised word belongs to
// two keys. Words are sorted and unique.
export function renderDomain(blocks, domain, file = `${domain}.txt`) {
  const owner = new Map();
  const conflicts = [];
  const entries = blocks.map((block) => {
    const words = new Set();
    for (const list of Object.values(block.tags)) {
      for (const raw of list) {
        const word = normalize(raw);
        if (word === '') throw new Error(`${file}:${block.line}: word "${raw}" in block "${block.key}" normalises to nothing`);
        const other = owner.get(word);
        if (other !== undefined && other !== block.id) {
          const message = `${file}: "${word}" (from "${raw}") is in both "${other}" and "${block.id}"`;
          if (!conflicts.includes(message)) conflicts.push(message);
          continue;
        }
        owner.set(word, block.id);
        words.add(word);
      }
    }
    return { key: block.key, categories: block.categories, words: [...words].sort() };
  });
  if (conflicts.length > 0) throw new Error(conflicts.join('\n'));
  return { entries };
}

export function sourceFiles(dir = sourceDir) {
  return fs.readdirSync(dir).filter((f) => f.endsWith('.txt') && !SKIP.has(f)).sort();
}

export function checkPictures(blocks, domain, file, assetsDir = path.join(root, 'app/assets/emoji')) {
  for (const block of blocks) {
    if (block.key.startsWith('@')) continue;
    if (!fs.existsSync(path.join(assetsDir, domain, `${block.key}.png`))) {
      throw new Error(`${file}:${block.line}: no picture app/assets/emoji/${domain}/${block.key}.png for "${block.key}"`);
    }
  }
}

export function loadDictionary(dir = sourceDir, { pictures = true } = {}) {
  const domains = {};
  const parsed = {};
  const errors = [];
  for (const f of sourceFiles(dir)) {
    const domain = f.slice(0, -4);
    try {
      const blocks = parseSource(fs.readFileSync(path.join(dir, f), 'utf8'), domain, `dictionary/${f}`);
      if (pictures) checkPictures(blocks, domain, `dictionary/${f}`);
      parsed[domain] = blocks;
      domains[domain] = renderDomain(blocks, domain, `dictionary/${f}`);
    } catch (e) {
      errors.push(e.message);
    }
  }
  if (errors.length > 0) throw new Error(errors.join('\n'));
  return { parsed, json: { version: 1, source: 'dictionary/*.txt, rendered by scripts/dictionary.mjs', domains } };
}

export function renderJson(json) {
  return `${JSON.stringify(json, null, 1)}\n`;
}

export const DOMAINS = ['shopping', 'meals', 'events', 'tasks'];

// The migration that (re)fills app.match_word with every word of every domain: the table the
// server's matcher reads (specs/29). Written whole each time the dictionary changes, as
// supabase/migrations/<timestamp>_match_words.sql; scripts/dictionary.test.mjs pins the newest
// such file to the current render, so the app asset and the server never drift apart.
export function sqlMigration(json) {
  const rows = [];
  for (const domain of DOMAINS) {
    const entries = [...(json.domains[domain]?.entries ?? [])].sort((a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
    for (const entry of entries) {
      const cats = `{${entry.categories.join(',')}}`;
      for (const word of entry.words) rows.push(`  ('${domain}', '${word.replaceAll("'", "''")}', '${entry.key}', '${cats}')`);
    }
  }
  return [
    '-- Generated by `node scripts/dictionary.mjs sql` from dictionary/*.txt (specs/29). Do not edit:',
    '-- change the source, run `build`, and write the next such file.',
    '--',
    '-- The words the server matches typed names against (app.match_dictionary): one row per domain',
    '-- and normalised word, the picture key (a key starting with @ names no picture, only',
    "-- categories) and, for shopping, the seeded category keys the word belongs to, most likely",
    '-- first. The table is replaced whole; nothing of a household is in it.',
    'create table if not exists app.match_word (',
    "  domain     text   not null check (domain in ('shopping', 'meals', 'events', 'tasks')),",
    '  word       text   not null,',
    '  key        text   not null,',
    "  categories text[] not null default '{}',",
    '  primary key (domain, word)',
    ');',
    'alter table app.match_word enable row level security;',
    'alter table app.match_word force row level security;',
    'drop policy if exists owner_all on app.match_word;',
    'create policy owner_all on app.match_word to postgres using (true) with check (true);',
    '-- No grants: only the matcher functions (definer) read it.',
    '',
    'delete from app.match_word;',
    'insert into app.match_word (domain, word, key, categories) values',
    `${rows.join(',\n')};`,
    '',
  ].join('\n');
}

function stats({ parsed, json }) {
  const lines = [];
  for (const [domain, blocks] of Object.entries(parsed)) {
    const perTag = Object.fromEntries(TAGS.map((t) => [t, new Set()]));
    for (const b of blocks) for (const [t, ws] of Object.entries(b.tags)) ws.forEach((w) => perTag[t].add(normalize(w)));
    const words = json.domains[domain].entries.reduce((n, e) => n + e.words.length, 0);
    lines.push(`${domain}: ${blocks.length} entries, ${words} words`);
    for (const t of TAGS) lines.push(`  ${t.padEnd(6)} ${String(perTag[t].size).padStart(5)}`);
  }
  return lines.join('\n');
}

function main(argv) {
  const [command] = argv;
  let loaded;
  try {
    loaded = loadDictionary();
  } catch (e) {
    console.error(e.message);
    return 1;
  }
  const counts = () => Object.entries(loaded.json.domains).map(([d, v]) =>
    `${d}: ${v.entries.length} entries, ${v.entries.reduce((n, e) => n + e.words.length, 0)} words`).join('\n');
  switch (command) {
    case 'build':
      fs.mkdirSync(path.dirname(outputFile), { recursive: true });
      fs.writeFileSync(outputFile, renderJson(loaded.json));
      console.log(counts());
      return 0;
    case 'check': {
      const fresh = renderJson(loaded.json);
      const committed = fs.existsSync(outputFile) ? fs.readFileSync(outputFile, 'utf8') : null;
      if (committed !== fresh) {
        console.error('app/assets/matching/dictionary.json is stale; run: node scripts/dictionary.mjs build');
        return 1;
      }
      console.log(`dictionary.json is up to date\n${counts()}`);
      return 0;
    }
    case 'sql':
      process.stdout.write(sqlMigration(loaded.json));
      return 0;
    case 'stats':
      console.log(stats(loaded));
      return 0;
    default:
      console.error('usage: node scripts/dictionary.mjs build | check | sql | stats');
      return 1;
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
