-- Region codes with umlauts. OpenHolidays writes some subdivision codes with Ä, Ö or Ü: the
-- Austrian states AT-KÄ, AT-NÖ and AT-OÖ, and 38 Swiss municipalities (CH-BE-SL-RÜ, ...).
-- The checks of 20261014120000_regions_holidays allowed A-Z and 0-9 only, so the cache write of
-- holidays-sync failed for the whole of Austria and Switzerland (check constraint, 23514): the
-- region picker found no regions and the country's holidays never arrived. Every check of a
-- region code now takes Ä, Ö and Ü as well; nothing else changes.
--
-- Additive for api_version: more values are accepted, none that was accepted is refused.

alter table app.region drop constraint region_code_check;
alter table app.region add constraint region_code_check
  check (code ~ '^[A-Z]{2}(-[A-Z0-9ÄÖÜ]{1,6}){1,4}$');

alter table app.school drop constraint school_region_code_check;
alter table app.school add constraint school_region_code_check
  check (region_code is null or region_code ~ '^[A-Z]{2}(-[A-Z0-9ÄÖÜ]{1,6}){1,4}$');
alter table app.school drop constraint school_state_code_check;
alter table app.school add constraint school_state_code_check
  check (state_code is null or state_code ~ '^[A-Z]{2}-[A-Z0-9ÄÖÜ]{1,6}$');

-- The functions below are those of 20261014120000_regions_holidays with the wider pattern.

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
         and (p_value #>> '{}') ~ '^[A-Z]{2}(-[A-Z0-9ÄÖÜ]{1,6}){1,4}$';

    else
      return false;
  end case;
end $$;

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
  c_region  constant text := '^[A-Z]{2}(-[A-Z0-9ÄÖÜ]{1,6}){1,4}$';
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
    if v_state is not null and v_state !~ '^[A-Z]{2}-[A-Z0-9ÄÖÜ]{1,6}$' then
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

create or replace function api.holiday_import_preview(p_actor uuid, p_school_id uuid, p_region text, p_from date, p_to date)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  c_region  constant text := '^[A-Z]{2}(-[A-Z0-9ÄÖÜ]{1,6}){1,4}$';
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
