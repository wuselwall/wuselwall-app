begin;
select plan(62);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

-- Named things of the test: profiles and households (ids), and devices (devs).
create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;
create temp table snap (k text primary key, v text);
grant all on snap to public;

-- Switches to the device's Auth user, as PostgREST would with its JWT.
create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- ---- household A: Papa (guardian, personal phone), Emma (child), Paul (member) -------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into app.profile (household_id, display_name, role, kind)
  select (r ->> 'household_id')::uuid, 'Emma', 'member', 'child' from sa;
insert into app.profile (household_id, display_name, role)
  select (r ->> 'household_id')::uuid, 'Paul', 'member' from sa;
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

-- ---- household B, made by hand (setup closes after the first household) ----------------------
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into users select 'b', app.create_auth_user('b@example.org', 'longpassword1');
insert into app.profile (household_id, display_name, role, auth_user_id)
  select (select id from ids where name = 'hh_b'), 'B', 'guardian', usr from users where name = 'b';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (select id from ids where name = 'hh_b'), u.usr, 'B-Phone', 'personal', 'adult', p.id
    from users u join app.profile p on p.auth_user_id = u.usr where u.name = 'b';
insert into devs
  select 'b', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id
   where u.name = 'b';

-- ---- the default calendar ------------------------------------------------------------------------
select is((select count(*)::int from app.calendar c
            where c.household_id = (select id from ids where name = 'hh_a')
              and c.name = 'Familie' and c.colour_hex = '#2D6A4F'), 1,
  'a new household gets its default calendar, Familie, in the household colour');
select is((select count(*)::int from app.calendar where household_id = (select id from ids where name = 'hh_b')), 1,
  'every new household gets exactly one default calendar');

-- ---- Papa, guardian on a personal phone ------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from api.calendars), 1, 'a household reads its own calendar only');

-- A timed event with two attendees. Emma sorts before Paul (sort order 20, 30).
insert into ids select 'e1', (api.event_save(null, jsonb_build_object(
  'title', 'Turnen', 'location', 'TSV-Halle', 'kind', 'appointment', 'is_all_day', false,
  'starts_at', '2026-10-14T14:00:00+02:00', 'ends_at', '2026-10-14T15:00:00+02:00',
  'attendee_ids', jsonb_build_array((select id from ids where name = 'paul'), (select id from ids where name = 'emma'))
  )) ->> 'id')::uuid;
select is((select attendee_ids from api.events where id = (select id from ids where name = 'e1')),
  array[(select id from ids where name = 'emma'), (select id from ids where name = 'paul')],
  'a timed event with two attendees comes back with them in sort order');
select is((select starts_at from api.events where id = (select id from ids where name = 'e1')),
  '2026-10-14T14:00:00+02:00'::timestamptz, 'a timed event keeps its instants');

-- Importance: no attendees is the whole family (key); one of three is normal.
insert into ids select 'e_key', (api.event_save(null, jsonb_build_object(
  'title', 'Muell raus', 'kind', 'appointment', 'is_all_day', true,
  'start_date', '2026-10-15', 'end_date', '2026-10-15')) ->> 'id')::uuid;
select is((select importance from api.events where id = (select id from ids where name = 'e_key')), 'key',
  'an event without attendees is key under the whole-family default');
insert into ids select 'e_one', (api.event_save(null, jsonb_build_object(
  'title', 'Paul liest', 'kind', 'appointment', 'is_all_day', true,
  'start_date', '2026-10-16', 'end_date', '2026-10-16',
  'attendee_ids', jsonb_build_array((select id from ids where name = 'paul')))) ->> 'id')::uuid;
select is((select importance from api.events where id = (select id from ids where name = 'e_one')), 'normal',
  'one attendee of several is not key');

-- Update: the same id, the uid stays, the sequence goes up.
insert into snap select 'uid', uid from api.events where id = (select id from ids where name = 'e1');
select lives_ok($$ select api.event_save(null, jsonb_build_object(
  'id', (select id from ids where name = 'e1'), 'title', 'Turnen in der Halle', 'location', 'TSV-Halle',
  'kind', 'appointment', 'is_all_day', false,
  'starts_at', '2026-10-14T14:00:00+02:00', 'ends_at', '2026-10-14T15:00:00+02:00',
  'attendee_ids', jsonb_build_array((select id from ids where name = 'paul'), (select id from ids where name = 'emma'))
  )) $$, 'a guardian updates an event by its id');
select is((select uid from api.events where id = (select id from ids where name = 'e1')),
  (select v from snap where k = 'uid'), 'an update keeps the uid');
select is((select sequence from api.events where id = (select id from ids where name = 'e1')), 1,
  'an update bumps the sequence');

-- Validation.
select throws_ok($$ select api.event_save(null, '{"title":"Ende vor Anfang","kind":"appointment","is_all_day":true,
  "start_date":"2026-10-20","end_date":"2026-10-19"}'::jsonb) $$,
  '22023', 'WW-CAL-001 invalid event', 'an all-day event that ends before it starts is refused');
select throws_ok($$ select api.event_save(null, '{"title":"Ohne Zustand","kind":"presence","is_all_day":true,
  "start_date":"2026-10-20","end_date":"2026-10-20"}'::jsonb) $$,
  '22023', 'WW-CAL-001 invalid event', 'a presence entry without a state is refused');
select throws_ok($$ select api.event_save(null, '{"title":"Presence mit Zustand","kind":"appointment","presence_state":"travel",
  "is_all_day":true,"start_date":"2026-10-20","end_date":"2026-10-20"}'::jsonb) $$,
  '22023', 'WW-CAL-001 invalid event', 'an appointment cannot carry a presence state');
select throws_ok($$ select api.event_save(null, '{"title":"Stunden","kind":"appointment","is_all_day":false,
  "starts_at":"2026-10-20T10:00:00Z","ends_at":"2026-10-20T09:00:00Z"}'::jsonb) $$,
  '22023', 'WW-CAL-001 invalid event', 'a timed event must end after it starts');
select throws_ok($$ select api.event_save(null, '{"title":"   ","kind":"appointment","is_all_day":true,
  "start_date":"2026-10-20","end_date":"2026-10-20"}'::jsonb) $$,
  '22023', 'WW-CAL-001 invalid event', 'a title is required');
select throws_ok($$ select api.event_save(null, '{"title":"Hourly","kind":"appointment","is_all_day":false,
  "starts_at":"2026-10-20T10:00:00Z","ends_at":"2026-10-20T11:00:00Z","rrule":"FREQ=HOURLY"}'::jsonb) $$,
  '22023', 'WW-CAL-002 rrule invalid', 'an rrule outside the supported subset is refused');
select throws_ok($$ select api.event_save(null, '{"title":"Zweimal","kind":"appointment","is_all_day":false,
  "starts_at":"2026-10-20T10:00:00Z","ends_at":"2026-10-20T11:00:00Z","rrule":"FREQ=WEEKLY;COUNT=3;UNTIL=20270701"}'::jsonb) $$,
  '22023', 'WW-CAL-002 rrule invalid', 'an rrule with both COUNT and UNTIL is refused');
select throws_ok($$ select api.event_save(null, '{"title":"Unbekannt","kind":"appointment","is_all_day":true,
  "start_date":"2026-10-20","end_date":"2026-10-20","attendee_ids":["00000000-0000-4000-8000-000000000000"]}'::jsonb) $$,
  '22023', 'WW-CAL-003 attendee invalid', 'an attendee outside the household is refused');
select throws_ok($$ select api.event_save(null, '{"title":"Zeitzone","kind":"appointment","is_all_day":true,
  "start_date":"2026-10-20","end_date":"2026-10-20","timezone":"Mars/Olympus"}'::jsonb) $$,
  '22023', 'WW-CAL-001 invalid event', 'an unknown time zone is refused');

-- A valid series and a rota with rdates and exdates.
insert into ids select 'e_rule', (api.event_save(null, jsonb_build_object(
  'title', 'Schwimmen', 'kind', 'appointment', 'is_all_day', false,
  'starts_at', '2026-10-12T07:00:00+02:00', 'ends_at', '2026-10-12T08:00:00+02:00',
  'rrule', 'FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20270701',
  'attendee_ids', jsonb_build_array((select id from ids where name = 'emma')))) ->> 'id')::uuid;
select is((select rrule from api.events where id = (select id from ids where name = 'e_rule')),
  'FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20270701', 'a supported rrule is stored as written');

insert into ids select 'e_rota', (api.event_save(null, jsonb_build_object(
  'title', 'Homeoffice nach Plan', 'kind', 'presence', 'presence_state', 'home_office', 'is_all_day', true,
  'start_date', '2026-10-14', 'end_date', '2026-10-14',
  'rdates', jsonb_build_array('2026-10-14', '2026-10-21'), 'exdates', jsonb_build_array('2026-10-28'),
  'attendee_ids', jsonb_build_array((select id from ids where name = 'papa')))) ->> 'id')::uuid;
select is((select rdates from api.events where id = (select id from ids where name = 'e_rota')),
  array['2026-10-14', '2026-10-21']::date[], 'rdates come back as the dates that were saved');
select is((select exdates from api.events where id = (select id from ids where name = 'e_rota')),
  array['2026-10-28']::date[], 'exdates come back as the dates that were saved');

-- Overrides: save, replace, delete.
select lives_ok($$ select api.event_override_save(null, (select id from ids where name = 'e_rule'),
  '2026-10-14T05:00:00Z', false, '{"title":"Schwimmen verschoben","starts_at":"2026-10-14T06:00:00Z","ends_at":"2026-10-14T07:00:00Z"}'::jsonb) $$,
  'a guardian saves a modified occurrence');
select lives_ok($$ select api.event_override_save(null, (select id from ids where name = 'e_rule'),
  '2026-10-21T05:00:00Z', true, '{}'::jsonb) $$, 'a guardian cancels one occurrence');
select is((select title from api.event_overrides where event_id = (select id from ids where name = 'e_rule')
             and recurrence_id = '2026-10-14T05:00:00Z'), 'Schwimmen verschoben',
  'the override shows its title');
select is((select is_cancelled from api.event_overrides where event_id = (select id from ids where name = 'e_rule')
             and recurrence_id = '2026-10-21T05:00:00Z'), true, 'the cancelled occurrence is listed as cancelled');
select lives_ok($$ select api.event_override_delete(null, (select id from ids where name = 'e_rule'),
  '2026-10-14T05:00:00Z') $$, 'a guardian removes an override');
select is((select count(*)::int from api.event_overrides where event_id = (select id from ids where name = 'e_rule')), 1,
  'only the removed override is gone');
select throws_ok($$ select api.event_override_save(null, (select id from ids where name = 'e1'),
  '2026-10-14T12:00:00Z', false, '{"title":"Einzeln"}'::jsonb) $$,
  '22023', 'WW-CAL-001 invalid event', 'a single event has no occurrences to override');

-- Soft delete hides the event.
select lives_ok($$ select api.event_delete(null, (select id from ids where name = 'e_one')) $$,
  'a guardian deletes an event');
select is((select count(*)::int from api.events where id = (select id from ids where name = 'e_one')), 0,
  'a deleted event disappears from the calendar');

-- Busy until: set, then cleared with null.
select lives_ok($$ select api.busy_until_set(null, (select id from ids where name = 'emma'), '2026-10-14', '17:00') $$,
  'a guardian sets a busy-until time for a child');
select is((select until from api.busy_until where profile_id = (select id from ids where name = 'emma')
             and on_date = '2026-10-14'), '17:00'::time, 'the busy-until time is listed');
select lives_ok($$ select api.busy_until_set(null, (select id from ids where name = 'emma'), '2026-10-14', null) $$,
  'a null time clears the busy-until entry');
select is((select count(*)::int from api.busy_until where profile_id = (select id from ids where name = 'emma')), 0,
  'the cleared entry is gone');
select lives_ok($$ select api.busy_until_set(null, (select id from ids where name = 'paul'), '2026-10-15', '12:00') $$,
  'a busy-until entry for another member is set');

-- Baseline: set, then cleared.
select lives_ok($$ select api.member_baseline_set(null, (select id from ids where name = 'paul'), 'travel', 'Reise') $$,
  'a guardian sets a member''s usual presence');
select is((select default_presence_state from api.members where id = (select id from ids where name = 'paul')),
  'travel', 'the usual presence is on the member');
select lives_ok($$ select api.member_baseline_set(null, (select id from ids where name = 'paul'), null, null) $$,
  'a null state clears the usual presence');
select is((select default_presence_state from api.members where id = (select id from ids where name = 'paul')),
  null::text, 'the cleared usual presence is gone');

-- ---- a member on the shared iPad -----------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('ipad');
select lives_ok($$ insert into ids select 'e_kid', (api.event_save(
  (select id from ids where name = 'emma'), jsonb_build_object(
  'title', 'Lesen', 'kind', 'appointment', 'is_all_day', true,
  'start_date', '2026-10-17', 'end_date', '2026-10-17',
  'attendee_ids', jsonb_build_array((select id from ids where name = 'emma')))) ->> 'id')::uuid $$,
  'a member saves an event she attends');
select throws_ok($$ select api.event_save((select id from ids where name = 'emma'), jsonb_build_object(
  'title', 'Nur Paul', 'kind', 'appointment', 'is_all_day', true,
  'start_date', '2026-10-18', 'end_date', '2026-10-18',
  'attendee_ids', jsonb_build_array((select id from ids where name = 'paul')))) $$,
  '42501', 'guardian required', 'a member cannot save an event she does not attend');
select lives_ok($$ select api.event_save((select id from ids where name = 'emma'), jsonb_build_object(
  'id', (select id from ids where name = 'e1'), 'title', 'Turnen (Emma)', 'kind', 'appointment', 'is_all_day', false,
  'starts_at', '2026-10-14T14:00:00+02:00', 'ends_at', '2026-10-14T15:00:00+02:00',
  'attendee_ids', jsonb_build_array((select id from ids where name = 'paul'), (select id from ids where name = 'emma')))) $$,
  'a member updates an event she attends');
select throws_ok($$ select api.event_delete((select id from ids where name = 'emma'), (select id from ids where name = 'e1')) $$,
  '42501', 'guardian required', 'a member cannot delete an event with two attendees');
select lives_ok($$ select api.event_delete((select id from ids where name = 'emma'), (select id from ids where name = 'e_kid')) $$,
  'a member deletes her own event with no one else attending');
select throws_ok($$ select api.busy_until_set((select id from ids where name = 'emma'), (select id from ids where name = 'paul'),
  '2026-10-15', '12:00') $$, '42501', 'guardian required', 'a member sets only her own busy-until time');

-- ---- Papa switches member editing off ------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.set_setting(null, 'calendar.members_edit_own_events', 'false') $$,
  'a guardian switches off member editing of own events');
reset role;
select pg_temp.act_as_dev('ipad');
select throws_ok($$ select api.event_save((select id from ids where name = 'emma'), jsonb_build_object(
  'title', 'Verboten', 'kind', 'appointment', 'is_all_day', true,
  'start_date', '2026-10-19', 'end_date', '2026-10-19',
  'attendee_ids', jsonb_build_array((select id from ids where name = 'emma')))) $$,
  '42501', 'guardian required', 'with editing switched off a member cannot save even her own event');

-- ---- a kiosk never writes ------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('kiosk');
select throws_ok($$ select api.event_save((select id from ids where name = 'papa'), jsonb_build_object(
  'title', 'Kiosk', 'kind', 'appointment', 'is_all_day', true,
  'start_date', '2026-10-20', 'end_date', '2026-10-20')) $$,
  '42501', 'not allowed on a kiosk', 'a kiosk device cannot save events');

-- ---- household B sees and touches nothing of A ---------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from api.event_overrides), 1, 'the guardian sees the override that remains');
select is((select count(*)::int from api.busy_until), 1, 'the guardian sees the busy-until entry she set');
reset role;
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.events), 0, 'another household sees none of the events');
select is((select count(*)::int from api.event_overrides), 0, 'another household sees none of the overrides');
select is((select count(*)::int from api.busy_until), 0, 'another household sees none of the busy-until entries');
select is((select count(*)::int from api.calendars), 1, 'another household sees only its own calendar');
select throws_ok($$ select api.event_save(null, jsonb_build_object(
  'id', (select id from ids where name = 'e1'), 'title', 'Fremd', 'kind', 'appointment', 'is_all_day', true,
  'start_date', '2026-10-14', 'end_date', '2026-10-14')) $$,
  'P0002', 'event not found', 'another household cannot update an event by its id');
select throws_ok($$ select api.busy_until_set(null, (select id from ids where name = 'emma'), '2026-10-14', '17:00') $$,
  'P0002', 'profile not found', 'another household cannot set busy-until for a member of another');

-- ---- a revoked phone ----------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('old');
select is((select count(*)::int from api.events), 0, 'a revoked phone reads no events');
select throws_ok($$ select api.event_save(null, '{"title":"Alt","kind":"appointment","is_all_day":true,
  "start_date":"2026-10-20","end_date":"2026-10-20"}'::jsonb) $$,
  '42501', 'device not usable', 'a revoked phone cannot save an event');

-- ---- anonymous callers ----------------------------------------------------------------------------
reset role;
set local role anon;
select throws_ok('select count(*) from api.events', '42501', 'permission denied for view events',
  'anonymous callers cannot read events');
select throws_ok($$ select api.event_save(null, '{}'::jsonb) $$, '42501', 'permission denied for function event_save',
  'anonymous callers cannot save events');
reset role;

-- ---- the owner's view: audit ------------------------------------------------------------------------
select ok(exists (select 1 from app.audit_log where entity_type = 'event' and action = 'create'
                  and household_id = (select id from ids where name = 'hh_a')),
  'event writes are audited');

select * from finish();
rollback;
