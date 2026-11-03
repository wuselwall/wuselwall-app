begin;
select plan(94);

-- The fetch attempt record, the backoff and the recurrence check of
-- migrations/20261102130000_calendar_import_attempt.sql (security review 2026-11-01, F6). Start
-- from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
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
-- Runs one statement as the service role (the calendar-import Edge Function) and comes back.
create function pg_temp.svc(p_sql text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  execute 'set local role service_role';
  execute p_sql;
  execute 'reset role';
end $$;
create function pg_temp.svc_json(p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  execute 'set local role service_role';
  execute p_sql into v;
  execute 'reset role';
  return v;
end $$;
-- The ids api.external_calendar_due answers, in its order.
create function pg_temp.due_ids() returns jsonb language sql as $$
  select pg_temp.svc_json($q$ select jsonb_agg(e ->> 'id') from jsonb_array_elements(api.external_calendar_due(20)) e $q$)
$$;
create function pg_temp.pid(p_name text) returns uuid language sql as $$
  select id from ids where name = p_name
$$;
create function pg_temp.cid(p_name text) returns uuid language sql as $$
  select id from cal where name = p_name
$$;

-- ---- household A: Papa (guardian, personal phone) ----------------------------------------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', p.id from app.profile p where p.household_id = pg_temp.pid('hh_a');
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.pid('hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = pg_temp.pid('papa');
insert into devs
  select 'papa', d.auth_user_id, d.id, d.household_id, 'personal' from app.device d where d.label = 'A-Phone';

-- ---- the recurrence check ---------------------------------------------------------------------
select ok(app.rrule_valid(r), 'rrule_valid accepts ' || r) from unnest(array[
  'FREQ=DAILY', 'FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20270701', 'FREQ=WEEKLY;INTERVAL=2;BYDAY=SA',
  'FREQ=MONTHLY;BYMONTHDAY=31', 'FREQ=MONTHLY;BYDAY=-1FR', 'FREQ=MONTHLY;BYDAY=MO;BYSETPOS=5',
  'FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29', 'FREQ=DAILY;BYMONTH=2;BYMONTHDAY=29',
  'FREQ=MONTHLY;BYMONTH=2,3;BYMONTHDAY=31', 'FREQ=WEEKLY;BYDAY=MO,TU;BYSETPOS=2',
  'FREQ=YEARLY;BYMONTH=1,2;BYDAY=1MO;BYSETPOS=2', 'FREQ=DAILY;INTERVAL=999;COUNT=9999',
  'FREQ=YEARLY;BYMONTH=1,7;BYSETPOS=2', 'FREQ=MONTHLY;BYDAY=MO,1MO', 'FREQ=YEARLY;BYDAY=MO,TU,-1TU',
  'FREQ=YEARLY;BYDAY=20MO', 'FREQ=YEARLY;BYDAY=53MO,-53MO', 'FREQ=MONTHLY;BYDAY=+2TU,-1FR'
]) as r;
select ok(not app.rrule_valid(r), 'rrule_valid refuses ' || r) from unnest(array[
  'FREQ=DAILY;BYMONTH=2;BYMONTHDAY=30', 'FREQ=DAILY;BYMONTH=2;BYMONTHDAY=31',
  'FREQ=MONTHLY;BYMONTH=4,6,9,11;BYMONTHDAY=31', 'FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=-30',
  'FREQ=MONTHLY;BYDAY=MO,1TU', 'FREQ=WEEKLY;BYDAY=1MO', 'FREQ=WEEKLY;BYDAY=MO;BYSETPOS=2',
  'FREQ=DAILY;BYSETPOS=-2', 'FREQ=MONTHLY;BYDAY=MO;BYSETPOS=6', 'FREQ=MONTHLY;BYSETPOS=2',
  'FREQ=DAILY;COUNT=0', 'FREQ=DAILY;INTERVAL=1000', 'FREQ=DAILY;COUNT=10000',
  'FREQ=DAILY;BYMONTHDAY=0', 'FREQ=DAILY;BYMONTH=13', 'FREQ=DAILY;UNTIL=20261399',
  'FREQ=WEEKLY;COUNT=3;UNTIL=20270701', 'FREQ=HOURLY', 'FREQ=DAILY;FREQ=WEEKLY', '',
  'FREQ=MONTHLY;BYDAY=-MO', 'FREQ=MONTHLY;BYDAY=0MO', 'FREQ=MONTHLY;BYDAY=6MO', 'FREQ=YEARLY;BYDAY=54MO',
  'FREQ=YEARLY;BYMONTH=1,7;BYSETPOS=3', 'FREQ=MONTHLY;BYDAY=MO,TU,1WE'
]) as r;
select ok(not app.rrule_valid(null), 'rrule_valid refuses null');

-- Events: the rule, the start and UNTIL are checked whichever function writes the row.
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.event_save(null, '{"title":"Gift","kind":"appointment","is_all_day":false,
  "starts_at":"2026-10-20T10:00:00Z","ends_at":"2026-10-20T11:00:00Z","rrule":"FREQ=DAILY;BYMONTH=2;BYMONTHDAY=30"}'::jsonb) $$,
  '22023', 'WW-CAL-002 rrule invalid', 'an event with a rule that can never match is refused');
select throws_ok($$ select api.event_save(null, '{"title":"Vorbei","kind":"appointment","is_all_day":true,
  "start_date":"2026-10-20","end_date":"2026-10-20","rrule":"FREQ=WEEKLY;UNTIL=20261019"}'::jsonb) $$,
  '22023', 'WW-CAL-002 rrule invalid', 'an UNTIL before the start is refused');
select throws_ok($$ select api.event_save(null, '{"title":"Uralt","kind":"appointment","is_all_day":true,
  "start_date":"1899-12-31","end_date":"1899-12-31","rrule":"FREQ=YEARLY"}'::jsonb) $$,
  '22023', 'WW-CAL-002 rrule invalid', 'a series starting before 1900 is refused');
select lives_ok($$ select api.event_save(null, '{"title":"Uralt ohne Regel","kind":"appointment","is_all_day":true,
  "start_date":"1899-12-31","end_date":"1899-12-31"}'::jsonb) $$,
  'a single event before 1900 is still allowed');
insert into ids select 'e_ok', (api.event_save(null, jsonb_build_object(
  'title', 'Schwimmen', 'kind', 'appointment', 'is_all_day', false,
  'starts_at', '2026-10-12T07:00:00+02:00', 'ends_at', '2026-10-12T08:00:00+02:00',
  'rrule', 'FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261012')) ->> 'id')::uuid;
select is((select rrule from api.events where id = pg_temp.pid('e_ok')),
  'FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261012', 'an UNTIL on the start day is fine');
reset role;
select throws_ok($$ update app.event set rrule = 'FREQ=MONTHLY;BYDAY=MO,1TU' where id = pg_temp.pid('e_ok') $$,
  '22023', 'WW-CAL-002 rrule invalid', 'the trigger refuses a direct write as well');

-- A row stored before the migration with a rule the check refuses: reported, not blocking.
alter table app.event disable trigger event_rrule_check;
update app.event set rrule = 'FREQ=DAILY;BYMONTH=2;BYMONTHDAY=30' where id = pg_temp.pid('e_ok');
alter table app.event enable trigger event_rrule_check;
select is((select events from app.rrule_invalid_rows() where household_id = pg_temp.pid('hh_a')), 1,
  'a stored event with a rule the check refuses is counted for its household');
select lives_ok($$ do $n$ declare r record; begin
    for r in select * from app.rrule_invalid_rows() loop raise notice 'household %: % %', r.household_id, r.events, r.chores; end loop;
  end $n$ $$, 'the migration''s notice over such rows runs without an error');
select lives_ok($$ update app.event set title = 'Schwimmen neu' where id = pg_temp.pid('e_ok') $$,
  'such a row can still be changed where the rule is not written');
select pg_temp.act_as_dev('papa');
select is((select rrule from api.events where id = pg_temp.pid('e_ok')), 'FREQ=DAILY;BYMONTH=2;BYMONTHDAY=30',
  'and it still shows');
reset role;
update app.event set rrule = 'FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261012' where id = pg_temp.pid('e_ok');
select is((select count(*)::int from app.rrule_invalid_rows()), 0, 'a corrected rule leaves nothing to report');

-- Chores the same way.
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.task_definition_save(null, '{"title":"Gift","rrule":"FREQ=DAILY;BYMONTH=2;BYMONTHDAY=30",
  "assignment":"open"}'::jsonb) $$, '22023', 'WW-TSK-001 task invalid', 'a chore with a rule that can never match is refused');
select throws_ok($$ select api.task_definition_save(null, '{"title":"Vorbei","rrule":"FREQ=WEEKLY;UNTIL=20200101",
  "assignment":"open","starts_on":"2026-10-01"}'::jsonb) $$, '22023', 'WW-TSK-001 task invalid',
  'a chore whose UNTIL is before its start is refused');
select lives_ok($$ select api.task_definition_save(null, '{"title":"Tisch","rrule":"FREQ=WEEKLY;BYDAY=SA",
  "assignment":"open","starts_on":"2026-10-01"}'::jsonb) $$, 'a usual chore is saved');
reset role;

-- ---- the attempt record ------------------------------------------------------------------------
insert into app.external_calendar (household_id, name, url, colour_hex)
  values (pg_temp.pid('hh_a'), 'Club', 'https://club.example.org/a.ics', '#336699'),
         (pg_temp.pid('hh_a'), 'Bins', 'https://bins.example.org/b.ics', '#336699'),
         (pg_temp.pid('hh_a'), 'School', 'https://school.example.org/c.ics', '#336699');
insert into cal select lower(name), id from app.external_calendar;
update app.external_calendar set last_fetched_at = now() - interval '3 hours' where id = pg_temp.cid('club');
update app.external_calendar set last_fetched_at = now() - interval '2 hours' where id = pg_temp.cid('bins');
select is((select last_attempt_at from app.external_calendar where id = pg_temp.cid('club')), null::timestamptz,
  'a calendar from before the migration carries no attempt yet');

select pg_temp.act_as_dev('papa');
select throws_like($$ select api.external_calendar_begin(pg_temp.cid('club')) $$, '%permission denied%',
  'a guardian cannot record an attempt');
select is((select consecutive_failures from api.external_calendars where id = pg_temp.cid('club')), 0,
  'the view carries consecutive_failures');
select ok((select last_attempt_at is null from api.external_calendars where id = pg_temp.cid('club')),
  'the view carries last_attempt_at');
reset role;

select is(pg_temp.due_ids(),
  jsonb_build_array(pg_temp.cid('school')::text, pg_temp.cid('club')::text, pg_temp.cid('bins')::text),
  'due: never attempted first, then the oldest result');

select lives_ok($$ select pg_temp.svc($q$ select api.external_calendar_begin(pg_temp.cid('club')) $q$) $$, 'the service role records an attempt');
select ok((select last_attempt_at > now() - interval '1 minute' from app.external_calendar where id = pg_temp.cid('club')),
  'begin sets last_attempt_at');
select ok((select last_fetched_at < now() - interval '2 hours' from app.external_calendar where id = pg_temp.cid('club')),
  'begin leaves last_fetched_at alone');
select is((select consecutive_failures from app.external_calendar where id = pg_temp.cid('club')), 0,
  'a first attempt is not a failure');
select is(pg_temp.due_ids(),
  jsonb_build_array(pg_temp.cid('school')::text, pg_temp.cid('bins')::text),
  'a calendar attempted just now is not due, whatever its last result');
select is(pg_temp.svc_json($q$ select api.external_calendar_get(pg_temp.cid('club')) $q$) ->> 'consecutive_failures', '0',
  'get carries consecutive_failures');
select ok((pg_temp.svc_json($q$ select api.external_calendar_get(pg_temp.cid('club')) $q$) ->> 'last_attempt_at') is not null,
  'get carries last_attempt_at');

-- The worker died: nothing concluded the attempt. The next begin counts it.
update app.external_calendar set last_attempt_at = now() - interval '1 hour' where id = pg_temp.cid('club');
select is(pg_temp.due_ids(),
  jsonb_build_array(pg_temp.cid('school')::text, pg_temp.cid('bins')::text, pg_temp.cid('club')::text),
  'an attempt older than 55 minutes is due again, after the others');
select lives_ok($$ select pg_temp.svc($q$ select api.external_calendar_begin(pg_temp.cid('club')) $q$) $$, 'the next attempt begins');
select is((select consecutive_failures from app.external_calendar where id = pg_temp.cid('club')), 1,
  'an attempt that never concluded counts as a failure');
select is((select last_error from app.external_calendar where id = pg_temp.cid('club')), 'interrupted',
  'and is reported as interrupted');

-- A failure that was reported counts once; a success ends the run.
select lives_ok($$ select pg_temp.svc($q$ select api.external_calendar_fail(pg_temp.cid('club'), 'http_503') $q$) $$, 'a failure is recorded');
select is((select consecutive_failures from app.external_calendar where id = pg_temp.cid('club')), 2,
  'fail counts the failure');
select lives_ok($$ select pg_temp.svc($q$ select api.external_calendar_begin(pg_temp.cid('club')) $q$) $$, 'a concluded attempt is followed by a new one');
select is((select consecutive_failures from app.external_calendar where id = pg_temp.cid('club')), 2,
  'a concluded attempt is not counted again');
select is((select last_error from app.external_calendar where id = pg_temp.cid('club')), 'http_503',
  'and its result stays');
select lives_ok($$ select pg_temp.svc($q$ select api.external_calendar_store(pg_temp.cid('club'),
  '[{"uid":"a","starts_at":"2026-10-20T16:00:00Z","ends_at":"2026-10-20T17:00:00Z","all_day":false,"title":"Spiel"}]', null) $q$) $$,
  'a fetch succeeds');
select is((select consecutive_failures from app.external_calendar where id = pg_temp.cid('club')), 0,
  'store ends the run of failures');
select lives_ok($$ select pg_temp.svc($q$ select api.external_calendar_begin(pg_temp.cid('club')) $q$) $$, 'an attempt after a success');
select lives_ok($$ select pg_temp.svc($q$ select api.external_calendar_not_modified(pg_temp.cid('club')) $q$) $$, 'a not-modified answer');
select is((select consecutive_failures from app.external_calendar where id = pg_temp.cid('club')), 0,
  'not_modified keeps the run at zero');

-- The backoff: three failures wait six hours, six wait a day.
update app.external_calendar set consecutive_failures = 3, last_attempt_at = now() - interval '2 hours',
       last_fetched_at = now() - interval '2 hours' where id = pg_temp.cid('club');
select is((select count(*)::int from jsonb_array_elements(coalesce(pg_temp.due_ids(), '[]'::jsonb)) e where e #>> '{}' = pg_temp.cid('club')::text), 0,
  'after three failures a calendar attempted two hours ago is not due');
update app.external_calendar set last_attempt_at = now() - interval '7 hours', last_fetched_at = now() - interval '7 hours'
 where id = pg_temp.cid('club');
select is((select count(*)::int from jsonb_array_elements(coalesce(pg_temp.due_ids(), '[]'::jsonb)) e where e #>> '{}' = pg_temp.cid('club')::text), 1,
  'after three failures a calendar attempted seven hours ago is due');
update app.external_calendar set consecutive_failures = 6 where id = pg_temp.cid('club');
select is((select count(*)::int from jsonb_array_elements(coalesce(pg_temp.due_ids(), '[]'::jsonb)) e where e #>> '{}' = pg_temp.cid('club')::text), 0,
  'after six failures a calendar attempted seven hours ago is not due');
update app.external_calendar set last_attempt_at = now() - interval '25 hours', last_fetched_at = now() - interval '25 hours'
 where id = pg_temp.cid('club');
select is((select count(*)::int from jsonb_array_elements(coalesce(pg_temp.due_ids(), '[]'::jsonb)) e where e #>> '{}' = pg_temp.cid('club')::text), 1,
  'after six failures a calendar attempted a day ago is due');
update app.external_calendar set consecutive_failures = 2, last_attempt_at = now() - interval '2 hours',
       last_fetched_at = now() - interval '2 hours' where id = pg_temp.cid('club');
select is((select count(*)::int from jsonb_array_elements(coalesce(pg_temp.due_ids(), '[]'::jsonb)) e where e #>> '{}' = pg_temp.cid('club')::text), 1,
  'two failures do not hold a calendar back');

-- The guardian's "fetch now" reads the attempt, and a new URL forgets the old feed's record.
update app.external_calendar set consecutive_failures = 4, last_attempt_at = now() - interval '2 minutes'
 where id = pg_temp.cid('club');
select pg_temp.act_as_dev('papa');
select ok((api.external_calendar_refresh_request(pg_temp.pid('papa'), pg_temp.cid('club')) ->> 'last_attempt_at')::timestamptz
          > now() - interval '3 minutes', 'refresh_request carries last_attempt_at');
select is(api.external_calendar_refresh_request(pg_temp.pid('papa'), pg_temp.cid('club')) ->> 'consecutive_failures', '4',
  'refresh_request carries consecutive_failures');
select lives_ok($$ select api.external_calendar_save(pg_temp.pid('papa'),
  jsonb_build_object('id', pg_temp.cid('club'), 'url', 'https://club.example.org/neu.ics')) $$, 'a new URL is saved');
reset role;
select ok((select last_attempt_at is null and consecutive_failures = 0 from app.external_calendar where id = pg_temp.cid('club')),
  'a new URL clears the attempt record');

select * from finish();
rollback;
