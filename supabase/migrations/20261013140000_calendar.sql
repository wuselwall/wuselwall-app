-- M1.3a Calendar backend (specs/05, specs/04 "Calendar", ADR-009, specs/21 calendar settings).
--
-- Events are stored once; recurrence is RFC 5545 text, expanded by Edge Functions (never here).
-- Occurrences are never materialised. Every write goes through one api function that starts with
-- app.actor, refuses kiosks, writes an audit row and broadcasts 'calendar'.

-- ------------------------------------------------------------------ tables

create table app.calendar (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references app.household on delete cascade,
  name         text not null check (length(btrim(name)) between 1 and 60),
  colour_hex   text not null check (colour_hex ~ '^#[0-9A-Fa-f]{6}$'),
  kind         text not null default 'local' check (kind in ('local', 'imported')),
  created_at   timestamptz not null default now()
);

create table app.event (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  calendar_id           uuid not null references app.calendar on delete cascade,
  title                 text not null check (length(btrim(title)) between 1 and 200),
  description           text check (description is null or length(description) <= 4000),
  location              text check (location is null or length(location) <= 200),
  kind                  text not null check (kind in ('appointment', 'presence')),
  presence_state        text check (presence_state in
                          ('working', 'home_office', 'travel', 'away', 'off', 'childcare')),
  check ((kind = 'presence') = (presence_state is not null)),
  status                text not null default 'confirmed' check (status in ('confirmed', 'tentative', 'cancelled')),
  importance            text not null default 'normal' check (importance in ('normal', 'key')),
  is_all_day            boolean not null,
  starts_at             timestamptz,
  ends_at               timestamptz,
  start_date            date,
  end_date              date,
  -- Exactly one pair is set, matching is_all_day. The end date of an all-day event is inclusive.
  check (case when is_all_day then
           start_date is not null and end_date is not null and end_date >= start_date
           and starts_at is null and ends_at is null
         else
           starts_at is not null and ends_at is not null and ends_at > starts_at
           and start_date is null and end_date is null
         end),
  timezone              text not null,
  rrule                 text check (rrule is null or length(rrule) between 1 and 300),
  rdates                date[] check (rdates is null or cardinality(rdates) between 1 and 1000),
  exdates               date[] check (exdates is null or cardinality(exdates) between 1 and 1000),
  uid                   text not null unique,
  sequence              int not null default 0 check (sequence >= 0),
  created_by_profile_id uuid references app.profile on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz
);
create index on app.event (household_id, deleted_at);
create index on app.event (household_id, start_date);
create index on app.event (household_id, starts_at);

create table app.event_attendee (
  event_id     uuid not null references app.event on delete cascade,
  profile_id   uuid not null references app.profile on delete cascade,
  household_id uuid not null references app.household on delete cascade,
  primary key (event_id, profile_id)
);
create index on app.event_attendee (profile_id);

-- One modified or cancelled occurrence of a recurring event, keyed by the original start instant.
create table app.event_override (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references app.household on delete cascade,
  event_id      uuid not null references app.event on delete cascade,
  recurrence_id timestamptz not null,
  is_cancelled  boolean not null default false,
  title         text check (title is null or length(btrim(title)) between 1 and 200),
  starts_at     timestamptz,
  ends_at       timestamptz,
  start_date    date,
  end_date      date,
  location      text check (location is null or length(location) <= 200),
  status        text check (status is null or status in ('confirmed', 'tentative', 'cancelled')),
  check ((starts_at is null) = (ends_at is null)),
  check ((start_date is null) = (end_date is null)),
  unique (event_id, recurrence_id)
);
create index on app.event_override (event_id);

-- "Termine bis 17:00" (FR-1.19): one row per member and day, absent on a normal day.
create table app.busy_until (
  household_id uuid not null references app.household on delete cascade,
  profile_id   uuid not null references app.profile on delete cascade,
  on_date      date not null,
  until        time not null,
  primary key (profile_id, on_date)
);
create index on app.busy_until (household_id, on_date);

-- ------------------------------------------------------------------ RLS

alter table app.calendar       enable row level security;
alter table app.event          enable row level security;
alter table app.event_attendee enable row level security;
alter table app.event_override enable row level security;
alter table app.busy_until     enable row level security;
alter table app.calendar       force row level security;
alter table app.event          force row level security;
alter table app.event_attendee force row level security;
alter table app.event_override force row level security;
alter table app.busy_until     force row level security;

create policy calendar_read on app.calendar for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy event_read on app.event for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy event_attendee_read on app.event_attendee for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy event_override_read on app.event_override for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy busy_until_read on app.busy_until for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());

create policy owner_all on app.calendar       to postgres using (true) with check (true);
create policy owner_all on app.event          to postgres using (true) with check (true);
create policy owner_all on app.event_attendee to postgres using (true) with check (true);
create policy owner_all on app.event_override to postgres using (true) with check (true);
create policy owner_all on app.busy_until     to postgres using (true) with check (true);

-- No write grants: every change goes through the api functions below.
grant select on app.calendar, app.event, app.event_attendee, app.event_override, app.busy_until
  to authenticated;

-- ------------------------------------------------------------------ default calendar

-- Every household gets one calendar, "Familie", from the moment it exists.
create function app.household_default_calendar() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into app.calendar (household_id, name, colour_hex, kind)
  values (new.id, 'Familie', '#2D6A4F', 'local');
  return null;
end $$;

create trigger household_default_calendar after insert on app.household
  for each row execute function app.household_default_calendar();

insert into app.calendar (household_id, name, colour_hex, kind)
  select h.id, 'Familie', '#2D6A4F', 'local' from app.household h
   where not exists (select 1 from app.calendar c where c.household_id = h.id);

-- ------------------------------------------------------------------ internals

-- A guardian with a current step-up (or on a personal phone). Mirrors app.require_guardian.
create function app.calendar_is_guardian(a app.actor_t) returns boolean
language sql stable set search_path = '' as $$
  select a.profile_role = 'guardian'
     and (a.device_class = 'personal'
          or (coalesce(a.guardian_verified_until, '-infinity') > now()
              and a.verified_profile = a.profile_id))
$$;

-- Household setting calendar.members_edit_own_events: the effective value (override, else default).
create function app.calendar_members_edit(a app.actor_t) returns boolean
language plpgsql stable set search_path = '' as $$
begin
  return (coalesce(
    (select s.value from app.household_setting s
      where s.household_id = a.household_id and s.key = 'calendar.members_edit_own_events'
        and s.profile_id is null and s.device_id is null
      limit 1),
    (select d.default_value from app.setting_definition d where d.key = 'calendar.members_edit_own_events'))
    #>> '{}')::boolean;
end $$;

-- May the caller change an existing event? Guardians always; a member only when the setting
-- allows it and they attend the event as it is stored.
create function app.calendar_may_edit_event(a app.actor_t, p_event uuid) returns boolean
language plpgsql stable set search_path = '' as $$
begin
  if app.calendar_is_guardian(a) then
    return true;
  end if;
  return app.calendar_members_edit(a) and exists (
    select 1 from app.event_attendee e where e.event_id = p_event and e.profile_id = a.profile_id);
end $$;

-- A JSON array of 'YYYY-MM-DD' strings as date[]; null when absent, null or empty.
create function app.calendar_dates(p_value jsonb) returns date[]
language plpgsql immutable set search_path = '' as $$
declare v_dates date[];
begin
  if p_value is null or jsonb_typeof(p_value) = 'null' then
    return null;
  end if;
  if jsonb_typeof(p_value) <> 'array' or jsonb_array_length(p_value) > 1000 then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;
  if exists (select 1 from jsonb_array_elements_text(p_value) as x(v)
              where coalesce(x.v, '') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;
  v_dates := array(select x.v::date from jsonb_array_elements_text(p_value) as x(v));
  if cardinality(v_dates) = 0 then
    return null;
  end if;
  return v_dates;
end $$;

-- ------------------------------------------------------------------ api: reads

create view api.calendars with (security_invoker = true) as
  select id, name, colour_hex, kind from app.calendar;

-- Every event column except household_id and deleted_at; soft-deleted rows are hidden.
create view api.events with (security_invoker = true) as
  select e.id, e.calendar_id, e.title, e.description, e.location, e.kind, e.presence_state,
         e.status, e.importance, e.is_all_day, e.starts_at, e.ends_at, e.start_date, e.end_date,
         e.timezone, e.rrule, e.rdates, e.exdates, e.uid, e.sequence, e.created_by_profile_id,
         e.created_at, e.updated_at,
         coalesce((select array_agg(a.profile_id order by p.sort_order, p.id)
                     from app.event_attendee a
                     join app.profile p on p.id = a.profile_id
                    where a.event_id = e.id), '{}') as attendee_ids
    from app.event e
   where e.deleted_at is null;

create view api.event_overrides with (security_invoker = true) as
  select o.id, o.event_id, o.recurrence_id, o.is_cancelled, o.title, o.starts_at, o.ends_at,
         o.start_date, o.end_date, o.location, o.status
    from app.event_override o
    join app.event e on e.id = o.event_id and e.deleted_at is null;

create view api.busy_until with (security_invoker = true) as
  select profile_id, on_date, until from app.busy_until;

grant select on api.calendars, api.events, api.event_overrides, api.busy_until to authenticated;
revoke all on api.calendars, api.events, api.event_overrides, api.busy_until from anon;

-- ------------------------------------------------------------------ api: event_save

create function api.event_save(p_actor uuid, p_event jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a             app.actor_t := app.actor(p_actor);
  c_uuid        constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  c_date        constant text := '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';
  c_rrule_part  constant text := '^(FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)|INTERVAL=[1-9][0-9]{0,2}|COUNT=[1-9][0-9]{0,3}|UNTIL=[0-9]{8}(T[0-9]{6}Z)?|BYDAY=([+-]?[1-5]?(MO|TU|WE|TH|FR|SA|SU))(,([+-]?[1-5]?(MO|TU|WE|TH|FR|SA|SU)))*|BYMONTHDAY=-?[0-9]{1,2}(,-?[0-9]{1,2})*|BYMONTH=[0-9]{1,2}(,[0-9]{1,2})*|BYSETPOS=-?[0-9]{1,3}|WKST=(MO|TU|WE|TH|FR|SA|SU))$';
  v_old         app.event;
  v_found       boolean;
  v_id          uuid;
  v_calendar    uuid;
  v_title       text;
  v_description text;
  v_location    text;
  v_kind        text := coalesce(p_event ->> 'kind', '');
  v_presence    text := nullif(p_event ->> 'presence_state', '');
  v_status      text := coalesce(nullif(p_event ->> 'status', ''), 'confirmed');
  v_importance  text := nullif(p_event ->> 'importance', '');
  v_all_day     boolean;
  v_starts      timestamptz;
  v_ends        timestamptz;
  v_sdate       date;
  v_edate       date;
  v_tz          text;
  v_rrule       text;
  v_rdates      date[];
  v_exdates     date[];
  v_attendees   uuid[];
  v_key_default text;
  v_seq         int;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if jsonb_typeof(p_event) is distinct from 'object' then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;

  -- The client may choose the id (idempotent retries). An existing row is updated only when it
  -- belongs to the caller's household and is not deleted; otherwise it is not found.
  if nullif(p_event ->> 'id', '') is null then
    v_id := gen_random_uuid();
    v_found := false;
  else
    if (p_event ->> 'id') !~* c_uuid then
      raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
    end if;
    v_id := (p_event ->> 'id')::uuid;
    select * into v_old from app.event where id = v_id for update;
    v_found := found;
    if v_found and (v_old.household_id <> a.household_id or v_old.deleted_at is not null) then
      raise exception 'event not found' using errcode = 'P0002', hint = 'event_not_found';
    end if;
  end if;

  v_title       := btrim(coalesce(p_event ->> 'title', ''));
  v_description := nullif(btrim(coalesce(p_event ->> 'description', '')), '');
  v_location    := nullif(btrim(coalesce(p_event ->> 'location', '')), '');
  if length(v_title) not between 1 and 200
     or length(coalesce(v_description, '')) > 4000
     or length(coalesce(v_location, '')) > 200
     or v_kind not in ('appointment', 'presence')
     or v_status not in ('confirmed', 'tentative', 'cancelled')
     or (v_presence is not null and v_presence not in
           ('working', 'home_office', 'travel', 'away', 'off', 'childcare'))
     or (v_kind = 'presence') <> (v_presence is not null)
     or (v_importance is not null and v_importance not in ('normal', 'key'))
     or jsonb_typeof(p_event -> 'is_all_day') is distinct from 'boolean' then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;

  -- Timing: an all-day event has dates (inclusive end), a timed event has instants.
  v_all_day := (p_event ->> 'is_all_day')::boolean;
  if v_all_day then
    if coalesce(p_event ->> 'start_date', '') !~ c_date
       or coalesce(p_event ->> 'end_date', '') !~ c_date
       or nullif(p_event ->> 'starts_at', '') is not null
       or nullif(p_event ->> 'ends_at', '') is not null then
      raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
    end if;
    v_sdate := (p_event ->> 'start_date')::date;
    v_edate := (p_event ->> 'end_date')::date;
    if v_edate < v_sdate then
      raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
    end if;
  else
    if nullif(p_event ->> 'starts_at', '') is null
       or nullif(p_event ->> 'ends_at', '') is null
       or nullif(p_event ->> 'start_date', '') is not null
       or nullif(p_event ->> 'end_date', '') is not null then
      raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
    end if;
    v_starts := (p_event ->> 'starts_at')::timestamptz;
    v_ends   := (p_event ->> 'ends_at')::timestamptz;
    if v_ends <= v_starts then
      raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
    end if;
  end if;

  -- The event's zone: its own, else the household's. Expansion happens in that zone.
  v_tz := coalesce(nullif(p_event ->> 'timezone', ''),
                   (select h.timezone from app.household h where h.id = a.household_id));
  if not exists (select 1 from pg_timezone_names where name = v_tz) then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;

  -- Recurrence: RFC 5545 parts from the supported subset only, FREQ exactly once.
  v_rrule := nullif(btrim(coalesce(p_event ->> 'rrule', '')), '');
  if v_rrule is not null and (
       length(v_rrule) > 300
       or exists (select 1 from regexp_split_to_table(v_rrule, ';') as x(part)
                   where x.part !~ c_rrule_part)
       or (select count(*) from regexp_split_to_table(v_rrule, ';') as x(part)
            where x.part like 'FREQ=%') <> 1
       or (v_rrule ~ '(^|;)COUNT=' and v_rrule ~ '(^|;)UNTIL=')) then
    raise exception 'WW-CAL-002 rrule invalid' using errcode = '22023', hint = 'rrule_invalid';
  end if;
  v_rdates  := app.calendar_dates(p_event -> 'rdates');
  v_exdates := app.calendar_dates(p_event -> 'exdates');

  -- Attendees replace the set. Each must be an active profile of this household.
  if jsonb_typeof(p_event -> 'attendee_ids') = 'array' then
    if exists (select 1 from jsonb_array_elements_text(p_event -> 'attendee_ids') as x(v)
                where coalesce(x.v, '') !~* c_uuid) then
      raise exception 'WW-CAL-003 attendee invalid' using errcode = '22023', hint = 'attendee_invalid';
    end if;
    v_attendees := array(select distinct x.v::uuid
                           from jsonb_array_elements_text(p_event -> 'attendee_ids') as x(v));
  elsif jsonb_typeof(p_event -> 'attendee_ids') is null or jsonb_typeof(p_event -> 'attendee_ids') = 'null' then
    v_attendees := '{}';
  else
    raise exception 'WW-CAL-003 attendee invalid' using errcode = '22023', hint = 'attendee_invalid';
  end if;
  if (select count(*) from app.profile p
       where p.id = any(v_attendees) and p.household_id = a.household_id and p.active)
     <> cardinality(v_attendees) then
    raise exception 'WW-CAL-003 attendee invalid' using errcode = '22023', hint = 'attendee_invalid';
  end if;

  -- Calendar: the one named, else the household's first.
  if nullif(p_event ->> 'calendar_id', '') is null then
    select c.id into v_calendar from app.calendar c
     where c.household_id = a.household_id order by c.created_at, c.id limit 1;
  else
    if (p_event ->> 'calendar_id') !~* c_uuid then
      raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
    end if;
    select c.id into v_calendar from app.calendar c
     where c.id = (p_event ->> 'calendar_id')::uuid and c.household_id = a.household_id;
  end if;
  if v_calendar is null then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;

  -- Importance, when not given: the household's rule for key appointments (specs/21).
  if v_importance is null then
    v_key_default := coalesce(
      (select s.value from app.household_setting s
        where s.household_id = a.household_id and s.key = 'calendar.key_default'
          and s.profile_id is null and s.device_id is null
        limit 1),
      (select d.default_value from app.setting_definition d where d.key = 'calendar.key_default'))
      #>> '{}';
    v_importance := case
      when v_key_default = 'all' then 'key'
      when v_key_default = 'none' then 'normal'
      when cardinality(v_attendees) = 0 or not exists (
             select 1 from app.profile p
              where p.household_id = a.household_id and p.active and not (p.id = any(v_attendees)))
        then 'key'
      else 'normal'
    end;
  end if;

  -- Members may save only events they attend, and only when the household allows it.
  if not app.calendar_is_guardian(a) and (
       not app.calendar_members_edit(a)
       or not (a.profile_id = any(v_attendees))
       or (v_found and not app.calendar_may_edit_event(a, v_id))) then
    raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
  end if;

  if v_found then
    update app.event set
      calendar_id = v_calendar, title = v_title, description = v_description, location = v_location,
      kind = v_kind, presence_state = v_presence, status = v_status, importance = v_importance,
      is_all_day = v_all_day, starts_at = v_starts, ends_at = v_ends, start_date = v_sdate,
      end_date = v_edate, timezone = v_tz, rrule = v_rrule, rdates = v_rdates, exdates = v_exdates,
      sequence = sequence + 1, updated_at = now()
     where id = v_id
    returning sequence into v_seq;
  else
    insert into app.event (id, household_id, calendar_id, title, description, location, kind,
                           presence_state, status, importance, is_all_day, starts_at, ends_at,
                           start_date, end_date, timezone, rrule, rdates, exdates, uid,
                           created_by_profile_id)
    values (v_id, a.household_id, v_calendar, v_title, v_description, v_location, v_kind,
            v_presence, v_status, v_importance, v_all_day, v_starts, v_ends, v_sdate, v_edate,
            v_tz, v_rrule, v_rdates, v_exdates, v_id::text || '@wuselwall.app', a.profile_id)
    returning sequence into v_seq;
  end if;

  delete from app.event_attendee where event_id = v_id;
  insert into app.event_attendee (event_id, profile_id, household_id)
    select v_id, x.id, a.household_id from unnest(v_attendees) as x(id);

  perform app.audit(a, 'event', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('title', v_title, 'kind', v_kind, 'sequence', v_seq));
  perform app.broadcast(a.household_id, 'calendar');
  return jsonb_build_object('id', v_id, 'sequence', v_seq);
end $$;

-- ------------------------------------------------------------------ api: event_delete

-- Soft delete. A guardian may delete anything; a member only an event they attend alone, and
-- only when the household allows members to edit their own events.
create function api.event_delete(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a    app.actor_t := app.actor(p_actor);
  v_ev app.event;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  select * into v_ev from app.event
   where id = p_id and household_id = a.household_id and deleted_at is null
   for update;
  if not found then
    raise exception 'event not found' using errcode = 'P0002', hint = 'event_not_found';
  end if;

  if not app.calendar_is_guardian(a) and (
       not app.calendar_members_edit(a)
       or not exists (select 1 from app.event_attendee e
                       where e.event_id = p_id and e.profile_id = a.profile_id)
       or (select count(*) from app.event_attendee e where e.event_id = p_id) <> 1) then
    raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
  end if;

  update app.event set deleted_at = now(), sequence = sequence + 1, updated_at = now()
   where id = p_id;
  perform app.audit(a, 'event', p_id, 'delete');
  perform app.broadcast(a.household_id, 'calendar');
end $$;

-- ------------------------------------------------------------------ api: overrides

-- Upserts one modified or cancelled occurrence. The patch replaces the stored values; a key it
-- does not name is null (the occurrence keeps the series' value).
create function api.event_override_save(p_actor uuid, p_event_id uuid, p_recurrence_id timestamptz,
                                        p_cancelled boolean, p_patch jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  c_date    constant text := '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';
  v_ev      app.event;
  v_patch   jsonb := coalesce(p_patch, '{}');
  v_title   text;
  v_location text;
  v_status  text;
  v_starts  timestamptz;
  v_ends    timestamptz;
  v_sdate   date;
  v_edate   date;
  v_id      uuid;
  v_seq     int;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if p_recurrence_id is null or jsonb_typeof(v_patch) <> 'object' then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;
  select * into v_ev from app.event
   where id = p_event_id and household_id = a.household_id and deleted_at is null
   for update;
  if not found then
    raise exception 'event not found' using errcode = 'P0002', hint = 'event_not_found';
  end if;
  if not app.calendar_may_edit_event(a, v_ev.id) then
    raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
  end if;
  if v_ev.rrule is null and v_ev.rdates is null then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;

  v_title    := nullif(btrim(coalesce(v_patch ->> 'title', '')), '');
  v_location := nullif(btrim(coalesce(v_patch ->> 'location', '')), '');
  v_status   := nullif(v_patch ->> 'status', '');
  if length(coalesce(v_title, '')) > 200 or length(coalesce(v_location, '')) > 200
     or (v_status is not null and v_status not in ('confirmed', 'tentative', 'cancelled'))
     or (nullif(v_patch ->> 'starts_at', '') is null) <> (nullif(v_patch ->> 'ends_at', '') is null)
     or (nullif(v_patch ->> 'start_date', '') is null) <> (nullif(v_patch ->> 'end_date', '') is null)
     or (nullif(v_patch ->> 'start_date', '') is not null
         and (v_patch ->> 'start_date' !~ c_date or v_patch ->> 'end_date' !~ c_date)) then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;
  v_starts := nullif(v_patch ->> 'starts_at', '')::timestamptz;
  v_ends   := nullif(v_patch ->> 'ends_at', '')::timestamptz;
  v_sdate  := nullif(v_patch ->> 'start_date', '')::date;
  v_edate  := nullif(v_patch ->> 'end_date', '')::date;

  -- The occurrence keeps its parent's kind of timing.
  if v_ev.is_all_day then
    if v_starts is not null or (v_sdate is not null and v_edate < v_sdate) then
      raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
    end if;
  else
    if v_sdate is not null or (v_starts is not null and v_ends <= v_starts) then
      raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
    end if;
  end if;

  insert into app.event_override (household_id, event_id, recurrence_id, is_cancelled, title,
                                  starts_at, ends_at, start_date, end_date, location, status)
  values (a.household_id, v_ev.id, p_recurrence_id, coalesce(p_cancelled, false), v_title,
          v_starts, v_ends, v_sdate, v_edate, v_location, v_status)
  on conflict (event_id, recurrence_id) do update set
    is_cancelled = excluded.is_cancelled, title = excluded.title,
    starts_at = excluded.starts_at, ends_at = excluded.ends_at,
    start_date = excluded.start_date, end_date = excluded.end_date,
    location = excluded.location, status = excluded.status
  returning id into v_id;

  update app.event set sequence = sequence + 1, updated_at = now() where id = v_ev.id
  returning sequence into v_seq;
  perform app.audit(a, 'event_override', v_id, 'save', jsonb_build_object('event_id', v_ev.id));
  perform app.broadcast(a.household_id, 'calendar');
  return jsonb_build_object('id', v_id, 'sequence', v_seq);
end $$;

create function api.event_override_delete(p_actor uuid, p_event_id uuid, p_recurrence_id timestamptz)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a    app.actor_t := app.actor(p_actor);
  v_ev app.event;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  select * into v_ev from app.event
   where id = p_event_id and household_id = a.household_id and deleted_at is null
   for update;
  if not found then
    raise exception 'event not found' using errcode = 'P0002', hint = 'event_not_found';
  end if;
  if not app.calendar_may_edit_event(a, v_ev.id) then
    raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
  end if;

  -- Removing an absent override is a no-op, so a retried request is harmless.
  delete from app.event_override where event_id = v_ev.id and recurrence_id = p_recurrence_id;
  if found then
    update app.event set sequence = sequence + 1, updated_at = now() where id = v_ev.id;
    perform app.audit(a, 'event_override', v_ev.id, 'delete');
    perform app.broadcast(a.household_id, 'calendar');
  end if;
end $$;

-- ------------------------------------------------------------------ api: busy until

-- A guardian may set anyone's; a member only their own. A null time removes the day's entry.
create function api.busy_until_set(p_actor uuid, p_profile_id uuid, p_on_date date, p_until time)
returns void language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if not (app.calendar_is_guardian(a) or a.profile_id = p_profile_id) then
    raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
  end if;
  if not exists (select 1 from app.profile p where p.id = p_profile_id and p.household_id = a.household_id) then
    raise exception 'profile not found' using errcode = 'P0002', hint = 'profile_not_found';
  end if;
  if p_on_date is null then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;

  if p_until is null then
    delete from app.busy_until where profile_id = p_profile_id and on_date = p_on_date;
    perform app.audit(a, 'busy_until', p_profile_id, 'clear', jsonb_build_object('on_date', p_on_date));
  else
    insert into app.busy_until (household_id, profile_id, on_date, until)
    values (a.household_id, p_profile_id, p_on_date, p_until)
    on conflict (profile_id, on_date) do update set until = excluded.until;
    perform app.audit(a, 'busy_until', p_profile_id, 'set',
                      jsonb_build_object('on_date', p_on_date, 'until', p_until));
  end if;
  perform app.broadcast(a.household_id, 'calendar');
end $$;

-- ------------------------------------------------------------------ api: baseline

-- The usual presence of a person (profile.default_presence_*). Null state clears both. The
-- profile trigger broadcasts 'members'; this function broadcasts 'calendar' as well.
create function api.member_baseline_set(p_actor uuid, p_profile_id uuid, p_state text, p_label text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  v_label text := case when p_state is null then null else nullif(btrim(coalesce(p_label, '')), '') end;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if not (app.calendar_is_guardian(a) or a.profile_id = p_profile_id) then
    raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
  end if;
  if p_state is not null and p_state not in ('working', 'home_office', 'travel', 'away', 'off', 'childcare') then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;
  if length(coalesce(v_label, '')) > 40 then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;

  update app.profile set default_presence_state = p_state, default_presence_label = v_label
   where id = p_profile_id and household_id = a.household_id;
  if not found then
    raise exception 'profile not found' using errcode = 'P0002', hint = 'profile_not_found';
  end if;
  perform app.audit(a, 'profile', p_profile_id, 'baseline_set',
                    jsonb_build_object('state', p_state, 'label', v_label));
  perform app.broadcast(a.household_id, 'calendar');
end $$;

-- ------------------------------------------------------------------ grants

revoke all on function api.event_save(uuid, jsonb), api.event_delete(uuid, uuid),
  api.event_override_save(uuid, uuid, timestamptz, boolean, jsonb),
  api.event_override_delete(uuid, uuid, timestamptz),
  api.busy_until_set(uuid, uuid, date, time),
  api.member_baseline_set(uuid, uuid, text, text) from public, anon;
grant execute on function api.event_save(uuid, jsonb), api.event_delete(uuid, uuid),
  api.event_override_save(uuid, uuid, timestamptz, boolean, jsonb),
  api.event_override_delete(uuid, uuid, timestamptz),
  api.busy_until_set(uuid, uuid, date, time),
  api.member_baseline_set(uuid, uuid, text, text) to authenticated;

-- Internal: PUBLIC may execute new app functions unless revoked here.
revoke all on function app.household_default_calendar(), app.calendar_is_guardian(app.actor_t),
  app.calendar_members_edit(app.actor_t), app.calendar_may_edit_event(app.actor_t, uuid),
  app.calendar_dates(jsonb)
  from public, anon, authenticated;
