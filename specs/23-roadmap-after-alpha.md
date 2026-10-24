# 23 — Roadmap after the Alpha

*Drafted 2026-10-18, while the Alpha goes onto the pilot household's devices.* This is the
plan for what comes **after** M1.6, the step that follows [13 — Roadmap](13-roadmap.md). It
does not replace 13's milestones. It orders what 13 left for M2 and M3, what
[14](14-open-questions.md) left open, and a few new candidates, into four phases, and runs
each item past the principles first.

Not repeated here: the journey gaps of [16, step 10](16-setup-plan.md#step-10--journey-gaps-before-launch-m15)
and the M1.6 launch checklist. They belong to the Alpha and come first.

## The test every item passes

An item is on this roadmap only if it passes all of these. Each one comes from a
decision already taken, linked so it is not argued again.

| # | Test | Comes from |
|---|---|---|
| P1 | **No service run by the project holds a family's data.** Anything new runs on the family's own server or on the device | [ADR-018](adr/ADR-018-self-hosted-only.md) |
| P2 | **Every outbound connection justifies itself.** No analytics, no crash-reporting SaaS, no tracking SDK. A third party is contacted by the server, never by the apps, and the privacy policy names it in both languages in the same change | [01, principle 5](01-vision-and-scope.md#principles), [11](11-security-and-privacy.md) |
| P3 | **Never punish a child in software.** No negative points, no leaderboard, no public failure, no money for points | [01, principle 3](01-vision-and-scope.md#principles), [06](06-module-tasks.md), Q6 |
| P4 | **Every mutation is attributable.** One `api` function per write, `app.actor()` first, an audit row in the same transaction | [01, principle 4](01-vision-and-scope.md#principles), [03](03-architecture.md) |
| P5 | **No household is hard-coded.** What one family would answer differently is a setting with a curated default | [21](21-household-settings.md) |
| P6 | **Capture in three seconds, the wall readable from two metres, the week visible without asking.** A feature that slows any of the three is not worth it | [01, the vision](01-vision-and-scope.md#the-vision) |
| P7 | **Deepen against observed use, not imagined use.** A conditional item waits for evidence from a real family | [13, milestone discipline](13-roadmap.md#milestone-discipline) |
| P8 | **Do not become a second Nextcloud.** No chat, photo sharing, document storage, budgeting or two-way calendar sync | [01, out of scope](01-vision-and-scope.md#explicitly-out-of-scope), [ADR-001](adr/ADR-001-calendar-backbone.md) |
| P9 | **Four application languages, accessible, portable.** Complete DE/EN/FR/ES ARB and server catalogues, DE/EN family guides, the targets of NFR-13/16, one installation-selected email language, and a server that still runs on any Supabase stack inside the `api_version` window | [AGENTS.md](../AGENTS.md), [ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md#amendment-2026-10-19-four-application-languages-and-one-email-language), [ADR-018](adr/ADR-018-self-hosted-only.md) |
| P10 | **Joy without levers.** *(Added 2026-10-24.)* Delight answers a moment the family created and never pulls anyone into the app: no mascot in a notification, no streak to lose, no "come back", no second currency for children | [01, principle 7](01-vision-and-scope.md#principles), [ADR-020](adr/ADR-020-a-lighter-day.md) |

The rules every slice follows in the build (pgTAP for the cross-household, revoked-device
and unauthenticated cases; `api_version` raised for a contract change; the docs page in both
languages) are [03](03-architecture.md)'s and [16, step 10](16-setup-plan.md#step-10--journey-gaps-before-launch-m15)'s
and are not repeated per item.

## The four phases

Each phase starts only when the one before it has a reason to end. Phases R2 and R3 can
overlap once R1 is done.

| Phase | Starts when | Done when |
|---|---|---|
| **R1 — Learn from the Alpha** | The pilot household has used the Alpha for two weeks ([13, M1.6](13-roadmap.md#m16-launch)) | The household's questions from those weeks have an answer in the app, and the curated defaults are recalibrated once |
| **R2 — Ready for other families** | R1 is done | Every line of [13's opening gate](13-roadmap.md#opening-to-other-households) is true |
| **R3 — Depth** | R1 is done, and an item has evidence from use | Never as a whole; each item is done on its own |
| **R4 — Only when a family asks** | A real family asks, with a concrete case | Each is a decision first, and a build only if the decision says so |

---

## R1 — Learn from the Alpha

*About three to four weeks. Reserve half of it for what the two weeks show (13's own rule
for M2); the items below are the half that is already known.*

| Item | What | Why now | Passes because |
|---|---|---|---|
| **R1.1** Feedback without telemetry | Einstellungen → *Feedback geben*: a prefilled mail or GitHub issue with app version, build, platform and the server's `api_version`, shown to the member before anything leaves the device. Optionally a local diagnostic log (the last errors and `Failure` codes, no household data) the member can attach by hand | The Alpha's feedback has to come from somewhere, and there is no crash reporting on purpose | Nothing is sent automatically (P2); the operator receives only what the member chose to send |
| **R1.2** Recalibrate the curated defaults | Review points, reward prices, jokers, duty and bonus, notifications, key flag, board rollover and member labels ([#10](https://github.com/wuselwall/wuselwall-app/issues/10), [#6–#9](https://github.com/wuselwall/wuselwall-app/issues/6), Q13, Q25–Q27) against two weeks of use, and change the defaults that were wrong in one migration | Every proposed default says "review after two weeks of real use" | A default changes, a household's override does not (P5) |
| **R1.3** The audit log in Einstellungen | The last 30 days by member, guardians only, filterable by origin (app, wall, Shortcuts, assistant). A read view over the existing audit rows ([13, M2](13-roadmap.md#m2--assistants-and-the-obvious-gaps)) | "Who ticked my chore on the wall?" is the first dispute a tap-to-switch device produces, and J2 promises it as the counterweight to guardian invitations | It shows what P4 already records; no new data |
| **R1.4** Mark what an assistant added | A small marker on shopping items and tasks created through Shortcuts or MCP ([Q17](14-open-questions.md)) | Siri can already add shopping items, and nobody can tell them apart | Trust and reviewability; the origin is already in the audit row (P4) |
| ~~**R1.5** Birthdays on the profile~~ *Moved before M1.6 on 2026-10-24 ([16, step 11.6](16-setup-plan.md#step-11--a-lighter-day-m15), [27](27-family-rituals.md#birthdays)): Vorfreude counts down to them* | `profile.birthday`, projected like public holidays as a read-only occurrence: "Paul wird 8" on the board's day header and in the month view ([Q50](14-open-questions.md)). Written on the member page of step 10.1. Grandparents stay yearly events | The most-asked family date | A guardian-set field; no reminder mail, no third party (P2) |
| **R1.6** A month overview | A read-only month view in the calendar for Ferien, public holidays, birthdays and key appointments ([13, M2](13-roadmap.md#m2--assistants-and-the-obvious-gaps)) | The views stop at a week, and holidays are planned months ahead | Read-only, so no new write path |
| **R1.7** Backups the family can see | The backup job records its last success; guardians see *Datensicherung: zuletzt heute 03:10* in Einstellungen, and a warning card on Today after 48 hours without one. `wuselwall restore --verify` restores the newest dump into a throwaway database and records the date | Success criterion 6 of [01](01-vision-and-scope.md#what-success-looks-like): no unplanned data loss, ever, and a tested restore | The status lives on the family's own server (P1); no monitoring service |
| **R1.8** The wall at night | The night variant gains household-set quiet hours with the screen dimmed or off, and the kiosk tile layout polish still open from M1.1 | A wall that lights the kitchen at 02:00 is switched off by morning, and then it is not looked at | A household setting with a curated default (P5); P6 |

## R2 — Ready for other families

*The opening gate of [13](13-roadmap.md#opening-to-other-households), made into work.
About four to six weeks. The store listings stay internal until the last item is done.*

| Item | What | Passes because |
|---|---|---|
| **R2.1** CI against the previous server release | A CI job runs the current app's integration tests against the previous tagged server release, as ADR-018 requires, and a test that the app refuses a server outside the `api_version` window with a clear message | P9: version skew between store apps and servers is permanent |
| **R2.2** A safe `wuselwall update` | Backup first (refuse to continue without one), dry run of the new migrations, health check after, release notes shown before the update starts, and what to do when it fails | An operator who is a parent with a NAS cannot be asked to read SQL |
| **R2.3** The fifth job: empty-account clean-up | Accounts without a household after 30 days are deleted, with the job in `infra/cron/` and `server/wuselwall schedule` ([11, T11](11-security-and-privacy.md#t11--the-open-front-door)) | The abuse control that replaced a captcha (Q44); no third party |
| **R2.4** Server status in the app | Einstellungen → Server for guardians: the server's release, `api_version`, the jobs' last runs, and *Server-Update empfohlen* when the server is older than the app's current `api_version` — computed in the app, with no call to GitHub | P1, P2: the server never phones home to learn about updates |
| **R2.5** A self-hosting guide that a parent can follow | `docs/server` walked through on one clean Docker host from nothing to Today, with mail and without (step 10.4), timed, both languages; NAS notes marked as tested or not | The gate's "self-hosting kit" line |
| **R2.6** Honest store listings | App privacy labels and the Data safety form filled in from [11](11-security-and-privacy.md) and the privacy policy, App Review pointed at the demo mode, store screenshots from the docs' demo shots | P2 has to be true in the stores' forms too |
| **R2.7** The cross-household review | The cross-household pgTAP suite read again with "a stranger is on the other side" in mind, every gap a test first | The gate's last technical line |
| **R2.8** Accessibility on real devices | VoiceOver and TalkBack, 200 % system text, reduced motion, on an iPhone, an iPad and the wall tablet; the parts the Alpha's audit could only simulate | P9; a seven-year-old's frustration tolerance is the design constraint ([01](01-vision-and-scope.md#users)) |

## R3 — Depth

*Each item starts only with a reason from use. They are ordered by how often the reference
household is expected to need them, and that order changes with R1's findings.*

| Item | What | Passes because |
|---|---|---|
| **R3.1** OAuth for assistants | Supabase Auth's OAuth 2.1 server with the server's own login and consent screens, and grant management in Einstellungen, replacing the `wwa_` interim keys ([Q15](14-open-questions.md), [12](12-mcp-and-assistants.md#part-2--the-mcp-server)) | The family's own assistant talks to the family's own server; the project is not in the path (P1) |
| **R3.2** The first MCP write scope: shopping | `shopping:write` only ([Q16](14-open-questions.md)): add and tick items, attributed to the person who granted it, marked as R1.4 does | The most useful and least destructive write; attributable (P4) |
| **R3.3** Recipe import from a URL | The family's server fetches the page, reads schema.org JSON-LD and shows a preview before saving (FR-3.9). Private addresses refused, size and time limited | The server, not the app, contacts the site (P2); nothing is kept but the recipe |
| **R3.4** A family goal | One shared goal the whole family's points fill ("Zoo-Ausflug"), shown on the wall without a per-child breakdown ([06](06-module-tasks.md)) | Cooperative, never comparative (P3) |
| **R3.5** Ageing bonuses | An open bonus task slowly gains points until someone takes it; a household setting, off by default | Rewards picking the task up; nobody loses anything (P3, P5) |
| **R3.6** Richer badges and rewards | More badges and a wider starter catalogue of non-money rewards (time, choices, outings) | P3 and Q6: no money items |
| **R3.7** The adult register at a desk | Keyboard shortcuts and bulk editing (move, reassign, delete several) in the web build and on an iPad (moved here from [09](09-clients-and-ux.md)) | P6 for the planning parent on Sunday evening |
| **R3.8** Candidates to decide after R1 | New ideas, each to be accepted or rejected with the Alpha's evidence rather than built on spec: *wer holt ab?* (which adult collects which child, on the wall beside the school-day span); *Stammartikel* (staples offered before a planned trip); *Woche wiederholen* (copy last week's meal plan); a busy-until derived from a read-only work calendar (Q28) | Each must pass P1–P9 before it gets its own item |

## R4 — Only when a family asks

Each of these is a decision card, not a build. The decision records the case that prompted
it, and the answer goes into [14](14-open-questions.md).

| Item | The question | What would make it a yes |
|---|---|---|
| **R4.1** A push relay | Do local reminders and the Today notices miss something that matters ([Q47](14-open-questions.md), Q38)? | A real missed event. The relay would be the one service the project runs: stateless, a device token and an end-to-end-encrypted payload, no household data |
| **R4.2** One account in two households | Separated parents and a child with two homes ([Q43](14-open-questions.md)) | A real family with that case, and a design that keeps every read inside one household |
| **R4.3** CalDAV for the phones | Is the read-only feed too limiting on the move ([05](05-module-calendar.md#later-two-way-for-the-phones))? | Entering events in WuselWall proves to be the reason they are not entered. Never Outlook two-way (P8) |
| **R4.4** A school portal import | Does a family's school publish substitutions (Q20, FR-7.14)? | A school with a documented feed; manual entry stays the default. *2026-10-22: the pilot's schools publish paper and closed platforms, so the sheet comes in by paste, proposal or photo instead ([24](24-school-import.md))* |
| **R4.5** More languages | Further languages beyond the built DE/EN/FR/ES set, e.g. Italian for Swiss families, since the regions already reach the Gemeinde | A maintainer who keeps every app/server string and native permission prompt complete in that language (P9); family-guide translation stays a separate DE/EN decision |

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
| A mood check-in for children | Turns a child's feelings into stored data and reads as monitoring; P3's spirit | The Tischfrage's *Heute* questions, answered aloud and never recorded ([27](27-family-rituals.md#tischfrage)) |
| Children's drawings or photos on the wall | Photo and file storage (P8) | A paper drawing on the fridge; Wusel's outfits for self-expression |
| BeReal-style prompts ("what are you doing right now?") | Photos (P8) and a push to respond (P10) | — |
| A Wusel that needs feeding or care, or gets sad | Guilt by design (P3, P10); Finch keeps its pet from dying for this reason | Wusel's warm, positive range ([25](25-wusel.md#who-wusel-is)) |
| Wusel outfits or items earned with points | A second reward loop aimed at children; the overjustification risk (P10) | Outfits free from the start ([25](25-wusel.md#outfits)) |
| Wusel in notifications, reminders in a character's voice | The Duolingo pattern (P10) | The plain voice of [09](09-clients-and-ux.md#realtime-and-notifications) |

## Keeping this file honest

When an item is built, strike it here and record it where 13 records built work. When R1's
findings change the order, change the tables, not the phases. When the "next step" changes,
the DE/EN public "Where we are" list on the website and the status line in `AGENTS.md` change
in the same commit; the website copy itself is a separate repository change.
