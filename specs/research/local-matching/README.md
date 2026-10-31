# Research — local pattern matching and small models (2026-10-31)

Four research passes made on 2026-10-31 for [specs/29](../../29-local-matching.md) and
[ADR-021](../../adr/ADR-021-local-matching.md): the app's user-input flows, on-device machine
learning in Flutter, small multilingual text models, and server-side options on the
self-hosted Supabase stack. Figures marked *estimate* were not measured by anyone we could
find; licences marked *from memory* are re-checked before anything ships. Sources are
linked inline; model cards and package pages are as read on 2026-10-31.

## 1 — Where the app loses user input

All current matching is deterministic: SQL word lists, TypeScript parsers and counting. No
model exists anywhere.

| Feature | Today | Gap |
|---|---|---|
| Shopping picture | `app.catalog_icon_for` (migration 20261015120000): whole name, then last word, then longest known word the last word ends with, ~60 keys, DE/EN with a few Swiss words; only on catalogue insert | No Austrian words, no typo tolerance, no learning |
| Shopping category | None for a new name; `api.shopping_set_category` teaches the catalogue (#195 adds a word list) | A new item lands uncategorised until someone fixes it |
| Picker search | `rankTiles`: prefix, word-start, substring, ties by purchase count | No typo tolerance, no aliases |
| Quantity | Long-press free text, kept verbatim; `parseShoppingText` in `_shared/shortcuts.ts` parses only Siri dictation | The in-app field never parses |
| Duplicates | Exact folded name | *Tomate*/*Tomaten*, *Bio-Milch*/*Milch* |
| Meal picture | `app.meal_icon_for` (20261025130000), ~35 keys, generated column | Same gaps; a second word table parallel to the shopping one |
| Meal suggestions | `suggestMeals`, counts by lowercased title | Near-duplicate titles split the count |
| Event picture and template | Picked by hand from 20 pictures; `api.event_suggestions` groups by lower-cased, punctuation-stripped signature | No title → picture; specs/28 names `pg_trgm` as the next step |
| Imported ICS events | One member set and colour per feed | No per-event person, picture or importance |
| Task picture and recurrence | Picked by hand; a new chore defaults to daily | No title → picture; no "jeden Mittwoch" → rrule |
| School scan | RapidOCR sidecar, grid reading, aliases, edit-distance snapping, 1084 lines of subject vocabulary | The most mature area; left alone |
| Regional German | UI strings only (`app_de_CH.arb`, `app_de_AT.arb`) | The matchers know Swiss words, almost no Austrian |

Constraints found in the specs: specs/28 "no machine learning and no outside service"; specs/07
FR-3.8 "needs no AI"; specs/24 "no AI the project runs", no ML Kit on the phone; specs/23 P1/P2;
NFR-9 no runtime fetches; specs/11 no analytics, crash or ad SDK; Q49 the ML Kit finding.

## 2 — On-device runtimes in Flutter

**The deciding criterion is telemetry.** The project removed ML Kit because it sent device, app
and performance data with a per-installation identifier to Google (Q49).

| Option | Telemetry or network | Platforms | Verdict |
|---|---|---|---|
| MediaPipe Tasks / LLM Inference (`flutter_gemma`, now `flutter_edge_ai`) | Sends usage and performance metrics (app ID, inference counts, hardware) to Google per the [MediaPipe ToS](https://developers.google.com/edge/mediapipe/legal/tos); models download from Hugging Face | Android, iOS, web preview | Out |
| ML Kit GenAI / Gemini Nano (AICore) | Per-installation identifiers, device info, latency and errors to Google ([disclosure](https://developers.google.com/ml-kit/android-data-disclosure)); flagships only | Android | Out |
| LiteRT in Play services | Contacts Google for models and accelerator info, sends metrics with a device identifier ([docs](https://developers.google.com/edge/litert/android/play_services)) | Android | Out |
| `tflite_flutter` / `flutter_litert` (bundled runtime) | None found for the bundled runtime; the web variant loads LiteRT.js from a CDN by default (self-hostable) | Android, iOS, desktop; web via LiteRT.js | Possible, .tflite only |
| `flutter_onnxruntime` (ORT 1.28, MIT) | None on mobile (ORT telemetry exists only in Windows builds, [Privacy.md](https://sources.debian.org/src/onnxruntime/1.23.2%2Bdfsg-6/docs/Privacy.md)); web through self-hosted `onnxruntime-web` | Android, iOS, desktop, web | The clean native runtime, ~10–20 MB per ABI (*estimate*) |
| `llama_cpp_dart` 0.9.0-dev, `flutter_edge_ai_llama` | None mentioned; GGUF bundled or downloaded | iOS, Android, macOS; no web | Dev-stage, one maintainer |
| Cactus SDK | Telemetry **on by default**, optional cloud fallback | mobile | Out |
| Apple Natural Language (`NLEmbedding`, `NLContextualEmbedding` iOS 17+, de/fr/es/en) and Foundation Models (iOS 26) | Local; one plugin offers Private Cloud Compute as opt-in, never enable it | iOS only, platform channel | Allowed, not shared |
| Pure Dart | None | All, including web | A static-embedding lookup is a table and a dot product; tokenisers exist (`dart_wordpiece`, `dart_sentencepiece_tokenizer`, MIT) |

**Hardware.** Android and iOS keep roughly 40–50 % of RAM for the system; a 3 GB tablet leaves
well under 2 GB for the app. A 0.5–1 B model at int4 needs 0.5–1 GB of weights plus overhead;
Qwen2.5-0.5B int4 ran at 12–32 tokens/s and 1.7 GB RAM on a 2020 flagship
([dispatchAI dataset](https://huggingface.co/datasets/dispatchAI/on-device-latency)); a 2021
mid-range phone with 4 GB does a few tokens per second (*anecdotal*). Fanless tablets throttle.
Embedding models of 20–120 MB answer a short string in milliseconds to tens of milliseconds
(*estimate*). **Recommendation:** no language model on the device; embeddings or a precomputed
table are fine even on the wall tablet. Before shipping any runtime: a network capture on a
debug build, a manifest check for Play-services dependencies, self-hosted WASM on the web.

## 3 — Small multilingual text models

### Classic string methods
`unaccent` + `pg_trgm` (`similarity`, `word_similarity`), `fuzzystrmatch` (levenshtein), hand
rules for plural endings and compound heads. Fix typos, missing umlauts, plurals. Break on
synonyms, dialect and compounds without a dictionary-based head rule; trigram scores on 4–8
letter strings are threshold-sensitive (defaults 0.3 and 0.6). Zero megabytes, runs in Postgres
and Dart. Layer 0.

### Static embeddings (a table, no runtime)

| Model | Size | Dim | Languages | Licence |
|---|---|---|---|---|
| [potion-multilingual-128M](https://huggingface.co/minishlab/potion-multilingual-128M) | 512 MB F32, ~128 MB int8 (*estimate*), far less after pruning the vocabulary to DE/EN/FR/ES | 256 | 101, distilled from bge-m3 | MIT |
| [static-similarity-mrl-multilingual-v1](https://huggingface.co/sentence-transformers/static-similarity-mrl-multilingual-v1) | ~434 MB F32; a community d256-int8 build ~27 MB | 1024, truncatable | multilingual | Apache-2.0 |
| fastText aligned vectors | GB-scale, pruned to tens of MB | 300 | 157 | CC-BY-SA |

Encoding is tokenise, look up, mean-pool, normalise: an afternoon in Dart. Only vectors for the
project's own vocabulary are needed. **Caveat:** no published benchmark on short German grocery
strings; a name inside the string (*Zahnarzt Mia*) adds noise. Use a threshold and the rule
fallback.

### Transformer sentence encoders

| Model | Params | int8 ONNX | Languages | Licence |
|---|---|---|---|---|
| [multilingual-e5-small](https://huggingface.co/Xenova/multilingual-e5-small/tree/main/onnx) | 118M | ~118 MB | ~100 | MIT (*from memory*) |
| [paraphrase-multilingual-MiniLM-L12-v2](https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2) | ~118M | ~118 MB | 50 | Apache-2.0 |
| [gte-multilingual-base](https://huggingface.co/onnx-community/gte-multilingual-base/tree/main/onnx) | 305M | 340 MB | 70+ | Apache-2.0 |
| bge-m3 | ~568M | ~570 MB | 100+ | MIT |
| [EmbeddingGemma-300M](https://huggingface.co/google/embeddinggemma-300m) | 308M | <200 MB quantised (Google's claim) | 100+ | Gemma Terms (gated) |
| [Qwen3-Embedding-0.6B](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B) | 0.6B | — | 100+ | Apache-2.0 |
| [Supabase gte-small](https://huggingface.co/Supabase/gte-small) | ~33M | ~34 MB | **English only** | MIT |

Latency for a 5–10 token string: 5–20 ms for a 12-layer 384-dim int8 model on one modern x86
core, 30–150 ms for 300–600M (*estimates*). About 100 MB of e5-small is the 250k-token embedding
matrix, which can be pruned. Pre-embed the labels; only the user's string is encoded at
runtime.

### Classifier and per-household learning
kNN or a prototype classifier over frozen embeddings works with 3–10 synonyms per label
(*experience, not measured*); fastText supervised wants 20+ per label. Per-household learning
is a lookup table `(normalised_text, label, household)`: exact first, then nearest by
embedding, then the global prototypes. No training run, nothing leaves the household.

### Small instruction models (for structuring text)

| Model | Q4_K_M | Licence |
|---|---|---|
| Qwen3-0.6B / Qwen2.5-0.5B | ~0.4–0.5 GB | Apache-2.0 |
| Qwen3-1.7B | ~1.1 GB (*estimate*) | Apache-2.0 |
| Gemma 3 1B | 806 MB | Gemma Terms |
| Llama 3.2 1B | 808 MB | Llama community licence |
| SmolLM2-1.7B | 1.06 GB | Apache-2.0 (English-centric) |
| Gemma 3n E2B, Phi-4-mini | 2.5–3 GB | Gemma Terms / MIT |

No direct benchmark for 4–8 x86 cores was found; nearby data points give ~17 t/s for a 1.5B
Q4 model on a 4-vCPU Xeon and ~36 t/s on an 8-thread Arm board. Expect 10–30 t/s for a 1.7B Q4
model on 4–8 cores, so a shopping line with a grammar-constrained JSON answer takes roughly 2–5 s
(*estimate*). Models below 1.5B are untested for German, French, Spanish and Swiss dialect.
Apache-2.0 is the simplest licence for an open-source project; Gemma and Llama terms carry
use restrictions and flow-down obligations.

### Recommendation matrix

| Task | Approach | Size | Pure Dart incl. web | Native on phone | Server |
|---|---|---|---|---|---|
| Icon/category | Rules + dictionary + compound/typo | 0 MB | yes | — | — |
| Icon/category | **Pruned static embeddings + label prototypes + household corrections** | 3–30 MB (*estimate*) | **yes** | — | — |
| Icon/category | e5-small / MiniLM int8 + kNN | ~118 MB | no (ORT) | yes | yes (pgvector) |
| Structured parsing | Regex, unit table, per-item matching | 0 MB | **yes** | — | — |
| Structured parsing | Qwen3-1.7B, constrained JSON | ~1.1 GB | no | heavy | **recommended, later** |

## 4 — Server side on the self-hosted stack

| Question | Finding |
|---|---|
| Postgres extensions | The Supabase image builds `pgvector` (0.8.x likely; HNSW from 0.5), `pg_trgm`, `unaccent`, `fuzzystrmatch`; `pg_cron` 1.6.4 and `pg_net` 0.20.4. No `plpython3u`, no PostgresML. Confirm with `select * from pg_available_extensions`. |
| `Supabase.ai.Session('gte-small')` self-hosted | The edge-runtime image ships `libonnxruntime.so`; the model URL is hard-coded to huggingface.co and fetched at first use into `EXT_AI_CACHE_DIR`; only `gte-small` is accepted (`ext/ai/lib.rs`); English-only. Unusable here. `Session` can proxy to Ollama or an OpenAI-compatible server through `AI_INFERENCE_API_HOST`. |
| transformers.js in the Edge Runtime | Possible but fragile: self-hosted workers default to 150 MB memory, single-threaded WASM, model reloaded per cold worker. A sidecar is better. |
| Sidecar for embeddings | Add `multilingual-e5-small` int8 to the existing FastAPI/ONNX OCR container (300–500 MB RSS, 5–30 ms per string, *estimates*), or HF Text Embeddings Inference `cpu-1.9` with a mounted model dir. Ship the ~300 label vectors in a migration as `vector(384)` with the model file's SHA-256 pinned. |
| Sidecar for a language model | `ghcr.io/ggml-org/llama.cpp:server` pinned by digest, GGUF mounted, `--offline`, `--json-schema` for constrained output, `--api-key`; no `-hf`, no `--connect`. Ollama works but keeps a registry-style model store; vLLM-CPU is too heavy. 1–2 GB RSS for 1.5B. |
| Async pattern | Insert writes `match_status = 'pending'`; `pg_cron` every 10–60 s or an `AFTER INSERT` trigger calls `net.http_post` to an Edge Function that calls the sidecar; `FOR UPDATE SKIP LOCKED` and an attempts counter make retries idempotent; Realtime pushes the result. |
| No egress | Sidecars on a compose network with `internal: true`; the functions container on both networks; prove it with a failing `wget` from inside; `HF_HUB_OFFLINE=1`, `TRANSFORMERS_OFFLINE=1` in any Python image; licence files copied into the image. |

## What the research could not settle

- No measured CPU latency or RSS for any embedding model on the actual server.
- No measured quality of static embeddings on short Swiss-German strings.
- `flutter_onnxruntime` on the web and the maturity of the llama.cpp Dart bindings are unverified
  in practice.
- Licences marked *from memory* above.
