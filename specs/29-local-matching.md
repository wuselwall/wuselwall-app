# 29 — Local matching: less typing, nothing leaves the family

*Added 2026-10-31 ([ADR-021](adr/ADR-021-local-matching.md)). Builds on the shopping picker of
[07](07-module-meals-shopping.md#the-tile-picker), the meal pictures and event suggestions of
[27](27-family-rituals.md) and [28](28-event-templates.md), the school scan of
[24](24-school-import.md) and the privacy rules of [11](11-security-and-privacy.md). The
research behind it is in [research/local-matching/](research/local-matching/README.md). The
dictionary lives in `dictionary/`, its renderer is `scripts/dictionary.mjs`, the matcher is
`app/lib/core/matching/`.*

## Why

Much of what a family types into WuselWall is a short name that the app then has to
understand: a shopping item needs a picture and a category, a meal needs a picture, an event
title would like a template, a chore would like an icon, an imported calendar entry needs a
person. Today each of these is answered by an exact word list in SQL (`app.catalog_icon_for`,
`app.meal_icon_for`, the category words of issue #195) or not at all. The lists are German and
English with a few Swiss words, miss plurals and compounds (*Vollmilch*, *Bio-Karotten*), know no
typos (*Tomatten*), and nothing is learned from a correction: the family fixes *Rüebli* to the
carrot once, and the next *Rüebli* lands wrong again.

Doing this well does not need a language model. It needs one good dictionary, a few
string rules, a memory of the family's own corrections and, later, a small bundled embedding
table. All of it runs on the device or on the family's server. That is the whole point: the
app that promises not to phone home must solve this without phoning home.

## What may run where

P1 and P2 of [23](23-roadmap-after-alpha.md#the-test-every-item-passes) decide the shape. In
this spec's terms:

| Allowed | Not allowed |
|---|---|
| Rules and dictionaries bundled with the app or rendered into a migration | Any runtime download of a model, dictionary or word list (NFR-9) |
| A model file bundled as an asset, run by code in the app or by a container in the family's compose stack | A vendor SDK that reports metrics: Google ML Kit, MediaPipe Tasks and LLM Inference, LiteRT in Play services, Gemini Nano through AICore (each sends device identifiers and usage data, the finding of Q49) |
| A sidecar in the family's stack on an internal Docker network with no route out, like the OCR container of specs/24 | Any cloud inference, including a vendor's "private cloud" tier |
| Learning from the family's corrections inside the family's database | Pooling corrections across families, or sending any text anywhere to improve a model |

A platform framework that stays on the device (Apple's Natural Language and Foundation
Models) is allowed by these rules but is iOS-only, so it can never be the solution the web app,
the Android tablet on the wall and the phones share. The shared solution is pure Dart.

## The layered matcher

One matcher serves every domain. It takes a text and a dictionary and answers a key, a
confidence and which layer answered. The first layer that hits wins:

| # | Layer | Example | Confidence |
|---|---|---|---|
| 0 | **Quantity stripped** | *2 kg Kartoffeln* → *Kartoffeln*, quantity `2 kg` (the Siri parser's rules, now shared) | — |
| 1 | **Household correction** | the family once set *Guetzli* to `cookie` | 1.0 |
| 2 | **Phrase** | the whole normalised name is a dictionary word: *crème fraîche* | 0.95 |
| 3 | **Word** | the longest word group in the name that is a dictionary word, taken from the head noun: *orange juice* → `juice`, *jus d'orange* → `juice`, *zumo de naranja* → `juice` | 0.9 |
| 4 | **Stem** | a plural or inflection ending removed: *Tomates* → *tomate* | 0.8 |
| 5 | **Compound** | the word ends with a dictionary word of four letters or more: *Vollmilch* → *milch*, *Schoggigipfeli* → *gipfeli* | 0.75 |
| 6 | **Typo** | Damerau-Levenshtein distance 1 (2 from nine letters) to a dictionary word of similar length: *Tomatten*, *Brokoli* | 0.6 |
| — | **Unknown** | nothing hit: the item shows its category's icon, the family picks, the pick becomes a layer-1 correction | 0 |

**The head noun.** German and English put it last (*Bio Vollmilch*, *orange juice*); French and
Spanish put it first and join with a connector (*jus d'orange*, *zumo de naranja*). The matcher
needs no language tag: when the tokens contain a connector (*de, d, du, des, di, con, au, of,
mit, with, et, y, und, and*) the earliest hit is the head, otherwise the latest.

**Normalisation** is `app.fold` (case, umlauts to `ae oe ue`, `ß` to `ss`, the common accents
stripped) followed by every run of other characters becoming one space, so *WC-Papier* and
*wc papier* are the same. The database and the app already share `fold`; the matcher adds only
the second step, in both.

**Where it runs.** On the device, at once, offline, on every platform including the web: the
picker shows the picture while the item is typed, before the outbox drains. On the server, on
sync, so that items added by Siri, by the ICS import or by an older app get the same answer, and
so that the family's corrections (which live in the database) apply to everyone's devices. Both
sides read the same rendered dictionary (below), so they agree.

### A later layer: a small bundled embedding table

When the corpus shows the rules plateauing (unseen synonyms: *Pouletgeschnetzeltes*, *Kefir*,
*Nata para montar*), layer 7 becomes a nearest-label lookup over **static word embeddings**: a
table of token vectors distilled from a multilingual model (model2vec's
*potion-multilingual*, MIT), pruned to the vocabulary of DE/EN/FR/ES groceries, meals and
chores, quantised to int8, roughly 3–30 MB. Encoding is tokenise, look up, average, normalise; a
match is the cosine-nearest label above a threshold. That is a table lookup, not a neural
network, so it runs in pure Dart on every platform and needs no runtime. It is **not built**
until the corpus proves it beats the rules on strings the rules miss, and it is a bundled asset,
never fetched. A transformer encoder (multilingual-e5-small, ~118 MB int8) stays a server-side
option in the OCR sidecar with the labels' vectors in pgvector, if the device table is not
enough; a language model is not on this path (below).

## The dictionary

**One source, two renderings.** `dictionary/<domain>.txt` holds the words, one block per icon
key, one line per language tag, in natural spelling:

```
carrot -> produce
  de: Karotte, Karotten, Möhre, Möhren
  de-CH: Rüebli
  de-AT: Gelbe Rüben
  en: carrot, carrots
  fr: carotte, carottes
  es: zanahoria, zanahorias
```

`node scripts/dictionary.mjs build` validates the files (every key has a picture, every
category key is a seeded one, no word maps to two keys within a domain) and renders
`app/assets/matching/dictionary.json`, the asset the app loads; `sql <domain>` renders the same
words as `values` rows for the migration that replaces `app.catalog_icon_for`,
`app.meal_icon_for` and the category words of #195 with functions generated from this file.
CI runs `check`, so the committed asset never drifts from the source. The four domains:

| Domain | Keys | Carries |
|---|---|---|
| `shopping` | the 60 shopping pictures | words in six tags, and the icon's seeded categories, most likely first (`milk -> dairy`), which gives a new item its category (the `i(icon, keys)` table of #195 moves here) |
| `meals` | the 35 meal pictures | dishes in six tags |
| `events` | the 20 event pictures | title words: *Geburtstag* → `cake`, *Schwimmkurs* → `swim`, *Chilbi* → `ferris` |
| `tasks` | the 18 task pictures | chore words: *Spülmaschine ausräumen* → `dishes`, *Ufzgi* → `book` |

A regional word (`de-CH`, `de-AT`) is matched for every family: the tag documents where the
word comes from and guides the regional review, it does not gate the match. Server-produced
text stays in the German of Germany ([09](09-clients-and-ux.md#regional-german)); this file
only *reads* dialect.

**Words that must stay out.** An appointment (*Zahnarzt*, *Friseur*, *Termin*) has no fitting
event picture, and a name is not a thing. Such words are deliberately absent, so the matcher
answers *unknown* rather than *star*. Pictures the set lacks and the corpus asks for are listed
in the dictionary's README as candidates for the icon expansion that #196 deferred.

## The corpus

`dictionary/corpus.txt` is the acceptance test: about 500 lines of `text => key` (or `=> -`
for *must stay unknown*) across the four domains and the six tags, at least 40 % of them
strings that are not in the dictionary verbatim (plurals, compounds, typos, glued quantities,
connectors, descriptors). `app/test/core/matching/corpus_test.dart` runs the matcher over it,
prints the hits per layer and the misses, and asserts a floor per domain. The same test runs
the **legacy** algorithm (whole name, last word, longest suffix over the words regex-extracted
from the two SQL migrations) as the baseline, so every PR shows what the layers add. A line
that the family's real use contradicts is changed in the corpus first, then in the dictionary.

The Swiss and Austrian lines are the operator's to review; a word tagged `de-CH` or `de-AT`
that a family would not say is removed, not argued.

## Learning from the family

Every manual correction of a picture or category is remembered **for that household**:

- `app.match_correction (household_id, domain, folded_text, key, set_by, set_at)`, unique on
  household, domain and text; written by the same `api` function that applies the correction
  (`api.shopping_set_category`, the icon pickers), in the same transaction, with the usual
  audit row (P4).
- Layer 1 reads it: on the server directly, on the device from a small synced table that is
  part of the household's ordinary pull.
- **Silent to use, visible to guardians.** Nothing asks "always?". Settings → Einkaufen →
  Advanced lists the learned words (*Guetzli → Keks, von Mia, 12.11.*) with **Vergessen**, the
  same way the catalogue tiles can be forgotten today. The export contains the table; deleting
  the household deletes it.
- Nothing leaves the household. There is no upload, no pooled dictionary, no telemetry about
  which words missed. Growing the shared dictionary is a human act: a guardian reads the
  learned words and opens an issue, or the operator does.

## The first four features

Decided 2026-10-31; each is its own PR after this spec's PR, which carries the dictionary,
the corpus, the renderer and the matcher without changing behaviour.

1. **Shopping: picture, category, typo tolerance.** The SQL functions of 20261015120000 and
   #195 become generated functions from `dictionary/shopping.txt`; the app matches on the
   device while typing (`rankTiles` gains the matcher as a fallback behind prefix, word-start
   and substring); `api.shopping_add_item` takes the category from the match when the catalogue
   has none; the correction table and its settings page. Austrian words arrive with the file.
2. **Shopping: a quantity in quick-add.** The long-press field and the quick-add input parse
   *2 l Milch*, *Kartoffeln 2 kg*, *6 Eier*, *Joghurt 4x* with the shared parser; the name is
   matched without the quantity; a pasted list becomes several items (the Siri path's
   `parseShoppingText`, now one implementation in Dart and one in TypeScript with one test
   corpus). The text stays verbatim where the parser is unsure (FR-4.9).
3. **Events and tasks: a picture from the title.** The event editor and the task editor
   preselect the picture the matcher proposes as the title is typed, marked as proposed until
   touched; `api.event_suggestions` groups signatures with `pg_trgm` similarity as specs/28
   foresaw; a built-in template whose icon matches is offered first on the tiles page.
4. **Imported calendars: a person and a picture per event.** `calendar-import` matches each
   imported title and description against the members' names and nicknames (whole words, folded)
   and the `events` dictionary, storing `member_ids` and `icon_key` per occurrence; the feed's
   colour stays the fallback. Nothing is written back to the subscribed calendar.

## Not on this path

- **A language model on the phone.** The runtimes that would make it easy report to their
  vendor; the ones that do not (`llama.cpp` bindings, ONNX Runtime) add tens of megabytes, need
  a 0.5–1 B parameter model of 0.4–1 GB, and a five-year-old phone or the wall tablet would
  throttle or be killed. Nothing above needs generation.
- **A language model on the server, now.** A `llama.cpp` server with an Apache-2.0 model such
  as Qwen3-1.7B, started with `--offline` on an internal network, is a credible **later** option
  for bulk free text (a pasted shopping list, a school letter): roughly 2–5 s per request on
  four CPU cores, 1–2 GB of memory. It would be an optional service like the OCR container,
  enabled by the operator, with its own spec, after a family's concrete need and an evaluation
  of its German, French and Spanish. It is not part of the four features.
- **`Supabase.ai` in the Edge Runtime.** Self-hosted it knows only the English `gte-small` and
  downloads it from Hugging Face at first use.
- **Per-family model training.** Corrections are looked up, never trained on.

## Open points the corpus answers

- Whether static embeddings help on short Swiss-German strings at all: no published number
  exists; the corpus decides.
- The CPU cost of `multilingual-e5-small` on a home server: unmeasured; only relevant if the
  device table is not enough.
- Two licences are from memory and are re-checked before any model ships:
  multilingual-e5-small (MIT) and the small Qwen models (Apache-2.0).
