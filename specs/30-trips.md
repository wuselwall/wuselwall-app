# 30 — Trips: plan a family vacation in one place

*Added 2026-11-15 (issue #265). Builds on [05](05-module-calendar.md) (events, tentative entries,
the calendar file import), [15](15-module-school-timetable.md) (Ferien and public holidays),
[27](27-family-rituals.md) (Vorfreude) and [09](09-clients-and-ux.md) (the registers). The
optional weather and map services are decided in
[ADR-022](adr/ADR-022-opt-in-services.md). Migrations `20261115100000_services.sql` (pgTAP 315)
and `20261115110000_trips.sql` (pgTAP 320), Edge Functions `services` and `trips`, app code in
`app/lib/features/trips/` and `app/lib/features/services/`.*

## Why

A family that plans a vacation collects its findings in a chat, a notes app, browser tabs and
somebody's head: when everybody is free, where it is warm then, which train or flight, which
flat. The pilot family asked for one place (2026-11-15).

WuselWall is not a travel search engine and does not become one: it searches no flights and
books nothing. It does three things no trip planner can, because it already knows the family:

1. **It knows when the family is free.** Ferien per child and school, public holidays, the
   adults' appointments and business trips are in the calendar. Time windows are computed, not
   typed.
2. **It is where the family already looks.** A planned trip is a dashed entry in the calendar,
   a fixed one counts down on the wall and on the children's home (Vorfreude).
3. **It is one record for everyone.** What the adults find elsewhere is collected as options
   with link, price and note, compared, and chosen. What is chosen becomes the day plan that
   guides the family through the trip, readable without network.

## Who does what

Decided by the owner on 2026-11-15: **adults plan, children look forward.**

| Who | May |
|---|---|
| An adult profile (`profile.kind = 'adult'`), guardian or not, on a personal or shared device | Everything in this document except the services and the home place |
| A guardian | Also: switch services on and off, store API keys, set the home place |
| A child profile | Nothing here. A child sees the fixed trip in the calendar and as a countdown (the ordinary event) |
| The wall (kiosk) | Shows the trip's calendar entry and its countdown; changes nothing |

Reads follow the household rule of [01](01-vision-and-scope.md#explicitly-out-of-scope):
everything in `api.trips`, `api.trip_entries`, `api.trip_combos` and `api.trip_checks` is readable by every device
of the household. A booking reference is therefore no secret inside the family; API keys are
(they are never readable by any device). The pages restrict themselves to the adult register.

## The journey

A trip has a **stage**:

| Stage | Meaning | Calendar |
|---|---|---|
| `idea` | A wish: "Sardinien", "Nordsee". No dates needed. The ideas are the family's lasting wish list | nothing |
| `planned` | Pencilled into dates; options are being collected | one all-day entry, `status = 'tentative'` (dashed, "?") |
| `fixed` | Decided ("Das machen wir") | the same entry, confirmed, `countdown = true`, importance `key` |

There is no stage for "under way" or "over": a fixed trip is *running* from `starts_on` to
`ends_on` and *past* after it, by date. A stage can go back (a fixed trip that falls through
becomes an idea again; its calendar entry goes).

The order is the family's: start with an idea and look for a window, or start with a window
and look for a destination. Both end in the same trip.

### Ideas

*Reisen* (`/trips`) lists: the running or next trips, the ideas, and past trips (folded).
*Neue Idee* asks for a name; a picture (one of the event icons), a destination and a note are
optional. An idea can come from discovery (*Als Idee merken*).

### Time windows

*Zeitfenster* proposes when the family could travel, computed by the server
(`trips` function, action `windows`) for the next 18 months:

- **Who travels** is the trip's members (default: everyone).
- A day is **free for a child** when the child has no school: a weekend, a public holiday, a
  closure day or Ferien of the child's school (the child's timetable names the school; a child
  without one is free every day).
- A **window** is a run of days on which every travelling child is free, at least
  `min_days` long (default 4; the page offers 3, 4, 7, 10, 14). Ferien runs are extended over
  the weekends and public holidays that touch them. Without travelling school children, the
  windows are the long weekends: weekends joined with public holidays and at most two bridge
  days.
- Each window says: its dates and length, the name of the Ferien it lies in, the **leave days**
  the adults need (Monday to Friday inside the window that are not public holidays), and the
  **conflicts**: confirmed or tentative appointments and presence entries (`working`, `travel`,
  `away`, `childcare`) of the travelling members inside it, by name and day. A conflict does
  not remove a window; the family decides.
- Where the children's Ferien differ, the window is the days all share; the days only some
  have are named beside it.

Choosing a window (or any dates by hand) on an idea makes it `planned`. The dates can be
narrower than the window.

### Options and the plan

Everything the family finds or decides is an **entry** of the trip:

| Kind | Examples | Extra fields |
|---|---|---|
| `transport` | Flight ZRH–OLB, train via Milano, the ferry, the own car | `mode`: `flight`, `train`, `car`, `ferry`, `bus`, `other`; from and to |
| `stay` | A flat, a hotel, the campsite | address, phone |
| `rental` | The rental car, a camper, bikes | from and to (pick-up and return place) |
| `activity` | The boat tour, the museum, a restaurant | address, phone |
| `note` | "Reisepass von Paul läuft im Juni ab" | — |

Every entry may carry a link, a price, a short line of details ("1 Stopp, Gepäck inklusive"),
a note, a start and an end (a date with or without a time), a booking reference and the day
until which it can be cancelled free of charge. An entry has a **state**:

| State | Meaning |
|---|---|
| `option` | Found, not decided |
| `chosen` | This one. It belongs to the plan |
| `booked` | Chosen and booked; the reference is filled in |

- **Capturing an option is quick.** Each kind's section has *Option hinzufügen*: a name and a
  price are enough, a pasted link goes into the link field, everything else can follow. An
  option can be **copied** ("the same flight a day later") and changed.
- **A price has a date.** `price_checked_on` is set to today whenever the price is entered or
  changed, and shown beside it ("CHF 840 · Preis vom 12.11."), because flight and hotel prices
  move and the family compares over weeks.
- **Times are the place's own.** A date and a time on an entry are what the ticket says, where
  it says it (`starts_on`, `starts_time`, no zone, no conversion). A flight's arrival is the
  arrival airport's clock. This is what a family reads on a ticket, and it needs no time zone
  database for places the server does not know.
- **The plan** of a trip with dates is its days from `starts_on` to `ends_on`, each with the
  chosen and booked entries of that day in time order; a stay shows on its first day
  ("Einchecken") and its last ("Auschecken"), and in the day's footer in between; a rental on
  its pick-up and return day. Chosen entries without a date are listed under the plan.
- **Prices** are estimates for comparing, in the trip's currency (three letters, default CHF
  for a household in CH or LI, else EUR; the last trip's currency wins). There is no expense
  tracking ([23](23-roadmap-after-alpha.md) P8).
- **Links, phone numbers and addresses** open in the phone's own browser, dialler and maps
  app. The app itself contacts none of them.
- **No documents.** A PDF ticket stays where it is; the entry holds the reference and the link
  (P8).

### Comparing and combining

Added 2026-11-15 on the owner's word: tracking flight, accommodation and rental car options,
comparing them and trying out combinations is the core of planning.

- **Compare within a kind.** *Vergleichen* shows the options of one kind side by side, each a
  card with the same rows in the same order so the eye can run across: price (and what it
  comes to per night for a stay, per day for a rental), from and to, start and end, the details
  line, free cancellation until, the price's date, the link. The cheapest price is marked; an
  option whose free cancellation has passed says so. On a phone the cards scroll sideways; from
  840 logical pixels they stand in a row.
- **Try a combination.** In the same view every option has a tick. The ticked options are the
  combination being tried: a bar at the bottom shows its **total**, its dates from the first
  start to the last end, and what does not fit:
  - a night between the first and the last day that no ticked stay covers,
  - a rental that starts before the arrival or ends after the departure of the ticked
    transport, or is ticked without any,
  - two ticked stays that overlap,
  - an option without a price (the total says "at least").
  Nothing is saved while trying; ticking is free.
- **Keep combinations.** *Als Kombination merken* stores the ticked set under a name
  ("Günstig", "Direktflug und Strandhotel"). The stored combinations stand side by side like
  the options: total, dates, the transport, the stay, the rental and the warnings. A stored
  combination can be loaded back into the ticks, changed and stored again. An option that is
  deleted leaves its combinations.
- **Take one.** *Diese nehmen* on a combination sets its entries to `chosen`, sets every other
  `chosen` transport, stay and rental of the trip back to `option` (a `booked` entry is never
  touched), and, if asked, sets the trip's dates to the combination's dates. The trip becomes
  `planned` if it was an idea with dates now; fixing it stays its own step.
- The checks above are computed in the app from what it shows (`trips/domain/combination.dart`);
  the server stores sets and applies the choice.

### Packing and preparing

A trip has **checks** of two kinds:

- `pack`: the packing list, per person (`profile_id`) or for the family (null). *Vorschläge*
  adds a starter list (documents, chargers, the pharmacy bag, swimming things, the cuddly toy;
  a localised catalogue in the app, like the chore examples), *Wie letztes Mal* copies the
  list of another trip, unticked.
- `todo`: what has to happen before ("Pässe prüfen", "Katze: Nachbarn fragen"), optionally
  with `due_days_before` (the day is shown as a date once the trip has dates).

A check is ticked and unticked by any adult; nothing counts, ranks or earns points
([27](27-family-rituals.md) rule 1 applies: this is not a chore). Children do not tick
(decision above); a packing list for the child's own bag is a later candidate.

### In the calendar and on the wall

- A `planned` or `fixed` trip owns **one all-day appointment** from `starts_on` to `ends_on`
  with the trip's members as attendees, its picture, its name as title and the destination as
  place. `planned`: tentative. `fixed`: confirmed, `countdown = true`, importance `key`, so it
  shows on the wall on every day it covers and counts down in the Vorfreude strip, on the kid
  home and on Today within the household's horizon (`rituals.countdown_days`).
- The entry belongs to the trip: `app.event.trip_id`. Opening it in the app opens the trip.
  Saving or deleting it through the calendar is refused (`trip_event`); an older app shows its
  general error. The outbound ICS feed carries it like any event.
- It is an appointment, not a presence entry: a presence entry has no picture and no
  countdown and is not in the month view. Who is away is said by the attendees.
- The wall is at home while the family is away. Its part is the *before* (the dashed band,
  the countdown) and whoever stays. There is no trip page on the wall.

### During the trip

- **Heute** (adult register) shows a trip card: before the trip (from 30 days before a fixed
  trip) the days left, the open to-dos that are due and the packing progress; during the trip
  "Tag 3 von 10", today's entries in time order, where the family sleeps tonight (address,
  phone) and tomorrow's first entry.
- **Without network.** The trips, their entries and checks are read through the read cache
  ([ADR-006](adr/ADR-006-offline-strategy.md), `cacheKey`), so the last state is readable in a
  plane or abroad without roaming. Writing still needs the server.
- With a forecast service on, the trip page shows the forecast for the destination from seven
  days before until the end; before that, with a climate service on, what is typical for the
  month.

### A booking's calendar file

Railways, airlines and booking sites often attach a calendar file to the confirmation. Opening
an `.ics` file in the app ([05, "Receiving one"](05-module-calendar.md#receiving-one)) offers,
when the family has a planned or fixed trip, **Zur Reise hinzufügen**: every event of the file
becomes an entry of the chosen trip (state `booked`, kind guessed from the words: flight,
train, hotel, rental car; title, date and time as written, the place as address, the description as note).
The file's UID is kept (`source_uid`), so opening the same file again updates instead of
doubling. There is no mailbox access, no PDF and no wallet-pass reading.

## Discovery

*Wohin?* (`/trips/discover`) answers "where is it warm and dry in that window, and how far is
it". The server (`trips` function, action `discover`) ranks:

- the **catalogue**: about 150 destinations bundled with the server
  (`supabase/functions/_shared/trips/destinations.ts`): a key, names in DE/EN/FR/ES,
  coordinates, country and tags (`sea`, `island`, `mountains`, `lake`, `city`, `countryside`,
  `north`, `long_haul`). It is the project's own compilation of well-known places, weighted
  towards Europe and the Mediterranean; regions and islands are units (Mallorca, Tessin), not
  resorts;
- the family's own **ideas** that have coordinates.

Filters: the window (or a month), the day temperature wanted (at least / at most), "little
rain", the sea temperature (at least), tags, and the travel effort.

- **Travel effort** needs the home place (a guardian sets it once: picked from the catalogue's
  places or looked up with a geocoding service; stored rounded to two decimals). It is an
  estimate from the great-circle distance: up to 300 km *nah*, up to 800 km *eine lange
  Autofahrt*, up to 1,500 km *Kurzstrecke*, up to 4,000 km *Mittelstrecke*, beyond
  *Langstrecke*. It is labelled as an estimate and names no connection. With a route service
  on, a trip's page shows the driving time from home.
- **Climate** comes from a climate service, if the household has switched one on
  ([below](#services)): typical day and night temperature, rain days, sunshine and, by the
  sea, water temperature for the window's months. Values are cached on the server for five
  years (they are normals). Places whose values are not fetched yet are fetched a few per
  request within the provider's budget; the answer says how many are pending and the page
  asks again. Without a climate service the list shows tags and distance only and says what a
  service would add.
- The result never names a hotel, a price or a connection, and says where the numbers come
  from (the provider's attribution line).

## Services

Weather, place search, routes and map pictures come from third parties. ADR-022 decides how:

- **A service is off until a guardian switches it on**, per household, under Einstellungen →
  *Wetter und Karten* (`/settings/services`). The page says for each provider what it
  receives.
- **Only the family's server contacts a provider** (`services` and `trips` functions), never an
  app. The provider learns the server's address, the coordinates or the search text, and
  nothing about the family.
- **A provider is a plug-in**: one file under `supabase/functions/_shared/services/providers/`
  that declares its capabilities and implements them. The apps learn the list from the server
  (action `catalogue`), so a new provider needs no app release.
- **Keys** are typed in by a guardian, stored in `app.service_secret`, which no device role can
  read, read by the service role only after the caller's JWT and household are verified, never
  exported, never logged, and shown only as "…last four".

| Capability | Used for |
|---|---|
| `climate` | typical months in discovery and on a trip |
| `forecast` | the days before and during a trip |
| `geocode` | finding a destination's or the home's coordinates by name |
| `route` | driving time and distance from home |
| `map` | a map picture on the trip page |

Providers in the first build (each verified against its own documentation at build time; the
plug-in file names the documentation it was written from):

| Provider | Key | Capabilities |
|---|---|---|
| `open-meteo` | none | climate, forecast, geocode |
| `met-no` (MET Norway) | none | forecast |
| `nominatim` (OpenStreetMap) | none | geocode |
| `openweathermap` | own key | forecast, geocode |
| `meteostat` | own key | climate |
| `openrouteservice` | own key (free) | route, geocode |
| `google` | own key | geocode, route, map |

For a capability the server asks the household's enabled providers that offer it in the
household's order; the first answer wins. Answers are cached (climate 5 years, geocode 90
days, route 30 days, map 30 days, forecast 3 hours) in `app.service_cache`, which holds public
facts and no household. A provider declares how many calls an hour and a day are polite; the
server counts and stops (`service_limit`).

## Data and contract

`api_version` stays 1: everything is additive. Feature flags `services` and `trips`. An older
app ignores both; a newer app on an older server hides every entry point
(`serverSupportsProvider`). Realtime topics `trips` (and `calendar` when the entry changes)
and `settings` for the services.

### Tables (`app`, RLS enabled and forced, `household_id` with `on delete cascade`)

```
trip
  id, household_id, title (1–120), icon_key NULL, stage ('idea','planned','fixed'),
  destination_name NULL (≤120), destination_key NULL (catalogue key), country NULL (2 letters),
  lat NULL, lon NULL, starts_on NULL, ends_on NULL (both or neither; required unless 'idea';
  at most 366 days), note (≤4000), currency (3 letters),
  created_by_profile_id, created_at, updated_at
trip_member        trip_id, profile_id, household_id          -- empty = the whole family
trip_entry
  id, household_id, trip_id, kind ('transport','stay','rental','activity','note'),
  mode NULL ('flight','train','car','ferry','bus','other'; only for transport),
  title (1–200), state ('option','chosen','booked'), url NULL (http/https, ≤2000),
  price_cents NULL (0…10^10), price_checked_on NULL (set by the server when the price changes),
  details NULL (≤200), note (≤4000), from_place NULL (≤80), to_place NULL (≤80),
  booking_ref NULL (≤80), cancel_until NULL (date), address NULL (≤300), phone NULL (≤40),
  lat NULL, lon NULL,
  starts_on NULL, starts_time NULL, ends_on NULL, ends_time NULL (a time needs its date;
  an end is not before its start),
  position, source_uid NULL, created_by_profile_id, created_at, updated_at
trip_combo         id, household_id, trip_id, name (1–60), position, created_by_profile_id,
                   created_at, updated_at
trip_combo_entry   combo_id, entry_id, household_id      -- both cascade
trip_check
  id, household_id, trip_id, kind ('pack','todo'), title (1–120), profile_id NULL,
  due_days_before NULL (0…365, todo only), done_at NULL, done_by_profile_id NULL,
  position, created_at
trip_home          household_id PK, name (≤120), lat, lon (two decimals), updated_at
event              + trip_id NULL references trip on delete set null

service_provider   household_id, provider (^[a-z0-9-]{2,40}$), enabled, capabilities text[],
                   position, has_key, key_hint NULL, last_ok_at NULL, last_error NULL,
                   calls_day date, calls_today int, updated_at, updated_by_profile_id
                   PK (household_id, provider)
service_secret     household_id, provider, secret        -- no grant to any device role
service_cache      key PK, capability, provider, payload jsonb, fetched_at, expires_at
                   -- no household: public facts; no grant to any device role
```

All household tables are in the family's export except `service_secret` (never) and the call
counters of `service_provider`.

### Reads (views, `security_invoker`)

`api.trips` (the trip's columns, `member_ids uuid[]`, `event_id`), `api.trip_entries`,
`api.trip_combos` (with `entry_ids uuid[]`), `api.trip_checks`, `api.trip_home`,
`api.service_providers` (everything of `service_provider`
but no secret). `api.events` gains `trip_id` as its last column; the `occurrences` function's
rows gain `trip_id`.

### Writes (one function each, `app.actor()` first, audit in the same transaction)

| Function | Who | Does |
|---|---|---|
| `api.trip_save(p_actor, p_trip jsonb)` → `{id, event_id}` | adult, no kiosk | creates or updates (client-chosen `id` makes it idempotent). Keys: `id`, `title`, `icon_key`, `stage`, `destination_name`, `destination_key`, `country`, `lat`, `lon`, `starts_on`, `ends_on`, `note`, `currency`, `member_ids`. An omitted key keeps its value on update. Keeps the calendar entry in step |
| `api.trip_delete(p_actor, p_id)` | adult, no kiosk | removes the trip, its entries and checks, and its calendar entry (soft-deleted like any event) |
| `api.trip_entry_save(p_actor, p_entry jsonb)` → `{id}` | adult, no kiosk | creates or updates an entry (`trip_id` required on create) |
| `api.trip_entry_delete(p_actor, p_id)` | adult, no kiosk | |
| `api.trip_entry_copy(p_actor, p_id)` → `{id}` | adult, no kiosk | a copy as `option`, without booking reference and `source_uid`, placed after the original |
| `api.trip_combo_save(p_actor, p_combo jsonb)` → `{id}` | adult, no kiosk | keys `id`, `trip_id`, `name`, `entry_ids` (entries of that trip, at most 40; replaces the set) |
| `api.trip_combo_delete(p_actor, p_id)` | adult, no kiosk | |
| `api.trip_combo_choose(p_actor, p_id, p_set_dates boolean default false)` → `{chosen, released, dates_set}` | adult, no kiosk | the rule of "Take one" above, in one transaction, with the calendar entry kept in step |
| `api.trip_entries_import(p_actor, p_trip, p_entries jsonb)` → `{added, updated}` | adult, no kiosk | at most 50 entries, each with `source_uid`; an entry of the trip with the same `source_uid` is updated |
| `api.trip_check_save(p_actor, p_check jsonb)` → `{id}` | adult, no kiosk | |
| `api.trip_checks_add(p_actor, p_trip, p_checks jsonb)` → `{added}` | adult, no kiosk | at most 100 at once (the starter list); a title the trip already has for the same person and kind is skipped |
| `api.trip_checks_copy(p_actor, p_from, p_to)` → `{added}` | adult, no kiosk | copies the checks of another trip, unticked, skipping the same way |
| `api.trip_check_tick(p_actor, p_id, p_done boolean)` | adult, no kiosk | |
| `api.trip_check_delete(p_actor, p_id)` | adult, no kiosk | |
| `api.trip_home_set(p_actor, p_home jsonb)` | guardian, no kiosk | `{name, lat, lon}` or `null` to forget it |
| `api.service_provider_set(p_actor, p_provider, p_config jsonb)` | guardian, no kiosk | keys `enabled`, `capabilities`, `position`, `key` (a string stores it, `''` removes it, absent keeps it). The audit row never holds the key |
| `api.service_request(p_actor, p_capability)` → `{household_id, providers: [{provider, has_key, calls_today}]}` | adult, no kiosk (a null capability, for the test and catalogue actions: guardian) | the door of the Edge Functions: run as the caller before any provider is contacted |

Service role only (`service_role_required` otherwise): `api.service_secrets(p_household)` →
`{provider: key}` of the enabled providers, `api.service_report(p_household, p_provider, p_ok,
p_error)` (counts the call, records the outcome as a short code), `api.service_cache_get(p_keys
text[])`, `api.service_cache_put(p_key, p_capability, p_provider, p_payload, p_ttl_seconds)`,
`api.service_cache_recent(p_provider, p_capability, p_seconds)` → count.

Errors (the hint travels): `WW-TRIP-001 trip_invalid`, `trip_not_found`, `WW-TRIP-002
trip_entry_invalid`, `trip_entry_not_found`, `WW-TRIP-006 trip_combo_invalid`, `trip_combo_not_found`, `WW-TRIP-003 trip_check_invalid`,
`trip_check_not_found`, `WW-TRIP-004 trip_event` (the calendar entry of a trip is changed in the
trip), `WW-TRIP-005 trip_home_invalid`, `adult_required`, `WW-SVC-001 service_invalid`, and the
existing `kiosk_forbidden`, `guardian_required`, `device_revoked`.

### Edge Functions (user JWT; POST, JSON)

`services`:

| Body | Answer |
|---|---|
| `{action: 'catalogue'}` | `{providers: [{id, name, homepage, key_url, needs_key, cost: 'free'|'free_key'|'paid_key', capabilities, receives: ['coordinates','search_text','home_coordinates'], attribution}]}` (any member) |
| `{action: 'test', provider, actor_profile_id?}` | `{ok, error?}`: one small real call (guardian) |
| `{action: 'geocode', q, lang?, actor_profile_id?}` | `{places: [{name, country, admin?, lat, lon}], provider, attribution}` |
| `{action: 'forecast', lat, lon, actor_profile_id?}` | `{days: [{date, tmax, tmin, precip_mm, precip_prob?, code}], provider, attribution}` (`code`: `clear`, `partly`, `cloudy`, `fog`, `rain`, `snow`, `storm`) |
| `{action: 'climate', lat, lon, actor_profile_id?}` | `{months: [{month 1–12, tmax, tmin, rain_days?, precip_mm?, sun_hours?, sea?}], provider, attribution}` |
| `{action: 'route', from: {lat, lon}, to: {lat, lon}, actor_profile_id?}` | `{km, minutes, provider, attribution}` |
| `{action: 'map', lat, lon, zoom?, width, height, actor_profile_id?}` | `{image_base64, mime, provider, attribution}` |

Errors are `{error: code}` with a status: `service_off` (409, no enabled provider offers the
capability), `service_key_missing` (409), `service_limit` (429), `service_failed` (502, every
provider failed), `invalid_request` (400), and the database's refusals passed through (403).

`trips`:

| Body | Answer |
|---|---|
| `{action: 'windows', from?, to?, min_days?, member_ids?}` | `{windows: [{from, to, days, name?, kind: 'holidays'|'long_weekend', leave_days, partial: [{profile_id, from, to}], conflicts: [{date, title, event_id, kind, presence_state?, profile_ids}]}]}` |
| `{action: 'discover', from, to, lang?, filters: {temp_min?, temp_max?, dry?, sea_min?, tags?, effort?}, actor_profile_id?}` | `{places: [{key?, trip_id?, name, country, lat, lon, tags, km?, effort?, climate?: {tmax, tmin, rain_days?, sun_hours?, sea?}, fits: 'yes'|'no'|'unknown'}], pending, provider?, attribution?}` sorted: fits first, then nearer |

`windows` reads as the caller (RLS) and contacts nobody. `discover` contacts a provider only
through the services runner, so every rule above holds for it.

## Considered and not chosen

- **Searching flights, trains and hotels.** A booking engine's business, behind commercial
  interfaces; and a third party in every query. The family searches where it always did and
  keeps what it found here.
- **A bundled climate table** (DWD CLIMAT normals with ERA5 for the gaps). Researched
  2026-11-15: licences allow it (CC BY 4.0, Copernicus), coverage at holiday places is patchy
  and sea temperature needs a second source. The owner chose the services instead; the table
  stays a possible keyless provider (`bundled`) later.
- **Children's wishes and hearts.** Offered, not chosen for now (owner, 2026-11-15).
- **A presence entry for the trip.** No picture, no countdown, not in the month view.
- **Watching prices.** The price's date is kept; fetching a price is a search engine's work
  and a third party per option.
- **Events for every entry.** A flight at 10:40 in the family calendar is right for some
  families and noise for others, and the time is the airport's, not the household's. The plan
  lives in the trip; one entry stands in the calendar.
- **Tasks for the to-dos, a shopping list for packing.** Tasks are chores with points; a
  shopping list has no person per item and tells the other adults when somebody goes
  shopping.
- **Documents, expense tracking, a shared map with pins, chat.** P8.
- **An AI that suggests destinations.** On hold with all assistant work
  ([deferred](deferred/mcp-and-ai-assistants.md)).

## Not built yet

- A packing list for a child's own bag on the kid home.
- Local notifications for a dated entry ("in 2 Stunden: Fähre") and for a due to-do.
- Reading PDF tickets and wallet passes; fetching a title from a pasted link.
- The wall showing more than the calendar entry and the countdown.
- Trip days in the local time zone of the destination (a trip across the date line shows the
  household's dates).
