# Market Research — Family Planners with Meal Planning

A survey of family organiser apps for the German-speaking market, prioritising products
that combine family planning (calendar, chores) **and** meal planning, with open-source and
self-hosted projects called out separately. Researched 2026-10-11.

Feature and price claims come mostly from vendor pages, store listings and project READMEs
as of that date, not from hands-on testing. A `?` marks a claim that could not be
confirmed. GitHub figures were read from the API on the same day.

## Feature matrix

Legend: ✓ yes · ◐ partial or paid only · – no · ? unconfirmed

| App | Calendar | Chores / tasks | Kid points / rewards | Recipes | Meal plan | Meal plan → shopping | Shopping list | German UI | Self-host / OSS | Price |
|---|---|---|---|---|---|---|---|---|---|---|
| **MyNestPlan** (DE) | ✓ | ✓ | ✓ | ✓ (15 free) | ✓ | ✓ | ✓ (by aisle) | ✓ | – | Free; €19.99 one-time |
| **FamilyWall** | ✓ | ◐ (lists) | – | ◐ | ◐ Premium | ◐ Premium | ✓ | ✓ | – | Free; Premium ≈ $5/month |
| **Famn** | ✓ (CalDAV) | ✓ | – | ✓ (URL / scan) | ✓ | ✓ | ✓ | ✓ (per listing) | – | Mostly free |
| **MomPlan** | ✓ | ✓ | – | ✓ | ✓ (AI) | ? | ✓ | ✓ | – | €4.99/month, €44.99/year |
| **AlltagsHeld** (DE) | ✓ | ✓ | – | ✓ | ✓ | ? | ✓ | ✓ | – | Free, iPhone only |
| **FamCal** | ✓ | ✓ | – | ✓ | ◐ (on calendar) | ✓ | ✓ | ? | – | ≈ $27/year |
| **Cozi** | ✓ | ◐ (lists) | – | ✓ | ✓ | ✓ | ✓ | **–** (English only) | – | Free; Gold €34.99/year |
| **Maple** | ✓ | ✓ | – | ✓ | ✓ (AI) | ✓ (Instacart) | ✓ | – | – | $9.99/month |
| **Yuvomi** | ✓ (2-way CalDAV) | ✓ | ✓ | ✓ (Mealie / Tandoor mirror) | ✓ | ✓ | ✓ (by aisle) | ✓ | **MIT, self-hosted** | Free |
| **Tribu** | ✓ (CalDAV / CardDAV) | ✓ | ✓ (stars) | ✓ | ✓ | ✓ | ✓ | ✓ | **MIT, self-hosted** | Free |
| **Pinn** | ✓ | ✓ (kids' page) | ◐ (pocket money) | ? | ✓ | ? | ✓ | ✓ | **MIT, self-hosted** | Free |
| **Homechart** | ✓ | ✓ | – | ✓ | ✓ | ✓ | ✓ | ✓ | ◐ (source-available) | Hosted subscription |
| **OpenFamily** | ✓ (iCal export) | ✓ | – | ✓ | ✓ | ? | ✓ | **–** | **AGPL-3.0, self-hosted** | Free; cloud €3.90/month |
| **Grocy** | ✓ (iCal) | ✓ | – | ✓ | ✓ | ✓ | ✓ | ✓ | **MIT, self-hosted** | Free |

## Group A — commercial, family and meals in one app

**MyNestPlan** — the closest commercial match for the German market.

- Pros: covers every column — calendar, chores with points and levels, recipes, a weekly
  meal plan that feeds the shopping list, school and Kita times, a tablet dashboard for the
  hallway. Servers in Germany, no trackers. Premium is a one-time €19.99 per family.
- Cons: a one-person project. The free tier is capped (6 members, 15 recipes); leaderboard,
  badges and the hallway dashboard are paid.

**FamilyWall**

- Pros: established and fully German. The free tier is ad-free with messenger, lists and a
  calendar filterable by person.
- Cons: the meal planner and the meal-plan-to-shopping link are Premium only. Recipe import
  is reported to be unreliable. No chore rewards.

**Famn**

- Pros: calendar sync over CalDAV/WebDAV, so it works against self-hosted servers — rare in
  this group. Recipe import by URL or camera, one-tap shopping list, recurring chores with a
  history of who did what.
- Cons: German support rests on the store listing alone; no independent reviews found.

**MomPlan**

- Pros: broad scope — AI meal week, budget, chores, calendar, family chat.
- Cons: single developer, 2 ratings on the German App Store, subscription only, marketed
  squarely at mothers.

**AlltagsHeld**

- Pros: free, German-made, built for families and shared flats (WGs), with practical extras
  such as a cleaning plan and a sick-day log for children.
- Cons: iPhone only (Android in testing), 9 ratings.

**FamCal**

- Pros: recipes go straight to the shopping list; children need no email address.
- Cons: the family shares one login. A complete German UI could not be confirmed.

**Cozi and Maple** lead the US market but have **no German UI**. Maple's grocery
integration (Instacart) is US-only. Cozi remains the reference that open-source projects
measure themselves against.

## Group B — open-source and self-hosted

**Yuvomi** — the strongest project in this group and the closest match to WuselWall.

- Pros: every column in the matrix, including tasks that pay out points, a parent-approved
  reward catalogue, meal plan → shopping list, budget and two-way CalDAV. 26 UI languages
  including German. MIT, ≈ 1,700 stars, very active (≈ 4,250 commits since March 2026).
  Optional SQLCipher encryption.
- Cons: PWA only, no native apps. Plain JavaScript and SQLite. 118 open issues; the project
  is seven months old.

**Tribu**

- Pros: two-way CalDAV/CardDAV including chores as VTODO, school timetables, a shared
  kitchen-tablet display, stars as rewards, recipe-to-shopping handoff, Home Assistant, a
  German translation. MIT; Next.js, FastAPI and Postgres.
- Cons: 23 stars — effectively one maintainer.

**Pinn**

- Pros: designed for a NAS, with PIN-protected family profiles, an iPad overview and pocket
  money. German UI and README. MIT, built on PocketBase.
- Cons: created 2026-10-07.

**Grocy**

- Pros: the mature option — since 2017, ≈ 9,600 stars, German translation. Chores, a meal
  plan that puts missing products on the shopping list, stock tracking, an iCal feed.
- Cons: a household ERP rather than a family app. Not suitable for children, no rewards,
  web only.

**Homechart**

- Pros: calendar, meals, chores and budget; designed for extended and blended families;
  German UI.
- Cons: not really open source — the public GitHub repository holds only a README.

**OpenFamily**

- Pros: AGPL-3.0, a solid stack (React, Postgres), an Android APK, optional hosted cloud.
- Cons: **no German**, no rewards.

## Group C — one side only (context)

- **Meals only, open source, German UI:** **Mealie** (≈ 13,500 stars, AGPL) — the best
  recipe and meal-plan tool, often paired with something else; **Tandoor** (≈ 8,700 stars);
  **KitchenOwl** (≈ 3,700 stars, AGPL) — Flutter with native apps, household expenses.
- **Chores only, open source:** **Donetick** (≈ 2,600 stars, AGPL).
- **Family only, German:** **Famanice** — German UI only, strong school feature (homework,
  timetables and exams shared per class), no meals.
- **Commercial meals and shopping:** Bring!, Choosy, Smartteller.
- **Wall displays:** **Skylight** and **Hearth** offer meal planning only with a
  subscription and are built for the US (Hearth specifies 110–120 V). Sales in Germany could
  not be confirmed.

## Implications for WuselWall

- **The commercial market has a gap.** No commercial app combines a German UI, chores with
  kid rewards, a meal plan that feeds the shopping list, and data under the family's own
  control. MyNestPlan comes closest, but it is closed source and cloud-hosted.
- **The open-source field changed in 2026.** Yuvomi, Tribu and Pinn all appeared this year
  and already cover most of what [ADR-002](adr/ADR-002-build-vs-assemble.md) cites as the
  reason to build rather than assemble: one identity, points across modules, and meal plan
  → shopping list. What still sets WuselWall apart:
  - native Flutter apps instead of a PWA ([ADR-010](adr/ADR-010-flutter-and-self-hosted-supabase.md));
  - a UI register suitable for a seven-year-old ([09](09-clients-and-ux.md));
  - a shared kiosk device with guardian roles ([08](08-users-auth-permissions.md));
  - one MCP and assistant surface over everything ([12](12-mcp-and-assistants.md));
  - Supabase with RLS as the security perimeter ([11](11-security-and-privacy.md)).
- Yuvomi deserves a hands-on look before M1, at least as a source of ideas, and possibly a
  note in ADR-002.

## Sources

- [MyNestPlan](https://mynestplan.de/)
- [FamilyWall Premium](https://support.familywall.com/en/support/solutions/articles/47001239196)
- [heise — Familienkalender-Apps](https://www.heise.de/tipps-tricks/Familienkalender-Apps-diese-gibt-s-7549456.html)
- [Mailfence — Familienkalender-Apps](https://blog.mailfence.com/de/beste-familienkalender-app/)
- [Smartteller — Essensplaner-Apps](https://smartteller.de/essensplaner-apps-vergleich/)
- App Store: [Cozi](https://apps.apple.com/de/app/id407108860),
  [MomPlan](https://apps.apple.com/de/app/momplan/id6755446969),
  [Famanice](https://apps.apple.com/de/app/famanice/id806214101),
  [AlltagsHeld](https://apps.apple.com/de/app/alltagsheld/id6468967570),
  [FamCal](https://apps.apple.com/app/apple-store/id1098999871),
  [Famn](https://apps.apple.com/app/id1585619579),
  [Maple](https://apps.apple.com/us/app/maple-family-organizer/id1551070188)
- Open source: [Yuvomi](https://github.com/ulsklyc/yuvomi),
  [Tribu](https://github.com/itsDNNS/tribu),
  [Pinn](https://github.com/pinn-shost/pinn),
  [OpenFamily](https://openfamily.fr/),
  [Grocy](https://github.com/grocy/grocy),
  [KitchenOwl](https://github.com/TomBursch/kitchenowl),
  [Mealie](https://github.com/mealie-recipes/mealie),
  [Tandoor](https://github.com/TandoorRecipes/recipes),
  [Donetick](https://github.com/donetick/donetick),
  [Homechart](https://github.com/candiddev/homechart)
- [Hearth Display](https://hearthdisplay.com/pages/features)
