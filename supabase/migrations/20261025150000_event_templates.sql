-- Event templates: start a new event from a tile (specs/28).
--
--   * Saved templates. app.event_template holds the family's own templates (title, picture,
--     kind, time of day, length, people, place, notes, importance, countdown); never a date, a
--     repeat or a tradition. Any member saves one on a phone or tablet, never on the wall; the
--     author or a guardian changes or deletes it. At most 50 per household. The built-in
--     templates live in the app and need nothing here.
--   * Suggestions from the family's history. api.event_suggestions counts the one-off events
--     the caller may read (security invoker, so RLS decides) and offers what the family enters
--     often, as the group of events usually is. app.event_signature(title) is the grouping key.
--     A hidden suggestion (app.event_suggestion_hidden) is never offered again.
--   * Both tables are in the export; api.server_info announces 'event-templates'.
--
-- Additive for api_version: two tables, a view, new functions and a feature flag. The previous
-- app release calls none of them and works unchanged.
--
-- Errors (hint in brackets):
--   WW-CAL-020 template invalid    (template_invalid)    a bad template, or a bad signature to hide
--   WW-CAL-021 too many templates  (template_limit)      the household already keeps 50
--   template not found             (template_not_found)  P0002
--   not allowed on a kiosk         (kiosk_forbidden)
--   guardian required              (guardian_required)   changing someone else's template

-- ================================================================== the signature

-- The key that groups events "of the same kind" (specs/28 "Suggestions"): the title in lower
-- case, runs of white space made one space, leading and trailing white space and punctuation
-- removed, at most 120 characters. "Grosi kommt!" and "  grosi  kommt" are both 'grosi kommt'.
-- Null when nothing is left. Applying it to a signature gives the same signature.
create function app.event_signature(p_title text) returns text
language sql immutable parallel safe set search_path = '' as $$
  select nullif(regexp_replace(
           left(regexp_replace(
                  regexp_replace(lower(p_title), '[[:space:]]+', ' ', 'g'),
                  '^[[:space:][:punct:]]+|[[:space:][:punct:]]+$', '', 'g'), 120),
           '[[:space:][:punct:]]+$', ''), '')
$$;

-- api.event_suggestions runs as the caller and computes signatures, so the caller needs this
-- one pure function (it reads nothing).
revoke all on function app.event_signature(text) from public, anon, authenticated;
grant execute on function app.event_signature(text) to authenticated;

-- ================================================================== saved templates

create table app.event_template (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  title                 text not null check (length(btrim(title)) between 1 and 120),
  icon_key              text check (icon_key is null or icon_key ~ '^[a-z0-9_]{1,40}$'),
  kind                  text not null default 'appointment' check (kind in ('appointment', 'presence')),
  presence_state        text check (presence_state in
                          ('working', 'home_office', 'travel', 'away', 'off', 'childcare')),
  check ((kind = 'presence') = (presence_state is not null)),
  is_all_day            boolean not null default false,
  -- The start's time of day in minutes after midnight; null: the next full hour.
  start_minute          int check (start_minute between 0 and 1439),
  -- The length: minutes for a timed template, days for an all-day one.
  duration_minutes      int check (duration_minutes between 5 and 10080),
  days                  int check (days between 1 and 366),
  check (not is_all_day or (start_minute is null and duration_minutes is null)),
  check (is_all_day or days is null),
  -- Profiles of the household; applying the template drops those no longer active.
  attendee_ids          uuid[] not null default '{}',
  location              text check (location is null or length(location) <= 200),
  description           text check (description is null or length(description) <= 4000),
  -- 'key' or 'normal' when set by hand; null: the household's rule (calendar.key_default).
  importance            text check (importance in ('key', 'normal')),
  countdown             boolean not null default false,
  created_by_profile_id uuid references app.profile on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index event_template_household_id_id_idx on app.event_template (household_id, id);
alter table app.event_template enable row level security;
alter table app.event_template force row level security;
create policy event_template_read on app.event_template for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.event_template to postgres using (true) with check (true);
revoke all on app.event_template from public, anon, authenticated;
grant select on app.event_template to authenticated;

-- A suggestion the family does not want offered again, by signature.
create table app.event_suggestion_hidden (
  household_id          uuid not null references app.household on delete cascade,
  signature             text not null check (length(signature) between 1 and 120),
  created_by_profile_id uuid references app.profile on delete set null,
  created_at            timestamptz not null default now(),
  primary key (household_id, signature)
);
alter table app.event_suggestion_hidden enable row level security;
alter table app.event_suggestion_hidden force row level security;
create policy event_suggestion_hidden_read on app.event_suggestion_hidden for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.event_suggestion_hidden to postgres using (true) with check (true);
revoke all on app.event_suggestion_hidden from public, anon, authenticated;
grant select on app.event_suggestion_hidden to authenticated;

-- The household's templates, oldest first.
create view api.event_templates with (security_invoker = true) as
  select id, title, icon_key, kind, presence_state, is_all_day, start_minute, duration_minutes,
         days, attendee_ids, location, description, importance, countdown, created_by_profile_id,
         created_at, updated_at
    from app.event_template
   order by created_at, id;
grant select on api.event_templates to authenticated;

-- An integer of a template, or null; anything else (a string, a fraction, out of range) is
-- refused. Only the owner calls it, inside api.event_template_save.
create function app.event_template_int(p_value jsonb, p_min int, p_max int) returns int
language plpgsql immutable set search_path = '' as $$
begin
  if p_value is null or jsonb_typeof(p_value) = 'null' then
    return null;
  end if;
  if jsonb_typeof(p_value) <> 'number'
     or (p_value #>> '{}')::numeric <> trunc((p_value #>> '{}')::numeric)
     or (p_value #>> '{}')::numeric not between p_min and p_max then
    raise exception 'WW-CAL-020 template invalid' using errcode = '22023', hint = 'template_invalid';
  end if;
  return (p_value #>> '{}')::int;
end $$;
revoke all on function app.event_template_int(jsonb, int, int) from public, anon, authenticated;

-- Saves a template: inserts, or updates the one named by 'id' (its author or a guardian).
-- Keys: title, icon_key, kind ('appointment' when absent), presence_state, is_all_day (false
-- when absent), start_minute, duration_minutes, days, attendee_ids, location, description,
-- importance, countdown (false when absent). An update replaces every value. The values a
-- template of the other timing does not use are not kept: a timed template has no days, an
-- all-day one no start time or length. A presence template carries no picture and no
-- countdown, as api.event_save refuses them on a presence entry. Returns {id}.
create function api.event_template_save(p_actor uuid, p_template jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a             app.actor_t := app.actor(p_actor);
  c_uuid        constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  t             jsonb := p_template;
  v_old         app.event_template;
  v_id          uuid;
  v_title       text;
  v_icon        text;
  v_kind        text;
  v_presence    text;
  v_all_day     boolean;
  v_start       int;
  v_duration    int;
  v_days        int;
  v_attendees   uuid[];
  v_location    text;
  v_description text;
  v_importance  text;
  v_countdown   boolean;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if jsonb_typeof(t) is distinct from 'object'
     or jsonb_typeof(t -> 'title') is distinct from 'string'
     or coalesce(jsonb_typeof(t -> 'id'), 'null') not in ('string', 'null')
     or coalesce(jsonb_typeof(t -> 'icon_key'), 'null') not in ('string', 'null')
     or coalesce(jsonb_typeof(t -> 'kind'), 'null') not in ('string', 'null')
     or coalesce(jsonb_typeof(t -> 'presence_state'), 'null') not in ('string', 'null')
     or coalesce(jsonb_typeof(t -> 'is_all_day'), 'null') not in ('boolean', 'null')
     or coalesce(jsonb_typeof(t -> 'attendee_ids'), 'null') not in ('array', 'null')
     or coalesce(jsonb_typeof(t -> 'location'), 'null') not in ('string', 'null')
     or coalesce(jsonb_typeof(t -> 'description'), 'null') not in ('string', 'null')
     or coalesce(jsonb_typeof(t -> 'importance'), 'null') not in ('string', 'null')
     or coalesce(jsonb_typeof(t -> 'countdown'), 'null') not in ('boolean', 'null') then
    raise exception 'WW-CAL-020 template invalid' using errcode = '22023', hint = 'template_invalid';
  end if;

  v_title       := btrim(t ->> 'title');
  v_icon        := nullif(t ->> 'icon_key', '');
  v_kind        := coalesce(nullif(t ->> 'kind', ''), 'appointment');
  v_presence    := nullif(t ->> 'presence_state', '');
  v_all_day     := coalesce((t ->> 'is_all_day')::boolean, false);
  v_start       := app.event_template_int(t -> 'start_minute', 0, 1439);
  v_duration    := app.event_template_int(t -> 'duration_minutes', 5, 10080);
  v_days        := app.event_template_int(t -> 'days', 1, 366);
  v_location    := nullif(btrim(coalesce(t ->> 'location', '')), '');
  v_description := nullif(btrim(coalesce(t ->> 'description', '')), '');
  v_importance  := nullif(t ->> 'importance', '');
  v_countdown   := coalesce((t ->> 'countdown')::boolean, false);
  if v_all_day then
    v_start := null;
    v_duration := null;
  else
    v_days := null;
  end if;

  if length(v_title) not between 1 and 120
     or (v_icon is not null and v_icon !~ '^[a-z0-9_]{1,40}$')
     or v_kind not in ('appointment', 'presence')
     or (v_presence is not null and v_presence not in
           ('working', 'home_office', 'travel', 'away', 'off', 'childcare'))
     or (v_kind = 'presence') <> (v_presence is not null)
     or (v_kind = 'presence' and (v_icon is not null or v_countdown))
     or length(coalesce(v_location, '')) > 200
     or length(coalesce(v_description, '')) > 4000
     or (v_importance is not null and v_importance not in ('key', 'normal')) then
    raise exception 'WW-CAL-020 template invalid' using errcode = '22023', hint = 'template_invalid';
  end if;

  -- People: profiles of this household (a member no longer active may stay on a template; the
  -- app drops them when it applies it).
  if jsonb_typeof(t -> 'attendee_ids') = 'array' then
    if exists (select 1 from jsonb_array_elements(t -> 'attendee_ids') as x(v)
                where jsonb_typeof(x.v) <> 'string' or (x.v #>> '{}') !~* c_uuid) then
      raise exception 'WW-CAL-020 template invalid' using errcode = '22023', hint = 'template_invalid';
    end if;
    v_attendees := array(select distinct x.v::uuid
                           from jsonb_array_elements_text(t -> 'attendee_ids') as x(v)
                          order by 1);
  else
    v_attendees := '{}';
  end if;
  if (select count(*) from app.profile p
       where p.id = any(v_attendees) and p.household_id = a.household_id)
     <> cardinality(v_attendees) then
    raise exception 'WW-CAL-020 template invalid' using errcode = '22023', hint = 'template_invalid';
  end if;

  if nullif(t ->> 'id', '') is not null then
    if (t ->> 'id') !~* c_uuid then
      raise exception 'WW-CAL-020 template invalid' using errcode = '22023', hint = 'template_invalid';
    end if;
    select * into v_old from app.event_template
     where id = (t ->> 'id')::uuid and household_id = a.household_id
       for update;
    if not found then
      raise exception 'template not found' using errcode = 'P0002', hint = 'template_not_found';
    end if;
    if v_old.created_by_profile_id is distinct from a.profile_id then
      perform app.require_guardian(a);
    end if;
    v_id := v_old.id;
    update app.event_template set
      title = v_title, icon_key = v_icon, kind = v_kind, presence_state = v_presence,
      is_all_day = v_all_day, start_minute = v_start, duration_minutes = v_duration, days = v_days,
      attendee_ids = v_attendees, location = v_location, description = v_description,
      importance = v_importance, countdown = v_countdown, updated_at = now()
     where id = v_id;
  else
    -- One household's saves count one after the other, so two at once cannot pass 50.
    perform pg_advisory_xact_lock(hashtextextended('event_template:' || a.household_id::text, 0));
    if (select count(*) from app.event_template x where x.household_id = a.household_id) >= 50 then
      raise exception 'WW-CAL-021 too many templates' using errcode = '22023', hint = 'template_limit';
    end if;
    insert into app.event_template (household_id, title, icon_key, kind, presence_state, is_all_day,
                                    start_minute, duration_minutes, days, attendee_ids, location,
                                    description, importance, countdown, created_by_profile_id)
    values (a.household_id, v_title, v_icon, v_kind, v_presence, v_all_day, v_start, v_duration,
            v_days, v_attendees, v_location, v_description, v_importance, v_countdown, a.profile_id)
    returning id into v_id;
  end if;

  perform app.audit(a, 'event_template', v_id, case when v_old.id is null then 'create' else 'update' end,
                    jsonb_build_object('title', v_title, 'kind', v_kind));
  perform app.broadcast(a.household_id, 'calendar');
  return jsonb_build_object('id', v_id);
end $$;

-- The author or a guardian deletes a template.
create function api.event_template_delete(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  v app.event_template;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  select * into v from app.event_template
   where id = p_id and household_id = a.household_id
     for update;
  if not found then
    raise exception 'template not found' using errcode = 'P0002', hint = 'template_not_found';
  end if;
  if v.created_by_profile_id is distinct from a.profile_id then
    perform app.require_guardian(a);
  end if;
  delete from app.event_template where id = p_id;
  perform app.audit(a, 'event_template', p_id, 'delete', jsonb_build_object('title', v.title));
  perform app.broadcast(a.household_id, 'calendar');
end $$;

-- ================================================================== suggestions

-- Any member hides a suggestion for the household ("Nicht mehr vorschlagen"), or shows it
-- again (p_hidden false). p_signature is a suggestion's signature as api.event_suggestions
-- returned it.
create function api.event_suggestion_hide(p_actor uuid, p_signature text, p_hidden boolean default true)
returns void language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if p_signature is null or length(p_signature) not between 1 and 120
     or app.event_signature(p_signature) is distinct from p_signature
     or p_hidden is null then
    raise exception 'WW-CAL-020 template invalid' using errcode = '22023', hint = 'template_invalid';
  end if;
  if p_hidden then
    insert into app.event_suggestion_hidden (household_id, signature, created_by_profile_id)
    values (a.household_id, p_signature, a.profile_id)
    on conflict (household_id, signature) do nothing;
  else
    delete from app.event_suggestion_hidden where household_id = a.household_id and signature = p_signature;
  end if;
  perform app.audit(a, 'event_suggestion', null, case when p_hidden then 'hide' else 'show' end,
                    jsonb_build_object('signature', p_signature));
  perform app.broadcast(a.household_id, 'calendar');
end $$;

-- What the family enters often (specs/28 "Suggestions from the family's history"), as a jsonb
-- array of at most p_limit (1–12) elements:
--   {signature, title, icon_key, kind, presence_state, is_all_day, start_minute,
--    duration_minutes, days, attendee_ids, location, count, last_on}
-- 1. The household's one-off events: not deleted, no rrule or rdates, not a tradition, starting
--    (all day: start_date; timed: the start's day in the event's zone) within the last 365 days
--    or the next 60 of the household's today.
-- 2. Grouped by app.event_signature(title) and kind; 3. a group of at least three.
-- 4. The title of the group's most recent event; the most frequent picture, all-day value, ISO
--    weekday, start time (in the event's zone) and length (of the events with that all-day
--    value), people (as a set) and presence state; the most frequent place when at least half
--    of the events have it. "No picture" is a value like any other. Ties go to the value of the
--    most recent event.
-- 5. Not offered: a hidden signature, and a signature of a saved template of the same kind.
-- 6. Each event weighs 1 from 90 days ago on, ½ before; with p_on, a group whose most frequent
--    weekday is p_on's weighs 1.5 times. Highest first, then the most recent, then signature.
-- Runs as the caller: RLS shows only the events the caller may read, and a caller without a
-- household or on a revoked device gets [].
create function api.event_suggestions(p_on date default null, p_limit int default 4) returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
declare
  v_household uuid := app.jwt_household();
  v_tz        text;
  v_today     date;
  v_limit     int := least(greatest(coalesce(p_limit, 4), 1), 12);
  v_result    jsonb;
begin
  if v_household is null or not app.device_ok() then
    return '[]'::jsonb;
  end if;
  select coalesce(h.timezone, 'UTC') into v_tz from app.household h where h.id = v_household;
  v_today := (now() at time zone coalesce(v_tz, 'UTC'))::date;

  with ev as (
    select e.id, e.title, e.kind, e.presence_state, e.icon_key, e.is_all_day, e.location,
           e.created_at, x.signature, x.start_day, x.start_minute, x.duration_minutes, x.days,
           coalesce((select array_agg(at.profile_id order by at.profile_id)
                       from app.event_attendee at where at.event_id = e.id), '{}') as attendees
      from app.event e
      cross join lateral (
        select app.event_signature(e.title) as signature,
               case when e.is_all_day then e.start_date
                    else (e.starts_at at time zone coalesce(e.timezone, v_tz))::date end as start_day,
               case when not e.is_all_day then
                 (extract(hour from e.starts_at at time zone coalesce(e.timezone, v_tz)) * 60
                  + extract(minute from e.starts_at at time zone coalesce(e.timezone, v_tz)))::int
               end as start_minute,
               case when not e.is_all_day then
                 round(extract(epoch from e.ends_at - e.starts_at) / 60)::int end as duration_minutes,
               case when e.is_all_day then e.end_date - e.start_date + 1 end as days) x
     where e.household_id = v_household
       and e.deleted_at is null and e.rrule is null and e.rdates is null and not e.tradition
       -- A coarse range the indexes can use; the exact one is below.
       and (e.start_date between v_today - 366 and v_today + 61
            or e.starts_at between ((v_today - 367)::timestamp at time zone 'UTC')
                               and ((v_today + 62)::timestamp at time zone 'UTC'))
  ),
  counted as (
    -- How many events of the group share each value, to pick the most frequent one.
    select ev.*,
           extract(isodow from ev.start_day)::int as dow,
           case when ev.start_day >= v_today - 90 then 1.0 else 0.5 end as weight,
           count(*) over (partition by signature, kind, icon_key)             as n_icon,
           count(*) over (partition by signature, kind, is_all_day)           as n_all_day,
           count(*) over (partition by signature, kind, extract(isodow from ev.start_day)) as n_dow,
           count(*) over (partition by signature, kind, is_all_day, start_minute)     as n_start,
           count(*) over (partition by signature, kind, is_all_day, duration_minutes) as n_duration,
           count(*) over (partition by signature, kind, is_all_day, days)     as n_days,
           count(*) over (partition by signature, kind, attendees)            as n_people,
           count(*) over (partition by signature, kind, presence_state)       as n_presence,
           count(*) over (partition by signature, kind, location)             as n_location
      from ev
     where ev.signature is not null
       and ev.start_day between v_today - 365 and v_today + 60
  ),
  grouped as (
    select c.signature, c.kind,
           count(*)::int as n,
           sum(c.weight) as weight,
           max(c.start_day) as last_on,
           (array_agg(c.title order by c.start_day desc, c.created_at desc, c.id))[1] as title,
           (array_agg(c.icon_key order by c.n_icon desc, c.start_day desc, c.created_at desc))[1] as icon_key,
           (array_agg(c.is_all_day order by c.n_all_day desc, c.start_day desc, c.created_at desc))[1] as is_all_day,
           (array_agg(c.dow order by c.n_dow desc, c.start_day desc, c.created_at desc))[1] as dow,
           (array_agg(c.start_minute order by c.n_start desc, c.start_day desc, c.created_at desc)
              filter (where not c.is_all_day))[1] as start_minute_timed,
           (array_agg(c.duration_minutes order by c.n_duration desc, c.start_day desc, c.created_at desc)
              filter (where not c.is_all_day))[1] as duration_timed,
           (array_agg(c.days order by c.n_days desc, c.start_day desc, c.created_at desc)
              filter (where c.is_all_day))[1] as days_all_day,
           -- As text: array_agg cannot gather arrays of different lengths, or empty ones.
           (array_agg(c.attendees::text order by c.n_people desc, c.start_day desc, c.created_at desc))[1]::uuid[]
             as attendees,
           (array_agg(c.presence_state order by c.n_presence desc, c.start_day desc, c.created_at desc))[1]
             as presence_state,
           (array_agg(c.location order by c.n_location desc, c.start_day desc, c.created_at desc)
              filter (where c.location is not null))[1] as location,
           max(c.n_location) filter (where c.location is not null) as n_location
      from counted c
     group by c.signature, c.kind
    having count(*) >= 3
  ),
  offered as (
    select g.*,
           g.weight * case when p_on is not null and g.dow = extract(isodow from p_on)::int
                           then 1.5 else 1 end as score
      from grouped g
     where not exists (select 1 from app.event_suggestion_hidden s
                        where s.household_id = v_household and s.signature = g.signature)
       and not exists (select 1 from app.event_template t
                        where t.household_id = v_household and t.kind = g.kind
                          and app.event_signature(t.title) = g.signature)
     order by score desc, g.last_on desc, g.signature, g.kind
     limit v_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'signature', o.signature,
           'title', o.title,
           'icon_key', case when o.kind = 'presence' then null else o.icon_key end,
           'kind', o.kind,
           'presence_state', o.presence_state,
           'is_all_day', o.is_all_day,
           'start_minute', case when o.is_all_day then null else o.start_minute_timed end,
           'duration_minutes', case when o.is_all_day then null else o.duration_timed end,
           'days', case when o.is_all_day then o.days_all_day end,
           'attendee_ids', to_jsonb(o.attendees),
           'location', case when o.n_location * 2 >= o.n then o.location end,
           'count', o.n,
           'last_on', o.last_on)
         order by o.score desc, o.last_on desc, o.signature, o.kind), '[]'::jsonb)
    into v_result
    from offered o;
  return v_result;
end $$;

revoke all on function api.event_template_save(uuid, jsonb), api.event_template_delete(uuid, uuid),
  api.event_suggestion_hide(uuid, text, boolean), api.event_suggestions(date, int) from public, anon;
grant execute on function api.event_template_save(uuid, jsonb), api.event_template_delete(uuid, uuid),
  api.event_suggestion_hide(uuid, text, boolean), api.event_suggestions(date, int) to authenticated;

-- ================================================================== export

-- Beside the other calendar tables.
insert into app.export_table (name, position, omit, keep) values
  ('event_template',          81, '{}', null),
  ('event_suggestion_hidden', 82, '{}', null);

-- ================================================================== announce

-- The server keeps templates and makes suggestions, so the app shows "Häufig bei euch" and
-- "Eure Vorlagen" (api.server_info's `features`, ADR-018). The rest as in 20261024110000.
create or replace function api.server_info()
returns jsonb
language sql
immutable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'api_version', 1,
    'min_app_version', '1.0.0',
    'household_creation', 'token',
    'features', jsonb_build_array(
      'calendar', 'ics', 'calendar-import', 'school', 'tasks', 'meals', 'shopping', 'holidays',
      'lighter-day', 'event-templates'
    )
  );
$$;
