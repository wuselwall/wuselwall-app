# ADR-012 — Product name: WuselWall

**Status:** Accepted · 2026-10-11 · Amends [ADR-010](ADR-010-flutter-and-self-hosted-supabase.md) and [ADR-011](ADR-011-native-distribution-and-ci-cd.md) (identifiers)

## Context

The project ran under the working title *GoombaWall*. The household wanted a name that is
its own rather than generic, works for German and English speakers, can be said by a
seven-year-old, and fits under an app icon. The identifiers derived from the name
(bundle ID, deep-link scheme, Dart package, Supabase project) could still change cheaply:
no App Store Connect or Play Console record existed and nothing had been released.

A market check on 2026-10-11 (App Store, Google Play, web search) showed the category
crowded with *Fam-*, *Family-*, *Nest-* and *-Wall* names (FamilyWall, Famanice,
Famiverse, Familio, Fami, NestWard, NestBoard, Cozi, TimeTree, Skylight, Hearth).

## Decision

The application is called **WuselWall**. *Wuseln* is German for bustling about; the wall
is the kitchen display that shows the household's busy week at a glance.

| Identifier | Value |
|---|---|
| Display name (both locales, iOS, Android, web) | `WuselWall` |
| Application ID, bundle ID, auth deep-link scheme | `ch.wuselwall.app` |
| Dart package | `wuselwall` |
| Supabase project ID (local and dev stack) | `wuselwall` |
| Server user, deploy path, backup path | `wuselwall`, `/opt/wuselwall`, `/var/backups/wuselwall` |
| Domain-error code prefix | `WW-<MODULE>-<NNN>` |
| ICS extension property | `X-WUSELWALL-KIND` |
| Theme extension | `WwColors`, read with `context.ww` |

### Logo and mascot

*Added 2026-10-11*, chosen from the four concepts in
[docs/mockups/logo.html](../mockups/logo.html):

- **Logo and app icon: Wuselpunkte** (concept C). A W made of nine dots in the member
  colours, like magnets on the fridge or the "isst mit" dots on the board, with Tanne
  green at the centre peak and two small dots flying off to the top right. The app icon
  puts it on the paper ground (`#F7F4EE`); the night variant is on `#14171A`.
- **Mascot: Wuselchen** (concept B). A round Tanne-green critter with four tufts of hair
  in the family's colours and a "w" for a mouth. It is a character, not the logo. It
  appears where the app speaks to the household: empty states, a finished chore list,
  the children's register, and the sleepy night display. It never replaces the logo on
  an icon, a splash screen or the web title.

The source files are in [docs/brand/](../brand/): `wuselwall-mark[-dark].svg`,
`wuselwall-icon[-dark].svg`, the Android adaptive layers, and `wuselchen[-dark].svg`.
`npm run brand` (`scripts/brand-assets.js`) regenerates them and the PNGs in
`app/assets/icon/`. `dart run flutter_launcher_icons` in `app/` then rebuilds the iOS,
Android and web icons.

Below 40 px the dots stop reading as a W and become confetti. That is accepted: at that
size the colours alone still identify the app.

## Alternatives considered

| Name | Why not |
|---|---|
| Kuckuck | Google Meet's German UI uses it for a calling feature; Oetinger publishes a *Kuckuck* app |
| Tafelrunde | An education product (eduroundtable.de), restaurants and an agency use it; *Die Tafel* is the food-bank charity |
| Wimmel | Dozens of children's *Wimmel* apps |
| Nestwerk | Too close to NestWard and NestBoard |
| Siebenpunkt, Siebensachen, Wuselwoche | No conflicts found; WuselWall was preferred for being shorter and keeping continuity with the working title |

## Consequences

- A web search is not a trademark search. Check the DPMA and EUIPO registers and the
  `.de` domain at DENIC before the domain is bought ([Q1](../14-open-questions.md)).
- The *-Wall* suffix is shared with FamilyWall. Acceptable for an app with no public
  store listing.
- The dev Supabase stack runs under a new project ID, so its containers and volumes are
  new: the stack under the old ID (`supabase_*_goombawall`) has to be stopped and the
  new one started, which applies all migrations to an empty database.
- Device accounts created before the rename keep `@devices.goombawall.invalid`
  addresses; only the dev stack has any.
