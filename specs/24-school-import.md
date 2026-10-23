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
- the grid as it will be saved: each period with its clock span, each subject's short name
  with its name underneath (on a phone the cells are too narrow, a long press shows it), new
  subjects in bold, dropped ones struck through;
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
- The app: *Einlesen… → Foto scannen*, a sheet saying the file stays at home, camera or
  gallery through `image_picker` (Flutter's own plugin, no telemetry, pictures resized to
  2400 px and re-encoded, so an iPhone's HEIC arrives as a JPEG), or *Datei wählen* through
  `file_picker` for the school's PDF or a picture kept elsewhere, a busy dialog, then the
  preview. A server without OCR gets the message pointing at the guide.
- **PDF** (*added 2026-10-23*): the function accepts `application/pdf` and `image/heic`; the
  service reads a PDF's **text layer** with positions through `pypdfium2` (no OCR at all,
  exact), joining the per-character rectangles into words along their baselines, and renders
  the first page for OCR only when the layer holds fewer than eight pieces (a scan). The pilot's
  own school PDF came through the text layer as five days, eight rows with both breaks and all
  eight bell times, better than the OCR of its rendering. HEIC originals decode through
  `pillow-heif`.
- **The family's words** (*added 2026-10-23*): the app sends its language and the household's
  subject names (short and long) with the scan. The parser then uses only that language's
  short weekday forms, since short codes collide across languages ("Ma" is Mathe in German and
  mardi in French; "SU" is Sachunterricht and the English Sunday), while the full names of
  every language stay matchable by prefix, so a French sheet in a German family still reads.
  A token that is one of the family's subjects is never a weekday by guess. Without hints, every
  short form counts, as before. Which subject names and codes exist per region, how they
  group, and which codes collide (with weekdays and with each other) is researched in
  `specs/research/school-subjects/`; its section 6 says how the matcher and the starter
  subject lists should use it.
- **The language's words** (*added 2026-10-23*): `_shared/school_subjects.ts` carries the
  subject names and codes of German (DE, AT, CH), French (FR, Romandie), Spanish (with the
  co-official languages' words), Italian (Ticino) and English, from the research. With the
  family's language known, a cell's code gets its full name in the payload (`name`:
  "SU · Sachunterricht", "EPS · Éducation physique et sportive"), so the preview and a
  created subject carry both; a long name is one subject even across words ("Natur, Mensch,
  Gesellschaft", "Calcul mental", "ARTS PLASTIQUES"), the words after it the teacher; a word
  the OCR almost read snaps to the family's own word or the language's name (one edit for
  five letters, two for nine: "Sachuntericht", "MATHEMATIQUE", "ARBEITSGEMEINSCHAFTEN"),
  short codes never snap; a cell that is a break ("Pause", "Récré", "Esplai", "Mittag") is
  no lesson; a code with several meanings in the language ("TG", "AP", "CS") stays bare for
  the parent to name; without a language no code is named, since "Ma" is Mathematik in
  German and Mathématiques in French. The Spanish two-letter weekdays "Lu Ma Mi" count only
  for a Spanish family, as "Ma" is Mathe on every German sheet. Over the corpus the grids
  and lesson counts stay the same; the named cells go from none to most (Alpuente 53 of 61,
  Wangen 33 of 38, Leonhard 23 of 24, the own PDF snaps its one misread "Sachuntericht").
  Where the family's language and the sheet's differ, a near name of the family's language
  can win ("English" → "Englisch"); acceptable for the family that would name it so.
- **The sheet's own words, and the family's** (*added 2026-10-23, roadmap steps 1 to 7*):
  the parser reads the **legend** many sheets print under the grid (a code and its name in
  one box, or in two boxes on one line, in a one- or two-column legend); only codes that
  stand in a cell count, the lines read no longer count as unplaced, and a legend name the
  language almost knows snaps to it ("BMewegung und Sport"). The legend beats the language's
  word, so Wangen's "GES tc" reads Technisches Gestalten and Augustinum's "E4" Englisch für
  die 4. Schulstufe. A subject **remembers the words** sheets used for it (`subject.aliases`,
  migration `20261023110000`): the scan sends them (`subjectList` with short name, name and
  aliases), a cell with any of a subject's words gets the subject's short name, and the
  app's resolver matches aliases too. In the preview every new subject has a list: **create
  it**, or **take it as** an existing subject, which then remembers the sheet's word; the
  scan **preselects** the family's subject of the same group when exactly one exists
  (`like`: "HSU" at the family's Sachunterricht, never "F" at Englisch, since every language
  is its own group). A **week marker** on the cell ("A", "B", "Q2", "A-Woche") becomes the
  lesson's parity; a word in capitals in parentheses is a **room**; a word the OCR split at
  a line break is **joined** when the join is a word of the family's or of the language
  ("Sachunter richt", "Mathe matik"); a level behind a code keeps the name ("E1"); a **care
  word** on a row with clock times (Hort, Mittagstisch, Cantine, Comedor) becomes a care row
  of the payload. Ten public sheets of the corpus live as **fixtures** with their expected
  grid sizes (`_shared/fixtures/timetables/`, `timetable_ocr_corpus_test.ts`), so a tuning
  that loses a sheet fails in CI; the own sheets never. Over the whole corpus no grid or
  lesson count changes.
- **Starter subjects per region** (*added 2026-10-23*, specs/21): the first school brings
  the subject list of its region in the words its sheets print, so the scan matches them:
  Germany, Austria (2023/24 names), German-, French- and Italian-speaking Switzerland,
  France, Spain with the co-official language of the region. The app sends its language
  with the school for the bilingual cantons and for countries without a list.
- **Accents** (*checked 2026-10-23*, roadmap step 9): the Latin-script recognition model
  reads the accented letters of the German, French and Spanish subject names at 98.7 to 100
  percent in four fonts from 18 px up, so no sheet needs another model; `fold` maps œ and æ
  to oe and ae as the app does.

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
master plans and a substitution plan give "no grid".

*Third round, twelve photographed sheets* (Commons and Flickr: a crumpled sheet held in two
hands, a hand-drawn plan under museum glass, Kurrent handwriting from 1898, a diary page, a
projector screen, a corkboard, sheets in Finnish, Korean and Russian). Two of them run the
days down the left and the periods across the top, as a diary page or a hand-drawn sheet
often does, and so did the Spanish photo of the second round: the parser now reads a sheet
**turned** when no horizontal header exists, by swapping the axes and running the same
algorithm. That pass needed a **plausibility check**, which now guards both readings: at
least two periods (three when turned, since a one-row list of weekdays is a rota or a menu),
at most four text pieces per cell (a master plan packs dozens into what looks like one), and a
turned reading that placed more than it dropped. With it, the whole corpus of 80 files
classifies as it should: every class sheet in five languages is a grid, the gym course plan
is the one look-alike that parses, and every other look-alike, poor photograph, master plan
and sheet in an unsupported language gives "no grid". Handwriting itself stays beyond the
OCR: the diary page yields its six days and nine periods but a third of its cells.

*Fourth round, the pilot household's own sheets:* seven iPhone photographs (HEIC, as the
picker converts them to JPEG for the app), a software-made PNG and the school's PDF. They
taught what no public file had: a phone photo tilts, by a few degrees or by ninety when the
sheet was held sideways, and a child's hand writes "Pierstag" and "Pornerstag". Built since:
the sheet is **levelled** first, by the median direction of its words taken from the OCR's
quads, and read in all four orientations after that; weekday names may be two edits off when
they are long; "Ma" is Mathe, never mardi, so the two-letter French abbreviations went; the
header band is one text line, with a looser second try; a period label is the whole text, so
"1. Semester" in a remark is none; whichever kind of label, number or clock, marks more rows
defines them; a bare "800" on a label is 08:00. Result: eight of the nine own sheets yield
a grid, with the cells readable and the bell times taken from the labels; the ninth is a
Kindergarten plan whose handwritten header defeats the OCR itself. The corpus stands at 89
files: 59 grids, 30 "no grid", and every look-alike and poor photograph on the right side.

What remains is handwriting the OCR cannot read, and the Swiss sheets' "×" marks, which the
preview shows as subjects named "×" until the parent clears them. The preview's warnings exist
so that a parent sees what the parser missed. The
RapidOCR language switch is used when the installed version has it, with the default models
as fallback, so an API change in `rapidocr` degrades to "reads Latin letters without
accents" rather than to a failed build.

## Recognition roadmap

What the research and the corpus say the next steps are, in the order they pay off. None
needs a model; all stay on the family's server. *Status 2026-10-23: steps 1 to 7, 9 and 10
are built (see "The sheet's own words, and the family's", "Accents" and "The preview" above);
8 stays open.*

1. **Read the legend.** Swiss, Spanish and most Untis sheets print `CODE Name` pairs under
   or beside the grid. A block of short-code-plus-name lines outside the grid resolves every
   code on that sheet with certainty and beats every list above. Parser only, tested on the
   corpus sheets that have one (Wangen, Sumiswald, Alpuente, the Berlin legend).
2. **Remember the family's corrections.** When the parent renames a scanned subject in the
   preview or merges it into an existing one, keep the sheet's word as an alias of that
   subject (`subject.aliases`, sent with the hints). The next scan, twice a year, then needs
   no correction. Table column, one function change, the preview's merge action.
3. **Match by group in the app.** The resolver matches by short name and name only. Give
   each vocabulary entry its research group (17 groups) and let the preview offer "same as
   Sachunterricht?" when a scanned "Sachkunde" or "HSU" has no match but an existing subject
   of the same group exists, instead of creating a second one.
4. **Strip what is not the subject.** Week markers (`A`/`B`, `Q1`/`Q2`, `S1`/`S2`) become the
   lesson's parity (the payload has it); level and group suffixes (`E1`, `F3`, `Math Sek`,
   `Knaben D`) come off the code; Valencian rooms in parentheses (`(MAT1)`, `(PATI1)`) are
   rooms, never subjects.
5. **Join wrapped cells.** Spanish and French sheets wrap a name over two lines ("Diseño Web /
   y redes", "Cumunic / aciones") and put the teacher on the next. Joining vertically adjacent
   lines inside one cell when the join is a known word, before `lessonOf`, reads these; the
   vocabulary says when a join is a word.
6. **Care rows from care words.** Hort, Mittagstisch, périscolaire, comedor, Betreuung cells
   become `care` entries of the payload (it has them) rather than lessons, so the timetable
   shows them as the module intends (specs/15).
7. **A regression corpus in CI.** The OCR line files of the public sheets (Wikimedia Commons,
   school websites) can live in the repository with the expected grid sizes; a test runs the
   parser over them so a tuning never silently loses a sheet. The own sheets never.
8. **Starter lists checked against sheets.** No real sheet was found for Rheinland-Pfalz,
   Sachsen-Anhalt, Thüringen, NRW primary, the Romandie, Ticino, the Basque Country, Navarra
   and the Balearics; their lists and codes are official names and conventions. One sheet per
   region, read through the scan, settles the short names. Belgium, Luxembourg and the
   Netherlands have no list yet.
9. **OCR accents.** *Checked 2026-10-23; nothing to change.* The service selects RapidOCR's
   PP-OCRv5 Latin-script recognition model explicitly, and its dictionary (503 entries, in
   the model's metadata) holds every accented letter of German, French and Spanish. The
   measurement: the 54 accented words of the subject lists of de, fr and es (Français,
   Mathématiques, Educación, Física, Förderunterricht, ...), set in 5x5 grids under a weekday
   header with four real fonts (DejaVu Sans, Liberation Sans, FreeSerif, Lato) at 18, 26 and
   36 px, posted to the container and aligned letter by letter: the accented letters came
   back at 98.7 to 100 percent and the plain letters at 99.0 to 100 percent for every font
   and size. The only confusion is FreeSerif's "rn" read as "m" at 18 px (twice in 606
   letters); no letter ever became a digit; upscaling the sheet twofold before recognition
   moves the misses around and changes no figure. The misses that remain are a detection
   quirk unrelated to accents: the box around "Tutoría" is sometimes not found at all, and
   plain "Tutoria" just as often, while "Teoría" and "Autoría" are found every time. A
   caution for whoever repeats this: Pillow's bundled fallback font (`ImageFont.load_default`)
   has no proper glyphs for accented letters and draws other marks in their place, so a sheet
   drawn with it loses every accent (0 of 77); that is the font, not the model, and no reason
   to change anything. Should a real sheet ever show the model losing accents, PP-OCRv6's
   multilingual small recognition model (`lang_type` EN, `ocr_version` PPOCRV6, `model_type`
   SMALL) is already in the image as the ready fallback. On the parser's side a dropped
   accent costs one edit, which `snapSubject` absorbs for words of five letters or more
   ("Fran6ais" snaps to Français), and `fold` maps œ and æ to oe and ae as the app's
   `foldText` does.
10. **The preview shows the name.** Built: the grid shows each subject's name under its
    short name (on a phone, where five columns leave no room, a long press shows it), the
    row header shows the period's clock span, and the merge action of step 3 is in the list
    of new subjects; the payload carries the name already.

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
| 5 | The language's words and the starter lists per region, from the research | Built |
| 6 | The recognition roadmap, steps 1 to 7: legend, aliases, suggestions, markers, wrapped words, care rows, the corpus in CI | Built |
| 7 | The pilot's measurements, roadmap steps 8 to 10, iOS Vision if the server path is not enough | Open |
