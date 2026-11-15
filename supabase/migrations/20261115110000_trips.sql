-- Family trips: plan a vacation in one place (specs/30, issue #265).
--
-- A trip is a wish (an idea), pencilled into dates (planned) or decided (fixed). Everything the
-- family finds on the way is an entry of the trip: transport, a stay, a rental, an activity, a
-- note, each an option, chosen or booked. Options are compared, stored as combinations and taken
-- in one step; a packing list and to-dos belong to the trip. A planned or fixed trip owns one
-- all-day appointment in the calendar, kept in step by the server.
--
--   * app.trip, app.trip_member, app.trip_entry, app.trip_combo, app.trip_combo_entry,
--     app.trip_check, app.trip_home: household tables, readable by every device of the household
--     (RLS, grant select), written only by the functions below.
--   * app.event.trip_id: the trip a calendar entry belongs to. api.events shows it as its last
--     column. At most one live event per trip.
--   * Views api.trips (member_ids, event_id), api.trip_entries, api.trip_combos (entry_ids),
--     api.trip_checks, api.trip_home.
--   * Writes (one function each, app.trip_actor first, audit in the same transaction, topic
--     'trips'; 'calendar' when the entry changes): api.trip_save, trip_delete, trip_entry_save,
--     trip_entry_delete, trip_entry_copy, trip_entries_import, trip_combo_save, trip_combo_delete,
--     trip_combo_choose, trip_check_save, trip_checks_add, trip_checks_copy, trip_check_tick,
--     trip_check_delete; api.trip_home_set needs a guardian. Every function needs an adult
--     profile on a device that is not the wall (app.trip_actor, 20261115100000).
--   * The calendar entry belongs to the trip: a BEFORE UPDATE trigger on app.event (and a trigger
--     on app.event_override) refuses every change that does not come from app.trip_event_sync or
--     api.trip_delete, so api.event_save, api.event_delete and the override functions fail on it
--     with the hint trip_event. An update that changes no column a person sees (the creator set
--     to null when a profile goes, the trip reference cleared when the trip goes, the sequence
--     and the clock) passes, so deleting a household or a profile keeps working.
--   * The export carries every new household table.
--
-- Errors (hint in brackets):
--   WW-TRIP-001 trip invalid (trip_invalid)               a trip key, date, member or length
--   WW-TRIP-002 trip entry invalid (trip_entry_invalid)   an entry key, state, time or price
--   WW-TRIP-003 trip check invalid (trip_check_invalid)   a check key or a due day on a packing item
--   WW-TRIP-004 the calendar entry of a trip is changed in the trip (trip_event)
--   WW-TRIP-005 trip home invalid (trip_home_invalid)     a home place without a name or a coordinate
--   WW-TRIP-006 trip combination invalid (trip_combo_invalid)  a name, or entries that are not the trip's
--   P0002 trip_not_found / trip_entry_not_found / trip_combo_not_found / trip_check_not_found
--                                                         (also for another household's ids)
--   42501 adults_only / kiosk_forbidden / guardian_required / device_revoked
--
-- api_version: unchanged. Additive: tables, one column, one more column at the end of
-- api.events, functions. An older app neither reads nor writes any of it; where it saves or
-- deletes a trip's calendar entry it gets the calendar's general error. api.server_info
-- announces 'trips'; an app on an older server hides every entry point.

-- ================================================================== tables

create table app.trip (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  title                 text not null check (length(btrim(title)) between 1 and 120),
  icon_key              text check (icon_key is null or icon_key ~ '^[a-z0-9_]{1,40}$'),
  stage                 text not null check (stage in ('idea', 'planned', 'fixed')),
  destination_name      text check (destination_name is null or length(destination_name) between 1 and 120),
  destination_key       text check (destination_key is null or destination_key ~ '^[a-z0-9_-]{1,60}$'),
  country               text check (country is null or country ~ '^[A-Z]{2}$'),
  lat                   double precision check (lat is null or lat between -90 and 90),
  lon                   double precision check (lon is null or lon between -180 and 180),
  check ((lat is null) = (lon is null)),
  starts_on             date,
  ends_on               date,
  check ((starts_on is null) = (ends_on is null)),
  check (ends_on is null or (ends_on >= starts_on and ends_on - starts_on <= 365)),
  check (stage = 'idea' or starts_on is not null),
  note                  text not null default '' check (length(note) <= 4000),
  currency              text not null check (currency ~ '^[A-Z]{3}$'),
  created_by_profile_id uuid references app.profile on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index trip_household_id_id_idx on app.trip (household_id, id);

-- Empty = the whole family.
create table app.trip_member (
  trip_id      uuid not null references app.trip on delete cascade,
  profile_id   uuid not null references app.profile on delete cascade,
  household_id uuid not null references app.household on delete cascade,
  primary key (trip_id, profile_id)
);
create index trip_member_household_idx on app.trip_member (household_id, trip_id);

create table app.trip_entry (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  trip_id               uuid not null references app.trip on delete cascade,
  kind                  text not null check (kind in ('transport', 'stay', 'rental', 'activity', 'note')),
  mode                  text check (mode in ('flight', 'train', 'car', 'ferry', 'bus', 'other')),
  check ((kind = 'transport') = (mode is not null)),
  title                 text not null check (length(btrim(title)) between 1 and 200),
  state                 text not null default 'option' check (state in ('option', 'chosen', 'booked')),
  url                   text check (url is null or (length(url) <= 2000 and url ~* '^https?://')),
  price_cents           bigint check (price_cents is null or price_cents between 0 and 10000000000),
  price_checked_on      date,
  details               text check (details is null or length(details) <= 200),
  note                  text not null default '' check (length(note) <= 4000),
  from_place            text check (from_place is null or length(from_place) <= 80),
  to_place              text check (to_place is null or length(to_place) <= 80),
  booking_ref           text check (booking_ref is null or length(booking_ref) <= 80),
  cancel_until          date,
  address               text check (address is null or length(address) <= 300),
  phone                 text check (phone is null or length(phone) <= 40),
  lat                   double precision check (lat is null or lat between -90 and 90),
  lon                   double precision check (lon is null or lon between -180 and 180),
  check ((lat is null) = (lon is null)),
  starts_on             date,
  starts_time           time,
  ends_on               date,
  ends_time             time,
  -- A time needs its date; an end is not before its start.
  check (starts_time is null or starts_on is not null),
  check (ends_time is null or ends_on is not null),
  check (starts_on is null or ends_on is null or ends_on >= starts_on),
  check (starts_on is null or ends_on is null or ends_on > starts_on
         or starts_time is null or ends_time is null or ends_time >= starts_time),
  position              int not null default 0 check (position between 0 and 100000),
  source_uid            text check (source_uid is null or length(source_uid) between 1 and 300),
  created_by_profile_id uuid references app.profile on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index trip_entry_household_id_id_idx on app.trip_entry (household_id, id);
create index trip_entry_trip_idx on app.trip_entry (trip_id, kind, position);
create unique index trip_entry_source_uid_idx on app.trip_entry (trip_id, source_uid) where source_uid is not null;

create table app.trip_combo (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  trip_id               uuid not null references app.trip on delete cascade,
  name                  text not null check (length(btrim(name)) between 1 and 60),
  position              int not null default 0 check (position between 0 and 100000),
  created_by_profile_id uuid references app.profile on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index trip_combo_household_id_id_idx on app.trip_combo (household_id, id);
create index trip_combo_trip_idx on app.trip_combo (trip_id, position);

create table app.trip_combo_entry (
  combo_id     uuid not null references app.trip_combo on delete cascade,
  entry_id     uuid not null references app.trip_entry on delete cascade,
  household_id uuid not null references app.household on delete cascade,
  primary key (combo_id, entry_id)
);
create index trip_combo_entry_entry_idx on app.trip_combo_entry (entry_id);
create index trip_combo_entry_household_idx on app.trip_combo_entry (household_id, combo_id);

create table app.trip_check (
  id                 uuid primary key default gen_random_uuid(),
  household_id       uuid not null references app.household on delete cascade,
  trip_id            uuid not null references app.trip on delete cascade,
  kind               text not null check (kind in ('pack', 'todo')),
  title              text not null check (length(btrim(title)) between 1 and 120),
  -- A person's packing goes with the person; the creator and the ticker only lose their name.
  profile_id         uuid references app.profile on delete cascade,
  due_days_before    int check (due_days_before is null or (kind = 'todo' and due_days_before between 0 and 365)),
  done_at            timestamptz,
  done_by_profile_id uuid references app.profile on delete set null,
  position           int not null default 0 check (position between 0 and 100000),
  created_at         timestamptz not null default now()
);
create index trip_check_household_id_id_idx on app.trip_check (household_id, id);
create index trip_check_trip_idx on app.trip_check (trip_id, kind, position);

-- The home place of the family, for the travel effort (a guardian sets it; two decimals).
create table app.trip_home (
  household_id uuid primary key references app.household on delete cascade,
  name         text not null default '' check (length(name) <= 120),
  lat          numeric(5, 2) not null check (lat between -90 and 90),
  lon          numeric(5, 2) not null check (lon between -180 and 180),
  updated_at   timestamptz not null default now()
);

-- The calendar entry of a trip. The trip's removal leaves the event to trip_delete, which
-- detaches it first; the reference is cleared on its own only when the household goes.
alter table app.event add column trip_id uuid references app.trip on delete set null;
create unique index event_trip_live_idx on app.event (trip_id) where trip_id is not null and deleted_at is null;

alter table app.trip             enable row level security;
alter table app.trip_member      enable row level security;
alter table app.trip_entry       enable row level security;
alter table app.trip_combo       enable row level security;
alter table app.trip_combo_entry enable row level security;
alter table app.trip_check       enable row level security;
alter table app.trip_home        enable row level security;
alter table app.trip             force row level security;
alter table app.trip_member      force row level security;
alter table app.trip_entry       force row level security;
alter table app.trip_combo       force row level security;
alter table app.trip_combo_entry force row level security;
alter table app.trip_check       force row level security;
alter table app.trip_home        force row level security;

create policy trip_read on app.trip for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy trip_member_read on app.trip_member for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy trip_entry_read on app.trip_entry for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy trip_combo_read on app.trip_combo for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy trip_combo_entry_read on app.trip_combo_entry for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy trip_check_read on app.trip_check for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy trip_home_read on app.trip_home for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());

create policy owner_all on app.trip             to postgres using (true) with check (true);
create policy owner_all on app.trip_member      to postgres using (true) with check (true);
create policy owner_all on app.trip_entry       to postgres using (true) with check (true);
create policy owner_all on app.trip_combo       to postgres using (true) with check (true);
create policy owner_all on app.trip_combo_entry to postgres using (true) with check (true);
create policy owner_all on app.trip_check       to postgres using (true) with check (true);
create policy owner_all on app.trip_home        to postgres using (true) with check (true);

revoke all on app.trip, app.trip_member, app.trip_entry, app.trip_combo, app.trip_combo_entry,
  app.trip_check, app.trip_home from public, anon, authenticated;
grant select on app.trip, app.trip_member, app.trip_entry, app.trip_combo, app.trip_combo_entry,
  app.trip_check, app.trip_home to authenticated;

-- ================================================================== the calendar entry belongs to the trip

-- app.trip_sync is a transaction-local setting that app.trip_event_sync and api.trip_delete turn
-- on around their own writes. Anything else that changes what a person sees of a trip's event is
-- refused. A row update that only moves the creator, the trip reference, the sequence or the
-- clock passes: the creator becomes null when a profile is deleted, the trip reference when a
-- household is deleted (the event and the trip go in one statement).
create function app.trip_event_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if coalesce(current_setting('app.trip_sync', true), '') = 'on' then
    return new;
  end if;
  if (to_jsonb(new) - 'created_by_profile_id' - 'updated_at' - 'sequence' - 'trip_id')
     is distinct from (to_jsonb(old) - 'created_by_profile_id' - 'updated_at' - 'sequence' - 'trip_id') then
    raise exception 'WW-TRIP-004 the calendar entry of a trip is changed in the trip'
      using errcode = '42501', hint = 'trip_event';
  end if;
  return new;
end $$;

create trigger trip_event_guard before update on app.event
  for each row when (old.trip_id is not null) execute function app.trip_event_guard();

-- The overrides of a trip's event: none may be made, changed or removed from the calendar. The
-- deletion that comes with the event itself (a nested statement of the household's deletion)
-- passes.
create function app.trip_override_guard() returns trigger
language plpgsql set search_path = '' as $$
declare v_event uuid := case when tg_op = 'DELETE' then old.event_id else new.event_id end;
begin
  if coalesce(current_setting('app.trip_sync', true), '') <> 'on'
     and not (tg_op = 'DELETE' and pg_trigger_depth() > 1)
     and exists (select 1 from app.event e where e.id = v_event and e.trip_id is not null) then
    raise exception 'WW-TRIP-004 the calendar entry of a trip is changed in the trip'
      using errcode = '42501', hint = 'trip_event';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;

create trigger trip_override_guard before insert or update or delete on app.event_override
  for each row execute function app.trip_override_guard();

revoke all on function app.trip_event_guard(), app.trip_override_guard() from public, anon, authenticated;

-- ================================================================== api: reads

create view api.trips with (security_invoker = true) as
  select t.id, t.title, t.icon_key, t.stage, t.destination_name, t.destination_key, t.country,
         t.lat, t.lon, t.starts_on, t.ends_on, t.note, t.currency, t.created_by_profile_id,
         t.created_at, t.updated_at,
         coalesce((select array_agg(m.profile_id order by p.sort_order, p.id)
                     from app.trip_member m
                     join app.profile p on p.id = m.profile_id
                    where m.trip_id = t.id), '{}') as member_ids,
         (select e.id from app.event e where e.trip_id = t.id and e.deleted_at is null) as event_id
    from app.trip t;

create view api.trip_entries with (security_invoker = true) as
  select e.id, e.trip_id, e.kind, e.mode, e.title, e.state, e.url, e.price_cents, e.price_checked_on,
         e.details, e.note, e.from_place, e.to_place, e.booking_ref, e.cancel_until, e.address,
         e.phone, e.lat, e.lon, e.starts_on, e.starts_time, e.ends_on, e.ends_time, e.position,
         e.source_uid, e.created_by_profile_id, e.created_at, e.updated_at
    from app.trip_entry e;

create view api.trip_combos with (security_invoker = true) as
  select c.id, c.trip_id, c.name, c.position, c.created_by_profile_id, c.created_at, c.updated_at,
         coalesce((select array_agg(ce.entry_id order by ce.entry_id)
                     from app.trip_combo_entry ce where ce.combo_id = c.id), '{}') as entry_ids
    from app.trip_combo c;

create view api.trip_checks with (security_invoker = true) as
  select k.id, k.trip_id, k.kind, k.title, k.profile_id, k.due_days_before, k.done_at,
         k.done_by_profile_id, k.position, k.created_at
    from app.trip_check k;

create view api.trip_home with (security_invoker = true) as
  select h.name, h.lat, h.lon, h.updated_at from app.trip_home h;

grant select on api.trips, api.trip_entries, api.trip_combos, api.trip_checks, api.trip_home
  to authenticated;
revoke all on api.trips, api.trip_entries, api.trip_combos, api.trip_checks, api.trip_home from anon;

-- As in 20261114120000_event_reminder.sql with trip_id appended: the columns before it keep
-- their place.
create or replace view api.events with (security_invoker = true) as
  select e.id, e.calendar_id, e.title, e.description, e.location, e.kind, e.presence_state,
         e.status, e.importance, e.is_all_day, e.starts_at, e.ends_at, e.start_date, e.end_date,
         e.timezone, e.rrule, e.rdates, e.exdates, e.uid, e.sequence, e.created_by_profile_id,
         e.created_at, e.updated_at,
         coalesce((select array_agg(a.profile_id order by p.sort_order, p.id)
                     from app.event_attendee a
                     join app.profile p on p.id = a.profile_id
                    where a.event_id = e.id), '{}') as attendee_ids,
         e.icon_key, e.countdown, e.tradition,
         (select jsonb_build_object('slot', m.slot, 'recipe_id', m.recipe_id, 'free_text', m.free_text,
                                    'title', coalesce(r.title, m.free_text))
            from app.tradition_meal m left join app.recipe r on r.id = m.recipe_id
           where m.event_id = e.id) as tradition_meal,
         e.reminder_minutes,
         e.trip_id
    from app.event e
   where e.deleted_at is null;

-- ================================================================== helpers: failing and reading JSON

-- Raises the invalid-input error of one kind: trip, entry, check, combo or home.
create function app.trip_fail(p_what text) returns void
language plpgsql immutable set search_path = '' as $$
begin
  case p_what
    when 'entry' then
      raise exception 'WW-TRIP-002 trip entry invalid' using errcode = '22023', hint = 'trip_entry_invalid';
    when 'check' then
      raise exception 'WW-TRIP-003 trip check invalid' using errcode = '22023', hint = 'trip_check_invalid';
    when 'home' then
      raise exception 'WW-TRIP-005 trip home invalid' using errcode = '22023', hint = 'trip_home_invalid';
    when 'combo' then
      raise exception 'WW-TRIP-006 trip combination invalid' using errcode = '22023', hint = 'trip_combo_invalid';
    else
      raise exception 'WW-TRIP-001 trip invalid' using errcode = '22023', hint = 'trip_invalid';
  end case;
end $$;

-- Raises the not-found error of one kind: trip, entry, combo or check.
create function app.trip_missing(p_what text) returns void
language plpgsql immutable set search_path = '' as $$
begin
  case p_what
    when 'entry' then
      raise exception 'trip entry not found' using errcode = 'P0002', hint = 'trip_entry_not_found';
    when 'combo' then
      raise exception 'trip combination not found' using errcode = 'P0002', hint = 'trip_combo_not_found';
    when 'check' then
      raise exception 'trip check not found' using errcode = 'P0002', hint = 'trip_check_not_found';
    else
      raise exception 'trip not found' using errcode = 'P0002', hint = 'trip_not_found';
  end case;
end $$;

-- A text key of p_in: absent keeps p_old, null or empty is null, a string is trimmed and at most
-- p_max long; anything else is invalid (of kind p_what).
create function app.trip_jtext(p_in jsonb, p_key text, p_old text, p_max int, p_what text)
returns text language plpgsql stable set search_path = '' as $$
declare v text;
begin
  if not (p_in ? p_key) then
    return p_old;
  end if;
  if jsonb_typeof(p_in -> p_key) = 'null' then
    return null;
  end if;
  if jsonb_typeof(p_in -> p_key) <> 'string' then
    perform app.trip_fail(p_what);
  end if;
  v := nullif(btrim(p_in ->> p_key), '');
  if length(coalesce(v, '')) > p_max then
    perform app.trip_fail(p_what);
  end if;
  return v;
end $$;

-- A date key ('YYYY-MM-DD', a real date).
create function app.trip_jdate(p_in jsonb, p_key text, p_old date, p_what text)
returns date language plpgsql stable set search_path = '' as $$
declare v text := app.trip_jtext(p_in, p_key, null, 10, p_what);
begin
  if not (p_in ? p_key) then
    return p_old;
  end if;
  if v is null then
    return null;
  end if;
  if v !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    perform app.trip_fail(p_what);
  end if;
  begin
    return v::date;
  exception when others then
    perform app.trip_fail(p_what);
  end;
  return null;
end $$;

-- A time key ('HH:MM' or 'HH:MM:SS', no zone).
create function app.trip_jtime(p_in jsonb, p_key text, p_old time, p_what text)
returns time language plpgsql stable set search_path = '' as $$
declare v text := app.trip_jtext(p_in, p_key, null, 8, p_what);
begin
  if not (p_in ? p_key) then
    return p_old;
  end if;
  if v is null then
    return null;
  end if;
  if v !~ '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$' then
    perform app.trip_fail(p_what);
  end if;
  return v::time;
end $$;

-- A number key within p_min and p_max; p_whole demands a whole number. A JSON number only.
create function app.trip_jnum(p_in jsonb, p_key text, p_old numeric, p_min numeric, p_max numeric,
                              p_whole boolean, p_what text)
returns numeric language plpgsql stable set search_path = '' as $$
declare v numeric;
begin
  if not (p_in ? p_key) then
    return p_old;
  end if;
  if jsonb_typeof(p_in -> p_key) = 'null' then
    return null;
  end if;
  if jsonb_typeof(p_in -> p_key) <> 'number' then
    perform app.trip_fail(p_what);
  end if;
  v := (p_in ->> p_key)::numeric;
  if v < p_min or v > p_max or (p_whole and v <> trunc(v)) then
    perform app.trip_fail(p_what);
  end if;
  return v;
end $$;

-- A list of uuids of active profiles of the household (a JSON array, null for none). Distinct,
-- in the order they came. Any other shape, or a profile that is not the household's, is invalid.
create function app.trip_jprofiles(a app.actor_t, p_value jsonb, p_max int, p_what text)
returns uuid[] language plpgsql stable set search_path = '' as $$
declare v_ids uuid[];
begin
  if p_value is null or jsonb_typeof(p_value) = 'null' then
    return '{}';
  end if;
  if jsonb_typeof(p_value) <> 'array' or jsonb_array_length(p_value) > p_max
     or exists (select 1 from jsonb_array_elements(p_value) x
                 where jsonb_typeof(x) <> 'string'
                    or (x #>> '{}') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
    perform app.trip_fail(p_what);
  end if;
  v_ids := array(select u.id from (select (x #>> '{}')::uuid as id, min(o) as o
                                     from jsonb_array_elements(p_value) with ordinality as e(x, o)
                                    group by 1) u order by u.o);
  if (select count(*) from app.profile p
       where p.id = any (v_ids) and p.household_id = a.household_id and p.active) <> cardinality(v_ids) then
    perform app.trip_fail(p_what);
  end if;
  return v_ids;
end $$;

revoke all on function app.trip_fail(text), app.trip_missing(text),
  app.trip_jtext(jsonb, text, text, int, text), app.trip_jdate(jsonb, text, date, text),
  app.trip_jtime(jsonb, text, time, text),
  app.trip_jnum(jsonb, text, numeric, numeric, numeric, boolean, text),
  app.trip_jprofiles(app.actor_t, jsonb, int, text) from public, anon, authenticated;

-- ================================================================== the trip's calendar entry

-- Brings the trip's calendar entry in step with the trip: none for an idea (an existing one is
-- soft-deleted and detached), otherwise one all-day appointment from starts_on to ends_on with
-- the trip's members as attendees. Planned: tentative, importance as the household's default
-- for a new appointment. Fixed: confirmed, importance key, counting down. It writes app.event
-- directly (not through event_save_core, whose rules for members do not apply) and leaves the
-- row as an ordinary all-day event: uid, sequence and updated_at move when something changed.
create function app.trip_event_sync(a app.actor_t, p_trip uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  t           app.trip;
  v_ev        app.event;
  v_exists    boolean;
  v_members   uuid[];
  v_old_att   uuid[];
  v_status    text;
  v_importance text;
  v_countdown boolean;
  v_default   text;
  v_row       boolean;
  v_att       boolean;
  v_id        uuid;
  v_calendar  uuid;
begin
  select * into t from app.trip where id = p_trip and household_id = a.household_id;
  if not found then
    return;
  end if;
  perform set_config('app.trip_sync', 'on', true);

  select * into v_ev from app.event where trip_id = p_trip and deleted_at is null for update;
  v_exists := found;

  if t.stage = 'idea' then
    if v_exists then
      update app.event set deleted_at = now(), trip_id = null, sequence = sequence + 1, updated_at = now()
       where id = v_ev.id;
      perform app.broadcast(a.household_id, 'calendar');
    end if;
  else
    v_members := array(select m.profile_id from app.trip_member m where m.trip_id = p_trip order by m.profile_id);
    if t.stage = 'fixed' then
      v_status := 'confirmed';
      v_importance := 'key';
      v_countdown := true;
    else
      v_status := 'tentative';
      v_countdown := false;
      -- The household's rule for key appointments, as app.event_save_core applies it.
      v_default := app.setting_value(a.household_id, 'calendar.key_default') #>> '{}';
      v_importance := case
        when v_default = 'all' then 'key'
        when v_default = 'none' then 'normal'
        when cardinality(v_members) = 0 or not exists (
               select 1 from app.profile p
                where p.household_id = a.household_id and p.active and not (p.id = any (v_members)))
          then 'key'
        else 'normal'
      end;
    end if;

    if not v_exists then
      v_id := gen_random_uuid();
      select c.id into v_calendar from app.calendar c
       where c.household_id = a.household_id order by c.created_at, c.id limit 1;
      insert into app.event (id, household_id, calendar_id, title, description, location, kind,
                             presence_state, status, importance, is_all_day, start_date, end_date,
                             timezone, uid, created_by_profile_id, icon_key, countdown, trip_id)
      values (v_id, a.household_id, v_calendar, t.title, null, t.destination_name, 'appointment',
              null, v_status, v_importance, true, t.starts_on, t.ends_on,
              (select h.timezone from app.household h where h.id = a.household_id),
              v_id::text || '@wuselwall.app', a.profile_id, t.icon_key, v_countdown, p_trip);
      insert into app.event_attendee (event_id, profile_id, household_id)
        select v_id, x.id, a.household_id from unnest(v_members) as x(id);
      perform app.broadcast(a.household_id, 'calendar');
    else
      v_old_att := array(select ea.profile_id from app.event_attendee ea where ea.event_id = v_ev.id order by ea.profile_id);
      v_att := v_old_att is distinct from v_members;
      v_row := (v_ev.title, v_ev.location, v_ev.icon_key, v_ev.start_date, v_ev.end_date, v_ev.status,
                v_ev.importance, v_ev.countdown)
               is distinct from
               (t.title, t.destination_name, t.icon_key, t.starts_on, t.ends_on, v_status, v_importance,
                v_countdown);
      if v_row or v_att then
        update app.event set
          title = t.title, location = t.destination_name, icon_key = t.icon_key,
          start_date = t.starts_on, end_date = t.ends_on, status = v_status, importance = v_importance,
          countdown = v_countdown, sequence = sequence + 1, updated_at = now()
         where id = v_ev.id;
        if v_att then
          delete from app.event_attendee where event_id = v_ev.id;
          insert into app.event_attendee (event_id, profile_id, household_id)
            select v_ev.id, x.id, a.household_id from unnest(v_members) as x(id);
        end if;
        perform app.broadcast(a.household_id, 'calendar');
      end if;
    end if;
  end if;

  perform set_config('app.trip_sync', 'off', true);
end $$;

revoke all on function app.trip_event_sync(app.actor_t, uuid) from public, anon, authenticated;

-- ================================================================== api: trips

-- Creates or updates a trip. Keys: id (the client's choice makes a retry idempotent), title,
-- icon_key, stage, destination_name, destination_key, country, lat, lon, starts_on, ends_on,
-- note, currency, member_ids. An omitted key keeps its value on update; a null or empty one
-- clears an optional value. A new trip without a currency takes the household's last trip's,
-- else CHF for a household in CH or LI, else EUR. Answers {id, event_id}.
create function api.trip_save(p_actor uuid, p_trip jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a          app.actor_t := app.trip_actor(p_actor);
  c_uuid     constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_id       uuid;
  v_old      app.trip;
  v_found    boolean := false;
  v_title    text;
  v_icon     text;
  v_stage    text;
  v_dname    text;
  v_dkey     text;
  v_country  text;
  v_lat      double precision;
  v_lon      double precision;
  v_starts   date;
  v_ends     date;
  v_note     text;
  v_currency text;
  v_members  uuid[];
begin
  if jsonb_typeof(p_trip) is distinct from 'object' then
    perform app.trip_fail('trip');
  end if;

  if nullif(p_trip ->> 'id', '') is null then
    v_id := gen_random_uuid();
  else
    if jsonb_typeof(p_trip -> 'id') <> 'string' or (p_trip ->> 'id') !~* c_uuid then
      perform app.trip_fail('trip');
    end if;
    v_id := (p_trip ->> 'id')::uuid;
    select * into v_old from app.trip where id = v_id for update;
    v_found := found;
    if v_found and v_old.household_id <> a.household_id then
      perform app.trip_missing('trip');
    end if;
  end if;

  v_title    := app.trip_jtext(p_trip, 'title', v_old.title, 120, 'trip');
  v_icon     := app.trip_jtext(p_trip, 'icon_key', v_old.icon_key, 40, 'trip');
  v_stage    := app.trip_jtext(p_trip, 'stage', v_old.stage, 10, 'trip');
  v_dname    := app.trip_jtext(p_trip, 'destination_name', v_old.destination_name, 120, 'trip');
  v_dkey     := app.trip_jtext(p_trip, 'destination_key', v_old.destination_key, 60, 'trip');
  v_country  := app.trip_jtext(p_trip, 'country', v_old.country, 2, 'trip');
  v_lat      := app.trip_jnum(p_trip, 'lat', v_old.lat::numeric, -90, 90, false, 'trip')::double precision;
  v_lon      := app.trip_jnum(p_trip, 'lon', v_old.lon::numeric, -180, 180, false, 'trip')::double precision;
  v_starts   := app.trip_jdate(p_trip, 'starts_on', v_old.starts_on, 'trip');
  v_ends     := app.trip_jdate(p_trip, 'ends_on', v_old.ends_on, 'trip');
  v_note     := coalesce(app.trip_jtext(p_trip, 'note', v_old.note, 4000, 'trip'), '');
  v_currency := upper(app.trip_jtext(p_trip, 'currency', v_old.currency, 3, 'trip'));

  if not v_found then
    v_stage := case when p_trip ? 'stage' then v_stage else 'idea' end;
    -- The household's habit: the last trip's currency, else its country's.
    v_currency := coalesce(v_currency,
      (select t.currency from app.trip t where t.household_id = a.household_id
        order by t.created_at desc, t.id desc limit 1),
      case when app.household_country(a.household_id) in ('CH', 'LI') then 'CHF' else 'EUR' end);
  end if;

  if v_title is null
     or v_stage is null or v_stage not in ('idea', 'planned', 'fixed')
     or (v_icon is not null and v_icon !~ '^[a-z0-9_]{1,40}$')
     or (v_dkey is not null and v_dkey !~ '^[a-z0-9_-]{1,60}$')
     or (v_country is not null and v_country !~ '^[A-Z]{2}$')
     or (v_lat is null) <> (v_lon is null)
     or (v_starts is null) <> (v_ends is null)
     or (v_stage <> 'idea' and v_starts is null)
     or v_ends < v_starts or v_ends - v_starts > 365
     or v_currency is null or v_currency !~ '^[A-Z]{3}$' then
    perform app.trip_fail('trip');
  end if;

  if p_trip ? 'member_ids' then
    v_members := app.trip_jprofiles(a, p_trip -> 'member_ids', 50, 'trip');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('trip:' || v_id::text, 0));
  if v_found then
    update app.trip set title = v_title, icon_key = v_icon, stage = v_stage, destination_name = v_dname,
           destination_key = v_dkey, country = v_country, lat = v_lat, lon = v_lon,
           starts_on = v_starts, ends_on = v_ends, note = v_note, currency = v_currency,
           updated_at = now()
     where id = v_id;
  else
    insert into app.trip (id, household_id, title, icon_key, stage, destination_name, destination_key,
                          country, lat, lon, starts_on, ends_on, note, currency, created_by_profile_id)
    values (v_id, a.household_id, v_title, v_icon, v_stage, v_dname, v_dkey, v_country, v_lat, v_lon,
            v_starts, v_ends, v_note, v_currency, a.profile_id);
  end if;

  if v_members is not null then
    delete from app.trip_member where trip_id = v_id;
    insert into app.trip_member (trip_id, profile_id, household_id)
      select v_id, x.id, a.household_id from unnest(v_members) as x(id);
  end if;

  perform app.trip_event_sync(a, v_id);
  perform app.audit(a, 'trip', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('title', v_title, 'stage', v_stage));
  perform app.broadcast(a.household_id, 'trips');
  return jsonb_build_object('id', v_id,
    'event_id', (select e.id from app.event e where e.trip_id = v_id and e.deleted_at is null));
end $$;

-- Removes the trip, its entries, combinations and checks, and its calendar entry (soft-deleted
-- like any event, detached from the trip).
create function api.trip_delete(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.trip_actor(p_actor);
  v_trip app.trip;
begin
  select * into v_trip from app.trip where id = p_id and household_id = a.household_id for update;
  if not found then
    perform app.trip_missing('trip');
  end if;
  perform set_config('app.trip_sync', 'on', true);
  update app.event set deleted_at = coalesce(deleted_at, now()), trip_id = null,
         sequence = sequence + 1, updated_at = now()
   where trip_id = p_id;
  delete from app.trip where id = p_id;
  perform set_config('app.trip_sync', 'off', true);
  perform app.audit(a, 'trip', p_id, 'delete', jsonb_build_object('title', v_trip.title));
  perform app.broadcast(a.household_id, 'trips');
  perform app.broadcast(a.household_id, 'calendar');
end $$;

-- ================================================================== entries

-- The entry p_in describes, on top of p_old (null row for a new one): every key validated, an
-- omitted key kept. The server sets price_checked_on: today in the household's zone when a
-- price is entered or changed, null when it is removed. p_state is the state of a new entry
-- that names none. Does not write.
create function app.trip_entry_parse(a app.actor_t, p_in jsonb, p_old app.trip_entry, p_create boolean,
                                     p_state text) returns app.trip_entry
language plpgsql stable set search_path = '' as $$
declare
  r      app.trip_entry := p_old;
  v_mode text;
begin
  r.kind := app.trip_jtext(p_in, 'kind', p_old.kind, 20, 'entry');
  if r.kind is null or r.kind not in ('transport', 'stay', 'rental', 'activity', 'note') then
    perform app.trip_fail('entry');
  end if;

  -- The mode is the transport's alone; a transport without one is "other".
  v_mode := app.trip_jtext(p_in, 'mode', case when r.kind = 'transport' then p_old.mode end, 10, 'entry');
  if r.kind = 'transport' then
    r.mode := coalesce(v_mode, 'other');
    if r.mode not in ('flight', 'train', 'car', 'ferry', 'bus', 'other') then
      perform app.trip_fail('entry');
    end if;
  else
    if v_mode is not null then
      perform app.trip_fail('entry');
    end if;
    r.mode := null;
  end if;

  r.title := app.trip_jtext(p_in, 'title', p_old.title, 200, 'entry');
  r.state := app.trip_jtext(p_in, 'state', case when p_create then p_state else p_old.state end, 10, 'entry');
  r.url   := app.trip_jtext(p_in, 'url', p_old.url, 2000, 'entry');
  r.price_cents := app.trip_jnum(p_in, 'price_cents', p_old.price_cents, 0, 10000000000, true, 'entry');
  r.details     := app.trip_jtext(p_in, 'details', p_old.details, 200, 'entry');
  r.note        := coalesce(app.trip_jtext(p_in, 'note', p_old.note, 4000, 'entry'), '');
  r.from_place  := app.trip_jtext(p_in, 'from_place', p_old.from_place, 80, 'entry');
  r.to_place    := app.trip_jtext(p_in, 'to_place', p_old.to_place, 80, 'entry');
  r.booking_ref := app.trip_jtext(p_in, 'booking_ref', p_old.booking_ref, 80, 'entry');
  r.cancel_until := app.trip_jdate(p_in, 'cancel_until', p_old.cancel_until, 'entry');
  r.address     := app.trip_jtext(p_in, 'address', p_old.address, 300, 'entry');
  r.phone       := app.trip_jtext(p_in, 'phone', p_old.phone, 40, 'entry');
  r.lat := app.trip_jnum(p_in, 'lat', p_old.lat::numeric, -90, 90, false, 'entry')::double precision;
  r.lon := app.trip_jnum(p_in, 'lon', p_old.lon::numeric, -180, 180, false, 'entry')::double precision;
  r.starts_on   := app.trip_jdate(p_in, 'starts_on', p_old.starts_on, 'entry');
  r.starts_time := app.trip_jtime(p_in, 'starts_time', p_old.starts_time, 'entry');
  r.ends_on     := app.trip_jdate(p_in, 'ends_on', p_old.ends_on, 'entry');
  r.ends_time   := app.trip_jtime(p_in, 'ends_time', p_old.ends_time, 'entry');
  r.position    := app.trip_jnum(p_in, 'position', p_old.position, 0, 100000, true, 'entry')::int;
  r.source_uid  := app.trip_jtext(p_in, 'source_uid', p_old.source_uid, 300, 'entry');

  if r.title is null
     or r.state is null or r.state not in ('option', 'chosen', 'booked')
     or (r.url is not null and (r.url !~* '^https?://' or r.url ~ '\s'))
     or (r.lat is null) <> (r.lon is null)
     or (r.starts_time is not null and r.starts_on is null)
     or (r.ends_time is not null and r.ends_on is null)
     or r.ends_on < r.starts_on
     or (r.starts_on is not null and r.starts_on = r.ends_on
         and r.starts_time is not null and r.ends_time is not null and r.ends_time < r.starts_time) then
    perform app.trip_fail('entry');
  end if;

  -- The date of a price is the server's: today for the household when the price is new or changed.
  r.price_checked_on := case
    when r.price_cents is null then null
    when p_create or r.price_cents is distinct from p_old.price_cents then app.tasks_today(a.household_id)
    else p_old.price_checked_on end;
  return r;
end $$;

-- Writes one entry: creates it (p_found false, p_trip the trip) or updates the row p_id. The
-- position of a new entry without one is the last of its kind in the trip, plus one.
create function app.trip_entry_write(a app.actor_t, p_in jsonb, p_id uuid, p_found boolean, p_trip uuid,
                                     p_state text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_old app.trip_entry;
  r     app.trip_entry;
begin
  perform pg_advisory_xact_lock(hashtextextended('trip:' || p_trip::text, 0));
  if p_found then
    select * into v_old from app.trip_entry where id = p_id and household_id = a.household_id for update;
  end if;
  r := app.trip_entry_parse(a, p_in, v_old, not p_found, p_state);

  if p_found then
    update app.trip_entry set kind = r.kind, mode = r.mode, title = r.title, state = r.state, url = r.url,
           price_cents = r.price_cents, price_checked_on = r.price_checked_on, details = r.details,
           note = r.note, from_place = r.from_place, to_place = r.to_place, booking_ref = r.booking_ref,
           cancel_until = r.cancel_until, address = r.address, phone = r.phone, lat = r.lat, lon = r.lon,
           starts_on = r.starts_on, starts_time = r.starts_time, ends_on = r.ends_on,
           ends_time = r.ends_time, position = r.position, source_uid = r.source_uid, updated_at = now()
     where id = p_id;
  else
    insert into app.trip_entry (id, household_id, trip_id, kind, mode, title, state, url, price_cents,
                                price_checked_on, details, note, from_place, to_place, booking_ref,
                                cancel_until, address, phone, lat, lon, starts_on, starts_time, ends_on,
                                ends_time, position, source_uid, created_by_profile_id)
    values (p_id, a.household_id, p_trip, r.kind, r.mode, r.title, r.state, r.url, r.price_cents,
            r.price_checked_on, r.details, r.note, r.from_place, r.to_place, r.booking_ref,
            r.cancel_until, r.address, r.phone, r.lat, r.lon, r.starts_on, r.starts_time, r.ends_on,
            r.ends_time,
            coalesce(r.position, (select coalesce(max(e.position), -1) + 1 from app.trip_entry e
                                   where e.trip_id = p_trip and e.kind = r.kind)),
            r.source_uid, a.profile_id);
  end if;
  perform app.audit(a, 'trip_entry', p_id, case when p_found then 'update' else 'create' end,
                    jsonb_build_object('trip_id', p_trip, 'kind', r.kind, 'title', r.title, 'state', r.state));
  return p_id;
end $$;

revoke all on function app.trip_entry_parse(app.actor_t, jsonb, app.trip_entry, boolean, text),
  app.trip_entry_write(app.actor_t, jsonb, uuid, boolean, uuid, text) from public, anon, authenticated;

-- Creates or updates an entry. Keys: id, trip_id (required on create), kind, mode, title, state,
-- url, price_cents, details, note, from_place, to_place, booking_ref, cancel_until, address,
-- phone, lat, lon, starts_on, starts_time, ends_on, ends_time, position, source_uid. An omitted
-- key keeps its value; a new entry starts as an option. Answers {id}.
create function api.trip_entry_save(p_actor uuid, p_entry jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.trip_actor(p_actor);
  c_uuid   constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_id     uuid;
  v_old    app.trip_entry;
  v_found  boolean := false;
  v_trip   uuid;
begin
  if jsonb_typeof(p_entry) is distinct from 'object' then
    perform app.trip_fail('entry');
  end if;
  if nullif(p_entry ->> 'id', '') is null then
    v_id := gen_random_uuid();
  else
    if jsonb_typeof(p_entry -> 'id') <> 'string' or (p_entry ->> 'id') !~* c_uuid then
      perform app.trip_fail('entry');
    end if;
    v_id := (p_entry ->> 'id')::uuid;
    select * into v_old from app.trip_entry where id = v_id for update;
    v_found := found;
    if v_found and v_old.household_id <> a.household_id then
      perform app.trip_missing('entry');
    end if;
  end if;

  if v_found then
    v_trip := v_old.trip_id;
    if p_entry ? 'trip_id' and (p_entry ->> 'trip_id') is distinct from v_trip::text then
      perform app.trip_fail('entry');
    end if;
  else
    if jsonb_typeof(p_entry -> 'trip_id') is distinct from 'string'
       or (p_entry ->> 'trip_id') !~* c_uuid then
      perform app.trip_fail('entry');
    end if;
    v_trip := (p_entry ->> 'trip_id')::uuid;
    if not exists (select 1 from app.trip t where t.id = v_trip and t.household_id = a.household_id) then
      perform app.trip_missing('trip');
    end if;
  end if;

  perform app.trip_entry_write(a, p_entry, v_id, v_found, v_trip, 'option');
  perform app.broadcast(a.household_id, 'trips');
  return jsonb_build_object('id', v_id);
end $$;

create function api.trip_entry_delete(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.trip_actor(p_actor);
  v app.trip_entry;
begin
  select * into v from app.trip_entry where id = p_id and household_id = a.household_id for update;
  if not found then
    perform app.trip_missing('entry');
  end if;
  delete from app.trip_entry where id = p_id;
  perform app.audit(a, 'trip_entry', p_id, 'delete', jsonb_build_object('trip_id', v.trip_id, 'title', v.title));
  perform app.broadcast(a.household_id, 'trips');
end $$;

-- A copy of an entry as an option, without booking reference and source_uid, placed after the
-- original (the later ones of its kind move one place down). Answers {id}.
create function api.trip_entry_copy(p_actor uuid, p_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a    app.actor_t := app.trip_actor(p_actor);
  v    app.trip_entry;
  v_id uuid := gen_random_uuid();
begin
  select * into v from app.trip_entry where id = p_id and household_id = a.household_id for update;
  if not found then
    perform app.trip_missing('entry');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('trip:' || v.trip_id::text, 0));
  update app.trip_entry set position = least(position + 1, 100000)
   where trip_id = v.trip_id and kind = v.kind and position > v.position;
  insert into app.trip_entry (id, household_id, trip_id, kind, mode, title, state, url, price_cents,
                              price_checked_on, details, note, from_place, to_place, booking_ref,
                              cancel_until, address, phone, lat, lon, starts_on, starts_time, ends_on,
                              ends_time, position, source_uid, created_by_profile_id)
  values (v_id, a.household_id, v.trip_id, v.kind, v.mode, v.title, 'option', v.url, v.price_cents,
          v.price_checked_on, v.details, v.note, v.from_place, v.to_place, null,
          v.cancel_until, v.address, v.phone, v.lat, v.lon, v.starts_on, v.starts_time, v.ends_on,
          v.ends_time, least(v.position + 1, 100000), null, a.profile_id);
  perform app.audit(a, 'trip_entry', v_id, 'copy', jsonb_build_object('trip_id', v.trip_id, 'from', p_id));
  perform app.broadcast(a.household_id, 'trips');
  return jsonb_build_object('id', v_id);
end $$;

-- Takes up to 50 entries from a booking's calendar file: each names its source_uid (1 to 300
-- characters) and carries the fields of api.trip_entry_save. An entry of the trip with the same
-- source_uid is updated, any other is added, by default as booked. Answers {added, updated}.
create function api.trip_entries_import(p_actor uuid, p_trip uuid, p_entries jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.trip_actor(p_actor);
  x         jsonb;
  v_uid     text;
  v_existing uuid;
  v_id      uuid;
  v_added   int := 0;
  v_updated int := 0;
begin
  if not exists (select 1 from app.trip t where t.id = p_trip and t.household_id = a.household_id) then
    perform app.trip_missing('trip');
  end if;
  if jsonb_typeof(p_entries) is distinct from 'array' or jsonb_array_length(p_entries) > 50 then
    perform app.trip_fail('entry');
  end if;
  for x in select e from jsonb_array_elements(p_entries) e loop
    if jsonb_typeof(x) <> 'object' or jsonb_typeof(x -> 'source_uid') is distinct from 'string' then
      perform app.trip_fail('entry');
    end if;
    v_uid := btrim(x ->> 'source_uid');
    if length(v_uid) not between 1 and 300 then
      perform app.trip_fail('entry');
    end if;
    x := x || jsonb_build_object('source_uid', v_uid);
    perform pg_advisory_xact_lock(hashtextextended('trip:' || p_trip::text, 0));
    select e.id into v_existing from app.trip_entry e where e.trip_id = p_trip and e.source_uid = v_uid;
    if found then
      v_id := app.trip_entry_write(a, x - 'id' - 'trip_id', v_existing, true, p_trip, 'booked');
      v_updated := v_updated + 1;
    else
      v_id := app.trip_entry_write(a, x - 'id' - 'trip_id', gen_random_uuid(), false, p_trip, 'booked');
      v_added := v_added + 1;
    end if;
  end loop;
  perform app.broadcast(a.household_id, 'trips');
  return jsonb_build_object('added', v_added, 'updated', v_updated);
end $$;

-- ================================================================== combinations

-- Creates or updates a combination. Keys: id, trip_id (required on create), name, entry_ids
-- (entries of that trip, at most 40; replaces the set). Answers {id}.
create function api.trip_combo_save(p_actor uuid, p_combo jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.trip_actor(p_actor);
  c_uuid  constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_id    uuid;
  v_old   app.trip_combo;
  v_found boolean := false;
  v_trip  uuid;
  v_name  text;
  v_ids   uuid[];
begin
  if jsonb_typeof(p_combo) is distinct from 'object' then
    perform app.trip_fail('combo');
  end if;
  if nullif(p_combo ->> 'id', '') is null then
    v_id := gen_random_uuid();
  else
    if jsonb_typeof(p_combo -> 'id') <> 'string' or (p_combo ->> 'id') !~* c_uuid then
      perform app.trip_fail('combo');
    end if;
    v_id := (p_combo ->> 'id')::uuid;
    select * into v_old from app.trip_combo where id = v_id for update;
    v_found := found;
    if v_found and v_old.household_id <> a.household_id then
      perform app.trip_missing('combo');
    end if;
  end if;

  if v_found then
    v_trip := v_old.trip_id;
    if p_combo ? 'trip_id' and (p_combo ->> 'trip_id') is distinct from v_trip::text then
      perform app.trip_fail('combo');
    end if;
  else
    if jsonb_typeof(p_combo -> 'trip_id') is distinct from 'string' or (p_combo ->> 'trip_id') !~* c_uuid then
      perform app.trip_fail('combo');
    end if;
    v_trip := (p_combo ->> 'trip_id')::uuid;
    if not exists (select 1 from app.trip t where t.id = v_trip and t.household_id = a.household_id) then
      perform app.trip_missing('trip');
    end if;
  end if;

  v_name := app.trip_jtext(p_combo, 'name', v_old.name, 60, 'combo');
  if v_name is null then
    perform app.trip_fail('combo');
  end if;

  if p_combo ? 'entry_ids' then
    if jsonb_typeof(p_combo -> 'entry_ids') is distinct from 'array'
       or jsonb_array_length(p_combo -> 'entry_ids') > 40
       or exists (select 1 from jsonb_array_elements(p_combo -> 'entry_ids') x
                   where jsonb_typeof(x) <> 'string' or (x #>> '{}') !~* c_uuid) then
      perform app.trip_fail('combo');
    end if;
    v_ids := array(select distinct (x #>> '{}')::uuid from jsonb_array_elements(p_combo -> 'entry_ids') x);
    if (select count(*) from app.trip_entry e
         where e.id = any (v_ids) and e.trip_id = v_trip and e.household_id = a.household_id)
       <> cardinality(v_ids) then
      perform app.trip_fail('combo');
    end if;
  end if;

  perform pg_advisory_xact_lock(hashtextextended('trip:' || v_trip::text, 0));
  if v_found then
    update app.trip_combo set name = v_name, updated_at = now() where id = v_id;
  else
    insert into app.trip_combo (id, household_id, trip_id, name, position, created_by_profile_id)
    values (v_id, a.household_id, v_trip, v_name,
            (select coalesce(max(c.position), -1) + 1 from app.trip_combo c where c.trip_id = v_trip),
            a.profile_id);
  end if;
  if v_ids is not null then
    delete from app.trip_combo_entry where combo_id = v_id;
    insert into app.trip_combo_entry (combo_id, entry_id, household_id)
      select v_id, x.id, a.household_id from unnest(v_ids) as x(id);
  end if;

  perform app.audit(a, 'trip_combo', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('trip_id', v_trip, 'name', v_name));
  perform app.broadcast(a.household_id, 'trips');
  return jsonb_build_object('id', v_id);
end $$;

create function api.trip_combo_delete(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.trip_actor(p_actor);
  v app.trip_combo;
begin
  select * into v from app.trip_combo where id = p_id and household_id = a.household_id for update;
  if not found then
    perform app.trip_missing('combo');
  end if;
  delete from app.trip_combo where id = p_id;
  perform app.audit(a, 'trip_combo', p_id, 'delete', jsonb_build_object('trip_id', v.trip_id, 'name', v.name));
  perform app.broadcast(a.household_id, 'trips');
end $$;

-- "Diese nehmen": the combination's options become chosen; every other chosen transport, stay
-- and rental of the trip goes back to option; a booked entry is never touched. With p_set_dates
-- and at least one start among the combination's entries, the trip's dates become the first
-- start to the last end (at most 366 days), and an idea becomes planned. The calendar entry is
-- kept in step. Answers {chosen, released, dates_set}.
create function api.trip_combo_choose(p_actor uuid, p_id uuid, p_set_dates boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a          app.actor_t := app.trip_actor(p_actor);
  v_combo    app.trip_combo;
  v_trip     app.trip;
  v_chosen   int;
  v_released int;
  v_from     date;
  v_to       date;
  v_dates    boolean := false;
begin
  select * into v_combo from app.trip_combo where id = p_id and household_id = a.household_id for update;
  if not found then
    perform app.trip_missing('combo');
  end if;
  select * into v_trip from app.trip where id = v_combo.trip_id for update;

  with up as (
    update app.trip_entry e set state = 'chosen', updated_at = now()
     where e.trip_id = v_combo.trip_id and e.state = 'option'
       and e.id in (select ce.entry_id from app.trip_combo_entry ce where ce.combo_id = p_id)
    returning 1)
  select count(*)::int into v_chosen from up;

  with up as (
    update app.trip_entry e set state = 'option', updated_at = now()
     where e.trip_id = v_combo.trip_id and e.state = 'chosen'
       and e.kind in ('transport', 'stay', 'rental')
       and e.id not in (select ce.entry_id from app.trip_combo_entry ce where ce.combo_id = p_id)
    returning 1)
  select count(*)::int into v_released from up;

  if coalesce(p_set_dates, false) then
    select min(e.starts_on), max(coalesce(e.ends_on, e.starts_on)) into v_from, v_to
      from app.trip_entry e
      join app.trip_combo_entry ce on ce.entry_id = e.id and ce.combo_id = p_id;
    if v_from is not null then
      v_to := greatest(v_to, v_from);
      if v_to - v_from > 365 then
        perform app.trip_fail('trip');
      end if;
      update app.trip set starts_on = v_from, ends_on = v_to,
             stage = case when stage = 'idea' then 'planned' else stage end, updated_at = now()
       where id = v_trip.id;
      v_dates := true;
    end if;
  end if;

  perform app.trip_event_sync(a, v_trip.id);
  perform app.audit(a, 'trip_combo', p_id, 'choose',
                    jsonb_build_object('trip_id', v_trip.id, 'chosen', v_chosen, 'released', v_released,
                                       'dates_set', v_dates));
  perform app.broadcast(a.household_id, 'trips');
  return jsonb_build_object('chosen', v_chosen, 'released', v_released, 'dates_set', v_dates);
end $$;

-- ================================================================== checks

-- One check described by p_in on top of p_old: kind, title, profile_id (an active profile of the
-- household or null), due_days_before (0 to 365, to-dos only). Does not write.
create function app.trip_check_parse(a app.actor_t, p_in jsonb, p_old app.trip_check) returns app.trip_check
language plpgsql stable set search_path = '' as $$
declare r app.trip_check := p_old;
begin
  r.kind  := app.trip_jtext(p_in, 'kind', p_old.kind, 10, 'check');
  r.title := app.trip_jtext(p_in, 'title', p_old.title, 120, 'check');
  if p_in ? 'profile_id' then
    if jsonb_typeof(p_in -> 'profile_id') = 'null' then
      r.profile_id := null;
    else
      r.profile_id := (app.trip_jprofiles(a, jsonb_build_array(p_in -> 'profile_id'), 1, 'check'))[1];
    end if;
  end if;
  r.due_days_before := app.trip_jnum(p_in, 'due_days_before', p_old.due_days_before, 0, 365, true, 'check')::int;
  r.position := app.trip_jnum(p_in, 'position', p_old.position, 0, 100000, true, 'check')::int;
  if r.kind is null or r.kind not in ('pack', 'todo') or r.title is null
     or (r.due_days_before is not null and r.kind <> 'todo') then
    perform app.trip_fail('check');
  end if;
  return r;
end $$;

revoke all on function app.trip_check_parse(app.actor_t, jsonb, app.trip_check) from public, anon, authenticated;

-- Creates or updates a check. Keys: id, trip_id (required on create), kind, title, profile_id,
-- due_days_before (to-dos only), position. Answers {id}.
create function api.trip_check_save(p_actor uuid, p_check jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.trip_actor(p_actor);
  c_uuid  constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_id    uuid;
  v_old   app.trip_check;
  v_found boolean := false;
  v_trip  uuid;
  r       app.trip_check;
begin
  if jsonb_typeof(p_check) is distinct from 'object' then
    perform app.trip_fail('check');
  end if;
  if nullif(p_check ->> 'id', '') is null then
    v_id := gen_random_uuid();
  else
    if jsonb_typeof(p_check -> 'id') <> 'string' or (p_check ->> 'id') !~* c_uuid then
      perform app.trip_fail('check');
    end if;
    v_id := (p_check ->> 'id')::uuid;
    select * into v_old from app.trip_check where id = v_id for update;
    v_found := found;
    if v_found and v_old.household_id <> a.household_id then
      perform app.trip_missing('check');
    end if;
  end if;

  if v_found then
    v_trip := v_old.trip_id;
    if p_check ? 'trip_id' and (p_check ->> 'trip_id') is distinct from v_trip::text then
      perform app.trip_fail('check');
    end if;
  else
    if jsonb_typeof(p_check -> 'trip_id') is distinct from 'string' or (p_check ->> 'trip_id') !~* c_uuid then
      perform app.trip_fail('check');
    end if;
    v_trip := (p_check ->> 'trip_id')::uuid;
    if not exists (select 1 from app.trip t where t.id = v_trip and t.household_id = a.household_id) then
      perform app.trip_missing('trip');
    end if;
  end if;

  r := app.trip_check_parse(a, p_check, v_old);
  perform pg_advisory_xact_lock(hashtextextended('trip:' || v_trip::text, 0));
  if v_found then
    update app.trip_check set kind = r.kind, title = r.title, profile_id = r.profile_id,
           due_days_before = r.due_days_before, position = r.position
     where id = v_id;
  else
    insert into app.trip_check (id, household_id, trip_id, kind, title, profile_id, due_days_before, position)
    values (v_id, a.household_id, v_trip, r.kind, r.title, r.profile_id, r.due_days_before,
            coalesce(r.position, (select coalesce(max(k.position), -1) + 1 from app.trip_check k
                                   where k.trip_id = v_trip and k.kind = r.kind)));
  end if;
  perform app.audit(a, 'trip_check', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('trip_id', v_trip, 'kind', r.kind, 'title', r.title));
  perform app.broadcast(a.household_id, 'trips');
  return jsonb_build_object('id', v_id);
end $$;

-- Adds up to 100 checks at once (the starter list): each {kind, title, profile_id?,
-- due_days_before?}. A check the trip already has for the same kind and person with the same
-- title (compared trimmed and ignoring case) is skipped. Answers {added}.
create function api.trip_checks_add(p_actor uuid, p_trip uuid, p_checks jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.trip_actor(p_actor);
  x       jsonb;
  r       app.trip_check;
  v_added int := 0;
begin
  if not exists (select 1 from app.trip t where t.id = p_trip and t.household_id = a.household_id) then
    perform app.trip_missing('trip');
  end if;
  if jsonb_typeof(p_checks) is distinct from 'array' or jsonb_array_length(p_checks) > 100 then
    perform app.trip_fail('check');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('trip:' || p_trip::text, 0));
  for x in select e from jsonb_array_elements(p_checks) e loop
    if jsonb_typeof(x) <> 'object' then
      perform app.trip_fail('check');
    end if;
    r := app.trip_check_parse(a, x - 'id' - 'trip_id', null);
    if not exists (select 1 from app.trip_check k
                    where k.trip_id = p_trip and k.kind = r.kind
                      and k.profile_id is not distinct from r.profile_id
                      and lower(btrim(k.title)) = lower(btrim(r.title))) then
      insert into app.trip_check (household_id, trip_id, kind, title, profile_id, due_days_before, position)
      values (a.household_id, p_trip, r.kind, r.title, r.profile_id, r.due_days_before,
              coalesce(r.position, (select coalesce(max(k.position), -1) + 1 from app.trip_check k
                                     where k.trip_id = p_trip and k.kind = r.kind)));
      v_added := v_added + 1;
    end if;
  end loop;
  perform app.audit(a, 'trip_check', p_trip, 'add', jsonb_build_object('added', v_added));
  perform app.broadcast(a.household_id, 'trips');
  return jsonb_build_object('added', v_added);
end $$;

-- Copies the checks of p_from to p_to, unticked, skipping the ones p_to has (as trip_checks_add).
-- Answers {added}.
create function api.trip_checks_copy(p_actor uuid, p_from uuid, p_to uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.trip_actor(p_actor);
  c       app.trip_check;
  v_added int := 0;
begin
  if (select count(*) from app.trip t
       where t.id in (p_from, p_to) and t.household_id = a.household_id) <> (case when p_from = p_to then 1 else 2 end) then
    perform app.trip_missing('trip');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('trip:' || p_to::text, 0));
  for c in select k.* from app.trip_check k where k.trip_id = p_from order by k.kind, k.position, k.id loop
    if not exists (select 1 from app.trip_check k
                    where k.trip_id = p_to and k.kind = c.kind
                      and k.profile_id is not distinct from c.profile_id
                      and lower(btrim(k.title)) = lower(btrim(c.title))) then
      insert into app.trip_check (household_id, trip_id, kind, title, profile_id, due_days_before, position)
      values (a.household_id, p_to, c.kind, c.title, c.profile_id, c.due_days_before, c.position);
      v_added := v_added + 1;
    end if;
  end loop;
  perform app.audit(a, 'trip_check', p_to, 'copy', jsonb_build_object('from', p_from, 'added', v_added));
  perform app.broadcast(a.household_id, 'trips');
  return jsonb_build_object('added', v_added);
end $$;

-- Ticks (p_done true, by the acting profile, now; an already ticked check keeps its first tick)
-- or unticks a check.
create function api.trip_check_tick(p_actor uuid, p_id uuid, p_done boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.trip_actor(p_actor);
begin
  if p_done is null then
    perform app.trip_fail('check');
  end if;
  perform 1 from app.trip_check where id = p_id and household_id = a.household_id for update;
  if not found then
    perform app.trip_missing('check');
  end if;
  if p_done then
    update app.trip_check set done_at = coalesce(done_at, now()),
           done_by_profile_id = case when done_at is null then a.profile_id else done_by_profile_id end
     where id = p_id;
  else
    update app.trip_check set done_at = null, done_by_profile_id = null where id = p_id;
  end if;
  perform app.audit(a, 'trip_check', p_id, case when p_done then 'tick' else 'untick' end);
  perform app.broadcast(a.household_id, 'trips');
end $$;

create function api.trip_check_delete(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.trip_actor(p_actor);
  v app.trip_check;
begin
  select * into v from app.trip_check where id = p_id and household_id = a.household_id for update;
  if not found then
    perform app.trip_missing('check');
  end if;
  delete from app.trip_check where id = p_id;
  perform app.audit(a, 'trip_check', p_id, 'delete', jsonb_build_object('trip_id', v.trip_id, 'title', v.title));
  perform app.broadcast(a.household_id, 'trips');
end $$;

-- ================================================================== the home place

-- The family's home place, for the travel effort: {name, lat, lon}, or null to forget it. A
-- guardian's. The coordinates are rounded to two decimals.
create function api.trip_home_set(p_actor uuid, p_home jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.trip_actor(p_actor);
  v_name text;
  v_lat  numeric;
  v_lon  numeric;
begin
  perform app.require_guardian(a);
  if p_home is null or jsonb_typeof(p_home) = 'null' then
    delete from app.trip_home where household_id = a.household_id;
    perform app.audit(a, 'trip_home', a.household_id, 'delete');
    perform app.broadcast(a.household_id, 'trips');
    return;
  end if;
  if jsonb_typeof(p_home) <> 'object'
     or jsonb_typeof(p_home -> 'lat') is distinct from 'number'
     or jsonb_typeof(p_home -> 'lon') is distinct from 'number' then
    perform app.trip_fail('home');
  end if;
  v_name := coalesce(app.trip_jtext(p_home, 'name', null, 120, 'home'), '');
  v_lat  := app.trip_jnum(p_home, 'lat', null, -90, 90, false, 'home');
  v_lon  := app.trip_jnum(p_home, 'lon', null, -180, 180, false, 'home');
  insert into app.trip_home (household_id, name, lat, lon, updated_at)
  values (a.household_id, v_name, round(v_lat, 2), round(v_lon, 2), now())
  on conflict (household_id) do update set
    name = excluded.name, lat = excluded.lat, lon = excluded.lon, updated_at = now();
  perform app.audit(a, 'trip_home', a.household_id, 'set',
                    jsonb_build_object('name', v_name, 'lat', round(v_lat, 2), 'lon', round(v_lon, 2)));
  perform app.broadcast(a.household_id, 'trips');
end $$;

-- ================================================================== grants

revoke all on function
  api.trip_save(uuid, jsonb), api.trip_delete(uuid, uuid),
  api.trip_entry_save(uuid, jsonb), api.trip_entry_delete(uuid, uuid), api.trip_entry_copy(uuid, uuid),
  api.trip_entries_import(uuid, uuid, jsonb),
  api.trip_combo_save(uuid, jsonb), api.trip_combo_delete(uuid, uuid),
  api.trip_combo_choose(uuid, uuid, boolean),
  api.trip_check_save(uuid, jsonb), api.trip_checks_add(uuid, uuid, jsonb),
  api.trip_checks_copy(uuid, uuid, uuid), api.trip_check_tick(uuid, uuid, boolean),
  api.trip_check_delete(uuid, uuid), api.trip_home_set(uuid, jsonb)
  from public, anon;
grant execute on function
  api.trip_save(uuid, jsonb), api.trip_delete(uuid, uuid),
  api.trip_entry_save(uuid, jsonb), api.trip_entry_delete(uuid, uuid), api.trip_entry_copy(uuid, uuid),
  api.trip_entries_import(uuid, uuid, jsonb),
  api.trip_combo_save(uuid, jsonb), api.trip_combo_delete(uuid, uuid),
  api.trip_combo_choose(uuid, uuid, boolean),
  api.trip_check_save(uuid, jsonb), api.trip_checks_add(uuid, uuid, jsonb),
  api.trip_checks_copy(uuid, uuid, uuid), api.trip_check_tick(uuid, uuid, boolean),
  api.trip_check_delete(uuid, uuid), api.trip_home_set(uuid, jsonb)
  to authenticated;

-- ================================================================== export

-- Beside the other calendar tables.
insert into app.export_table (name, position, omit, keep) values
  ('trip',             83, '{}', null),
  ('trip_member',      84, '{}', null),
  ('trip_entry',       85, '{}', null),
  ('trip_combo',       86, '{}', null),
  ('trip_combo_entry', 87, '{}', null),
  ('trip_check',       88, '{}', null),
  ('trip_home',        89, '{}', null);

-- ================================================================== announce

-- As in 20261115100000_services.sql, plus 'trips'.
create or replace function api.server_info()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'api_version', 1,
    'min_app_version', '1.0.0',
    'household_creation', case when app.household_creation_mode() = 'code' then 'token' else 'open' end,
    'claimed', app.server_claimed(),
    'features', jsonb_build_array(
      'calendar', 'ics', 'calendar-import', 'school', 'tasks', 'meals', 'shopping', 'holidays',
      'lighter-day', 'event-templates', 'password-reset', 'claim', 'local-matching', 'event-import',
      'shopping-start', 'event-reminder', 'services', 'trips'
    )
  );
$$;
