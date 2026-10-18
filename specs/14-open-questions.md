# 14 — Open Questions

Decisions deliberately deferred. Each has a point by which it must be answered, so that
none of them quietly becomes a blocker. Anything that surfaces during implementation
lands here rather than in the module being built.

**Since 2026-10-11, a question whose answer differs between households is a setting.**
What stays open here is only the *curated default*; each household sets its own value in
Einstellungen ([21 — Household settings](21-household-settings.md)). All proposed defaults
are collected for review in [#10](https://github.com/wuselwall/wuselwall-app/issues/10). Facts about the reference household (its
schools, its rota, where its display hangs) are setup data, not product decisions.

## Before M0

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q1 | Which domain? | Needed for TLS, feed URLs, the OAuth issuer and the PWA scope. Changing it later invalidates every subscribed ICS feed. | **Decided 2026-08-30: own `.de` domain** (not a free dyndns subdomain), with `home.` and `mcp.` subdomains. Use a wildcard cert (DNS-01) so subdomains don't appear individually in CT logs. Pick the actual domain name next. **Superseded 2026-10-13 ([ADR-017](adr/ADR-017-wuselwall-app-domain.md)): `wuselwall.app`** for the project's website, docs and links site. Since [ADR-018](adr/ADR-018-self-hosted-only.md) each server lives on its operator's own domain. |
| Q2 | SvelteKit or Next.js? | [ADR-003](adr/ADR-003-technology-stack.md) recommends SvelteKit; you may prefer the larger ecosystem | ~~Decided 2026-08-30: SvelteKit.~~ **Superseded 2026-10-11: Flutter clients on self-hosted Supabase** ([ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md)). |
| Q3 | GitHub or a self-hosted forge? | Determines the CI and registry path | **Decided 2026-08-30: GitHub.** GHCR is no longer needed — Supabase's images are pulled from upstream and nothing is built into an image ([16](16-setup-plan.md)). |
| Q35 | Is a Mac available — own, borrowed, or a second-hand Mac mini? | Without one, iOS builds exist only in CI: no simulator, no Xcode debugger, iOS-only bugs diagnosed from TestFlight crash reports ([ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md)) | *Added 2026-10-11.* Start without; buy or borrow one if the first iOS-specific bug costs more than an evening. *Resolved 2026-10-11:* a MacBook Pro is available — iOS Simulator, Xcode and local iOS builds ([18](18-testing-strategy.md)) |
| Q36 | Accept the higher running cost? | The Apple Developer Program (€99/year) and an 8 GB server for Supabase put the total at ≈ €18–21/month, against the original ≤ €10 target (NFR-7) | *Added 2026-10-11.* Accept: the €99 is the price of native apps on iOS at all, and a 4 GB server would make Supabase the thing that stalls. NFR-7 is revised as *proposed* until confirmed **Resolved 2026-10-11 by [ADR-013](adr/ADR-013-self-hosted-compose-stack.md):** a server at home instead of a rented one, so the total is ≈ €8–12/month and NFR-7's €10 target roughly holds. |
| Q37 | Can the children's Apple accounts be TestFlight testers? | Child accounts under Family Sharing may not be addable as App Store Connect users or may not be allowed to run TestFlight | *Added 2026-10-11.* Try it with one iPad as soon as the developer account is active (M0.4). If it fails: Ad Hoc builds to the iPads' registered UDIDs, installed from a web page. *Since Q42 the public App Store listing is the route for a family's iPads; the question remains for TestFlight builds only* |

## Before M1.0 (onboarding)

*Added 2026-10-11 with [ADR-014](adr/ADR-014-self-service-onboarding.md).*

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q41 | Which SMTP provider sends the sign-in codes? | Email codes do not work without one (Mailpit only catches mail on the home network; hosted Supabase's built-in mail is for testing, not production); the provider sees addresses and codes (NFR-9), and deliverability decides whether people get in at all | **Decided 2026-10-11: Scaleway Transactional Email** (Paris, EU company; 300 mails/month free, then €0.25 per 1,000; transactional only, no "sent with" footer; SMTP and an HTTP API). One project per server with its own credentials, sending from a subdomain with SPF, DKIM and DMARC; other operators bring their own provider. Setup in [10](10-deployment-and-ops.md#4-sign-in-and-mail). Brevo's free plan was the runner-up but stamps its branding on mails; Postmark has the best deliverability but is a US company |
| Q43 | One household per account — what about separated parents, or a grandparent in two families? | `profile.auth_user_id` is unique, so an adult can be in one household. Patchwork families are common, and a child living in two homes is the hardest case | One household per account in v1; the data model does not prevent a later household switcher (a second linked profile per account, the household chosen per session). Revisit when a real family asks, not before |

## Before opening to other households

*The gate in [13](13-roadmap.md#opening-to-other-households).*

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q40 | Where does the one project with everyone's households run? | ADR-014 puts all households in one project, and the app has one backend URL | **Decided 2026-10-11 ([ADR-015](adr/ADR-015-saas-and-self-hosted-flavours.md)): two flavours.** *WuselWall Cloud*, a hosted Supabase project in the user's own account (Frankfurt, Pro plan), is the store app's default and holds every self-service household. *Self-hosted* stacks are reached by the same app through "Eigener Server". Whether Cloud is ever charged for is left open **Superseded 2026-10-13 by [ADR-018](adr/ADR-018-self-hosted-only.md): self-hosted only.** No Cloud; the store app has no default server, and every household lives on a server its own operator runs |
| Q42 | How do strangers install the app? | Internal testing reaches only App Store Connect users and listed Play testers | **Decided 2026-10-11: public App Store and Google Play listings** once the developer accounts exist ([ADR-015](adr/ADR-015-saas-and-self-hosted-flavours.md)); TestFlight and the Play internal track stay as pre-release channels |
| Q44 | Captcha on sign-up? | Supabase Auth supports hCaptcha and Turnstile; both are third parties in the sign-up path and awkward in native apps | **Decided 2026-10-11: no captcha.** Rate limits, `code` mode until the gate and the empty-account clean-up carry abuse control |
| Q45 | Which domain do other families see? | Invitation links, universal links, App Links, the passkey relying-party ID and Cloud's custom domain are bound to it; changing it later breaks every passkey and every outstanding link | **Decided 2026-10-13: `wuselwall.app`** ([ADR-017](adr/ADR-017-wuselwall-app-domain.md)). Website, docs and links site on the apex; passkey RP ID `wuselwall.app`. |
| Q46 | *(Withdrawn 2026-10-14: a question about one operator's own server, answered outside the repository.)* | | |
| Q47 | How do self-hosted servers send push notifications to the store app? | APNs and FCM accept pushes only from holders of the app's credentials, which are the project's ([ADR-018](adr/ADR-018-self-hosted-only.md), decision 10). Without an answer, push (M1.6) works on first-party servers only | *Added 2026-10-13.* Lean: **local notifications first.** The app schedules reminders it already knows about (events, due chores, the shopping list for a planned trip), and no server is involved. Live changes arrive through Realtime while the app runs. A stateless relay run by the project (device token plus an end-to-end-encrypted payload, no household data, as Nextcloud and Home Assistant do) only if families miss pushes in practice. It would be the one service the project runs for others. Decide before M1.6  **Built 2026-10-15:** local reminders on personal phones only (morning summary, event reminders), nothing sent anywhere. The relay is not built; reopen it only if families miss pushes in practice. |
| Q48 | How does sign-up work on a server without SMTP? | E1→E2 (code first, password after) needs mail ([20](20-onboarding.md#with-email)). A family's NAS often has no mail set up | *Added 2026-10-13.* Sign-up with email and password and an unconfirmed address (`mailer_autoconfirm`), offered only when the discovery document says there is no mail. Founder codes and invitations keep strangers out. A forgotten password is reset by a guardian on a personal device (a new one-time code shown on screen), not by mail. **Decided 2026-10-16, to build in [16, step 10.4](16-setup-plan.md#step-10--journey-gaps-before-launch-m15):** the kit is built and installs with autoconfirm off, so without SMTP nobody can sign up today. Autoconfirm only without SMTP, `sign_in.email_code` in the discovery document, and no automatic invitation match by email on such servers, because an autoconfirmed address proves nothing |
| Q49 | What replaces ML Kit in the Android QR scanner? | `mobile_scanner` uses Google's ML Kit on Android, which reports device, app and performance data with an installation ID to Google (NFR-9, [11](11-security-and-privacy.md)). iOS uses Apple's Vision and is fine | **Built 2026-10-14:** the `camera` plugin (BSD-3-Clause; on Android CameraX, Apache-2.0) plus `zxing2` (BSD-3-Clause, a Dart port of ZXing), both decoding on the device with no telemetry. `mobile_scanner` and ML Kit are gone from the app, and the privacy policy no longer names ML Kit. The native build is verified by CI only |

*Built 2026-10-14 (local notifications first):* the app now schedules the reminders it can compute itself, with no server and no third party: the morning summary and event reminders (`notify.morning_summary`, `notify.event_reminder`) for the acting member on a personal device, planned seven days ahead from the calendar and open chores the app already loads, and replaced on every change. Android and iOS only, through `flutter_local_notifications` with `timezone` and `flutter_timezone`; nothing is sent anywhere. Nothing is scheduled until the OS permission is granted, which the app asks for only after a tap on *Erinnerungen einschalten*. Pushes that need a server event (`notify.task_verified`, `notify.redemption_request`) are not built: guardians see pending approvals as a notice on Today instead ([16, step 10.5](16-setup-plan.md#step-10--journey-gaps-before-launch-m15)), and the relay waits until real use shows it is missed.

## Before M1.2 (tasks)

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q39 | Which design direction — A Küchentisch, B Pausenhof or C Fjord? | Sets the theme tokens before the first real screens (M1.2) are built; changing later is cheap in code but means re-reviewing every screen **Decided 2026-10-11: A "Küchentisch"**, in every register ([17](17-design-system.md)). B's outlines for the kid register remain the fallback if the children find it too plain |
| Q4 | What is a point actually worth? | The exchange rate sets the entire economy's feel. Too generous and rewards are meaningless; too stingy and the children disengage in week two. | *Since 2026-10-11 a setting* (`tasks.points.*`); open is the default. Proposed: duty 1 (0–3), bonus 5, starter rewards 5 / 15 / 50. Expect to recalibrate once. → [#6](https://github.com/wuselwall/wuselwall-app/issues/6) |
| Q5 | Which chores are duties and which are bonuses? | The intrinsic-motivation argument in [06](06-module-tasks.md) hinges on this line | *Since 2026-10-11:* the default kind is `duty` (a setting), and the starter chores carry a proposed kind each. Each household sorts its own chores with the children present — participation in the rules is most of the buy-in. → [#7](https://github.com/wuselwall/wuselwall-app/issues/7) |
| Q6 | Do points convert to pocket money? | Changes the psychology significantly and is very hard to walk back | Not in v1, as a design rule rather than a setting; no money items in the starter rewards. → [#8](https://github.com/wuselwall/wuselwall-app/issues/8) |
| Q7 | How many joker days per month? | Anti-frustration tuning for younger children | *Since 2026-10-11 a setting* (`tasks.jokers_per_month`, overridable per member). Proposed: 1 per streak per calendar month, used automatically. → [#9](https://github.com/wuselwall/wuselwall-app/issues/9) |

## Before M1.3 (calendar, presence and Stundenplan)

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q8 | Do the children get calendar write access? | Affects the kid register and the permission matrix | **Decided 2026-10-11: yes, for events they attend themselves**; deleting another member's event stays a guardian action. A household setting (`calendar.members_edit_own_events`), default on |
| Q9 | Should chore due dates appear in the ICS feed? | An Outlook calendar full of "empty the dishwasher" is unhelpful at work | **Decided 2026-10-11: no by default**; a per-token filter option, off for every new token |
| Q10 | Which external calendars should the M2 import handle first? | Determines how much the import feature actually needs to handle | Sports club and bin collection (plain ICS URLs). Ferien come from the regional feed ([15](15-module-school-timetable.md#holidays)); the timetable itself is not an import |

*Q18–Q24 were added 2026-08-30 with the A5 requirement. Most are answerable in one
conversation with the family — and that conversation is worth having before the grid
editor is built, not after.*

| Q18 | Which regions does the product support, and how is a school's region chosen? | The Ferien import is per region, and bell times differ per school | *Answered 2026-10-14:* regions are subdivisions of the public OpenHolidays dataset (openholidaysapi.org, ODbL 1.0): Germany, Austria, Switzerland (Kanton, Bezirk, Gemeinde) and Liechtenstein, to any depth the data has. `household.region` is asked with the first school and proposed for every further one; each school has its own `region_code`. Public holidays (Feiertage) apply automatically from the region; school holidays (Ferien) are imported with a preview and stay editable, because Swiss school holidays differ by Gemeinde and the import never guesses one. The server fetches the data, weekly and on demand; the apps never contact OpenHolidays ([15](15-module-school-timetable.md#holidays)). The reference household is in Berlin (one child in Klasse 5, one in the Schulanfangsphase) — that is setup data |
| Q19 | Do schools use A/B weeks (Doppelwochen)? | If not, a whole layer of UI never has to be drawn | *Resolved 2026-10-11 by generalisation:* A/B weeks stay in v1 and are switched on per timetable; a new timetable is `weekly`, so households without them never see the concept |
| Q20 | Does either school publish a timetable or substitution feed (WebUntis, IServ, Schulmanager)? | Decides whether manual entry is a stopgap or the permanent answer | Assume manual for v1 either way — an import is an M3 addition, not a v1 dependency |
| Q21 | How does a shift rota typically arrive — paper, PDF, an employer app? And how far ahead? | Decides whether the `rdates` month grid is sufficient or whether it needs a bulk-paste path | Month grid first (the reference household's rota arrives monthly). Revisit only if entering a month takes more than a minute |
| Q22 | Is Hort/Betreuung a timetable row or a presence entry? | Affects both the grid editor and the "isst mit" defaulting | **Decided 2026-10-11: a timetable row with `kind='care'`** — it is part of the child's school day and the parent reads it there |
| Q23 | Who maintains the Stundenplan, and may the children enter an Entfall? | Guardian-only is simpler; a nine-year-old reporting "Mathe fällt aus" is also genuinely useful | **Decided 2026-10-11: guardian-only in v1.** Kept as a household setting (`school.members_report_changes`, default off) so it can be opened per household later |
| Q24 | Does the timetable go into the ICS feed at all, and collapsed or per lesson? | An Outlook calendar with sixty lessons a week is an unsubscribed calendar | **Decided 2026-10-11: off for every new token**; the collapsed school-day block is one checkbox per token, per-lesson available but never default |

## Before M1.6 (launch)

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q11 | Which wall-display hardware does the product recommend? | Constrains the kiosk register and needs lead time to order | Cheap Android tablet (≥ 1280×800, landscape) running the native app in kiosk mode; Fully Kiosk with the web build only as a fallback — see [09](09-clients-and-ux.md#the-wall-display). *Revised 2026-10-11* |
| Q12 | Where does the display go? | Needs power and a viewing angle from where people stand | *Not a product decision (2026-10-11):* guidance for every household in the user documentation — kitchen, adult eye level, children's columns reachable |
| Q13 | Which notifications are on by default? | Over-notifying in week one trains the family to ignore the app permanently | *A member setting since 2026-10-11.* Proposed: morning summary at 07:00 only; everything else opt-in — see [#10](https://github.com/wuselwall/wuselwall-app/issues/10) |
| Q14 | Backup target: Backblaze B2 or Hetzner Storage Box? | Cost versus keeping everything in Germany | B2 is cheaper; the Storage Box keeps data in-country. Both encrypted client-side, so either is defensible. *Since ADR-013:* the dumps land on the server first; the off-site copy via restic goes to any S3-compatible store the operator picks (docs/server/extras). |
| Q38 | Push: FCM for both platforms, or FCM for Android and APNs directly for iOS? | FCM for both is one code path and one Flutter plugin, but routes iOS notifications through Google as well as Apple. APNs direct keeps iOS pushes away from Google at the cost of a second sender | *Added 2026-10-11.* APNs direct for iOS, FCM for Android, both sent by one `push-send` Edge Function; payloads minimal either way. **Deferred 2026-10-15 by Q47:** v1 has local reminders only, so no push credentials are needed for launch. Answer this only if the relay is built |
| Q28 | Should `busy_until` ("Termine bis 17:00") be typed in daily, or is that the moment a private work-calendar subscription earns its place? | Typing it every morning is exactly the kind of chore that lapses in week three | Hand-entered in v1; if it lapses, subscribe to the work calendar read-only in M3 and take **only** the end of the last meeting from it |
| Q25 | What counts as a "key appointment" that reaches the kitchen display? | The week board is only trusted if it is complete, and only readable if it is not | Explicit flag; its default is a household setting (`calendar.key_default`), proposed: on for whole-family events, off for personal ones. Review after two weeks of real use |
| Q26 | When should the week board roll over to the coming week? | Sunday-evening planning wants next week; Saturday morning still wants today | A household setting (`board.rollover`), proposed default Saturday 12:00. Watch what actually gets asked at the display |
| Q27 | Are the children's names on the wall display, or initials and colours? | The display is visible to anyone in the kitchen, including visitors | A household setting (`board.member_label`), proposed default: names. Initials are harder to read at two metres |

## Answered by the mockups

| # | Question | Answer |
|---|---|---|
| Q29 | Tiles with pictures, or a text list, for capture? | **Decided 2026-09-02: tiles**, with a self-hosted icon set. See [07](07-module-meals-shopping.md#settled-on-2026-09-02) |
| Q30 | May the children add shopping items? | **Decided 2026-09-02: yes**, same screen as everyone else, with the adder's colour on each row |
| Q31 | One shopping list or several? | **Decided 2026-09-02: several**, with Supermarkt as the default and the only one on the wall |
| Q32 | How is quantity captured without a numeric field? | **Decided 2026-09-02:** tap counts up; long press opens one free-text field ("Bio", "500 g", "Dose") |
| Q33 | Should the kiosk be able to add to the shopping list? | **Decided 2026-09-02: yes**, tiles only, no search field, default list only (FR-8.12) |
| Q34 | Merge "wer ist wo" and "Termine" on the week board? | **Decided 2026-09-02: no** — see the rejected layouts in [09](09-clients-and-ux.md#considered-and-rejected-merging-the-zones) |

## Before M2 (assistants and the obvious gaps)

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q15 | Does self-hosted Supabase Auth's OAuth 2.1 server cover MCP's requirements as of the 2026-07-28 spec? *(was: Better Auth's OIDC provider; revised 2026-10-11)* | Determines whether OAuth is configuration or a build | Verify early; if not, `family:read` over a static bearer token is an acceptable interim. *Checked 2026-10-16:* the OAuth 2.1 server is in public beta and available self-hosted (authorization code with PKCE, dynamic client registration), but each server must bring its own login and consent screens, and MCP 2026-07-28 prefers Client ID Metadata Documents over dynamic registration. **Phase 2 shipped with the interim** (per-person `wwa_` assistant keys, [12](12-mcp-and-assistants.md#part-2--the-mcp-server)); OAuth is a build, scheduled with the write scopes |
| Q16 | Which assistant gets write access first, and to what? | Sets the blast radius of a misunderstanding | Shopping only. It is the most useful and the least destructive. |
| Q17 | Should assistant-created items look different in the UI? | Trust and reviewability | Yes — a small marker, and a filter in the audit view |
| Q50 | Birthdays: a field on the profile, or a yearly event? | The most-asked family date, and the data model ([04](04-data-model.md#identity)) lists `profile.birthday`, but no migration has added it. A field gives "Hanna wird 8" on the board's day header and an age for task defaults; a yearly event works today, but has to be entered per person and knows no age | *Added 2026-10-16.* Lean: the field, projected like public holidays (a read-only occurrence, never an event row), written on the member page of [16, step 10.1](16-setup-plan.md#step-10--journey-gaps-before-launch-m15). Grandparents and friends stay yearly events. Decide after the first weeks of use (M2) |

## Deferred indefinitely

Recorded so they are not re-litigated every time they occur to someone.

- ~~**Multi-household support.** No. See [01](01-vision-and-scope.md).~~ **Reversed
  2026-10-11 by [ADR-014](adr/ADR-014-self-service-onboarding.md)**: self-service
  households. Still deferred: anything *between* households (Q43).
- **A sibling leaderboard.** No. See [06](06-module-tasks.md).
- **Two-way Outlook/Google sync.** No. See [ADR-001](adr/ADR-001-calendar-backbone.md).
- **Per-item privacy between family members.** No, unless a concrete need appears.
- ~~**A public App Store or Play Store listing.** No — internal distribution only
  ([ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md)).~~ **Reversed 2026-10-11 by
  [Q42](#before-opening-to-other-households):** public listings, with TestFlight and the Play
  testing tracks as pre-release channels.

## How to use this file

When something comes up mid-build that is not required by the module in front of you,
write it here with the milestone by which it must be decided, and carry on. That is the
mechanism that keeps [13 — Roadmap](13-roadmap.md)'s cut lines from eroding — and cut
lines eroding, not technical difficulty, is what usually ends projects like this one.
