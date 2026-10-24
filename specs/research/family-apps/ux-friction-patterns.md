# Reducing friction in family apps: evidence and patterns for WuselWall

Research pass of 2026-10-24. Read-only on the repo. Context skimmed: specs 01, 09, 20, ADR-020.

## How to read the evidence labels

- **A (strong):** randomised experiment or large meta-analysis, or a replicated finding.
- **B (moderate):** peer-reviewed qualitative or field study (CHI/CSCW/TOCHI/Pervasive), or Nielsen Norman Group (NN/g) guidance built on usability testing.
- **C (weak):** product behaviour, vendor claims, practitioner writing. Useful for "what the best apps do", not for "this works".

**What I could and could not verify.** I read the NN/g articles, the Skylight page, Baymard, the TimeTree guide and the Springer summary of Fitz et al. I got only abstracts or search summaries for the ACM, Springer and Psychological Bulletin papers (publisher PDFs would not parse, and the ACM site blocked fetches). Where a number comes from a secondary source it says so. Nothing here was invented, but treat paper-level details marked "abstract only" as pointers, not as quotes to build a decision on.

## What WuselWall already does (from the specs)

So the report does not recommend what exists:

- Onboarding: one door for adults, no tours, one getting-started card, zero typing on shared devices, invitation by code, QR, link and share sheet, 7-day invitations, and targets of 60 s to join and 90 s to start (spec 20).
- Principles 3 and 7: no punishment, no streaks, no mascot in notifications, no second currency for children.
- Siri adds shopping items through Shortcuts (R1.4). The wall has a quiet-hours item (R1.8). School import exists (spec 24).
- Not there, or deferred: natural-language event entry (explicitly out of scope in spec 05), widgets (spec 09 says "natural M3 candidate"), email-in, a notification digest policy (only in-app notice cards exist, "no server push"), and a stated rule for what children's points may and may not reward.

---

## 1. Why family apps get abandoned: second adopter, invitations, novelty decay

### Evidence

- **The calendar must fit existing routines, or it is not used** (LINC field trial, 4 families, 4 weeks; abstract and MSR page only). Their design findings: at-a-glance awareness from a highly visible spot, flexibility in where it sits, and access from outside the home (e.g. work). Families reported that ubiquitous access increased involvement from additional family members. [B]
  https://www.microsoft.com/en-us/research/publication/linc-in-the-home-field-trials-of-a-digital-family-calendar
  https://grouplab.cpsc.ucalgary.ca/grouplab/uploads/Publications/Publications/2007-LinkFieldTrial.GI.pdf
- **One-sided use makes the other parent dependent.** In a co-design study with 10 new-parent couples (Lin et al., 2025), some apps were used by only one parent, so the secondary caregiver had to ask the primary for updates, which reduced their independent involvement. Mothers sometimes took tasks because "it was faster to do it themselves"; fathers reported passivity and feeling pushed out. Small, Taiwanese, affluent sample. [B]
  https://arxiv.org/html/2505.22428
- **Typology of how families run a calendar:** 44 families, three types by how many people take part in calendaring (monocentric, pericentric, polycentric). Abstract only. From memory (unverified here): one person, most often the mother, usually keeps the calendar. [B]
  https://grouplab.cpsc.ucalgary.ca/grouplab/uploads/Publications/Publications/2009-CalendarCrucial.TOCHI.pdf
- **Lapsing is the normal outcome, and design keeps influencing people after they stop.** Epstein et al. (CHI 2016 short paper; 193 surveyed, 12 interviewed; six reasons for stopping, five perspectives on life after). I could not read the list of reasons. The design point is to plan for lapse and resumption, not only for retention. [B, personal-informatics, not family]
  https://pmc.ncbi.nlm.nih.gov/articles/PMC5428074/
- **General retention baselines** (secondary: Business of Apps via a blog): Android Day 1 about 21 %, Day 30 about 2.1 %; iOS 24 % and 3.7 %. Not family- or productivity-specific. Use only as "single-user apps decay fast". [C]
  https://quashbugs.com/blog/app-retention-rate-statistics
- **Partner not joining is, per practitioners, an ownership problem more than an app problem**: sharing information is not sharing responsibility; name an owner per activity. One vendor survey (93 mothers, 11 % use a shared app) is too small and biased to rely on. [C]
  https://getsense.ai/blog/posts/the-mental-load-of-family-coordination.html

### Patterns

1. The second adult's first screen must already contain things that are theirs (events they are in, items assigned to them, tonight's dinner), not an empty household. Spec 20 does the first half; make "assigned to you" the join landing.
2. Keep the invitation's context across the app-store install (deferred deep link or a code that survives install). Vendor claim of +20-40 % day-0 conversion is unproven [C]; the mechanism (context lost at install, user lands on a generic home) is well described. https://appsflyer.com/glossary/deferred-deep-linking
3. Do not put an account wall in front of the first value. Baymard's checkout analogue: 84 % of benchmarked sites do not delay account creation, and forced account creation is a listed abandonment cause; recommended fix is to ask after the value is delivered. [B, different domain] https://baymard.com/blog/checkout-flow-average-form-fields
4. Give a lapsed user a no-guilt re-entry: the app is current after three weeks away (calendar synced, recurring chores rolled forward) and says nothing about the gap.
5. Let the anchor habit be the wall, not the phone: LINC's lesson is that the calendar lives where people already look.

### Anti-patterns

- Primary-user dashboards the partner cannot edit; partner accounts that need a separate onboarding (e.g. needing a Microsoft account just to join a to-do list [C]).
- Streaks and "come back" nudges (already excluded by principle 7).

---

## 2. Capture friction

### What the best apps do

| App | Capture routes (as documented) | Strength |
|---|---|---|
| Todoist | Quick Add parses date, project, label, priority from one line; widgets and share extensions | C (product behaviour; MacStories review). https://www.macstories.net/reviews/todoist-10-brings-intelligent-input-themes-and-new-gestures/ |
| Skylight | "Sidekick Magic Import": forward email, PDF, screenshot or photo of a flyer to the device's address; add the device's address as an attendee on any event; photo scan for events and lists; sync of Google, Apple, Outlook, Yahoo, Cozi; touchscreen add on the device. Import needs the paid Plus tier. Reviewers report mixed email results | C. https://myskylight.com/calendar |
| Cozi | Free: shared lists with live sync, agenda emails. Paid Max: AI event import from email. Calendar sync is read-only from Google/Outlook | C |
| TimeTree | Invitation link valid 7 days; invitee installs, registers, taps the link, taps "Join this calendar"; events have chat; memos for undated events; anyone with edit rights can add | C. https://timetreeapp.com/intl/en/tutorial |
| Bring!, AnyList | Recipe import via the browser share function; ingredients to list in one tap; Siri/Shortcuts and Alexa/Google voice | C. https://help.anylist.com/articles/recipe-extension |
| Things | Quick Entry, but no natural-language parser | C |

### Evidence on speed

- Response time limits (0.1 s feels instant, 1 s keeps the flow of thought, 10 s loses attention). If "kitchen roll" is to be added in 3 seconds, the add must show immediately (optimistic UI) and never wait on a round trip. [B] https://www.nngroup.com/articles/response-times-3-important-limits/
- Voice at home is socially embedded in conversation (Porcheron et al., CHI 2018, month-long Echo deployments; abstract only). That favours "say it to the room" capture for shopping and timers over screen-based capture, but young children's speech is recognised poorly (Hiniker's 3-5 year-old study, reported by Quartz; Lovato and Piper's review notes voice fits the pre-reader age band but is under-researched). [B/C]
  https://nottingham-repository.worktribe.com/output/927340/voice-interfaces-in-everyday-life
  https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6349721/
- There is no controlled study I found comparing capture routes in family apps. Everything in this section beyond response times is **C**.

### Patterns

1. **Capture from where the thing arrives**: share sheet (recipe URL becomes ingredients on the list; text or link becomes an event draft), forward-to-address, photo of the school letter. Always show a review step ("3 events found") before saving, because reviewers report mixed accuracy.
2. **Draft, don't ask**: a quick-add that parses "Zahnarzt Do 15 Uhr Olivia" into a pre-filled event chip the user can accept with one tap beats a form. Smart defaults (current person, usual time, next free evening) remove fields rather than adding AI.
3. **Lock-screen and widget entry** for the two highest-frequency items (shopping item, "I'll do it"). Spec 09 defers widgets to M3; this is the highest-frequency surface in the vision's own words ("three seconds at the cupboard").
4. **One address, many sources**: a single per-household inbox address covers school emails, club schedules and booking confirmations.

### Anti-patterns

- A capture flow that interrupts with a mascot, a tip or a confirmation (ADR-020 already bans this).
- Paywalling the import features that make the first week work (Skylight's Plus) if first-week value matters.
- One-way calendar sync presented as sync (Cozi complaint pattern).

---

## 3. Shared and ambient displays

### Evidence

- **LINC** (Neustaedter and Brush, CHI/CSCW 2006; GI 2007 field trial). Participatory design of an inkable kitchen calendar. Field trial lessons (abstract level): fit existing routines; glanceable and highly visible; flexible placement; reachable from outside the home. [B]
  https://www.microsoft.com/en-us/research/publication/linc-in-the-home-field-trials-of-a-digital-family-calendar
- **Fridge surfaces** (Swan and Taylor, CHI 2005 LBR; ethnography of 12 UK households, plus the Graesch figure of 52 items on an average fridge from a press piece): the fridge is a shared, always-available surface in the kitchen; use and arrangement depend on material properties, magnets give fluidity and reconfigurability, and families negotiate relations through it. Design cue: the display must be reconfigurable by ordinary people and sit in the walk-past space. [B]
  https://course.ccs.neu.edu/csg170/ssl/swan05.pdf (PDF; abstract confirmed via search)
- **Domestic routines** (Crabtree and Rodden, CSCW journal 2004): routines are coordinated through visible artefacts; shared orientation to the calendar was essential for explicit negotiation about scheduling. [B] https://people.cs.nott.ac.uk/pszaxc/work/JCSCWv13.pdf
- **Display blindness** (Müller et al., Pervasive 2009; 91 interviews at 11 public displays): people skip displays they expect to show uninteresting content, like banner blindness. A display that earns a reputation for being useful gets looked at. [B]
  https://www.dfki.de/web/forschung/projekte-publikationen/publikation/4186
- **Ambient display heuristics** (Mankoff et al., CHI 2003): adapted heuristics found more and more severe problems than Nielsen's general set. Later in-home work found the most severe problem was missed by heuristic evaluation, so test in a real kitchen. [B] https://www.doi.org/10.1145/642611.642642
- **Commercial signal**: Skylight sells on "schedule in a common place, no app needed", per-person colour, kids checking off chores on the device, weather per event, countdowns. Constant power and Wi-Fi required. Ratings (4.5-4.7 from thousands of reviews) are retailer-reported. Complaints: slow touch, paywalled extras. [C]

### Patterns

- The wall earns its glance by answering the questions people actually ask ("who is where, what is for dinner") with content that changes through the day. This supports WuselWall's "Wer ist wo" row and week board.
- Content that is the same all day, or decorative, trains people to ignore the screen. Keep motion for state changes (a chore done, a new event), not for ambience.
- Ambient mode must be dim or off at night (R1.8) or it is switched off by hand and then never looked at.
- Tap-to-act on a small set, with auto-revert (the kiosk register already does this), because a wall that needs a login to do anything is read but not used.
- Remote access: the same data must be one tap away on the phone (the LINC finding).

### Anti-patterns

- Ads, tips or mascot chatter in the glance zone.
- Small type, dense grids (reading distance of 2 m).
- Requiring touch precision on a wall panel.

---

## 4. Kids: pre-readers, early readers, rewards, visual schedules

### Evidence

- **Age bands and motor skill (NN/g)**: 3-5 pre-readers, 6-8 beginner readers, 9-12 moderately skilled; tapping and swiping on large targets works for all ages; dragging is easy on touchscreens for young children; precise drag/scroll/click on small objects is hard under 9. Recommendation: targets at least 2 cm x 2 cm for under-9s on touch (four times the 1 cm adult figure); offer several gestures for the same task; avoid unforgiving precision; reduce navigation; under 8, avoid simultaneous controls. [B]
  https://www.nngroup.com/articles/children-ux-physical-development/
- **Overjustification, the reward literature.**
  - Deci, Koestner and Ryan 1999 (Psychological Bulletin; 128 experiments): tangible rewards, especially expected and task-contingent ones, undermine intrinsic motivation; verbal praise tends to enhance it. A secondary source gives d about -0.40 for expected tangible rewards and +0.31 for verbal praise (unverified). Cameron and Pierce dispute the size and generality. [A, contested] https://journals.sagepub.com/doi/10.3102/00346543071001001
  - Lepper, Greene and Nisbett 1973: preschoolers promised a certificate for drawing later drew less in free play; the effect appeared only for children who already liked drawing, and the designers predicted unexpected rewards would not undermine (the outcome of that arm was not confirmed in what I read). [B]
  - Warneken and Tomasello 2008 (Developmental Psychology): 20-month-olds who were given a tangible reward for helping helped less afterwards than those given praise or nothing. [B, small]
  - Cerasoli et al. 2014 (k = 183, N = 212,468): intrinsic motivation and incentives are not simply opposed; incentives predicted quantity, intrinsic motivation predicted quality, and the effect depends on how directly the incentive is tied to performance. [A]
  - Deci et al. 1994: for uninteresting tasks, a meaningful rationale, acknowledgement of feelings and a sense of choice promote internalisation. [B]
- **Visual schedules**: a meta-style review (Knight, Sartini and Spriggs 2015: 31 studies, 16 acceptable) supports visual activity schedules as an evidence-based practice for autistic individuals. I found no controlled study for typically developing pre-readers; claims about independence and smoother transitions for them are practitioner guidance. [A for ASD, C otherwise]
  https://cbmt.franciscan.edu/wp-content/uploads/sites/32/2021/07/Knight-et-al.-2015_Visual-Schedules.pdf
- **Mascots**: ADR-020 already summarises the Clippy/Duolingo evidence.

### Patterns

1. Icon first, one gesture, big targets: tap to complete, with a drag alternative; no precision gestures (Jack, 7, is in the band where this is not yet reliable).
2. Use points where the task is a chore (uninteresting): the overjustification effect is documented for activities children already enjoy. Do not attach points to what they love (drawing, reading, helping cook) or to spontaneous helping.
3. Put the reward conversation in words: "thanks for doing X, it made tonight easier" (informational). Wusel's cheer on completion is unexpected and non-contingent, which is the safe quadrant; keep it unannounced.
4. Offer a rationale and a choice: let the child pick which of three chores today, and show why it matters for the family (the 1994 internalisation conditions). Cheap to build as "pick one".
5. A now-and-next view for the youngest child (the day's three pictures), built on the Stundenplan icons, is low risk; do not claim measured benefit.
6. Voice should be optional for small children (recognition is poor for ages 3-5).

### Anti-patterns

- Announcing a reward before the activity ("do this for 10 points") for tasks the child already likes.
- Leaderboards between siblings, public failure, loss of points (principle 3 already excludes).
- Small or two-handed controls for under-8s.

---

## 5. Notifications

### Evidence

- **Batching RCT** (Fitz et al., 2019, Computers in Human Behavior; n = 237 per the abstract, four conditions, two weeks): notifications delivered in three fixed daily batches (9:00, 15:00, 21:00) made people happier, more productive, less stressed and more attentive than the control; hourly batches showed little benefit; switching notifications off gave no benefit and raised anxiety (fear of missing out). The benefit seems to come from predictability. Self-reported outcomes; participants were in India. [A]
  https://communities.springernature.com/posts/batching-notifications-can-improve-attention-well-being-and-productivity
- **NN/g on push notifications**: average 56 notifications per day (2016, Telefonica); combine bursts of more than five; notify only about things that concern the recipient; most users never change settings, so defaults must already be sensible; do not ask for permission at first launch, ask after the user has seen value and explain what will be sent; settings reachable inside the app. [B] https://www.nngroup.com/articles/push-notification/
- **The proxy for nagging**: a CSCW 2020 study of children's activity trackers found the prompts reduced friction because they came from the device, one parent calling it far better than repeated reminders; a 2026 arXiv robot-reminder study found children more receptive to a calm non-parent source ("not nagging parent mode"). Small, parent-reported. [B/C]
  https://depstein.net/assets/pubs/ioygur_cscw20.pdf (title and abstract confirmed via search, body unreadable)
  https://arxiv.org/pdf/2602.22628
- Vendors claim chore apps reduce nagging; no controlled trial found. [C]

### Patterns

- For adults: at most one morning digest and one evening digest by default, optional immediate alerts only for changes that affect me in the next few hours (a changed pickup time, an invitation). The digest also answers "Was kommt morgen?" without a question.
- For children: the reminder is the wall and the child's own screen ("two things left"), not a push from the parent's account. Reminder wording is neutral and from the system, never from Wusel (principle 7) and never "Papa says".
- Never notify someone about a thing that does not involve them (NN/g).
- Ask for push permission after the first completed action, with a sentence of what will come.

### Anti-patterns

- Hourly or per-event push; badge counts that never clear; notifications that expose a sibling's missed chore.
- Silencing everything by default (anxiety effect in Fitz et al.).

---

## 6. Onboarding: time to value, progressive setup, empty states, templates, imports

### Evidence

- **NN/g mobile onboarding**: avoid onboarding wherever possible; tutorial cards did not improve task performance; show tips in context; request only what is needed to start and say why; allow skip; keep visual customisation (colours) out of onboarding; interactive walkthroughs only for complex or novel flows. [B] https://www.nngroup.com/articles/mobile-app-onboarding/ (This matches spec 20's "no tours".)
- **NN/g empty states**: three jobs: communicate system status, give a learning cue, give a direct path to the key task. [B] https://www.nngroup.com/articles/empty-state-interface-design/
- **NN/g progressive disclosure**: defer rare features to a secondary level, keep to two levels. [B] https://www.nngroup.com/articles/progressive-disclosure/ (matches the Basic/Advanced settings view already in spec 09).
- **Endowed progress** (Nunes and Drèze 2006, Journal of Consumer Research): car-wash loyalty cards with 2 of 10 stamps pre-filled were redeemed by 34 % versus 19 % for an 8-stamp empty card (secondary reports of the same figures; original not opened). A getting-started card that opens already part-complete ("Familie angelegt, du bist drin") borrows this. [A/B, one field experiment]
  https://coglode.com/nuggets/endowed-progress-effect
- **Form-field count** (Baymard): complexity, not step count, predicts checkout trouble; most sites need about 8 fields; 17 % abandoned a checkout because of complexity. Analogue for household setup: infer, defer, minimise (spec 20 already follows). [B] https://baymard.com/blog/checkout-flow-average-form-fields
- Import of existing calendars is a first-week requirement in the products: Skylight syncs six services and any public link, Cozi syncs read-only. [C]

### Patterns

1. Sample data that is clearly sample and one tap to clear, so the first Today screen shows what "full" looks like (spec 20 rule 4 already lands on examples).
2. Subscribe to an existing calendar by link or device calendar during setup, shown as a result ("14 Termine gefunden") rather than as a settings screen.
3. Templates for the three things families set up first: a usual week, a starter set of chores by age, a rota. Offer them on the empty states that need them, not in a wizard.
4. Ask for push permission and the guardian PIN at the moment they become necessary (already planned).

### Anti-patterns

- Carousel tours, mandatory profile photos, colour pickers before value, long checklists.

---

## 7. Multi-person coordination: assignment, claiming, visibility, mental load

### Evidence

- **Mental load has four parts** (Daminger 2019, American Sociological Review; 70 interviews, 35 couples): anticipating needs, identifying options, deciding, monitoring. Women did more of the anticipating and monitoring; decision-making was roughly equal in the published article. The work is invisible to both partners and a common source of conflict. [B, strong qualitative]
  https://inequality.hks.harvard.edu/publications/cognitive-dimension-household-labor
- **Visible contributions help but cut both ways** (Lin et al. 2025): parents wanted task assignment with deadlines and the ability to swap and negotiate; "done lists" to recognise contributions; but making contributions visible can expose imbalance and automated appreciation can feel insincere. [B, small]
  https://arxiv.org/html/2505.22428
- **Visible logged work reduced disputes** in a one-week study with 11 families using a task-splitting tool for children's learning; the authors warn that tallying only one kind of activity can skew perceptions of contribution and reinforce gender norms, and suggest showing collective effort next to individual effort. [B/C, small]
  https://arxiv.org/html/2510.20123v1
- **Practitioner view**: a tool cannot decide who notices, enters and acts; name an owner per activity. [C]

### Patterns

1. **An owner per recurring thing, not only per instance.** "Who owns the weekly meal plan / the school-bag Sunday check / the vet?" makes the anticipate-and-monitor work something the system can show, instead of a head-space only one adult carries. The open task type (`whoever completes it claims it`) already covers the execution half.
2. **One-tap claiming** on the wall and phone ("Ich mach das"), and a visible state for unclaimed things that is calm (no red).
3. **Collective summaries first**: the Sunday look-back shows what the family did together, with the per-person split one level down and opt-in for guardians. This honours Lin et al.'s warning about exposed imbalance while still making invisible work visible.
4. **Credit for planning, not only doing**: let a guardian who set up the week or the rota show up in the look-back as "planned the week".
5. **Edit rights for everyone adult** so one person is not the gatekeeper (maternal gatekeeping appears in Lin et al. as a barrier).

### Anti-patterns

- Assignment by one parent to the other as a default (feels like manager and report; some vendors market self-assignment against that, a C-level claim).
- A per-person completion scoreboard for adults.
- Blame wording on missed tasks ("overdue" in red for a child; principle 3).

---

## Ranked list: 10 highest-leverage friction reducers

| # | Change | Why (key evidence) | Strength | Effort for WuselWall |
|---|---|---|---|---|
| 1 | Make the second adult's first screen theirs: land on "assigned to you / your events", keep invitation context through install, no account wall before value | Lin et al.: one-sided apps make the other parent dependent; LINC: remote access raised involvement; Baymard on account walls | B | Low-medium |
| 2 | Capture surfaces outside the app: lock-screen/widget quick add for shopping and "I'll do it", share sheet for recipe URL and text | Spec 01's own 3-second rule; product practice (Bring!, AnyList, Todoist) | C (plus NN/g response limits, B) | Medium (widgets are M3 in spec 09) |
| 3 | Forward-and-photo import with a review step, via one household inbox address | Skylight Magic Import, Cozi Max; mixed email accuracy reported, so keep review | C | Medium (spec 24 already has the parser) |
| 4 | Natural-language event quick-add producing a pre-filled chip | Todoist model; removes form fields | C | Medium |
| 5 | Notification policy: two fixed digests by default, immediate only for changes that touch me, permission asked after first value | Fitz et al. RCT (3 fixed batches helped; silence raised anxiety); NN/g push guidance | A/B | Low (policy), medium (digest build) |
| 6 | Keep the wall useful, changing and dark at night; no decoration in the glance zone | LINC, Müller et al. display blindness, Swan and Taylor | B | Low (R1.8 plus content rules) |
| 7 | Kids: icon-first, big targets (at least 2 cm), several gestures, no precision; voice optional | NN/g children's motor study | B | Low |
| 8 | Reward rules: points only for uninteresting chores, no points for spontaneous help or loved activities, verbal/informational praise, unexpected cheers, let kids choose | Deci et al. 1999 (contested), Warneken and Tomasello, Lepper et al., Cerasoli et al. | A (contested)/B | Low (rules) |
| 9 | Ownership of recurring decisions plus one-tap claiming; collective summaries first | Daminger 2019; Lin et al. 2025 | B | Medium |
| 10 | Getting-started card starts part-complete; empty states do the three jobs; samples one tap to clear; design the return after a lapse | Nunes and Drèze; NN/g; Epstein et al. | B (Nunes and Drèze: one field experiment) | Low |

Items 1, 5 and 8 are the cheapest per unit of evidence. Items 2 and 6 are the ones that most directly serve the vision's own capture and glance properties.

## Gaps and caveats

- No study I found compares capture routes in family apps; section 2 is product practice.
- No controlled evidence on partner-adoption interventions; the claim here rests on qualitative HCI and on the mechanism.
- Visual schedules: strong evidence only for autistic children; for typical pre-readers it is plausible guidance.
- Several papers were abstract-only (listed above). The effect sizes quoted for Deci et al. come from a secondary source.
- Retention figures are cross-category benchmarks.
- Search returned many vendor blogs; they are labelled C and not used to support a ranking.

## Source list

- https://www.microsoft.com/en-us/research/publication/linc-in-the-home-field-trials-of-a-digital-family-calendar
- https://grouplab.cpsc.ucalgary.ca/grouplab/uploads/Publications/Publications/2009-CalendarCrucial.TOCHI.pdf
- https://people.cs.nott.ac.uk/pszaxc/work/JCSCWv13.pdf
- https://course.ccs.neu.edu/csg170/ssl/swan05.pdf
- https://www.dfki.de/web/forschung/projekte-publikationen/publikation/4186
- https://www.doi.org/10.1145/642611.642642
- https://arxiv.org/html/2505.22428
- https://arxiv.org/html/2510.20123v1
- https://inequality.hks.harvard.edu/publications/cognitive-dimension-household-labor
- https://journals.sagepub.com/doi/10.3102/00346543071001001
- https://www.nngroup.com/articles/children-ux-physical-development/
- https://www.nngroup.com/articles/mobile-app-onboarding/
- https://www.nngroup.com/articles/empty-state-interface-design/
- https://www.nngroup.com/articles/progressive-disclosure/
- https://www.nngroup.com/articles/push-notification/
- https://www.nngroup.com/articles/response-times-3-important-limits/
- https://communities.springernature.com/posts/batching-notifications-can-improve-attention-well-being-and-productivity
- https://baymard.com/blog/checkout-flow-average-form-fields
- https://myskylight.com/calendar
- https://timetreeapp.com/intl/en/tutorial
- https://help.anylist.com/articles/recipe-extension
- https://pmc.ncbi.nlm.nih.gov/articles/PMC5428074/
- https://cbmt.franciscan.edu/wp-content/uploads/sites/32/2021/07/Knight-et-al.-2015_Visual-Schedules.pdf
- https://coglode.com/nuggets/endowed-progress-effect
