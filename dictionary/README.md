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
  shopping categories the picture belongs to, most likely first; only `shopping.txt` has it.
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
node scripts/dictionary.mjs sql shopping   # the words as SQL values rows, for a migration
node scripts/dictionary.mjs stats          # words per domain and tag
node --test scripts/dictionary.test.mjs    # parser, renderer, and: nothing of the old SQL lists lost
cd app && flutter test test/core/matching  # the matcher, the parser, and the corpus below
```

Change a word, run `build`, run the corpus test, look at the misses it prints, commit source and
asset together.

## The corpus

`corpus.txt` is the acceptance test: `text => key` lines (`=> -` means *must stay unknown*) in
`[domain]` sections, about 500 of them, deliberately hard: plurals, compounds, typos, glued
quantities, French and Spanish with connectors, Swiss and Austrian words, descriptors, and
strings that must not match. `app/test/core/matching/corpus_test.dart` prints the accuracy per
domain and per layer, the misses, and the legacy SQL algorithm's score on the same lines.

A line the family's real use contradicts is changed here first, then in the dictionary. The
`de-CH` and `de-AT` lines are the operator's to review: a word a family would not say is
removed, not argued.

## Known gaps and candidates for new pictures

The corpus asks for pictures the sets do not have. Candidates for the icon expansion that
issue #195 deferred (shopping ~150 more pictures), in the order the corpus misses them:

- shopping: flour/sugar/baking (today `salt`), spreads apart from honey (today `honey`),
  cereals apart from yoghurt (today `bowl`), berries and stone fruit apart from the strawberry,
  cabbage family (today `broccoli`), herbs (today `lettuce`), frozen goods (today `ice_cream`),
  pet food, flowers, stationery, clothes
- events: an appointment (doctor, dentist, hairdresser), a school lesson or exam distinct from
  the book, a market or shopping trip, a visit to a restaurant distinct from pizza
- tasks: the bathroom, vacuuming, the piano or an instrument, feeding the pet distinct from the
  dog, homework distinct from reading

Two legacy keys changed meaning on purpose when the lists were merged: *Erdnussbutter* and
*peanut butter* are spreads (`honey`), not `nuts`; *Rüebli* with its umlaut never matched the
old SQL (`fold` gives `rueebli`, the list had `ruebli`), both spellings are here now.
