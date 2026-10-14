begin;
select plan(69);

-- Imported external calendars (migrations/20261014150000_external_calendars.sql). Start from an
-- empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

-- Named things of the test: profiles and households (ids), devices (devs), calendars (cal).
create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;
create temp table cal (name text primary key, id uuid);
grant all on cal to public;

-- Switches to the device's Auth user, as PostgREST would with its JWT.
create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function pg_temp.pid(p_name text) returns uuid language sql as $$
  select id from ids where name = p_name
$$;

-- ---- household A: Papa (guardian, personal phone), Lotta (child), Hanna, iPad, kiosk, revoked phone
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into app.profile (household_id, display_name, role, kind)
  select (r ->> 'household_id')::uuid, 'Lotta', 'member', 'child' from sa;
insert into app.profile (household_id, display_name, role)
  select (r ->> 'household_id')::uuid, 'Hanna', 'member' from sa;
insert into ids select lower(p.display_name), p.id from app.profile p
 where p.household_id = (select id from ids where name = 'hh_a');

insert into users values
  ('ipad', app.create_auth_user('ipad@devices.invalid', 'x1234567890')),
  ('kiosk', app.create_auth_user('kiosk@devices.invalid', 'x1234567890')),
  ('old', app.create_auth_user('old@example.org', 'longpassword1'));

insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (select id from ids where name = 'hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = (select id from ids where name = 'papa');
insert into app.device (household_id, auth_user_id, label, class, register)
  select (select id from ids where name = 'hh_a'), usr, 'iPad', 'shared', 'kid' from users where name = 'ipad';
insert into app.device (household_id, auth_user_id, label, class, register)
  select (select id from ids where name = 'hh_a'), usr, 'Kiosk', 'kiosk', 'kiosk' from users where name = 'kiosk';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  select (select id from ids where name = 'hh_a'), usr, 'Old-Phone', 'personal', 'adult',
         (select id from ids where name = 'papa'), now()
    from users where name = 'old';

insert into devs
  select 'papa', d.auth_user_id, d.id, d.household_id, 'personal' from app.device d where d.label = 'A-Phone'
  union all
  select 'ipad', u.usr, d.id, d.household_id, 'shared' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'ipad'
  union all
  select 'kiosk', u.usr, d.id, d.household_id, 'kiosk' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'kiosk'
  union all
  select 'old', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'old';

-- ---- household B: a guardian of its own -------------------------------------------------------
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into users select 'b', app.create_auth_user('b@example.org', 'longpassword1');
insert into app.profile (household_id, display_name, role, auth_user_id)
  select (select id from ids where name = 'hh_b'), 'B', 'guardian', usr from users where name = 'b';
insert into ids select 'b_profile', p.id from app.profile p where p.household_id = (select id from ids where name = 'hh_b');
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (select id from ids where name = 'hh_b'), u.usr, 'B-Phone', 'personal', 'adult', p.id
    from users u join app.profile p on p.auth_user_id = u.usr where u.name = 'b';
insert into devs
  select 'b', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id
   where u.name = 'b';

-- ---- guardian writes ----------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
select pg_temp.act_as_dev('papa');
insert into cal select 'club', (api.external_calendar_save(pg_temp.pid('papa'),
  jsonb_build_object('name', 'Fussball', 'url', 'https://club.example.org/fixtures.ics',
                     'colour_hex', '#1E88E5', 'member_ids', jsonb_build_array(pg_temp.pid('lotta'))))->>'id')::uuid;
reset role;
select is((select count(*)::int from cal), 1, 'a guardian creates an imported calendar and gets its id back');

select pg_temp.act_as_dev('papa');
insert into cal select 'bins', (api.external_calendar_save(pg_temp.pid('papa'),
  '{"name":"Abfall","url":"WEBCAL://bins.example.ch/abfall.ics","colour_hex":"#6D4C41","show_on_board":true}'::jsonb)->>'id')::uuid;
reset role;
select is((select url from app.external_calendar where id = (select id from cal where name = 'bins')),
  'https://bins.example.ch/abfall.ics', 'a webcal:// URL is stored as https://');
select is((select member_ids from app.external_calendar where id = (select id from cal where name = 'bins')),
  '{}'::uuid[], 'member_ids that are not sent are empty: the whole family');
select is((select show_on_board from app.external_calendar where id = (select id from cal where name = 'bins')),
  true, 'show_on_board is stored');
select is((select active from app.external_calendar where id = (select id from cal where name = 'bins')),
  true, 'a new calendar is active');

select is((select member_ids from app.external_calendar where id = (select id from cal where name = 'club')),
  array[pg_temp.pid('lotta')], 'member_ids are stored as given');
select is((select last_fetched_at from app.external_calendar where id = (select id from cal where name = 'club')),
  null::timestamptz, 'a new calendar has not been fetched yet');

-- Update: name and colour change, the URL does not, so the occurrences stay.
insert into app.external_occurrence (calendar_id, household_id, uid, starts_at, ends_at, all_day, title)
  select id, household_id, 'match-1', '2026-10-20T16:00:00Z', '2026-10-20T17:30:00Z', false, 'Spiel'
    from app.external_calendar where id = (select id from cal where name = 'club');
update app.external_calendar set last_fetched_at = now(), etag = '"v1"', last_error = 'http_503'
 where id = (select id from cal where name = 'club');

select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.external_calendar_save(pg_temp.pid('papa'),
  jsonb_build_object('id', (select id from cal where name = 'club'), 'name', 'Fussball Junioren', 'colour_hex', '#3949AB')) $$,
  'a guardian renames an imported calendar and keeps its URL');
reset role;
select is((select name from app.external_calendar where id = (select id from cal where name = 'club')),
  'Fussball Junioren', 'the update changes the name');
select is((select count(*)::int from app.external_occurrence where calendar_id = (select id from cal where name = 'club')),
  1, 'an update without a new URL keeps the occurrences');
select is((select etag from app.external_calendar where id = (select id from cal where name = 'club')),
  '"v1"', 'an update without a new URL keeps the etag');
select is((select member_ids from app.external_calendar where id = (select id from cal where name = 'club')),
  array[pg_temp.pid('lotta')], 'an update without member_ids keeps them');

-- Update: a new URL clears the occurrences, the etag and the fetch record.
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.external_calendar_save(pg_temp.pid('papa'),
  jsonb_build_object('id', (select id from cal where name = 'club'), 'url', 'https://club.example.org/neu.ics')) $$,
  'a new URL is accepted');
reset role;
select is((select count(*)::int from app.external_occurrence where calendar_id = (select id from cal where name = 'club')),
  0, 'changing the URL clears the occurrences');
select ok((select last_fetched_at is null and etag is null and last_error is null from app.external_calendar
            where id = (select id from cal where name = 'club')),
  'changing the URL clears last_fetched_at, etag and last_error');

-- Refusals, all as the guardian.
select pg_temp.act_as_dev('papa');
select throws_like($$ select api.external_calendar_save(pg_temp.pid('papa'), '{"name":"X","url":"http://insecure.example.org/a.ics"}') $$,
  '%WW-CAL-006%', 'a non-https URL is refused');
select throws_like($$ select api.external_calendar_save(pg_temp.pid('papa'), '{"name":"X","url":"ftp://a.example.org/a.ics"}') $$,
  '%WW-CAL-006%', 'an ftp URL is refused');
select throws_like($$ select api.external_calendar_save(pg_temp.pid('papa'), '{"name":"X","url":"https://a.example.org/a b.ics"}') $$,
  '%WW-CAL-006%', 'a URL with a space is refused');
select throws_like($$ select api.external_calendar_save(pg_temp.pid('papa'), ('{"name":"X","url":"https://a.example.org/' || repeat('x', 1000) || '"}')::jsonb) $$,
  '%WW-CAL-006%', 'a URL over 1000 characters is refused');
select throws_like($$ select api.external_calendar_save(pg_temp.pid('papa'), '{"name":"   ","url":"https://a.example.org/a.ics"}') $$,
  '%WW-CAL-005%', 'a blank name is refused');
select throws_like($$ select api.external_calendar_save(pg_temp.pid('papa'), '{"name":"X","url":"https://a.example.org/a.ics","colour_hex":"blue"}') $$,
  '%WW-CAL-005%', 'a colour that is not #RRGGBB is refused');
select throws_like($$ select api.external_calendar_save(pg_temp.pid('papa'), ('{"name":"X","url":"https://a.example.org/a.ics","member_ids":["' || pg_temp.pid('b_profile') || '"]}')::jsonb) $$,
  '%WW-CAL-003%', 'a member of another household is refused');
select throws_like($$ select api.external_calendar_save(pg_temp.pid('papa'), '{"name":"X","url":"https://a.example.org/a.ics","member_ids":["not-a-uuid"]}') $$,
  '%WW-CAL-003%', 'a member id that is not a uuid is refused');
select throws_like($$ select api.external_calendar_save(pg_temp.pid('papa'), '{"name":"X","url":"https://a.example.org/a.ics","show_on_board":"yes"}') $$,
  '%WW-CAL-005%', 'a flag that is not a boolean is refused');
reset role;

-- Members, children and kiosks write nothing.
select pg_temp.act_as_dev('ipad');
select throws_like($$ select api.external_calendar_save(pg_temp.pid('lotta'), '{"name":"Lotta","url":"https://a.example.org/a.ics"}') $$,
  '%guardian required%', 'a child on the shared iPad cannot create an imported calendar');
select throws_like($$ select api.external_calendar_delete(pg_temp.pid('lotta'), (select id from cal where name = 'bins')) $$,
  '%guardian required%', 'a child cannot delete an imported calendar');
select throws_like($$ select api.external_calendar_refresh_request(pg_temp.pid('lotta'), (select id from cal where name = 'bins')) $$,
  '%guardian required%', 'a child cannot ask for an on-demand fetch');
reset role;

select pg_temp.act_as_dev('kiosk');
select throws_like($$ select api.external_calendar_save(pg_temp.pid('papa'), '{"name":"Kiosk","url":"https://a.example.org/a.ics"}') $$,
  '%not allowed on a kiosk%', 'a kiosk cannot create an imported calendar');
reset role;

-- Cross-household: household B's guardian sees and changes nothing of household A.
select pg_temp.act_as_dev('b');
select throws_like($$ select api.external_calendar_save(pg_temp.pid('b_profile'), jsonb_build_object('id', (select id from cal where name = 'bins'), 'name', 'Fremd')) $$,
  '%external calendar not found%', 'another household cannot update a calendar');
select throws_like($$ select api.external_calendar_delete(pg_temp.pid('b_profile'), (select id from cal where name = 'bins')) $$,
  '%external calendar not found%', 'another household cannot delete a calendar');
select throws_like($$ select api.external_calendar_refresh_request(pg_temp.pid('b_profile'), (select id from cal where name = 'bins')) $$,
  '%external calendar not found%', 'another household cannot ask for a fetch');
select is((select count(*)::int from api.external_calendars), 0, 'another household reads no imported calendar');
select is((select count(*)::int from api.external_occurrences), 0, 'another household reads no imported occurrence');
reset role;

-- Reads: a live device of the household reads; a revoked device and the anon role read nothing.
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from api.external_calendars), 2, 'a guardian reads the household calendars');
select is((select count(*)::int from api.external_calendars where url like 'https://%'), 2,
  'the calendars are https');
select ok(not exists (select 1 from information_schema.columns
                       where table_schema = 'api' and table_name = 'external_calendars' and column_name = 'etag'),
  'the api view does not expose the etag');
reset role;

select pg_temp.act_as_dev('old');
select is((select count(*)::int from api.external_calendars), 0, 'a revoked device reads no imported calendar');
select is((select count(*)::int from api.external_occurrences), 0, 'a revoked device reads no imported occurrence');
reset role;

select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_like($$ select count(*) from api.external_calendars $$, '%permission denied%',
  'anon reads no imported calendar');
select throws_like($$ select count(*) from api.external_occurrences $$, '%permission denied%',
  'anon reads no imported occurrence');
reset role;
select throws_like($$ select api.external_calendar_save(null, '{"name":"X","url":"https://a.example.org/a.ics"}') $$,
  '%device not usable%', 'an unauthenticated write is refused');

-- Occurrences of an active calendar are read; an inactive one hides them.
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from api.external_occurrences), 0,
  'a URL change leaves no occurrence of the old feed to read');
reset role;
insert into app.external_occurrence (calendar_id, household_id, uid, starts_at, ends_at, all_day, title)
  select id, household_id, 'bin-1', '2026-10-15T06:00:00Z', '2026-10-15T07:00:00Z', false, 'Papier'
    from app.external_calendar where id = (select id from cal where name = 'bins');
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from api.external_occurrences where calendar_name = 'Abfall'), 1,
  'a guardian reads the occurrences of an active calendar');
reset role;

-- Deletion: a guardian deletes, the occurrences go with the calendar.
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.external_calendar_delete(pg_temp.pid('papa'), (select id from cal where name = 'club')) $$,
  'a guardian deletes an imported calendar');
select throws_like($$ select api.external_calendar_delete(pg_temp.pid('papa'), (select id from cal where name = 'club')) $$,
  '%external calendar not found%', 'a deleted calendar is not found again');
reset role;
select is((select count(*)::int from app.external_calendar where id = (select id from cal where name = 'club')), 0,
  'the deleted calendar is gone');

-- ---- the fetch job (service role only) -----------------------------------------------------------
-- Authenticated callers are refused before the function runs.
select pg_temp.act_as_dev('papa');
select throws_like($$ select api.external_calendar_due(5) $$, '%permission denied%',
  'an authenticated guardian cannot call the fetch job functions');
select throws_like($$ select api.external_calendar_get((select id from cal where name = 'bins')) $$, '%permission denied%',
  'an authenticated caller cannot read the fetch details');
select throws_like($$ select api.external_calendar_store((select id from cal where name = 'bins'), '[]', null) $$,
  '%permission denied%', 'an authenticated caller cannot store occurrences');
reset role;

-- The service role; the functions also refuse a token that is not the service role's.
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
set local role service_role;
select throws_like($$ select api.external_calendar_due(5) $$, '%service role required%',
  'the service role grant refuses a non-service JWT');
reset role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;

select is(jsonb_array_length(api.external_calendar_due(20)), 1,
  'the fetch job is due for the one active calendar that was never fetched');
select is(api.external_calendar_due(20) -> 0 ->> 'id', (select id::text from cal where name = 'bins'),
  'the due row carries the calendar id');
select is(api.external_calendar_due(20) -> 0 ->> 'timezone', 'Europe/Berlin',
  'the due row carries the household timezone');
select is(api.external_calendar_get((select id from cal where name = 'bins')) ->> 'url',
  'https://bins.example.ch/abfall.ics', 'the fetch details carry the url');
select throws_like($$ select api.external_calendar_get('00000000-0000-0000-0000-000000000000') $$,
  '%external calendar not found%', 'an unknown calendar has no fetch details');

select is(api.external_calendar_store((select id from cal where name = 'bins'),
  '[{"uid":"a@x","starts_at":"2026-10-15T06:00:00Z","ends_at":"2026-10-15T07:00:00Z","all_day":false,"title":"Papier","location":null},
    {"uid":"b@x","starts_at":null,"ends_at":null,"all_day":true,"start_date":"2026-10-16","end_date":"2026-10-16","title":"Restmüll"}]'::jsonb,
  '"etag-1"'), 2, 'store writes the rows and returns their count');

-- The checks below read the app tables, which the service role may not: the owner reads.
reset role;
select is((select count(*)::int from app.external_occurrence where calendar_id = (select id from cal where name = 'bins')), 2,
  'store replaces the occurrences: the old row is gone, two remain');
select is((select count(*)::int from app.external_occurrence where calendar_id = (select id from cal where name = 'bins') and uid = 'bin-1'), 0,
  'the occurrence the feed no longer has is removed');
select is((select etag from app.external_calendar where id = (select id from cal where name = 'bins')), '"etag-1"',
  'store keeps the etag');
select ok((select last_fetched_at is not null and last_error is null from app.external_calendar
            where id = (select id from cal where name = 'bins')),
  'store sets last_fetched_at and clears last_error');
set local role service_role;
select is(jsonb_array_length(api.external_calendar_due(20)), 0, 'a fresh calendar is not due');

select lives_ok($$ select api.external_calendar_fail((select id from cal where name = 'bins'), 'http_404') $$,
  'a failed fetch is recorded');
reset role;
select is((select last_error from app.external_calendar where id = (select id from cal where name = 'bins')),
  'http_404', 'the failure code is stored');
select is((select count(*)::int from app.external_occurrence where calendar_id = (select id from cal where name = 'bins')), 2,
  'a failed fetch keeps the stored occurrences');
set local role service_role;

select lives_ok($$ select api.external_calendar_not_modified((select id from cal where name = 'bins')) $$,
  'a not-modified answer is recorded');
reset role;
select is((select last_error from app.external_calendar where id = (select id from cal where name = 'bins')), null,
  'a not-modified answer clears last_error');
update app.external_calendar set last_fetched_at = now() - interval '2 hours' where id = (select id from cal where name = 'bins');
set local role service_role;
select is(jsonb_array_length(api.external_calendar_due(20)), 1, 'a calendar fetched two hours ago is due again');
reset role;
update app.external_calendar set active = false where id = (select id from cal where name = 'bins');
set local role service_role;
select is(jsonb_array_length(api.external_calendar_due(20)), 0, 'an inactive calendar is not fetched');
reset role;

-- Inactive calendars show no occurrences to the household.
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from api.external_occurrences), 0, 'an inactive calendar shows no occurrences');
reset role;

select * from finish();
rollback;
