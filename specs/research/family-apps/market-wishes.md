# What users of family apps want, ask for and complain about

Researched 2026-10-24 for WuselWall. Read against `specs/market-research.md` (competitors, 2026-10-11),
`01-vision-and-scope.md`, `23-roadmap-after-alpha.md` and `13-roadmap.md`. Nothing in the repository was changed.

## 1. Method and limits (read this first)

**What was actually mined**

| Source | Size | How |
|---|---|---|
| Apple App Store customer reviews (public RSS feed), 38 apps, storefronts US, GB, DE, AT, CH, FR, ES, newest up to 500 per app and storefront | about 30,400 reviews (18,624 in the family-planner and chores set, 11,838 in the adjacent set: co-parenting, school communication, visual schedules, screen time, vaccination, pocket money) | keyword and regex counts, then reading samples. Counts are **mentions** (praise and requests mixed), so they show salience, not demand |
| GitHub issues sorted by reactions: Yuvomi, Tribu, Donetick, KitchenOwl, Grocy, Mealie, ChoreOps, Hestia, Skylite-UX, FamilyNido, Pinn | read via `gh api search/issues` | reaction count is the demand signal |
| Home Assistant community threads (TaskMate, wall tablets, LX Family) | 4 threads, thin replies | read |
| Web search (vendor pages, news, cantonal documents) | many results were SEO spam and were discarded | read |

**What could not be reached**

- **Reddit is not accessible** from this environment (the fetch tool and the search tool both refuse reddit.com, `curl` gets a block page).
  No claim below comes from r/Parenting, r/selfhosted, r/homeassistant, r/daddit, r/Mommit, r/de or r/Switzerland. Reddit-only themes
  (r/ADHD parenting, co-parenting threads, "regret" threads about Skylight) are therefore under-represented. The only trace is the topic
  index of r/skylightcalendar on GummySearch (calendar 70, sync 41, tasks 20, chores 15, features 13 posts; a "Feature Request: API"
  thread and a "Regret" thread exist but could not be read).
- Google Play reviews were not scraped. App Store skews to iPhone owners; Play would add Android-specific (widget, battery) complaints.
- German, French and Spanish parenting forums (urbia, gutefrage, Doctissimo, Hispamoms) did not surface through search. DE/FR/ES
  evidence is the App Store reviews of FamilyWall, TimeTree, Cozi, FamCal, Famanice, Bring!, SchoolFox, Klapp.
- "Evidence strength" below: **A** = 100+ mentions across 3+ apps or storefronts, or 15+ GitHub reactions and a second source.
  **B** = 30 to 100 mentions or two independent kinds of source. **C** = under 30 mentions or a single source.

## 2. The five biggest facts

1. **Price and paywalls are the single largest complaint, everywhere.** Mentions of subscription, premium, ads or fee: FamilyWall 187 of
   1,853 reviews, Cozi 147 of 1,113, TimeTree 126 of 2,619, Skylight 63 of 606, Hearth Companion 33 of only 122, Joon 88 of 590, and
   30 to 40 percent of co-parenting reviews (OurFamilyWizard 206/570, AppClose 194/562, TalkingParents 213/520). In one-star and two-star
   reviews of the planners it is 20 percent. Skylight and Hearth owners say the hardware "is a calendar brick without the subscription".
   WuselWall (free, self-hosted, ADR-018) already answers this. It is a marketing fact, not a feature.
2. **Reliability and sync are the second.** Crashes, lost data, duplicates, wrong colours after a re-sync, push that does not arrive
   (SchoolFox: 185 of 512 reviews mention failing login, load or push). A family tool is judged on "did the reminder arrive".
3. **Kids' routines are what the new hardware calendars are loved for.** 40 of Hearth's 122 companion-app reviews (33 percent) praise
   "routines"; Joon (a routines-and-quests app for children with ADHD or autism) has 590 reviews, 106 mention routines, 156 mention ADHD,
   autism or sensory needs, 64 say "no more nagging". WuselWall has chores with points but no routine with steps.
4. **Widgets and the wrist.** Home-screen widgets are asked for or fixed in 7.1 percent of FamilyWall reviews (132), and Apple Watch or
   Siri on the wrist in 7.2 percent of Bring! reviews (206). Both are cheap for the user and absent from the 23 roadmap.
5. **"Mental load" is named as the benefit, in DE, AT and FR.** 11 FamilyWall reviews say it outright ("Reduziert meinen Mental Load",
   "Fini la charge mentale ... plus besoin de me répéter"). The value people describe is shared *visibility* (the other adult can see it,
   nobody repeats it), not task scoring. That is exactly vision property 3 of `01`.

## 3. Ranked wishes

Ordered by evidence strength first, then by how much the wish is missing from the specs. "Status" cites the spec.

| # | Wish | Evidence | WuselWall status | Principle check | Recommendation |
|---|---|---|---|---|---|
| 1 | **Kids' routines: a morning / evening checklist with steps, picture-led, instead of a parent who nags** | **A.** Hearth 40/122 reviews; Joon 106 routine, 156 ADHD/autism, 64 "nagging", 95 about the pet/character; Skylight 13; Tiimo (21k US ratings) and Lil Planner; HA TaskMate: "picture-based mode for pre-readers"; Donetick #608 sub-tasks in the list, #911 require sub-tasks (small); Hestia #35/#43 | **Not covered.** `06` has tasks with RRULE and four assignment policies, no steps; `06` lists "time estimates, task dependencies" as out; `09` kid register is icon-led but has no routine object | Compatible if there is no timer, no per-step points, no streak on the routine, no push (P3, P10). Joon's pet that must be fed is the lever `25`/ADR-020 rejects | **Build as an R3 item.** A *Routine* is an ordered list of pictogram steps for one daypart (Morgen, Abend), shown on the kid home and in a wall tile, completed as one task instance. Steps tick locally; points (if any) once, for the whole routine. Check the existing getting-ready slots on the board first |
| 2 | **Home-screen widgets** (today, next appointment, shopping list), per person, on phone and tablet | **A.** FamilyWall 132 mentions (DE, FR, ES, UK); TimeTree 38; Howbout 20; Famanice, Skylight; GitHub: Donetick #387 (14), KitchenOwl #287 (9). Typical ask: "widget filtered to me, not the whole family" (FamilyWall FR) | **Acknowledged, not scheduled.** `09` says "a widget for the open-task count is a natural M3 candidate" and iOS widgets need native Swift | Local data only, no network, so P1, P2, P6 hold | **Add to R3**: a Today widget (next three appointments, open tasks) and a shopping widget, per signed-in member, iOS and Android. Pairs with the Android demo-UI work of #117 |
| 3 | **Shopping and agenda on the wrist and by voice** (Apple Watch, Siri on HomePod, Alexa) | **A for the wrist and Siri** (Bring!: Watch 206 of 2,867; Siri/Alexa/Google Home 119; FamilyWall 26 Watch, 8 voice; Cozi 8 voice). **B for Alexa/Google** (Grocy #236, 15 reactions; KitchenOwl #117, 11) | **Partly built.** Siri via Shortcuts for shopping, agenda, tasks (`12`, built 2026-10-16). No watch app, no Alexa/Google Home | Alexa and Google Home route household data through a third party (P1, P2). Shortcuts already run on the Watch and HomePod | **Test and document** "Siri on Watch and HomePod" with the existing Shortcuts (FR, ES, DE, EN). Do not build a watch app or Alexa skill. The MCP surface (R3.1) is the answer for the family's own assistant |
| 4 | **Event capture from a letter, flyer, invitation or screenshot** (the AI "Sidekick" / "Helper") | **B.** Skylight Sidekick and Hearth Helper are the paywalled features reviewers praise ("auto scans and loads appointments from emails and letters", "saved us hours"); Klapp and SchoolFox users ask for a calendar they can use and for forwarding Elternbriefe: Klapp CH "weder auf dem MacBook ... noch ... an externe Mail weiterleiten", 15 of 324 Klapp reviews mention the calendar | **Partly planned.** `24` imports timetable sheets by paste, assistant proposal and photo, with a local OCR container. Letters and invitations are not covered. R4.4 (school portal) is about feeds, not letters | Server-side OCR on the family's server keeps P1 and P2. Must show a proposal before saving (P4) | **Extend `24` to "Terminvorschläge aus einem Brief"**: photo or pasted text of an Elternbrief or invitation produces proposed events and a packing note, reviewed one by one. Same pipeline, new extractor. No cloud AI |
| 5 | **Two homes: a child who lives alternately with two parents** | **B.** Co-parenting apps are a separate market (OurFamilyWizard 56k US ratings; Wechselplan.de, a German PWA at 8.98 EUR/month; Shared, 2houses, Copario); FamilyWall UK reviewer "my ex and I are using this to schedule childcare"; DACH guides say a plain calendar "reicht nicht" for Wechselmodell | **Planned as a decision.** Q43, R4.2 ("a real family with that case"). The A/B week mechanic of `15` exists for school only | Anything *between* households is out of scope (`01`). Co-parent products are dominated by court records, messaging tone and expense splitting, which are P8 territory | **Keep R4.2.** Cheap interim inside one household: a per-child *Betreuungsmuster* (week A at Mama, week B at Papa, holidays split) as a presence pattern reusing `week_cycle` and ADR-009, so the wall can say "Jack ist diese Woche bei Papa". Do not add messaging, expenses or evidence logs |
| 6 | **Limited access for helpers: grandparent, babysitter, au pair, Betreuung** | **B-/C.** TimeTree FR 4-star "pas de read only ... qui ne peuvent pas modifier mais suggérer"; Hestia #33 "Restricted profile role"; Hearth reviewer: "coordinating care ... with visiting grandparents or other helpers"; Skylight "medical based household"; FamilyWall UK has a second setup "for the grandparents" | **Partly covered.** Per-subscriber ICS tokens (FR-1.6, `05`); role `member` for an au pair or grandparent who ticks tasks (`20`). No read-only role; `08` says "resist adding a third" | No per-item privacy is a stated non-goal, so a *view* role that sees everything is consistent; a role that hides things is not | **Small step:** a token-protected, read-only "Heute und diese Woche" page (like the feed token, revocable, optional expiry) plus a guardian-written "für die Betreuung" note (allergies, bedtime, numbers). No third role |
| 7 | **Reusable lists and repeat actions** (packing lists, staples, "same as last week") | **B-.** Bring!: 32 mentions of recurring staples and favourites, 42 of moving items between lists, French "mettre en favori", "planification à la semaine"; chores set 35 for packing, templates, checklists; Mealie/KitchenOwl ask for scaling, pantry (#10, 10 reactions) | **Planned as candidates.** R3.8: Stammartikel, Woche wiederholen; packing reminder built from the timetable (FR-7.12, `15`) | Fine. Pantry or stock tracking is Grocy territory (P8) | **Pull *Stammartikel* and *Woche wiederholen* from R3.8 into R1/R2 if the pilot shows retyping.** Add a "Packliste" as a list whose ticks reset (swimming bag, school trip). No stock tracking |
| 8 | **Home Assistant, webhooks, an API** | **B** (self-hosting audience). Donetick #147, #319, #44 webhooks (4), #357 n8n (3); Hestia #41 HA, #31 tokens; Skylite-UX #99 and #100 API; Skylight owners: "an api for home assistant", "useful endpoints for the Shortcuts app"; KitchenOwl, Grocy; ChoreOps (450 stars) lives entirely inside HA | **Not planned.** Only the market research mentions it. MCP and Shortcuts exist (`12`) | Outbound webhooks from the server are P2-compatible if the family configures the target | **Docs, not code:** a "WuselWall and Home Assistant" recipe using the ICS feed (calendar entity), the Shortcuts REST endpoints (to-do, shopping) and later an R3.2 `shopping:write` scope. Consider one outbound webhook (opt-in) only when a family asks (R4) |
| 9 | **Calendar sync that does not break** (Google, Outlook, Apple, work calendars) | **A as a complaint**, not as a request for WuselWall: sync or Google/Outlook mentions 202 in the family set (73 low-rated); duplicated events 44; Skylight "not compatible with Qgenda"; Yuvomi #1897 #237 #220 #236 (Google variants), KitchenOwl #127 (9) | **Deliberately out.** ADR-001, P8: ICS out, read-only ICS in (`imported` source built 2026-10-14); CalDAV only via R4.3 | The complaints are exactly the "duplicate and ghost events" ADR-001 predicted. This *supports* the decision | Keep ADR-001. Invest in the **read-only import**: show last fetch, errors and a "refresh now"; let a source be assigned to a member (Skylight "default assignee per calendar" echoes Yuvomi #1897). Note it in the opening-gate FAQ |
| 10 | **A link, note or file on an event** (tickets, booking confirmation, invitation PDF) | **B-.** 95 attachment/ticket mentions in the planners; TimeTree CH "Bilder oder Dateien an ein Ereignis anheften ... Fehlermeldung"; FamilyWall FR "plusieurs photos ou PJ (ex: tickets de concert)"; Yuvomi #151 documents via WebDAV (12 comments), #762, #277 | **Out** (`05`: attachments; P8 document storage) | File storage is the "second Nextcloud" P8 forbids | **Add a URL field and a longer note, nothing stored.** If a family wants files, point at Nextcloud or Paperless via the URL |
| 11 | **Pocket money / Taschengeld ledger** | **A.** ChoresBot 84 of 544, Chorsee 85 of 541, Homey 30 of 377, S'moresUp 15 of 209 reviews; Sparkasse KNAX (virtual money, 137 DE/AT reviews, loved: "keiner vergisst es mehr"); bling and DB4Kids; FamilyWall users running kids' allowances through the budget screen; Pinn does it | **Rejected by design.** Q6, P3 ("no money for points"), R-not-on-roadmap row, `06` out: "allowance payouts" | **Conflict.** The demand is for tracking a *separate* weekly sum (deposit, spend, savings goal), not for converting points. Even so it is budgeting (P8) | **Do not build.** If a pilot family asks, make it an R4 decision card: a ledger with *no link to points*, guardians only, no bank. Say the stance plainly in the docs |
| 12 | **Notifications that arrive, but fewer** (per-person settings, quiet hours, not 30 pings) | **A as a theme.** SchoolFox push failing (185 of 512 reviews); "too many notifications" 375 mentions in chores apps (many are Joon praising "no nagging"); HA wall-tablet thread: "my house would stop yelling at everyone"; ES FamCal wants the family notified when someone adds a note | **Mostly covered.** Local reminders per person, morning summary 07:00, quiet by default (`09`, Q47 built 2026-10-14). Push relay R4.1 | P10 forbids pulling anyone in | **Keep.** Watch the pilot for "I did not get it" (R4.1's test). Note a phone not opened for seven days gets no reminder (`09`), the one gap SchoolFox-style complaints would find |
| 13 | **Private entries in a shared calendar** (a birthday gift, a work item, a doctor) | **C.** 35 mentions (TimeTree 23, FamilyWall 12), ES FamilyWall: "eventos privados ... solo yo" | **Out by decision** (`01`: no fine-grained privacy) | **Conflict, already decided.** The one exception worth a thought: *Überraschung* (hide from the children) | Keep the decision. A "nur Erwachsene" flag would be a small, honest compromise only if the pilot asks; do not build per-item ACLs |
| 14 | **Health: vaccinations, U-Untersuchungen, medication, vet** | **B as demand for a separate app**, **C inside planners.** ImpfPassDE has 9,856 ratings in DE (34 of 238 reviews are about family profiles), STIKO-App 13k; 54 mentions in planners; 11pets for pets | **Not covered, not planned** | Health data is sensitive; `01` has no per-member privacy, so it would be visible to the whole household and to an assistant | **Do not store records.** Offer a **template pack** of recurring appointments (U1 to U9, J1, school-entry check, annual dentist, vaccine boosters as *reminder only*). Pets: a pet as a non-person assignee for chores is enough |
| 15 | **Pets as family members** | **C.** 45 mentions in planners, 120 in chores apps (most are Joon's game pet); real-pet chores appear in Chorsee ("feeding the dog" rotation) and Sweepy | Covered as chores ("Jonas: feed the cat", `06`) | A pet that needs care is rejected (ADR-020) | Nothing to build. Mention "Haustier-Aufgaben" in the starter chores |
| 16 | **Screen-time rules** | **B for the category** (Qustodio 1,249 reviews, 23 percent iOS limits, 10 percent bypass; Family Link 295k US ratings); **C** as a planner feature | Rewards can be "30 Minuten Bildschirmzeit" (`06`, R3.6 non-money rewards); no enforcement | Enforcement is surveillance, and teens "hack it" (Qustodio reviews) and say "don't use this if you want your kids to trust you" | Stay out of enforcement. Ship "Bildschirmzeit" as a starter reward, redeemed by trust |
| 17 | **Photo proof of a done chore** | **C.** Chorsee, TaskMate, Hestia #43 ("photo verification") | Out in `06` v1 cut | Photo storage is P8; proof turns a chore into policing | Skip. Guardian verification (`06`) already exists |
| 18 | **Gift lists and wish lists** | **C.** FamilyWall 38 mentions; none from DACH | Not covered. A child's *Wunschessen* is covered (`27`) | Outside the three vision properties | Skip |
| 19 | **Carpool, who picks up** | **C.** 18 mentions in planners, 9 in chores; Skylight: "helps my husband know who is taking each child to their activities" | R3.8 *wer holt ab?* | Fine | Decide after the pilot as planned |
| 20 | **Barcode scanning / receipt OCR / Open Food Facts** | **B** in the self-hosted audience only: Grocy #158 (82 reactions), #404 receipts (34); KitchenOwl #123 images on items (18) | Not mentioned anywhere in `specs/` | Capture speed (P6) favours it, but Open Food Facts is a third party | Defer. Revisit only for the shop-time "scan to tick off" idea; the catalogue's picture tiles (`07`) already serve images |

### What users complain about that WuselWall already answers (keep saying it)

| Complaint | Where | WuselWall |
|---|---|---|
| Subscription for basics; hardware useless without it | Skylight, Hearth, Cozi Gold (30-day horizon), FamilyWall Premium, Joon (a month of £10), Bring! recipes and ads | Free, self-hosted, no ads (ADR-018, `01`) |
| English only | Cozi in DE reviews; Howbout ES "lo único que le falta es poder cambiarlo a español"; Tiimo DE "Englisch geschrieben" | DE/EN/FR/ES complete (P9) |
| The family shares one login, or a sibling ticks another's chores on the wall | Skylight "screen lock so the littles wouldn't mark off their siblings' chores"; Hearth "no user identification to stop siblings"; FamCal | Tap-to-switch with guardian PIN, device classes (`08`), and the audit view R1.3 |
| Sick day breaks a streak | chores apps | Jokers (`06`) |
| Week starts on Sunday; no month view; no per-person colours; no filter | TimeTree (Monday option 8 mentions), Cozi, FamilyWall | Monday (`21`), month view R1.6, member ink colours (`26`) |
| Meal planner not tied to the shopping list | Skylight GB "wish there was some synchronisation between the meal planner and the shopping list" | `07` |
| Meal plan behind a paywall, "I can ask any free AI for a meal plan" | Skylight | Free in WuselWall; the AI planner is on the "not on the roadmap" list |
| Wall screens gather dust | HA: "no one in the house looks at a screen on a wall" | Glanceable by design (P6), R1.8 night mode; test in the pilot |
| Data lock-in | Tiimo CH "Export fehlt" (ADHD users), 35 export/backup mentions | Self-hosted, backups, R1.7 |
| Privacy | OurFamilyWizard review listing third-party analytics hosts; Klapp consent questions in Basel-Landschaft | No third-party SDKs (P2) |

## 4. Principle conflicts to avoid recommending blindly

| Wish seen | Source | Conflicts with |
|---|---|---|
| Pocket money / allowance ledger | ChoresBot, Chorsee, Homey, KNAX, Pinn | Q6, P3, P8 |
| A pet that must be fed or a character who is sad (Joon's retention loop; "feeding his pet" is why children come back) | Joon 95 reviews | P3, P10, ADR-020 (Wusel stays warm and never needs care) |
| Negative points and penalties ("Do this / don't do that" with penalties) | S'moresUp, ChoresBot deductions (44 mentions in chores apps), Donetick #198 | P3 |
| Leaderboards, "first to complete", a sibling comparison | Skylight and Hearth rewards boards; "fair split" requests | P3 and the "no counts between people" rule of `27` |
| Location sharing (FamilyWall 29 and FamCal 10 mentions, Life360 comparisons) | planners | P2, `01` non-goals; none |
| Family chat | 148 mentions (FamilyWall 49, TimeTree 40, Howbout 27), Skylight/Hearth video messages | P8 |
| Private events; photo proof; event attachments; photo screensaver (Skylight reviews: 113 of 606) | planners | P8, `01` "no per-item privacy" |
| Gamification wears off ("lost interest in a matter of days", "isn't into dragons") | Joon, S'moresUp, Chorsee | supports P7 (look at use), not a feature. Wusel's outfits and themes should stay free and varied |
| Mood check-ins for children | not seen as a user request in this corpus | already refused in `23` |
| A mental-load meter between the two adults | surveys only (Austria 93 percent want a different split; 16 percent of Viennese mothers satisfied), not app reviews | would count one adult against the other; `27` rule 2. If anything, offer *ownership* (see below), never a score |

## 5. Mental load and the other adult

- App reviewers name the benefit as **being able to stop repeating**: "Plus besoin de me répéter", "Fini la charge mentale ... je n'ai
  plus à me rappeler de tout ce qu'on a de prévu", "Reduziert meinen Mental Load". 48 reviews across the corpus use the term (FamilyWall 11).
  The first three properties of `01` deliver this.
- The German advice literature adds an idea the specs do not have: **hand a domain over completely** instead of asking for help
  (the psychiatrist quoted by ihre-vorsorge.de; the *Fair Play* card method in leinetal24). In WuselWall terms: a recurring task with
  a `fixed` owner already exists (`06`); a visible *Zuständig für* per domain (Arzttermine der Kinder, Geschenke, Schulsachen) is not
  modelled. Evidence: **C** for the app, **B** for the topic in the press. It must show an owner, never a tally.
  Treat it as an R3.8-style candidate to decide after the pilot.

## 6. Neurodivergent families

- ADHD, autism, sensory or ODD terms appear in 156 of Joon's 590 reviews and 239 of Tiimo's 1,400 (Tiimo is for the adult user, with
  parents asking for family profiles: "a way for those profiles to be connected without being merged"; "layer other profiles' events onto my own").
- What helps, in the parents' words: the child *does not have to be asked* ("there's less demand on him and our relationship feels easier"),
  a visible sequence, a reward that is immediate, predictable rules.
- What users ask for: visual timers or "now / next", picture steps for pre-readers, a Monday-first, quiet-hours, no AI motivational chatter
  (Tiimo 2-star: "randomly notified ... about check-ins and supposedly motivational messages ... annoying").
- Match with WuselWall: the kid register (`09`) is icon-led and has "never punish". The gap is wish 1. The anti-wish (motivational pings)
  matches P10. Visual timers are an open choice: `06` lists "time estimates" as out; a *plain* countdown ring with no sound would stay
  inside P6 and P10, but belongs after the routine item, behind a household setting (P5).

## 7. Open-source competitor signals

- The field is crowded and young. A GitHub repository search finds at least 25 small self-hosted family dashboards and chore apps (creation dates not checked), most under 100
  stars (FamilyNido 72, LX Family 65, HomeBoard 46, Beacon 16: "Free open-source Skylight alternative"); the largest chores project
  is **ChoreOps** (450 stars, Home Assistant). Skylite-UX (107 stars) is an explicit Skylight clone.
- Most-reacted issues across them are about **auth and deployment** (SSO/OIDC: KitchenOwl #32 with 31 reactions, Donetick #66/#371/#438,
  Grocy #207; disable signup: Donetick #212, 18), **translation** (Donetick #251, 11) and **widgets** (Donetick #387, 14; KitchenOwl #287, 9),
  then recipe-tool integration (Yuvomi #530, 15; KitchenOwl #90, 18) and reward systems (Yuvomi #27, 5; #248).
- Operators ask for SSO and for turning off public signup. WuselWall's self-service onboarding (ADR-014) and R2 hardening touch this;
  OIDC for the *app* login is not on the roadmap (only OAuth for assistants, R3.1). Worth a line in 14 as a question for self-hosters.
- Yuvomi's #260 ("is there a public roadmap?") shows what a young open-source family project is asked first.

## 8. Language notes (DE, FR, ES)

- DE/AT/CH reviews (FamilyWall, TimeTree, Famanice): widgets ("Keine Widget Funktion ... Warum?"), iPad layout too small (TimeTree DE,
  FR), Apple Watch, Alexa/HomePod links to the to-do and shopping lists, week view too cramped, cancel/decline on shared events
  (TimeTree CH "Absage"), colours per family member (Famanice, FamilyWall 2016), a school section (Famanice: 26 of 237 reviews mention
  school, Stundenplan or homework). Cantonal Klapp documents show the consent and data-protection friction parents face with school apps.
- FR: price complaints are loudest ("dommage que trop de fonctionnalités soient payantes", "j'aurais préféré avoir accès à tout avec des pubs"),
  then widgets and the iPad layout, then charge mentale as the praise. TimeTree FR wants read-only members.
- ES: widget, private events, Apple Watch, budget balance view; very few reviews (the Spanish corpus is thin, 16 wish-style hits).
- Switzerland: Bring! CH "Ohne Coop leider nur halb brauchbar" and AT "Jö-Bonuskarte" show regional supermarket integrations are
  valued; they are third-party links and stay out (P2).

## 9. Cross-checks against the roadmap

| Roadmap item | Does the evidence support it? |
|---|---|
| R1.3 audit view ("who ticked my chore on the wall?") | Yes: Skylight and Hearth owners ask for exactly the identification WuselWall has |
| R1.6 month overview | Yes: FamCal, 2houses, TimeTree, Cozi all complain about weak month views |
| R1.8 the wall at night | Yes: the HA threads say wall panels get ignored when they shout |
| R3.4 family goal | Neutral: no demand seen; cooperative goals avoid the sibling complaints |
| R3.5 ageing bonuses, R3.6 richer rewards | Rewards: yes (Hearth, Joon, TaskMate "rewards unlock device time"). Ageing bonuses: no evidence either way |
| R3.3 recipe import | Yes: Yuvomi #530 (15), KitchenOwl #90 (18) and #83 (13), Mealie scaling #507 (21) |
| R3.8 Stammartikel, Woche wiederholen, wer holt ab? | Stammartikel and favourites: yes (Bring!). Wer holt ab: weak |
| R4.1 push relay | Keep conditional; SchoolFox shows how angry parents get when push fails |
| R4.2 one account in two households | Real market (co-parenting apps) but legal and court features dominate it; keep as a decision |
| R4.3 CalDAV | Demand exists (KitchenOwl #127, Yuvomi google-calendar issues) but sync complaints say it costs more than it returns |
| Not-on-roadmap list | Every row is consistent with what users complain about, except weather (Hearth owners ask for it, 2 mentions), which the roadmap already keeps closed |

## 10. Sources

**App Store listings used (reviews read through the public feed `https://itunes.apple.com/<cc>/rss/customerreviews/page=<n>/id=<id>/sortby=mostrecent/json`)**

- Cozi https://apps.apple.com/app/id407108860 · TimeTree https://apps.apple.com/app/id952578473 · FamilyWall https://apps.apple.com/app/id496889629 ·
  FamCal https://apps.apple.com/app/id1098999871 · Skylight https://apps.apple.com/app/id1438779037 · Hearth Companion https://apps.apple.com/app/id6498717775 ·
  Howbout https://apps.apple.com/app/id1477248221 · Famanice https://apps.apple.com/de/app/famanice/id806214101
- Chores: Joon https://apps.apple.com/app/id1482225056 · Chorsee https://apps.apple.com/app/id1611068600 · Chores & Allowance Bot https://apps.apple.com/app/id629797415 ·
  Homey https://apps.apple.com/app/id1033286805 · S'moresUp https://apps.apple.com/app/id1287367596 · Sweepy https://apps.apple.com/app/id1498897320 · Tody https://apps.apple.com/app/id595339588
- Shopping: Bring! https://apps.apple.com/app/id580669177
- Co-parenting: OurFamilyWizard https://apps.apple.com/app/id497405393 · TalkingParents https://apps.apple.com/app/id1092220726 · AppClose https://apps.apple.com/app/id1019290876 ·
  Shared https://apps.apple.com/app/id1345299534 · 2houses https://apps.apple.com/app/id632536949
- School: SchoolFox https://apps.apple.com/app/id1424962016 · Klapp https://apps.apple.com/app/id1247557480
- Routines: Tiimo https://apps.apple.com/app/id1480220328 · Structured https://apps.apple.com/app/id1499198946 · Lil Planner https://apps.apple.com/app/id6448482826
- Other: Qustodio https://apps.apple.com/app/id1501720596 · Google Family Link https://apps.apple.com/app/id1150085200 · ImpfPassDE https://apps.apple.com/app/id1472717242 ·
  STIKO-App https://apps.apple.com/app/id1527738367 · 11pets https://apps.apple.com/app/id1232470530 · KNAX https://apps.apple.com/de/app/knax-taschengeld-app/id1434656763

**GitHub issues (reaction counts read 2026-10-24)**

- Yuvomi https://github.com/ulsklyc/yuvomi/issues/530 (15), /27 (5), /260, /151, /1897, /247 · Donetick https://github.com/donetick/donetick/issues/387 (14), /251 (11), /133 (10), /66 (8), /212 (18), /608, /911, /319, /147 ·
  KitchenOwl https://github.com/TomBursch/kitchenowl/issues/32 (31), /123 (18), /90 (18), /206 (14), /293 (14), /127 (9), /117 (11), /287 (9), /10 (10) ·
  Grocy https://github.com/grocy/grocy/issues/158 (82), /404 (34), /236 (15), /644 (24) · Mealie https://github.com/mealie-recipes/mealie/issues/507 (21) ·
  Hestia https://github.com/Wikid82/Hestia/issues/33 and /35 /36 /41 /43 · Skylite-UX https://github.com/Wetzel402/Skylite-UX/issues/99 · ChoreOps https://github.com/ccpk1/ChoreOps ·
  Tribu https://github.com/itsDNNS/tribu/issues/168 · Pinn https://github.com/pinn-shost/pinn/issues/1

**Community and web**

- Home Assistant: TaskMate https://community.home-assistant.io/t/taskmate-family-chore-rewards-integration-now-in-hacs-default/1023281 ·
  wall tablets https://community.home-assistant.io/t/are-we-thinking-about-wall-tablets-the-wrong-way/1019690 ·
  LX Family https://community.home-assistant.io/t/lx-family-a-self-hosted-family-board-with-calendars-chores-kid-profiles-and-home-assistant-widgets/1020587 ·
  Chores and Rewards https://community.home-assistant.io/t/chores-and-rewards/1014299
- Skylight: GummySearch topic index https://gummysearch.com/r/skylightcalendar/ · Best Buy reviews https://www.bestbuy.com/product/skylight-calendar-15-inch-touchscreen-smart-calendar-and-chore-chart-white/J3Q5Q2C7XR/sku/6567807/reviews ·
  Trustpilot https://au.trustpilot.com/review/skylightframe.com · Twin Perspectives https://twinperspectives.co.uk/uk-mums-honest-review-of-skylight-calendar-2025/
- Hearth: Reddit mirror thread (setup trouble, 2024) https://lr.eu.psf.lt/r/HearthDisplay/comments/1b1mb4t/unable_to_set_up · Ideal House review https://ideal.house/zh-CN/community/news/review-the-hearth-display-changed-how-i-manage-my-family
- Cozi review analyses https://kimola.com/reports/explore-in-depth-user-feedback-analysis-on-cozi-family-organizer-app-store-us-148390
- Two homes: Wechselplan https://www.startbase.de/organization/wechselplan/ · Vienna VAMV brochure https://www.vamv-berlin.de/wp-content/uploads/2022/03/Wechselmodell-Broschüre-2021.pdf ·
  co-parenting apps list https://apps.apple.com/app/id1345299534 (Shared), https://apps.apple.com/app/id632536949 (2houses)
- Mental load: https://www.vienna.at/mental-load-lastet-immer-noch-vor-allem-auf-muettern/8063257 · https://www.vienna.at/mental-load-verteildung-16-prozent-der-wiener-muetter-zufrieden/8065411 ·
  https://www.familie.de/familienleben/weniger-sex-mehr-streit-studie-bestaetigt-mental-load-ist-ein-absoluter-beziehungskiller--01J3QZ7VVY37MPZKVTMYCMZTDC ·
  https://www.leinetal24.de/welt/mental-load-kann-die-fair-play-methode-muetter-entlasten-zr-93469008.html · https://www.ihre-vorsorge.de/gesundheit/nachrichten/familien-stress-5-tipps-die-muettern-und-familien-helfen ·
  https://www.stuttgarter-zeitung.de/wissen/tipps-und-tools-so-teilen-sich-eltern-familienarbeit-gleichberechtigt-auf-79025317.html
- School communication and consent: https://www.zg.ch/behoerden/gemeinden/steinhausen/schule/angebot/schulportal/dokumente/merkblatt-klapp_eltern-schule_steinhausen_2025_08_04/download ·
  https://baselland.talus.ch/de/dokumente/geschaeft/62ee561510d744afac67e3d81c114eff-332 · https://www.trendingtopics.eu/schoolfox-startup-ersetzt-mit-einer-app-das-mitteilungsheft-an-3-000-schulen/
- Pocket money: https://www.giga.de/artikel/bling-taschengeld-per-app-karte-so-funktioniert-es/ · https://www.itreseller.ch/Artikel/95607/DB4Kids_Kinder_sollen_mit_Sackgeld-App_den_Umgang_mit_Geld_erlernen.html
- Vaccination and health apps: https://apps.apple.com/de/app/vaxy-impfpass/id1229465470 · https://apps.apple.com/de/app/appzumarzt/id410324684

Working data (the mined reviews and the counting scripts) was not kept in the repository.
