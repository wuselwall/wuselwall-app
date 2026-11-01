# ADR-021 — Local matching: bundled dictionaries and models, no outside service

**Status:** Accepted · 2026-10-31 · Amends [28](../28-event-templates.md) ("no machine learning
and no outside service" becomes "no outside service; bundled models only") and
[07](../07-module-meals-shopping.md) (the picker's word list becomes a shared dictionary);
extends [ADR-018](ADR-018-self-hosted-only.md) and P1/P2 of
[23](../23-roadmap-after-alpha.md#the-test-every-item-passes); specified in
[29](../29-local-matching.md).

## Context

The app turns short typed names into pictures, categories, templates and people. Each place
does it with its own exact word list in SQL, or not at all, and nothing is learned from a
correction. On 2026-10-31 the user asked how pattern matching or small machine-learning
models could reduce this typing, with the constraint that no data may leave the device or
the family's server, and noted that phones can now run small models.

Four research passes (summarised in [research/local-matching/](../research/local-matching/README.md))
found:

- The mainstream on-device paths on Android are closed to this project. Google's MediaPipe
  Tasks and LLM Inference, ML Kit GenAI (Gemini Nano through AICore) and LiteRT in Play services
  each send usage and performance metrics with device identifiers to Google. That is the
  finding that removed ML Kit from the QR scanner (Q49). Apple's frameworks stay local but are
  iOS-only.
- The telemetry-free runtimes (ONNX Runtime through `flutter_onnxruntime`, `llama.cpp` bindings)
  exist, but a language model of 0.5–1 B parameters is 0.4–1 GB, strains a five-year-old
  phone and is wrong for a fanless wall tablet. Nothing the app needs here is generation.
- Static word embeddings (model2vec, MIT) reduce a multilingual model to a token-vector table
  that a pure-Dart lookup can use on every platform, a few megabytes after pruning. Their
  quality on short Swiss-German strings is unmeasured.
- `pgvector`, `pg_trgm`, `unaccent` and `fuzzystrmatch` ship in the self-hosted Supabase
  image. `Supabase.ai` in the Edge Runtime knows only the English `gte-small` and downloads it
  from Hugging Face at first use, so it is unusable here. A `llama.cpp` server with
  `--offline` on an internal network is a credible optional sidecar later.
- specs/28 wrote "no machine learning and no outside service" for event suggestions and named
  `pg_trgm` as the next step. P1/P2 of specs/23 allow anything that runs on the family's
  server or device. A bundled model is compatible with P1/P2 but contradicts the letter of
  specs/28.

## Decision

1. **Matching runs on the device or on the family's server, never elsewhere.** Dictionaries
   and any model are bundled with the app or rendered into a migration; nothing is fetched at
   runtime (NFR-9); no SDK that reports to a vendor is linked (Q49). Specs/28's sentence is
   amended to: *no outside service; a bundled dictionary or model only*. Machine learning is
   not excluded, phoning home is.
2. **A layered matcher before any model.** Household correction, phrase, word with the
   head-noun rule, stem, compound suffix, typo tolerance; unknown otherwise. One Dart
   implementation on every platform, the same words rendered into SQL for the server. The
   ordering, confidences and normalisation are in [29](../29-local-matching.md).
3. **One dictionary source** (`dictionary/*.txt`, six language tags including `de-CH` and
   `de-AT`) rendered by `scripts/dictionary.mjs` into the app asset and the SQL, checked in CI.
   It replaces `app.catalog_icon_for`, `app.meal_icon_for` and the category words of #195
   when the first feature PR lands.
4. **A corpus is the acceptance test**, with the legacy algorithm as the baseline, so every
   change to the dictionary or the layers shows its effect.
5. **Learning is per household and silent.** Corrections are stored in the household's
   database, applied as the first layer, listed for guardians with a *forget* action, exported
   with the household and deleted with it. No pooling, no upload.
6. **A static-embedding table is the only model on the device path**, built when the corpus
   shows the rules plateau, as a bundled asset of a few megabytes with a documented licence.
7. **A language model is a later, optional, server-side sidecar** behind its own spec, enabled
   by the operator like the OCR container, not part of the first four features.

## Alternatives considered

- **Rules only, forever.** Honours specs/28 literally and costs nothing, but never generalises
  to an unseen synonym. Chosen as the first step, not the last.
- **Server-side embeddings only** (`multilingual-e5-small` in the OCR sidecar, label vectors in
  `pgvector`, matching asynchronously after the insert). Better quality than static vectors and
  nothing on the device, but the picture would appear only after the outbox drains and never
  on an offline device, against the three-second rule. Kept as a fallback behind the device
  table.
- **Device model plus server fallback.** The most capable combination, and the most moving
  parts for a benefit the corpus has not yet shown. Can be reached from this decision later.
- **Apple Natural Language on iOS, something else elsewhere.** Two behaviours for one family;
  rejected.
- **A local language model now**, on the phone or the server: see the context. Rejected for
  now, documented as an option.

## Consequences

- A new top-level `dictionary/` folder, a generator script, a CI check and a Dart library
  `app/lib/core/matching/` arrive without behaviour change; the four feature PRs of
  [29](../29-local-matching.md#the-first-four-features) follow.
- The regional words become reviewable in one file; the operator reviews `de-CH` and `de-AT`.
- The two SQL word lists and #195's dictionary are retired in favour of generated functions;
  pgTAP keeps testing the generated SQL.
- A new table `app.match_correction`, in the export and the purge, with a guardian page.
- Specs/28, 07 and 23 carry a dated note pointing here; Q59 records the model question.
