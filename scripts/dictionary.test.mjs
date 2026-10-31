import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { fold, loadDictionary, normalize, parseSource, renderDomain, renderJson, sqlRows } from './dictionary.mjs';

const root = new URL('../', import.meta.url);
const read = (file) => readFileSync(new URL(file, root), 'utf8');

test('fold lower-cases and replaces umlauts, sharp s and accents', () => {
  assert.equal(fold('Äpfel Öl Über Straße'), 'aepfel oel ueber strasse');
  assert.equal(fold('ÁÀÂÉÈÊÍÌÎÓÒÔÚÙÛÑÇ'), 'aaaeeeiiiooouuunc');
  assert.equal(fold('Œuf'), 'œuf');
});

test('normalize folds and collapses runs of other characters to one space', () => {
  assert.equal(normalize('WC-Papier'), 'wc papier');
  assert.equal(normalize("Jus d'orange"), 'jus d orange');
  assert.equal(normalize('Crème fraîche'), 'creme fraiche');
  assert.equal(normalize('  Mac & Cheese!! '), 'mac cheese');
  assert.equal(normalize('Rüebli'), 'rueebli');
});

const sample = `# comment
milk -> dairy, other
  de: Milch, Käse-Milch
  de-CH: Rahm
  # inside a block
  fr: Crème fraîche

egg -> dairy
  en: Egg, EGG, eggs
`;

test('parses blocks, arrows, tags and comments', () => {
  const blocks = parseSource(sample, 'shopping');
  assert.deepEqual(blocks.map((b) => [b.key, b.categories]), [['milk', ['dairy', 'other']], ['egg', ['dairy']]]);
  assert.deepEqual(blocks[0].tags, { de: ['Milch', 'Käse-Milch'], 'de-CH': ['Rahm'], fr: ['Crème fraîche'] });
  assert.deepEqual(renderDomain(blocks, 'shopping').entries, [
    { key: 'milk', categories: ['dairy', 'other'], words: ['creme fraiche', 'kaese milch', 'milch', 'rahm'] },
    { key: 'egg', categories: ['dairy'], words: ['egg', 'eggs'] },
  ]);
});

test('a word in two keys throws and names both', () => {
  const blocks = parseSource('a\n  de: Tee\nb\n  en: tee, x\n', 'meals');
  assert.throws(() => renderDomain(blocks, 'meals'), /"tee".*"a".*"b"/);
});

test('invalid sources throw with file:line', () => {
  assert.throws(() => parseSource('a\n  xx: word\n', 'meals', 'm.txt'), /m\.txt:2: unknown tag "xx"/);
  assert.throws(() => parseSource('a\n  de: one, , two\n', 'meals', 'm.txt'), /m\.txt:2: empty word/);
  assert.throws(() => parseSource('a\nb\n  de: x\n', 'meals', 'm.txt'), /m\.txt:1: block "a" has no words/);
  assert.throws(() => parseSource('a\n  de: x\na\n  de: y\n', 'meals', 'm.txt'), /m\.txt:3: duplicate block "a"/);
  assert.throws(() => parseSource('a -> nope\n  de: x\n', 'shopping', 's.txt'), /s\.txt:1: unknown category "nope"/);
  assert.throws(() => parseSource('a -> dairy\n  de: x\n', 'meals', 'm.txt'), /only allowed in the shopping domain/);
});

test('sql rows are sorted by key then word, the last without a comma', () => {
  const rows = sqlRows({ entries: [{ key: 'b', words: ['y', "d'x"] }, { key: 'a', words: ['z'] }] });
  assert.deepEqual(rows, ["('z', 'a'),", "('y', 'b'),", "('d''x', 'b')"]);
});

const { json } = loadDictionary();
const index = (domain) => new Map(json.domains[domain].entries.flatMap((e) => e.words.map((w) => [w, e.key])));

// Every (word, key) pair of a `with w(word, key) as (values ...)` list in a SQL function.
function sqlPairs(file, fn) {
  const sql = read(file);
  const start = sql.indexOf(`function ${fn}(`);
  assert.ok(start >= 0, `${fn} not found in ${file}`);
  const values = sql.slice(start).match(/with w\(word, key\) as \(values([\s\S]*?)\n\s*\),/);
  assert.ok(values, `no values list in ${fn}`);
  const pairs = [...values[1].matchAll(/\('((?:[^']|'')*)', '([a-z_0-9]+)'\)/g)].map((m) => [m[1].replaceAll("''", "'"), m[2]]);
  assert.ok(pairs.length > 100, `${fn}: only ${pairs.length} pairs found`);
  return pairs;
}

// Pairs where the dictionary deliberately (or pending review) files a word under another key than
// the SQL function. The test pins the dictionary's key, so a change in either place shows up.
const differs = {
  shopping: { erdnussbutter: 'honey', 'peanut butter': 'honey' },
  meals: { gratin: 'pie', parmentier: 'pie', tostadas: 'sandwich', wedges: 'fries' },
};

for (const [domain, file, fn] of [
  ['shopping', 'supabase/migrations/20261015120000_catalog_icons.sql', 'app.catalog_icon_for'],
  ['meals', 'supabase/migrations/20261025130000_rituals_wishes_story.sql', 'app.meal_icon_for'],
]) {
  test(`the ${domain} dictionary contains every pair of ${fn}`, () => {
    const have = index(domain);
    const wrong = sqlPairs(file, fn)
      .map(([word, key]) => [normalize(word), key])
      .filter(([word, key]) => (differs[domain][word] ?? key) !== have.get(word))
      .map(([word, key]) => `${word}: SQL ${key}, dictionary ${have.get(word) ?? 'missing'}`);
    assert.deepEqual(wrong, []);
  });
}

test('the rendered JSON is deterministic and sorted', () => {
  const again = loadDictionary().json;
  assert.equal(renderJson(again), renderJson(json));
  for (const domain of Object.values(json.domains)) {
    for (const entry of domain.entries) {
      assert.deepEqual(entry.words, [...new Set(entry.words)].sort());
    }
  }
});

test('the committed dictionary.json is up to date', () => {
  assert.equal(read('app/assets/matching/dictionary.json'), renderJson(json));
});
