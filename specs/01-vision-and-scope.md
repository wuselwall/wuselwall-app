# 01 — Vision & Scope

## The problem

A family household runs on information that currently lives in four incompatible
places: appointments in individual calendars, chores in someone's head, meals decided
at 17:30 in front of an open fridge, and shopping needs remembered until the moment
the supermarket doors close behind you. Nobody has the whole picture, and the
adults carry the coordination load asymmetrically.

## The vision

> One screen in the kitchen and one app on every device that answers, without anyone
> having to ask: *What does this week look like, who is where, what are we eating —
> and who is eating with us — and what do we need to buy?*

Three properties make or break this:

- **Capture must be effortless.** If adding "kitchen roll" takes more than three
  seconds while standing at the cupboard, the list will not be trusted, and an
  untrusted list is worse than no list.
- **The wall display must be glanceable.** The kitchen screen is read from two metres
  away while carrying a saucepan. It is a display first and an input device second.
- **The week must be visible without asking for it.** Several school timetables, a shift
  rota and a parent who travels do not fit in anyone's head, and the questions they
  generate — *hat sie morgen Sport? arbeitest du Donnerstag? wer isst mit?* — are asked
  daily. A screen that answers them before they are asked is the difference between an
  app the family uses and one they remember to open.

## Users

A household has one or more guardians and any number of children. The design case is the
**reference household** — two adults, children of 9 and 7 — whose members appear by name
in the examples, the mockups and the demo data
([21](21-household-settings.md#the-reference-household)). Everything that differs between
households is a setting with a curated default, not an assumption.

| Persona | Devices | What they need |
|---|---|---|
| **Guardian** — an adult (Lukas, Sabine) | Phone (primary), work laptop (browser + Outlook), wall display | Full control. Plan the week, set up recurring chores, approve rewards. See family appointments inside Outlook on the work laptop without installing anything. Two working rhythms are designed for: **travel at short notice**, which must be enterable in seconds and visible to everyone else, and **a pattern that repeats but is revised** (a shift rota), which needs maintaining once rather than entering weekly. |
| **Older child** (Lotta, 9) | Tablet, wall display | See own tasks, own Stundenplan and today's plan, tick things off, watch points grow, redeem rewards. Can read fluently, understands a points economy. |
| **Younger child** (Hanna, 7) | Tablet, wall display | Same, but icon-led. Reads slowly — the subject icon on the timetable does more work than its name. Needs immediate, unambiguous feedback and no way to break anything. Frustration tolerance is the design constraint. |
| **Assistant** (Siri today, an AI agent later) | — | Read the agenda, add shopping items, mark tasks done, on behalf of a named person. |
| **Another family** *(added 2026-10-11, [ADR-014](adr/ADR-014-self-service-onboarding.md))* | Whatever they own | Install the app, start their household in under two minutes without talking to anyone, get the other parent in with one message, set up the kitchen tablet without typing on it ([20](20-onboarding.md)). They have never heard of the operator and owe them nothing. |

## In scope for v1

Five modules, each deliberately thin (see [13 — Roadmap](13-roadmap.md) for the exact
cut lines):

- **A1 Family calendar** with an outbound ICS feed that Outlook and iOS can subscribe to
- **A2 Task management** — recurring household chores and one-off tasks, with points,
  redeemable rewards, streaks and badges
- **A3 Meal plan** — what is being eaten, when, by whom, who cooks
- **A4 Shopping list** — capture anywhere, work through it in the shop, offline-capable
- **A5 Stundenplan & presence** *(added 2026-08-30)* — the children's school timetables as
  a maintainable pattern, and "who is working, away or travelling" as flexible calendar
  entries; both feeding the kitchen display's seven-day week board

Plus the cross-cutting essentials: per-person identity, four device classes, a secure
self-hosted deployment, an MCP endpoint for assistants, and *(since 2026-10-11)*
**self-service onboarding**: adults sign up with Apple, Google or email, create or join a
household, and connect shared devices from their phone ([20](20-onboarding.md)).

## Explicitly out of scope

Naming these now prevents them being argued about later.

| Not building | Why |
|---|---|
| ~~Multi-tenancy / other families~~ | **Reversed 2026-10-11 by [ADR-014](adr/ADR-014-self-service-onboarding.md):** other families can create their own household. It costs less than this row once feared, because every row already carries `household_id` and RLS already scopes every query by it. What differs between households is configuration — settings with curated defaults ([21](21-household-settings.md)), never code. What remains out of scope is anything *between* households: sharing, federation, one person in two households ([Q43](14-open-questions.md)). |
| Commercialisation, billing | Personal project, stated non-goal. Self-service does not change it: no plans, no payments, no ads. The only public web presence is the landing pages, the privacy policy and the deletion page ([20](20-onboarding.md#universal-links-and-the-landing-pages)). |
| A public App Store or Play Store listing | The apps are native since 2026-10-11 ([ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md)) and distributed internally through TestFlight and the Play internal track ([ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md)). *Since ADR-014 this holds only until the opening gate.* **Reversed 2026-10-11 by [ADR-015](adr/ADR-015-saas-and-self-hosted-flavours.md): public App Store and Google Play listings** once the developer accounts exist. |
| Budgeting / expense tracking | Different problem, different data model. Possible Phase 4. |
| Photo sharing, family chat, document storage | Solved better elsewhere. Do not become a second Nextcloud. |
| Two-way calendar sync with Outlook or Google | Technically possible, disproportionately expensive, and the failure modes (duplicate and ghost events) are miserable. See [ADR-001](adr/ADR-001-calendar-backbone.md). |
| Fine-grained privacy between family members | Everyone in the household sees everything except a small set of guardian-only settings. Adding per-item ACLs would double the complexity of every read path for a benefit a family household does not need. |
| Offline support outside the shopping list | See [ADR-006](adr/ADR-006-offline-strategy.md). |

## What success looks like

Concrete enough to check honestly three months after launch:

1. The shopping list is the only shopping list anyone in the household uses. No paper,
   no notes app, no WhatsApp messages to self.
2. The wall display is switched on and looked at daily without being asked, and the
   questions *"hat sie morgen Sport?"*, *"wann bist du wieder da?"* and *"wer isst mit?"*
   get answered by pointing at it instead of by asking someone.
3. Both children voluntarily open the app to check their tasks at least a few times a
   week — because of the points, not because they were told to.
4. The family calendar appears in Outlook on the work laptop and is accurate enough to
   be used for scheduling work meetings around family commitments.
5. Total running cost stays within NFR-7 — originally under €10/month, under revision
   since the move to native apps ([Q36](14-open-questions.md)).
6. No unplanned data loss, ever. A restore has been tested at least once.

## Principles

These are the tie-breakers when a design question has no obvious answer.

1. **Boring where it does not matter, careful where it does.** Use dull, well-known
   technology for infrastructure so the interesting effort goes into the domain.
2. **The server is the truth.** Clients are caches with opinions. One exception, and it
   is a documented one ([ADR-006](adr/ADR-006-offline-strategy.md)).
3. **Never punish a child in software.** No negative points, no public failure, no
   red screens for a seven-year-old. Missing a chore is a parenting conversation, not
   an application feature.
4. **Every mutation is attributable.** An append-only audit trail is cheap now and
   irreplaceable later, particularly for the points economy.
5. **Data minimalism as a default.** No third-party analytics, no external fonts, no
   error-reporting SaaS, no tracking SDK in the apps. Every outbound connection must
   justify itself.
6. **Ship thin slices end to end.** A module that is 60% done in all four layers beats
   two modules perfect in the database and absent from the screen.
