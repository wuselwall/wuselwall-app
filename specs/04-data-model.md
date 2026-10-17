# 04 — Data Model

Conceptual model. Column lists are indicative, not a migration script — but the
invariants at the end are binding.

Conventions across every table: tables live in the `app` schema and are reached by
clients only through `api` views and functions ([03](03-architecture.md#repository-layout)); `id` is a UUIDv7 (time-sortable, safe to generate
client-side for idempotency), `household_id` is present on every domain table,
`created_at` / `updated_at` are `timestamptz`, and soft deletion uses `deleted_at`
only where undo matters (events, shopping items) — everywhere else, delete for real.

---

## Identity

```
household
  id, name, timezone, locale,                    -- timezone/locale from the founder's device
  created_by_profile_id, created_at,
  deleted_at NULL,                               -- J6: purged 14 days later
  -- the household's region is the setting household.region (21), not a column: an OpenHolidays
  -- subdivision code of any depth, e.g. 'DE-BE' or 'CH-ZH-ZH-ZH'; asked with the first school.
  -- Added 2026-10-14.

setting_definition               -- the catalogue of settings and curated defaults,
  key, scope, type, default_value JSONB,        -- written by migrations only; see
  constraints JSONB                             -- 21 — Household settings

household_setting                -- only what a household changed from the default
  household_id, key, profile_id NULL, device_id NULL,
  value JSONB, updated_at, updated_by_profile_id

profile                          -- a family member
  id, household_id, display_name, short_name, avatar_key, colour_hex,
  role ENUM('guardian','member'), birthday DATE NULL,
  kind ENUM('adult','child'),                   -- ADR-014: role says what you may do,
                                                -- kind whether you can have an account;
                                                -- a guardian is always an adult
  default_presence_state ENUM(...) NULL,        -- the baseline: 'home_office' for one
  default_presence_label TEXT NULL,             -- adult, 'off' for the other. FR-1.18
  pin_hash NULL, pin_failed_count, pin_locked_until,
  auth_user_id → auth.users NULL UNIQUE,         -- the adult's account; NULL for children
                                                 -- and for adults without one. UNIQUE =
                                                 -- one household per account (Q43)
  is_active, sort_order
  (credentials, identities — email, password, passkeys — sessions and MFA
   factors live in Supabase's own auth schema)

device
  id, household_id, label,                       -- "Kitchen display", "Papa iPhone"
  class ENUM('personal','shared','kiosk'),
  bound_profile_id NULL,                         -- set for class='personal'
  ui_register ENUM('adult','kid','kiosk'),
  auth_user_id → auth.users,                     -- the device's own Auth user;
                                                 -- for an adult's personal device,
                                                 -- the adult's Auth user …
  auth_session_id NULL,                          -- … and the session it is bound to
  guardian_verified_until timestamptz NULL,      -- PIN step-up, server-side only
  enrolled_at, last_seen_at, revoked_at,
  push_platform ENUM('apns','fcm') NULL, push_token TEXT NULL

enrolment_code                   -- M0.1 direction; kept one release after pairing ships
  id, household_id, code_hash, label, class, register, created_by,
  expires_at, consumed_at

pairing_request                  -- J3: the new device asks, a guardian approves (ADR-014)
  id, code_hash,                                 -- the 8-character display code
  secret_hash,                                   -- only the requesting device knows it
  client_ip, created_at, expires_at,             -- 10 minutes
  approved_at NULL, approved_by_profile_id NULL,
  household_id NULL, label NULL, class NULL, register NULL, bound_profile_id NULL,
  claimed_at NULL, device_id NULL

invitation                       -- J2: an adult joins a household
  id, household_id, profile_id,                  -- the profile the invitee will become
  role ENUM('guardian','member'),
  email NULL,                                    -- matched against verified addresses
  token_hash, code_hash,                         -- link token (128 bit) and typed code
  created_by_profile_id, created_at, expires_at, -- 7 days
  accepted_at NULL, accepted_by_auth_user NULL, revoked_at NULL

getting_started_dismissal        -- items are derived from data; only "not needed" is stored
  household_id, item_key, profile_id NULL,       -- NULL = for the whole household
  device_id NULL, dismissed_at

notice_dismissal                 -- notices (join, new sign-in) are derived from audit_log and
  id, household_id, profile_id,                  -- device rows (specs/20 J2, J4); only "Gesehen"
  notice_key, dismissed_at                       -- is stored, per profile; unique (profile_id, key)

instance_setting                 -- one row per instance, not per household
  household_creation ENUM('code','open')         -- 'code' until the opening gate

setup_token                      -- the founder codes in 'code' mode (old name kept)
  token_hash, created_at, consumed_at, consumed_by_household NULL

audit_entry                      -- append-only, never updated or deleted
  id, household_id, occurred_at,
  actor_profile_id, device_id NULL, origin, on_behalf_of JSONB NULL,
  entity_type, entity_id, action, diff JSONB
```

Tunable behaviour — point defaults, jokers, rollover, night hours, notification
defaults — is never a column: it is a setting with a curated default, resolved as the
override row if one exists and the definition's default otherwise
([21](21-household-settings.md#model)). Columns hold what identifies an entity.

## Calendar

```
calendar
  id, household_id, name, colour_hex, kind ENUM('local','imported'),
  source_url NULL, last_polled_at NULL          -- kind='imported' only

event
  id, household_id, calendar_id, title, description, location,
  kind ENUM('appointment','presence'),          -- FR-1.11
  presence_state ENUM('working','home_office','travel',
                      'away','off','childcare') NULL,   -- kind='presence' only
  status ENUM('confirmed','tentative','cancelled'),     -- ICS STATUS, FR-1.15
  busy_until TIME NULL,                         -- "Termine bis 17:00", FR-1.19
  importance ENUM('normal','key'),              -- 'key' → the kiosk week board, FR-1.16
  starts_at timestamptz NULL, ends_at timestamptz NULL,   -- timed events
  start_date DATE NULL, end_date DATE NULL,               -- all-day events
  is_all_day BOOLEAN,
  timezone TEXT,                                -- IANA, e.g. 'Europe/Berlin'
  rrule TEXT NULL,                              -- RFC 5545 RRULE
  rdates DATE[] NULL,                           -- RFC 5545 RDATE — the tap-the-days rota
  exdates DATE[] NULL,
  uid TEXT,                                     -- stable ICS UID, never changes
  sequence INT,                                 -- ICS SEQUENCE, bumped on edit
  created_by_profile_id, deleted_at NULL

event_attendee
  event_id, profile_id, PRIMARY KEY (event_id, profile_id)

event_override                   -- one modified or cancelled occurrence
  id, event_id, recurrence_id timestamptz,      -- the original occurrence start
  is_cancelled BOOLEAN,
  title NULL, starts_at NULL, ends_at NULL, location NULL

calendar_feed_token
  id, household_id, label,                      -- "Work laptop Outlook"
  token_hash, filter JSONB,                     -- {profileIds:[], calendarIds:[],
                                                --  kinds:['appointment'],
                                                --  school:'off'|'day'|'lessons'}
  created_at, last_fetched_at, fetch_count, revoked_at

shortcut_token                                  -- Siri and Shortcuts (specs/12), added 2026-10-16
  id, household_id, profile_id,                 -- the person the key acts as
  label, token_hash,                            -- "iPhone"; "wws_…" shown once
  created_by_profile_id, created_at,
  last_used_at, use_count,
  writes_on DATE, writes_count,                 -- the daily write cap (100)
  revoked_at                                    -- also set when the holder leaves or the family is deleted
  kind                                          -- 'shortcut' ("wws_…", reads and adds) or 'assistant'
                                                --  ("wwa_…", MCP family:read, adults only), added 2026-10-16
```

`event` deliberately stores **both** a timestamp pair and a date pair, with exactly one
pair populated depending on `is_all_day`. Collapsing them into one nullable timestamp
pair is where all-day-event bugs come from.

`rrule` and `rdates` are not alternatives — a series may use either or both, exactly as
RFC 5545 allows. `rrule` covers "jede zweite Woche Mo/Mi"; `rdates` covers the shift rota
that no rule describes, entered by tapping days in a month grid (FR-1.13). Both expand
through the same code path and both survive the trip into the ICS feed, so a subscriber
sees one series rather than fourteen separate events.

**`busy_until` answers a different question from `presence_state`.** Homeoffice says
*where*; "Termine bis 17:00" says *from when someone is reachable* — which is the question
actually asked about a home-office day. It is a single time per member per day, entered by
hand in v1 and derivable in M3 from a privately imported work calendar, where the only
thing that would cross into the household's data is the end of the last meeting. Nothing
else about that calendar is stored, shown or fed anywhere.

**The baseline is on the profile, not in the events.** `profile.default_presence_state`
records where a person normally is — Homeoffice for one adult, at home for the other.
Nothing is stored per day for a normal day; only deviations become `event` rows. This
halves what has to be maintained and is what lets the week board draw the baseline quietly
and the exception loudly (FR-1.18). A baseline is display and defaulting only: it never
generates occurrences and never reaches the ICS feed.

`kind='presence'` rows are drawn as day bands and are excluded from agendas, conflict
checks and notifications — see [ADR-009](adr/ADR-009-event-kinds-and-presence.md). They
are ordinary events in every other respect, which is the point of not giving them their
own table.

## School (Stundenplan)

Added 2026-08-30. Owned by the `school` module; the calendar reads it but never writes
events for it — [ADR-008](adr/ADR-008-school-timetable-model.md).

```
school
  id, household_id, name,
  region_code TEXT NULL,                        -- OpenHolidays subdivision, any depth (DE-BE,
                                                -- AT-9, CH-ZH-ZH-ZH): drives the holiday rules
  state_code TEXT NULL,                         -- the first two segments of region_code, kept
                                                -- for the previous app release
  timezone TEXT

  -- Added 2026-10-14: several schools per household; a school takes the household's
  -- timezone when it is created. Starter subjects follow the country (see 21).

school_period                    -- the bell times, shared by every timetable at a school
  id, school_id, index INT,                     -- 1 = 1. Stunde
  label TEXT,                                   -- "1. Stunde", "Große Pause"
  starts_at TIME, ends_at TIME,
  kind ENUM('lesson','break')

school_term                      -- Schuljahr / Halbjahr
  id, school_id, name, starts_on DATE, ends_on DATE,
  ab_anchor_week INT NULL,                      -- ISO week that counts as an 'a' week
  is_current BOOLEAN

subject
  id, household_id, name,                       -- "Mathematik"
  short_name TEXT,                              -- "Ma"
  colour_hex, icon_key,
  equipment_note TEXT NULL                      -- "Sportsachen" — FR-7.12

timetable                        -- one child, one term
  id, household_id, profile_id, school_id, term_id,
  class_label TEXT,                             -- "3b"
  week_cycle ENUM('weekly','ab'),
  valid_from DATE, valid_to DATE NULL,          -- within the term's range
  source ENUM('manual','imported'), source_ref TEXT NULL,
  updated_at                                    -- drives the projected SEQUENCE

timetable_lesson                 -- one cell of the grid
  id, timetable_id, weekday INT,                -- 1 = Monday (ISO)
  period_index INT NULL,                        -- resolves against school_period
  starts_at TIME NULL, ends_at TIME NULL,       -- override for off-grid rows (Hort)
  subject_id NULL, kind ENUM('lesson','care','club'),
  title TEXT NULL,                              -- for kind='care'/'club' without a subject
  teacher TEXT NULL, room TEXT NULL,
  week_parity ENUM('all','a','b'),
  is_notable BOOLEAN,                           -- shown on the kiosk week board, FR-8.3
  note TEXT NULL

timetable_exception              -- one date, one slot
  id, timetable_id, on_date DATE, period_index INT NULL,
  kind ENUM('cancelled','substituted','room_change','extra'),
  subject_id NULL, teacher NULL, room NULL,
  starts_at TIME NULL, ends_at TIME NULL,       -- for kind='extra' off the grid
  note TEXT, created_by_profile_id

school_holiday                   -- Ferien, bewegliche Ferientage, closures, public holidays
  id, household_id, school_id NULL,             -- NULL = applies to every school
  name TEXT, starts_on DATE, ends_on DATE,
  kind ENUM('holiday','closure_day','public_holiday'),
  source ENUM('manual','imported'), source_url NULL,
  feed_id TEXT NULL                             -- the holiday_feed row it was imported from
```

Added 2026-10-14. A `public_holiday` is a Feiertag: it has no school (`school_id` NULL) and
is never imported by hand. Imported Ferien (`kind = 'holiday'`, `feed_id` set) are ordinary
holidays once they are in the list; the feed row is imported once per household and school.

### Holiday reference data

Added 2026-10-14. Public reference data, not household data: the server's holidays sync fills
it from the public OpenHolidays dataset ([15](15-module-school-timetable.md#holidays)); it holds
no household id, and any live device may read it (a revoked device reads nothing).

```
region                           -- every subdivision the sync knows
  code PK,                                      -- 'CH-ZH-ZH-ZH', 'AT-9', 'DE-BY'
  country, parent_code NULL, level 1..4,
  category TEXT,                                -- source label: Kanton, Bezirk, Gemeinde, ...
  short_name, names JSONB (language -> name), fetched_at

holiday_feed                     -- public holidays and school holidays per country
  id PK,                                        -- the OpenHolidays id
  country, kind ENUM('public','school'),
  starts_on, ends_on, names JSONB,
  nationwide BOOLEAN, subdivisions TEXT[],      -- where it applies (see the rule in 15)
  fetched_at

holiday_feed_sync                -- per country: requested_at, fetched_at, valid_from,
  country PK, ...                               -- valid_to, last_error (bookkeeping only)
```

`api.regions`, `api.holiday_feed` and `api.holiday_feed_status` read these tables; the rule
"does a holiday of country C with subdivisions S apply to region R" is `app.region_covers`,
and the Edge Functions mirror it in `_shared/openholidays.ts`. Writes go only through the service-role cache functions of `holidays-sync`.

### Getting started and export

Added 2026-10-14 (the Today tab, FR-5.17, and the data export, FR-5.16).

```
getting_started_dismissal        -- the only stored state of the getting-started card
  id, household_id, profile_id NULL,            -- NULL = household-wide; the guardian's
                                                -- profile for set_pin
  item ENUM('invite_partner','connect_tablet','wall_display','set_pin','subscribe_feed','school'),
  dismissed_at
```

```
notice_dismissal                 -- added 2026-10-15 (specs/20 J2, J4): "Gesehen", per profile
  id, household_id, profile_id, notice_key,     -- 'join:<audit id>' | 'signin:<device id>'
  dismissed_at                                  -- unique (profile_id, notice_key)
```

Notices themselves are not stored: `api.notices` derives them from `audit_log` and `device`
rows and drops anything older than 14 days.

The card's items are derived from data and never ticked by hand (`api.getting_started`).
The export (`api.household_export`) has no table of its own: it reads every household table
and leaves out secrets (password and PIN hashes, token and code hashes, Auth ids) and the
technical bookkeeping listed in migration `160`. A pgTAP guard fails when a new household
table is neither exported nor listed there.

### External calendars

Added 2026-10-14, with FR-1.9 ([05](05-module-calendar.md#external-calendars-subscribed-ics-fr-19)).

```
external_calendar                -- a subscription of the household
  id, household_id, name, url (https only, webcal:// stored as https://),
  colour_hex, member_ids UUID[] ([] = whole family), show_on_board BOOLEAN,
  active BOOLEAN, etag, timezone, last_fetched_at (the last attempt),
  last_error (a short code or NULL), created_at, updated_at

external_occurrence              -- the expanded feed, replaced as a whole on each fetch
  id, calendar_id, household_id, uid, starts_at, ends_at, all_day,
  start_date, end_date (all-day, inclusive), title, location
```

Only the server writes the occurrences; the apps read them through `api.external_occurrences`
and never write them. The URL is not written to the audit log.

### Views over existing tables

Added 2026-10-14, no new storage. `api.meal_history` (the cooked meals of the last 365 days,
grouped by recipe or by free text) feeds the meal suggestions (FR-3.8), and
`api.shopping_item_meals` lists the meals behind a shopping item (FR-3.7).
Both are `security_invoker` views, so RLS and the device check apply.

Two things this shape is protecting:

**A lesson stores a period, not a clock time.** Bell times live once per school, so moving
first period five minutes earlier is one `UPDATE`, not sixty. `starts_at`/`ends_at` on the
lesson exist only for rows that genuinely sit off the grid — Hort until 15:30, an AG that
runs across two periods.

**A/B weeks are derived, never stored per week.** `school_term.ab_anchor_week` plus ISO
week arithmetic gives the parity of any date. A stored per-week table would need
maintaining for eternity and would silently drift.

## Tasks & gamification

```
task_definition                  -- the template
  id, household_id, title, description, icon_key,
  kind ENUM('duty','bonus'),
  points INT,                                   -- >= 0, never negative
  rrule TEXT NULL,                              -- NULL = one-off
  window_days INT,                              -- how long an instance stays open
  assignment ENUM('fixed','rotating','open','each'),
  assignee_profile_ids UUID[],                  -- pool for fixed/rotating/each
  rotation_cursor INT,
  requires_verification BOOLEAN,
  is_active BOOLEAN, created_by_profile_id

task_instance                    -- one concrete occurrence
  id, household_id, definition_id NULL,         -- NULL for pure ad-hoc tasks
  title, points, kind,                          -- snapshotted from the definition
  due_on DATE, opens_on DATE,
  assigned_profile_id NULL,                     -- NULL for 'open'
  status ENUM('open','done','verified','skipped','expired'),
  completed_by_profile_id NULL, completed_at NULL,
  verified_by_profile_id NULL, verified_at NULL

point_transaction                -- append-only ledger; balance is derived
  id, household_id, profile_id, occurred_at,
  amount INT,                                   -- signed: + earned, − spent
  reason ENUM('task','redemption','adjustment','badge','bonus'),
  source_type, source_id,
  created_by_profile_id, note

reward
  id, household_id, title, description, icon_key,
  cost_points INT, stock INT NULL,              -- NULL = unlimited
  requires_approval BOOLEAN, is_active

reward_redemption
  id, household_id, reward_id, profile_id, cost_points,
  status ENUM('requested','approved','declined','fulfilled'),
  requested_at, decided_by_profile_id NULL, decided_at NULL, note

streak
  id, household_id, profile_id, definition_id,
  current_length INT, longest_length INT,
  last_completed_on DATE, jokers_remaining INT, period_started_on DATE

badge_definition
  id, household_id, key, title, description, icon_key, rule JSONB

badge_award
  id, household_id, profile_id, badge_definition_id, awarded_at, context JSONB
```

**The ledger is the point balance.** There is no `profile.points` column. A balance is
`SUM(amount)` over the ledger, cached in a materialised view or a small counter table
refreshed on write — but the ledger stays authoritative. Anything else and you will
eventually have a child's balance that nobody can explain.

## Meals

```
recipe
  id, household_id, title, description, servings_default INT,
  steps TEXT, source_url NULL, image_key NULL, tags TEXT[]

recipe_ingredient
  id, recipe_id, position INT,
  catalog_item_id NULL,                         -- links to the shopping catalogue
  raw_name TEXT, quantity NUMERIC NULL, unit TEXT NULL, note TEXT

meal_plan_entry
  id, household_id, on_date DATE,
  slot ENUM('breakfast','lunch','dinner','snack'),
  recipe_id NULL, free_text NULL,               -- exactly one is set
  servings INT NULL, cook_profile_id NULL,
  attendee_profile_ids UUID[],
  shopping_generated_at NULL                    -- guard against double generation
```

## Shopping

```
shopping_list
  id, household_id, name, store_id NULL, is_default BOOLEAN

shopping_item
  id, household_id, list_id,
  client_uuid UUID UNIQUE,                      -- idempotency key from the client
  name TEXT, quantity NUMERIC NULL, unit TEXT NULL, note TEXT,
  category_id NULL,
  catalog_item_id NULL,
  status ENUM('open','in_cart','bought'),
  added_by_profile_id, added_at,
  checked_by_profile_id NULL, checked_at NULL,
  source_meal_plan_entry_id NULL,               -- provenance, for FR-3.7
  updated_at, updated_seq BIGINT,               -- for last-write-wins merges
  deleted_at NULL

catalog_item                     -- learned vocabulary, powers the tile picker
  id, household_id, canonical_name, aliases TEXT[],
  icon_key TEXT,                                -- the tile's picture, FR-4.1
  default_category_id NULL, default_unit NULL,
  purchase_count INT, last_purchased_at

category                         -- "Obst & Gemüse", "Kühlregal", ...
  id, household_id, name, icon_key, colour_hex

store
  id, household_id, name

store_section_order
  store_id, category_id, position INT, PRIMARY KEY (store_id, category_id)
```

`store_section_order` is what turns a shopping list into a route through the shop.
Cheap to build, disproportionately useful in practice.

Three fields carry the capture decisions of 2026-09-02. `catalog_item.icon_key` is what
makes a tile a tile — every catalogue row needs a picture, and a newly created one gets a
placeholder until somebody assigns one. `shopping_item.note` holds the free-text
specification from a long press ("Bio", "500 g", "E14 warmweiß"); the quantity/unit columns
are filled only when the text parses unambiguously, and the note is kept verbatim either
way, because it is what a human reads in the shop. `shopping_list.is_default` is what the
wall display opens, and the wall never offers the others.

---

## Onboarding tables (built 2026-10-15)

Tables in the `app` schema, RLS enabled and forced, never exposed; written only through `api` functions:

- `app.instance_setting`: per-server settings, such as the `code` household creation mode (`households` migration).
- `app.founder_attempt`: the guess log of founder codes.
- `app.pairing_request`, `app.pairing_attempt`: a device's request to be connected (a secret, a code, the approving guardian, an expiry), and its attempt log.
- `app.invitation`, `app.invitation_attempt`: an invitation (a token and a code, the role, an optional confirmed email, an expiry, single use) and its attempt log.
- `app.apple_token`: the encrypted Apple refresh token of an account created before sign-in with Apple was removed (2026-10-17), kept only until the account is deleted and access is revoked.
- `app.household.created_by_profile_id` and `app.household.deleted_at`: who started the family, and when a deleted family becomes purgeable (14 days).


## Relationship overview

```
household ─┬─< profile ─┬── auth.users (0..1, adults only)
           │            ├─< point_transaction
           │            ├─< streak
           │            └─< badge_award
           ├─< device ──< enrolment_code
           ├─< invitation ──> profile
           ├─< getting_started_dismissal
           ├─< notice_dismissal
           ├─< audit_entry
           ├─< calendar ──< event ─┬─< event_attendee
           │                       └─< event_override
           ├─< calendar_feed_token
           ├─< shortcut_token ──> profile
           ├─< school ─┬─< school_period
           │           ├─< school_term ──< timetable ─┬─< timetable_lesson ──> subject
           │           │                              └─< timetable_exception
           │           └─< school_holiday
           ├─< subject
           ├─< task_definition ──< task_instance
           ├─< reward ──< reward_redemption
           ├─< badge_definition
           ├─< recipe ──< recipe_ingredient ──> catalog_item
           ├─< meal_plan_entry ──> recipe
           │                  └──< shopping_item  (via source_meal_plan_entry_id)
           ├─< shopping_list ──< shopping_item ──> catalog_item, category
           └─< store ──< store_section_order ──> category
```

## Invariants

Enforce these in the database where a constraint can express them, and in the `api`
functions where it cannot. Each one should have a pgTAP test.

1. Every domain row belongs to exactly one `household_id`, and every query filters on it.
2. `event`: exactly one of (`starts_at`,`ends_at`) or (`start_date`,`end_date`) is
   populated, matching `is_all_day`. `ends_at >= starts_at`.
3. `event.uid` is immutable once issued. Changing it makes every ICS subscriber see a
   delete plus a create — a guaranteed way to produce ghost events in Outlook.
4. `event_override.recurrence_id` must correspond to an occurrence the `rrule` actually
   generates.
5. `task_definition.points >= 0`. There is no mechanism to award negative points from a
   task (FR-2.11). Guardian corrections go through `point_transaction` with
   `reason='adjustment'` and are always visible in the audit log.
6. A `task_instance` moves `open → done → verified` or `open → skipped/expired` only.
   Points are credited on `done` unless `requires_verification`, in which case on
   `verified`.
7. Exactly one `point_transaction` may reference a given `(source_type, source_id)` pair
   — a unique index. This makes double-crediting a completed task structurally impossible.
8. A `reward_redemption` writes its negative ledger entry at `approved`, not at
   `requested`. A declined request never touches the ledger.
9. A redemption cannot be approved if the resulting balance would go below zero.
10. `meal_plan_entry`: exactly one of `recipe_id` or `free_text` is set.
11. `shopping_item.client_uuid` is globally unique. Server-side inserts generate one too,
    so there is a single code path.
12. `audit_entry` rows are never updated or deleted. Revoke `UPDATE`/`DELETE` on the
    table for the application role.
13. `device.bound_profile_id` is non-null exactly when `class = 'personal'`.
13a. An Auth user is linked to at most one profile (`profile.auth_user_id` unique), and only
    to a profile with `kind = 'adult'`. `role = 'guardian'` implies `kind = 'adult'`. An invitation is
    accepted at most once, and never after `expires_at` or `revoked_at`.
13b. A `pairing_request` is approved at most once and claimed at most once, and only with
    its secret; an approved request that is not claimed before `expires_at` binds nothing.
14. `calendar_feed_token.token_hash` stores a hash; the plaintext token is shown once at
    creation and never retrievable afterwards. The same holds for `shortcut_token.token_hash`.
14a. A `shortcut_token` acts only while it is not revoked, its holder's profile is active and
    its household is not deleted; deactivating the profile, clearing its account (leaving the
    family) or deleting the household revokes it, and restoring the household does not undo that.
15. `event.presence_state` is non-null exactly when `kind = 'presence'`, and null
    otherwise. A presence row never carries attendees other than its owner.
15a. A member's baseline never materialises as rows. Any day with no `presence` event is
    the baseline by definition — so removing a deviation is a delete, not an edit.
16. `event.rdates` and `event.exdates` are disjoint. A date in both is a contradiction,
    and silently preferring one produces a rota nobody can explain.
17. `timetable_lesson` is unique on `(timetable_id, weekday, period_index, week_parity)`.
    Two subjects in one slot is a data-entry error, not an overlap to render.
18. A `timetable`'s `valid_from`/`valid_to` lies inside its term, and two timetables for
    the same `profile_id` never overlap in validity.
19. `timetable_exception` with `kind != 'extra'` must reference a slot the projection
    actually produces on that date. An Entfall for a lesson that does not exist is a
    signal that the grid is wrong, and it should fail loudly at write time.
20. Lessons are **never** written as `event` rows, and projected occurrences are never
    editable through the event API. The only way to change what a lesson looks like is a
    `timetable_lesson` or `timetable_exception` write.
21. A projected occurrence's ICS `UID` is a pure function of its lesson (or day) and its
    date, so it is stable across restarts, redeploys and re-projections.

## Indexing notes

- `event`: index on `(household_id, starts_at)` and `(household_id, start_date)`; a
  partial index excluding `deleted_at IS NOT NULL`.
- `task_instance`: `(household_id, due_on, status)` — the wall display's main query.
- `point_transaction`: `(household_id, profile_id, occurred_at)`; the derived balance is
  a rolling aggregate over this.
- `shopping_item`: `(list_id, status)` partial on `deleted_at IS NULL`; unique on
  `client_uuid`.
- `catalog_item`: trigram index on `canonical_name` for fuzzy autocomplete
  (`pg_trgm`) — the three-second capture target in FR-4.1 depends on it.
- `event`: an additional partial index on `(household_id, importance)` where
  `importance = 'key'` — the week board asks for exactly these, seven days at a time,
  every few seconds on a device that is always on.
- `timetable_lesson`: `(timetable_id, weekday)`; `timetable_exception`:
  `(timetable_id, on_date)`; `school_holiday`: `(household_id, starts_on, ends_on)`.
  Projection queries a week at a time and should touch three small indexes, not scan.
