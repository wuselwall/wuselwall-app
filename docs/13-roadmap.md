# 13 — Roadmap

> **GoombaWall restart, 2026-10-11.** This roadmap was carried over from BretApp, where
> M0 and M1.1 had been built. GoombaWall starts again from M0.0; the scope notes below
> describe what each milestone means, and the status column tracks this repository only.

## A note on the "all four modules at once" decision

You chose to build all four modules in the first release rather than starting with one.
That is workable, and it has a real advantage: a family organiser with only a shopping
list is not a family organiser, and the household will not change its habits for a
partial system. Adoption is genuinely easier with a complete-feeling first release.

The risk is equally real and worth naming. Four modules at once means the first useful
thing arrives months rather than weeks after you start, motivation has to survive a long
stretch with nothing to show, and the natural failure mode — building each module to the
depth it deserves rather than the depth v1 needs — turns a three-month project into an
abandoned one.

The plan below manages that in two ways. **Milestone 0** puts one thin vertical slice —
the shopping list, on real devices — in front of the family early, so the adoption
question is answered before months of domain complexity land on top. And each module in
Milestone 1 has an explicit cut line — the "out" lists in documents [05](05-module-calendar.md) through
[07](07-module-meals-shopping.md) are not suggestions. Ship narrow, then deepen against
observed use rather than imagined use.

---

## M0 — Walking skeleton

*Goal: something real the family can use for one trivial thing.*

**Reordered on 2026-09-02.** The original plan ended M0 on the real domain over real
TLS, on the argument that everything genuinely hard about operating this system is in
M0 and easier to debug with nothing else to blame. That argument still holds, but the
deployment work (M0.3) is held back until the app is worth
deploying.

The reason is not cost (€7–9/month is not the risk here). It is that the open question
is no longer *"can this be operated?"* but *"will four people actually use it?"* — and
that question is answerable on the home network, without a domain, a VPS or a
certificate. Standing up production infrastructure for a system the household has not
yet tried is building the wrong thing carefully.

| | Status |
|---|---|
| **M0.0** Monorepo, TypeScript strict, Drizzle, first migration, PWA-ready shell, i18n | Not started |
| **M0.1a** Household and profiles seeded; a development actor stand-in | Not started (BretApp: superseded by M0.1b) |
| **M0.2** The shopping list, online only: add, tick, finish | Not started |
| **M0.1b** Device enrolment, tap-to-switch, guardian PIN, row-level security | Not started |
| **M0.3** Docker image, production compose, Caddy, CI, backups, CSP, setup gate | Not started — deployment held for M1.6 |

**Done when:** the shopping list is used on both parents' phones for one real supermarket
trip — over the home network, against the laptop.

### Trialling on the home network

The dev server already binds to `0.0.0.0`, so a phone on the same wifi reaches it at
`http://<laptop-ip>:5173` and enrols like any other device. That is enough to answer the
adoption question, and it is what M1.1–M1.5 are now built against.

Four things a LAN trial cannot show, all deferred rather than lost:

- **iOS home-screen install.** A PWA needs a secure origin, so the app runs in a Safari
  tab rather than as an installed app. Installability is proven at M1.6, not before.
- **Web push.** Same constraint. The morning summary (Q13) cannot be trialled.
- **The ICS feed into Outlook.** Needs a public URL, so the calendar's whole outbound
  half stays untested until deployment.
- **Availability.** The laptop has to be awake and on the network. A wall display is not
  worth mounting until that stops being true.

These are the reasons M1.6 is a milestone rather than an afterthought. None of them
block finding out whether the family wants the thing.

## M1 — The four modules, thin

Four blocks, each buildable in a handful of focused sessions. Order matters: shopping
first because it is already started, tasks second because it is the heaviest, calendar and
Stundenplan third, meals last because it depends on shopping's catalogue. The week board
is assembled in M1.5, once all of its sources exist.

### M1.1 Shopping, complete

**Scope (as reached in BretApp, 2026-09-12):** Categories and store layouts (a category belongs to a list rather
than a separate `store` entity — v1's three lists already map onto real venues, so the
category *is* the layout) · catalogue with a self-hosted icon set, populated lazily on
purchase rather than on capture · **the tile picker** with folded, ranked typeahead and
"tap again for 2×" · **several lists with a default**, each with its own catalogue ·
the offline outbox (IndexedDB mirror, idempotent replay against the existing form
actions, a caught-in-testing fix for a request that hangs rather than rejects when
connectivity drops mid-flight) · SSE live updates, proven with two real enrolled devices
syncing with neither told to reload.

**One deliberate simplification:** the spec's long-press-for-quantity became a plain
tap-to-edit field — a real long-press gesture's pointer-timing and scroll-cancellation
logic wasn't judged worth the fragility yet. Revisit if it is missed in practice.

**Archive and history, added 2026-09-13:** `/verlauf`, grouped by trip — every item
`finishShopping` stamped with the same `boughtAt` in one "Einkauf beenden" is one trip,
so there is no separate trip entity to keep in sync. Reachable per list from the main
screen and from its own list switcher.

### M1.2 Tasks and gamification
Definitions with RRULE · the materialiser job · four assignment policies · the point
ledger · rewards with the approval flow · streaks with jokers · three or four badges ·
kid task screen · the family task board (reached from the week board's footer in M1.5) ·
guardian PIN and approvals

### M1.3 Calendar, presence and Stundenplan
*Grew on 2026-08-30 with the A5 addition; the largest single block after tasks.*

**M1.3a — Calendar core.** Events, all-day and timed · attendees · recurrence with
overrides · `rdates` and the tap-the-days rota editor · presence kind with its six states ·
tentative status · the key-appointment flag · day/3-day/week views · the signed ICS feed
with per-token filtering by member, calendar and kind · verified against real Outlook and
real iOS.

**M1.3b — Stundenplan.** School, bell times, terms, subjects · the timetable grid editor ·
A/B weeks · care and club rows · per-date exceptions · hand-entered holidays · the
projection function and its test suite · the Stundenplan grid view in the adult and kid
registers · the collapsed school-day block in the feed, off by default.

Build 1.3a fully before starting 1.3b: the projection has nowhere to render until the
calendar's occurrence-source seam exists.

### M1.4 Meals
Meal plan week grid · recipes with ingredients · who is eating at home, with the defaulting
rule from presence and Hort · generation into the shopping list, with the mandatory
preview · the meal zone of the week board

### M1.5 Polish
**The week board** — the composed `/api/board/week` read model, the four zones, today
emphasis, degradation rules, tap-through detail, night variant · three UI registers
finished · seed data including one real term's timetable for each child

Everything here is verifiable on the home network. What is not — push, installability,
the feed, the mounted display — moved to M1.6.

The week board comes last on purpose: it is a composition of all four modules plus the
Stundenplan, and building it before its sources exist means building it twice. It is also
the screen the household judges the whole system by, so it should be built when there is
real data to put on it — and the
[mockup](mockups/kiosk-week-board.html) agreed with the family beforehand is what keeps
that session short.

### M1.6 Deployment and launch

*The M0.3 artefacts, finally used. Held until here on purpose.*

Domain (Q1) · Hetzner CX22, provisioned and hardened · GitHub repository, CI and GHCR ·
first deploy and the setup wizard behind its token · TLS on the real hostname · **iOS
home-screen install proven on both parents' phones** · web push and notification
preferences · the ICS feed verified against real Outlook and real iOS · nightly backups
with the dead-man's switch · **a restore drill, with the date written down** · the
pre-launch checklist in [11](11-security-and-privacy.md) · wall display mounted in the
kitchen.

Guardian accounts (Better Auth: passkey and email/password) belong here too, or are
consciously deferred again. Device tokens protect the running app, so what is missing is
account *recovery* — today that means SSH and `pnpm db:enrol`. That is acceptable while
the developer is the only operator and worth revisiting before anyone else depends on it.

**Done when:** all four members use it daily for two weeks without asking you to fix
anything.

---

## M2 — Assistants and the obvious gaps

- Shortcuts endpoints and per-person tokens
- MCP server, `family:read` scope
- Imported external calendars (sports club, bin collection)
- Ferien import for the Bundesland, so holidays stop being hand-entered
- Equipment reminders from tomorrow's subjects ("Morgen brauchst du: Sportsachen")
- Meal suggestions from history ("not cooked in 60 days")
- Whatever the first two weeks of real use made obviously necessary — reserve capacity
  for this rather than planning around it

## M3 — Depth

- Substitution import from a school portal, *if* either school ever publishes one
- MCP write scopes with consent and grant management
- Recipe import from URL
- Family goal bar and ageing bonuses on open tasks
- CalDAV for two-way phone editing, if read-only proves limiting
- Richer badges and a wider reward catalogue

## M4 — Speculative

Photo proof of chores · allowance payouts · household inventory and pantry stock ·
budget tracking · natural-language event entry · a native iOS wrapper, if and only if a
specific capability demands it

---

## Effort

Rough, for a solo developer working evenings and weekends with AI assistance. Treat as
order-of-magnitude, not commitment.

| Milestone | Calendar time | Where it goes wrong |
|---|---|---|
| M0 | 1–2 weekends | TLS, DNS, iOS PWA installability. Budget an evening for surprises. |
| M1.1 | 2 weeks | The offline outbox is the whole cost; the tile picker and several lists add a few days. |
| M1.2 | 2–3 weeks | The largest module. The materialiser and rotation logic need real tests. |
| M1.3a | 2–3 weeks | Recurrence and ICS correctness. Timezones and all-day events will each cost you a day. |
| M1.3b | 1–2 weeks | The projection function: A/B weeks × holidays × exceptions is where the edge cases live. Write the tests first, genuinely. |
| M1.4 | 1–2 weeks | Quantity aggregation and unit handling is fiddlier than it looks. |
| M1.5 | 2–3 weeks | Always underestimated, and now carries the week board. Three registers plus one screen that has to be right. |
| M1.6 | 1 weekend | TLS, DNS, iOS installability — the M0 risks, deferred rather than removed, and now landing on top of four modules instead of one thin slice. Budget an evening for surprises, and expect the first `docker compose up` to be a debugging session: the images have never been built. |
| **M1 total** | **~3–4 months** | The A5 addition (Stundenplan, presence, week board) added roughly a month. |
| M2 | 2–3 weeks | |

## Milestone discipline

Two rules that decide whether this ships.

**A module is done when its "in" list is done.** Every idea that arrives mid-build goes
into [14 — Open Questions](14-open-questions.md) or the M3 list. Not into the current
module.

**Deploy at the end of every block.** M1.2 goes to production before M1.3 starts, even
though the calendar is still missing. Long-lived unreleased work is where solo projects
go to die, and a family that watches the app grow every fortnight is a family that will
adopt it.
