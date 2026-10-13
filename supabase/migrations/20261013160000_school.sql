-- M1.3b School timetable backend (specs/15 Part 1, specs/04 "School", ADR-008, specs/21 school settings).
--
-- The Stundenplan is a pattern (weekday x period -> subject, per term), not a set of events. The
-- calendar, the agenda and the week board get their school days from the projection in Edge
-- Functions (scratchpad contract, supabase/functions/_shared/school.ts), never from SQL.
-- Every write goes through one api function that starts with app.actor, refuses kiosks, writes an
-- audit row and broadcasts 'school'. The definer functions bypass RLS, so every foreign reference
-- passed inside a json parameter is checked here against the caller's household (WW-SCH-001).
--
-- Starter subjects are German example data that the family renames (v1). The bell-time template
-- is the usual six 45-minute lessons from 08:00; a school changes it with api.school_periods_set.

-- ------------------------------------------------------------------ tables

create table app.school (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references app.household on delete cascade,
  name         text not null check (length(btrim(name)) between 1 and 120),
  state_code   text check (state_code is null or state_code ~ '^[A-Z]{2}-[A-Z0-9]{1,3}$'),
  timezone     text not null,
  created_at   timestamptz not null default now()
);
create index on app.school (household_id);

-- The bell times. A break's index is the lesson it follows.
create table app.school_period (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references app.household on delete cascade,
  school_id    uuid not null references app.school on delete cascade,
  index        int not null check (index between 1 and 15),
  label        text check (label is null or length(btrim(label)) between 1 and 40),
  starts_at    time not null,
  ends_at      time not null,
  kind         text not null check (kind in ('lesson', 'break')),
  check (ends_at > starts_at),
  unique (school_id, kind, index)
);
create index on app.school_period (household_id);

create table app.school_term (
  id             uuid primary key default gen_random_uuid(),
  household_id   uuid not null references app.household on delete cascade,
  school_id      uuid not null references app.school on delete cascade,
  name           text not null check (length(btrim(name)) between 1 and 60),
  starts_on      date not null,
  ends_on        date not null,
  -- ISO week (in starts_on's ISO year) that is an 'a' week of a Doppelwoche.
  ab_anchor_week int check (ab_anchor_week between 1 and 53),
  is_current     boolean not null default false,
  check (ends_on >= starts_on)
);
create index on app.school_term (household_id);
-- At most one current term per school, enforced by the database and not only by the function.
create unique index school_term_one_current on app.school_term (school_id) where is_current;

-- Subjects are household-wide: the same Mathematik serves every child and every school.
create table app.subject (
  id              uuid primary key default gen_random_uuid(),
  household_id    uuid not null references app.household on delete cascade,
  name            text not null check (length(btrim(name)) between 1 and 60),
  short_name      text not null check (length(btrim(short_name)) between 1 and 12),
  tint            text not null check (tint in ('blue', 'rose', 'lilac', 'leaf', 'peach', 'lemon', 'mint', 'stone')),
  icon_key        text check (icon_key is null or length(icon_key) between 1 and 40),
  equipment_note  text check (equipment_note is null or length(equipment_note) <= 80),
  notable_default boolean not null default false,
  unique (household_id, name)
);

-- One child, one term, one class: the grid is timetable_lesson rows.
create table app.timetable (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references app.household on delete cascade,
  profile_id   uuid not null references app.profile on delete cascade,
  school_id    uuid not null references app.school,
  term_id      uuid not null references app.school_term on delete cascade,
  class_label  text check (class_label is null or length(class_label) <= 20),
  week_cycle   text not null default 'weekly' check (week_cycle in ('weekly', 'ab')),
  valid_from   date not null,
  valid_to     date,
  source       text not null default 'manual' check (source in ('manual', 'imported')),
  source_ref   text check (source_ref is null or length(source_ref) <= 200),
  -- Drives the ICS SEQUENCE of the projected school days, so every grid write moves it.
  updated_at   timestamptz not null default now(),
  unique (profile_id, term_id),
  check (valid_to is null or valid_to >= valid_from)
);
create index on app.timetable (household_id);
create index on app.timetable (profile_id);

-- One cell of the grid. Lessons sit on a period; Hort, AGs and other off-grid rows carry times.
create table app.timetable_lesson (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references app.household on delete cascade,
  timetable_id uuid not null references app.timetable on delete cascade,
  weekday      int not null check (weekday between 1 and 7),
  period_index int check (period_index between 1 and 15),
  starts_at    time,
  ends_at      time,
  check (period_index is not null or (starts_at is not null and ends_at is not null)),
  check ((starts_at is null) = (ends_at is null)),
  check (starts_at is null or ends_at is null or ends_at > starts_at),
  subject_id   uuid references app.subject,
  kind         text not null default 'lesson' check (kind in ('lesson', 'care', 'club')),
  title        text check (title is null or length(btrim(title)) between 1 and 60),
  check (subject_id is not null or title is not null),
  teacher      text check (teacher is null or length(teacher) <= 60),
  room         text check (room is null or length(room) <= 40),
  week_parity  text not null default 'all' check (week_parity in ('all', 'a', 'b')),
  is_notable   boolean not null default false,
  note         text check (note is null or length(note) <= 200)
);
create index on app.timetable_lesson (household_id);
create index on app.timetable_lesson (timetable_id);
create index on app.timetable_lesson (subject_id);

-- One changed date of a timetable: a cancelled lesson, a substitute, a new room or an extra.
create table app.timetable_exception (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  timetable_id          uuid not null references app.timetable on delete cascade,
  on_date               date not null,
  period_index          int check (period_index between 1 and 15),
  kind                  text not null check (kind in ('cancelled', 'substituted', 'room_change', 'extra')),
  subject_id            uuid references app.subject,
  teacher               text check (teacher is null or length(teacher) <= 60),
  room                  text check (room is null or length(room) <= 40),
  starts_at             time,
  ends_at               time,
  note                  text check (note is null or length(note) <= 200),
  created_by_profile_id uuid references app.profile on delete set null,
  check ((starts_at is null) = (ends_at is null)),
  check (starts_at is null or ends_at is null or ends_at > starts_at)
);
create index on app.timetable_exception (household_id);
create index on app.timetable_exception (timetable_id, on_date);
create index on app.timetable_exception (subject_id);

-- Ferien and bewegliche Ferientage. A null school applies to every school of the household.
create table app.school_holiday (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references app.household on delete cascade,
  school_id    uuid references app.school on delete cascade,
  name         text not null check (length(btrim(name)) between 1 and 80),
  starts_on    date not null,
  ends_on      date not null,
  kind         text not null check (kind in ('holiday', 'closure_day')),
  source       text not null default 'manual' check (source in ('manual', 'imported')),
  source_url   text check (source_url is null or length(source_url) <= 300),
  check (ends_on >= starts_on)
);
create index on app.school_holiday (household_id, starts_on);

-- ------------------------------------------------------------------ RLS

alter table app.school          enable row level security;
alter table app.school_period   enable row level security;
alter table app.school_term     enable row level security;
alter table app.subject         enable row level security;
alter table app.timetable       enable row level security;
alter table app.timetable_lesson enable row level security;
alter table app.timetable_exception enable row level security;
alter table app.school_holiday  enable row level security;

alter table app.school          force row level security;
alter table app.school_period   force row level security;
alter table app.school_term     force row level security;
alter table app.subject         force row level security;
alter table app.timetable       force row level security;
alter table app.timetable_lesson force row level security;
alter table app.timetable_exception force row level security;
alter table app.school_holiday  force row level security;

create policy school_read on app.school for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy school_period_read on app.school_period for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy school_term_read on app.school_term for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy subject_read on app.subject for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy timetable_read on app.timetable for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy timetable_lesson_read on app.timetable_lesson for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy timetable_exception_read on app.timetable_exception for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy school_holiday_read on app.school_holiday for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());

create policy owner_all on app.school           to postgres using (true) with check (true);
create policy owner_all on app.school_period    to postgres using (true) with check (true);
create policy owner_all on app.school_term      to postgres using (true) with check (true);
create policy owner_all on app.subject          to postgres using (true) with check (true);
create policy owner_all on app.timetable        to postgres using (true) with check (true);
create policy owner_all on app.timetable_lesson to postgres using (true) with check (true);
create policy owner_all on app.timetable_exception to postgres using (true) with check (true);
create policy owner_all on app.school_holiday   to postgres using (true) with check (true);

-- No write grants: every change goes through the api functions below.
revoke all on app.school, app.school_period, app.school_term, app.subject, app.timetable,
  app.timetable_lesson, app.timetable_exception, app.school_holiday from public, anon;
grant select on app.school, app.school_period, app.school_term, app.subject, app.timetable,
  app.timetable_lesson, app.timetable_exception, app.school_holiday to authenticated;

-- ------------------------------------------------------------------ internals

-- Input readers. Each returns null for an absent or JSON-null value and raises WW-SCH-001 for a
-- value of the wrong shape, so every function checks its json the same way.
create function app.school_text(p_value jsonb, p_max int) returns text
language plpgsql immutable set search_path = '' as $$
declare v_text text;
begin
  if p_value is null or jsonb_typeof(p_value) = 'null' then
    return null;
  end if;
  if jsonb_typeof(p_value) <> 'string' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  v_text := nullif(btrim(p_value #>> '{}'), '');
  if v_text is not null and length(v_text) > p_max then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  return v_text;
end $$;

create function app.school_int(p_value jsonb, p_min int, p_max int) returns int
language plpgsql immutable set search_path = '' as $$
declare v_n numeric;
begin
  if p_value is null or jsonb_typeof(p_value) = 'null' then
    return null;
  end if;
  if jsonb_typeof(p_value) <> 'number' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  v_n := (p_value #>> '{}')::numeric;
  if v_n <> trunc(v_n) or v_n < p_min or v_n > p_max then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  return v_n::int;
end $$;

create function app.school_bool(p_value jsonb) returns boolean
language plpgsql immutable set search_path = '' as $$
begin
  if p_value is null or jsonb_typeof(p_value) = 'null' then
    return null;
  end if;
  if jsonb_typeof(p_value) <> 'boolean' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  return (p_value #>> '{}')::boolean;
end $$;

create function app.school_uuid(p_value jsonb) returns uuid
language plpgsql immutable set search_path = '' as $$
begin
  if p_value is null or jsonb_typeof(p_value) = 'null' or (p_value #>> '{}') = '' then
    return null;
  end if;
  if jsonb_typeof(p_value) <> 'string'
     or (p_value #>> '{}') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  return (p_value #>> '{}')::uuid;
end $$;

create function app.school_date(p_value jsonb) returns date
language plpgsql immutable set search_path = '' as $$
begin
  if p_value is null or jsonb_typeof(p_value) = 'null' then
    return null;
  end if;
  if jsonb_typeof(p_value) <> 'string' or (p_value #>> '{}') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  return (p_value #>> '{}')::date;
exception when datetime_field_overflow then
  -- 2026-02-30 matches the pattern but is not a date.
  raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
end $$;

create function app.school_time(p_value jsonb) returns time
language plpgsql immutable set search_path = '' as $$
begin
  if p_value is null or jsonb_typeof(p_value) = 'null' then
    return null;
  end if;
  if jsonb_typeof(p_value) <> 'string' or (p_value #>> '{}') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  return (p_value #>> '{}')::time;
end $$;

-- Household setting school.members_report_changes: the effective value (override, else default).
-- When on, members may save and delete timetable exceptions; everything else stays guardian-only.
create function app.school_members_report_changes(a app.actor_t) returns boolean
language plpgsql stable set search_path = '' as $$
begin
  return (coalesce(
    (select s.value from app.household_setting s
      where s.household_id = a.household_id and s.key = 'school.members_report_changes'
        and s.profile_id is null and s.device_id is null
      limit 1),
    (select d.default_value from app.setting_definition d where d.key = 'school.members_report_changes'))
    #>> '{}')::boolean;
end $$;

-- ------------------------------------------------------------------ api: reads

create view api.schools with (security_invoker = true) as
  select id, name, state_code, timezone, created_at from app.school;

create view api.school_periods with (security_invoker = true) as
  select id, school_id, index, label, starts_at, ends_at, kind from app.school_period;

create view api.school_terms with (security_invoker = true) as
  select id, school_id, name, starts_on, ends_on, ab_anchor_week, is_current from app.school_term;

create view api.subjects with (security_invoker = true) as
  select id, name, short_name, tint, icon_key, equipment_note, notable_default from app.subject;

create view api.timetables with (security_invoker = true) as
  select id, profile_id, school_id, term_id, class_label, week_cycle, valid_from, valid_to, source,
         source_ref, updated_at
    from app.timetable;

create view api.timetable_lessons with (security_invoker = true) as
  select id, timetable_id, weekday, period_index, starts_at, ends_at, subject_id, kind, title, teacher,
         room, week_parity, is_notable, note
    from app.timetable_lesson;

create view api.timetable_exceptions with (security_invoker = true) as
  select id, timetable_id, on_date, period_index, kind, subject_id, teacher, room, starts_at, ends_at,
         note, created_by_profile_id
    from app.timetable_exception;

create view api.school_holidays with (security_invoker = true) as
  select id, school_id, name, starts_on, ends_on, kind, source, source_url from app.school_holiday;

grant select on api.schools, api.school_periods, api.school_terms, api.subjects, api.timetables,
  api.timetable_lessons, api.timetable_exceptions, api.school_holidays to authenticated;
revoke all on api.schools, api.school_periods, api.school_terms, api.subjects, api.timetables,
  api.timetable_lessons, api.timetable_exceptions, api.school_holidays from anon;

-- ------------------------------------------------------------------ api: school

-- Insert or update a school. On insert the bell-time template and, when the household has no
-- subjects yet, the starter subjects are written too. The starter content is example data in
-- German; the family renames it, so it is not a rule of the module.
create function api.school_save(p_actor uuid, p_school jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  v_old   app.school;
  v_found boolean;
  v_id    uuid;
  v_name  text;
  v_state text;
  v_tz    text;
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
  v_state := case when p_school ? 'state_code' then app.school_text(p_school -> 'state_code', 6)
                  else v_old.state_code end;
  if v_state is not null and v_state !~ '^[A-Z]{2}-[A-Z0-9]{1,3}$' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  v_tz := coalesce(
    case when p_school ? 'timezone' then app.school_text(p_school -> 'timezone', 64) end,
    case when v_found then v_old.timezone end,
    (select h.timezone from app.household h where h.id = a.household_id));
  if not exists (select 1 from pg_timezone_names n where n.name = v_tz) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  if v_found then
    update app.school set name = v_name, state_code = v_state, timezone = v_tz where id = v_id;
  else
    insert into app.school (id, household_id, name, state_code, timezone)
    values (v_id, a.household_id, v_name, v_state, v_tz);

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
    -- app maps them to its icon set.
    if not exists (select 1 from app.subject s where s.household_id = a.household_id) then
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

  perform app.audit(a, 'school', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('name', v_name));
  perform app.broadcast(a.household_id, 'school');
  return jsonb_build_object('id', v_id);
end $$;

-- Replaces the bell times of one school. Each entry: index 1-15, kind lesson|break, starts_at,
-- ends_at (HH:MM, ends after it starts), optional label. Index and kind are unique together.
create function api.school_periods_set(p_actor uuid, p_school_id uuid, p_periods jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v_item jsonb;
  v_idx  int;
  v_kind text;
  v_st   time;
  v_en   time;
  v_lbl  text;
  v_keys text[] := '{}';
  v_key  text;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if not exists (select 1 from app.school s where s.id = p_school_id and s.household_id = a.household_id) then
    raise exception 'school not found' using errcode = 'P0002', hint = 'school_not_found';
  end if;
  if jsonb_typeof(p_periods) is distinct from 'array' or jsonb_array_length(p_periods) > 40 then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  delete from app.school_period where school_id = p_school_id;
  for v_item in select x.v from jsonb_array_elements(p_periods) as x(v) loop
    v_idx  := app.school_int(v_item -> 'index', 1, 15);
    v_st   := app.school_time(v_item -> 'starts_at');
    v_en   := app.school_time(v_item -> 'ends_at');
    v_lbl  := app.school_text(v_item -> 'label', 40);
    v_kind := coalesce(v_item ->> 'kind', '');
    if jsonb_typeof(v_item) is distinct from 'object'
       or v_idx is null or v_st is null or v_en is null
       or v_en <= v_st
       or v_kind not in ('lesson', 'break') then
      raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
    end if;
    v_key := v_kind || ':' || v_idx::text;
    if v_key = any(v_keys) then
      raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
    end if;
    v_keys := v_keys || v_key;

    insert into app.school_period (household_id, school_id, index, label, starts_at, ends_at, kind)
    values (a.household_id, p_school_id, v_idx, v_lbl, v_st, v_en, v_kind);
  end loop;

  perform app.audit(a, 'school', p_school_id, 'periods_set',
                    jsonb_build_object('count', jsonb_array_length(p_periods)));
  perform app.broadcast(a.household_id, 'school');
end $$;

-- ------------------------------------------------------------------ api: terms

-- Insert or update a term. Setting is_current clears it on the school's other terms first.
create function api.school_term_save(p_actor uuid, p_term jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_old     app.school_term;
  v_found   boolean;
  v_id      uuid;
  v_school  uuid;
  v_name    text;
  v_start   date;
  v_end     date;
  v_anchor  int;
  v_current boolean;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_term) is distinct from 'object' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  v_id := coalesce(app.school_uuid(p_term -> 'id'), gen_random_uuid());
  select * into v_old from app.school_term where id = v_id;
  v_found := found;
  if v_found and v_old.household_id <> a.household_id then
    raise exception 'term not found' using errcode = 'P0002', hint = 'term_not_found';
  end if;

  v_school := app.school_uuid(p_term -> 'school_id');
  if v_school is null
     or not exists (select 1 from app.school s where s.id = v_school and s.household_id = a.household_id) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  v_name := app.school_text(p_term -> 'name', 60);
  v_start := app.school_date(p_term -> 'starts_on');
  v_end := app.school_date(p_term -> 'ends_on');
  v_anchor := app.school_int(p_term -> 'ab_anchor_week', 1, 53);
  v_current := coalesce(app.school_bool(p_term -> 'is_current'), false);
  if v_name is null or v_start is null or v_end is null or v_end < v_start then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  if v_current then
    update app.school_term set is_current = false
     where school_id = v_school and is_current and id <> v_id;
  end if;

  if v_found then
    update app.school_term set school_id = v_school, name = v_name, starts_on = v_start, ends_on = v_end,
           ab_anchor_week = v_anchor, is_current = v_current
     where id = v_id;
  else
    insert into app.school_term (id, household_id, school_id, name, starts_on, ends_on, ab_anchor_week, is_current)
    values (v_id, a.household_id, v_school, v_name, v_start, v_end, v_anchor, v_current);
  end if;

  perform app.audit(a, 'school_term', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('name', v_name, 'is_current', v_current));
  perform app.broadcast(a.household_id, 'school');
  return jsonb_build_object('id', v_id);
end $$;

-- ------------------------------------------------------------------ api: subjects

create function api.subject_save(p_actor uuid, p_subject jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_old     app.subject;
  v_found   boolean;
  v_id      uuid;
  v_name    text;
  v_short   text;
  v_tint    text;
  v_icon    text;
  v_equip   text;
  v_notable boolean;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_subject) is distinct from 'object' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  v_id := coalesce(app.school_uuid(p_subject -> 'id'), gen_random_uuid());
  select * into v_old from app.subject where id = v_id;
  v_found := found;
  if v_found and v_old.household_id <> a.household_id then
    raise exception 'subject not found' using errcode = 'P0002', hint = 'subject_not_found';
  end if;

  v_name := app.school_text(p_subject -> 'name', 60);
  v_short := app.school_text(p_subject -> 'short_name', 12);
  v_tint := coalesce(p_subject ->> 'tint', '');
  v_icon := app.school_text(p_subject -> 'icon_key', 40);
  v_equip := app.school_text(p_subject -> 'equipment_note', 80);
  v_notable := coalesce(app.school_bool(p_subject -> 'notable_default'), false);
  if v_name is null or v_short is null
     or v_tint not in ('blue', 'rose', 'lilac', 'leaf', 'peach', 'lemon', 'mint', 'stone')
     or exists (select 1 from app.subject s
                 where s.household_id = a.household_id and s.name = v_name and s.id <> v_id) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  if v_found then
    update app.subject set name = v_name, short_name = v_short, tint = v_tint, icon_key = v_icon,
           equipment_note = v_equip, notable_default = v_notable
     where id = v_id;
  else
    insert into app.subject (id, household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
    values (v_id, a.household_id, v_name, v_short, v_tint, v_icon, v_equip, v_notable);
  end if;

  perform app.audit(a, 'subject', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('name', v_name));
  perform app.broadcast(a.household_id, 'school');
  return jsonb_build_object('id', v_id);
end $$;

-- A subject that a lesson or an exception still uses cannot go (WW-SCH-002).
create function api.subject_delete(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if not exists (select 1 from app.subject s where s.id = p_id and s.household_id = a.household_id) then
    raise exception 'subject not found' using errcode = 'P0002', hint = 'subject_not_found';
  end if;
  if exists (select 1 from app.timetable_lesson l where l.subject_id = p_id)
     or exists (select 1 from app.timetable_exception x where x.subject_id = p_id) then
    raise exception 'WW-SCH-002 subject in use' using errcode = '23503', hint = 'subject_in_use';
  end if;

  delete from app.subject where id = p_id;
  perform app.audit(a, 'subject', p_id, 'delete');
  perform app.broadcast(a.household_id, 'school');
end $$;

-- ------------------------------------------------------------------ api: timetables

-- Metadata of one child's timetable for one term. The grid is saved by timetable_lessons_set.
create function api.timetable_save(p_actor uuid, p_timetable jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_old     app.timetable;
  v_found   boolean;
  v_id      uuid;
  v_profile uuid;
  v_school  uuid;
  v_term_id uuid;
  v_term    app.school_term;
  v_class   text;
  v_cycle   text;
  v_from    date;
  v_to      date;
  v_source  text;
  v_ref     text;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_timetable) is distinct from 'object' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  v_id := coalesce(app.school_uuid(p_timetable -> 'id'), gen_random_uuid());
  select * into v_old from app.timetable where id = v_id;
  v_found := found;
  if v_found and v_old.household_id <> a.household_id then
    raise exception 'timetable not found' using errcode = 'P0002', hint = 'timetable_not_found';
  end if;

  v_profile := app.school_uuid(p_timetable -> 'profile_id');
  v_school := app.school_uuid(p_timetable -> 'school_id');
  v_term_id := app.school_uuid(p_timetable -> 'term_id');
  if v_profile is null or v_school is null or v_term_id is null then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  if not exists (select 1 from app.profile p where p.id = v_profile and p.household_id = a.household_id) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  -- The term must belong to the household and to the named school.
  select * into v_term from app.school_term t
   where t.id = v_term_id and t.household_id = a.household_id and t.school_id = v_school;
  if not found then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  if exists (select 1 from app.timetable t
              where t.profile_id = v_profile and t.term_id = v_term_id and t.id <> v_id) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  v_class := app.school_text(p_timetable -> 'class_label', 20);
  v_cycle := coalesce(nullif(p_timetable ->> 'week_cycle', ''), 'weekly');
  v_from := coalesce(app.school_date(p_timetable -> 'valid_from'), v_term.starts_on);
  v_to := app.school_date(p_timetable -> 'valid_to');
  v_source := coalesce(nullif(p_timetable ->> 'source', ''), 'manual');
  v_ref := app.school_text(p_timetable -> 'source_ref', 200);
  if v_cycle not in ('weekly', 'ab') or v_source not in ('manual', 'imported')
     or (v_to is not null and v_to < v_from) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  if v_found then
    update app.timetable set profile_id = v_profile, school_id = v_school, term_id = v_term_id,
           class_label = v_class, week_cycle = v_cycle, valid_from = v_from, valid_to = v_to,
           source = v_source, source_ref = v_ref, updated_at = now()
     where id = v_id;
  else
    insert into app.timetable (id, household_id, profile_id, school_id, term_id, class_label, week_cycle,
                               valid_from, valid_to, source, source_ref)
    values (v_id, a.household_id, v_profile, v_school, v_term_id, v_class, v_cycle, v_from, v_to,
            v_source, v_ref);
  end if;

  perform app.audit(a, 'timetable', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('profile_id', v_profile, 'term_id', v_term_id));
  perform app.broadcast(a.household_id, 'school');
  return jsonb_build_object('id', v_id);
end $$;

-- Replaces the whole grid of one timetable. A lesson sits on a period (period_index, 1-15) or
-- has its own starts_at and ends_at (Hort, an AG). is_notable defaults to the subject's
-- notable_default when the entry does not say.
create function api.timetable_lessons_set(p_actor uuid, p_timetable_id uuid, p_lessons jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_tt      app.timetable;
  v_item    jsonb;
  v_weekday int;
  v_period  int;
  v_st      time;
  v_en      time;
  v_subject uuid;
  v_sub_notable boolean;
  v_kind    text;
  v_title   text;
  v_teacher text;
  v_room    text;
  v_parity  text;
  v_notable boolean;
  v_note    text;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  select * into v_tt from app.timetable where id = p_timetable_id and household_id = a.household_id;
  if not found then
    raise exception 'timetable not found' using errcode = 'P0002', hint = 'timetable_not_found';
  end if;
  if jsonb_typeof(p_lessons) is distinct from 'array' or jsonb_array_length(p_lessons) > 300 then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  delete from app.timetable_lesson where timetable_id = v_tt.id;
  for v_item in select x.v from jsonb_array_elements(p_lessons) as x(v) loop
    if jsonb_typeof(v_item) is distinct from 'object' then
      raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
    end if;
    v_weekday := app.school_int(v_item -> 'weekday', 1, 7);
    v_period := app.school_int(v_item -> 'period_index', 1, 15);
    v_st := app.school_time(v_item -> 'starts_at');
    v_en := app.school_time(v_item -> 'ends_at');
    if v_weekday is null
       or (v_period is null and v_st is null)
       or (v_st is null) <> (v_en is null)
       or (v_st is not null and v_en <= v_st) then
      raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
    end if;

    v_subject := app.school_uuid(v_item -> 'subject_id');
    v_sub_notable := false;
    if v_subject is not null then
      select s.notable_default into v_sub_notable from app.subject s
       where s.id = v_subject and s.household_id = a.household_id;
      if not found then
        raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
      end if;
    end if;

    v_kind := coalesce(nullif(v_item ->> 'kind', ''), 'lesson');
    v_title := app.school_text(v_item -> 'title', 60);
    v_teacher := app.school_text(v_item -> 'teacher', 60);
    v_room := app.school_text(v_item -> 'room', 40);
    v_note := app.school_text(v_item -> 'note', 200);
    v_parity := coalesce(nullif(v_item ->> 'week_parity', ''), 'all');
    if v_kind not in ('lesson', 'care', 'club') or v_parity not in ('all', 'a', 'b')
       or (v_subject is null and v_title is null) then
      raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
    end if;
    v_notable := coalesce(app.school_bool(v_item -> 'is_notable'), v_sub_notable);

    insert into app.timetable_lesson (household_id, timetable_id, weekday, period_index, starts_at, ends_at,
                                      subject_id, kind, title, teacher, room, week_parity, is_notable, note)
    values (a.household_id, v_tt.id, v_weekday, v_period, v_st, v_en, v_subject, v_kind, v_title,
            v_teacher, v_room, v_parity, v_notable, v_note);
  end loop;

  -- The grid changed, so the ICS SEQUENCE of this timetable's school days moves on.
  update app.timetable set updated_at = now() where id = v_tt.id;
  perform app.audit(a, 'timetable', v_tt.id, 'lessons_set',
                    jsonb_build_object('count', jsonb_array_length(p_lessons)));
  perform app.broadcast(a.household_id, 'school');
end $$;

-- Copies the metadata and the grid of one timetable to another child (the sibling) or to the
-- next term. The copy takes the chosen term's school and its validity; exceptions are not copied,
-- because their dates belong to the term they were entered for.
create function api.timetable_copy(p_actor uuid, p_from_timetable_id uuid, p_profile_id uuid, p_term_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a    app.actor_t := app.actor(p_actor);
  v_src app.timetable;
  v_term app.school_term;
  v_id uuid := gen_random_uuid();
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  select * into v_src from app.timetable where id = p_from_timetable_id and household_id = a.household_id;
  if not found then
    raise exception 'timetable not found' using errcode = 'P0002', hint = 'timetable_not_found';
  end if;
  select * into v_term from app.school_term where id = p_term_id and household_id = a.household_id;
  if not found then
    raise exception 'term not found' using errcode = 'P0002', hint = 'term_not_found';
  end if;
  if not exists (select 1 from app.profile p where p.id = p_profile_id and p.household_id = a.household_id) then
    raise exception 'profile not found' using errcode = 'P0002', hint = 'profile_not_found';
  end if;
  if exists (select 1 from app.timetable t where t.profile_id = p_profile_id and t.term_id = p_term_id) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  insert into app.timetable (id, household_id, profile_id, school_id, term_id, class_label, week_cycle,
                             valid_from, valid_to, source, source_ref)
  values (v_id, a.household_id, p_profile_id, v_term.school_id, p_term_id, v_src.class_label, v_src.week_cycle,
          v_term.starts_on, null, 'manual', null);
  insert into app.timetable_lesson (household_id, timetable_id, weekday, period_index, starts_at, ends_at,
                                    subject_id, kind, title, teacher, room, week_parity, is_notable, note)
    select household_id, v_id, weekday, period_index, starts_at, ends_at, subject_id, kind, title, teacher,
           room, week_parity, is_notable, note
      from app.timetable_lesson where timetable_id = v_src.id;

  perform app.audit(a, 'timetable', v_id, 'copy', jsonb_build_object('from', v_src.id));
  perform app.broadcast(a.household_id, 'school');
  return jsonb_build_object('id', v_id);
end $$;

-- ------------------------------------------------------------------ api: exceptions

-- Authorisation for exceptions: a guardian always; any member only while the household setting
-- school.members_report_changes is on. Kiosks never.
create function api.timetable_exception_save(p_actor uuid, p_exception jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a           app.actor_t := app.actor(p_actor);
  v_old       app.timetable_exception;
  v_found     boolean;
  v_id        uuid;
  v_timetable uuid;
  v_date      date;
  v_kind      text;
  v_period    int;
  v_subject   uuid;
  v_st        time;
  v_en        time;
  v_teacher   text;
  v_room      text;
  v_note      text;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if not app.school_members_report_changes(a) then
    perform app.require_guardian(a);
  end if;
  if jsonb_typeof(p_exception) is distinct from 'object' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  v_id := coalesce(app.school_uuid(p_exception -> 'id'), gen_random_uuid());
  select * into v_old from app.timetable_exception where id = v_id;
  v_found := found;
  if v_found and v_old.household_id <> a.household_id then
    raise exception 'exception not found' using errcode = 'P0002', hint = 'exception_not_found';
  end if;

  v_timetable := app.school_uuid(p_exception -> 'timetable_id');
  if v_timetable is null
     or not exists (select 1 from app.timetable t where t.id = v_timetable and t.household_id = a.household_id) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  v_date := app.school_date(p_exception -> 'on_date');
  v_kind := coalesce(p_exception ->> 'kind', '');
  v_period := app.school_int(p_exception -> 'period_index', 1, 15);
  v_st := app.school_time(p_exception -> 'starts_at');
  v_en := app.school_time(p_exception -> 'ends_at');
  v_subject := app.school_uuid(p_exception -> 'subject_id');
  v_teacher := app.school_text(p_exception -> 'teacher', 60);
  v_room := app.school_text(p_exception -> 'room', 40);
  v_note := app.school_text(p_exception -> 'note', 200);
  if v_date is null or v_kind not in ('cancelled', 'substituted', 'room_change', 'extra')
     or (v_st is null) <> (v_en is null)
     or (v_st is not null and v_en <= v_st) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  if v_subject is not null
     and not exists (select 1 from app.subject s where s.id = v_subject and s.household_id = a.household_id) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  -- A change names the lesson it touches by period; an extra needs a subject and a period or a time.
  if v_kind = 'extra' then
    if v_subject is null or (v_period is null and v_st is null) then
      raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
    end if;
  elsif v_period is null then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  if v_found then
    update app.timetable_exception set timetable_id = v_timetable, on_date = v_date, period_index = v_period,
           kind = v_kind, subject_id = v_subject, teacher = v_teacher, room = v_room, starts_at = v_st,
           ends_at = v_en, note = v_note
     where id = v_id;
  else
    insert into app.timetable_exception (id, household_id, timetable_id, on_date, period_index, kind,
                                         subject_id, teacher, room, starts_at, ends_at, note,
                                         created_by_profile_id)
    values (v_id, a.household_id, v_timetable, v_date, v_period, v_kind, v_subject, v_teacher, v_room,
            v_st, v_en, v_note, a.profile_id);
  end if;

  update app.timetable set updated_at = now() where id in (v_timetable, v_old.timetable_id);
  perform app.audit(a, 'timetable_exception', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('timetable_id', v_timetable, 'on_date', v_date, 'kind', v_kind));
  perform app.broadcast(a.household_id, 'school');
  return jsonb_build_object('id', v_id);
end $$;

create function api.timetable_exception_delete(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a     app.actor_t := app.actor(p_actor);
  v_old app.timetable_exception;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if not app.school_members_report_changes(a) then
    perform app.require_guardian(a);
  end if;
  select * into v_old from app.timetable_exception where id = p_id and household_id = a.household_id;
  if not found then
    raise exception 'exception not found' using errcode = 'P0002', hint = 'exception_not_found';
  end if;

  delete from app.timetable_exception where id = p_id;
  update app.timetable set updated_at = now() where id = v_old.timetable_id;
  perform app.audit(a, 'timetable_exception', p_id, 'delete');
  perform app.broadcast(a.household_id, 'school');
end $$;

-- ------------------------------------------------------------------ api: holidays

-- A holiday with no school applies to every school of the household.
create function api.school_holiday_save(p_actor uuid, p_holiday jsonb) returns jsonb
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
     or v_kind not in ('holiday', 'closure_day') or v_source not in ('manual', 'imported') then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

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

create function api.school_holiday_delete(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if not exists (select 1 from app.school_holiday h where h.id = p_id and h.household_id = a.household_id) then
    raise exception 'holiday not found' using errcode = 'P0002', hint = 'holiday_not_found';
  end if;

  delete from app.school_holiday where id = p_id;
  perform app.audit(a, 'school_holiday', p_id, 'delete');
  perform app.broadcast(a.household_id, 'school');
end $$;

-- ------------------------------------------------------------------ grants

-- New api functions are executable by authenticated by default (see the schema migration), and
-- the anon role must not reach them. Each function is granted explicitly.
revoke all on function api.school_save(uuid, jsonb), api.school_periods_set(uuid, uuid, jsonb),
  api.school_term_save(uuid, jsonb), api.subject_save(uuid, jsonb), api.subject_delete(uuid, uuid),
  api.timetable_save(uuid, jsonb), api.timetable_lessons_set(uuid, uuid, jsonb),
  api.timetable_copy(uuid, uuid, uuid, uuid), api.timetable_exception_save(uuid, jsonb),
  api.timetable_exception_delete(uuid, uuid), api.school_holiday_save(uuid, jsonb),
  api.school_holiday_delete(uuid, uuid) from public, anon;
grant execute on function api.school_save(uuid, jsonb), api.school_periods_set(uuid, uuid, jsonb),
  api.school_term_save(uuid, jsonb), api.subject_save(uuid, jsonb), api.subject_delete(uuid, uuid),
  api.timetable_save(uuid, jsonb), api.timetable_lessons_set(uuid, uuid, jsonb),
  api.timetable_copy(uuid, uuid, uuid, uuid), api.timetable_exception_save(uuid, jsonb),
  api.timetable_exception_delete(uuid, uuid), api.school_holiday_save(uuid, jsonb),
  api.school_holiday_delete(uuid, uuid) to authenticated;

-- Internal: PUBLIC may execute new app functions unless revoked here.
revoke all on function app.school_text(jsonb, int), app.school_int(jsonb, int, int),
  app.school_bool(jsonb), app.school_uuid(jsonb), app.school_date(jsonb), app.school_time(jsonb),
  app.school_members_report_changes(app.actor_t)
  from public, anon, authenticated;
