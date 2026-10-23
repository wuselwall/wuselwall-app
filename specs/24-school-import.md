# 24 — School setup without typing: fewer facts, imports, proposals, scanning

*Added 2026-10-22.* Builds on [15](15-module-school-timetable.md) (the Stundenplan),
[12](12-mcp-and-assistants.md) (assistants) and [20](20-onboarding.md) (onboarding).
Decision context: the onboarding review of 2026-10-22 with the pilot household's own
experience. Measured by NFR-17's "smooth" check, applied to the school.

The family part of onboarding is lean: one screen for the family, one for the people, then
Today. The expensive part is the second week, when the school goes in. Before a parent
could fill a grid they created a school, confirmed bell times, created a term with dates
and an A/B anchor, accepted or edited subjects, imported holidays, and only then entered
the grid for each child. Five sections before the first lesson. The pilot household's
answer to "where did the minutes go?" was: the scaffolding, not the grid.

This document is the answer in four parts, ordered by cost: ask for fewer facts, let a
sheet come in as text, let an assistant hand one in as a proposal, and read a photo on the
family's own server. Every part ends in the same preview, and nothing exists until a
guardian taps *Übernehmen*.

> **Built 2026-10-22 (all four parts, first version):** the prefilled term, subjects from the
> cell, the first-school page and its next steps; the paste import with the preview; the
> proposal table, `api.mcp_propose`, the `propose_timetable` tool and the proposal cards; the
> `timetable-scan` function, the grid parser and the optional `ocr` container. Not yet:
> on-device OCR, the share-sheet entry, proposals of other kinds. See "What is not built".

## Decisions

1. **The assistant may propose, never change.** [12](12-mcp-and-assistants.md) said "lessons
   are read-only over MCP, permanently", so that "Mathe fällt aus" could never rewrite a
   term. That intent stands: an assistant still changes no timetable. It may hand the
   family a *proposal*, a payload stored on the server with shape checks only, which a
   guardian reviews in the app and applies with their own writes. A bad proposal touches
   nothing. The rule in [12](12-mcp-and-assistants.md) is amended accordingly.
2. **No AI the project runs.** P1 and P2 of [23](23-roadmap-after-alpha.md) hold. The text
   import works with whichever assistant the parent already uses and trusts (the same
   stance as the shopping scope). The scan runs on the family's own server, or not at all.
3. **No Google ML Kit on the phone.** Q49 removed it for the QR scanner because it reports
   device and usage data to Google; the same reason applies to text recognition. On-device
   OCR means Apple's Vision on iOS (built into the OS, no SDK) and nothing on Android until a
   clean option exists. Both wait; the server path serves every platform now.
4. **One payload, one preview.** Paste, proposal and scan produce the same JSON and land on
   the same screen. The preview is built once and the three ways in are thin.

## Fewer required facts

What the first version removes from the parent's path, all built:

| Before | Now |
|---|---|
| A term with name, both dates and the A/B anchor before any lesson | The term is **proposed**: the school year around the week on screen, 1 August to 31 July, named "Schuljahr 2026/27" in the app's language, current when the school has no term yet. The dialog comes prefilled; one tap continues. Name and dates stay editable, the A/B anchor stays optional |
| A subject must exist before a cell can use it | Typing a short code the household lacks offers **"„Phy“ als Fach anlegen"** in the cell dialog. The subject is created with that text as name and short name and the least used tint, and the cell takes it. The subject page remains for colours, icons and equipment |
| Five sections on the setup page before the first school is saved | The **first school** asks for name and region only, with one button, and a line saying bell times and subjects are proposed. Bell times, terms and holidays appear once the school exists |
| Nothing says what comes next | **Next steps** at the top of the setup page: every child without a timetable in the current term, one tap to the editor (with the proposed term) or to the import |
| "Copy from" exists but is easy to miss | Unchanged in the editor; the next steps and the docs point to it |

The setup card's copy changed with it: "Lege die Schule an. Klingelzeiten und Fächer werden
vorgeschlagen; den Stundenplan trägst du danach ein oder liest ihn ein."

What stays deliberately: the holiday import (one tap, region-based, already built), the
bell-time editor (most schools match the template; the rest edit once), and the grid itself
(cell by cell is fine for a sheet with twenty-five cells; the import exists for the rest).

## The payload

The format every way in produces and every way out reads, `wuselwall-timetable/1`.
Names, never ids: subjects by their short name or name, days by number or name in any of the
four languages, lessons by period or by clock time. Resolution against the household's
subjects and bell times happens in the app, at preview time.

```json
{
  "format": "wuselwall-timetable/1",
  "member": "Emma",
  "school": "Grundschule Lindenhof",
  "class": "3b",
  "week_cycle": "weekly",
  "periods": [{"index": 1, "starts": "08:00", "ends": "08:45"}],
  "lessons": [
    {"day": "Mo", "period": 1, "subject": "Ma", "name": "Mathematik", "room": "R12"},
    {"day": 4, "starts": "08:50", "ends": "09:35", "subject": "E", "teacher": "Fr. Kurz", "week": "a"}
  ],
  "grid": {"Di": ["Ma", "D", null, "Sp"]},
  "care": [{"title": "Hort", "days": ["Mo", "Di"], "starts": "13:30", "ends": "15:30"}]
}
```

- `lessons` or `grid` (one list per day, index = period) or both; an empty cell is skipped.
- `day`: 1–7 (Monday first) or `Mo`, `Montag`, `Thu`, `mar.`, `mié` and so on.
- `period`: 1–15, also as `"1."` or `"1. Stunde"`; or `starts`/`ends`, matched to the bell
  time that starts within five minutes.
- `week`: `a` or `b` for A/B weeks; `week_cycle` is derived when absent.
- `periods`: the sheet's bell times, used when the school's own need extending.
- Everything else is optional. The parser is tolerant about the wrapping (a code fence, a
  sentence around the JSON) and strict about the shape.
- Bounds, the same in the app and the server: 200 lessons, 15 periods, 10 care rows,
  strings of 60 (names), 40 (room) or 120 (school) characters, 64 KB in all.

Where it lives: `app/lib/features/school/domain/timetable_import.dart` (parse, resolve,
extend bell times, pick a tint), `app.proposal_check` (shape on the server),
`_shared/timetable_ocr.ts` (the scan's output).

## The preview

`TimetableImportPage`, reached from the paste sheet, a proposal card or the scan, guardian
only (the server refuses the writes of anyone else):

- the child (preselected when the payload names one, else the first) and the school (when
  there are several, matched by name first);
- the term the import lands in: the one covering the week on screen, else the proposed
  school year, marked "(wird angelegt)";
- the count, the class, the cycle, and a line when an existing timetable will be replaced;
- the grid as it will be saved, with the bell times, new subjects in bold, dropped ones
  struck through;
- the subjects that will be created, with a switch to leave them (and their lessons) out;
- the care rows;
- every warning: lessons whose time matched no bell time (dropped), periods beyond the bell
  times (the bell times are extended, 45 minutes after a 5-minute break, or from the sheet's
  own times), a sheet whose bell times differ from the school's (the school's stay), a sheet
  naming another school, and from a scan the text pieces that fit no cell.

*Übernehmen* then writes, in this order and each through the existing school functions with
the guardian's own actor: the term when missing, the extended bell times, the new subjects,
the timetable's metadata, the whole grid, and the proposal's verdict when there was one. A
failure stops at that step and says so; what was written (a subject, a term) is ordinary data.
*Verwerfen* rejects a proposal without a look.

## Paste: the assistant the family already has

The parent photographs the sheet, gives it to their assistant with the instructions the app
copies to the clipboard (the sentence in the app's language plus the format above), and
pastes the answer into *Einlesen… → Aus Text einfügen*. This works on a phone, with any
assistant, with no key, no server change and no new party: the privacy decision is the
parent's existing one.

The paste sheet names the one error it saw: no JSON, no lessons, too many entries, a lesson
without day/period/subject, a day or time it cannot read, each with the offending value.

## Proposals

The pattern that lets an assistant hand something in without being able to change anything.

**`app.proposal`**

| Column | Meaning |
|---|---|
| `kind` | `timetable` (more kinds later: members, holidays, events) |
| `payload` | The JSON above, checked for shape and size only (`app.proposal_check`), never resolved |
| `source` | `mcp` or `scan` |
| `proposed_by_profile_id`, `assistant_label` | Whose key, and the key's label ("Claude"), so the family knows which assistant spoke |
| `summary`, `client_key` | One line for the card; the client's id, so a retry returns the same proposal |
| `status` | `open`, `applied`, `rejected`; the view reads an open row past `expires_at` (14 days) as `expired` |
| `resolved_by_profile_id`, `resolved_at` | The guardian's verdict |

Rules:

- **`api.mcp_propose`** (service role only, the `mcp` function) is the assistant key's one
  write. The key stays read-only for every table of the household: `app.key_actor` still
  refuses writes for assistant keys, and this function never touches anything but
  `app.proposal`. At most five open proposals per person; the sixth is refused
  (`proposal_limit`), so a looping assistant stops early. Rows resolved or expired a month ago
  are deleted on the way in.
- **`api.proposal_resolve`** (guardians, never on a kiosk) records `applied` or `rejected`
  once. The app calls it after its own writes. The audit log therefore shows the creation
  with origin `mcp` on behalf of the key's holder, and the apply as the guardian's own act
  with the proposal's id and assistant in the diff: "Papa applied a timetable proposed by
  Claude". The marker of R1.4 falls out of it.
- **`api.proposals`** is read by the household; the app shows open ones to guardians, as a
  card on Today and above the Stundenplan: assistant, summary, *Prüfen*, *Verwerfen*.
- Realtime: every proposal write broadcasts the `school` topic, so the cards refresh.
- pgTAP: `supabase/tests/225_proposals.test.sql` (34 assertions: who may propose, the shape
  check, idempotency, the cap, who sees what, the verdict, expiry).

## The MCP tool

`propose_timetable` in `_shared/mcp_family.ts`: `member` (name), `lessons` (the list
above), optionally `class`, `school`, `week_cycle`, `periods`, `care`, `client_key`.
Annotations: `readOnlyHint: false`, `destructiveHint: false`, `idempotentHint: true`. The tool
resolves the member's name against the family (an unknown name is the usual actionable
error), stores the payload with the member's display name, and answers in the household's
language: "Vorschlag gespeichert: Stundenplan für Emma, 24 Stunden. Eine
erziehungsberechtigte Person prüft ihn in WuselWall …". The server's instructions now say
that a proposal is the one thing the connection can hand in.

The scope is still the interim assistant key of Q15; the new write lives under it because it
changes nothing. When OAuth and the write scopes come (R3.1), proposals belong to a scope of
their own, `import:propose`, granted separately from `shopping:write`.

## Scanning

### What was looked at (2026-10-22)

- **Immich** reads text in photos since v2.2.0 (October 2025) with RapidOCR: PaddleOCR's
  PP-OCR models on ONNX Runtime inside its machine-learning container, CPU or GPU, models
  from Hugging Face on first use. The engine and the models are Apache-2.0; Immich itself is
  AGPL-3.0, its container is built for its own request format and ships CLIP and face models
  beside OCR, and standalone use is undocumented. It is a reference implementation, not a
  dependency.
- **RapidOCR** on its own (`rapidocr` 3.x, Apache-2.0, maintained) runs the same models with
  a Latin-script variant that covers German, French and Spanish, returns text with boxes and
  scores, and runs on a CPU in well under a second per sheet with the mobile models. That
  is the self-hosted path.
- Alternatives: Tesseract (small, weaker on photographs), docTR and EasyOCR (PyTorch, heavy,
  EasyOCR stagnant), PaddleOCR serving (heavy framework), Surya (weights under a
  non-commercial licence). None beats RapidOCR for this job on a home server.
- **On the phone:** Apple's Vision (`VNRecognizeTextRequest`) is built into iOS, reads German
  in accurate mode and gives boxes; a small platform channel exposes it without a third-party
  package. Google ML Kit reads on the device but reports device, package and usage data to
  Google (its own data disclosure), which Q49 already ruled out. ONNX-based Flutter packages
  with PP-OCR models exist but are young and bundle 30 MB of models.
- **Table structure models** (PP-Structure, Table Transformer) are heavier than the problem:
  a timetable is a regular grid with a weekday header and period labels, so geometry does.

### What is built

```
 phone ──(photo, ≤6 MB)──► timetable-scan (Edge Function, caller's JWT verified)
                              │  multipart POST
                              ▼
                        ocr (optional container, RapidOCR, CPU, no public port, no internet)
                              │  {lines: [{text, box, score}]}
                              ▼
                        _shared/timetable_ocr.ts: header → columns, labels → rows,
                        boxes → cells, cells → lessons (subject, room, teacher)
                              │  the payload + placed/unplaced counts
                              ▼
                        the preview, as for paste and proposals
```

- `infra/supabase/ocr/`: a Dockerfile (python, `rapidocr`, `onnxruntime`, FastAPI) and
  `server.py` with `POST /ocr` and `GET /health`. The models are fetched at build time; the
  running container needs no internet. Off by default: profile `ocr` in the compose overlay,
  `OCR_URL=http://ocr:9003/ocr` in the stack's `.env`, 2 GB memory limit. The release bundles
  it with the stack. [docs/server/extras](../docs/server/extras.md) tells a family how.
- `timetable-scan`: verifies the caller (any member; reading changes nothing, applying needs a
  guardian in the app), refuses more than 6 MB or another type, posts to `OCR_URL`, answers
  `ocr_not_configured` (503) when unset, `scan_nothing_found` (422) when no weekday header was
  found, `ocr_failed` (502) when the service does not answer. Stores nothing, logs no image.
- The grid parser: the horizontal band with the most distinct weekday names (three at least,
  in weekday order) gives the columns; labels left of the first column with a period number
  or clock times give the rows, and clock times become the payload's `periods`; without
  labels the cell texts form the rows. Every other box lands in the nearest cell within
  six tenths of a column or row spacing, or counts as unplaced. In a cell, the first token is
  the subject, tokens with digits the room, the rest the teacher. Tested on synthetic sheets
  (`timetable_ocr_test.ts`); the unplaced count reaches the preview as a warning.
- The app: *Einlesen… → Foto scannen*, a sheet saying the photo stays at home, camera or
  gallery through `image_picker` (Flutter's own plugin, no telemetry, pictures resized to
  2400 px), a busy dialog, then the preview. A server without OCR gets the message pointing
  at the guide.

### What was not verified

The container was built from the Dockerfile and read a rendered sheet (five weekdays, five
numbered periods with bell times, twenty-one cells) without a miss, and the parser placed
every cell and took the bell times from the labels.

*2026-10-23:* sixteen public sheets (Wikimedia Commons renders and scans, school and
ministry PDFs from Germany, Austria, Switzerland, England and Canada, one worn handwritten
card) went through the container and the parser, locally, never committed. Fifteen yield a
grid; the sixteenth is a bell-time regulation sheet, so "no grid" is right. What the first
real sheets taught, all built since: letter-spaced print ("M ittw och"), a typo ("Dinstag")
and truncated columns ("Dinsd") are matched against the full names by prefix or one edit;
a header the OCR returns as one box is split along its width; "Stunde 3" counts as a row
label; text in the header band is not a lesson; row labels may sit close to the first
column; a name in parentheses is the teacher; weekdays the OCR garbled are inferred when
the header's spacing per day is even. The clean renders and scans come back complete, with
subject and room per cell; the handwritten card gives six columns but only a third of its
cells.

*Second round, same day, 48 more files from four searches:* software-made sheets (Austrian
Volksschulen, Swiss Excel and Untis-style sheets with teacher codes, a Canva design), French
and Spanish sheets, eight look-alikes (a shift rota, a bus timetable, a canteen menu, a
bell-time table, a holiday calendar, a gym course plan) and eight poor photographs (skewed,
blurred, frosted, an LED board, a 330-pixel thumbnail). What it taught, built since: a sheet
that left-aligns its text puts the teacher code at the cell's right edge, so cells now run
from a header's left edge to the next one's, which also holds for centred text. Results:
every German, Austrian, Swiss, French and Spanish class sheet yields a grid; the Swiss
Excel sheets with stacked class-split cells and legends leave a third to a half of their
text unplaced, which the preview reports; dense two-line cells without a label per row are
halved. Seven of the eight look-alikes give "no grid"; the gym course plan parses, as any
weekly grid with weekday headers will, and only the subjects on the preview tell a parent.
No poor photograph produced a false grid, and the thumbnail parsed completely. Whole-school
master plans, a substitution plan and a transposed sheet (days down the left) give "no
grid". What remains open is the real photograph from a phone: paper, shadows, a slant.
The preview's warnings exist so that a parent sees what the parser missed. The
RapidOCR language switch is used when the installed version has it, with the default models
as fallback, so an API change in `rapidocr` degrades to "reads Latin letters without
accents" rather than to a failed build.

## What is not built

- **On-device OCR.** iOS through Vision would remove the server from the loop for iPhone
  families; it needs a platform channel and a real device to verify, and waits for the pilot
  to show the server path is not enough. Android has no clean option.
- **The share sheet as entry.** Receiving text or a picture shared from another app needs a
  native intent filter and a plugin; the clipboard and the picker do the same job today.
- **Proposals of other kinds** (members, holidays, events): the table takes them, the review
  screen does not yet.
- **An `import:propose` scope.** Comes with OAuth (R3.1).
- **WebUntis and other portal exports.** The pilot's schools publish paper, PDF and closed
  platforms (Sdui, IServ, Schulmanager), so there is nothing deterministic to parse; R4.4 stays
  "only when a family asks".

## How "smooth" is checked

With the pilot household and their real sheets, before and after:

1. From "Schule einrichten" to the first saved timetable, by hand: minutes and taps.
2. The same sheet through the paste import with the parent's own assistant: minutes, and how
   many cells needed correcting on the preview.
3. The same sheet through the scan: the unplaced count and the corrections.
4. Twice a year: the new sheet through *Copy from* plus corrections, against the import.

The parser and the resolver are pure and tested; what the pilot teaches goes into the
thresholds and the warnings, not into new screens.

## Sequencing

| Phase | Deliverable | State |
|---|---|---|
| 1 | Fewer required facts: proposed term, subjects from the cell, the first-school page, next steps | Built |
| 2 | The payload, the preview, the paste import | Built |
| 3 | Proposals: table, functions, tests; the MCP tool; the cards | Built |
| 4 | Scanning: the container, the function, the parser, the app's way in | Built, unverified on real sheets |
| 5 | The pilot's measurements, threshold tuning, iOS Vision if the server path is not enough | Open |
