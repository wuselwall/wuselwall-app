-- "Somebody is going shopping" (specs/07 "Telling the others", issue #242).
--
-- When an adult opens Einkaufen, the other adults should learn it while it is still useful, so
-- they can put what they need on the list. A self-hosted server cannot push to the store app
-- (specs/14 Q47), so the server only records the trip in progress and says so on the household's
-- channel; an app that is running shows it, and a closed one shows it on Today when opened.
--
--   * app.shopping_run: one trip in progress per shopper (who, which list, since when). It ends
--     when the shopper leaves Einkaufen, and by itself two hours after it started. Rows older
--     than a day are removed at the next start: this is a signal, not a record (the finished
--     trip with its items stays app.shopping_trip).
--   * api.shopping_start / api.shopping_leave: the app calls them when the trip page opens and
--     closes. Only an adult's trip is recorded; a child's call is accepted and records nothing.
--     Opening the page again while the trip runs, or within 30 minutes after leaving it,
--     continues the same trip: the others are told once per trip, not once per tap.
--   * app.notices_for gains the kind 'shopping' and a `data` column ({list_id, list_name}): shown
--     to every other adult whose notify.shopping_start is on, for as long as the trip runs or
--     until they dismiss it. Never to the shopper, a child or the wall.
--   * notify.shopping_start: per person, on by default, self-service.
--
-- api_version: unchanged. Additive: a table, two functions, a setting, one more notice kind and
-- one more key in a notice. The previous app release calls neither function, ignores a notice
-- kind it does not know, and lists the setting with its key under Advanced.
-- api.server_info announces 'shopping-start'; an app on an older server calls nothing.

insert into app.setting_definition (key, scope, type, default_value, constraints, self_service, since_migration) values
  ('notify.shopping_start', 'member', 'boolean', 'true', '{}', true, '20261114100000');

-- ================================================================== the trip in progress

create table app.shopping_run (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references app.household on delete cascade,
  list_id      uuid not null references app.shopping_list on delete cascade,
  profile_id   uuid not null references app.profile on delete cascade,
  started_at   timestamptz not null default now(),
  ended_at     timestamptz
);
create index shopping_run_household_started_idx on app.shopping_run (household_id, started_at desc);

-- Nobody reads the table directly: the notices carry what the others may know.
alter table app.shopping_run enable row level security;
alter table app.shopping_run force row level security;
create policy owner_all on app.shopping_run to postgres using (true) with check (true);
revoke all on app.shopping_run from public, anon, authenticated;

-- How many other adults learn of a trip by p_profile: active adults of the household with
-- notify.shopping_start on.
create function app.shopping_run_audience(p_household uuid, p_profile uuid) returns int
language sql stable security definer set search_path = '' as $$
  select count(*)::int
    from app.profile p
   where p.household_id = p_household and p.active and p.kind = 'adult' and p.id <> p_profile
     and app.setting_value(p_household, 'notify.shopping_start', p.id) is distinct from 'false'::jsonb
$$;
revoke all on function app.shopping_run_audience(uuid, uuid) from public, anon, authenticated;

-- The trip page opened: {"id", "new", "told"}. "new" is true when the others are told now
-- (false when a trip was continued), "told" how many adults that is. A child's call returns
-- {"id": null, "new": false, "told": 0}.
create function api.shopping_start(p_actor uuid, p_list uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v_list uuid;
  v_id   uuid;
  v_new  boolean := false;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if (select p.kind from app.profile p where p.id = a.profile_id) is distinct from 'adult' then
    return jsonb_build_object('id', null, 'new', false, 'told', 0);
  end if;
  v_list := app.shopping_target_list(a.household_id, p_list);

  -- One trip per shopper at a time: two phones of one person, or a quick second tap.
  perform pg_advisory_xact_lock(hashtextextended('shopping_run:' || a.profile_id::text, 0));
  delete from app.shopping_run
   where household_id = a.household_id and started_at < now() - interval '1 day';

  -- The same trip: still running, or left less than 30 minutes ago.
  select r.id into v_id
    from app.shopping_run r
   where r.profile_id = a.profile_id and r.list_id = v_list
     and r.started_at > now() - interval '2 hours'
     and (r.ended_at is null or r.ended_at > now() - interval '30 minutes')
   order by r.started_at desc
   limit 1;

  -- A trip on another list ends with this one.
  update app.shopping_run set ended_at = now()
   where profile_id = a.profile_id and ended_at is null and id is distinct from v_id;

  if v_id is null then
    insert into app.shopping_run (household_id, list_id, profile_id)
    values (a.household_id, v_list, a.profile_id)
    returning id into v_id;
    v_new := true;
    perform app.audit(a, 'shopping_run', v_id, 'start', jsonb_build_object('list_id', v_list));
  else
    update app.shopping_run set ended_at = null where id = v_id and ended_at is not null;
  end if;

  perform app.broadcast(a.household_id, 'shopping');
  return jsonb_build_object('id', v_id, 'new', v_new,
                            'told', app.shopping_run_audience(a.household_id, a.profile_id));
end $$;

-- The trip page closed (Planen, back, the end of the trip): the shopper's trip ends.
create function api.shopping_leave(p_actor uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a    app.actor_t := app.actor(p_actor);
  v_id uuid;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  for v_id in
    update app.shopping_run set ended_at = now()
     where profile_id = a.profile_id and ended_at is null
    returning id
  loop
    perform app.audit(a, 'shopping_run', v_id, 'end', '{}'::jsonb);
  end loop;
  if found then
    perform app.broadcast(a.household_id, 'shopping');
  end if;
end $$;

revoke all on function api.shopping_start(uuid, uuid), api.shopping_leave(uuid) from public, anon;
grant execute on function api.shopping_start(uuid, uuid), api.shopping_leave(uuid) to authenticated;

-- ================================================================== the notice

alter table app.notice_dismissal drop constraint notice_dismissal_notice_key_check;
alter table app.notice_dismissal add constraint notice_dismissal_notice_key_check
  check (notice_key ~ '^(join|signin|mfa_reset|password_reset_issued|shopping):[0-9a-f-]{1,40}$');

-- As in 20261102140000_account_security.sql, plus the trip in progress and the `data` column
-- (null for every other kind): another adult's trip that still runs, for an adult whose
-- notify.shopping_start is on. `name` is the shopper, `profile_id` the shopper's profile,
-- `at` the start, `data` the list. The return type changes, so the function is made anew;
-- api.notices and api.notice_dismiss call it by name.
drop function app.notices_for(app.actor_t);
create function app.notices_for(a app.actor_t)
returns table (notice_key text, kind text, at timestamptz, name text, device_id uuid, profile_id uuid,
               data jsonb)
language plpgsql stable security definer set search_path = '' as $$
declare v_since timestamptz;
begin
  if a.device_class = 'kiosk' then
    return;
  end if;

  return query
  select 'join:' || l.id::text, 'join'::text, l.occurred_at, p.display_name, null::uuid, p.id, null::jsonb
    from app.audit_log l
    join app.profile p on p.id = l.actor_profile_id and p.household_id = a.household_id
   where app.guardian_ok(a)
     and l.household_id = a.household_id
     and l.entity_type = 'invitation' and l.action = 'accept'
     and l.occurred_at > now() - interval '14 days'
     and l.actor_profile_id <> a.profile_id
     and not exists (select 1 from app.notice_dismissal d
                      where d.profile_id = a.profile_id and d.notice_key = 'join:' || l.id::text);

  return query
  select k.key, k.kind, l.occurred_at, p.display_name, null::uuid, l.entity_id, null::jsonb
    from app.audit_log l
    join app.profile p on p.id = l.actor_profile_id and p.household_id = a.household_id
    cross join lateral (
      select case l.action when 'mfa_reset' then 'mfa_reset' else 'password_reset_issued' end as kind,
             case l.action when 'mfa_reset' then 'mfa_reset:' else 'password_reset_issued:' end || l.id::text as key) k
   where l.household_id = a.household_id
     and l.entity_type = 'profile' and l.action in ('mfa_reset', 'password_reset_code')
     and l.occurred_at > now() - interval '14 days'
     and l.actor_profile_id <> a.profile_id
     and (l.entity_id = a.profile_id or app.guardian_ok(a))
     and not exists (select 1 from app.notice_dismissal d
                      where d.profile_id = a.profile_id and d.notice_key = k.key);

  if (select p.kind from app.profile p where p.id = a.profile_id) = 'adult'
     and app.setting_value(a.household_id, 'notify.shopping_start', a.profile_id)
           is distinct from 'false'::jsonb then
    return query
    select 'shopping:' || r.id::text, 'shopping'::text, r.started_at, p.display_name, null::uuid,
           r.profile_id, jsonb_build_object('list_id', r.list_id, 'list_name', sl.name)
      from app.shopping_run r
      join app.profile p on p.id = r.profile_id
      join app.shopping_list sl on sl.id = r.list_id
     where r.household_id = a.household_id
       and r.ended_at is null
       and r.started_at > now() - interval '2 hours'
       and r.profile_id <> a.profile_id
       and not exists (select 1 from app.notice_dismissal d
                        where d.profile_id = a.profile_id and d.notice_key = 'shopping:' || r.id::text);
  end if;

  if a.device_class = 'personal' then
    select created_at into v_since from app.device where id = a.device_id;
    return query
    select 'signin:' || d.id::text, 'signin'::text, d.created_at, d.label, d.id, null::uuid, null::jsonb
      from app.device d
     where d.household_id = a.household_id
       and d.profile_id = a.profile_id
       and d.class = 'personal'
       and d.revoked_at is null
       and d.id <> a.device_id
       and d.created_at > v_since
       and d.created_at > now() - interval '14 days'
       and not exists (select 1 from app.notice_dismissal x
                        where x.profile_id = a.profile_id and x.notice_key = 'signin:' || d.id::text);
  end if;
end $$;

revoke all on function app.notices_for(app.actor_t) from public, anon, authenticated;

-- As in 20261015110000_notices.sql, plus `data`.
create or replace function api.notices(p_actor uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'key', n.notice_key, 'kind', n.kind, 'at', n.at,
             'name', n.name, 'device_id', n.device_id, 'profile_id', n.profile_id, 'data', n.data)
           order by n.at desc)
      from app.notices_for(a) n), '[]'::jsonb);
end $$;

-- ================================================================== announce

-- As in 20261112100000_event_import.sql, plus 'shopping-start'.
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
      'shopping-start'
    )
  );
$$;
