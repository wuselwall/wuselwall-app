# ADR-008 — The Stundenplan is a pattern projected into the calendar, not a set of events

**Status:** Accepted · 2026-08-30

## Context

A requirement added on 2026-08-30 (A5, → FR-7.x): the children's school timetables must
be in WuselWall, visible in the calendar, and present on the kitchen wall display as part
of the standard view.

Two children, five days, five to six lessons a day, plus Hort and an AG. The timetable is
valid for a Halbjahr, does not apply during roughly 75 days of Ferien a year, and is
disturbed by irregular single-date events: Entfall, Vertretung, Raumänderung, Wandertag.
German primary schools publish it as a sheet of paper.

## Decision

A new bounded context, `school`, owns schools, bell times (`school_period`), terms,
subjects, timetables, lessons, per-date exceptions and holidays. A timetable is stored as
a **pattern** — weekday × period → subject — not as calendar events.

The calendar's read model composes occurrence sources. `school` contributes read-only
projected occurrences for any requested window; no `event` rows are ever written for a
lesson. In the outbound ICS feed the projection is emitted **collapsed to one school-day
block per child per day**, and is switched off by default on new feed tokens.

## Alternatives considered

**One recurring event per lesson.** `FREQ=WEEKLY` per subject per slot, `UNTIL` the end of
term. Rejected on maintenance cost: about sixty series across two children, each needing
an `EXDATE` for every holiday date — roughly 4,500 exclusions a year, and a re-edit of
sixty series every time the school announces a beweglicher Ferientag. It also gets the
editing model backwards: a timetable is entered and revised as a grid, not lesson by
lesson, and bell-time changes would have to be applied to every series individually.

**Materialise lessons into rows, like the task materialiser.** Consistent with an existing
pattern in the system, and fast to query. Rejected because, unlike a task instance, a
lesson carries no state — nothing is completed, verified or scored — so the rows would be
a pure cache that can go stale, and re-materialising after a grid edit or a newly entered
holiday is a data-migration problem where projection is a pure function.

**Import from the school's system (WebUntis, IServ, Schulmanager).** Zero manual entry and
substitutions arrive automatically. Rejected for v1 because the schools in question do not
publish a machine-readable feed, several of those systems have no stable public API, and
the requirement would then depend on a third party outside the household's control. The
schema keeps `timetable.source` so an import can be added later without a migration of
meaning.

**A photo of the paper timetable on the wall display.** Genuinely the cheapest option, and
worth naming so it is not re-proposed. Rejected because it answers nothing: it cannot feed
the week board, cannot say "Sport morgen", cannot be filtered per child, and cannot be
read from two metres.

## Consequences

**Positive**

- Holidays are subtracted once, centrally, for both children. Adding a beweglicher
  Ferientag is one row.
- Bell-time changes move every lesson at once, because lessons store a period, not a time.
- Entering a term's timetable is a five-minute grid session, and copying from the previous
  term or a sibling is trivial.
- Projection is a pure function over a window — cheap to test exhaustively, and the place
  where A/B weeks, exceptions and holidays interact is one file rather than sixty rows.
- No sixty extra `VEVENT`s per week in the ICS feed, which is what would have made a
  subscriber unsubscribe.

**Negative**

- Lessons are not editable as calendar events. A parent who taps a lesson in the week view
  gets timetable actions (Entfall, Vertretung), not the normal event editor. That
  asymmetry must be obvious in the UI or it reads as a bug.
- Projected occurrences need deterministic UIDs and a derived `SEQUENCE`, or Outlook shows
  ghosts. This is fiddly and must be tested against a real client (see
  [05](../05-module-calendar.md)).
- The calendar read path gains a composition step it did not have. That step is also what
  makes imported feeds (FR-1.9) and task due dates cheap later, so the cost is largely
  brought forward rather than added.
- Two entry surfaces exist for things that happen at school: the grid for the pattern, the
  calendar for one-off school events (Schulfest, Elternabend). The rule is simple — if it
  repeats weekly it is a lesson, otherwise it is an event — but it must be stated in the
  household documentation.

**Revisit if** a school starts publishing a substitution feed. The import path is then an
addition to `school`, not a change to this decision.
