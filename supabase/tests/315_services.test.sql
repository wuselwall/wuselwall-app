begin;
select plan(126);

-- Opt-in services (ADR-022, specs/30 "Services"), migrations/20261115100000_services.sql: the
-- provider rows a guardian keeps, the write-only keys, the door the Edge Functions ask first, the
-- service-role functions and the cache of public facts. Start from an empty system, whatever the
-- database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;

create function pg_temp.id(p_name text) returns uuid language sql as $$
  select id from ids where name = p_name
$$;

-- Switches to the device's Auth user, as PostgREST would with its JWT.
create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- The hint of the error a statement raises, or 'no error'.
create function pg_temp.error_hint(p_sql text) returns text language plpgsql as $$
declare v_hint text;
begin
  execute p_sql;
  return 'no error';
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint;
  return v_hint;
end $$;

create function pg_temp.add_dev(p_name text, p_user text, p_hh text, p_profile text, p_class text,
  p_register text, p_revoked boolean default false) returns void language plpgsql as $$
declare
  v_id  uuid := gen_random_uuid();
  v_usr uuid := (select usr from users where name = p_user);
  v_hh  uuid := pg_temp.id(p_hh);
begin
  insert into app.device (id, household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  values (v_id, v_hh, v_usr, p_name, p_class, p_register, pg_temp.id(p_profile),
          case when p_revoked then now() end);
  insert into devs values (p_name, v_usr, v_id, v_hh, p_class);
end $$;

-- The Edge Functions' identity: the service role, with its JWT claims.
create function pg_temp.as_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  perform set_config('role', 'service_role', true);
end $$;

-- Sets a provider as device p_dev (acting as p_actor on a shared device, else null).
create function pg_temp.set_prov(p_dev text, p_provider text, p_config text, p_actor text default null)
returns void language plpgsql as $$
begin
  perform pg_temp.act_as_dev(p_dev);
  perform api.service_provider_set(pg_temp.id(p_actor), p_provider, p_config::jsonb);
  reset role;
end $$;

-- The names of the providers service_request(p_capability) answers, in order, as one string.
create function pg_temp.names(p_dev text, p_capability text, p_actor text default null) returns text
language plpgsql as $$
declare v text;
begin
  perform pg_temp.act_as_dev(p_dev);
  select coalesce(string_agg(x ->> 'provider', ',' order by o), '') into v
    from jsonb_array_elements(api.service_request(pg_temp.id(p_actor), p_capability) -> 'providers')
         with ordinality t(x, o);
  reset role;
  return v;
end $$;

-- ---- household A: Papa and Mama (guardians), Opa (an adult member), Kind (a child); B: Bea ---------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;
insert into users select 'papa', auth_user_id from app.profile where id = pg_temp.id('papa');
insert into users select n, app.create_auth_user(n || '@example.org', 'longpassword1')
  from unnest(array['bea', 'mama', 'opa', 'kind', 'papa_old', 'ipad', 'kiosk']) n;

insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
with ins as (insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_b'), 'Bea', 'guardian', usr from users where name = 'bea' returning id)
insert into ids select 'bea', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_a'), 'Mama', 'guardian', usr from users where name = 'mama' returning id)
insert into ids select 'mama', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_a'), 'Opa', 'member', usr from users where name = 'opa' returning id)
insert into ids select 'opa', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, kind)
  select pg_temp.id('hh_a'), 'Kind', 'member', 'child' returning id)
insert into ids select 'kind', id from ins;

select pg_temp.add_dev('papa', 'papa', 'hh_a', 'papa', 'personal', 'adult');
select pg_temp.add_dev('bea', 'bea', 'hh_b', 'bea', 'personal', 'adult');
select pg_temp.add_dev('mama', 'mama', 'hh_a', 'mama', 'personal', 'adult');
select pg_temp.add_dev('opa', 'opa', 'hh_a', 'opa', 'personal', 'adult');
select pg_temp.add_dev('kind', 'kind', 'hh_a', 'kind', 'personal', 'kid');
select pg_temp.add_dev('ipad', 'ipad', 'hh_a', null, 'shared', 'adult');
select pg_temp.add_dev('kiosk', 'kiosk', 'hh_a', null, 'kiosk', 'kiosk');

-- ---- 1. The announcement and the shape ------------------------------------------------------------
select ok(api.server_info() -> 'features' ? 'services', 'the server announces the services');
select hasnt_column('app', 'service_cache', 'household_id', 'the cache holds public facts: no household');
select has_column('app', 'service_provider', 'key_hint', 'the provider row keeps the hint of a key');
select hasnt_column('app', 'service_provider', 'secret', 'and never the key');

-- ---- 2. A guardian switches providers on ----------------------------------------------------------------
select lives_ok($$ select pg_temp.set_prov('papa', 'open-meteo',
  '{"enabled": true, "capabilities": ["forecast", "climate", "geocode", "climate"], "position": 0}') $$,
  'a guardian switches a provider on');
select is((select enabled::text || ':' || capabilities::text || ':' || position::text || ':' || has_key::text
             from app.service_provider where household_id = pg_temp.id('hh_a') and provider = 'open-meteo'),
  'true:{climate,forecast,geocode}:0:false', 'with its capabilities, de-duplicated and sorted, its place and no key');

select lives_ok($$ select pg_temp.set_prov('papa', 'openweathermap',
  '{"enabled": true, "capabilities": ["forecast", "geocode"], "key": "abcdefghijkl1234"}') $$,
  'a provider is switched on with a key');
select pg_temp.act_as_dev('papa');
select is((select has_key::text || ':' || key_hint from api.service_providers where provider = 'openweathermap'),
  'true:…1234', 'the household reads that there is a key and its last four characters');
select is((select position from api.service_providers where provider = 'openweathermap'), 1,
  'a new provider goes last in the household''s order');
select is((select calls_today from api.service_providers where provider = 'openweathermap'), 0,
  'and has made no calls');
reset role;
select is((select secret from app.service_secret where household_id = pg_temp.id('hh_a') and provider = 'openweathermap'),
  'abcdefghijkl1234', 'the key itself is in the secret table');

select lives_ok($$ select pg_temp.set_prov('papa', 'meteostat', '{"enabled": false, "capabilities": ["climate"], "key": "short1"}') $$,
  'a short key is stored');
select is((select key_hint from app.service_provider where household_id = pg_temp.id('hh_a') and provider = 'meteostat'),
  '…', 'a key under twelve characters shows no characters of itself');

select lives_ok($$ select pg_temp.set_prov('papa', 'openweathermap', '{"enabled": false}') $$,
  'a key that is not sent is kept');
select is((select has_key::text || ':' || key_hint || ':' || enabled::text from app.service_provider
            where household_id = pg_temp.id('hh_a') and provider = 'openweathermap')
          || ':' || (select count(*)::text from app.service_secret where household_id = pg_temp.id('hh_a') and provider = 'openweathermap'),
  'true:…1234:false:1', 'with its hint, and the other keys untouched');
select pg_temp.set_prov('papa', 'openweathermap', '{"enabled": true}');

select lives_ok($$ select pg_temp.set_prov('papa', 'meteostat', '{"key": ""}') $$, 'an empty key removes it');
select is((select has_key::text || ':' || coalesce(key_hint, 'none') from app.service_provider
            where household_id = pg_temp.id('hh_a') and provider = 'meteostat')
          || ':' || (select count(*)::text from app.service_secret where household_id = pg_temp.id('hh_a') and provider = 'meteostat'),
  'false:none:0', 'the flag, the hint and the secret are gone');

-- ---- 3. The key never leaves -----------------------------------------------------------------------
select ok(not exists (select 1 from app.audit_log where diff::text like '%abcdefghijkl1234%' or diff::text like '%short1%'),
  'no audit row holds a key');
select ok(exists (select 1 from app.audit_log where entity_type = 'service_provider' and diff ->> 'provider' = 'openweathermap'
                    and diff ->> 'key' = 'set'), 'the audit row says only that a key was set');
select ok(exists (select 1 from app.audit_log where entity_type = 'service_provider' and diff ->> 'provider' = 'meteostat'
                    and diff ->> 'key' = 'removed'), 'or removed');
select pg_temp.act_as_dev('papa');
select ok(not exists (select 1 from api.service_providers p where to_jsonb(p)::text like '%abcdefghijkl1234%'),
  'no view shows a key');
select throws_ok($$ select count(*) from app.service_secret $$, '42501', null, 'a guardian''s device cannot read the secret table');
select throws_ok($$ select count(*) from app.service_cache $$, '42501', null, 'nor the cache');
select pg_temp.act_as_dev('kind');
select throws_ok($$ select count(*) from app.service_secret $$, '42501', null, 'nor a child''s device');
select pg_temp.act_as_dev('kiosk');
select throws_ok($$ select count(*) from app.service_secret $$, '42501', null, 'nor the wall');
reset role;
set local role anon;
select throws_ok($$ select count(*) from app.service_secret $$, '42501', null, 'nor an anonymous caller');
select throws_ok($$ select count(*) from api.service_providers $$, '42501', null, 'who reads no provider view either');
reset role;
select is((select count(*)::int from pg_policy p join pg_class c on c.oid = p.polrelid
            where c.relname in ('service_secret', 'service_cache') and 'authenticated'::regrole::oid = any (p.polroles)),
  0, 'neither table has a policy for a device role');

-- ---- 4. Who may ------------------------------------------------------------------------------------
select pg_temp.act_as_dev('opa');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'open-meteo', '{"enabled": false}') $$),
  'guardian_required', 'an adult who is no guardian cannot switch a provider');
select is(pg_temp.error_hint($$ select api.service_request(null, null) $$), 'guardian_required',
  'nor ask for the catalogue and test door');
select is(api.service_request(null, 'forecast') ->> 'household_id', pg_temp.id('hh_a')::text,
  'but may ask for a capability');
select pg_temp.act_as_dev('kind');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'open-meteo', '{"enabled": false}') $$),
  'adults_only', 'a child cannot switch a provider');
select is(pg_temp.error_hint($$ select api.service_request(null, 'forecast') $$), 'adults_only',
  'nor spend a call: the door refuses a child');
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.error_hint(format($$ select api.service_provider_set(%L, 'open-meteo', '{"enabled": false}') $$, pg_temp.id('papa'))),
  'kiosk_forbidden', 'the wall switches nothing');
select is(pg_temp.error_hint(format($$ select api.service_request(%L, 'forecast') $$, pg_temp.id('papa'))),
  'kiosk_forbidden', 'and asks for nothing');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($$ select api.service_request(%L, 'forecast') $$, pg_temp.id('kind'))), 'adults_only',
  'a child at the shared device is refused as well');
select is(pg_temp.error_hint(format($$ select api.service_request(%L, 'forecast') $$, pg_temp.id('opa'))), 'no error',
  'an adult at the shared device may ask');
select is(pg_temp.error_hint(format($$ select api.service_provider_set(%L, 'open-meteo', '{"enabled": false}') $$, pg_temp.id('opa'))),
  'guardian_required', 'and still needs a guardian to switch');
select is(pg_temp.error_hint($$ select api.service_request(null, 'forecast') $$), 'actor_required',
  'a shared device must say who acts');

-- ---- 5. Households and devices are kept apart -------------------------------------------------------
select pg_temp.act_as_dev('bea');
select is((select count(*)::int from api.service_providers), 0, 'another household sees no provider');
select is(api.service_request(null, 'forecast'), jsonb_build_object('household_id', pg_temp.id('hh_b'), 'providers', '[]'::jsonb),
  'and the door answers for its own household only');
select lives_ok($$ select api.service_provider_set(null, 'open-meteo', '{"enabled": true, "capabilities": ["climate"]}') $$,
  'it keeps its own provider rows, with the same name');
select is((select count(*)::int from api.service_providers), 1, 'one of them');
reset role;
select is((select capabilities::text from app.service_provider where household_id = pg_temp.id('hh_a') and provider = 'open-meteo'),
  '{climate,forecast,geocode}', 'and the first household''s row is as it was');

select pg_temp.add_dev('papa_old', 'papa_old', 'hh_a', 'papa', 'personal', 'adult', true);
select pg_temp.act_as_dev('papa_old');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'open-meteo', '{"enabled": false}') $$),
  'device_revoked', 'a revoked device switches nothing');
select is(pg_temp.error_hint($$ select api.service_request(null, 'forecast') $$), 'device_revoked', 'and asks for nothing');
select is((select count(*)::int from api.service_providers), 0, 'and sees no provider');
reset role;
set local role anon;
select throws_ok($$ select api.service_provider_set(null, 'open-meteo', '{}') $$, '42501', null, 'an anonymous caller cannot switch a provider');
select throws_ok($$ select api.service_request(null, 'forecast') $$, '42501', null, 'nor ask the door');
reset role;

-- ---- 6. What is refused ---------------------------------------------------------------------------
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from app.service_provider), 3, 'the rows before the refusals');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'X', '{}') $$), 'service_invalid', 'a provider id in capitals');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'a', '{}') $$), 'service_invalid', 'a one-letter id');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'new-one', '[]') $$), 'service_invalid', 'a config that is no object');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'new-one', '{"capabilities": ["teleport"]}') $$),
  'service_invalid', 'an unknown capability');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'new-one', '{"capabilities": "climate"}') $$),
  'service_invalid', 'capabilities that are no array');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'new-one', '{"position": 100}') $$), 'service_invalid', 'a position of 100');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'new-one', '{"position": -1}') $$), 'service_invalid', 'a negative position');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'new-one', '{"position": 1.5}') $$), 'service_invalid', 'a fractional position');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'new-one', '{"enabled": "yes"}') $$), 'service_invalid', 'an enabled that is no boolean');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'new-one', '{"key": 12345678}') $$), 'service_invalid', 'a key that is no string');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'new-one', '{"key": null}') $$), 'service_invalid', 'a null key');
select is(pg_temp.error_hint($$ select api.service_provider_set(null, 'new-one', '{"key": "   "}') $$), 'service_invalid', 'a key of blanks');
select is(pg_temp.error_hint(format($$ select api.service_provider_set(null, 'new-one', jsonb_build_object('key', %L)) $$, repeat('k', 501))),
  'service_invalid', 'a key of 501 characters');
select lives_ok(format($$ select api.service_provider_set(null, 'long-key', jsonb_build_object('enabled', true, 'key', %L)) $$, repeat('k', 500)),
  'but 500 are taken');
reset role;
select is((select count(*)::int from app.service_provider where provider in ('new-one', 'a', 'X')), 0, 'no refusal wrote a row');

-- ---- 7. The door: order and filter -----------------------------------------------------------------
select pg_temp.set_prov('papa', 'zeta-geo', '{"enabled": true, "capabilities": ["climate"], "position": 5}');
select pg_temp.set_prov('papa', 'alpha-geo', '{"enabled": true, "capabilities": ["climate", "map"], "position": 5}');
select pg_temp.set_prov('papa', 'off-geo', '{"enabled": false, "capabilities": ["climate"], "position": 0}');
select is(pg_temp.names('papa', 'climate'), 'open-meteo,alpha-geo,zeta-geo',
  'the door lists the enabled providers of a capability by position, then name');
select is(pg_temp.names('papa', 'map'), 'alpha-geo', 'only those that offer it');
select is(pg_temp.names('papa', 'route'), '', 'none when nobody does');
select is(pg_temp.names('opa', 'forecast'), 'open-meteo,openweathermap', 'a member adult asks the same way');
select is(pg_temp.names('papa', null), 'open-meteo,openweathermap,long-key,alpha-geo,zeta-geo',
  'a guardian''s null capability lists every enabled provider');
select pg_temp.act_as_dev('papa');
select is(api.service_request(null, 'forecast') -> 'providers' -> 1, '{"provider": "openweathermap", "has_key": true, "calls_today": 0}'::jsonb,
  'each carries its name, whether it has a key and today''s calls');
select is(pg_temp.error_hint($$ select api.service_request(null, 'teleport') $$), 'service_invalid', 'an unknown capability is refused');
reset role;

-- ---- 8. The service role ---------------------------------------------------------------------------
select pg_temp.act_as_dev('papa');
select throws_like($$ select api.service_secrets((select household_id from app.service_provider limit 1)) $$,
  '%permission denied%', 'a guardian''s device cannot read the keys');
select throws_like($$ select api.service_report(null, 'open-meteo', true, null) $$, '%permission denied%', 'nor report a call');
select throws_like($$ select api.service_cache_get(array['x']) $$, '%permission denied%', 'nor read the cache');
select throws_like($$ select api.service_cache_put('k', 'climate', 'open-meteo', '{}', 10) $$, '%permission denied%', 'nor fill it');
select throws_like($$ select api.service_cache_recent('open-meteo', 'climate', 10) $$, '%permission denied%', 'nor count it');
reset role;
set local role anon;
select throws_like($$ select api.service_secrets(null) $$, '%permission denied%', 'an anonymous caller cannot read the keys either');
reset role;
select is((select string_agg(f, ',' order by f) from unnest(array['api.service_secrets(uuid)', 'api.service_report(uuid,text,boolean,text)',
  'api.service_cache_get(text[])', 'api.service_cache_put(text,text,text,jsonb,integer)', 'api.service_cache_recent(text,text,integer)']) f
  where has_function_privilege('service_role', f, 'execute') and not has_function_privilege('authenticated', f, 'execute')
    and not has_function_privilege('anon', f, 'execute')),
  'api.service_cache_get(text[]),api.service_cache_put(text,text,text,jsonb,integer),api.service_cache_recent(text,text,integer),api.service_report(uuid,text,boolean,text),api.service_secrets(uuid)',
  'only the service role may execute the five functions');

select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
set local role service_role;
select throws_like($$ select api.service_secrets(null) $$, '%service role required%', 'the grant alone is not enough: the JWT must be the service role''s');
select throws_like($$ select api.service_cache_get(array['x']) $$, '%service role required%', 'for each of them');
reset role;
select pg_temp.as_service();

select is(api.service_secrets(pg_temp.id('hh_a')) ->> 'openweathermap', 'abcdefghijkl1234', 'the service role reads the key of an enabled provider');
select is((select array_agg(k order by k) from jsonb_object_keys(api.service_secrets(pg_temp.id('hh_a'))) k),
  array['long-key', 'openweathermap'], 'and only keys: providers without one are absent');
reset role;
select pg_temp.set_prov('papa', 'long-key', '{"enabled": false}');
select pg_temp.as_service();
select is((select array_agg(k order by k) from jsonb_object_keys(api.service_secrets(pg_temp.id('hh_a'))) k),
  array['openweathermap'], 'a provider that is switched off hands out no key');
select is(api.service_secrets(pg_temp.id('hh_b')), '{}'::jsonb, 'another household has none');

-- Reporting.
select is(api.service_report(pg_temp.id('hh_a'), 'open-meteo', true, null), '{"calls_today": 1}'::jsonb, 'the first call of the day is counted');
select is(api.service_report(pg_temp.id('hh_a'), 'open-meteo', true, null), '{"calls_today": 2}'::jsonb, 'and the second');
reset role;
select is((select last_ok_at is not null and last_error is null from app.service_provider
            where household_id = pg_temp.id('hh_a') and provider = 'open-meteo'), true, 'a success is recorded');
select pg_temp.as_service();
select is(api.service_report(pg_temp.id('hh_a'), 'open-meteo', false, repeat('e', 100)) ->> 'calls_today', '3', 'a failure counts as a call');
reset role;
select is((select length(last_error) from app.service_provider where household_id = pg_temp.id('hh_a') and provider = 'open-meteo'),
  60, 'and keeps a short code, cut at 60 characters');
select pg_temp.act_as_dev('papa');
select is((select calls_today from api.service_providers where provider = 'open-meteo'), 3, 'the household sees today''s calls');
reset role;
update app.service_provider set calls_day = current_date - 1 where household_id = pg_temp.id('hh_a') and provider = 'open-meteo';
select pg_temp.act_as_dev('papa');
select is((select calls_today from api.service_providers where provider = 'open-meteo'), 0, 'a counter of an earlier day reads zero');
select is(api.service_request(null, 'climate') -> 'providers' -> 0 ->> 'calls_today', '0', 'also at the door');
reset role;
select pg_temp.as_service();
select is(api.service_report(pg_temp.id('hh_a'), 'open-meteo', true, null) ->> 'calls_today', '1', 'a new day starts the counter again');
reset role;
select is((select calls_day from app.service_provider where household_id = pg_temp.id('hh_a') and provider = 'open-meteo'),
  current_date, 'on today''s date');
select pg_temp.as_service();
select is(pg_temp.error_hint(format($$ select api.service_report(%L, 'open-meteo', true, null) $$, pg_temp.id('hh_b'))), 'no error',
  'household B has its own provider row of that name');
select is(pg_temp.error_hint(format($$ select api.service_report(%L, 'openweathermap', true, null) $$, pg_temp.id('hh_b'))), 'service_invalid',
  'but a provider only another household has is refused');
select is(pg_temp.error_hint(format($$ select api.service_report(%L, 'open-meteo', null, null) $$, pg_temp.id('hh_a'))), 'service_invalid',
  'an outcome that is neither ok nor failed is refused');
reset role;
select is((select calls_today from app.service_provider where household_id = pg_temp.id('hh_b') and provider = 'open-meteo'), 1,
  'and a report counts for one household only');

-- The cache.
select pg_temp.as_service();
select lives_ok($$ select api.service_cache_put('climate:47.37,8.54', 'climate', 'open-meteo', '{"months": [1, 2]}', 3600) $$, 'an answer is cached');
select is(api.service_cache_get(array['climate:47.37,8.54', 'climate:0,0']) -> 'climate:47.37,8.54' ->> 'provider', 'open-meteo',
  'and read back with its provider');
select is(api.service_cache_get(array['climate:47.37,8.54']) -> 'climate:47.37,8.54' -> 'payload', '{"months": [1, 2]}'::jsonb, 'and its payload');
select ok(api.service_cache_get(array['climate:47.37,8.54']) -> 'climate:47.37,8.54' ? 'fetched_at', 'and the time it was fetched');
select ok(not api.service_cache_get(array['climate:47.37,8.54', 'climate:0,0']) ? 'climate:0,0', 'a key that was never cached is absent');
select lives_ok($$ select api.service_cache_put('climate:47.37,8.54', 'climate', 'met-no', '{"months": []}', 3600) $$, 'putting again replaces');
select is(api.service_cache_get(array['climate:47.37,8.54']) -> 'climate:47.37,8.54' ->> 'provider', 'met-no', 'the newer answer');
reset role;
select is((select count(*)::int from app.service_cache), 1, 'one row for one key');
update app.service_cache set expires_at = now() - interval '1 second';
select pg_temp.as_service();
select is(api.service_cache_get(array['climate:47.37,8.54']), '{}'::jsonb, 'an expired answer is not served');
reset role;
delete from app.service_cache;
insert into app.service_cache (key, capability, provider, payload, expires_at)
  select 'old:' || g, 'geocode', 'nominatim', '{}', now() - interval '1 day' from generate_series(1, 230) g;
select pg_temp.as_service();
select lives_ok($$ select api.service_cache_put('geo:zurich', 'geocode', 'nominatim', '{"lat": 47.37}', 7776000) $$, 'the next put');
reset role;
select is((select count(*)::int from app.service_cache), 31, 'removes up to 200 expired rows (230 expired, 30 left, and the new one)');
select pg_temp.as_service();
select is(api.service_cache_recent('nominatim', 'geocode', 60), 31, 'the recent count');
select is(api.service_cache_recent('nominatim', 'climate', 60), 0, 'counts by capability');
select is(api.service_cache_recent('open-meteo', 'geocode', 60), 0, 'and by provider');
reset role;
update app.service_cache set fetched_at = now() - interval '2 hours' where key = 'geo:zurich';
select pg_temp.as_service();
select is(api.service_cache_recent('nominatim', 'geocode', 3600), 30, 'only within the window');
select is(pg_temp.error_hint($$ select api.service_cache_get(array_fill('k'::text, array[501])) $$), 'service_invalid', 'more than 500 keys are refused');
select is(pg_temp.error_hint($$ select api.service_cache_put('k', 'weather', 'open-meteo', '{}', 10) $$), 'service_invalid', 'an unknown capability');
select is(pg_temp.error_hint($$ select api.service_cache_put('k', 'climate', 'Open Meteo', '{}', 10) $$), 'service_invalid', 'a provider that is no id');
select is(pg_temp.error_hint($$ select api.service_cache_put('k', 'climate', 'open-meteo', '{}', 0) $$), 'service_invalid', 'no time to live');
select is(pg_temp.error_hint($$ select api.service_cache_put('', 'climate', 'open-meteo', '{}', 10) $$), 'service_invalid', 'an empty key');
reset role;

-- ---- 9. The export ----------------------------------------------------------------------------------
select is((select omit from app.export_table where name = 'service_provider'),
  array['calls_day', 'calls_today', 'last_ok_at', 'last_error'], 'the provider rows are exported without their counters');
select is((select count(*)::int from app.export_table where name in ('service_secret', 'service_cache')), 0,
  'the keys and the cache never are');
select pg_temp.act_as_dev('papa');
select is((select r from (select jsonb_array_elements(api.household_export_page(null, 'service_provider', null, 100) -> 'rows') r) q
            where r ->> 'provider' = 'openweathermap') ?| array['calls_today', 'calls_day', 'last_ok_at', 'last_error', 'secret'],
  false, 'an exported row holds no counter and no key');
select is((select r ->> 'key_hint' from (select jsonb_array_elements(api.household_export_page(null, 'service_provider', null, 100) -> 'rows') r) q
            where r ->> 'provider' = 'openweathermap'), '…1234', 'only the hint');
reset role;

-- ---- 10. A household takes its keys with it -----------------------------------------------------------
select is((select count(*)::int from app.service_secret where household_id = pg_temp.id('hh_a')), 2, 'household A has two keys');
delete from app.household where id = pg_temp.id('hh_a');
select is((select count(*)::int from app.service_provider where household_id = pg_temp.id('hh_a'))
          + (select count(*)::int from app.service_secret where household_id = pg_temp.id('hh_a')), 0,
  'deleting a household deletes its providers and its keys');
select is((select count(*)::int from app.service_provider where household_id = pg_temp.id('hh_b')), 1, 'and only its own');

select * from finish();
rollback;
