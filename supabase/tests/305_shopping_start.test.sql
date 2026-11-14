begin;
select plan(46);

-- "Somebody is going shopping" (specs/07 "Telling the others"): the trip in progress, the notice
-- the other adults get, the per-person switch, and the perimeter.
-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;
create temp table runs (name text primary key, r jsonb);
grant all on runs to public;

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

-- The shopping notices of p_actor as "name@list" pairs.
create function pg_temp.shopping(p_actor uuid) returns text language sql as $$
  select coalesce(string_agg((x ->> 'name') || '@' || (x -> 'data' ->> 'list_name'), ',' order by x ->> 'at'), '')
    from jsonb_array_elements(api.notices(p_actor)) x
   where x ->> 'kind' = 'shopping'
$$;
create function pg_temp.shopping_key(p_actor uuid) returns text language sql as $$
  select x ->> 'key' from jsonb_array_elements(api.notices(p_actor)) x where x ->> 'kind' = 'shopping' limit 1
$$;
-- Calls api.shopping_start and keeps its answer under p_name.
create function pg_temp.start(p_name text, p_actor uuid, p_list uuid default null) returns void
language sql as $$
  insert into runs values (p_name, api.shopping_start(p_actor, p_list))
$$;
create function pg_temp.run(p_name text) returns jsonb language sql as $$
  select r from runs where name = p_name
$$;

-- ---- household A: Papa and Mama (guardians), Opa (an adult member), Kind (a child); B: Bea -----
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

-- ---- 1. The catalogue and the announcement ------------------------------------------------------
select is((select default_value from app.setting_definition where key = 'notify.shopping_start'), 'true'::jsonb,
  'the notice is on unless a person switches it off');
select is((select scope || ':' || self_service from app.setting_definition where key = 'notify.shopping_start'),
  'member:true', 'each person decides for themselves');
select ok(api.server_info() -> 'features' ? 'shopping-start', 'the server announces the feature');

-- ---- 2. Papa goes shopping ------------------------------------------------------------------------
select pg_temp.act_as_dev('papa');
select pg_temp.start('first', pg_temp.id('papa'));
select is(pg_temp.run('first') ->> 'new', 'true', 'the first tap starts a trip');
select is((pg_temp.run('first') ->> 'told')::int, 2, 'and says how many other adults learn of it');
select is(pg_temp.shopping(pg_temp.id('papa')), '', 'the shopper gets no notice of their own trip');

select pg_temp.act_as_dev('mama');
reset role;
insert into ids select 'list_a', id from app.shopping_list where household_id = pg_temp.id('hh_a') and is_default;
select pg_temp.act_as_dev('mama');
select is(pg_temp.shopping(pg_temp.id('mama')),
  'Papa@' || (select name from api.shopping_lists where id = pg_temp.id('list_a')),
  'another adult sees who shops and on which list');
select is((select x ->> 'profile_id' from jsonb_array_elements(api.notices(pg_temp.id('mama'))) x
            where x ->> 'kind' = 'shopping'), pg_temp.id('papa')::text, 'the notice names the shopper''s profile');
select is((select x -> 'data' ->> 'list_id' from jsonb_array_elements(api.notices(pg_temp.id('mama'))) x
            where x ->> 'kind' = 'shopping'), pg_temp.id('list_a')::text, 'and the list''s id');

select pg_temp.act_as_dev('opa');
select is(pg_temp.shopping(pg_temp.id('opa')) <> '', true, 'an adult who is no guardian sees it too');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.shopping(pg_temp.id('opa')) <> '', true, 'also on a shared tablet, as the person at it');
select is(pg_temp.shopping(pg_temp.id('kind')), '', 'a child gets none');
select pg_temp.act_as_dev('kind');
select is(pg_temp.shopping(pg_temp.id('kind')), '', 'nor on the child''s own phone');
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.shopping(pg_temp.id('mama')), '', 'the wall shows none');
select pg_temp.act_as_dev('bea');
select is(pg_temp.shopping(pg_temp.id('bea')), '', 'another household learns nothing');

-- ---- 3. One notice per trip, not per tap ---------------------------------------------------------
select pg_temp.act_as_dev('papa');
select pg_temp.start('again', pg_temp.id('papa'));
select is(pg_temp.run('again') ->> 'new', 'false', 'opening the trip again starts no second one');
select is(pg_temp.run('again') ->> 'id', pg_temp.run('first') ->> 'id', 'it is the same trip');
reset role;
select is((select count(*)::int from app.shopping_run), 1, 'one row');
select is((select count(*)::int from app.audit_log where entity_type = 'shopping_run' and action = 'start'), 1,
  'the start is audited once');

-- ---- 4. Each person's switch ---------------------------------------------------------------------
insert into app.household_setting (household_id, key, value, profile_id)
  values (pg_temp.id('hh_a'), 'notify.shopping_start', 'false', pg_temp.id('mama'));
select pg_temp.act_as_dev('mama');
select is(pg_temp.shopping(pg_temp.id('mama')), '', 'switched off, the notice is gone for that person');
select pg_temp.act_as_dev('opa');
select is(pg_temp.shopping(pg_temp.id('opa')) <> '', true, 'and stays for the others');
select pg_temp.act_as_dev('papa');
select pg_temp.start('fewer', pg_temp.id('papa'));
select is((pg_temp.run('fewer') ->> 'told')::int, 1, 'the shopper is told about one adult fewer');
reset role;
delete from app.household_setting where key = 'notify.shopping_start';

-- ---- 5. Gesehen -------------------------------------------------------------------------------------
select pg_temp.act_as_dev('opa');
select lives_ok(format($$ select api.notice_dismiss(%L, %L) $$, pg_temp.id('opa'), pg_temp.shopping_key(pg_temp.id('opa'))),
  'a shopping notice can be dismissed');
select is(pg_temp.shopping(pg_temp.id('opa')), '', 'and is gone for that person');
select pg_temp.act_as_dev('mama');
select is(pg_temp.shopping(pg_temp.id('mama')) <> '', true, 'not for the others');

-- ---- 6. Leaving ends it; coming back soon continues it ------------------------------------------
select pg_temp.act_as_dev('papa');
select lives_ok(format($$ select api.shopping_leave(%L) $$, pg_temp.id('papa')), 'the shopper leaves the trip');
select lives_ok(format($$ select api.shopping_leave(%L) $$, pg_temp.id('papa')), 'leaving twice is harmless');
select pg_temp.act_as_dev('mama');
select is(pg_temp.shopping(pg_temp.id('mama')), '', 'the notice ends with the trip');
select pg_temp.act_as_dev('papa');
select pg_temp.start('back', pg_temp.id('papa'));
select is(pg_temp.run('back') ->> 'new' || ':' || ((pg_temp.run('back') ->> 'id') = (pg_temp.run('first') ->> 'id')),
  'false:true', 'back within 30 minutes it is the same trip');
select pg_temp.act_as_dev('mama');
select is(pg_temp.shopping(pg_temp.id('mama')) <> '', true, 'and its notice is back');
select pg_temp.act_as_dev('opa');
select is(pg_temp.shopping(pg_temp.id('opa')), '', 'but stays dismissed for who dismissed it');

-- ---- 7. Two hours, and a later trip --------------------------------------------------------------
reset role;
update app.shopping_run set started_at = now() - interval '121 minutes';
select pg_temp.act_as_dev('mama');
select is(pg_temp.shopping(pg_temp.id('mama')), '', 'a trip ends by itself after two hours');
select pg_temp.act_as_dev('papa');
select pg_temp.start('later', pg_temp.id('papa'));
select is(pg_temp.run('later') ->> 'new' || ':' || ((pg_temp.run('later') ->> 'id') = (pg_temp.run('first') ->> 'id')),
  'true:false', 'after that a new trip starts');
select pg_temp.act_as_dev('opa');
select is(pg_temp.shopping(pg_temp.id('opa')) <> '', true, 'and everybody is told again');

-- ---- 8. Another list -----------------------------------------------------------------------------
select pg_temp.act_as_dev('papa');
reset role;
select pg_temp.act_as_dev('papa');
insert into ids select 'list_b', api.shopping_list_create(pg_temp.id('papa'), 'Drogerie');
select pg_temp.start('drogerie', pg_temp.id('papa'), pg_temp.id('list_b'));
select is(pg_temp.run('drogerie') ->> 'new', 'true', 'a trip on another list is a trip of its own');
select pg_temp.act_as_dev('mama');
select is(pg_temp.shopping(pg_temp.id('mama')), 'Papa@Drogerie', 'and replaces the shopper''s earlier one');

-- ---- 9. Who records nothing -----------------------------------------------------------------------
select pg_temp.act_as_dev('kind');
select is(api.shopping_start(pg_temp.id('kind')), '{"id": null, "new": false, "told": 0}'::jsonb,
  'a child''s trip is accepted and tells nobody');
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.error_hint(format($$ select api.shopping_start(%L) $$, pg_temp.id('mama'))), 'kiosk_forbidden',
  'the wall starts no trip');
select is(pg_temp.error_hint(format($$ select api.shopping_leave(%L) $$, pg_temp.id('mama'))), 'kiosk_forbidden',
  'and ends none');

-- ---- 10. Old trips are cleared ---------------------------------------------------------------------
reset role;
update app.shopping_run set started_at = now() - interval '2 days', ended_at = now() - interval '2 days';
select pg_temp.act_as_dev('mama');
select pg_temp.start('mama', pg_temp.id('mama'));
reset role;
select is((select count(*)::int from app.shopping_run), 1, 'trips older than a day are removed at the next start');

-- ---- 11. The perimeter -----------------------------------------------------------------------------
select pg_temp.act_as_dev('mama');
select throws_ok($$ select count(*) from app.shopping_run $$, '42501', null, 'no device reads the table itself');
select pg_temp.act_as_dev('bea');
select is(pg_temp.error_hint(format($$ select api.shopping_start(%L, %L) $$, pg_temp.id('bea'), pg_temp.id('list_a'))),
  'list_not_found', 'another household cannot start a trip on this household''s list');
select is(pg_temp.shopping(pg_temp.id('bea')), '', 'and still sees none of its trips');

reset role;
select pg_temp.add_dev('papa_old', 'papa_old', 'hh_a', 'papa', 'personal', 'adult', true);
select pg_temp.act_as_dev('papa_old');
select is(pg_temp.error_hint(format($$ select api.shopping_start(%L) $$, pg_temp.id('papa'))), 'device_revoked',
  'a revoked device is refused');

reset role;
set local role anon;
select throws_ok($$ select api.shopping_start(null) $$, '42501', null, 'anonymous cannot start a trip');
select throws_ok($$ select api.shopping_leave(null) $$, '42501', null, 'anonymous cannot end one');

select * from finish();
rollback;
