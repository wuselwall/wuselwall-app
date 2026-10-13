-- M1.2 Household settings and curated defaults (specs/21, ADR-013).
--
-- A setting is a row of the catalogue (app.setting_definition, written by migrations only)
-- and, only once a household changes it, a row of app.household_setting. An unchanged setting
-- has no row: the effective value is the default, so a better default shipped later reaches
-- every household that never touched it.

-- ------------------------------------------------------------------ tables

create table app.setting_definition (
  key             text primary key,
  scope           text not null check (scope in ('household', 'member', 'device')),
  type            text not null check (type in ('boolean', 'integer', 'time', 'enum',
                                                'weekday_time', 'time_range', 'times')),
  default_value   jsonb not null,
  constraints     jsonb not null default '{}',
  self_service    boolean not null default false,  -- a member may change their own value
  since_migration text not null,
  check (not self_service or scope = 'member')
);

create table app.household_setting (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  key                   text not null references app.setting_definition on delete cascade,
  profile_id            uuid references app.profile on delete cascade,
  device_id             uuid references app.device on delete cascade,
  value                 jsonb not null,
  updated_at            timestamptz not null default now(),
  updated_by_profile_id uuid references app.profile on delete set null,
  constraint household_setting_scope_key unique nulls not distinct (household_id, key, profile_id, device_id),
  check (profile_id is null or device_id is null)
);

alter table app.setting_definition enable row level security;
alter table app.household_setting enable row level security;
alter table app.setting_definition force row level security;
alter table app.household_setting force row level security;

-- The catalogue is not household data, but a revoked device still reads nothing.
create policy setting_definition_read on app.setting_definition for select to authenticated
  using (app.device_ok());
create policy household_setting_read on app.household_setting for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.setting_definition to postgres using (true) with check (true);
create policy owner_all on app.household_setting to postgres using (true) with check (true);

-- No write grants: every change goes through api.set_setting / api.reset_setting.
grant select on app.setting_definition, app.household_setting to authenticated;

-- ------------------------------------------------------------------ catalogue (specs/21)
-- Encodings the app depends on: integer and enum/time as above; weekday_time is
-- {weekday: 1-7 ISO, 6 = Saturday, time}; time_range {from, to}; times is a two-element
-- ascending array. "nullable" lets JSON null mean "off".

insert into app.setting_definition (key, scope, type, default_value, constraints, self_service, since_migration) values
  ('board.member_label',               'household', 'enum',         '"name"',                          '{"values":["name","initial"]}',                 false, '20261013120000'),
  ('member.completion_sound',          'member',    'boolean',      'true',                            '{}',                                            true,  '20261013120000'),
  ('tasks.points.duty_default',        'household', 'integer',      '1',                               '{"min":0,"max":3}',                             false, '20261013120000'),
  ('tasks.points.bonus_default',       'household', 'integer',      '5',                               '{"min":1,"max":50}',                            false, '20261013120000'),
  ('tasks.kind_default',               'household', 'enum',         '"duty"',                          '{"values":["duty","bonus"]}',                   false, '20261013120000'),
  ('tasks.verification_default',       'household', 'boolean',      'false',                           '{}',                                            false, '20261013120000'),
  ('tasks.jokers_per_month',           'household', 'integer',      '1',                               '{"min":0,"max":5,"per_member":true}',           false, '20261013120000'),
  ('tasks.reward_approval_default',    'household', 'enum',         '"required"',                      '{"values":["required","self_serve"]}',          false, '20261013120000'),
  ('calendar.members_edit_own_events', 'household', 'boolean',      'true',                            '{}',                                            false, '20261013120000'),
  ('calendar.key_default',             'household', 'enum',         '"whole_family"',                  '{"values":["whole_family","all","none"]}',      false, '20261013120000'),
  ('calendar.tentative_nudge',         'member',    'time',         '"19:00"',                         '{}',                                            true,  '20261013120000'),
  ('school.members_report_changes',    'household', 'boolean',      'false',                           '{}',                                            false, '20261013120000'),
  ('school.equipment_hint',            'household', 'boolean',      'true',                            '{}',                                            false, '20261013120000'),
  ('meals.warm_meal.school_day',       'household', 'enum',         '"dinner"',                        '{"values":["lunch","dinner"]}',                 false, '20261013120000'),
  ('meals.warm_meal.free_day',         'household', 'enum',         '"lunch"',                         '{"values":["lunch","dinner"]}',                 false, '20261013120000'),
  ('meals.away_means_not_eating',      'household', 'boolean',      'true',                            '{}',                                            false, '20261013120000'),
  ('meals.care_lunch_cutoff',          'household', 'time',         '"14:00"',                         '{}',                                            false, '20261013120000'),
  ('board.rollover',                   'household', 'weekday_time', '{"weekday":6,"time":"12:00"}',    '{}',                                            false, '20261013120000'),
  ('board.day_parts',                  'household', 'times',        '["12:00","17:00"]',               '{}',                                            false, '20261013120000'),
  ('device.night_hours',               'device',    'time_range',   '{"from":"21:00","to":"06:00"}',   '{}',                                            false, '20261013120000'),
  ('device.idle_revert_seconds',       'device',    'integer',      '60',                              '{"min":30,"max":300}',                          false, '20261013120000'),
  ('notify.morning_summary',           'member',    'time',         '"07:00"',                         '{"nullable":true}',                             true,  '20261013120000'),
  ('notify.event_reminder',            'member',    'integer',      'null',                            '{"min":5,"max":120,"nullable":true}',           true,  '20261013120000'),
  ('notify.task_verified',             'member',    'boolean',      'false',                           '{}',                                            true,  '20261013120000'),
  ('notify.redemption_request',        'member',    'boolean',      'false',                           '{}',                                            true,  '20261013120000');

-- ------------------------------------------------------------------ internals

-- Is p_value a legal value for the definition? JSON null is legal only where nullable.
create function app.setting_valid(p_def app.setting_definition, p_value jsonb)
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

    else
      return false;
  end case;
end $$;

-- Who may write p_profile / p_device for this definition, and is the target one of ours?
-- Household scope: guardian action (PIN step-up on shared devices). Member scope: the member
-- themselves may change a self-service setting without the PIN. Device scope: guardian.
create function app.setting_authorise(a app.actor_t, d app.setting_definition,
                                      p_profile uuid, p_device uuid)
returns void language plpgsql stable set search_path = '' as $$
declare
  v_profile_ok boolean := p_profile is not null and exists (
    select 1 from app.profile where id = p_profile and household_id = a.household_id);
  v_device_ok  boolean := p_device is not null and exists (
    select 1 from app.device where id = p_device and household_id = a.household_id);
  v_target_ok  boolean;
begin
  if d.scope = 'household' then
    v_target_ok := p_device is null
      and (p_profile is null or (coalesce((d.constraints ->> 'per_member')::boolean, false) and v_profile_ok));
  elsif d.scope = 'member' then
    v_target_ok := v_profile_ok and p_device is null;
  else
    v_target_ok := v_device_ok and p_profile is null;
  end if;
  if not coalesce(v_target_ok, false) then
    raise exception 'WW-SET-003 setting target invalid' using errcode = '22023', hint = 'setting_target';
  end if;

  if d.scope = 'member' and d.self_service and p_profile = a.profile_id then
    return;
  end if;
  perform app.require_guardian(a);
end $$;

-- ------------------------------------------------------------------ api: reads

-- One row per definition with the household's effective value, then every member and
-- device override of the household. RLS limits both halves to the caller's household.
create view api.settings with (security_invoker = true) as
  select d.key, d.scope, d.type, d.constraints, d.self_service, d.default_value,
         coalesce(h.value, d.default_value) as value,
         h.id is null as is_default,
         null::uuid as profile_id,
         null::uuid as device_id
    from app.setting_definition d
    left join app.household_setting h
      on h.key = d.key and h.household_id = app.jwt_household()
     and h.profile_id is null and h.device_id is null
  union all
  select o.key, d.scope, d.type, d.constraints, d.self_service, d.default_value,
         o.value, false, o.profile_id, o.device_id
    from app.household_setting o
    join app.setting_definition d on d.key = o.key
   where o.household_id = app.jwt_household()
     and (o.profile_id is not null or o.device_id is not null);

grant select on api.settings to authenticated;

-- ------------------------------------------------------------------ api: writes

create function api.set_setting(p_actor uuid, p_key text, p_value jsonb,
                                p_profile_id uuid default null, p_device_id uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a     app.actor_t := app.actor(p_actor);
  v_def app.setting_definition;
  v_id  uuid;
begin
  -- PostgREST hands a JSON null over as SQL NULL; for a nullable setting it means "off".
  p_value := coalesce(p_value, 'null'::jsonb);
  select * into v_def from app.setting_definition where key = p_key;
  if not found then
    raise exception 'WW-SET-002 unknown setting' using errcode = '22023', hint = 'setting_unknown';
  end if;
  perform app.setting_authorise(a, v_def, p_profile_id, p_device_id);
  if not app.setting_valid(v_def, p_value) then
    raise exception 'WW-SET-001 setting value out of range' using errcode = '22023', hint = 'setting_invalid';
  end if;

  insert into app.household_setting (household_id, key, profile_id, device_id, value, updated_by_profile_id)
  values (a.household_id, p_key, p_profile_id, p_device_id, p_value, a.profile_id)
  on conflict on constraint household_setting_scope_key do update
    set value = excluded.value,
        updated_at = now(),
        updated_by_profile_id = excluded.updated_by_profile_id
  returning id into v_id;

  perform app.audit(a, 'setting', v_id, 'set', jsonb_build_object(
    'key', p_key, 'value', p_value, 'profile_id', p_profile_id, 'device_id', p_device_id));
  perform app.broadcast(a.household_id, 'settings');
  return jsonb_build_object('key', p_key, 'value', p_value);
end $$;

create function api.reset_setting(p_actor uuid, p_key text,
                                  p_profile_id uuid default null, p_device_id uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a     app.actor_t := app.actor(p_actor);
  v_def app.setting_definition;
  v_id  uuid;
begin
  select * into v_def from app.setting_definition where key = p_key;
  if not found then
    raise exception 'WW-SET-002 unknown setting' using errcode = '22023', hint = 'setting_unknown';
  end if;
  perform app.setting_authorise(a, v_def, p_profile_id, p_device_id);

  delete from app.household_setting
   where household_id = a.household_id and key = p_key
     and profile_id is not distinct from p_profile_id
     and device_id is not distinct from p_device_id
  returning id into v_id;

  perform app.audit(a, 'setting', v_id, 'reset', jsonb_build_object(
    'key', p_key, 'profile_id', p_profile_id, 'device_id', p_device_id));
  perform app.broadcast(a.household_id, 'settings');
end $$;

-- ------------------------------------------------------------------ grants

revoke execute on function api.set_setting(uuid, text, jsonb, uuid, uuid),
                           api.reset_setting(uuid, text, uuid, uuid) from public, anon;
grant execute on function api.set_setting(uuid, text, jsonb, uuid, uuid),
                          api.reset_setting(uuid, text, uuid, uuid) to authenticated;

-- Internal: a new app function is executable by PUBLIC unless revoked here.
revoke execute on function app.setting_valid(app.setting_definition, jsonb),
                           app.setting_authorise(app.actor_t, app.setting_definition, uuid, uuid)
  from public, anon, authenticated;
