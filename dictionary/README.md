# The matching dictionary

The one source of the words WuselWall understands when a family types a short name: a shopping
item, a dish, an event title, a chore ([specs/29](../specs/29-local-matching.md),
[ADR-021](../specs/adr/ADR-021-local-matching.md)). Four files, one per domain, each a list of
blocks:

```
carrot -> produce
  de: Karotte, Karotten, Möhre, Möhren
  de-CH: Rüebli
  de-AT: Gelbe Rüben
  en: carrot, carrots
  fr: carotte, carottes
  es: zanahoria, zanahorias
```

- The block key is a picture in `app/assets/emoji/<domain>/`. The arrow lists the seeded
  shopping categories the picture belongs to, most likely first; only `shopping.txt` has it,
  and there every block needs it: the first category is the one a new item gets.
- A key starting with `@` (`@tools -> tools`) names no picture: the words only carry their
  categories, and the tile shows the category's icon, as it does for a name nobody knows.
  Flour, cereals, wipes and the hardware store's aisles live in such blocks, because a salt
  shaker is not flour and the set has no hammer.
- A picture may head a second block when some of its words belong elsewhere:
  `fries -> snacks, frozen` holds the crisps, `fries.frozen -> frozen, snacks` the Pommes. The
  part after the dot only tells the blocks apart.
- A word line is a tag (`de`, `de-CH`, `de-AT`, `en`, `fr`, `es`) and comma-separated words in
  their natural spelling; the renderer folds them. Write *Rüebli*, never *ruebli*; keep both
  spellings only where people type both (*œuf* and *oeuf*).
- A regional word is matched for every family. The tag says where the word comes from and
  which review it belongs to; it never gates the match.
- Within a domain a word may belong to one key only. The renderer stops with both keys named.
- Words that must stay out: appointments (*Zahnarzt*, *Friseur*, *Termin*), because no event
  picture fits and *unknown* is the better answer; names of people; anything that is not a thing.

## Workflow

```
node scripts/dictionary.mjs build          # validate, render app/assets/matching/dictionary.json
node scripts/dictionary.mjs check          # CI: the committed asset equals a fresh render
node scripts/dictionary.mjs sql > supabase/migrations/<timestamp>_match_words.sql
                                           # the migration that fills app.match_word, all domains
node scripts/dictionary.mjs stats          # words per domain and tag
node --test scripts/dictionary.test.mjs    # parser, renderer, and: nothing of the old SQL lists lost
cd app && flutter test test/core/matching  # the matcher, the parser, and the corpus below
```

Change a word, run `build`, run the corpus test, look at the misses it prints, then write the
next `*_match_words.sql` with `sql` (a new file with a later timestamp, never an edit of an old
one: each replaces the server's word table whole). Commit source, asset and migration together;
the node test pins the newest such migration to the render, so none of the three can drift.
The server's matcher (`app.match_dictionary`, 20261031151000) is the same layered algorithm as
`app/lib/core/matching/matcher.dart` over the same words; it does not strip quantities (the app
does, before an item is sent), and its typo layer prefilters with `fuzzystrmatch`.

## The corpus

`corpus.txt` is the acceptance test: `text => key` lines (`=> -` means *must stay unknown*) in
`[domain]` sections, about 500 of them, deliberately hard: plurals, compounds, typos, glued
quantities, French and Spanish with connectors, Swiss and Austrian words, descriptors, and
strings that must not match. `app/test/core/matching/corpus_test.dart` prints the accuracy per
domain and per layer, the misses, and the legacy SQL algorithm's score on the same lines.

A line the family's real use contradicts is changed here first, then in the dictionary. The
`de-CH` and `de-AT` lines are the operator's to review: a word a family would not say is
removed, not argued.

## Starter catalogue

`starter/catalogue.txt` is not a dictionary but a list of things to buy: the most common items of each shopping
list kind (issue #197), so a new family's list has tiles and search suggestions before anything was
bought. The app fills the tile grid from it while a list's own catalogue is small, offers it in the
search, and takes the picture of a catalogue entry the server gave none from its name-to-icon map.

```
[supermarket]              # list kind: supermarket | drugstore | hardware
produce:                   # a seeded category, sections in walking order of app.shopping_seed_categories
  de: Bananen, Äpfel, Tomaten, Gurken, Karotten, …    # most common first
  de-CH: Karotten = Rüebli, Paprika = Peperoni, + Nüsslisalat
  de-AT: Tomaten = Paradeiser, Karotten = Gelbe Rüben
  en: bananas, apples, tomatoes, …
  fr: bananes, pommes, tomates, …
  es: plátanos, manzanas, tomates, …
```

- A name may appear once per list kind and tag. The order inside a section is the popularity order;
  names are in natural spelling, plural where people buy plural (*Bananen*), singular for bulk (*Milch*).
- `de` and `en` are required in every section, `fr` and `es` are optional.
- `de-CH` and `de-AT` are overrides of the `de` list, never full lists: `base = regional` replaces the
  base name at its place (the base must be a name of that section's `de` line), `+ Name` appends one.
  Write what the family says: *Rüebli*, *Guetzli*, *Weggli*, *Gipfeli*, *Rahm*, *Anke*; *Paradeiser*,
  *Erdäpfel*, *Marillen*, *Topfen*, *Obers*, *Semmeln*, *Faschiertes*, *Melanzani*, *Karfiol*, *Kren*; and
  *ß* becomes *ss* in Swiss spelling (*Weißbrot* = *Weissbrot*). The rendered file has full lists for both.
- Sections follow the walking order of the categories the server seeds for that kind
  (`scripts/starter.test.mjs` compares them with the latest migration that defines
  `app.shopping_seed_categories`). Supermarket: produce, bakery, dairy, meat_fish, pantry, snacks,
  frozen, drinks, household, other. Drugstore: care, baby, cleaning, health, other. Hardware: tools,
  screws, electrical, garden, other.
- The picture of each name is looked up in `shopping.txt` with the rule of `app.catalog_icon_for`:
  the whole name, then its last word, then the longest known word the last word ends with (three
  letters or more). A name without a hit gets `"icon": null` and a warning from `build`: it is a
  candidate for a new word in `shopping.txt` (or, if the name is odd, for a better name here).

```
node scripts/starter.mjs build     # validate, render app/assets/matching/starter.json
node scripts/starter.mjs check     # CI: the committed asset equals a fresh render
node scripts/starter.mjs stats     # names per kind and tag, and the names without a picture
node --test scripts/starter.test.mjs
```

The rendered file: `{ "version": 1, "source": …, "kinds": { "<kind>": { "categories": ["produce", …],
"items": { "<tag>": [ { "name": "Bananen", "category": "produce", "icon": "banana" }, … ] } } } }`, with
every tag of `scripts/dictionary.mjs` (`de`, `de-CH`, `de-AT`, `en`, `fr`, `es`) as a full list in
category-walking order and then popularity order.

## Known gaps and candidates for new pictures

The corpus asks for pictures the sets do not have. Candidates for the icon expansion that
issue #195 deferred (shopping ~150 more pictures), in the order the corpus misses them:

- shopping: flour/sugar/baking and cereals (today `@baking` and `@cereal`, no picture), a hammer,
  screws, a plug and a plant for the hardware aisles (`@tools`, `@screws`, `@electrical`,
  `@garden`), wipes (`@wipes`), crisps apart from fries, spreads apart from honey (today
  `honey`), berries and stone fruit apart from the strawberry, cabbage family (today
  `broccoli`), herbs (today `lettuce`), frozen goods (today `ice_cream`), pet food, stationery,
  clothes
- events: an appointment (doctor, dentist, hairdresser), a school lesson or exam distinct from
  the book, a market or shopping trip, a visit to a restaurant distinct from pizza
- tasks: the bathroom, vacuuming, the piano or an instrument, feeding the pet distinct from the
  dog, homework distinct from reading

Decisions pinned in `scripts/dictionary.test.mjs` (change the test when you change your mind):
*Erdnussbutter* and *peanut butter* are spreads (`honey`), not `nuts`; cereals left the yoghurt
bowl for `@cereal`; *Studentenfutter* is nuts (pantry first), bin bags are household goods
first, the sponge's aisle is cleaning. Every other word of the two SQL lists of #196 and the two
legacy icon lists keeps its first category and its picture. *Rüebli* with its umlaut never
matched the old SQL (`fold` gives `rueebli`, the list had `ruebli`), both spellings are here now.
