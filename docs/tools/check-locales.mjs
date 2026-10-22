// Fail before publishing if a translated route or its localized screenshot is missing.
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { join, relative } from 'node:path';

const root = 'docs';
const pages = (await readdir(join(root, 'en'), { recursive: true })).filter((name) => name.endsWith('.md')).sort();
const shots = (text) => [...text.matchAll(/<Shot\s+name="([\w-]+)"/g)].map((m) => m[1]).sort();
for (const lang of ['fr', 'es']) {
  const translated = (await readdir(join(root, lang), { recursive: true })).filter((name) => name.endsWith('.md')).sort();
  assert.deepEqual(translated, pages, `${lang}: every English guide route has a translation`);
  for (const name of pages) {
    const path = join(root, lang, name);
    const text = await readFile(path, 'utf8');
    const source = await readFile(join(root, 'en', name), 'utf8');
    assert.notEqual(text, source, `${path}: translated content`);
    assert.deepEqual(shots(text), shots(source), `${path}: same screens as the source guide`);
    assert.ok(!text.includes('](/en/'), `${path}: internal links stay in the reader's language`);
    assert.ok(!/TODO\(translate\)|TRANSLATE_ME/.test(text), `${path}: no translation placeholders`);
    for (const [tag] of text.matchAll(/<Shot\s[^>]*\/>/g)) {
      assert.match(tag, /alt="[^"]+"/, `${relative(root, path)}: screenshot has localized alternative text`);
    }
  }
}
console.log(`${pages.length} guide pages in each of DE/EN/FR/ES; FR/ES route and screenshot coverage matches English.`);
