-- M2 Shortcuts (specs/12 "Part 1 — Siri today, via Shortcuts", FR-6.5): a token per person that
-- an Apple Shortcut (or any HTTP client) sends to the `shortcuts` Edge Function.
--
-- A token is "wws_" and 32 random bytes, base64url-encoded, shown once at creation; only its
-- SHA-256 hash is stored. It belongs to one profile (the person it acts as) and can add and
-- read, nothing else: the shopping list, the day, the meals, the school day, presence, points,
-- and ticking one of that person's own chores. It cannot delete, adjust points or manage
-- anything — the actor it yields has device class 'shortcut', which app.require_guardian
-- refuses, and only the functions below accept it.
--
-- The Edge Function has no user, so it calls these functions with the service-role key (as the
-- ICS feed does). Every function here starts from the token: unknown, revoked and inactive
-- tokens raise the same error, so tokens cannot be probed. Every write is audited with origin
-- 'shortcut' (specs/08), so the log tells "Papa did this" from "Papa's shortcut did this".
--
-- api.task_complete moves into app.tasks_do_complete, unchanged, so the app and the shortcut
-- tick a chore through the same code. Additive for api_version: new table, view and functions;
-- api.task_complete keeps its signature, grants and behaviour, and the export gains a key.

-- ------------------------------------------------------------------ table

create table app.shortcut_token (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  profile_id            uuid not null references app.profile on delete cascade,
  label                 text not null check (length(btrim(label)) between 1 and 60),
  token_hash            text not null unique,
  created_by_profile_id uuid references app.profile on delete set null,
  created_at            timestamptz not null default now(),
  last_used_at          timestamptz,
  use_count             int not null default 0,
  -- The day's writes, for the daily cap (household-local date).
  writes_on             date,
  writes_count          int not null default 0,
  revoked_at            timestamptz
);
create index on app.shortcut_token (household_id);
create index on app.shortcut_token (profile_id);

-- ------------------------------------------------------------------ RLS

alter table app.shortcut_token enable row level security;
alter table app.shortcut_token force row level security;

create policy shortcut_token_read on app.shortcut_token for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.shortcut_token to postgres using (true) with check (true);

-- The hash never leaves the database (as for the feed tokens).
revoke all on app.shortcut_token from public, anon, authenticated;
grant select (id, household_id, profile_id, label, created_by_profile_id, created_at, last_used_at,
              use_count, revoked_at)
  on app.shortcut_token to authenticated;

-- ------------------------------------------------------------------ api: reads

create view api.shortcut_tokens with (security_invoker = true) as
  select id, profile_id, label, created_by_profile_id, created_at, last_used_at, use_count, revoked_at
    from app.shortcut_token;

grant select on api.shortcut_tokens to authenticated;
revoke all on api.shortcut_tokens from anon;

-- ------------------------------------------------------------------ internals

-- The most writes one token makes in a household day: a shortcut in a loop hits a ceiling
-- before it fills the list (specs/12 "Rate limiting and safety").
create function app.shortcut_daily_writes() returns int
language sql immutable set search_path = '' as $$ select 100 $$;

-- The actor a token acts as, or the one error for every token that does not work: unknown,
-- revoked, of a deleted household or of a profile no longer active. Counts the use, and for a
-- write the day's writes. Device class and origin are 'shortcut'; there is no device.
create function app.shortcut_actor(p_token text, p_write boolean default false) returns app.actor_t
language plpgsql security definer set search_path = '' as $$
declare
  t       app.shortcut_token;
  p       app.profile;
  v_today date;
begin
  select k.* into t from app.shortcut_token k
    join app.household h on h.id = k.household_id and h.deleted_at is null
   where k.token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex')
     and k.revoked_at is null
   for update of k;
  if found then
    select * into p from app.profile where id = t.profile_id and household_id = t.household_id and active;
  end if;
  if t.id is null or p.id is null then
    raise exception 'WW-SHC-001 shortcut token invalid' using errcode = '42501', hint = 'shortcut_token_invalid';
  end if;

  v_today := app.tasks_today(t.household_id);
  if p_write then
    if t.writes_on = v_today and t.writes_count >= app.shortcut_daily_writes() then
      raise exception 'WW-SHC-002 daily limit reached' using errcode = '54000', hint = 'shortcut_rate_limited';
    end if;
    update app.shortcut_token
       set writes_count = case when writes_on = v_today then writes_count + 1 else 1 end,
           writes_on = v_today
     where id = t.id;
  end if;
  update app.shortcut_token set last_used_at = now(), use_count = use_count + 1 where id = t.id;

  return row(t.household_id, p.id, p.role, null::uuid, 'shortcut', 'shortcut',
             null::timestamptz, null::uuid)::app.actor_t;
end $$;

-- The household's list with this name (folded), else its default list.
create function app.shortcut_list(p_household uuid, p_name text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if nullif(btrim(coalesce(p_name, '')), '') is null then
    return app.shopping_target_list(p_household, null);
  end if;
  perform app.shopping_ensure_lists(p_household);
  select l.id into v_id from app.shopping_list l
   where l.household_id = p_household and app.fold(l.name) = app.fold(btrim(p_name))
   order by l.sort_order, l.id limit 1;
  if v_id is null then
    raise exception 'list not found' using errcode = 'P0002', hint = 'list_not_found';
  end if;
  return v_id;
end $$;

revoke all on function app.shortcut_daily_writes(), app.shortcut_actor(text, boolean),
  app.shortcut_list(uuid, text) from public, anon, authenticated;

-- ------------------------------------------------------------------ tasks: one completion path

-- The body of api.task_complete (20261013170000_tasks.sql), unchanged, for any actor: the app's
-- (app.actor) and a shortcut's (app.shortcut_actor).
create function app.tasks_do_complete(a app.actor_t, p_instance_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  i        app.task_instance;
  v_tz     text;
  v_today  date;
  v_pool   uuid[];
  v_count  int;
  v_credit int := 0;
begin
  select * into i from app.task_instance
   where id = p_instance_id and household_id = a.household_id for update;
  if not found then
    raise exception 'task not found' using errcode = 'P0002', hint = 'task_not_found';
  end if;
  -- Someone else's task stays someone else's, even when it is already ticked: the
  -- idempotent answer below is for a retry by the same person, not a probe by another.
  if i.assigned_profile_id is not null and i.assigned_profile_id <> a.profile_id
     and a.profile_role <> 'guardian' then
    raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
  end if;
  if i.status in ('done', 'verified') then
    return jsonb_build_object('status', i.status, 'points_credited', app.tasks_credited(i.id));
  end if;

  select h.timezone into v_tz from app.household h where h.id = a.household_id;
  v_today := (now() at time zone v_tz)::date;
  if i.status <> 'open' or i.opens_on > v_today then
    raise exception 'WW-TSK-005 task not open' using errcode = '22023', hint = 'task_not_open';
  end if;

  -- The assignee ticks their task; a guardian may tick an assigned task for anyone. An unassigned
  -- (open) task is claimed by the member who ticks it, from its pool when the definition has one.
  if i.assigned_profile_id is not null then
    if i.assigned_profile_id <> a.profile_id and a.profile_role <> 'guardian' then
      raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
    end if;
  else
    if a.profile_role <> 'member' then
      raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
    end if;
    if i.definition_id is not null then
      select d.assignee_profile_ids into v_pool from app.task_definition d where d.id = i.definition_id;
      if cardinality(v_pool) > 0 and not (a.profile_id = any(v_pool)) then
        raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
      end if;
    end if;
    i.assigned_profile_id := a.profile_id;
  end if;

  v_count := i.completion_count + 1;
  -- A task that needs verification holds its points until a guardian approves it.
  if not i.requires_verification and i.points > 0 then
    insert into app.point_transaction (household_id, profile_id, amount, reason, source_type, source_id,
                                       created_by_profile_id)
    values (a.household_id, i.assigned_profile_id, i.points, 'task', 'task',
            i.id::text || ':' || v_count::text, a.profile_id);
    v_credit := i.points;
  end if;

  update app.task_instance set status = 'done', completion_count = v_count,
         completed_by_profile_id = a.profile_id, completed_at = now(),
         assigned_profile_id = i.assigned_profile_id, updated_at = now()
   where id = i.id;
  if i.definition_id is not null then
    perform app.tasks_streak_complete(a.household_id, i.assigned_profile_id, i.definition_id, i.due_on);
  end if;

  perform app.audit(a, 'task_instance', i.id, 'complete',
                    jsonb_build_object('points', v_credit, 'profile_id', i.assigned_profile_id));
  perform app.broadcast(a.household_id, 'tasks');
  return jsonb_build_object('status', 'done', 'points_credited', v_credit);
end $$;

revoke all on function app.tasks_do_complete(app.actor_t, uuid) from public, anon, authenticated;

-- Same signature, grants and behaviour as before; the body now lives in app.tasks_do_complete.
create or replace function api.task_complete(p_actor uuid, p_instance_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  return app.tasks_do_complete(a, p_instance_id);
end $$;

-- ------------------------------------------------------------------ api: issuing and revoking

-- Creates a token for [p_profile] (the actor's own profile when null) and returns it once.
-- A guardian issues one for any active member; anyone issues their own on a personal device.
-- Never on a kiosk: the token is shown once, to the person who will paste it into a shortcut.
create function api.shortcut_token_create(p_actor uuid, p_profile uuid, p_label text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_profile uuid := coalesce(p_profile, a.profile_id);
  v_label   text := btrim(coalesce(p_label, ''));
  v_id      uuid := gen_random_uuid();
  v_token   text;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if v_profile <> a.profile_id or a.device_class <> 'personal' then
    perform app.require_guardian(a);
  end if;

  if not exists (select 1 from app.profile p
                  where p.id = v_profile and p.household_id = a.household_id and p.active) then
    raise exception 'unknown profile' using errcode = 'P0002', hint = 'profile_not_found';
  end if;
  if length(v_label) not between 1 and 60 then
    raise exception 'WW-SHC-003 shortcut label invalid' using errcode = '22023', hint = 'shortcut_label_invalid';
  end if;
  if (select count(*) from app.shortcut_token k
       where k.profile_id = v_profile and k.revoked_at is null) >= 10 then
    raise exception 'WW-SHC-004 too many shortcut tokens' using errcode = '22023', hint = 'shortcut_token_limit';
  end if;

  -- "wws_" and 32 random bytes, base64url without padding: 47 characters.
  v_token := 'wws_' || replace(replace(translate(encode(extensions.gen_random_bytes(32), 'base64'), '+/', '-_'),
                                       '=', ''), E'\n', '');

  insert into app.shortcut_token (id, household_id, profile_id, label, token_hash, created_by_profile_id)
  values (v_id, a.household_id, v_profile, v_label, encode(extensions.digest(v_token, 'sha256'), 'hex'),
          a.profile_id);
  perform app.audit(a, 'shortcut_token', v_id, 'create',
                    jsonb_build_object('label', v_label, 'profile_id', v_profile));
  return jsonb_build_object('id', v_id, 'token', v_token);
end $$;

-- Revokes one token: its holder (anywhere but a kiosk) or a guardian. A no-op when revoked.
create function api.shortcut_token_revoke(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  t app.shortcut_token;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  select * into t from app.shortcut_token k where k.id = p_id and k.household_id = a.household_id;
  if not found then
    raise exception 'shortcut token not found' using errcode = 'P0002', hint = 'shortcut_token_not_found';
  end if;
  if t.profile_id <> a.profile_id then
    perform app.require_guardian(a);
  end if;

  update app.shortcut_token set revoked_at = now() where id = p_id and revoked_at is null;
  if found then
    perform app.audit(a, 'shortcut_token', p_id, 'revoke');
  end if;
end $$;

-- ------------------------------------------------------------------ api: the shortcut's calls

-- Everything a shortcut's answer is computed from, for the token's household, as rows of the api
-- views the app reads (so the Edge Function's pure modules — occurrence expansion, the school
-- projection — work on them unchanged). The views are read as the owner and narrowed to the
-- token's household by joining their tables: nothing of another household is returned.
--
-- [p_parts] chooses what is loaded: 'calendar' (events, overrides, imported occurrences,
-- busy_until), 'school' (the projection's rows and the public holidays), 'meals' (plan entries),
-- 'tasks' (the holder's open chores and the unassigned ones). The holder, the household, its
-- active members, the holder's points and the lists always come back. The window is
-- [p_from (household today when null), + p_days - 1], at most 62 days.
create function api.shortcut_context(p_token text, p_parts text[], p_from date default null,
                                     p_days int default 1)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.shortcut_actor(p_token);
  h         app.household;
  v_today   date;
  v_from    date;
  v_to      date;
  v_region  text;
  v_out     jsonb;
  v_terms   uuid[];
  v_tts     uuid[];
  v_events  uuid[];
  v_instants_from timestamptz;
  v_instants_to   timestamptz;
begin
  select * into h from app.household where id = a.household_id;
  v_today := (now() at time zone h.timezone)::date;
  v_from := coalesce(p_from, v_today);
  if p_days is null or p_days not between 1 and 62 or v_from not between v_today - 7 and v_today + 400 then
    raise exception 'window invalid' using errcode = '22023', hint = 'window_invalid';
  end if;
  v_to := v_from + p_days - 1;
  -- Instants are widened by a day on each side, as calendar_data.ts does; expansion clips.
  v_instants_from := (v_from - 1)::timestamp at time zone 'UTC';
  v_instants_to := (v_to + 2)::timestamp at time zone 'UTC';
  v_region := nullif(app.setting_value(a.household_id, 'household.region') #>> '{}', '');

  v_out := jsonb_build_object(
    'holder', (select jsonb_build_object('profile_id', p.id, 'display_name', p.display_name,
                                         'role', p.role, 'kind', p.kind)
                 from app.profile p where p.id = a.profile_id),
    'household', jsonb_build_object('name', h.name, 'timezone', h.timezone, 'locale', h.locale,
                                    'today', v_today, 'region', v_region),
    'window', jsonb_build_object('from', v_from, 'to', v_to),
    'members', (select coalesce(jsonb_agg(jsonb_build_object(
                  'id', p.id, 'display_name', p.display_name, 'role', p.role, 'kind', p.kind,
                  'default_presence_state', p.default_presence_state,
                  'default_presence_label', p.default_presence_label)
                  order by p.sort_order, p.created_at, p.id), '[]'::jsonb)
                  from app.profile p where p.household_id = a.household_id and p.active),
    'points', app.tasks_balance(a.profile_id),
    'lists', (select coalesce(jsonb_agg(to_jsonb(v) order by v.sort_order, v.id), '[]'::jsonb)
                from api.shopping_lists v
               where v.id in (select l.id from app.shopping_list l where l.household_id = a.household_id)),
    'equipment_hint', coalesce((app.setting_value(a.household_id, 'school.equipment_hint') #>> '{}')::boolean, true));

  if 'calendar' = any(p_parts) then
    select coalesce(array_agg(e.id), '{}'::uuid[]) into v_events
      from app.event e
     where e.household_id = a.household_id and e.deleted_at is null
       and (e.rrule is not null or e.rdates is not null
            or (e.start_date <= v_to and e.end_date >= v_from)
            or (e.starts_at < v_instants_to and e.ends_at > v_instants_from));
    v_out := v_out || jsonb_build_object(
      'events', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                   from api.events v where v.id = any(v_events)),
      'overrides', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                      from api.event_overrides v where v.event_id = any(v_events)),
      'external', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                     from api.external_occurrences v
                    where v.id in (select o.id from app.external_occurrence o
                                    where o.household_id = a.household_id)
                      and ((v.starts_at < v_instants_to and v.ends_at > v_instants_from)
                           or (v.start_date <= v_to and v.end_date >= v_from))),
      'busy_until', (select coalesce(jsonb_agg(to_jsonb(v) order by v.profile_id, v.on_date), '[]'::jsonb)
                       from api.busy_until v
                      where v.profile_id in (select p.id from app.profile p where p.household_id = a.household_id)
                        and v.on_date between v_from and v_to));
  end if;

  if 'school' = any(p_parts) then
    select coalesce(array_agg(te.id), '{}'::uuid[]) into v_terms
      from app.school_term te
     where te.household_id = a.household_id and te.starts_on <= v_to and te.ends_on >= v_from;
    select coalesce(array_agg(tt.id), '{}'::uuid[]) into v_tts
      from app.timetable tt
     where tt.household_id = a.household_id and tt.term_id = any(v_terms)
       and tt.valid_from <= v_to and (tt.valid_to is null or tt.valid_to >= v_from);
    v_out := v_out || jsonb_build_object('school', jsonb_build_object(
      'schools', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                    from api.schools v
                   where v.id in (select s.id from app.school s where s.household_id = a.household_id)),
      'periods', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                    from api.school_periods v
                   where v.id in (select s.id from app.school_period s where s.household_id = a.household_id)),
      'terms', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                  from api.school_terms v where v.id = any(v_terms)),
      'subjects', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                     from api.subjects v
                    where v.id in (select s.id from app.subject s where s.household_id = a.household_id)),
      'timetables', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                       from api.timetables v where v.id = any(v_tts)),
      'lessons', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                    from api.timetable_lessons v where v.timetable_id = any(v_tts)),
      'exceptions', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                       from api.timetable_exceptions v
                      where v.timetable_id = any(v_tts) and v.on_date between v_from and v_to),
      'holidays', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                     from api.school_holidays v
                    where v.id in (select s.id from app.school_holiday s where s.household_id = a.household_id)
                      and v.starts_on <= v_to and v.ends_on >= v_from),
      -- The public holiday cache is not household data; only the countries in use are read.
      'public_feed', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                        from api.holiday_feed v
                       where v.kind = 'public' and v.starts_on <= v_to and v.ends_on >= v_from
                         and v.country in (
                           select split_part(r.code, '-', 1)
                             from (select s.region_code as code from app.school s
                                    where s.household_id = a.household_id
                                   union select v_region) r
                            where r.code is not null))));
  end if;

  if 'meals' = any(p_parts) then
    v_out := v_out || jsonb_build_object(
      'meals', (select coalesce(jsonb_agg(to_jsonb(v) order by v.on_date, v.slot), '[]'::jsonb)
                  from api.meal_plan_entries v
                 where v.id in (select m.id from app.meal_plan_entry m where m.household_id = a.household_id)
                   and v.on_date between v_from and v_to));
  end if;

  if 'tasks' = any(p_parts) then
    v_out := v_out || jsonb_build_object(
      'tasks', (select coalesce(jsonb_agg(to_jsonb(v) order by v.due_on, v.title, v.id), '[]'::jsonb)
                  from api.task_instances v
                 where v.id in (select i.id from app.task_instance i where i.household_id = a.household_id)
                   and v.status = 'open' and v.opens_on <= v_to and v.closes_on >= v_from
                   and (v.assigned_profile_id = a.profile_id or v.assigned_profile_id is null)));
  end if;

  return v_out;
end $$;

-- Adds [p_items] ([{name, quantity?, count?}], 1–20, parsed from dictation by the Edge Function)
-- to the list named [p_list] (the default list when null) as the token's holder. [p_op_id], the
-- shortcut's client id, makes a replay a no-op ('duplicate'), through the outbox's op log.
-- Returns the list, the household's locale (for the answer's language) and, per item, the name it
-- is filed under and whether it raised a count.
create function api.shortcut_shopping_add(p_token text, p_items jsonb, p_list text default null,
                                          p_op_id uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.shortcut_actor(p_token, true);
  v_list  uuid;
  v_item  jsonb;
  v_name  text;
  v_id    uuid;
  v_count int;
  v_merged boolean;
  v_out   jsonb := '[]';
begin
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 20 then
    raise exception 'invalid items' using errcode = '22023', hint = 'items_invalid';
  end if;
  v_list := app.shortcut_list(a.household_id, p_list);

  if p_op_id is not null then
    if exists (select 1 from app.shopping_op where household_id = a.household_id and op_id = p_op_id) then
      return jsonb_build_object('status', 'duplicate',
                                'list', (select l.name from app.shopping_list l where l.id = v_list),
                                'locale', (select h.locale from app.household h where h.id = a.household_id));
    end if;
    insert into app.shopping_op (household_id, op_id, kind, status)
      values (a.household_id, p_op_id, 'shortcut', 'applied');
  end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    if jsonb_typeof(v_item) is distinct from 'object' then
      raise exception 'invalid items' using errcode = '22023', hint = 'items_invalid';
    end if;
    v_name := btrim(coalesce(v_item ->> 'name', ''));
    if v_item ? 'count' and (jsonb_typeof(v_item -> 'count') <> 'number'
                             or (v_item ->> 'count') !~ '^[1-9][0-9]?$') then
      raise exception 'invalid items' using errcode = '22023', hint = 'items_invalid';
    end if;
    v_count := coalesce((v_item ->> 'count')::int, 1);
    v_merged := exists (select 1 from app.shopping_item i
                         where i.list_id = v_list and i.trip_id is null and not i.checked
                           and i.folded_name = app.fold(v_name));
    v_id := app.shopping_do_add(a, v_list, v_name, v_item ->> 'quantity');
    if v_count > 1 then
      perform app.shopping_do_count(a, v_id, v_count - 1);
    end if;
    v_out := v_out || jsonb_build_object(
      'id', v_id, 'merged', v_merged,
      'name', (select i.name from app.shopping_item i where i.id = v_id),
      'count', (select i.count from app.shopping_item i where i.id = v_id));
  end loop;

  perform app.broadcast(a.household_id, 'shopping');
  return jsonb_build_object('status', 'applied',
                            'list', (select l.name from app.shopping_list l where l.id = v_list),
                            'locale', (select h.locale from app.household h where h.id = a.household_id),
                            'items', v_out);
end $$;

-- Ticks one chore as the token's holder, through the app's own completion path: their own
-- task, or an unassigned one they may claim. Never someone else's, even for a guardian — a
-- shortcut acts for its holder only (specs/12, "never let the assistant guess who").
create function api.shortcut_task_complete(p_token text, p_instance_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.shortcut_actor(p_token, true);
  i app.task_instance;
begin
  select * into i from app.task_instance where id = p_instance_id and household_id = a.household_id;
  if not found then
    raise exception 'task not found' using errcode = 'P0002', hint = 'task_not_found';
  end if;
  if i.assigned_profile_id is not null and i.assigned_profile_id <> a.profile_id then
    raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
  end if;
  return app.tasks_do_complete(a, p_instance_id)
         || jsonb_build_object('title', i.title, 'points', i.points,
                               'requires_verification', i.requires_verification);
end $$;

-- ------------------------------------------------------------------ closed doors

-- A token stops with its holder: when the profile is deactivated, or an adult leaves the
-- family or deletes their account (auth_user_id cleared, specs/20 J6). A child's profile never
-- had an account, so clearing nothing changes nothing.
create function app.shortcut_tokens_follow_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (old.active and not new.active)
     or (old.auth_user_id is not null and new.auth_user_id is null) then
    update app.shortcut_token set revoked_at = now()
     where profile_id = new.id and revoked_at is null;
  end if;
  return new;
end $$;

create trigger shortcut_tokens_follow_profile after update of active, auth_user_id on app.profile
  for each row execute function app.shortcut_tokens_follow_profile();

-- A deleted family's tokens are revoked, like its feed tokens, and stay revoked if it is restored.
create function app.shortcut_tokens_follow_household() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.deleted_at is null and new.deleted_at is not null then
    update app.shortcut_token set revoked_at = now()
     where household_id = new.id and revoked_at is null;
  end if;
  return new;
end $$;

create trigger shortcut_tokens_follow_household after update of deleted_at on app.household
  for each row execute function app.shortcut_tokens_follow_household();

revoke all on function app.shortcut_tokens_follow_profile(), app.shortcut_tokens_follow_household()
  from public, anon, authenticated;

-- ------------------------------------------------------------------ grants

-- New api functions are executable by authenticated by default (see the schema migration). The
-- guardian functions are for the app; the shortcut's calls for the service role only.
revoke all on function api.shortcut_token_create(uuid, uuid, text), api.shortcut_token_revoke(uuid, uuid),
  api.shortcut_context(text, text[], date, int), api.shortcut_shopping_add(text, jsonb, text, uuid),
  api.shortcut_task_complete(text, uuid) from public, anon;
grant execute on function api.shortcut_token_create(uuid, uuid, text), api.shortcut_token_revoke(uuid, uuid)
  to authenticated;

revoke all on function api.shortcut_context(text, text[], date, int),
  api.shortcut_shopping_add(text, jsonb, text, uuid), api.shortcut_task_complete(text, uuid)
  from authenticated;
grant usage on schema api to service_role;
grant execute on function api.shortcut_context(text, text[], date, int),
  api.shortcut_shopping_add(text, jsonb, text, uuid), api.shortcut_task_complete(text, uuid)
  to service_role;

-- ------------------------------------------------------------------ the export

-- The household export carries the shortcut tokens (FR-5.16). Replaces api.household_export of
-- 20261016100000_export_invitations.sql verbatim except for the 'shortcut_token' key; its grants stay.
create or replace function api.household_export(p_actor uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  -- Columns that never leave the database, whichever table they sit in.
  v_secret constant text[] := array['pin_hash', 'pin_failures', 'pin_locked_until', 'auth_user_id',
                                    'auth_session_id', 'token_hash', 'code_hash'];
  v_household jsonb;
  v_tables    jsonb;
begin
  perform app.require_guardian(a);
  if a.device_class <> 'personal' then
    raise exception 'personal device required' using errcode = '42501', hint = 'personal_device_required';
  end if;

  select to_jsonb(h) into v_household from app.household h where h.id = a.household_id;

  v_tables := jsonb_build_object(
    'profile', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                  from app.profile r where r.household_id = a.household_id),
    -- Devices: label, class and dates only; the Auth user and guardian-verification state stay out.
    'device', (select coalesce(jsonb_agg(jsonb_build_object(
                  'id', r.id, 'label', r.label, 'class', r.class, 'register', r.register,
                  'profile_id', r.profile_id, 'created_at', r.created_at,
                  'last_seen_at', r.last_seen_at, 'revoked_at', r.revoked_at)
                  order by r.created_at, r.id), '[]')
                 from app.device r where r.household_id = a.household_id),
    'household_setting', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.key, r.id), '[]')
                            from app.household_setting r where r.household_id = a.household_id),
    'audit_log', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                    from app.audit_log r where r.household_id = a.household_id),
    'calendar', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                   from app.calendar r where r.household_id = a.household_id),
    'event', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                from app.event r where r.household_id = a.household_id),
    'event_attendee', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret), '[]')
                         from app.event_attendee r where r.household_id = a.household_id),
    'event_override', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                         from app.event_override r where r.household_id = a.household_id),
    'calendar_feed_token', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                              from app.calendar_feed_token r where r.household_id = a.household_id),
    'school', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                 from app.school r where r.household_id = a.household_id),
    'school_period', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                        from app.school_period r where r.household_id = a.household_id),
    'school_term', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                      from app.school_term r where r.household_id = a.household_id),
    'school_holiday', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                         from app.school_holiday r where r.household_id = a.household_id),
    -- Subscribed calendars, without the fetch bookkeeping; their occurrences are a cache of the URL.
    'external_calendar', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret - 'etag' order by r.id), '[]')
                            from app.external_calendar r where r.household_id = a.household_id),
    'subject', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                  from app.subject r where r.household_id = a.household_id),
    'timetable', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                    from app.timetable r where r.household_id = a.household_id),
    'timetable_lesson', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                           from app.timetable_lesson r where r.household_id = a.household_id),
    'timetable_exception', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                              from app.timetable_exception r where r.household_id = a.household_id),
    'shopping_list', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                        from app.shopping_list r where r.household_id = a.household_id),
    'shopping_item', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                        from app.shopping_item r where r.household_id = a.household_id),
    'shopping_trip', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.finished_at, r.id), '[]')
                        from app.shopping_trip r where r.household_id = a.household_id),
    'shopping_category', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.sort_order, r.id), '[]')
                            from app.shopping_category r where r.household_id = a.household_id),
    'catalog_item', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                       from app.catalog_item r where r.household_id = a.household_id),
    'recipe', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                 from app.recipe r where r.household_id = a.household_id),
    'recipe_ingredient', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.recipe_id, r.position), '[]')
                            from app.recipe_ingredient r where r.household_id = a.household_id),
    'meal_plan_entry', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.on_date, r.slot), '[]')
                          from app.meal_plan_entry r where r.household_id = a.household_id),
    'task_definition', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                          from app.task_definition r where r.household_id = a.household_id),
    'task_instance', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.due_on, r.id), '[]')
                        from app.task_instance r where r.household_id = a.household_id),
    'point_transaction', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.occurred_at, r.id), '[]')
                            from app.point_transaction r where r.household_id = a.household_id),
    'reward', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                 from app.reward r where r.household_id = a.household_id),
    'reward_redemption', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.requested_at, r.id), '[]')
                            from app.reward_redemption r where r.household_id = a.household_id),
    'streak', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                 from app.streak r where r.household_id = a.household_id),
    'badge_definition', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.key, r.id), '[]')
                           from app.badge_definition r where r.household_id = a.household_id),
    'badge_award', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.awarded_at, r.id), '[]')
                      from app.badge_award r where r.household_id = a.household_id),
    'tasks_day_closed', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.day), '[]')
                           from app.tasks_day_closed r where r.household_id = a.household_id),
    -- Invitations: token and code hashes are secrets (v_secret); the accepting Auth user is one too.
    'invitation', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret - 'accepted_by_user'
                                             order by r.created_at, r.id), '[]')
                     from app.invitation r where r.household_id = a.household_id),
    -- Shortcut tokens: label, holder and dates; the hash is a secret (v_secret), and the daily
    -- write counter is bookkeeping.
    'shortcut_token', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret - 'writes_on' - 'writes_count'
                                                 order by r.created_at, r.id), '[]')
                         from app.shortcut_token r where r.household_id = a.household_id)
  );

  perform app.audit(a, 'household', a.household_id, 'export');

  return jsonb_build_object(
    'format', 'wuselwall-export',
    'version', 1,
    'exported_at', now(),
    'household', coalesce(v_household, '{}'::jsonb),
    'tables', v_tables);
end $$;
