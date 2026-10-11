# 14 — Open Questions

Decisions deliberately deferred. Each has a point by which it must be answered, so that
none of them quietly becomes a blocker. Anything that surfaces during implementation
lands here rather than in the module being built.

## Before M0

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q1 | Which domain? | Needed for TLS, feed URLs, the OAuth issuer and the PWA scope. Changing it later invalidates every subscribed ICS feed. | **Decided 2026-08-30: own `.de` domain** (not a free dyndns subdomain), with `home.` and `mcp.` subdomains. Use a wildcard cert (DNS-01) so subdomains don't appear individually in CT logs. Pick the actual domain name next. **Superseded 2026-10-11 ([ADR-013](adr/ADR-013-one-self-hosted-environment.md)): `wusel.example.org`**, a subdomain of the user's own `example.org`, proxied by Cloudflare. |
| Q2 | SvelteKit or Next.js? | [ADR-003](adr/ADR-003-technology-stack.md) recommends SvelteKit; you may prefer the larger ecosystem | ~~Decided 2026-08-30: SvelteKit.~~ **Superseded 2026-10-11: Flutter clients on self-hosted Supabase** ([ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md)). |
| Q3 | GitHub or a self-hosted forge? | Determines the CI and registry path | **Decided 2026-08-30: GitHub.** GHCR is no longer needed — Supabase's images are pulled from upstream and nothing is built into an image ([16](16-setup-plan.md)). |
| Q35 | Is a Mac available — own, borrowed, or a second-hand Mac mini? | Without one, iOS builds exist only in CI: no simulator, no Xcode debugger, iOS-only bugs diagnosed from TestFlight crash reports ([ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md)) | *Added 2026-10-11.* Start without; buy or borrow one if the first iOS-specific bug costs more than an evening. *Resolved 2026-10-11:* a MacBook Pro is available — iOS Simulator, Xcode and local iOS builds ([18](18-testing-strategy.md)) |
| Q36 | Accept the higher running cost? | The Apple Developer Program (€99/year) and an 8 GB server for Supabase put the total at ≈ €18–21/month, against the original ≤ €10 target (NFR-7) | *Added 2026-10-11.* Accept: the €99 is the price of native apps on iOS at all, and a 4 GB server would make Supabase the thing that stalls. NFR-7 is revised as *proposed* until confirmed **Resolved 2026-10-11 by [ADR-013](adr/ADR-013-one-self-hosted-environment.md):** no rented server, so the total is ≈ €8–12/month and NFR-7's €10 target roughly holds. |
| Q37 | Can the children's Apple accounts be TestFlight testers? | Child accounts under Family Sharing may not be addable as App Store Connect users or may not be allowed to run TestFlight | *Added 2026-10-11.* Try it with one iPad as soon as the developer account is active (M0.4). If it fails: Ad Hoc builds to the iPads' registered UDIDs, installed from a page on the VPS |

## Before M1.0 (onboarding)

*Added 2026-10-11 with [ADR-014](adr/ADR-014-self-service-onboarding.md).*

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q41 | Which SMTP provider sends the sign-in codes? | Email codes do not work without one (Mailpit only catches mail on the home network); the provider sees addresses and codes (NFR-9), and deliverability decides whether people get in at all | An EU provider with a free tier and DKIM on our domain (Brevo, Mailjet or Scaleway TEM); not the home server's own mail, whose IP will be on blocklists. Decide before the email path is built; Apple and Google sign-in do not depend on it |
| Q43 | One household per account — what about separated parents, or a grandparent in two families? | `profile.auth_user_id` is unique, so an adult can be in one household. Patchwork families are common, and a child living in two homes is the hardest case | One household per account in v1; the data model does not prevent a later household switcher (a second linked profile per account, the household chosen per session). Revisit when a real family asks, not before |

## Before opening to other households

*The gate in [13](13-roadmap.md#opening-to-other-households).*

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q40 | Where does the one project with everyone's households run? | ADR-014 puts all households in one project, and the app has one backend URL. The home server costs nothing but makes the operator's house the data centre for strangers (availability, power cuts, GDPR controller duties); hosted Supabase in Frankfurt is EU-resident but US-owned, which ADR-010 rejected for this family's data | Keep one stack for all households, this family included. Before opening, move from the CLI stack to the official self-hosting compose stack (A8, *done 2026-10-11*) — at home, or on a rented EU server if availability or the operator's appetite for strangers' data at home says so. Hosted Supabase only if the family's own data may move too |
| Q42 | How do strangers install the app — TestFlight public link and Play open testing, or full store listings? | Internal testing reaches only App Store Connect users and listed Play testers. A public link still needs Beta App Review, and a store listing needs metadata, screenshots, privacy labels and a review account | TestFlight public link + Play open testing first (quick, honest "beta" label), store listings once the first outside families have used it for a month |
| Q44 | Captcha on sign-up? | Supabase Auth supports hCaptcha and Turnstile; both are third parties in the sign-up path and awkward in native apps | No. Rate limits, `code` mode and the empty-account clean-up first; Turnstile on the email step only if abuse appears |
| Q45 | Which domain do other families see? | Invitation links, universal links, App Links and the passkey relying-party ID are bound to it; changing it later breaks every passkey and every outstanding link | Decide before the first passkey or invitation leaves the family. `wusel.example.org` is fine for the family; a product domain (e.g. `wuselwall.de`/`.app`, availability to check) is the better public face |

## Before M1.2 (tasks)

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q39 | Which design direction — A Küchentisch, B Pausenhof or C Fjord? | Sets the theme tokens before the first real screens (M1.2) are built; changing later is cheap in code but means re-reviewing every screen **Decided 2026-10-11: A "Küchentisch"**, in every register ([17](17-design-system.md)). B's outlines for the kid register remain the fallback if the children find it too plain |
| Q4 | What is a point actually worth? | The exchange rate sets the entire economy's feel. Too generous and rewards are meaningless; too stingy and the children disengage in week two. | Start with: duty 1–3 points, bonus 5–15, cheapest reward ~5, mid ~15, big ~50. Expect to recalibrate once. |
| Q5 | Which chores are duties and which are bonuses? | The intrinsic-motivation argument in [06](06-module-tasks.md) hinges on this line | Decide it with the children present — participation in the rules is most of the buy-in |
| Q6 | Do points convert to pocket money? | Changes the psychology significantly and is very hard to walk back | Not in v1. Non-monetary rewards first; see how it lands. |
| Q7 | How many joker days per month? | Anti-frustration tuning for the 7-year-old | Start at 1, raise if there are tears |

## Before M1.3 (calendar, presence and Stundenplan)

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q8 | Do the children get calendar write access? | Affects the kid register and the permission matrix | Yes, for their own events. It is theirs too. |
| Q9 | Should chore due dates appear in the ICS feed? | An Outlook calendar full of "empty the dishwasher" is unhelpful at work | No by default; make it a per-token filter option |
| Q10 | Which external calendars will you import in M2? | Determines how much the import feature actually needs to handle | Sports club and bin collection. Ferien come from the Bundesland feed ([15](15-module-school-timetable.md#holidays)); the timetable itself is not an import |

*Q18–Q24 were added 2026-08-30 with the A5 requirement. Most are answerable in one
conversation with the family — and that conversation is worth having before the grid
editor is built, not after.*

| Q18 | Which schools, and which Bundesland? | The Ferien import is per-Bundesland, and bell times differ per school | **Decided 2026-09-02: Berlin.** Lotta is in Klasse 5a, Hanna in the Schulanfangsphase (SAPh E). Ferien and bewegliche Ferientage therefore come from the Berlin feed; still to collect: both schools' Stundenraster and the term dates |
| Q19 | Do either of the schools use A/B weeks (Doppelwochen)? | If neither does, `week_cycle` stays `'weekly'` and a whole layer of UI never has to be drawn | Ask before building the grid editor. Primary schools usually do not |
| Q20 | Does either school publish a timetable or substitution feed (WebUntis, IServ, Schulmanager)? | Decides whether manual entry is a stopgap or the permanent answer | Assume manual for v1 either way — an import is an M3 addition, not a v1 dependency |
| Q21 | How does Sabine's Dienstplan actually arrive — paper, PDF, an employer app? And how far ahead? | Decides whether the `rdates` month grid is sufficient or whether it needs a bulk-paste path | Month grid first. Revisit only if entering a month takes more than a minute |
| Q22 | Is Hort/Betreuung a timetable row or a presence entry? | Affects both the grid editor and the "isst mit" defaulting | Timetable row with `kind='care'` — it is part of the child's school day and the parent reads it there |
| Q23 | Who maintains the Stundenplan, and may the children enter an Entfall? | Guardian-only is simpler; a nine-year-old reporting "Mathe fällt aus" is also genuinely useful | Guardian-only in v1. Revisit once the children are actually using the app |
| Q24 | Does the timetable go into the ICS feed at all, and collapsed or per lesson? | An Outlook calendar with sixty lessons a week is an unsubscribed calendar | Off by default; the collapsed school-day block available per token; per-lesson only if someone asks |

## Before M1.5 (launch)

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q11 | Which wall-display hardware? | Constrains the kiosk register and needs lead time to order | Cheap Android tablet (≥ 1280×800, landscape) running the native app in kiosk mode; Fully Kiosk with the web build only as a fallback — see [09](09-clients-and-ux.md#the-wall-display). *Revised 2026-10-11* |
| Q12 | Where does the display go? | Needs power and a viewing angle from where people stand | Kitchen, at adult eye level, with the children's columns reachable |
| Q13 | Which notifications are on by default? | Over-notifying in week one trains the family to ignore the app permanently | Morning summary only; everything else opt-in |
| Q14 | Backup target: Backblaze B2 or Hetzner Storage Box? | Cost versus keeping everything in Germany | B2 is cheaper; the Storage Box keeps data in-country. Both encrypted client-side, so either is defensible. *Since ADR-013:* the dumps land on the home server first (`/srv/backups/wuselwall`); the off-site copy via restic is still to choose — B2, or any second location away from the house. Decide before M1.6. |
| Q38 | Push: FCM for both platforms, or FCM for Android and APNs directly for iOS? | FCM for both is one code path and one Flutter plugin, but routes iOS notifications through Google as well as Apple. APNs direct keeps iOS pushes away from Google at the cost of a second sender | *Added 2026-10-11.* APNs direct for iOS, FCM for Android, both sent by one `push-send` Edge Function; payloads minimal either way. Revisit if the iOS-only plumbing in Flutter proves fragile |
| Q28 | Should `busy_until` ("Termine bis 17:00") be typed in daily, or is that the moment a private work-calendar subscription earns its place? | Typing it every morning is exactly the kind of chore that lapses in week three | Hand-entered in v1; if it lapses, subscribe to the work calendar read-only in M3 and take **only** the end of the last meeting from it |
| Q25 | What counts as a "key appointment" that reaches the kitchen display? | The week board is only trusted if it is complete, and only readable if it is not | Explicit flag, defaulted on for whole-family events and off for personal ones. Review after two weeks of real use — if things are missing, widen the default |
| Q26 | When should the week board roll over to the coming week? | Sunday-evening planning wants next week; Saturday morning still wants today | Saturday 12:00, configurable. Watch what actually gets asked at the display |
| Q27 | Are the children's names on the wall display, or initials and colours? | The display is visible to anyone in the kitchen, including visitors | Names. It is a private kitchen, and initials are harder to read at two metres |

## Answered by the mockups

| # | Question | Answer |
|---|---|---|
| Q29 | Tiles with pictures, or a text list, for capture? | **Decided 2026-09-02: tiles**, with a self-hosted icon set. See [07](07-module-meals-shopping.md#settled-on-2026-09-02) |
| Q30 | May the children add shopping items? | **Decided 2026-09-02: yes**, same screen as everyone else, with the adder's colour on each row |
| Q31 | One shopping list or several? | **Decided 2026-09-02: several**, with Supermarkt as the default and the only one on the wall |
| Q32 | How is quantity captured without a numeric field? | **Decided 2026-09-02:** tap counts up; long press opens one free-text field ("Bio", "500 g", "Dose") |
| Q33 | Should the kiosk be able to add to the shopping list? | **Decided 2026-09-02: yes**, tiles only, no search field, default list only (FR-8.12) |
| Q34 | Merge "wer ist wo" and "Termine" on the week board? | **Decided 2026-09-02: no** — see the rejected layouts in [09](09-clients-and-ux.md#considered-and-rejected-merging-the-zones) |

## Before M2 (assistants)

| # | Question | Why it matters | Leaning |
|---|---|---|---|
| Q15 | Does self-hosted Supabase Auth's OAuth 2.1 server cover MCP's requirements as of the 2026-07-28 spec? *(was: Better Auth's OIDC provider; revised 2026-10-11)* | Determines whether OAuth is configuration or a build | Verify early; if not, `family:read` over a static bearer token is an acceptable interim |
| Q16 | Which assistant gets write access first, and to what? | Sets the blast radius of a misunderstanding | Shopping only. It is the most useful and the least destructive. |
| Q17 | Should assistant-created items look different in the UI? | Trust and reviewability | Yes — a small marker, and a filter in the audit view |

## Deferred indefinitely

Recorded so they are not re-litigated every time they occur to someone.

- ~~**Multi-household support.** No. See [01](01-vision-and-scope.md).~~ **Reversed
  2026-10-11 by [ADR-014](adr/ADR-014-self-service-onboarding.md)**: self-service
  households. Still deferred: anything *between* households (Q43).
- **A sibling leaderboard.** No. See [06](06-module-tasks.md).
- **Two-way Outlook/Google sync.** No. See [ADR-001](adr/ADR-001-calendar-backbone.md).
- **Per-item privacy between family members.** No, unless a concrete need appears.
- **A public App Store or Play Store listing.** No — internal distribution only
  ([ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md)). *(Replaces "a native iOS
  app — only if a capability forces it", which the move to Flutter on 2026-10-11 settled.)*

## How to use this file

When something comes up mid-build that is not required by the module in front of you,
write it here with the milestone by which it must be decided, and carry on. That is the
mechanism that keeps [13 — Roadmap](13-roadmap.md)'s cut lines from eroding — and cut
lines eroding, not technical difficulty, is what usually ends projects like this one.
