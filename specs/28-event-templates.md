# 28 — Event templates: start a new event from a tile

*Added 2026-10-25. Builds on [05](05-module-calendar.md) (events) and the tradition starters of
[27](27-family-rituals.md#familientraditionen). Migrations `20261025150000_event_templates.sql`
and `20261128110000_event_suggestions_similar.sql` (pgTAP 245), app code in `app/lib/features/calendar/{domain,data,application,ui}/`.*

## Why

Most new events are one of a handful of kinds: a birthday, guests for dinner, a match, the
doctor, a day out. Today every one starts from an empty editor. A family types the same title,
picks the same picture, sets the same three hours and chooses the same people again and again.

**Neuer Termin** therefore opens a page of tiles first. A tile fills in the editor; the family
changes what differs and saves. A template is only a starting point. What is saved is an
ordinary event, the same as one typed from scratch; nothing remembers which tile it came from.

## The page

Kalender → **Neuer Termin** and Today's new-event button open **Neuer Termin** with three
sections of tiles, each tile a picture, a name and one line about when and how long:

1. **Häufig bei euch** — up to four suggestions from the family's own history (below). Shown
   only when there is one, and only on a server that announces `event-templates`.
2. **Eure Vorlagen** — the templates the family saved. Shown only when there is one, on a
   server that announces `event-templates`.
3. **Weitere Vorlagen** (**Vorlagen** when nothing stands above) — the built-in templates.
   **Ohne Vorlage** comes first and opens the empty editor as before; **Neue Tradition**
   follows where the server knows traditions and opens the tradition starters (specs/27).

Choosing a tile opens the ordinary editor, filled in. Back from the editor returns to the tiles;
saving closes both. The day is the one the calendar shows (as for **Neuer Termin** before); a
template's start time is put on that day, and a template without one starts at the next full
hour as before.

A tile's menu (long press, or the ⋮ on a pointer device):

- a suggestion: **Als Vorlage behalten** (saves it as the family's template) and **Nicht mehr
  vorschlagen** (hides it for the household; a hidden suggestion is never shown again);
- a saved template: **Vorlage löschen** (the author or a guardian).

**Neue Tradition** stays its own button with its own six starters (specs/27): a tradition is a
weekly series with rules of its own, not a one-off.

## Built-in templates

Each language names them itself (ARB keys `eventStarter*`), regional German included
([09](09-clients-and-ux.md#regional-german)): *Familienurlaub* in Germany and Austria,
*Familienferien* and *Gäste zum Znacht* in Switzerland.
Every value is only a suggestion
the editor shows before anything is saved.

The page lists them in this order: what a family enters often first, what comes once a year
last (*reordered 2026-11-01*, when Putzhilfe was added).

| Template | Picture | When | Length | Who | Also |
|---|---|---|---|---|---|
| Putzhilfe kommt | cleaner (broom until #297) | 09:00 | 3 h | the person creating it | weekly on the day's weekday |
| Sporttraining | football | 17:00 | 1 h | the person creating it | |
| Arzttermin | doctor (none until #297) | next full hour | 1 h | the person creating it | |
| Gäste zum Essen | house | 18:30 | 3 h | whole family | |
| Familienausflug | hiking | all day | 1 day | whole family | Darauf freuen wir uns |
| Spielen mit Freunden | game_die | 15:00 | 2 h | the children | |
| Kinobesuch | cinema | 16:00 | 2 h | whole family | |
| Familienurlaub | plane | all day | 7 days | whole family | Darauf freuen wir uns |
| Geburtstag | cake | all day | 1 day | whole family | yearly, Darauf freuen wir uns |

*Reviewed 2026-11-15, issue #271.* Each general tile now names a distinct family occasion:
sports practice instead of a generic sporting event, a playdate instead of a second birthday
tile, and a cinema trip instead of an unspecified performance. Their times, lengths and
pictures match those occasions. The cinema trip is an outing; the tradition starter Film
night is at home. A cleaner visit is help coming to the home, not a chore assigned to the
family. The family day out lasts one day; the family holiday starts with seven.

The school group meeting and individual teacher appointment have distinct local names:
*Class meeting for parents* / *Parent–teacher meeting*, *Réunion de classe* / *Entretien avec
l’enseignant*, and *Reunión de clase* / *Tutoría individual*. German uses *Elternabend* /
*Elterngespräch*, including Austria: a 30-minute appointment is not the whole
*Elternsprechtag*. School sports day stays separate from sports practice.

"Whole family" selects every active member; "the children" every active child (the person
creating it when there is none). Members' own birthdays need no template: they come from the
profile (specs/27 "Birthdays"). The Geburtstag template is for grandparents and friends.

### School

Six more built-in templates for school life (*added 2026-11-14, issue #240*), marked `school` in
`EventStarter`. They come under a heading of their own, *Schule*, after the general ones, and
the section shows **only for a family with at least one active child**; a household without
children never sees it. The general section lists only the nine above. The tiles are keyed
`event-template-builtin-<name>` like the others.

| Template | Picture | When | Length | Who | Also |
|---|---|---|---|---|---|
| Elternabend | — (a group icon) | 19:30 | 2 h | the person creating it | |
| Elterngespräch | — (a talk icon) | 16:00 | 30 min | the person creating it | |
| Schulausflug | backpack | all day | 1 day | the children | Darauf freuen wir uns |
| Klassenarbeit | book | 08:00 | 1 h | the children | |
| Schulfest | balloon | 16:00 | 3 h | whole family | |
| Sporttag der Schule | — (a running icon) | all day | 1 day | the children | |

Regional German names them as the school does: *Schulreise*, *Prüfung* and *Sporttag* in
Switzerland, *Wandertag* and *Schularbeit* in
Austria; *Elternabend*, *Elterngespräch*, *Schulfest* and the rest stay as in German.

Built-in templates live in the app (`EventStarter`, beside `TraditionStarter`) and work with
every server.

## Saved templates

**Als Vorlage speichern** in the editor's menu saves what the editor shows as a household
template: title, picture, kind (and presence state), all day, the start's time of day, the length
(minutes, or days when all day), the people, the place, the notes, the kitchen-display choice
when it was set by hand, and Darauf freuen wir uns. Not saved: the date, the repeat, the
tradition and its meal, and "Noch nicht sicher". A template is for something that comes up now
and then; something that repeats on a rule is a series.

Any member may save one on a phone or tablet, never on the wall; the author or a guardian
changes or deletes it. A household keeps at most 50. A template's title has at most 120
characters (the app shortens a longer event title). A presence template has no picture and no
countdown, as a presence event has none. Applying a template drops people who are no longer
active members.

### Data and contract

```
app.event_template
  id, household_id, title (1–120), icon_key, kind ('appointment' | 'presence'),
  presence_state (as app.event), is_all_day, start_minute (0–1439, null: next full hour),
  duration_minutes (5–10080, timed), days (1–366, all day), attendee_ids uuid[],
  location (≤ 200), description (≤ 4000), importance ('key' | 'normal' | null: the household
  default), countdown, created_by_profile_id, created_at, updated_at

app.event_suggestion_hidden
  household_id, signature (1–120), created_by_profile_id, created_at; primary key
  (household_id, signature)
```

Both have RLS enabled and forced: members of the household on a device in good standing read
them; only the `api` functions write.

| Function | Who | What |
|---|---|---|
| `api.event_templates` (view) | members | the household's templates, oldest first |
| `api.event_template_save(p_actor, p_template jsonb)` → `{id}` | any member, not a kiosk; changing one: its author or a guardian | inserts, or updates when `id` is given |
| `api.event_template_delete(p_actor, p_id)` | its author or a guardian, not a kiosk | deletes it |
| `api.event_suggestions(p_on date default null, p_limit int default 4)` → jsonb array | members | the suggestions below |
| `api.event_suggestion_hide(p_actor, p_signature, p_hidden boolean default true)` | any member, not a kiosk | hides (or shows again) a suggestion |

Errors: `WW-CAL-020 template invalid` (`template_invalid`), `WW-CAL-021 too many templates`
(`template_limit`), `template not found` (`template_not_found`, P0002, also for another household's id),
`kiosk_forbidden` and `guardian_required` as elsewhere. Writes are audited (`event_template`, `event_suggestion`) and
broadcast on the `calendar` topic.

The migration is additive (`api_version` stays 1) and adds `event-templates` to
`api.server_info`'s features. A previous app ignores it; this app hides saved templates and
suggestions on a server that lacks it. Both tables are in the export.

## Suggestions from the family's history

No machine learning and no outside service: one SQL function, `api.event_suggestions`, counts
what the family already entered. It runs as the caller (`security invoker`), so it sees exactly
the events the caller may read.

1. **Which events.** The household's events that are not deleted, not a series (no `rrule`, no
   `rdates`), not a tradition, starting within the last 365 days or the next 60.
2. **Grouped by signature**: `app.event_signature(title)`, the title in lower case with runs of
   white space made one, leading and trailing white space and punctuation removed, and cut to
   120 characters
   ("Grosi kommt!" and "grosi  kommt" are one group), together with the kind.
   *Alike signatures are one group (2026-11-28, specs/29 feature 3):* two signatures of the same
   kind are alike (`app.event_signatures_alike`) when they are equal, or equal once spaces,
   hyphens and other punctuation are removed ("Arzttermin" / "Arzt Termin", "Judokurs" /
   "Judo-Kurs"), or have the same number of words (runs of spaces and hyphens separate them) and
   every pair of words is equal or, with both words at least four characters long, has a `pg_trgm`
   similarity (`extensions.similarity`) of at least **0.62** ("Grosi" / "Grossi" 0.625,
   "Fussballtraining" / "Fußballtraining" 0.65, "Klavierstunde" / "Klavier-Stunde" by the first
   rule). A different number of words is never alike, and a word under four characters must be
   equal, so a name added or changed keeps titles apart: "Coiffeur" / "Coiffeur Mia",
   "Zahnarzt Mia" / "Zahnarzt Lia", "Zahnarzt Mia" / "Zahnarzt Mia und Noah", "Oma kommt" / "Opa
   kommt" (the word similarity of "papa" / "mama" is 0, of "turnen" / "tennis" 0.08, of
   "Elternabend" / "Elterngespräch" 0.29). Among the distinct signatures of the window, ranked
   by number of events, then most recent, then signature text, a *root* is one that no
   higher-ranked signature is alike to; every signature joins the best-ranked root it is alike
   to (a root joins itself). One hop, no chains, deterministic; the group's representative is
   the root, and the suggestion's `signature` is the representative. Known limits: two names of
   four or more letters that differ by one letter stay apart as long as the similarity is
   below 0.62 ("Lina" / "Lena" 0.25, "Jonas" / "Jonah" 0.50, "Noah" / "Noahs" 0.57), but a
   longer name pair that differs by one letter may pass, and a title that gains a word for a
   reason other than a name ("Klavierstunde" / "Klavierstunde heute") stays apart.
3. **Regular means at least three** events in the group, all its signatures counted together
   ("Fussballtraining" twice and "Fussball-Training" once is a suggestion).
4. **What a suggestion fills in** is what the group usually does: the title of its most recent
   event; the most frequent picture, all-day value, start time (in the event's time zone),
   length, people (as a set) and presence state; the most frequent place when at least half
   of the events have it.
5. **Not suggested**: a group with a hidden signature among its members, and a group with a
   signature that already has a saved template of the same kind. Hiding and saving still name
   one signature, the one the tile showed; a hidden or covered signature that has no event in
   the window any more is not a member and hides nothing.
6. **Order.** Each event weighs 1 in the last 90 days (or ahead) and ½ before. With `p_on`, a
   group whose most frequent ISO weekday is `p_on`'s counts 1.5 times. Highest first, then the
   most recent, then the signature. At most `p_limit`, clamped to 1–12 (null: 4). Ties in
"most frequent" go to the most recent event's value.

A caller without a household or on a revoked device gets `[]`. Case folding and punctuation
follow the database's locale: on a `C`-locale database only ASCII letters are folded.

Each element: `signature`, `title`, `icon_key`, `kind`, `presence_state`, `is_all_day`,
`start_minute`, `duration_minutes`, `days`, `attendee_ids`, `location`, `count`, `last_on`.
The tile says how often ("5× benutzt"), or only "5×" where the line would not fit, with the
whole line as its tooltip.

## Considered and not chosen

- **A local language model** (e.g. a small model in an Ollama container) to merge
  near-duplicate titles and to read a typed sentence ("Abendessen mit Müllers Samstag 19 Uhr").
  Several GB of memory on every family's server, answers that are hard to predict, and it
  touches the paused assistant work ([deferred](deferred/mcp-and-ai-assistants.md)). Counting
  covers "the things we do often", and `pg_trgm` similarity in the same function merges
  near-duplicate titles (rule 2; *done 2026-11-28*, a step the first version of this note
  foresaw). *Amended 2026-10-31 by [ADR-021](adr/ADR-021-local-matching.md): the rule is "no
  outside service; a bundled dictionary or model only", and [29](29-local-matching.md) adds a
  title → picture matcher and the `pg_trgm` signatures as its third feature.*
- **Transitive grouping** (a chain of similar titles is one group): "A" ≈ "B" ≈ "C" can drift
  far from A, and the representative would depend on the order of merging. One hop from a root
  is deterministic and easy to explain.
- **Templates carrying a repeat.** Only the built-in Geburtstag does (yearly). A saved template
  would have to move a weekly rule to the new day; a series is the right tool for that.
- **Folding Neue Tradition into the page.** Kept apart for now; the tile page may take it in
  later.
- **Remembering which template an event came from.** Nothing would read it.
