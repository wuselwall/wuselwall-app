# 23 — After the Alpha: choose from use

Updated 2026-10-24. [13 — Roadmap](13-roadmap.md) is the single milestone schedule.
The old R1 learning work is part of **3 — Family Alpha**; R2 is **4 — Ready for other
families**. R3/R4 below are candidates, not additional releases or deadlines. Old item IDs
stay for traceability, not as a second build order.

<a id="the-four-phases"></a>
<a id="r1--learn-from-the-alpha"></a>

## Learn within the Alpha

Gather feedback directly during the two-week trial. Fix blockers, review curated defaults
without overwriting household overrides, and give Wusel, colour and every ritual its
keep/change/remove verdict. A feedback screen is not a prerequisite for talking to the
pilot household. Any future diagnostic report is previewed and sent deliberately, without
household data or automatic telemetry.

Birthdays (old R1.5) have moved to **2 — A lighter day**. Already-built Shortcuts, read-only
MCP, reminders, ICS import and timetable import do not return as future tasks.

<a id="r2--ready-for-other-families"></a>

## Make the opening gate one milestone

**4 — Ready for other families** owns compatibility with the previous server release,
backup-first updates, server/job/backup status, empty-account cleanup, the independent
installation walkthrough, security/accessibility review and store/legal readiness.
See [the gate](13-roadmap.md#opening-to-other-households); do not duplicate its checklist
here. Backup and wall problems that prevent a safe Alpha are blockers in milestone 3.

## Useful next candidates

Choose after the Alpha, with a concrete observation and an acceptance criterion. None is a
promised bundle or a gate for public release unless the trial shows why it must be.

| Old item | Candidate | Evidence to look for |
|---|---|---|
| R1.1 | Previewed, member-sent feedback/diagnostics | Families need an easier way to report a problem than the pilot conversation |
| R1.3 | Guardian audit history, last 30 days, by member/origin | A family needs to understand who changed something; the audit data already exists |
| R1.4 | Assistant-origin markers | Shortcuts/MCP additions are being confused with manual entries |
| R1.6 | Read-only calendar month | Planning Ferien, birthdays or appointments across weeks is awkward |
| R1.8 | Further wall quiet-hour/layout controls | The built night/ambience settings do not solve an observed display problem |
| 10.10 | Retire legacy wizard/enrolment paths | A distributed release and the supported previous-version window no longer require them; remove only then |

R1.2 (defaults) is in milestone 3; R1.7 (backup visibility/verification) is in milestone 4.
Any missed native accessibility check remains a release gate, not a backlog preference.

## The test every item passes

An item is on this roadmap only if it passes all of these. Each one comes from a
decision already taken, linked so it is not argued again.

| # | Test | Comes from |
|---|---|---|
| P1 | **No service run by the project holds a family's data.** Anything new runs on the family's own server or on the device | [ADR-018](adr/ADR-018-self-hosted-only.md) |
| P2 | **Every outbound connection justifies itself.** No analytics, no crash-reporting SaaS, no tracking SDK. A third party is contacted by the server, never by the apps, and the privacy policy names it in all shipped website languages in the same change | [01, principle 5](01-vision-and-scope.md#principles), [11](11-security-and-privacy.md) |
| P3 | **Never punish a child in software.** No negative points, no leaderboard, no public failure, no money for points | [01, principle 3](01-vision-and-scope.md#principles), [06](06-module-tasks.md), Q6 |
| P4 | **Every mutation is attributable.** One `api` function per write, `app.actor()` first, an audit row in the same transaction | [01, principle 4](01-vision-and-scope.md#principles), [03](03-architecture.md) |
| P5 | **No household is hard-coded.** What one family would answer differently is a setting with a curated default | [21](21-household-settings.md) |
| P6 | **Capture in three seconds, the wall readable from two metres, the week visible without asking.** A feature that slows any of the three is not worth it | [01, the vision](01-vision-and-scope.md#the-vision) |
| P7 | **Deepen against observed use, not imagined use.** A conditional item waits for evidence from a real family | [13, milestone discipline](13-roadmap.md#milestone-discipline) |
| P8 | **Do not become a second Nextcloud.** No chat, photo sharing, document storage, budgeting or two-way calendar sync | [01, out of scope](01-vision-and-scope.md#explicitly-out-of-scope), [ADR-001](adr/ADR-001-calendar-backbone.md) |
| P9 | **Four application languages, accessible, portable.** Complete DE/EN/FR/ES ARB and server catalogues, DE/EN/FR/ES family guides, the targets of NFR-13/16, one installation-selected email language, and a server that still runs on any Supabase stack inside the `api_version` window | [AGENTS.md](../AGENTS.md), [ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md#amendment-2026-10-19-four-application-languages-and-one-email-language), [ADR-018](adr/ADR-018-self-hosted-only.md) |
| P10 | **Joy without levers.** *(Added 2026-10-24.)* Delight answers a moment the family created and never pulls anyone into the app: no mascot in a notification, no streak to lose, no "come back", no second currency for children | [01, principle 7](01-vision-and-scope.md#principles), [ADR-020](adr/ADR-020-a-lighter-day.md) |

The rules every slice follows in the build (pgTAP for the cross-household, revoked-device
and unauthenticated cases; `api_version` raised for a contract change; the guide page in all four
languages) are [03](03-architecture.md)'s and [16, step 10](16-setup-plan.md#step-10--journey-gaps-before-launch-m15)'s
and are not repeated per item.

<a id="r3--depth"></a>

## Later — Depth

*Each item starts only with a reason from use. They are ordered by how often the reference
household is expected to need them, and that order changes with the Alpha's findings.*

| Item | What | Passes because |
|---|---|---|
| **R3.1** OAuth for assistants | Supabase Auth's OAuth 2.1 server with the server's own login and consent screens, and grant management in Einstellungen, replacing the `wwa_` interim keys ([Q15](14-open-questions.md), [12](12-mcp-and-assistants.md#part-2--the-mcp-server)) | The family's own assistant talks to the family's own server; the project is not in the path (P1) |
| **R3.2** The first MCP write scope: shopping | `shopping:write` only ([Q16](14-open-questions.md)): add and tick items, attributed to the person who granted it, marked as R1.4 does | The most useful and least destructive write; attributable (P4) |
| **R3.3** Recipe import from a URL | The family's server fetches the page, reads schema.org JSON-LD and shows a preview before saving (FR-3.9). Private addresses refused, size and time limited | The server, not the app, contacts the site (P2); nothing is kept but the recipe |
| **R3.4** A family goal | One shared goal the whole family's points fill ("Zoo-Ausflug"), shown on the wall without a per-child breakdown ([06](06-module-tasks.md)) | Cooperative, never comparative (P3) |
| **R3.5** Ageing bonuses | An open bonus task slowly gains points until someone takes it; a household setting, off by default | Rewards picking the task up; nobody loses anything (P3, P5) |
| **R3.6** Richer badges and rewards | More badges and a wider starter catalogue of non-money rewards (time, choices, outings) | P3 and Q6: no money items |
| **R3.7** The adult register at a desk | Keyboard shortcuts and bulk editing (move, reassign, delete several) in the web build and on an iPad (moved here from [09](09-clients-and-ux.md)) | P6 for the planning parent on Sunday evening |
| **R3.8** Candidates to decide after the Alpha | New ideas, each to be accepted or rejected with the Alpha's evidence rather than built on spec: *wer holt ab?* (which adult collects which child, on the wall beside the school-day span); *Stammartikel* (staples offered before a planned trip); *Woche wiederholen* (copy last week's meal plan); a busy-until derived from a read-only work calendar (Q28) | Each must pass P1–P10 before it gets its own item |

<a id="r4--only-when-a-family-asks"></a>

## Only when a family asks

Each of these is a decision card, not a build. The decision records the case that prompted
it, and the answer goes into [14](14-open-questions.md).

| Item | The question | What would make it a yes |
|---|---|---|
| **R4.1** A push relay | Do local reminders and the Today notices miss something that matters ([Q47](14-open-questions.md), Q38)? | A real missed event. The relay would be the one service the project runs: stateless, a device token and an end-to-end-encrypted payload, no household data |
| **R4.2** One account in two households | Separated parents and a child with two homes ([Q43](14-open-questions.md)) | A real family with that case, and a design that keeps every read inside one household |
| **R4.3** CalDAV for the phones | Is the read-only feed too limiting on the move ([05](05-module-calendar.md#later-two-way-for-the-phones))? | Entering events in WuselWall proves to be the reason they are not entered. Never Outlook two-way (P8) |
| **R4.4** A school portal import | Does a family's school publish substitutions (Q20, FR-7.14)? | A school with a documented feed; manual entry stays the default. *2026-10-22: the pilot's schools publish paper and closed platforms, so the sheet comes in by paste, proposal or photo instead ([24](24-school-import.md))* |
| **R4.5** More languages | Further languages beyond the built DE/EN/FR/ES set, e.g. Italian for Swiss families, since the regions already reach the Gemeinde | A maintainer who keeps every app/server string and native permission prompt complete in that language (P9); family guides need their own maintained translation |

## Not on the roadmap, and why

Recorded so that they are not proposed again every few weeks.

| Idea | Why not | Instead |
|---|---|---|
| A sibling leaderboard, streak-loss shaming, negative points | P3 | The family goal (R3.4) |
| Points as pocket money, allowance payouts | Q6: a design rule, not a setting | Non-money rewards (R3.6) |
| Two-way sync with Outlook or Google | [ADR-001](adr/ADR-001-calendar-backbone.md), P8 | The ICS feed; CalDAV only through R4.3 |
| Family chat, photo sharing, document storage, budgeting | P8 | The tools a family already uses for them |
| Crash reporting or analytics services | P2 | R1.1's feedback the member sends by hand |
| An AI meal planner or chatbot run by the project | P1, P2 | The family's own assistant through MCP (R3.1, R3.2) |
| A hosted WuselWall, paid plans, ads | ADR-018, [01](01-vision-and-scope.md#explicitly-out-of-scope) | The self-hosting kit (R2) |
| Weather or traffic on the wall | P2: a third party for something every phone already shows | Reopen only through R3.8 with a server-side, coarse-location, opt-in design |
| Homework, grades, absence reporting | [15](15-module-school-timetable.md#v1-scope-cut): the school already has one | — |
| Per-item privacy between family members | [01](01-vision-and-scope.md#explicitly-out-of-scope) | Guardian-only settings, as today |

## Keeping this file honest

When evidence selects a candidate, give it one issue with an outcome and assign a milestone
only when committing to that outcome. When it is built, remove it from this candidate list
and update [13](13-roadmap.md)'s status. Keep GitHub, the README and `AGENTS.md` in sync;
coordinate public-progress copy separately in the website repository. Do not require a
website checkout to contribute here.
