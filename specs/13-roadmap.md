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
is no longer *"can this be operated?"* but *"will the family actually use it?"* — and
that question is answerable on the home network, without a domain, a VPS or a
certificate. Standing up production infrastructure for a system the household has not
yet tried is building the wrong thing carefully.

*Superseded 2026-10-11 by [ADR-013](adr/ADR-013-one-self-hosted-environment.md): the home
server already had a public URL, so M0.3 shrank to securing that one environment and was
built straight away.*

| | Status |
|---|---|
| **M0.0** Repository skeleton · local Supabase with the first migration, RLS and pgTAP harness · Flutter shell with three registers and German l10n · `ci.yml` ([16](16-setup-plan.md) steps 1–4) | Built — CI green on `main` since PR #3; the RLS catalogue test (`040_catalogue`) exists |
| **M0.1** Identity: setup wizard, guardian accounts, device enrolment, tap-to-switch, guardian PIN, revocation (step 5) | Built and tested (pgTAP + end-to-end), incl. per-phone devices, TOTP, QR enrolment, rate limiting; passkeys wired, untested until the production domain exists — see ADR-010 implementation notes |
| **M0.2** The shopping list, online only: add, tick, finish, live across devices (step 6) | Built and tested; not yet tried on the family's real devices |
| **M0.4** Mobile release pipeline: signing, `release-mobile.yml`, TestFlight and the Play internal track (step 7) | In progress — Apple account active, iOS signing and `release-mobile.yml` (iOS job) written 2026-10-12; **first TestFlight build uploaded 2026-10-12** (it still calls `wusel.example.org`, which forwards — ADR-017); Android: a signed APK by hand (`build-android.yml`, `scripts/deploy-apk.sh`) until the Play account exists |
| **M0.3** The one environment ([ADR-013](adr/ADR-013-one-self-hosted-environment.md)): own keys, `wusel.example.org` (since 2026-10-13 `wuselwall.app`, ADR-017) through Cloudflare and nginx, nightly backups, restore drill (step 8) | Built 2026-10-11; **moved the same day to the official compose stack** ([ADR-013 amendment](adr/ADR-013-one-self-hosted-environment.md#amendment-2026-10-11-the-official-compose-stack)). The household starts fresh on it: the development data stayed behind in the stopped CLI stack |

M0.4 is new and comes **before** M0.3. A PWA reached the phones by URL; a native app
reaches an iPhone only through a signed build, and without a Mac the release pipeline is
the only way to get one there. So distribution is proven during M0, while deployment of
the backend can still wait.

**Done when:** the shopping list is used on both parents' phones for one real supermarket
trip — installed from TestFlight or Play, talking to the home server at
`https://api.wuselwall.app`.

### One environment from the start

*Rewritten 2026-10-11 for [ADR-013](adr/ADR-013-one-self-hosted-environment.md).* The plan
used to trial on the home network against a laptop stack and stand up production at
M1.6. Now the stack runs on the home server and is public (since 2026-10-13 at `https://api.wuselwall.app`,
[ADR-017](adr/ADR-017-wuselwall-app-domain.md)) from day one, so the trial and the real thing are the same environment. What the LAN
trial could not show is no longer blocked by infrastructure:

- **Use outside the house** works as soon as the apps are installed.
- **The ICS feed into Outlook** can be tested as soon as the feed exists (M1.3a).
- **Push** needs only its credentials (Q38) and the `push-send` function.

The price is that development and the family share one database; see ADR-013 for the
safeguards (a dump before every migration, no `db reset`, the integration test kept on
throwaway stacks).

## M1 — The four modules, thin

Four blocks, each buildable in a handful of focused sessions. Order matters: shopping
first because it is already started, tasks second because it is the heaviest, calendar and
Stundenplan third, meals last because it depends on shopping's catalogue. The week board
is assembled in M1.5, once all of its sources exist.

### M1.0 Onboarding

*Added 2026-10-11 ([ADR-014](adr/ADR-014-self-service-onboarding.md),
[20](20-onboarding.md), [16 step 9](16-setup-plan.md#step-9--onboarding-m10)).* Can be built
alongside M1.1–M1.4 and must be finished **before M1.6**, because the family's real
household is set up through it.

The front door (Apple, Google, email code, password) · household creation in `code` mode
with H1/H2 and seeded examples · invitations by link, code, QR and email match ·
reverse pairing for shared devices, with the PIN deferred to the first one · the
getting-started card · account and household deletion, leave, data export · localised
auth mail · the landing pages and `/.well-known` files · M0.1's setup wizard and code
entry retired one release later.

**Done when** the second parent joins from a WhatsApp message in under a minute, the wall
tablet is connected without anyone touching its keyboard, and both are timed on the
release checklist.

> **Built 2026-10-14 on `feature/regions-and-ux`, not yet on the server:** the getting-started card on the adult Today tab (FR-5.17) — six items derived from data (invite partner, connect tablet, wall display, set PIN, subscribe feed, and Stundenplan eintragen), dismissible ("Brauchen wir nicht"), brought back from Einstellungen → Erste Schritte. The data export for guardians on a personal device (FR-5.16, the export part): one JSON file, secrets left out. **Open:** account and household deletion, leave, and the rest of 9.1/9.2.

> **Built 2026-10-15 on `feature/regions-and-ux`, not yet on the server:** households (H1/H2, founder codes), invitations (without universal links and the "joined" notice), pairing (the code enrolment stays one release), email code sign-in (E1–E3), leaving, deleting and restoring a family, account deletion, the second-factor reset, the localised mail and the local reminders. **Open for M1.0:** universal links and App Links, the guardian notice, step 7a (on `feature/self-hosting-kit`), and the end-to-end and device checks of the release checklist.

### M1.1 Shopping, complete

> **Offline outbox built 2026-10-12:** drift mirror and outbox, `api.shopping_apply` with
> per-op idempotency keys, aliases for merged adds and per-op rejection; pending state shown
> on each item and in a banner ([07](07-module-meals-shopping.md#offline--the-one-place-it-is-non-negotiable)).
>
> **Built 2026-10-11 (online):** several lists with a default, categories per list as the
> store layout, the catalogue learned on purchase, the tile picker with folded ranked
> typeahead and tap-again counts, long-press notes and category correction, the trolley
> section, trips and the history page. **Still open:** the self-hosted icon set beyond category
> icons, and the kiosk tile layout polish.

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
> **Built 2026-10-13 on `feature/week-board`, not yet on the server:** household settings with the Einstellungen screen; definitions with RRULE, the four policies, the materialiser (`tasks-materialise`, `tasks-nightly`), the ledger, rewards with approval, streaks with jokers, four badges, the starter pack, the adult screens and the kiosk family task board; the kid screens. **Open:** scheduling `tasks-nightly` (pg_cron/pg_net or host cron).
> pgTAP green on a local throwaway Postgres (`scripts/local-pgtap`); not yet run on the
> compose stack or with real devices.

**Household settings first** ([21](21-household-settings.md)): `setting_definition`, the
override table, `api.settings` / `api.set_setting`, and the Einstellungen screen — M1.2 is
the first module whose behaviour is tuned per household. Its defaults (Q4–Q7, issues
#6–#9) are data, so the build does not wait for them ·
Definitions with RRULE · the materialiser job · four assignment policies · the point
ledger · rewards with the approval flow · streaks with jokers · three or four badges ·
kid task screen · the family task board (reached from the week board's footer in M1.5) ·
guardian PIN and approvals

### M1.3 Calendar, presence and Stundenplan
> **Built 2026-10-13 on `feature/week-board`, not yet on the server:** M1.3a — events, attendees, presence with six states, recurrence with overrides and `rdates` (the Dienstplan grid), tentative, the key flag, busy-until, day/3-day/week views and the editor, the signed ICS feed with per-token filters (school day or lessons included). M1.3b — schools, bell times, terms, subjects, A/B weeks, care rows, exceptions, holidays, the projection (`_shared/school.ts`) and the grid editor. **Open:** the feed verified against real Outlook and real iOS.
> pgTAP green on a local throwaway Postgres (`scripts/local-pgtap`); not yet run on the
> compose stack or with real devices.

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

> **Built 2026-10-14 on `feature/regions-and-ux`, not yet on the server:** regions to any depth (Germany, Austria, Switzerland to the Gemeinde, Liechtenstein) from the public OpenHolidays dataset, fetched by the server; public holidays (Feiertage) automatic, for school days, the week board's day header and the free-day meal; school holidays (Ferien) imported with a preview and editable afterwards (the M2 item, built early); several schools per household; day operations in the timetable editor (clear, copy, swap, with undo until Save). Details: [15](15-module-school-timetable.md#holidays).

### M1.4 Meals
> **Built 2026-10-13 on `feature/week-board`, not yet on the server:** the week plan (free text or recipe, cook, guests), recipes, who-is-eating with the defaulting rule (computed with the board in `board-week`), shopping generation with the mandatory preview, the kiosk correction dots.
> pgTAP green on a local throwaway Postgres (`scripts/local-pgtap`); not yet run on the
> compose stack or with real devices.

Meal plan week grid · recipes with ingredients · who is eating at home, with the defaulting
rule from presence and Hort · generation into the shopping list, with the mandatory
preview · the meal zone of the week board

> **Built 2026-10-14 on `feature/regions-and-ux`, not yet on the server:** meal suggestions in the meal editor from the last 365 days of cooked meals ("Oft bei uns", "Lange nicht gegessen" after 90 and 60 days — FR-3.8), the meal behind each generated shopping item (FR-3.7), and undo when a planned meal is cleared.

### M1.5 Polish
> **Week board built early, 2026-10-13:** the board, its tap-through details and the
> `api.board_week` read model exist before their sources. The read model's JSON is the
> contract (`app/lib/features/board/domain/week_board.dart`): each module fills its own
> part — presence and events (M1.3a, through the `board-week` Edge Function), school days
> (M1.3b), meals (M1.4), open tasks (M1.2) — so the board is built once, not twice. Until
> then its zones are present and empty, as the degradation rules require.

**The week board** — the composed `/api/board/week` read model, the four zones, today
emphasis, degradation rules, tap-through detail, night variant · three UI registers
finished · seed data including one real term's timetable for each child

Everything here is verifiable on the home network. What is not — push, installability,
the feed, the mounted display — moved to M1.6 (since ADR-013 only the mounted display
and push still wait for it).

The week board comes last on purpose: it is a composition of all four modules plus the
Stundenplan, and building it before its sources exist means building it twice. It is also
the screen the household judges the whole system by, so it should be built when there is
real data to put on it — and the
[mockup](mockups/kiosk-week-board.html) agreed with the family beforehand is what keeps
that session short.

### M1.6 Launch

*Re-scoped 2026-10-11 by [ADR-013](adr/ADR-013-one-self-hosted-environment.md): there is
no separate deployment any more, so this is the launch checklist on the one environment.*

The family's real household set up through the M1.0 flow with a founder code
(`scripts/remote-setup-token.sh`), the second parent joined by invitation and the devices
paired · the development data cleared before that, once · push credentials (Q38) and
notification preferences · the ICS feed verified against real Outlook and real iOS ·
nightly backups with the dead-man's switch and an off-site copy (Q14) · **a restore drill
on the real data, with the date written down** · the pre-launch checklist in
[11](11-security-and-privacy.md) · wall display mounted in the kitchen, the app pinned in
kiosk mode.

Account *recovery*, the gap this paragraph used to record, is closed by M1.0: an email
code replaces a forgotten password, and a co-guardian resets a lost second factor. Studio
remains the last resort only for an adult who has lost both their mailbox and every
linked provider.

**Done when:** every member of the household uses it daily for two weeks without asking you to fix
anything.

---

## Opening to other households

*Added 2026-10-11 ([ADR-014](adr/ADR-014-self-service-onboarding.md)).* Not a milestone
with features but a **gate**: the instance stays in `code` mode, and strangers cannot
start a household, until every line below is true. It sits after M1.6 on purpose. The
family uses the flows for weeks first, and their hesitations are fixed before anyone else
meets them.

- ~~WuselWall Cloud live~~ — dropped 2026-10-13 ([ADR-018](adr/ADR-018-self-hosted-only.md)):
  no instance of ours opens; the family's server stays in `code` mode for good.
- **The self-hosting kit** ([ADR-018](adr/ADR-018-self-hosted-only.md),
  [10](10-deployment-and-ops.md#other-families-servers)): tagged server releases with
  install, migrate and update scripts and the server's QR code; `/.well-known/wuselwall.json`
  with `api_version`; the app's server choice (S0), demo mode and the `api_version`
  window, tested against the previous server release in CI; a self-hosting guide in
  `docs/` for a parent with a NAS (email-only sign-in, SMTP, one's own Apple/Google
  clients).
- **The domain** — decided 2026-10-13: `wuselwall.app`
  ([ADR-017](adr/ADR-017-wuselwall-app-domain.md), [Q45](14-open-questions.md)). Still to do:
  retiring the `wusel.example.org` bridge.
- **Email** ([Q41](14-open-questions.md)): the sending domain verified, and the
  deliverability check in [10](10-deployment-and-ops.md#email-setup) passed.
- **Store listings** ([Q42](14-open-questions.md), decided: App Store and Google Play):
  store privacy labels and the Data safety form filled in honestly (Google's iOS sign-in
  library included), and App Review pointed at the demo mode.
- **Legal:** the privacy policy for the website, the apps and the sign-in providers
  (published 2026-10-13, operator details still to fill in), and a contact address. The
  record of processing and processor agreements cover the family's server only; each
  operator is the controller for their own ([11](11-security-and-privacy.md#privacy-and-legal)).
- **Abuse controls** live: Auth and Cloudflare rate limits, the 30-day clean-up of empty
  accounts, the attempt logs ([11, T11](11-security-and-privacy.md#t11--the-open-front-door)).
- **Deletion and export** tested on a real household, including Apple token revocation.
- **The cross-household pgTAP suite** reviewed once more with "a stranger is on the other
  side" in mind.
- Then: the store listings go public. `household_creation` stays `code` on the family's
  server. Other operators choose their own mode.

## M2 — Assistants and the obvious gaps

- Shortcuts endpoints and per-person tokens
- MCP server, `family:read` scope
- Imported external calendars (sports club, bin collection)
- ~~Ferien import for the Bundesland, so holidays stop being hand-entered~~ — built early on `feature/regions-and-ux` (2026-10-14), see M1.3
- ~~Imported external calendars (sports club, bin collection)~~ — FR-1.9 built early on `feature/regions-and-ux` (2026-10-14), see [05](05-module-calendar.md#external-calendars-subscribed-ics-fr-19). Open: the imported occurrences in the outbound ICS feed
- Equipment reminders from tomorrow's subjects ("Morgen brauchst du: Sportsachen")
- ~~Meal suggestions from history ("not cooked in 60 days")~~ — built early on `feature/regions-and-ux` (2026-10-14), see M1.4

- ~~Local reminders, the Q47 lean: morning summary and event reminders on personal phones, no relay~~ — built on `feature/regions-and-ux` (2026-10-15), see M1.0 and [09](09-clients-and-ux.md)
- ~~QR scanner without ML Kit (Q49)~~ — `camera` and `zxing2` (2026-10-14), see [14](14-open-questions.md)
- ~~"Alle Termine" on the week board (FR-8.11)~~ — built on `feature/regions-and-ux` (2026-10-15), see [09](09-clients-and-ux.md#the-wall-display)
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
| M1.6 | 1–2 evenings | Push credentials, the real household, the restore drill on real data. TLS, DNS and the stack already exist (ADR-013), and the release pipeline is proven from M0.4. |
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
