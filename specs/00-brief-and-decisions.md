# 00 — Original Brief & Decisions Taken

Kept verbatim so that a later session — or a later you — can tell what was asked for from
what was inferred.

## The brief, as given (2026-08-29, in German)

> **Scope**
>
> **A** Tagesplanung für die Familie mit:
> **A1** Familienkalender (Anzeigen eines Familienkalenders, der auch in anderen
> Umgebungen verwendet werden kann (z.B. von meinem Outlook auf dem Arbeitslaptop))
> **A2** Aufgabenverwaltung – z.B. für wiederkehrende Aufgaben im Haushalt, aber auch für
> Sonderaufgaben. Gerne mit Gamification, Pflichtaufgaben oder ähnlichem.
> **A3** Essensplan: Damit wir planen können, wann es was zu essen gibt.
> **A4** Einkaufsliste: Damit man jederzeit aufschreiben kann, wenn man etwas braucht und
> dann im Supermarkt die Liste abarbeiten kann.
>
> **B** Generelle Wünsche
> **B1** User – jedes Familienmitglied soll einen eigenen Nutzer haben, damit man Aufgaben
> als erledigt markieren kann, Termine einstellen kann.
> **B2** Multi-Device: Es sollte funktionieren, dass die App auf einem Notebook (z.B. im
> Browser) funktioniert, aber auch auf einem iPad (der Kinder) oder einem iPhone (der
> Eltern) oder einem einfachen Touch-Display / Tablet.
> **B3** Deployment: Ich habe keine Erfahrung, wie man eine solche App am besten deployt.
> Es wäre okay, wenn dafür auch kleinere Kosten benötigt werden. Ich will die App aber
> nicht für andere kommerzialisieren – dennoch wäre es super, wenn die App in Sachen
> Sicherheit gut umgesetzt wäre und die Daten nicht unnötig von vielen Diensten
> abgegriffen werden können.
> **B4** MCP-Anbindung: Idealerweise gibt es auch die Möglichkeit, dass z.B. Siri oder in
> Zukunft ein AI-Assistant mit der App interagieren kann.
>
> Ziel ist eine Dokumentation des Vorhabens, gerne auch auf Englisch, damit ich dann
> später Code erstellen kann. Ggfs. kommen später weitere Anforderungen dazu.
>
> *(This folder is for planning only; coding, deployment and everything technical happens
> separately.)*

## Decisions taken by the user

| Question | Answer | Recorded in |
|---|---|---|
| Calendar backbone | **Own database with an outbound ICS feed** | [ADR-001](adr/ADR-001-calendar-backbone.md) |
| Build vs. assemble | **Build one application from scratch** | [ADR-002](adr/ADR-002-build-vs-assemble.md) |
| Hosting | **Small VPS in Germany** — with the note "I'll need more guidance here" | [ADR-005](adr/ADR-005-hosting.md), [10](10-deployment-and-ops.md) |
| Technology | ~~TypeScript end to end~~ → **Flutter apps on self-hosted Supabase** (changed 2026-10-11) | [ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md), superseding [ADR-003](adr/ADR-003-technology-stack.md) |
| Household | **2 adults, 2 children aged 7 and 9** — since 2026-10-11 the *reference household*: the design case and the demo data, while every household-specific choice is a setting | [01](01-vision-and-scope.md), [21](21-household-settings.md) |
| Login model | **Device session with tap-to-switch profiles** | [ADR-004](adr/ADR-004-identity-model.md) |
| Gamification | **Points with redeemable rewards, plus streaks and badges** | [06](06-module-tasks.md) |
| Devices | **Parents' iPhones, children's iPads, laptop browser, fixed wall display** | [09](09-clients-and-ux.md) |
| First release | **All four modules at once** | [13](13-roadmap.md) |
| Stundenplan and presence (added 2026-08-30) | **In v1**, because the kitchen display depends on both | [15](15-module-school-timetable.md) |
| The kitchen display's standard view | **A seven-day week board**, not a today dashboard | [09](09-clients-and-ux.md#the-week-board) |

## Where the plan pushes back

Three places where the documentation recommends something other than the obvious reading
of the brief. Each is argued in full at the link; flagged here so they are not missed.

1. **Tap-to-switch profiles cannot prove who did anything** on a shared device. The plan
   accepts the choice — password prompts on a kitchen display are how family software dies
   — but treats attribution as cooperative bookkeeping and gates every action that moves
   points behind a guardian PIN. → [ADR-004](adr/ADR-004-identity-model.md)
2. **"All four modules at once" needs a walking skeleton in front of it.** Milestone 0
   ships one thin slice end to end so that auth, the apps' distribution and the
   deployment path are proven before four modules of domain logic land on top.
   → [13](13-roadmap.md)
3. **Outlook will lag by 3–24 hours.** This is a Microsoft limitation on subscribed
   internet calendars with no configuration and no manual refresh. The ICS feed is an
   awareness channel; anything time-critical goes out as a push instead.
   → [05](05-module-calendar.md)

## Later additions

The brief notes that further requirements may follow. Add them to
[02 — Requirements](02-requirements.md) with a new ID and an origin of `late`, and record
the date here.

### 2026-08-30 — A5: Stundenplan, flexible appointments, and the kitchen's standard view

> I want to add another key feature, basically a special version of views the calendar:
> Adding school schedule (Stundenplan) for the kids. Appointments in general should be
> flexible, e.g. regular to maintain when Sarah is working or flexible to show when David
> is travelling for work.
>
> The standard view in the kitchen (kiosk style) should contain the Stundenplan, main
> appointments in the week.

Three distinct requirements, and they were treated as three:

| Ask | Answer | Where |
|---|---|---|
| The children's Stundenplan | A first-class **timetable pattern** — weekday × Stunde → Fach, term-bound, minus Ferien, plus per-date exceptions — projected into the calendar rather than stored as sixty recurring events | [15](15-module-school-timetable.md), [ADR-008](adr/ADR-008-school-timetable-model.md), FR-7.x |
| Flexible appointments: regular for Sarah's work, ad hoc for David's travel | A second event **kind**, `presence`, in the same table: rotas as `RRULE` *or* an explicit `RDATE` set tapped into a month grid, travel as a plain span with a `tentative` status | [05](05-module-calendar.md#what-a-calendar-entry-can-be), [ADR-009](adr/ADR-009-event-kinds-and-presence.md), FR-1.11–1.17 |
| The kitchen's standard view | The kiosk's default screen is now a **seven-day week board** with four fixed zones per day, not the today dashboard originally planned | [09](09-clients-and-ux.md#the-week-board), FR-8.x |

**What this cost.** Roughly a month on M1 (see [13](13-roadmap.md#effort)), most of it in
the projection function and the week board. **What it changed elsewhere:** `event` gained
five columns, feed tokens gained a kind filter and now default to appointments only,
"who is eating at home" was promoted from `S` to `M` because the meal zone depends on it,
and the security model's most sensitive asset is no longer the calendar but a child's
timetable combined with an adult's absence pattern ([11](11-security-and-privacy.md)).

**Naming note.** The examples throughout the documents use the reference household's
names, the same as the demo's and in the language of the text around them: in English
*David* and *Sarah* for the adults, *Olivia* (9) and *Jack* (7) for the children; in German
(quoted German text, German mockups, the German docs and the code) *Thomas* and *Julia*,
*Emma* (9) and *Paul* (7).
Since 2026-10-11 they are examples, not assumptions — see the entry below and
[21](21-household-settings.md#the-reference-household).

**Refined 2026-09-02, from the first review of the mockup:** the wall carries only each
child's school-day span and the lessons worth packing for, with the full Stundenplan one
tap away (FR-8.3a); key appointments sit in three fixed day parts rather than on a time
axis, with a dot per attendee (FR-8.3b); the meal zone shows one warm meal a day; and each
adult gained a **baseline presence** so that only deviations are entered and only
deviations are emphasised (FR-1.18). Olivia's timetable in the mockup is the real one from
the class's paper plan.

### 2026-10-11 — Technology stack: Flutter and self-hosted Supabase

> For the TechStack: I want a self-hosted Supabase (docker) as backend and Flutter as
> frontend to be able to build native Apps for Android and iOS. So please adjust
> everything related to that and prepare a plan how to build out the basic setup,
> including ci/cd, etc.

Recorded as a change of decision, not a new requirement: the brief (B2, B3) is unchanged,
the way it is met is not.

| Change | Answer | Where |
|---|---|---|
| Backend | Self-hosted Supabase on the same German VPS. PostgreSQL becomes the domain core: an `api` schema of views and functions over RLS-protected tables; Edge Functions for recurrence, the week board, ICS, enrolment; `pg_cron` for jobs; Realtime for live updates | [ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md), [03](03-architecture.md) |
| Clients | One Flutter codebase: native iOS/iPadOS and Android apps, plus a web build for the laptop | [ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md), [09](09-clients-and-ux.md) |
| Distribution and CI/CD | TestFlight and the Play internal track; GitHub Actions with fastlane; deploy by SSH with a backup first | [ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md), [16](16-setup-plan.md) |
| Build order | M0 re-cut, with a new M0.4 for the release pipeline before production | [13](13-roadmap.md), [16](16-setup-plan.md) |

**What this cost.** The Apple Developer Program (€99/year) and a server one size larger
take the running cost to roughly €18–21/month, past the original €10 target — NFR-7 is
marked *proposed* until confirmed ([Q36](14-open-questions.md)). Three languages (Dart,
SQL, TypeScript) instead of one. **What it bought.** Native apps on every device, with real
push and a real kiosk mode; auth, realtime and jobs without writing them; and ADR-005's
objection to Supabase, which was about the hosted service, does not apply to a
self-hosted one.

### 2026-10-11 — Product name: WuselWall

> Can you work on getting a logo and a proper name for our Family Planning app. We don't
> want any generic name, but something unique.

After a market check of the shortlisted names, the household chose **WuselWall**:
*wuseln* (bustling about) plus the kitchen wall display. It replaces the working title
GoombaWall everywhere, including the bundle ID (`ch.wuselwall.app`), the Dart package and
the Supabase project ID. Names considered and rejected, and the consequences, are in
[ADR-012](adr/ADR-012-product-name.md).

### 2026-10-11 — One self-hosted stack, no separate dev and prod

> For now we only build one tenant, not two (dev and prod) landscapes. […] Any further
> tenants might be run on the Supabase SaaS service itself.

| Change | Answer | Where |
|---|---|---|
| Hosting | One self-hosted Supabase stack, used by the pilot household and for development alike. No VPS, no `deploy.yml`, no `env/prod.json` | [ADR-013](adr/ADR-013-self-hosted-compose-stack.md), [10](10-deployment-and-ops.md) |
| Public entry | An HTTPS front that forwards four API prefixes to the gateway | [10](10-deployment-and-ops.md) |
| Further tenants | Hosted Supabase, one project per tenant; `supabase/` stays portable | [ADR-013](adr/ADR-013-self-hosted-compose-stack.md#keeping-the-code-portable-to-hosted-supabase) |
| Identifiers | Application and bundle ID `ch.goomba.wuselwall` (chosen by the user before any store record existed); the GitHub repository moved to the `wuselwall` organisation as `wuselwall-app`, with `wuselwall-certificates` for iOS signing | [ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md#starting-point-and-identifiers), [ADR-011](adr/ADR-011-native-distribution-and-ci-cd.md) |

**What this cost.** Development and live data share one database, protected by a dump
before every migration and by keeping `db reset` and the integration test away from it.
**What it bought.** No hosting bill, no second stack to keep in step, and push, the
Outlook feed and use outside the house no longer wait for a deployment milestone.

### 2026-10-11 — Onboarding, social sign-in and self-service households

> Check all specs about the onboarding experience and iterate on it and improve it, so
> it is as smooth as possible. Include these social login providers: Apple & Google (no
> Facebook, etc). Allow email signup flow with one time passwords, but also allow normal
> passwords, etc.

Asked whether sign-up is for invited adults of this household or for any family, the user
chose **self-service households**.

| Change | Answer | Where |
|---|---|---|
| Adult sign-in | Email one-time code, email + password (chosen after the first code). One screen for sign-up and sign-in. No providers, no SMS, no magic links *(revised 2026-10-17: Sign in with Apple and Google removed, user)* | [ADR-014](adr/ADR-014-self-service-onboarding.md), [20](20-onboarding.md#the-front-door) |
| Households | Any adult can create one: `code` mode (founder code from the operator) until the opening gate, then `open`. One household per account. All households in one project, isolated by RLS | [20](20-onboarding.md#household-creation-open-or-by-code), [13](13-roadmap.md#opening-to-other-households) |
| Other adults | Invitation by link, code or QR, bound to a profile, 7 days; matched automatically by email | [20, J2](20-onboarding.md#j2--join-a-family) |
| Shared devices | Reverse pairing: the device shows a code, a parent's phone approves it; no typing on the device | [20, J3](20-onboarding.md#j3--connect-a-shared-device), [08](08-users-auth-permissions.md#device-pairing) |
| Deferred setup | PIN at the first shared device; avatars, second factor, passkeys and push from a getting-started card | [20](20-onboarding.md#the-getting-started-card) |
| Leaving | Delete account, leave or delete the household, export data, all in the app | [20, J6](20-onboarding.md#j6--leave) |
| Non-goals reversed | Multi-tenancy; a public store listing (at the opening gate) | [01](01-vision-and-scope.md#explicitly-out-of-scope) |

**What this costs.** Once other families are let in, the operator is a GDPR controller for
their data. The domain, the Apple and Google client setup, SMTP and public distribution
all become things to operate. A cross-household bug stops being theoretical.
**What it buys.** A family starts in under two minutes without a server in sight, the
second parent joins in one, nobody types on the wall display, and a lost password no
longer needs the operator.

### 2026-10-11 — The official self-hosting compose stack

> Yes, move to the official self-hosting compose file.

The answer to S10 and A8 in [19](19-security-and-architecture-review.md), and the first
condition of [Q40](14-open-questions.md). The server now runs Supabase's official
compose file (`infra/supabase/`) instead of the CLI's stack: no database port on the
local network, Studio behind a login, its own secrets, and the CLI's image versions so
CI and the server agree. The development data was not carried over — the pilot household
starts fresh. Recorded as the
[ADR-013 amendment](adr/ADR-013-self-hosted-compose-stack.md#amendment-2026-10-11-the-official-compose-stack).

### 2026-10-11 — A generic household setup with curated defaults

> You need to abstract from the specific family to a more generic setup, so the user can
> define those settings while still using carefully curated defaults. […] Update the
> specs to not lean so heavily into the demo family.

| Change | Answer | Where |
|---|---|---|
| The family | Becomes the **reference household**: the design case, the names in examples and mockups, and the demo and seed data. Nothing in code, schema or tests may depend on its size, ages, region or schools | [21](21-household-settings.md#the-reference-household), [01](01-vision-and-scope.md#users) |
| Household-specific choices | A **setting with a curated default**: a catalogue of definitions written by migrations, an override row only where a household changed something, reset to default always possible | [21](21-household-settings.md#model) |
| Setup | Household creation stays as [20, J1](20-onboarding.md#j1--start-a-family) defines it and asks nothing more: the region is asked when the first school is added; J1's starter examples are the curated starter content (chores, rewards, badges, lists) | [21](21-household-settings.md#household-creation), [08](08-users-auth-permissions.md#bootstrapping-a-new-household) |
| Open questions | A question that differs per household now only decides the default. Q8, Q9 and Q22–Q24 decided; Q4–Q7 tracked as issues #6–#9; every proposed default collected in #10 | [14](14-open-questions.md) |

**What this cost.** One settings table and two `api` functions, and a settings screen that
grows with each module. **What it bought.** Point values, jokers, rollover and the meal rule
no longer block a module's build; they are data that can be tuned after two weeks of real
use without a release — and a second household needs no code change.

### 2026-10-11 — Hosting flavours, stores, captcha, domain

> When it comes to hosting there is the self-host flavor […] but there should also be the
> option to use a SaaS via Supabase, which I will own as an account. If we will ever charge
> for that is another story. […] We will roll out the app in the Google and App Store once
> we have the Android dev account and Apple developer account. No captcha. Final public
> domain is not yet decided. […]

| Change | Answer | Where |
|---|---|---|
| Hosting | Two flavours from one codebase. **WuselWall Cloud** is a hosted Supabase project in the user's account (Frankfurt, Pro) and the store app's default. **Self-hosted** is any server, reached through "Eigener Server" | [ADR-015](adr/ADR-015-saas-and-self-hosted-flavours.md), [10](10-deployment-and-ops.md#wuselwall-cloud) |
| Sign-in on custom servers | Email code and password. Passkeys on first-party servers only, so that a hostile server cannot replay assertions to them *(Apple and Google removed 2026-10-17)* | [ADR-015](adr/ADR-015-saas-and-self-hosted-flavours.md), [20](20-onboarding.md#on-a-self-hosted-server) |
| Email | Decided: Scaleway Transactional Email, one project per environment, a sending subdomain with SPF/DKIM/DMARC, the code in the subject | [10](10-deployment-and-ops.md#email-setup), [Q41](14-open-questions.md) |
| Distribution | Public App Store and Google Play listings once the developer accounts exist | [ADR-015](adr/ADR-015-saas-and-self-hosted-flavours.md), Q42 |
| Captcha | None | Q44 |
| Domain | A temporary address for now; final domain open | Q45 |

**What this costs.** Supabase Pro (≈ $25/month, later ≈ $10 for a custom domain), a
US-headquartered processor for Cloud's households, two schemas to keep in step, and a
plainer front door on self-hosted servers. **What it buys.** Strangers' data and uptime
are off self-hosted servers, Edge Functions deploy normally on Cloud, and self-hosting stays a
real option in the same app.

### 2026-10-13 — The domain: wuselwall.app

> I just bought the domain wuselwall.app. […]

| Change | Answer | Where |
|---|---|---|
| Domain | **`wuselwall.app`** decides Q45: invitation and pairing links, universal links and App Links, the passkey RP ID | [ADR-017](adr/ADR-017-wuselwall-app-domain.md), [Q45](14-open-questions.md) |
| Public entry | `wuselwall.app` the website, `/docs/` and `/download/` | [ADR-017](adr/ADR-017-wuselwall-app-domain.md) |
| Unchanged | Application and bundle ID `ch.goomba.wuselwall` | [ADR-012](adr/ADR-012-product-name.md) |

**What this costs.** A domain to renew. **What it buys.** The product's own name in every
link.

### 2026-10-13 — Self-hosted only

> Also in general I think we should refrain from using a hosted variant of the app.
> Is it possible to seperate the frontend from the backend in a way, that the
> frontend/app can be plugged into ANY self-hosted backend? So ONLY self-hosted. No
> hosted Saas from our side?

| Change | Answer | Where |
|---|---|---|
| Hosting | **No WuselWall Cloud.** The project runs no service holding a family's data. Every household runs a server release on its own hardware or its own Supabase project | [ADR-018](adr/ADR-018-self-hosted-only.md) |
| The app | No default server: invitation link, the server's QR code or a typed address, discovered through `/.well-known/wuselwall.json`. A demo mode without any server, also for App Review | [ADR-018](adr/ADR-018-self-hosted-only.md), [20](20-onboarding.md#choosing-the-server) |
| Compatibility | `api_version` in the discovery document; each app release supports the current and the previous one; CI tests against the previous server release | [ADR-018](adr/ADR-018-self-hosted-only.md), [10](10-deployment-and-ops.md#other-families-servers) |
| Apple and Google | No sign-in with either (user, 2026-10-17; was: native sign-in on first-party servers, 2026-10-13). The app carries no vendor sign-in library | [ADR-018](adr/ADR-018-self-hosted-only.md), [11](11-security-and-privacy.md) |
| Open | Push to self-hosted servers ([Q47](14-open-questions.md)); sign-up without SMTP (Q48) | [14](14-open-questions.md) |

**What this costs.** Families need a server, version skew between store apps and servers
is permanent, and push needs its own answer. **What it buys.** No other family's data
on the project's infrastructure, no Supabase bill, and a privacy policy that can say so.

### 2026-10-13 — Licence: Apache 2.0

> I pick Apache 2.0.

Chosen over MIT for the explicit patent grant, contributions under the same licence
without a separate agreement (section 5), and section 6, which keeps the name and logo
from being used by forks. AGPL-3.0 was set aside: it would stop closed hosted copies, but
GPL terms clash with App Store distribution once other people's code is in the app. The
licence lets anyone run WuselWall as a hosted service, which fits
[ADR-018](adr/ADR-018-self-hosted-only.md). `LICENSE` and `NOTICE` (third-party material:
the Supabase compose files, the fonts, store badges, the GitHub mark and the Google "G")
are at the repository root.
