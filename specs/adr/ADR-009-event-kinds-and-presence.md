# ADR-009 — Presence is an event kind, and the week board is driven by an explicit flag

**Status:** Accepted · 2026-08-30

## Context

Added with A5 on 2026-08-30: *"Appointments in general should be flexible, e.g. regular to
maintain when Sarah is working or flexible to show when David is travelling for work."*

Two adults with very different scheduling shapes. One has a rota that repeats but is
revised monthly and does not always fit a recurrence rule. The other has irregular,
multi-day, frequently uncertain travel. Neither is an appointment in the ordinary sense:
"Julia arbeitet" is not something anyone attends, and it must not compete with "Zahnarzt
14:30" for attention on a wall display.

At the same time the wall display now shows a whole week (FR-8.1). A week of unfiltered
events on one screen is unreadable, so something has to decide what earns a place.

## Decision

**One table, two kinds.** `event.kind` is `appointment | presence`. Presence rows carry a
`presence_state` (`working`, `home_office`, `travel`, `away`, `off`, `childcare`) and are
rendered as day bands, never as timeline blocks, never in the appointment lane, and never
as a source of notifications or conflict warnings.

**Two entry mechanics, one storage model.** Regular patterns use `RRULE`; irregular rotas
use `RDATE` (`event.rdates`) edited through a tap-the-days month grid. Both are a single
series, so a one-off change is an ordinary `event_override`.

**Uncertainty is first-class.** `event.status` is `confirmed | tentative | cancelled`,
mapping directly to the ICS `STATUS` property.

**What appears on the week board is an explicit flag**, not a heuristic:
`event.importance = 'key'` ("Auf dem Küchendisplay zeigen"), defaulted on for events with
no individual attendee (whole-family events) and off otherwise.

## Alternatives considered

**A separate `availability` module and table.** Cleaner conceptually. Rejected because it
would duplicate recurrence expansion, overrides, attendees, the ICS emitter and the audit
integration — the four hardest parts of the calendar — for a row that differs from an
event only in how it is drawn. A single nullable enum buys the same separation at the
render layer.

**Free/busy computation and conflict detection.** Tempting once presence exists: the system
could warn that an appointment falls on a working day. Rejected as the wrong register for
a household. It would fire constantly (every appointment overlaps somebody's working day),
and a kitchen display that nags is one that gets ignored. Presence is context; the humans
do the reasoning.

**Deriving week-board prominence heuristically** — all-day events, or events with more than
one attendee, or events outside working hours. Rejected: every heuristic has a case where
the important thing is missing from the wall, and a display that is *sometimes* complete
cannot be trusted. An explicit toggle with a sensible default is predictable, and
predictability is the whole value of the display.

**A dedicated `is_travelling` field on the profile.** Rejected: it has no start, no end, no
history and no recurrence — it answers "now" and nothing else, and the question people
actually ask is about next Thursday.

## Consequences

**Positive**

- Recurrence, overrides, audit, ICS emission and the permission model are written once and
  serve both kinds.
- "Julia arbeitet Mo/Mi/Do" is maintained in seconds and stays correct for months; a
  swapped shift is one override, not a re-entry.
- The rota grid (`RDATE`) mirrors the physical gesture of marking up a paper roster, which
  is the difference between a system that gets maintained and one that does not.
- `STATUS:TENTATIVE` travels through the ICS feed, so an unconfirmed trip looks
  unconfirmed in Outlook too.
- The week board's content is explainable in one sentence to a family member: *what is
  flagged for the display is what shows on it.*

**Negative**

- `event` gains four nullable-ish columns that are meaningless for the other kind. Enforced
  by check constraints (invariant 15 in [04](../04-data-model.md)) rather than by types.
- Every read path must filter by kind, and forgetting to do so puts "Julia arbeitet" in
  the agenda list. Centralise it in the query helpers, not in the components.
- The `importance` flag can be forgotten, and then something genuinely important is missing
  from the kitchen. Mitigation: the event editor shows the flag prominently with the
  whole-family default, and the week board offers a "alle Termine zeigen" tap for the case
  where somebody says "but I put it in".
- Six presence states need six treatments that survive being read at two metres. That is a
  real design constraint on the kiosk palette, and it caps the set — a seventh state should
  be refused.

**Revisit if** the household starts wanting genuine availability queries ("when are we all
free?"). That is a different feature built on the same rows, and it would need working
hours modelled rather than merely displayed.
