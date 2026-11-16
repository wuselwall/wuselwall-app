-- Opt-in services: weather, place search, routes and map pictures through the family's server,
-- with the family's own keys (ADR-023, specs/30 "Services").
--
-- Third parties are contacted by the Edge Functions `services` and `trips`, never by an app, and
-- only for a household whose guardian switched the provider on. This migration holds what the
-- database knows of it: which providers a household enabled and in which order, the keys (write
-- only), the polite call counters, and a cache of public facts.
--
--   * app.service_provider: one row per household and provider (enabled, the capabilities the
--     household uses it for, its position in the household's order, whether a key is stored, the
--     last four characters of it, the outcome of the last call, today's call counter). No secret
--     lives here: every device of the household reads it through api.service_providers.
--   * app.service_secret: the API keys. RLS enabled and forced, no policy for a device role, no
--     grant to any role: only the service-role functions below read it. Never exported, never
--     audited, never logged.
--   * app.service_cache: answers that are public facts (a coordinate's climate, a place's
--     coordinates). No household. No policy for a device role, no grant to any role.
--   * api.service_provider_set (guardian): switches a provider on or off, sets its order and
--     capabilities, stores or removes its key. The audit row never holds the key.
--   * api.service_request: the door of the Edge Functions. Run as the calling user before any
--     provider is contacted: the actor must be an adult profile on a device that is not the wall,
--     and a request without a capability (the test and catalogue actions) needs a guardian.
--   * Service role only (`service_role_required` otherwise): api.service_secrets,
--     api.service_report, api.service_cache_get, api.service_cache_put,
--     api.service_cache_recent.
--   * app.trip_actor: "an adult profile, not the wall", the check of every trip function in the
--     next migration and of api.service_request. It lives here because this migration is the
--     first to need it.
--   * The export carries service_provider without its call counters and bookkeeping
--     (calls_day, calls_today, last_ok_at, last_error); service_secret is never exported.
--
-- Errors (hint in brackets):
--   WW-SVC-001 service invalid (service_invalid)  a provider id, capability, position, key,
--                                                 shape or cache argument the function refuses
--   42501 adults_only                             the acting profile is a child
--   42501 kiosk_forbidden / guardian_required / service_role_required / device_revoked
--
-- api_version: unchanged. Additive: tables and functions only. An older app calls none of them;
-- api.server_info announces 'services', and a newer app on an older server hides the page.

-- ================================================================== the adult check

-- The actor of an adult-only function: the device is live, it is not the wall, and the acting
-- profile is an adult (a child's phone holds a household session; without this check a loop on
-- one could spend a family's paid key or edit a trip).
create function app.trip_actor(p_actor uuid) returns app.actor_t
language plpgsql stable security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if (select p.kind from app.profile p where p.id = a.profile_id) is distinct from 'adult' then
    raise exception 'adults only' using errcode = '42501', hint = 'adults_only';
  end if;
  return a;
end $$;
revoke all on function app.trip_actor(uuid) from public, anon, authenticated;

-- ================================================================== tables

create table app.service_provider (
  household_id          uuid not null references app.household on delete cascade,
  provider              text not null check (provider ~ '^[a-z0-9-]{2,40}$'),
  enabled               boolean not null default false,
  capabilities          text[] not null default '{}'
                          check (capabilities <@ array['climate', 'forecast', 'geocode', 'route', 'map']::text[]),
  position              int not null default 0 check (position between 0 and 99),
  has_key               boolean not null default false,
  key_hint              text check (key_hint is null or length(key_hint) <= 8),
  last_ok_at            timestamptz,
  last_error            text check (last_error is null or length(last_error) <= 60),
  calls_day             date,
  calls_today           int not null default 0 check (calls_today >= 0),
  updated_at            timestamptz not null default now(),
  updated_by_profile_id uuid references app.profile on delete set null,
  primary key (household_id, provider)
);

-- The keys of a household. The foreign key makes the key go with its provider row.
create table app.service_secret (
  household_id uuid not null references app.household on delete cascade,
  provider     text not null,
  secret       text not null check (length(secret) between 1 and 500),
  primary key (household_id, provider),
  foreign key (household_id, provider) references app.service_provider on delete cascade
);

-- Public facts, keyed by what was asked ("climate:47.37,8.54"). No household on purpose.
create table app.service_cache (
  key        text primary key check (length(key) between 1 and 300),
  capability text not null check (capability in ('climate', 'forecast', 'geocode', 'route', 'map')),
  provider   text not null check (provider ~ '^[a-z0-9-]{2,40}$'),
  payload    jsonb not null,
  fetched_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index service_cache_expires_idx on app.service_cache (expires_at);
create index service_cache_recent_idx on app.service_cache (provider, capability, fetched_at);

alter table app.service_provider enable row level security;
alter table app.service_secret   enable row level security;
alter table app.service_cache    enable row level security;
alter table app.service_provider force row level security;
alter table app.service_secret   force row level security;
alter table app.service_cache    force row level security;

create policy service_provider_read on app.service_provider for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.service_provider to postgres using (true) with check (true);
-- The secret and the cache have no policy for a device role at all.
create policy owner_all on app.service_secret   to postgres using (true) with check (true);
create policy owner_all on app.service_cache    to postgres using (true) with check (true);

revoke all on app.service_provider, app.service_secret, app.service_cache from public, anon, authenticated;
grant select on app.service_provider to authenticated;

-- ================================================================== api: read

-- Everything of service_provider; no secret exists in that table. The counter shows today's
-- calls only: a counter of an earlier day reads 0.
create view api.service_providers with (security_invoker = true) as
  select p.provider, p.enabled, p.capabilities, p.position, p.has_key, p.key_hint,
         p.last_ok_at, p.last_error,
         case when p.calls_day = current_date then p.calls_today else 0 end as calls_today,
         p.updated_at, p.updated_by_profile_id
    from app.service_provider p;

grant select on api.service_providers to authenticated;
revoke all on api.service_providers from anon;

-- ================================================================== api: guardian

-- Switches a provider on or off for the household and keeps its order, capabilities and key.
-- p_config keys: enabled (boolean), capabilities (an array of climate, forecast, geocode, route,
-- map), position (0 to 99), key (a string stores it, '' removes it, absent keeps it). A key that
-- is not sent keeps the stored value on update; a new provider starts switched off, with no
-- capability, last in the household's order. The audit row says only that a key was set or
-- removed, never what it is.
create function api.service_provider_set(p_actor uuid, p_provider text, p_config jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a          app.actor_t := app.trip_actor(p_actor);
  v_old      app.service_provider;
  v_found    boolean;
  v_enabled  boolean;
  v_caps     text[];
  v_pos      int;
  v_key      text;
  v_has_key  boolean;
  v_hint     text;
  v_diff     jsonb;
begin
  perform app.require_guardian(a);
  if p_provider is null or p_provider !~ '^[a-z0-9-]{2,40}$' or jsonb_typeof(p_config) is distinct from 'object' then
    raise exception 'WW-SVC-001 service invalid' using errcode = '22023', hint = 'service_invalid';
  end if;

  -- One writer per household and provider at a time.
  perform pg_advisory_xact_lock(hashtextextended('service_provider:' || a.household_id::text || ':' || p_provider, 0));
  select * into v_old from app.service_provider where household_id = a.household_id and provider = p_provider;
  v_found := found;

  if p_config ? 'enabled' and jsonb_typeof(p_config -> 'enabled') is distinct from 'boolean' then
    raise exception 'WW-SVC-001 service invalid' using errcode = '22023', hint = 'service_invalid';
  end if;
  v_enabled := case when p_config ? 'enabled' then (p_config ->> 'enabled')::boolean
                    else coalesce(v_old.enabled, false) end;

  if p_config ? 'capabilities' then
    if jsonb_typeof(p_config -> 'capabilities') is distinct from 'array'
       or jsonb_array_length(p_config -> 'capabilities') > 5
       or exists (select 1 from jsonb_array_elements(p_config -> 'capabilities') x
                   where jsonb_typeof(x) <> 'string'
                      or (x #>> '{}') <> all (array['climate', 'forecast', 'geocode', 'route', 'map'])) then
      raise exception 'WW-SVC-001 service invalid' using errcode = '22023', hint = 'service_invalid';
    end if;
    v_caps := array(select distinct x #>> '{}' from jsonb_array_elements(p_config -> 'capabilities') x order by 1);
  else
    v_caps := coalesce(v_old.capabilities, '{}');
  end if;

  if p_config ? 'position' then
    if jsonb_typeof(p_config -> 'position') is distinct from 'number'
       or (p_config ->> 'position')::numeric <> trunc((p_config ->> 'position')::numeric)
       or (p_config ->> 'position')::numeric not between 0 and 99 then
      raise exception 'WW-SVC-001 service invalid' using errcode = '22023', hint = 'service_invalid';
    end if;
    v_pos := (p_config ->> 'position')::int;
  elsif v_found then
    v_pos := v_old.position;
  else
    v_pos := least(99, coalesce((select max(p.position) + 1 from app.service_provider p
                                  where p.household_id = a.household_id), 0));
  end if;

  -- The key: a string stores it, '' removes it, absent keeps it. Anything else is refused.
  v_has_key := coalesce(v_old.has_key, false);
  v_hint    := v_old.key_hint;
  if p_config ? 'key' then
    if jsonb_typeof(p_config -> 'key') is distinct from 'string' then
      raise exception 'WW-SVC-001 service invalid' using errcode = '22023', hint = 'service_invalid';
    end if;
    v_key := btrim(p_config ->> 'key');
    if (p_config ->> 'key') = '' then
      v_has_key := false;
      v_hint := null;
    elsif length(v_key) not between 1 and 500 then
      raise exception 'WW-SVC-001 service invalid' using errcode = '22023', hint = 'service_invalid';
    else
      v_has_key := true;
      v_hint := case when length(v_key) >= 12 then '…' || right(v_key, 4) else '…' end;
    end if;
  end if;

  insert into app.service_provider as p (household_id, provider, enabled, capabilities, position,
                                         has_key, key_hint, updated_at, updated_by_profile_id)
  values (a.household_id, p_provider, v_enabled, v_caps, v_pos, v_has_key, v_hint, now(), a.profile_id)
  on conflict (household_id, provider) do update set
    enabled = excluded.enabled, capabilities = excluded.capabilities, position = excluded.position,
    has_key = excluded.has_key, key_hint = excluded.key_hint, updated_at = now(),
    updated_by_profile_id = excluded.updated_by_profile_id;

  if p_config ? 'key' then
    if v_has_key then
      insert into app.service_secret (household_id, provider, secret)
      values (a.household_id, p_provider, v_key)
      on conflict (household_id, provider) do update set secret = excluded.secret;
    else
      delete from app.service_secret where household_id = a.household_id and provider = p_provider;
    end if;
  end if;

  v_diff := jsonb_build_object('provider', p_provider, 'enabled', v_enabled,
                               'capabilities', to_jsonb(v_caps), 'position', v_pos);
  if p_config ? 'key' then
    v_diff := v_diff || jsonb_build_object('key', case when v_has_key then 'set' else 'removed' end);
  end if;
  perform app.audit(a, 'service_provider', a.household_id,
                    case when v_found then 'update' else 'create' end, v_diff);
  perform app.broadcast(a.household_id, 'settings');
end $$;

-- ================================================================== api: the door

-- The door of the Edge Functions: asked as the calling user before any provider is contacted.
-- The actor must be an adult profile on a device that is not the wall. With p_capability null
-- (the test and catalogue actions) the actor must be a guardian too. Answers
-- {household_id, providers: [{provider, has_key, calls_today}]}: the household's enabled
-- providers that offer the capability (all enabled ones for null), in the household's order.
-- Writes nothing: a read with a door check.
create function api.service_request(p_actor uuid, p_capability text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare a app.actor_t := app.trip_actor(p_actor);
begin
  if p_capability is null then
    perform app.require_guardian(a);
  elsif p_capability <> all (array['climate', 'forecast', 'geocode', 'route', 'map']) then
    raise exception 'WW-SVC-001 service invalid' using errcode = '22023', hint = 'service_invalid';
  end if;
  return jsonb_build_object(
    'household_id', a.household_id,
    'providers', coalesce((
      select jsonb_agg(jsonb_build_object(
               'provider', p.provider, 'has_key', p.has_key,
               'calls_today', case when p.calls_day = current_date then p.calls_today else 0 end)
             order by p.position, p.provider)
        from app.service_provider p
       where p.household_id = a.household_id and p.enabled
         and (p_capability is null or p_capability = any (p.capabilities))), '[]'::jsonb));
end $$;

-- ================================================================== service role only

-- {provider: key} of the household's enabled providers that have a key.
create function api.service_secrets(p_household uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  return coalesce((
    select jsonb_object_agg(s.provider, s.secret)
      from app.service_secret s
      join app.service_provider p on p.household_id = s.household_id and p.provider = s.provider
     where s.household_id = p_household and p.enabled), '{}'::jsonb);
end $$;

-- Counts one call of a provider and records its outcome: a new day starts the counter again,
-- a success sets last_ok_at and clears last_error, a failure keeps a short code in last_error.
-- Answers {calls_today}.
create function api.service_report(p_household uuid, p_provider text, p_ok boolean, p_error text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_calls int;
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  if p_ok is null then
    raise exception 'WW-SVC-001 service invalid' using errcode = '22023', hint = 'service_invalid';
  end if;
  update app.service_provider p set
    calls_today = case when p.calls_day is distinct from current_date then 1 else p.calls_today + 1 end,
    calls_day   = current_date,
    last_ok_at  = case when p_ok then now() else p.last_ok_at end,
    last_error  = case when p_ok then null else left(coalesce(nullif(btrim(p_error), ''), 'error'), 60) end
   where p.household_id = p_household and p.provider = p_provider
  returning p.calls_today into v_calls;
  if not found then
    raise exception 'WW-SVC-001 service invalid' using errcode = '22023', hint = 'service_invalid';
  end if;
  return jsonb_build_object('calls_today', v_calls);
end $$;

-- {key: {payload, provider, fetched_at}} of the unexpired rows among p_keys (at most 500).
create function api.service_cache_get(p_keys text[]) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  if p_keys is null or cardinality(p_keys) > 500 then
    raise exception 'WW-SVC-001 service invalid' using errcode = '22023', hint = 'service_invalid';
  end if;
  return coalesce((
    select jsonb_object_agg(c.key, jsonb_build_object('payload', c.payload, 'provider', c.provider,
                                                       'fetched_at', c.fetched_at))
      from app.service_cache c
     where c.key = any (p_keys) and c.expires_at > now()), '{}'::jsonb);
end $$;

-- Stores an answer for p_ttl_seconds (one second to ten years) and removes up to 200 expired rows.
create function api.service_cache_put(p_key text, p_capability text, p_provider text, p_payload jsonb,
                                      p_ttl_seconds int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  if p_key is null or length(p_key) not between 1 and 300
     or p_capability is null or p_capability <> all (array['climate', 'forecast', 'geocode', 'route', 'map'])
     or p_provider is null or p_provider !~ '^[a-z0-9-]{2,40}$'
     or p_payload is null or pg_column_size(p_payload) > 4194304
     or p_ttl_seconds is null or p_ttl_seconds not between 1 and 315360000 then
    raise exception 'WW-SVC-001 service invalid' using errcode = '22023', hint = 'service_invalid';
  end if;
  delete from app.service_cache
   where key in (select c.key from app.service_cache c where c.expires_at <= now() limit 200);
  insert into app.service_cache (key, capability, provider, payload, fetched_at, expires_at)
  values (p_key, p_capability, p_provider, p_payload, now(), now() + make_interval(secs => p_ttl_seconds))
  on conflict (key) do update set
    capability = excluded.capability, provider = excluded.provider, payload = excluded.payload,
    fetched_at = excluded.fetched_at, expires_at = excluded.expires_at;
end $$;

-- How many answers of p_provider for p_capability were fetched in the last p_seconds: the
-- server's own measure of how politely it has been calling.
create function api.service_cache_recent(p_provider text, p_capability text, p_seconds int) returns int
language plpgsql stable security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  if p_provider is null or p_capability is null or p_seconds is null or p_seconds < 0 then
    raise exception 'WW-SVC-001 service invalid' using errcode = '22023', hint = 'service_invalid';
  end if;
  return (select count(*)::int from app.service_cache c
           where c.provider = p_provider and c.capability = p_capability
             and c.fetched_at > now() - make_interval(secs => p_seconds));
end $$;

-- ================================================================== grants

revoke all on function api.service_provider_set(uuid, text, jsonb), api.service_request(uuid, text)
  from public, anon;
grant execute on function api.service_provider_set(uuid, text, jsonb), api.service_request(uuid, text)
  to authenticated;

-- The service role only. New functions are executable by PUBLIC unless revoked.
revoke all on function api.service_secrets(uuid), api.service_report(uuid, text, boolean, text),
  api.service_cache_get(text[]), api.service_cache_put(text, text, text, jsonb, int),
  api.service_cache_recent(text, text, int) from public, anon, authenticated;
grant execute on function api.service_secrets(uuid), api.service_report(uuid, text, boolean, text),
  api.service_cache_get(text[]), api.service_cache_put(text, text, text, jsonb, int),
  api.service_cache_recent(text, text, int) to service_role;

-- ================================================================== export

-- The provider rows go with the family's data, without what is only bookkeeping. The keys
-- (app.service_secret) are never exported.
insert into app.export_table (name, position, omit, keep) values
  ('service_provider', 391, array['calls_day', 'calls_today', 'last_ok_at', 'last_error'], null);

-- ================================================================== announce

-- As in 20261114120000_event_reminder.sql, plus 'services': an app on an older server hides the
-- page for weather and maps.
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
      'shopping-start', 'event-reminder', 'services'
    )
  );
$$;
