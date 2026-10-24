# 21 — Household settings and curated defaults

*Added 2026-10-11.* The specification was written against one real family, and many of
its "leanings" were really that family's answers: two children aged 7 and 9, Berlin
schools, a shift rota, a warm meal at dinner on school days. This document separates the
product from the household it was first designed for:

> Every choice that one household would answer differently from another is a **setting
> with a curated default**, never a constant in code and never an assumption in a spec.

A household that changes nothing gets a carefully reasoned setup. A household that
differs changes a setting rather than waiting for a release.

## The reference household

The specs, mockups, demo build (`app/lib/main_demo.dart`), documentation screenshots and
`supabase/seed.sql` all use one example household:

| Member | Role | Example of |
|---|---|---|
| **David** | guardian | an adult with a home-office baseline who travels for work at short notice |
| **Sarah** | guardian | an adult on a shift rota that repeats but is revised monthly |
| **Olivia**, 9 | member | an older child: reads fluently, understands saving up points |
| **Jack**, 7 | member | a younger child: icon-led, needs quick rewards and forgiving streaks |

They live in Berlin, and the children go to two different schools. When a spec says
"Sarah's Dienstplan", read it as "a rota like the reference household's". Nothing in
code, schema or tests may depend on the number of members, their ages, their roles
beyond `guardian`/`member`, the region or the schools.

## What is a setting, and what is not

| Kind | Example | Where it lives |
|---|---|---|
| **Identity of an entity** | household name, timezone; a member's name, role, colour, birthday, baseline presence | Typed columns on `household` and `profile`, as today ([04](04-data-model.md#identity)) |
| **A tuning of behaviour** | points for a new duty, joker days, week-board rollover, night hours | A **setting**, below |
| **Starter content** | five starter chores, three rewards, shopping lists and categories, a subject list | Ordinary rows, offered when the household is created (J1) and owned by the household from then on |
| **A design rule** | no negative points, no leaderboard, six presence states | Fixed. Listed at the end so it is not re-asked as a setting |

Starter content differs from a default in one way: once created, it is the household's
data. Improving the starter set later does not touch households that already exist.
Improving a *default* does reach every household that never changed it (see below).

## Model

```
setting_definition               -- the catalogue, written by migrations only
  key TEXT PRIMARY KEY,                         -- 'tasks.jokers_per_month'
  scope ENUM('household','member','device'),
  type ENUM('boolean','integer','time','enum','weekday_time','time_range'),
  default_value JSONB,                          -- the curated default
  constraints JSONB,                            -- {min, max} or {values: [...]}
  since_migration TEXT

household_setting                -- only what a household changed
  household_id, key → setting_definition,
  profile_id NULL, device_id NULL,              -- set for member and device scope
  value JSONB, updated_at, updated_by_profile_id
  UNIQUE (household_id, key, profile_id, device_id)
```

- **An unchanged setting has no row.** The effective value is the row's value if one
  exists, otherwise the definition's default. A better default shipped in a migration
  therefore reaches every household that never touched the setting. Households that did
  change it keep their own value.
- `api.settings` (a `security_invoker` view) returns every definition with its
  effective value and an `is_default` flag. The settings screen uses that flag to show
  "Standard" or "angepasst" and to offer **reset to default**.
- `api.set_setting(p_actor, p_key, p_value, p_profile_id, p_device_id)` validates the
  value against the definition's type and constraints, and raises `WW-SET-001` when it is
  out of range. `api.reset_setting(...)` deletes the row. Household-scope and device-scope
  writes are guardian actions with PIN step-up. A member may change their own
  member-scope settings where the catalogue marks them *self*.
- Both functions write an audit row, like every other write.
- **Why rows of JSON and not one typed column per setting:** each new setting would be an
  `ALTER TABLE`, and "is this still the default?" could no longer be answered. The
  definition table keeps type checking in SQL, and pgTAP asserts that every default
  satisfies its own constraints.
- Every setting has a one-line explanation in both ARB files, shown under the control.
  The *Context* column below is the source for that line.

## Household creation

How a household starts is [20 — Onboarding, J1](20-onboarding.md#j1--start-a-family):
family name, the founder's own name, the other members, with timezone and locale from the
device. This spec adds **nothing to ask** there, only three rules:

1. Everything not asked starts at its curated default and is changed under Einstellungen.
2. **Region** (`household.region`) is not asked at creation. It drives the school holidays
   and the public holidays, so it is asked when the first school is added, with the country
   prefilled from the device locale.
3. J1's starter examples are the **starter content** below, each set on by default and
   removable: shopping lists with categories, starter chores, starter rewards, starter
   badges. The subject list is offered when the first school is added.

## Catalogue of curated defaults

Status: **proposed** until confirmed in the defaults issue
([#10](https://github.com/wuselwall/wuselwall-app/issues/10)). A row marked
**decided** was settled in [14](14-open-questions.md). *Scope* says who the setting
belongs to; *self* means a member may change it for themselves.

### Household and members

| Key | Scope | Default | Range | Context | Source |
|---|---|---|---|---|---|
| `household.region` | household | asked with the first school, country from the device | region picker: any OpenHolidays subdivision (`DE-BE`, `AT-NÖ`, `CH-ZH-ZH-ZH`, `LI`) | Proposes the timezone; the public holidays of the region apply automatically, and Ferien are imported from it. Changeable under Einstellungen. Hand-entered holidays work in any region. *Decided 2026-10-14* | Q18 |
| `board.member_label` | household | full name | name · initial | The kitchen is private, and a name is easier to read than an initial at two metres. A household with frequent visitors may prefer initials | Q27 |
| `member.completion_sound` | member, self | on | on · off | Ticking a chore off makes a short sound. The sound is part of the motivation for a young child; a child may switch it off | [06](06-module-tasks.md#screens) |

### Tasks and gamification (M1.2)

| Key | Scope | Default | Range | Context | Source |
|---|---|---|---|---|---|
| `tasks.points.duty_default` | household | 1 | 0–3 | Duties are expected of everyone, so they earn little or nothing. The streak is their reward. Paying well for everything teaches that unpaid help is not a thing | Q4 [#6](https://github.com/wuselwall/wuselwall-app/issues/6), Q5 [#7](https://github.com/wuselwall/wuselwall-app/issues/7) |
| `tasks.points.bonus_default` | household | 5 | 1–50 | One bonus task buys the cheapest starter reward. That keeps the reward within days for a younger child | Q4 [#6](https://github.com/wuselwall/wuselwall-app/issues/6) |
| `tasks.kind_default` | household | duty | duty · bonus | A new chore is a duty unless someone deliberately makes it a bonus. That keeps the earning surface narrow | Q5 [#7](https://github.com/wuselwall/wuselwall-app/issues/7) |
| `tasks.verification_default` | household | off | on · off | Verification turns every chore into an inspection, so use it only on high-value bonus tasks | [06](06-module-tasks.md#verification) |
| `tasks.jokers_per_month` | household, overridable per member | 1 | 0–5 | Per streak, per calendar month, used automatically. One sick day must not wipe out a three-week streak. A younger child can be given more | Q7 [#9](https://github.com/wuselwall/wuselwall-app/issues/9) |
| `tasks.reward_approval_default` | household | required | required · self-serve | A guardian approves each redemption with the PIN. Self-serve suits only trivial rewards | [06](06-module-tasks.md#rewards) |

Points never convert to money in v1 (Q6, proposed in [#8](https://github.com/wuselwall/wuselwall-app/issues/8)). That is a design rule rather than a
setting, and allowance payouts stay in M4.

<a id="starter-content"></a>**Starter content.** Five chores:

| Chore | Kind | Assignment | Points |
|---|---|---|---|
| Tisch decken | duty | rotating, daily | 1 |
| Spülmaschine ausräumen | duty | rotating, daily | 1 |
| Zimmer aufräumen | duty | each, Saturdays, with verification | 2 |
| Müll rausbringen | bonus | open, weekly | 5 |
| Beim Kochen helfen | bonus | open, weekly | 8 |

Three rewards: *Samstagsfilm aussuchen* (5), *15 Minuten länger aufbleiben* (15) and
*Ausflug nach Wahl* (50), in the 1 : 3 : 10 ratio. Four badges: first chore, a 7-day
streak, 25 chores, 100 points.

### Calendar, presence and school (M1.3)

| Key | Scope | Default | Range | Context | Source |
|---|---|---|---|---|---|
| `calendar.members_edit_own_events` | household | on | on · off | Children create and edit events they attend themselves ("Kindergeburtstag bei Ben"). Deleting someone else's event stays a guardian action | Q8 **decided** |
| `calendar.key_default` | household | whole-family events | whole-family · all · none | Decides which new events go on the kitchen board without anyone ticking the box. Review after two weeks of use | Q25 |
| `calendar.tentative_nudge` | member, self | 19:00 the evening before | time | Asks the owner whether a tentative entry is happening ("Fährst du morgen …?"), so it does not stay uncertain until it starts | [15](15-module-school-timetable.md#flexible-and-uncertain) |
| `school.members_report_changes` | household | off | on · off | Only guardians maintain the timetable and enter Entfall or Vertretung. A child's report goes through a parent | Q23 **decided** |
| `school.equipment_hint` | household | on | on · off | Shows "Morgen brauchst du: Sportsachen" from tomorrow's subjects (FR-7.12) | FR-7.12 |

**Defaults for a new feed token** apply per token when it is created:

| Kinds | Presence | School | Chores |
|---|---|---|---|
| appointments only | off | off | off |

Turning any of these on is one deliberate checkbox on that token
([05](05-module-calendar.md#url-and-authentication)). These defaults settle Q9 and Q24.

**Starter content when a school is added:**

- A **bell-time template**: 45-minute Stunden from 08:00, a 20-minute break after the
  2nd and the 4th, 5 minutes otherwise. Edited to match the school's sheet.
- A **subject list** with colours and icons, following the school's region (*added
  2026-10-14, lists revised 2026-10-23 after the research in
  `specs/research/school-subjects/`*). Names and short names are the ones the region's
  sheets print, so a scanned sheet matches them:
  - **Germany** (and any country without a list of its own): Deutsch D, Mathematik Ma,
    Sachunterricht SU, Englisch E, Musik Mu, Kunst Ku, Werken We, Religion/Ethik Rel,
    Förderunterricht Fö; Sport Sp and Schwimmen Sw, which are notable by default and carry an
    equipment note;
  - **Austria** (the names of 2023/24): Deutsch D, Mathematik M, Sachunterricht SU, Englisch E,
    Kunst und Gestaltung KuG, Musik Mu, Technik und Design TD, Religion Rel, Förderunterricht
    FU, Bewegung und Sport BS (notable, Sportsachen);
  - **German-speaking Switzerland and Liechtenstein** (Lehrplan 21 fields): Deutsch D,
    Mathematik M, Natur, Mensch, Gesellschaft NMG, Englisch E, Französisch F, Bildnerisches
    Gestalten BG, Textiles und Technisches Gestalten TTG, Musik Mu, Bewegung und Sport BS
    (notable, Sportsachen), Medien und Informatik MI;
  - **Romandie** (GE, VD, NE, JU, and a bilingual canton when the app runs in French; PER
    fields): Français FRA, Mathématiques MAT, Allemand ALL, Anglais ANG, Sciences de la nature
    SCN, Histoire HIS, Géographie GEO, Arts visuels AVI, Activités créatrices manuelles ACM,
    Musique MUS, Éthique et cultures religieuses ECR, Éducation physique EPH (notable);
  - **Ticino** (and a bilingual canton when the app runs in Italian): Italiano ITA, Matematica
    MAT, Tedesco TED, Francese FRA, Studio d'ambiente AMB, Educazione visiva EVI, Educazione
    alle arti plastiche APLA, Educazione musicale EMU, Educazione fisica EFI (notable);
  - **France**: Français FR, Mathématiques MATHS, Anglais ANG, Questionner le monde QLM,
    Sciences et technologie SCI, Histoire-géographie HG, Enseignement moral et civique EMC,
    Arts plastiques ARTS, Éducation musicale EM, EPS (notable) and Natation NAT (notable);
  - **Spain**: Lengua Castellana y Literatura LCL, Matemáticas MAT, Inglés ING, Conocimiento
    del Medio CM, Educación Plástica y Visual PLAS, Música MUS, Religión REL, Atención
    Educativa AE, Valores Cívicos y Éticos VCE, Tutoría TUT, Educación Física EF (notable);
    Navarra adds Euskara eta Literatura EUS. The regions whose sheets print the co-official
    language get the list in that language (*revised 2026-10-23 after real sheets*):
    **Catalonia, the Balearics and Valencia** in Catalan (Llengua Catalana i Literatura CAT,
    or Valencià: Llengua i Literatura VAL in Valencia; Llengua Castellana CAST, Matemàtiques
    MAT, Anglès ANG, Coneixement del Medi MEDI, Educació Plàstica PLAS, Música MUS, Religió REL,
    Valors VALORS, Tutoria TUT, Lectura LECT, Educació Física EF), the **Basque Country** in
    Basque (Euskara EUS, Gaztelania GAZT, Ingelesa ING, Matematika MAT, Ingurunea INGU, Musika
    MUS, Plastika PLAS, Erlijioa REL, Balio Zibiko eta Etikoak BAL, Tutoretza TUT, Gorputz
    Hezkuntza GH), **Galicia** in Galician (Lingua Galega LG, Lingua Castelá LC, Matemáticas
    MAT, Inglés ING, Coñecemento do Medio CM, Plástica PLAS, Música MUS, Relixión REL,
    Alternativa ALT, Valores Sociais e Cívicos VSC, Titoría TIT, Educación Física EF).
  A country without a list follows the app's language (French or Spanish, else German). The
  app sends its language with the school (`language` in `school_save`); the previous app
  release sends none and gets the German, Austrian or Swiss German list. The list is written
  only into an empty subject list, and the family renames or removes any of it. Starter
  content is example data, not a rule of the module.
- A new timetable is `weekly`. A/B weeks are switched on per timetable.
- Hort and Betreuung are `care` rows on the timetable, not presence entries (Q22,
  decided).

### Meals (M1.4)

| Key | Scope | Default | Range | Context | Source |
|---|---|---|---|---|---|
| `meals.warm_meal.school_day` | household | dinner | lunch · dinner | The one warm meal on the board. On school days children eat lunch at school or Hort | FR-8.4 |
| `meals.warm_meal.free_day` | household | lunch | lunch · dinner | Weekends and holidays | FR-8.4 |
| `meals.away_means_not_eating` | household | on | on · off | `travel` or `away` presence over the meal's slot marks that member as not eating, so most days need no input | [07](07-module-meals-shopping.md#views) |
| `meals.care_lunch_cutoff` | household | 14:00 | time | A child whose care row runs past this time is out for lunch | [07](07-module-meals-shopping.md#views) |

*Added 2026-10-14, no new setting:* a public holiday of the household's region counts as a free day for the warm meal (`meals.warm_meal.free_day`), and the meal suggestions ("Oft bei uns", "Lange nicht gegessen", after 90 and 60 days) need no setting either.

### Shopping

**Starter content:** three lists, each with its own categories:

- **Supermarkt**, the default list and the only one on the wall: Obst & Gemüse, Brot &
  Backwaren, Kühlregal, Fleisch & Fisch, Vorrat, Getränke, Tiefkühl, Haushalt.
- **Drogerie:** Körperpflege, Gesundheit, Baby & Kind, Putzmittel.
- **Baumarkt:** Werkzeug, Elektro, Garten, Farbe.

Lists can be renamed, added and removed, and any of them can become the default.
Children may add items (Q30) and the wall may add items by tile (Q33); both are design
rules, not settings.

### The kitchen display

| Key | Scope | Default | Range | Context | Source |
|---|---|---|---|---|---|
| `board.rollover` | household | Saturday 12:00 | weekday + time | When the board moves to the coming week. Sunday-evening planning wants next week; Saturday morning still wants this week | Q26 |
| `board.day_parts` | household | 12:00 · 17:00 | two times | Where the appointment zone splits morning, afternoon and evening | [09](09-clients-and-ux.md#the-zones) |
| `device.night_hours` | device | 21:00–06:00 | time range | When the kiosk switches to the amber night theme | [17](17-design-system.md) |
| `device.idle_revert_seconds` | device | 60 | 30–300 | How long a tapped profile or detail view stays open before the kiosk returns to the board | [08](08-users-auth-permissions.md#profile-switching-ux) |

Member order on the board is `profile.sort_order`. New members are appended, and the
order can be changed by dragging.

### Notifications

| Key | Scope | Default | Range | Context | Source |
|---|---|---|---|---|---|
| `notify.morning_summary` | member, self | on, 07:00 | off · time | Today's tasks and events for that member. Pending redemptions appear here for guardians | Q13 |
| `notify.event_reminder` | member, self | off | off · 5–120 min | A push before an event starts | Q13 |
| `notify.packing_reminder` | member, self | on, 19:00 | off · time | *Added 2026-10-16.* "Für morgen einpacken" the evening before a school day with equipment, a local notification: every child's things on an adult's phone, a child's own on theirs. Off with `school.equipment_hint` | FR-7.12 |
| `notify.task_verified` | member, self | off | on · off | A push when a guardian verifies a chore and points are credited | Q13 |
| `notify.redemption_request` | member, self (guardians) | off | on · off | An immediate push when a child requests a reward | Q13 |

Over-notifying in week one trains a family to ignore the app, so everything except the
morning summary is opt-in.

### A lighter day

*Added 2026-10-24 with [ADR-020](adr/ADR-020-a-lighter-day.md); not built.* Every ritual is
on by default, because the M1.6 trial judges them ([27](27-family-rituals.md#how-the-trial-judges-the-rituals))
and a default that is off cannot be judged. Einstellungen → Familie → *Rituale* groups the
household rows, and the member and device rows sit with Appearance. The **Basic** view of
[09](09-clients-and-ux.md#screens-by-register) gains `member.wusel` (switching Wusel off must
be easy to find), `rituals.table_question`, `meals.wishes` and `rituals.week_review`.
Everything else here is under **Erweitert**, including each occasion and the pixel shift.

| Key | Scope | Default | Range | Context | Source |
|---|---|---|---|---|---|
| `member.wusel` | member, self | children `lively`, adults `quiet` | lively · quiet · off | How present Wusel is for this member. *Quiet* means static, and only in empty states and on special days | [25](25-wusel.md#settings) |
| `member.wusel_outfit` | member, self | none | none · one of eight | What Wusel wears for this member. Free from the start, never earned | [25](25-wusel.md#outfits) |
| `device.wusel` | device | lively | lively · quiet · off | Wusel on a wall or shared device while no member is active | [25](25-wusel.md#settings) |
| `device.sounds` | device | kiosk off, others on | on · off | Silences a device; `member.completion_sound` still governs the member. Never at night | [26](26-colour-and-ambience.md#sound-and-haptics) |
| `ambience.occasions` | household | by country of `household.region`: season, birthday and Ferien everywhere; Advent and Western Ostern where the region's Easter is Western; Orthodox Ostern where it is Orthodox | one switch per occasion | Which dates decorate the wall and the Today header. Easter is computed each year, Western and Orthodox separately. *Decided 2026-10-24* | [26](26-colour-and-ambience.md#defaults-per-country), Q52 |
| `device.pixel_shift` | device | kiosk on, others off | on · off | Shifts the whole screen by up to 2 px every 10 minutes against OLED burn-in. The OS's own protection does not cover a static full-screen app. *Decided 2026-10-24* | [26](26-colour-and-ambience.md#protecting-the-wall), Q54 |
| `ambience.sky` | device | on | on · off | The time-of-day sky behind the board's and Today's header | [26](26-colour-and-ambience.md#day-phases) |
| `rituals.countdown_days` | household | 14 | 7–60 | How far ahead Vorfreude starts counting | [27](27-family-rituals.md#vorfreude) |
| `rituals.countdown_return` | household | on | on · off | "Papa ist in 2× schlafen zurück" for an adult's travel of two nights or more | [27](27-family-rituals.md#vorfreude) |
| `meals.wishes` | household | children | children · everyone · off | Who may wish a meal | [27](27-family-rituals.md#wunschessen) |
| `meals.wishes_per_week` | household | 1 | 1–3 | Open wishes per member | [27](27-family-rituals.md#wunschessen) |
| `rituals.table_question` | household | warm meal | warm meal · every main meal · off | When the Tischfrage appears | [27](27-family-rituals.md#tischfrage) |
| `rituals.table_question_times` | household | lunch 11:30–13:30 · dinner 17:30–19:30 | two time ranges | The meal windows; there are no meal times anywhere else | [27](27-family-rituals.md#tischfrage) |
| `rituals.table_question_deck` | household | Familie | Familie · Ältere | *Ältere* adds questions for 8 and over | [27](27-family-rituals.md#tischfrage) |
| `rituals.table_question_hidden` | household | none | list of question ids | Bundled questions this family does not want | [27](27-family-rituals.md#tischfrage) |
| `rituals.week_review` | household | Sunday 16:00 – Monday 10:00 | weekday + time range · off | When "Unsere Woche" appears | [27](27-family-rituals.md#wochenrückblick) |

## Fixed by design — not settings

Recorded so that nobody turns these into options:

- No negative points, no leaderboard and no comparison between siblings ([06](06-module-tasks.md)).
- Wusel is never sad, never speaks in a notification and never appears in a capture flow;
  outfits are never earned ([25](25-wusel.md)). No ritual creates a task, a streak or a
  "missed" state ([27](27-family-rituals.md#rules-every-ritual-follows)).
- The points ledger, the snapshot of points onto instances, and approval before a debit.
- The guardian PIN: 6 digits, a 15-minute window, and a lockout after 10 failures
  ([08](08-users-auth-permissions.md)).
- Enrolment codes are single use and expire after 10 minutes.
- The six presence states ([15](15-module-school-timetable.md#presence-states)) and the
  four assignment policies.
- The UI register belongs to the device, never to a screen width.
- DE/EN/FR/ES, with device regional variants accepted; German for any unsupported device
  language (NFR-14). A new family stores `de-DE`, `en-GB`, `fr-FR` or `es-ES`. Email language is
  not a household setting: it is selected once for the server installation. The week starts on
  Monday.
- The task materialiser's 14-day horizon.
