-- Regions in any depth and imported holidays (specs/04 "School", ADR-008, ADR-013).
--
-- A region is an OpenHolidays subdivision code: CH, CH-ZH (canton), CH-ZH-ZH (district),
-- CH-ZH-ZH-ZH (municipality), DE-BY, AT-9. app.region is public reference data, filled by the
-- holidays sync (an Edge Function with the service role, from openholidaysapi.org); no household
-- writes it. app.holiday_feed is the same kind of cache: public holidays (Feiertage) and school
-- holidays (Ferien) per country, with the subdivisions they apply to. A household imports the
-- feed rows it wants into app.school_holiday (kind public_holiday or holiday, feed_id set), so
-- the imported rows are ordinary holidays that the projection and the ICS feed already read.

-- ------------------------------------------------------------------ tables

create table app.region (
  code        text primary key check (code ~ '^[A-Z]{2}(-[A-Z0-9]{1,6}){1,4}$'),
  country     text not null check (country ~ '^[A-Z]{2}$'),
  parent_code text,                       -- null for level 1; no foreign key, the sync inserts in any order
  level       smallint not null check (level between 1 and 4),
  category    text not null,              -- source label: Kanton, Bezirk, Gemeinde, Bundesland, ...
  short_name  text not null,
  names       jsonb not null check (jsonb_typeof(names) = 'object'),  -- language -> name
  fetched_at  timestamptz not null default now(),
  check (split_part(code, '-', 1) = country),
  check (level = array_length(string_to_array(code, '-'), 1) - 1)
);
create index on app.region (country, parent_code);

create table app.holiday_feed (
  id           text primary key,          -- OpenHolidays id
  country      text not null check (country ~ '^[A-Z]{2}$'),
  kind         text not null check (kind in ('public', 'school')),
  starts_on    date not null,
  ends_on      date not null check (ends_on >= starts_on),
  names        jsonb not null check (jsonb_typeof(names) = 'object'),
  nationwide   boolean not null,
  subdivisions text[] not null default '{}',
  fetched_at   timestamptz not null default now()
);
create index on app.holiday_feed (country, starts_on);

-- Bookkeeping per country: when the sync asked, when it last succeeded, and what it covers.
create table app.holiday_feed_sync (
  country      text primary key check (country ~ '^[A-Z]{2}$'),
  requested_at timestamptz,
  fetched_at   timestamptz,
  valid_from   date,
  valid_to     date,
  last_error   text
);

-- A school holiday or public holiday imported from the feed carries the feed id. A feed row is
-- imported once per household and school (public holidays have no school).
alter table app.school_holiday add column feed_id text;
alter table app.school_holiday drop constraint school_holiday_kind_check;
alter table app.school_holiday add constraint school_holiday_kind_check
  check (kind in ('holiday', 'closure_day', 'public_holiday'));
create unique index school_holiday_feed_once on app.school_holiday
  (household_id, coalesce(school_id, '00000000-0000-0000-0000-000000000000'::uuid), feed_id)
  where feed_id is not null;

-- ------------------------------------------------------------------ RLS

alter table app.region            enable row level security;
alter table app.holiday_feed      enable row level security;
alter table app.holiday_feed_sync enable row level security;
alter table app.region            force row level security;
alter table app.holiday_feed      force row level security;
alter table app.holiday_feed_sync force row level security;

-- Public data: any authenticated session reads it, nobody but the sync writes it.
create policy region_read on app.region for select to authenticated using (true);
create policy holiday_feed_read on app.holiday_feed for select to authenticated using (true);
create policy holiday_feed_sync_read on app.holiday_feed_sync for select to authenticated using (true);
create policy owner_all on app.region            to postgres using (true) with check (true);
create policy owner_all on app.holiday_feed      to postgres using (true) with check (true);
create policy owner_all on app.holiday_feed_sync to postgres using (true) with check (true);

revoke all on app.region, app.holiday_feed, app.holiday_feed_sync from public, anon, authenticated;
grant select on app.region, app.holiday_feed, app.holiday_feed_sync to authenticated;
-- The holidays sync runs with the service role (it bypasses RLS there, as on every table).
grant usage on schema app to service_role;
grant select, insert, update, delete on app.region, app.holiday_feed, app.holiday_feed_sync to service_role;

-- ------------------------------------------------------------------ school region

alter table app.school add column region_code text
  check (region_code is null or region_code ~ '^[A-Z]{2}(-[A-Z0-9]{1,6}){1,4}$');
-- A region's second segment can be longer than the three characters the old state code allowed;
-- state_code is the first two segments, so it must take them too.
alter table app.school drop constraint school_state_code_check;
alter table app.school add constraint school_state_code_check
  check (state_code is null or state_code ~ '^[A-Z]{2}-[A-Z0-9]{1,6}$');
update app.school set region_code = state_code where state_code is not null;

-- ------------------------------------------------------------------ household setting

-- The household's own region (for school holidays and the holiday import). Any depth.
alter table app.setting_definition drop constraint setting_definition_type_check;
alter table app.setting_definition add constraint setting_definition_type_check
  check (type in ('boolean', 'integer', 'time', 'enum', 'weekday_time', 'time_range', 'times', 'region'));

insert into app.setting_definition (key, scope, type, default_value, constraints, self_service, since_migration) values
  ('household.region', 'household', 'region', 'null', '{"nullable":true}', false, '20261014120000');

-- ------------------------------------------------------------------ internals

-- Is p_value a legal value for the definition? JSON null is legal only where nullable.
create or replace function app.setting_valid(p_def app.setting_definition, p_value jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare
  c_time constant text := '^([01][0-9]|2[0-3]):[0-5][0-9]$';
  v_kind text := jsonb_typeof(p_value);
  v_n    numeric;
  v_min  numeric := (p_def.constraints ->> 'min')::numeric;
  v_max  numeric := (p_def.constraints ->> 'max')::numeric;
begin
  if p_value is null then
    return false;
  end if;
  if v_kind = 'null' then
    return coalesce((p_def.constraints ->> 'nullable')::boolean, false);
  end if;

  case p_def.type
    when 'boolean' then
      return v_kind = 'boolean';

    when 'integer' then
      if v_kind <> 'number' then
        return false;
      end if;
      v_n := (p_value #>> '{}')::numeric;
      return v_n = trunc(v_n)
         and (v_min is null or v_n >= v_min)
         and (v_max is null or v_n <= v_max);

    when 'time' then
      return v_kind = 'string' and (p_value #>> '{}') ~ c_time;

    when 'enum' then
      return v_kind = 'string'
         and coalesce((p_def.constraints -> 'values') @> jsonb_build_array(p_value), false);

    when 'weekday_time' then
      if v_kind <> 'object' then
        return false;
      end if;
      return coalesce(jsonb_typeof(p_value -> 'weekday') = 'number'
         and (p_value ->> 'weekday') ~ '^[1-7]$'
         and jsonb_typeof(p_value -> 'time') = 'string'
         and (p_value ->> 'time') ~ c_time, false);

    when 'time_range' then
      if v_kind <> 'object' then
        return false;
      end if;
      return coalesce(jsonb_typeof(p_value -> 'from') = 'string'
         and (p_value ->> 'from') ~ c_time
         and jsonb_typeof(p_value -> 'to') = 'string'
         and (p_value ->> 'to') ~ c_time, false);

    when 'times' then
      if v_kind <> 'array' or jsonb_array_length(p_value) <> 2 then
        return false;
      end if;
      if jsonb_typeof(p_value -> 0) <> 'string' or jsonb_typeof(p_value -> 1) <> 'string'
         or (p_value ->> 0) !~ c_time or (p_value ->> 1) !~ c_time then
        return false;
      end if;
      return (p_value ->> 0)::time < (p_value ->> 1)::time;

    when 'region' then
      return v_kind = 'string'
         and (p_value #>> '{}') ~ '^[A-Z]{2}(-[A-Z0-9]{1,6}){1,4}$';

    else
      return false;
  end case;
end $$;

-- Does a holiday of country p_country (nationwide, or for these subdivisions) apply to p_region?
-- CH-ZH covers CH-ZH-ZH-ZH; CH-ZH-ZH-ZH does not cover CH-ZH; CH-AG does not cover CH-AGX.
create function app.region_covers(p_region text, p_country text, p_nationwide boolean, p_subdivisions text[])
returns boolean language sql immutable set search_path = '' as $$
  select split_part(p_region, '-', 1) = p_country
     and (p_nationwide
          or exists (select 1 from unnest(p_subdivisions) s
                      where p_region = s or starts_with(p_region, s || '-')))
$$;

-- ------------------------------------------------------------------ api: reads

create view api.regions with (security_invoker = true) as
  select code, country, parent_code, level, category, short_name, names from app.region;

create view api.holiday_feed_status with (security_invoker = true) as
  select country, fetched_at, valid_from, valid_to, last_error from app.holiday_feed_sync;

-- region_code is appended; the rest of the view is unchanged.
create or replace view api.schools with (security_invoker = true) as
  select id, name, state_code, timezone, created_at, region_code from app.school;

-- feed_id is appended.
create or replace view api.school_holidays with (security_invoker = true) as
  select id, school_id, name, starts_on, ends_on, kind, source, source_url, feed_id from app.school_holiday;

grant select on api.regions, api.holiday_feed_status to authenticated;
revoke all on api.regions, api.holiday_feed_status from public, anon;

-- ------------------------------------------------------------------ api: school

-- Insert or update a school. On insert the bell-time template and, when the household has no
-- subjects yet, the starter subjects are written too. The starter content is example data; the
-- family renames it, so it is not a rule of the module. The starter list follows the country.
--
-- The region is sent as region_code (any depth; state_code becomes its first two segments). A
-- caller that only knows state_code (the previous app release) sets both to that value.
create or replace function api.school_save(p_actor uuid, p_school jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_old     app.school;
  v_found   boolean;
  v_id      uuid;
  v_name    text;
  v_region  text;
  v_state   text;
  v_tz      text;
  v_country text;
  c_region  constant text := '^[A-Z]{2}(-[A-Z0-9]{1,6}){1,4}$';
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_school) is distinct from 'object' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  v_id := coalesce(app.school_uuid(p_school -> 'id'), gen_random_uuid());
  select * into v_old from app.school where id = v_id;
  v_found := found;
  if v_found and v_old.household_id <> a.household_id then
    raise exception 'school not found' using errcode = 'P0002', hint = 'school_not_found';
  end if;

  v_name := app.school_text(p_school -> 'name', 120);
  if v_name is null then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  -- A key that is not sent keeps the stored value; a sent null clears it.
  if p_school ? 'region_code' then
    v_region := app.school_text(p_school -> 'region_code', 30);
    if v_region is not null and v_region !~ c_region then
      raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'invalid_region';
    end if;
    v_state := case when v_region is null then null
                    else split_part(v_region, '-', 1) || '-' || split_part(v_region, '-', 2) end;
  elsif p_school ? 'state_code' then
    v_state := app.school_text(p_school -> 'state_code', 6);
    if v_state is not null and v_state !~ '^[A-Z]{2}-[A-Z0-9]{1,6}$' then
      raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
    end if;
    v_region := v_state;
  else
    v_region := v_old.region_code;
    v_state := v_old.state_code;
  end if;
  v_tz := coalesce(
    case when p_school ? 'timezone' then app.school_text(p_school -> 'timezone', 64) end,
    case when v_found then v_old.timezone end,
    (select h.timezone from app.household h where h.id = a.household_id));
  if not exists (select 1 from pg_timezone_names n where n.name = v_tz) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  if v_found then
    update app.school set name = v_name, state_code = v_state, region_code = v_region, timezone = v_tz
     where id = v_id;
  else
    insert into app.school (id, household_id, name, state_code, region_code, timezone)
    values (v_id, a.household_id, v_name, v_state, v_region, v_tz);

    -- Bell-time template: six 45-minute lessons from 08:00, a 5-minute break after lessons 1, 3
    -- and 5, a 20-minute break after lessons 2 and 4.
    insert into app.school_period (household_id, school_id, index, label, starts_at, ends_at, kind)
    select a.household_id, v_id, t.idx, null, t.starts_at, t.ends_at, t.kind
      from (values
        (1, '08:00'::time, '08:45'::time, 'lesson'),
        (1, '08:45'::time, '08:50'::time, 'break'),
        (2, '08:50'::time, '09:35'::time, 'lesson'),
        (2, '09:35'::time, '09:55'::time, 'break'),
        (3, '09:55'::time, '10:40'::time, 'lesson'),
        (3, '10:40'::time, '10:45'::time, 'break'),
        (4, '10:45'::time, '11:30'::time, 'lesson'),
        (4, '11:30'::time, '11:50'::time, 'break'),
        (5, '11:50'::time, '12:35'::time, 'lesson'),
        (5, '12:35'::time, '12:40'::time, 'break'),
        (6, '12:40'::time, '13:25'::time, 'lesson')
      ) as t (idx, starts_at, ends_at, kind);

    -- Starter subjects, written only into an empty subject list. The icon keys are opaque: the
    -- app maps them to its icon set. Swiss (Lehrplan 21, CH and LI) and Austrian lists; every
    -- other country gets the German list.
    v_country := split_part(coalesce(v_region, ''), '-', 1);
    if not exists (select 1 from app.subject s where s.household_id = a.household_id) then
      if v_country in ('CH', 'LI') then
        insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
        values
          (a.household_id, 'Deutsch', 'De', 'rose', 'book', null, false),
          (a.household_id, 'Mathematik', 'Ma', 'blue', 'numbers', null, false),
          (a.household_id, 'Natur, Mensch, Gesellschaft', 'NMG', 'leaf', 'globe', null, false),
          (a.household_id, 'Englisch', 'En', 'lilac', 'chat', null, false),
          (a.household_id, 'Französisch', 'Fr', 'mint', 'chat', null, false),
          (a.household_id, 'Bildnerisches Gestalten', 'BG', 'peach', 'palette', null, false),
          (a.household_id, 'Textiles und Technisches Gestalten', 'TTG', 'stone', 'hands', null, false),
          (a.household_id, 'Musik', 'Mu', 'lemon', 'music', null, false),
          (a.household_id, 'Bewegung und Sport', 'Sp', 'peach', 'run', 'Sportsachen', true),
          (a.household_id, 'Medien und Informatik', 'MI', 'blue', 'numbers', null, false);
      elsif v_country = 'AT' then
        insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
        values
          (a.household_id, 'Deutsch', 'D', 'rose', 'book', null, false),
          (a.household_id, 'Mathematik', 'Ma', 'blue', 'numbers', null, false),
          (a.household_id, 'Sachunterricht', 'SU', 'leaf', 'globe', null, false),
          (a.household_id, 'Englisch', 'E', 'lilac', 'chat', null, false),
          (a.household_id, 'Bildnerische Erziehung', 'BE', 'mint', 'palette', null, false),
          (a.household_id, 'Musikerziehung', 'Mu', 'lemon', 'music', null, false),
          (a.household_id, 'Bewegung und Sport', 'Sp', 'peach', 'run', 'Sportsachen', true),
          (a.household_id, 'Technisches und textiles Werken', 'TTW', 'stone', 'hands', null, false),
          (a.household_id, 'Religion', 'Rel', 'stone', 'hands', null, false);
      else
        insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
        values
          (a.household_id, 'Deutsch', 'D', 'rose', 'book', null, false),
          (a.household_id, 'Mathematik', 'Ma', 'blue', 'numbers', null, false),
          (a.household_id, 'Sachunterricht', 'SU', 'leaf', 'globe', null, false),
          (a.household_id, 'Englisch', 'E', 'lilac', 'chat', null, false),
          (a.household_id, 'Musik', 'Mu', 'lemon', 'music', null, false),
          (a.household_id, 'Kunst', 'Ku', 'mint', 'palette', null, false),
          (a.household_id, 'Religion/Ethik', 'Rel', 'stone', 'hands', null, false),
          (a.household_id, 'Sport', 'Sp', 'peach', 'run', 'Sportsachen', true),
          (a.household_id, 'Schwimmen', 'Sw', 'peach', 'swim', 'Schwimmsachen', true);
      end if;
    end if;
  end if;

  perform app.audit(a, 'school', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('name', v_name));
  perform app.broadcast(a.household_id, 'school');
  return jsonb_build_object('id', v_id);
end $$;

-- ------------------------------------------------------------------ api: holidays

-- A holiday with no school applies to every school of the household. Public holidays are
-- stored without a school; imported school holidays name their school.
create or replace function api.school_holiday_save(p_actor uuid, p_holiday jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_old     app.school_holiday;
  v_found   boolean;
  v_id      uuid;
  v_school  uuid;
  v_name    text;
  v_start   date;
  v_end     date;
  v_kind    text;
  v_source  text;
  v_url     text;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_holiday) is distinct from 'object' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  v_id := coalesce(app.school_uuid(p_holiday -> 'id'), gen_random_uuid());
  select * into v_old from app.school_holiday where id = v_id;
  v_found := found;
  if v_found and v_old.household_id <> a.household_id then
    raise exception 'holiday not found' using errcode = 'P0002', hint = 'holiday_not_found';
  end if;

  v_school := app.school_uuid(p_holiday -> 'school_id');
  if v_school is not null
     and not exists (select 1 from app.school s where s.id = v_school and s.household_id = a.household_id) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  v_name := app.school_text(p_holiday -> 'name', 80);
  v_start := app.school_date(p_holiday -> 'starts_on');
  v_end := app.school_date(p_holiday -> 'ends_on');
  v_kind := coalesce(p_holiday ->> 'kind', '');
  v_source := coalesce(nullif(p_holiday ->> 'source', ''), 'manual');
  v_url := app.school_text(p_holiday -> 'source_url', 300);
  if v_name is null or v_start is null or v_end is null or v_end < v_start
     or v_kind not in ('holiday', 'closure_day', 'public_holiday') or v_source not in ('manual', 'imported') then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  -- feed_id is never changed here: only the import sets it.
  if v_found then
    update app.school_holiday set school_id = v_school, name = v_name, starts_on = v_start, ends_on = v_end,
           kind = v_kind, source = v_source, source_url = v_url
     where id = v_id;
  else
    insert into app.school_holiday (id, household_id, school_id, name, starts_on, ends_on, kind, source, source_url)
    values (v_id, a.household_id, v_school, v_name, v_start, v_end, v_kind, v_source, v_url);
  end if;

  perform app.audit(a, 'school_holiday', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('name', v_name, 'starts_on', v_start, 'ends_on', v_end));
  perform app.broadcast(a.household_id, 'school');
  return jsonb_build_object('id', v_id);
end $$;

-- What the import would bring for a region and a window: every feed row that covers the region
-- and overlaps the dates. Any member may look. Without a school only public holidays come back.
create function api.holiday_import_preview(p_actor uuid, p_school_id uuid, p_region text, p_from date, p_to date)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  c_region  constant text := '^[A-Z]{2}(-[A-Z0-9]{1,6}){1,4}$';
  v_out     jsonb;
begin
  if p_school_id is not null
     and not exists (select 1 from app.school s where s.id = p_school_id and s.household_id = a.household_id) then
    raise exception 'school not found' using errcode = 'P0002', hint = 'school_not_found';
  end if;
  if p_region is null or p_region !~ c_region then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'invalid_region';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  if p_to - p_from > 800 then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'window_too_large';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'feed_id', f.id,
           'kind', case when f.kind = 'public' then 'public_holiday' else 'holiday' end,
           'names', f.names,
           'starts_on', f.starts_on,
           'ends_on', f.ends_on,
           'already_imported', exists (select 1 from app.school_holiday h
                where h.household_id = a.household_id and h.feed_id = f.id
                  and (f.kind = 'public' or h.school_id = p_school_id)),
           -- Manual rows (no feed id) for this school or for every school that overlap the dates.
           'overlaps_existing', exists (select 1 from app.school_holiday m
                where m.household_id = a.household_id and m.feed_id is null
                  and (m.school_id is null or m.school_id = p_school_id)
                  and m.starts_on <= f.ends_on and m.ends_on >= f.starts_on)
         ) order by f.starts_on, f.id), '[]'::jsonb)
    into v_out
    from app.holiday_feed f
   where app.region_covers(p_region, f.country, f.nationwide, f.subdivisions)
     and f.starts_on <= p_to and f.ends_on >= p_from
     and (f.kind = 'public' or p_school_id is not null);

  return v_out;
end $$;

-- Imports feed rows into the household. Public holidays are stored without a school; school
-- holidays for p_school_id. A row already imported (same feed id, same school) is skipped, so a
-- second call inserts nothing. Unknown feed ids are ignored. Returns the number inserted.
create function api.holiday_import(p_actor uuid, p_school_id uuid, p_feed_ids text[], p_lang text)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  f      app.holiday_feed;
  v_name text;
  v_id   uuid;
  v_n    int := 0;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if p_school_id is not null
     and not exists (select 1 from app.school s where s.id = p_school_id and s.household_id = a.household_id) then
    raise exception 'school not found' using errcode = 'P0002', hint = 'school_not_found';
  end if;

  for f in select * from app.holiday_feed
            where id = any(coalesce(p_feed_ids, '{}')) order by starts_on, id loop
    if f.kind = 'school' and p_school_id is null then
      raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_required';
    end if;
    if exists (select 1 from app.school_holiday h
                where h.household_id = a.household_id and h.feed_id = f.id
                  and (f.kind = 'public' or h.school_id = p_school_id)) then
      continue;
    end if;

    -- The household's language, else German, else any name the feed has.
    v_name := left(nullif(btrim(coalesce(
                f.names ->> lower(split_part(coalesce(p_lang, ''), '-', 1)),
                f.names ->> 'de',
                (select e.value from jsonb_each_text(f.names) e
                  where nullif(btrim(e.value), '') is not null limit 1))), ''), 80);
    if v_name is null then
      continue;
    end if;

    insert into app.school_holiday (household_id, school_id, name, starts_on, ends_on, kind, source, source_url, feed_id)
    values (a.household_id, case when f.kind = 'public' then null else p_school_id end, v_name,
            f.starts_on, f.ends_on, case when f.kind = 'public' then 'public_holiday' else 'holiday' end,
            'imported', 'https://openholidaysapi.org', f.id)
    returning id into v_id;

    perform app.audit(a, 'school_holiday', v_id, 'create', jsonb_build_object(
      'name', v_name, 'starts_on', f.starts_on, 'ends_on', f.ends_on, 'feed_id', f.id));
    v_n := v_n + 1;
  end loop;

  if v_n > 0 then
    perform app.broadcast(a.household_id, 'school');
  end if;
  return v_n;
end $$;

-- ------------------------------------------------------------------ grants

revoke all on function api.school_save(uuid, jsonb), api.school_holiday_save(uuid, jsonb),
  api.holiday_import_preview(uuid, uuid, text, date, date), api.holiday_import(uuid, uuid, text[], text)
  from public, anon;
grant execute on function api.school_save(uuid, jsonb), api.school_holiday_save(uuid, jsonb),
  api.holiday_import_preview(uuid, uuid, text, date, date), api.holiday_import(uuid, uuid, text[], text)
  to authenticated;

-- Internal: PUBLIC may execute new app functions unless revoked here.
revoke all on function app.region_covers(text, text, boolean, text[]) from public, anon, authenticated;
