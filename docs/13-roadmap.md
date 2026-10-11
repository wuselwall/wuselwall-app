# 13 — Roadmap

> **WuselWall restart, 2026-10-11.** This roadmap was carried over from BretApp, where
> M0 and M1.1 had been built on the TypeScript stack. WuselWall starts again from M0.0 on
> Flutter and self-hosted Supabase ([ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md)).
> M0 has been re-cut for the new stack and gained a release-pipeline step (M0.4); the
> step-by-step build order is [16 — Setup Plan](16-setup-plan.md). The status column
> tracks this repository only.

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
| **M0.0** Repository skeleton · local Supabase with the first migration, RLS and pgTAP harness · Flutter shell with three registers and German l10n · `ci.yml` ([16](16-setup-plan.md) steps 1–4) | In progress — Flutter shell, first migration, pgTAP test and `ci.yml` written (CI not yet run on GitHub); RLS catalogue test still open |
| **M0.1** Identity: setup wizard, guardian accounts, device enrolment, tap-to-switch, guardian PIN, revocation (step 5) | Built and tested (pgTAP + end-to-end), incl. per-phone devices, TOTP, QR enrolment, rate limiting; passkeys wired, untested until the production domain exists — see ADR-010 implementation notes |
| **M0.2** The shopping list, online only: add, tick, finish, live across devices (step 6) | Built and tested; not yet tried on the family's real devices |
| **M0.4** Mobile release pipeline: signing, `release-mobile.yml`, TestFlight and the Play internal track (step 7) | Not started — needs the Apple and Google accounts |
| **M0.3** Production stack, Caddy, backups, `deploy.yml` — built and tested on a disposable VM (step 8) | Not started — deployment held for M1.6 |

M0.4 is new and comes **before** M0.3. A PWA reached the phones by URL; a native app
reaches an iPhone only through a signed build, and without a Mac the release pipeline is
the only way to get one there. So distribution is proven during M0, while deployment of
the backend can still wait.

**Done when:** the shopping list is used on both parents' phones for one real supermarket
trip — installed from TestFlight or Play, talking to Supabase on the laptop over the home
network.

### Trialling on the home network

Supabase runs on the laptop (`supabase start`), reachable from the home wifi through
WSL's mirrored networking at a reserved address, and the family's devices run builds
configured for that address ([16](16-setup-plan.md#before-production-exists)). That is
enough to answer the adoption question, and it is what M1.1–M1.5 are built against.

Native apps remove one limit of the original plan — **installation now works on day one**,
because TestFlight and Play deliver real apps without a public server. Three things a LAN
trial still cannot show, all deferred rather than lost:

- **Push.** The `push-send` function could reach APNs and FCM from the laptop, but push
  credentials and notification preferences are M1.6 work. The morning summary (Q13)
  waits.
- **The ICS feed into Outlook.** Needs a public URL, so the calendar's whole outbound
  half stays untested until deployment.
- **Availability, and use outside the house.** The laptop has to be awake and the phone
  on the home wifi. A wall display is not worth mounting until that stops being true —
  and a shopping list that only syncs at home leans entirely on the offline outbox.

These are the reasons M1.6 is a milestone rather than an afterthought. None of them
block finding out whether the family wants the thing.

## M1 — The four modules, thin

Four blocks, each buildable in a handful of focused sessions. Order matters: shopping
first because it is already started, tasks second because it is the heaviest, calendar and
Stundenplan third, meals last because it depends on shopping's catalogue. The week board
is assembled in M1.5, once all of its sources exist.

### M1.1 Shopping, complete

**Scope (as reached in BretApp, 2026-09-12, on the old stack — the mechanisms map to
drift and Supabase Realtime as described in [07](07-module-meals-shopping.md)):** Categories and store layouts (a category belongs to a list rather
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

Domain (Q1) · Hetzner server (8 GB), provisioned and hardened · the self-hosted Supabase
stack with fresh keys · `deploy.yml` switched from manual to on-push · first deploy and
the setup wizard behind its token · TLS on the real hostname · **a production release of
the apps** (`env/prod.json`) on every family device · push credentials (Q38) and
notification preferences · the ICS feed verified against real Outlook and real iOS ·
nightly backups with the dead-man's switch · **a restore drill, with the date written
down** · the pre-launch checklist in [11](11-security-and-privacy.md) · wall display
mounted in the kitchen, the app pinned in kiosk mode.

Guardian accounts already exist from M0.1. What is still missing is account *recovery*
for a guardian who loses their phone and password — today that means Studio over an SSH
tunnel. That is acceptable while the developer is the only operator and worth revisiting
before anyone else depends on it.

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
| M0 | 3–4 weekends, plus waiting for Apple and Google | Signing and the first TestFlight build without a Mac; WSL networking for the LAN trial; writing the first RLS policies and `api` functions well enough to serve as templates. |
| M1.1 | 2 weeks | The offline outbox is the whole cost; the tile picker and several lists add a few days. |
| M1.2 | 2–3 weeks | The largest module. The materialiser and rotation logic need real tests. |
| M1.3a | 2–3 weeks | Recurrence and ICS correctness. Timezones and all-day events will each cost you a day. |
| M1.3b | 1–2 weeks | The projection function: A/B weeks × holidays × exceptions is where the edge cases live. Write the tests first, genuinely. |
| M1.4 | 1–2 weeks | Quantity aggregation and unit handling is fiddlier than it looks. |
| M1.5 | 2–3 weeks | Always underestimated, and now carries the week board. Three registers plus one screen that has to be right. |
| M1.6 | 1 weekend | TLS, DNS, the first real run of the Supabase stack on the VPS, push credentials. The release pipeline is already proven from M0.4, which removes the biggest risk of the old plan. |
| **M1 total** | **~3–4 months** | The A5 addition (Stundenplan, presence, week board) added roughly a month. Supabase saves the auth, realtime and job plumbing; PL/pgSQL and pgTAP cost some of that back. |
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
