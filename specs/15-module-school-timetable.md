# 15 — Module: School Timetable & Presence (A5)

*Added 2026-08-30, after the original four modules were specified. Implements
FR-7.1 – FR-7.13 and the presence half of FR-1.11 – FR-1.17. Decision context:
[ADR-008](adr/ADR-008-school-timetable-model.md) and
[ADR-009](adr/ADR-009-event-kinds-and-presence.md).*

Read [05 — Calendar](05-module-calendar.md) first. This module does not replace it: the
Stundenplan is a *pattern* that the calendar renders, and presence is an *event kind* the
calendar already stores. Both exist because the same question — "what does this week look
like?" — has three different answers depending on who is asking:

| Question | Asked by | Answered by |
|---|---|---|
| "Does she need her sports kit tomorrow?" | A parent, at 21:00 | The **Stundenplan** |
| "Are you working on Thursday?" | The other parent, planning | A **presence** entry, maintained as a pattern |
| "When are you back?" | Everyone, constantly | A **presence** entry, entered ad hoc |
| "What is on this week?" | The kitchen, at a glance | The **week board** ([09](09-clients-and-ux.md)) |

---

## Part 1 — the Stundenplan

### Why it is not just recurring events

The obvious implementation is one recurring event per lesson: `FREQ=WEEKLY;BYDAY=TU`
until the end of the school year, one series per subject per slot. Two children, six
lessons a day, five days a week is roughly **sixty recurring series**, and every one of
them needs an `EXDATE` for every single day of every school holiday. Germany gives you
around 75 of those per year. That is 4,500 exclusion dates to maintain by hand, and every
"beweglicher Ferientag" announced by the school in November means editing sixty series.

It also gets the editing model wrong. Nobody edits a timetable one lesson at a time. It
arrives as a grid on a sheet of paper in the first week of term, it is typed in once, and
thereafter it changes in whole rows ("Mittwoch ist jetzt Schwimmen") or on single dates
("Deutsch fällt heute aus").

So the timetable is stored as what it is — a **pattern**: weekday × period → subject,
valid for a term, minus the holidays, plus the exceptions. It is projected into the
calendar at read time. See [ADR-008](adr/ADR-008-school-timetable-model.md) for the
alternatives and what this costs.

### The pieces

```
school            the school itself: name, Bundesland (drives the holiday feed)
school_period     the bell times: 1. Stunde 08:00–08:45, Pause, 2. Stunde 08:50–09:35 …
school_term       Schuljahr / Halbjahr, with a start and end date
subject           Mathematik, short "Ma", a colour and an icon
timetable         one child + one term + one class → the grid
timetable_lesson  one cell of that grid: weekday, period, subject, teacher, room
timetable_exception  one date: Entfall, Vertretung, Raumänderung, Zusatzstunde
school_holiday    Ferien, bewegliche Ferientage, closures — suppress the whole day
```

Columns are in [04 — Data Model](04-data-model.md#school-stundenplan).

**Bell times are shared, not repeated per lesson.** A lesson stores a period index, not a
clock time. When the school moves first period from 08:00 to 07:55 — which happens — you
change one row and every child's timetable at that school moves with it.

**A/B weeks.** Many German schools alternate a Doppelwoche. `timetable.week_cycle` is
`'weekly'` or `'ab'`, and each lesson carries `week_parity` of `all`, `a` or `b`. The
parity of a given calendar week is derived from `school_term.ab_anchor_week` — an anchor
plus ISO week arithmetic, never a stored per-week table. If the school does not use A/B
weeks, `week_cycle='weekly'` and the whole concept is invisible in the UI.

**Hort, Betreuung and AGs are lessons too.** `timetable_lesson.kind` is
`lesson | care | club`. "Hort bis 15:30" is a care row on four weekdays, and it is
exactly what a parent needs to see on the week board. Modelling it separately as presence
would split one child's day across two mechanisms for no benefit.

### Projection: from pattern to occurrences

A single pure function, tested to death, because everything downstream depends on it:

```ts
projectSchoolDays(
  timetables: Timetable[],        // valid on the dates in the window
  window: DateRange,
): SchoolOccurrence[]
```

The rules, in order — order matters and the tests should enforce it:

1. For each date in the window, take the timetables valid on that date (`valid_from` /
   `valid_to`, and the term's range).
2. Drop the date entirely if a `school_holiday` covers it for that school. Weekends too,
   unless a lesson exists for that weekday.
3. Expand the lessons for that weekday, filtered by the week's A/B parity.
4. Resolve times from `school_period` (or the lesson's own override, for the rare lesson
   that does not sit on the grid).
5. Apply `timetable_exception` rows for that date: `cancelled` removes, `substituted`
   and `room_change` rewrite, `extra` adds — and an `extra` may land on a holiday, which
   is how a Wandertag or a Nachschreibtermin gets in.
6. Emit occurrences that are **read-only in every calendar surface**. There is no path
   from a rendered lesson to an editable event, because there is no event.

**Stable identity.** A projected occurrence still needs a stable id, because it goes into
the ICS feed and Outlook will show ghosts if ids move. Derive it deterministically and
never randomly:

```
lesson-{lessonId}-{YYYYMMDD}@<domain>          one lesson, if lessons are emitted
schoolday-{profileId}-{YYYYMMDD}@<domain>      the collapsed school-day block
```

A `SEQUENCE` for these is derived from the timetable's `updated_at`, so an edited grid
propagates as a modification rather than a delete-plus-create.

### What goes into the ICS feed

**Not sixty lessons a week.** An Outlook calendar containing "Mathematik", "Deutsch",
"Sport" six times a day for two children is unusable, and it is precisely the sort of
noise that makes someone unsubscribe the family calendar from their work laptop.

Default: **one collapsed all-day-adjacent block per child per school day** —
`Mia: Schule 08:00–13:00`, with the day's subjects in the description, and any Entfall or
Vertretung noted there too. Per feed token, this is configurable to `off` (nothing) or
`lessons` (everything), because a grandparent's feed wants neither and a tablet in the
hallway might want all of it.

The default for a *new* token is `off` for school and presence. Sharing a child's daily
whereabouts should be a deliberate act, not a default. See
[11 — Security & Privacy](11-security-and-privacy.md).

### Views

**Stundenplan grid** — the main view, adult and kid registers both:

```
        Mo          Di          Mi          Do          Fr
 1  ┌──────────┬───────────┬───────────┬───────────┬──────────┐
08:00│ Deutsch  │ Mathe     │ Deutsch   │ Sachkunde │ Mathe    │
 2  ├──────────┼───────────┼───────────┼───────────┼──────────┤
08:50│ Mathe    │ Deutsch   │ Sport 🏃  │ Deutsch   │ Englisch │
 3  ├──────────┼───────────┼───────────┼───────────┼──────────┤
09:55│ Musik 🎵 │ Kunst 🎨  │ Sport 🏃  │ Mathe     │ ~~Deutsch~~│
 4  ├──────────┼───────────┼───────────┼───────────┼──────────┤
10:45│ Sachkunde│ Religion  │ Mathe     │ Englisch  │ Vertretung│
    ├──────────┼───────────┼───────────┼───────────┼──────────┤
    │ Hort     │ Hort      │ —         │ Hort      │ Hort     │
    └──────────┴───────────┴───────────┴───────────┴──────────┘
```

- Today's column is highlighted; the current lesson is marked, and outside school hours
  the *next* school day is marked instead. A grid that does not say "you are here" makes
  the reader do the work.
- Every subject carries a colour **and** an icon (NFR-13 — colour alone fails at two
  metres and for a colour-blind reader, and the seven-year-old reads the icon first).
- Cancellations are struck through in place rather than removed. "Die zweite Stunde
  fällt aus" is information; a blank cell is not.
- Ferien weeks render as one wide band across the grid — `Herbstferien · 12.–24.10.`
  and nothing else. Anything more is clutter.

**Detail on the kitchen display.** Tapping a child on the week board opens the same grid,
in the shape of the paper original: numbered Stunden down the left with both bell times
stacked, weekdays across the top, today's column tinted, Vertretung labelled in place,
Entfall struck through, a subject legend underneath, and one line at the bottom naming
tomorrow's school hours and what has to be packed. That last line is the reason the sheet
exists at 21:00; everything above it is the reason it exists at 07:30. See the
[mockup](mockups/kiosk-week-board.html).

**Kid register — "Mein Stundenplan":** today as a vertical list of large cards, each with
subject icon, room and time, the current one enlarged, plus a "Morgen brauchst du:"
footer when tomorrow has a subject with equipment attached (Sport → Sportsachen,
Schwimmen → Schwimmsachen). That footer is the single highest-value thing this module
does for the evening routine, which is why FR-7.12 exists even though it is only a `C`.

**Week board (kiosk):** the child's row shows the school-day span and only the lessons
flagged `is_notable` — Sport, Schwimmen, an AG, an excursion. Rendering six subjects per
day on a wall display at two metres produces a grey rectangle nobody reads.

### Maintaining it

Realistically this is done twice a year, in a hurry, on a laptop, from a sheet of paper.

- **Grid entry**, not a form per lesson: click a cell, type or pick a subject, tab to the
  next. The whole timetable should be enterable in five minutes.
- **Copy from**: previous term, or the sibling's timetable (same school, same bell times).
- **Column and row operations**: clear a day, shift a day, swap two days.
- **Exceptions are entered from the calendar or the grid** in two taps — long-press a
  lesson → "Fällt aus" / "Vertretung" / "Raum geändert".
- Guardian-only in v1 (Q23, decided; the household setting `school.members_report_changes`
  can open it later). Children read their timetable; they do not maintain it.
- **Starter content** when a school is added: a bell-time template and a German subject
  list with colours and icons ([21](21-household-settings.md#calendar-presence-and-school-m13)).

### Holidays

Ferien and bewegliche Ferientage are entered by hand in v1 and imported in M2. The import
is a public dataset (`ferien-api.de` and the Kultusministerien's own ICS files), it is
per region — a school's region defaults to the household's (`household.region`), and the
import starts with the German Bundesländer — and it must be fetched **server-side by a scheduled Edge Function**, cached, and never
requested from the app — NFR-9 is not suspended for convenience.

Bewegliche Ferientage are school-specific and are never in the public feed. They will
always be hand-entered, which is fine: it is four or five dates a year, announced in a
letter.

---

## Part 2 — presence: regular and flexible

The requirement, in the user's words (the names are the reference household's): *"Appointments
in general should be flexible, e.g. regular to maintain when Sabine is working or flexible
to show when Lukas is travelling for work."*

Two shapes of the same underlying fact — **where is this person, and are they available**
— and they need different input mechanics, not different data models.

| | Regular (a shift rota, a Dienstplan) | Flexible (a business trip, a Dienstreise) |
|---|---|---|
| Changes | Rarely; a pattern that holds for months | Constantly; every trip is its own thing |
| Entry | Once, then adjusted per occurrence | Ad hoc, often at short notice, often uncertain |
| Shape | Weekly or fortnightly rhythm, or a rota of explicit dates | One multi-day span |
| Mechanism | `RRULE`, or an explicit `RDATE` set | A plain start/end, `status='tentative'` while unconfirmed |

Both are `event` rows with `kind='presence'`. See
[ADR-009](adr/ADR-009-event-kinds-and-presence.md) for why this is one table and not two.

### The baseline, and why most days are empty

Before the states: each adult carries a **baseline** on their profile — where they
normally are — set per member, and empty until someone sets it. In the reference household
it is `home_office` for one adult and `off` (at home) for the other. It is not an event, it generates no occurrences, and it never reaches the ICS feed.

Two things follow, and both matter more than they look:

- **Only deviations are entered.** A normal week is zero input. "Mo + Mi Dienst
  8:30–14:00" is one recurring series; a Tuesday in the office is one row; a two-day
  Dienstreise is one row.
- **Only deviations are loud.** The week board draws the baseline as a muted chip and the
  deviation as a filled band. Drawing every day of everyone's normal life at full strength
  turns the zone into a solid block in which the one unusual day disappears — which is
  precisely the day someone needed to see.

### "Termine bis 17:00"

`event.busy_until` (FR-1.19) is a second, smaller fact about a day: not where somebody is,
but until when they are unavailable. It exists because the interesting question about a
home-office day is never *ob* but *ab wann* — and because a working parent's own calendar
is the one calendar this system deliberately does not own.

- Entered by hand in v1: one time, on the day, from the person's phone.
- In M3 it can be derived from that person's work calendar, subscribed privately and
  read-only. Only the end of the last meeting would cross into WuselWall — not titles, not
  attendees, not the meetings themselves. That narrow projection is the whole reason the
  field is a single `TIME` and not a nested calendar.
- It renders as a muted second line under the presence chip, and never as an appointment:
  it is a boundary, not an event.

### Presence states

`presence_state` — a small, closed set. German labels are what the household sees:

| Value | Label | Rendered as |
|---|---|---|
| `working` | Arbeitet · Dienst · Büro | Solid band in the member's colour. The free-text label carries the specificity ("Dienst", "Büro Hamburg") — the state set stays closed |
| `home_office` | Homeoffice | Band with a hatch pattern |
| `travel` | Dienstreise | Band with an arrow motif, spanning days |
| `away` | Auswärts | Band, muted |
| `off` | Frei | Band, very muted — visible but never loud |
| `childcare` | Betreuung | Band, used when one adult is covering the children |

Resist adding more. Six states already require six visually distinguishable treatments
that work at two metres; a seventh will not.

### Maintaining a rota

The `RRULE` handles the easy cases and should be offered first, in plain German rather
than as a recurrence editor: *"jede Woche Mo, Mi, Do"*, *"jede zweite Woche"*.

For a rota that no rule describes — the shift plan that arrives as a PDF each month —
`event.rdates` holds an explicit list of dates in one series (RFC 5545 `RDATE`, so it
survives the trip through the ICS feed intact). The UI for it is a **month grid where you
tap the working days**, which is the same physical gesture as marking up the paper roster,
and takes about fifteen seconds a month.

One series, many dates, one title, one colour. Changing a single day uses the same
`event_override` machinery as any other recurring event: swap Tuesday for Thursday, or
drop one day, without touching the rest.

### Flexible and uncertain

A trip that might happen is worth showing. `event.status` maps to the ICS `STATUS`
property:

- `confirmed` — normal rendering.
- `tentative` — dashed border, ~60% opacity, and the label carries a `?`
  (*"Dienstreise Berlin ?"*). Emitted as `STATUS:TENTATIVE`, which Outlook and iOS both
  render distinctly.
- `cancelled` — kept for the audit trail, hidden from every view, emitted as
  `STATUS:CANCELLED` so subscribers actually remove it.

A tentative entry that nobody confirms is worse than nothing, so the reminder job nudges
the owner the evening before a tentative entry starts (`calendar.tentative_nudge`, default
19:00): *"Fährst du morgen nach Berlin?"*
with confirm and delete as the two actions.

### What presence must never do

- **Never appear in the appointment lane.** A presence band is context, not an item on
  the agenda. If "Sabine arbeitet" (reference household) competes for space with "Zahnarzt 14:30", the board
  stops being readable.
- **Never generate a notification on its own.** The pattern is known; nobody needs a push
  saying that Thursday is a working day. The exception is the tentative-confirmation
  nudge above.
- **Never count as a conflict.** Presence overlapping an appointment is normal — it is
  what makes the appointment interesting, not a scheduling error to warn about.
- **Never leak by default.** Excluded from new feed tokens (FR-1.16).

---

## German glossary

The UI is German and English (NFR-14, [CLAUDE.md](../CLAUDE.md)), German by default; the code is English. This table is the German side. Fix the pairing
once, in the i18n catalogue, before any of these strings reaches a component:

| Code | UI (de-DE) |
|---|---|
| timetable | Stundenplan |
| period / lesson | Stunde |
| subject | Fach |
| term | Halbjahr / Schuljahr |
| cancelled lesson | Entfall |
| substitution | Vertretung |
| room change | Raumänderung |
| extra lesson | Zusatzstunde |
| school holidays | Ferien |
| in-service / closure day | Beweglicher Ferientag |
| after-school care | Hort / Betreuung |
| club, extracurricular | AG |
| presence | Anwesenheit |
| rota / shift plan | Dienstplan |
| business trip | Dienstreise |
| tentative | Vorläufig |
| key appointment | Wichtiger Termin |
| week board | Wochenübersicht |

---

## v1 scope cut

**In:** school, bell times, terms, subjects with colour and icon · one timetable per child
per term, grid entry, copy from previous term or sibling · A/B weeks · lessons, care and
clubs · per-date exceptions (Entfall, Vertretung, Raumänderung, Zusatzstunde) ·
hand-entered holidays that suppress the day · projection into calendar, agenda, kid views
and the kiosk week board · collapsed school-day block in the ICS feed, off by default ·
presence events with six states, RRULE and RDATE patterns, per-occurrence overrides,
tentative status · key-appointment flag.

**Out:** automatic import from WebUntis, IServ, Schulmanager or any school portal ·
imported Ferien feeds (M2) · homework and grades — that is a different application, and
the school already has one · marks, absence reporting, parent-teacher communication ·
equipment reminders (FR-7.12, `C` — do it in M2 if the evening routine still hurts) ·
free/busy computation across the household · anything that treats presence as capacity to
be optimised. This is a kitchen display, not a resource planner.
