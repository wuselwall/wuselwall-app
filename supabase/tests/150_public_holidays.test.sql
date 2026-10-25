begin;
select plan(15);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
-- The public feed cache outlives households; isolate it inside this rollback.
delete from app.holiday_feed;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;

-- Switches to the device's Auth user, as PostgREST would with its JWT.
create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- ---- household A: Papa on a personal phone, a revoked phone ----------------------------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;

insert into users values
  ('old', app.create_auth_user('old@example.org', 'longpassword1'));

insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (r ->> 'household_id')::uuid, p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from sa, app.profile p where p.id = (r ->> 'profile_id')::uuid;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  select (r ->> 'household_id')::uuid, u.usr, 'Old-Phone', 'personal', 'adult', p.id, now()
    from sa, users u, app.profile p where u.name = 'old' and p.id = (r ->> 'profile_id')::uuid;

insert into devs
  select 'papa', d.auth_user_id, d.id, d.household_id, 'personal' from app.device d where d.label = 'A-Phone'
  union all
  select 'old', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id
   where u.name = 'old';

-- ---- the public cache, as the sync would write it (the owner here) ----------------------------
insert into app.holiday_feed (id, country, kind, starts_on, ends_on, names, nationwide, subdivisions) values
  ('feed-de-pub', 'DE', 'public', '2026-10-03', '2026-10-03', '{"de":"Tag der Deutschen Einheit"}', true, '{}'),
  ('feed-ch-pub', 'CH', 'public', '2026-08-01', '2026-08-01', '{"de":"Bundesfeier"}', true, '{}'),
  ('feed-ch-school', 'CH', 'school', '2026-10-19', '2026-10-23', '{"de":"Herbstferien"}', false, '{"CH-ZH"}');

-- ---- anonymous callers -----------------------------------------------------------------------
reset role;
set local role anon;
select throws_ok('select count(*) from api.holiday_feed', '42501', 'permission denied for view holiday_feed',
  'anonymous callers cannot read the public holiday view');
select throws_ok('select count(*) from api.household', '42501', 'permission denied for view household',
  'anonymous callers cannot read the household view');
reset role;

-- ---- Papa, on a live device ------------------------------------------------------------------
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from api.holiday_feed), 3, 'a live device reads every cached holiday');
select is((select names ->> 'de' from api.holiday_feed where id = 'feed-de-pub'), 'Tag der Deutschen Einheit',
  'the names come as a language map');
select is((select nationwide from api.holiday_feed where id = 'feed-ch-school'), false,
  'the subdivisions are readable beside the rows');
select is((select subdivisions from api.holiday_feed where id = 'feed-ch-school'), array['CH-ZH'],
  'a school holiday names its subdivisions');
select throws_ok($$ insert into api.holiday_feed (id, country, kind, starts_on, ends_on, names, nationwide)
  values ('feed-mine', 'CH', 'public', '2026-01-01', '2026-01-01', '{}', true) $$, '42501', null,
  'a member cannot write the holiday view');
select is((select locale from api.household), 'de-DE', 'the household view shows the locale');
select is((select count(*)::int from api.household), 1, 'a member reads its own household only');
reset role;

-- ---- a revoked phone ---------------------------------------------------------------------------
select pg_temp.act_as_dev('old');
select is((select count(*)::int from api.holiday_feed), 0, 'a revoked device reads no public holidays');
select is((select count(*)::int from api.household), 0, 'a revoked device reads no household row');
reset role;

-- ---- the region rule stays the same in both places -----------------------------------------------
select is(app.region_covers('CH-ZH-ZH-ZH', 'CH', false, '{"CH-ZH"}'), true,
  'a canton covers its municipalities (the SQL rule the TypeScript mirrors)');
select is(app.region_covers('CH-AGX', 'CH', false, '{"CH-AG"}'), false,
  'the dash boundary holds in SQL too');
select is((select count(*)::int from app.holiday_feed where kind = 'public'), 2,
  'the owner sees the cache rows as written');
select is((select count(*)::int from app.holiday_feed where starts_on <= '2026-12-31'), 3,
  'every cache row starts in the window');

select * from finish();
rollback;
