begin;
select plan(161);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

-- Named things of the test: profiles, households, definitions, instances, redemptions (ids);
-- devices (devs); auth users (users); the days the test uses (dt).
create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;
create temp table dt (k text primary key, d date);
grant all on dt to public;
insert into dt values
  ('today', (now() at time zone 'Europe/Berlin')::date),
  ('tomorrow', (now() at time zone 'Europe/Berlin')::date + 1),
  ('today2', (now() at time zone 'Europe/Berlin')::date + 2),
  ('today20', (now() at time zone 'Europe/Berlin')::date + 20);

-- Switches to the device's Auth user, as PostgREST would with its JWT.
create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- The service role, as the Edge Functions call the system jobs.
create function pg_temp.act_as_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  perform set_config('role', 'service_role', true);
end $$;

-- A named id of the test.
create function pg_temp.id(p_name text) returns uuid language sql stable as $$
  select i.id from ids i where i.name = p_name
$$;

-- ---- household A: Papa (guardian, personal phone), Lotta and Hanna; B by hand ----------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;
insert into app.profile (household_id, display_name, role, kind)
  select (r ->> 'household_id')::uuid, 'Lotta', 'member', 'child' from sa;
insert into app.profile (household_id, display_name, role)
  select (r ->> 'household_id')::uuid, 'Hanna', 'member' from sa;
insert into ids select lower(p.display_name), p.id from app.profile p
 where p.household_id = (select id from ids where name = 'hh_a') and p.display_name in ('Lotta', 'Hanna');

insert into users values
  ('papa', (select auth_user_id from app.profile where id = (select id from ids where name = 'papa'))),
  ('ipad', app.create_auth_user('ipad@devices.invalid', 'x1234567890')),
  ('kiosk', app.create_auth_user('kiosk@devices.invalid', 'x1234567890')),
  ('old', app.create_auth_user('old@example.org', 'longpassword1')),
  ('b', app.create_auth_user('b@example.org', 'longpassword1'));

insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.id('hh_a'), usr, 'A-Phone', 'personal', 'adult', pg_temp.id('papa') from users where name = 'papa';
insert into app.device (household_id, auth_user_id, label, class, register)
  select pg_temp.id('hh_a'), usr, 'iPad', 'shared', 'kid' from users where name = 'ipad';
insert into app.device (household_id, auth_user_id, label, class, register)
  select pg_temp.id('hh_a'), usr, 'Kiosk', 'kiosk', 'kiosk' from users where name = 'kiosk';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  select pg_temp.id('hh_a'), usr, 'Old-Phone', 'personal', 'adult', pg_temp.id('papa'), now()
    from users where name = 'old';

insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_b'), 'B', 'guardian', usr from users where name = 'b';
insert into ids select 'b', p.id from app.profile p where p.household_id = pg_temp.id('hh_b');
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.id('hh_b'), usr, 'B-Phone', 'personal', 'adult', pg_temp.id('b') from users where name = 'b';

insert into devs
  select 'papa', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'papa'
  union all
  select 'ipad', u.usr, d.id, d.household_id, 'shared' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'ipad'
  union all
  select 'kiosk', u.usr, d.id, d.household_id, 'kiosk' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'kiosk'
  union all
  select 'old', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'old'
  union all
  select 'b', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'b';

-- The badges the nightly close awards (created directly: the API has no badge editor yet).
insert into app.badge_definition (household_id, key, title, rule) values
  (pg_temp.id('hh_a'), 'erste_aufgabe', 'Erste Aufgabe', '{"type":"first_task"}'),
  (pg_temp.id('hh_a'), 'streak3', 'Drei am Stück', '{"type":"streak_reached","length":3,"points":10}'),
  (pg_temp.id('hh_a'), 'total2', 'Zwei Aufgaben', '{"type":"total_tasks","count":2}');

-- ---- definitions: defaults, validation -------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');

insert into ids select 'd_tisch', (api.task_definition_save(null, ('{"title":"Tisch decken","rrule":"FREQ=DAILY",
  "assignment":"fixed","assignee_profile_ids":["' || pg_temp.id('lotta') || '"]}')::jsonb) ->> 'id')::uuid;
insert into ids select 'd_rot', (api.task_definition_save(null, jsonb_build_object('title', 'Spülmaschine',
  'kind', 'bonus', 'points', 3, 'rrule', 'FREQ=DAILY', 'assignment', 'rotating', 'requires_verification', true,
  'assignee_profile_ids', jsonb_build_array(pg_temp.id('lotta'), pg_temp.id('hanna')))) ->> 'id')::uuid;
insert into ids select 'd_muell', (api.task_definition_save(null, '{"title":"Müll rausbringen","kind":"bonus",
  "rrule":"FREQ=WEEKLY","assignment":"open"}'::jsonb) ->> 'id')::uuid;
insert into ids select 'd_zimmer', (api.task_definition_save(null, jsonb_build_object('title', 'Zimmer aufräumen',
  'points', 2, 'rrule', 'FREQ=WEEKLY;BYDAY=SA', 'assignment', 'each',
  'assignee_profile_ids', jsonb_build_array(pg_temp.id('lotta'), pg_temp.id('hanna')))) ->> 'id')::uuid;
insert into ids select 'd_fenster', (api.task_definition_save(null, jsonb_build_object('title', 'Fenster putzen',
  'points', 2, 'assignment', 'fixed', 'assignee_profile_ids', jsonb_build_array(pg_temp.id('hanna')))) ->> 'id')::uuid;

select is((select kind from api.task_definitions where id = pg_temp.id('d_tisch')), 'duty',
  'a chore without a kind is a duty, the household default');
select is((select points from api.task_definitions where id = pg_temp.id('d_tisch')), 1,
  'a duty without points takes the duty default of one point');
select is((select requires_verification from api.task_definitions where id = pg_temp.id('d_tisch')), false,
  'verification is off by default');
select is((select points from api.task_definitions where id = pg_temp.id('d_muell')), 5,
  'a bonus without points takes the bonus default of five');
select is((select starts_on from api.task_definitions where id = pg_temp.id('d_tisch')), (select d from dt where k = 'today'),
  'a definition starts today in the household zone when no start is given');
select is((select count(*)::int from api.task_instances where definition_id = pg_temp.id('d_fenster')
             and due_on = (select d from dt where k = 'today') and assigned_profile_id = pg_temp.id('hanna')), 1,
  'a one-off definition creates its instance at once, for its assignee');

select throws_ok($$ select api.task_definition_save(null, '{"title":"","assignment":"open"}'::jsonb) $$,
  '22023', 'WW-TSK-001 task invalid', 'a task needs a title');
select throws_ok($$ select api.task_definition_save(null, '{"title":"X","kind":"weird","assignment":"open"}'::jsonb) $$,
  '22023', 'WW-TSK-001 task invalid', 'the kind is duty or bonus');
select throws_ok($$ select api.task_definition_save(null, jsonb_build_object('title', 'Zwei', 'assignment', 'fixed',
  'assignee_profile_ids', jsonb_build_array(pg_temp.id('lotta'), pg_temp.id('hanna')))) $$,
  '22023', 'WW-TSK-001 task invalid', 'a fixed task has exactly one assignee');
select throws_ok($$ select api.task_definition_save(null, '{"title":"Keiner","assignment":"rotating",
  "rrule":"FREQ=DAILY","assignee_profile_ids":[]}'::jsonb) $$,
  '22023', 'WW-TSK-001 task invalid', 'a rotation needs at least one member');
select throws_ok($$ select api.task_definition_save(null, jsonb_build_object('title', 'Leer', 'assignment', 'each',
  'rrule', 'FREQ=DAILY')) $$, '22023', 'WW-TSK-001 task invalid', 'each needs at least one member');
select throws_ok($$ select api.task_definition_save(null, '{"title":"Minus","points":-1,"assignment":"open"}'::jsonb) $$,
  '22023', 'WW-TSK-001 task invalid', 'points are never negative');
select throws_ok($$ select api.task_definition_save(null, '{"title":"Lang","window_days":15,"assignment":"open"}'::jsonb) $$,
  '22023', 'WW-TSK-001 task invalid', 'a window is at most fourteen days');
select throws_ok($$ select api.task_definition_save(null, '{"title":"Stündlich","assignment":"open",
  "rrule":"FREQ=HOURLY"}'::jsonb) $$, '22023', 'WW-TSK-001 task invalid', 'an rrule outside the subset is refused');
select throws_ok($$ select api.task_definition_save(null, jsonb_build_object('title', 'Fremd', 'assignment', 'fixed',
  'assignee_profile_ids', jsonb_build_array(pg_temp.id('b')))) $$,
  '22023', 'WW-TSK-001 task invalid', 'an assignee of another household is refused');
select throws_ok($$ select api.task_definition_save(null, '{"title":"Wer","assignment":"random"}'::jsonb) $$,
  '22023', 'WW-TSK-001 task invalid', 'an unknown assignment is refused');

-- ---- materialise as the household, idempotent, rotation ----------------------------------------
select is((select (api.tasks_materialise(pg_temp.id('hh_a'), jsonb_build_array(
  jsonb_build_object('definition_id', pg_temp.id('d_tisch'), 'due_on', (select d from dt where k = 'today')),
  jsonb_build_object('definition_id', pg_temp.id('d_rot'), 'due_on', (select d from dt where k = 'today')),
  jsonb_build_object('definition_id', pg_temp.id('d_rot'), 'due_on', (select d from dt where k = 'tomorrow')),
  jsonb_build_object('definition_id', pg_temp.id('d_zimmer'), 'due_on', (select d from dt where k = 'today')),
  jsonb_build_object('definition_id', pg_temp.id('d_muell'), 'due_on', (select d from dt where k = 'today'))
  )) ->> 'created')::int), 6, 'materialising a fixed, a rotating (two days), an each and an open task creates six instances');
select is((select rotation_cursor from api.task_definitions where id = pg_temp.id('d_rot')), 2,
  'the rotation moves one member per new due day');
select is((select assigned_profile_id from api.task_instances where definition_id = pg_temp.id('d_rot')
             and due_on = (select d from dt where k = 'today')), pg_temp.id('lotta'),
  'the first day of the rotation goes to the first member of the pool');
select is((select assigned_profile_id from api.task_instances where definition_id = pg_temp.id('d_rot')
             and due_on = (select d from dt where k = 'tomorrow')), pg_temp.id('hanna'),
  'the second day goes to the second member');
select is((select (api.tasks_materialise(pg_temp.id('hh_a'), jsonb_build_array(
  jsonb_build_object('definition_id', pg_temp.id('d_rot'), 'due_on', (select d from dt where k = 'today')),
  jsonb_build_object('definition_id', pg_temp.id('d_rot'), 'due_on', (select d from dt where k = 'tomorrow')),
  jsonb_build_object('definition_id', pg_temp.id('d_tisch'), 'due_on', (select d from dt where k = 'today'))
  )) ->> 'created')::int), 0, 'a re-run creates nothing');
select is((select rotation_cursor from api.task_definitions where id = pg_temp.id('d_rot')), 2,
  'a re-run does not move the rotation on');
select is((select (api.tasks_materialise(pg_temp.id('hh_a'), jsonb_build_array(
  jsonb_build_object('definition_id', pg_temp.id('d_tisch'), 'due_on', (select d from dt where k = 'today20'))
  )) ->> 'created')::int), 0, 'due days beyond today plus fourteen are ignored');
select throws_ok($$ select api.tasks_materialise(pg_temp.id('hh_b'), '[]'::jsonb) $$,
  '42501', 'WW-TSK-002 task not yours', 'a member cannot materialise another household');

-- ---- the instances, by name -----------------------------------------------------------------------
insert into ids select 'i_tisch', id from app.task_instance where definition_id = pg_temp.id('d_tisch')
  and due_on = (select d from dt where k = 'today');
insert into ids select 'i_rot_today', id from app.task_instance where definition_id = pg_temp.id('d_rot')
  and due_on = (select d from dt where k = 'today');
insert into ids select 'i_rot_tomorrow', id from app.task_instance where definition_id = pg_temp.id('d_rot')
  and due_on = (select d from dt where k = 'tomorrow');
insert into ids select 'i_zimmer_l', id from app.task_instance where definition_id = pg_temp.id('d_zimmer')
  and assigned_profile_id = pg_temp.id('lotta') and due_on = (select d from dt where k = 'today');
insert into ids select 'i_zimmer_h', id from app.task_instance where definition_id = pg_temp.id('d_zimmer')
  and assigned_profile_id = pg_temp.id('hanna') and due_on = (select d from dt where k = 'today');
insert into ids select 'i_muell', id from app.task_instance where definition_id = pg_temp.id('d_muell');
insert into ids select 'i_fenster', id from app.task_instance where definition_id = pg_temp.id('d_fenster');

-- ---- service role: the system jobs --------------------------------------------------------------------
reset role;
select pg_temp.act_as_service();
select is(jsonb_array_length(api.tasks_schedule_all()), 2, 'the service role gets the schedule of every household');
select is((select count(*)::int from jsonb_array_elements(api.tasks_schedule_all()) x,
             jsonb_array_elements(x -> 'definitions') dd where x ->> 'household_id' = pg_temp.id('hh_a')::text), 4,
  'the schedule lists the four active recurring definitions and not the one-off');
select is((select (api.tasks_materialise(pg_temp.id('hh_a'), jsonb_build_array(
  jsonb_build_object('definition_id', pg_temp.id('d_rot'), 'due_on', (select d from dt where k = 'today2'))
  )) ->> 'created')::int), 1, 'the service role materialises for any household');
select is((select (api.tasks_materialise(pg_temp.id('hh_b'), '[]'::jsonb) ->> 'created')::int), 0,
  'the service role may materialise an empty list for another household');
reset role;
select is((select rotation_cursor from app.task_definition where id = pg_temp.id('d_rot')), 3,
  'the rotation goes on across the horizon');

reset role;
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.tasks_schedule_all() $$, '42501', 'permission denied for function tasks_schedule_all',
  'members cannot read every household''s schedule');
select throws_ok($$ select api.tasks_close_day(pg_temp.id('hh_a'), current_date) $$, '42501',
  'permission denied for function tasks_close_day', 'members cannot close a day');
select is((select jsonb_array_length(api.tasks_schedule() -> 'definitions')), 4,
  'a household reads its own schedule');

-- ---- completing: the iPad (shared device) acts as Lotta, then as Hanna --------------------------------
reset role;
select pg_temp.act_as_dev('ipad');
select is((api.task_complete(pg_temp.id('lotta'), pg_temp.id('i_tisch')) ->> 'points_credited')::int, 1,
  'the assignee ticks a duty and is credited its points');
select is((select status from api.task_instances where id = pg_temp.id('i_tisch')), 'done',
  'a ticked task is done');
select is((api.task_complete(pg_temp.id('lotta'), pg_temp.id('i_tisch')) ->> 'points_credited')::int, 1,
  'a retried tick reports the credit it already holds');
select is((select count(*)::int from api.point_transactions where source_id = pg_temp.id('i_tisch')::text || ':1'), 1,
  'a retried tick does not credit a second time');
select is((select balance from api.point_balances where profile_id = pg_temp.id('lotta')), 1,
  'the balance is the sum of the ledger');
select throws_ok($$ select api.task_complete(pg_temp.id('hanna'), pg_temp.id('i_tisch')) $$, '42501',
  'WW-TSK-002 task not yours', 'a member cannot tick another member''s task');
select is((api.task_complete(pg_temp.id('hanna'), pg_temp.id('i_muell')) ->> 'points_credited')::int, 5,
  'an open task is claimed by the member who ticks it, and credited');
select is((select assigned_profile_id from api.task_instances where id = pg_temp.id('i_muell')), pg_temp.id('hanna'),
  'the claimed open task now belongs to Hanna');
select is((api.task_complete(pg_temp.id('lotta'), pg_temp.id('i_rot_today')) ->> 'points_credited')::int, 0,
  'a task that needs verification is not credited on the tick');
select is((select status from api.task_instances where id = pg_temp.id('i_rot_today')), 'done',
  'a task awaiting verification is done');
select is((select balance from api.point_balances where profile_id = pg_temp.id('lotta')), 1,
  'the points of an unverified task are held back');

-- Verification: approve credits; reject returns the task to open.
reset role;
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.task_verify(null, pg_temp.id('i_rot_tomorrow'), true) $$, '22023',
  'WW-TSK-005 task not open', 'a task that is not done cannot be verified');
select lives_ok($$ select api.task_verify(null, pg_temp.id('i_rot_today'), true) $$, 'a guardian approves a verification');
select is((select status from api.task_instances where id = pg_temp.id('i_rot_today')), 'verified',
  'an approved task is verified');
select is((select balance from api.point_balances where profile_id = pg_temp.id('lotta')), 4,
  'approval credits the points of the task');

-- Undo: the completer may take a tick back the same day; the credit goes with it.
reset role;
select pg_temp.act_as_dev('ipad');
select is((api.task_complete(pg_temp.id('hanna'), pg_temp.id('i_fenster')) ->> 'points_credited')::int, 2,
  'Hanna ticks the one-off task');
select is((select balance from api.point_balances where profile_id = pg_temp.id('hanna')), 7,
  'Hanna has the open task and the one-off task credited');
select throws_ok($$ select api.task_undo(pg_temp.id('lotta'), pg_temp.id('i_fenster')) $$, '42501',
  'WW-TSK-002 task not yours', 'another member cannot take back a tick');
select lives_ok($$ select api.task_undo(pg_temp.id('hanna'), pg_temp.id('i_fenster')) $$,
  'the completer takes the tick back the same day');
select is((select status from api.task_instances where id = pg_temp.id('i_fenster')), 'open',
  'an undone task is open again');
select is((select balance from api.point_balances where profile_id = pg_temp.id('hanna')), 5,
  'the undo reverses the credit');
select is((api.task_complete(pg_temp.id('hanna'), pg_temp.id('i_fenster')) ->> 'points_credited')::int, 2,
  'ticking again credits again');
select is((select balance from api.point_balances where profile_id = pg_temp.id('hanna')), 7,
  'the balance is right after the second tick');

-- A kiosk with an acting child may tick: the wall's own mutation.
reset role;
select pg_temp.act_as_dev('kiosk');
select is((api.task_complete(pg_temp.id('lotta'), pg_temp.id('i_zimmer_l')) ->> 'points_credited')::int, 2,
  'a kiosk with an acting child ticks a task and credits the child');
select is((select balance from api.point_balances where profile_id = pg_temp.id('lotta')), 6,
  'Lotta has the kiosk credit');
select is((select sum(balance)::int from api.point_balances), 13, 'the balances of the household add up');
select is((select count(*)::int from api.point_balances), 3, 'every active member has a balance row');

-- ---- adjustments ---------------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.points_adjust(null, pg_temp.id('hanna'), -100, 'Strafe') $$, '22023',
  'WW-TSK-003 balance insufficient', 'an adjustment may not push the balance below zero');
select throws_ok($$ select api.points_adjust(null, pg_temp.id('hanna'), 5, '   ') $$, '22023',
  'WW-TSK-001 task invalid', 'an adjustment needs a note');
select lives_ok($$ select api.points_adjust(null, pg_temp.id('hanna'), 10, 'Extra für den Garten') $$,
  'a guardian adjusts a balance with a note');
select lives_ok($$ select api.points_adjust(null, pg_temp.id('hanna'), -17, 'Korrektur') $$,
  'a guardian takes the points back');
select is((select balance from api.point_balances where profile_id = pg_temp.id('hanna')), 0,
  'a corrected balance is right');
select throws_ok($$ select api.points_adjust(null, pg_temp.id('hanna'), -1, 'Zu viel') $$, '22023',
  'WW-TSK-003 balance insufficient', 'a balance of zero cannot go lower');

-- A guardian's action on the shared iPad needs the PIN window (specs/08).
reset role;
select pg_temp.act_as_dev('ipad');
select throws_ok($$ select api.points_adjust(pg_temp.id('papa'), pg_temp.id('lotta'), 1, 'ohne PIN') $$, '42501',
  'guardian required', 'a guardian on the shared device without the PIN cannot adjust');
select is((select (api.guardian_verify_pin(pg_temp.id('papa'), '123456') ->> 'ok')::boolean), true,
  'the guardian enters the PIN on the shared device');
select lives_ok($$ select api.points_adjust(pg_temp.id('papa'), pg_temp.id('lotta'), 1, 'Nachtrag') $$,
  'with the PIN window the guardian adjusts on the shared device');
select is((select balance from api.point_balances where profile_id = pg_temp.id('lotta')), 7,
  'Lotta has the adjustment');

-- The ledger is append-only (the owner included).
reset role;
select throws_ok($$ update app.point_transaction set note = note $$, '42501', 'point ledger is append-only',
  'the ledger refuses an update');

-- ---- rewards ---------------------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
insert into ids select 'r_film', (api.reward_save(null, '{"title":"Samstagsfilm aussuchen","cost_points":5}'::jsonb) ->> 'id')::uuid;
insert into ids select 'r_late', (api.reward_save(null, '{"title":"15 Minuten länger aufbleiben","cost_points":15,
  "requires_approval":false}'::jsonb) ->> 'id')::uuid;
insert into ids select 'r_zero', (api.reward_save(null, '{"title":"Nur wenn Vorrat da ist","cost_points":1,"stock":0}'::jsonb) ->> 'id')::uuid;
insert into ids select 'r_eis', (api.reward_save(null, '{"title":"Eis","cost_points":2,"stock":1,
  "requires_approval":false}'::jsonb) ->> 'id')::uuid;
select is((select requires_approval from api.rewards where id = pg_temp.id('r_film')), true,
  'a reward needs approval by default');
select is((select requires_approval from api.rewards where id = pg_temp.id('r_eis')), false,
  'a reward can be self-served');
select throws_ok($$ select api.reward_save(null, '{"title":"Gratis","cost_points":0}'::jsonb) $$, '22023',
  'WW-TSK-001 task invalid', 'a reward costs at least one point');

reset role;
select pg_temp.act_as_dev('ipad');
insert into ids select 'rq_film', (api.reward_request(pg_temp.id('lotta'), pg_temp.id('r_film')) ->> 'id')::uuid;
select is((select status from api.reward_redemptions where id = pg_temp.id('rq_film')), 'requested',
  'a reward that needs approval waits as requested');
select is((select balance from api.point_balances where profile_id = pg_temp.id('lotta')), 7,
  'a request does not debit the balance');
insert into ids select 'rq_late', (api.reward_request(pg_temp.id('lotta'), pg_temp.id('r_late')) ->> 'id')::uuid;
select is((select status from api.reward_redemptions where id = pg_temp.id('rq_late')), 'requested',
  'without the points a self-served reward waits too');
insert into ids select 'rq_zero', (api.reward_request(pg_temp.id('lotta'), pg_temp.id('r_zero')) ->> 'id')::uuid;
insert into ids select 'rq_eis', (api.reward_request(pg_temp.id('lotta'), pg_temp.id('r_eis')) ->> 'id')::uuid;
select is((select status from api.reward_redemptions where id = pg_temp.id('rq_eis')), 'approved',
  'a self-served reward with points and stock is approved at once');
select is((select balance from api.point_balances where profile_id = pg_temp.id('lotta')), 5,
  'the self-served reward is debited at once');
select is((select stock from api.rewards where id = pg_temp.id('r_eis')), 0, 'the stock goes down with it');
insert into ids select 'rq_eis2', (api.reward_request(pg_temp.id('lotta'), pg_temp.id('r_eis')) ->> 'id')::uuid;
select is((select status from api.reward_redemptions where id = pg_temp.id('rq_eis2')), 'requested',
  'with the stock gone a self-served reward waits');
reset role;
select pg_temp.act_as_dev('kiosk');
select throws_ok($$ select api.reward_request(pg_temp.id('lotta'), pg_temp.id('r_film')) $$, '42501',
  'not allowed on a kiosk', 'a kiosk cannot request a reward');
reset role;
select pg_temp.act_as_dev('ipad');
insert into ids select 'rq_hanna', (api.reward_request(pg_temp.id('hanna'), pg_temp.id('r_film')) ->> 'id')::uuid;

reset role;
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.reward_decide(null, pg_temp.id('rq_zero'), true, null) $$, '22023',
  'WW-TSK-004 reward out of stock', 'approval revalidates the stock');
select lives_ok($$ select api.reward_decide(null, pg_temp.id('rq_film'), true, null) $$,
  'a guardian approves a reward the balance covers');
select is((select balance from api.point_balances where profile_id = pg_temp.id('lotta')), 0,
  'the approval debits the cost');
select is((select status from api.reward_redemptions where id = pg_temp.id('rq_film')), 'approved',
  'an approved reward is approved');
select lives_ok($$ select api.reward_decide(null, pg_temp.id('rq_late'), false, 'Nicht diese Woche') $$,
  'a guardian declines with a note');
select is((select note from api.reward_redemptions where id = pg_temp.id('rq_late')), 'Nicht diese Woche',
  'the decline keeps its note');
select is((select status from api.reward_redemptions where id = pg_temp.id('rq_late')), 'declined',
  'a declined request is declined');
select throws_ok($$ select api.reward_decide(null, pg_temp.id('rq_hanna'), true, null) $$, '22023',
  'WW-TSK-003 balance insufficient', 'approval revalidates the balance');
select is((select status from api.reward_redemptions where id = pg_temp.id('rq_hanna')), 'requested',
  'a refused approval leaves the request waiting');
select throws_ok($$ select api.reward_decide(null, pg_temp.id('rq_film'), true, null) $$, '22023',
  'WW-TSK-005 task not open', 'a decided request cannot be decided again');
select lives_ok($$ select api.reward_fulfil(null, pg_temp.id('rq_film')) $$, 'an approved reward is handed over');
select is((select status from api.reward_redemptions where id = pg_temp.id('rq_film')), 'fulfilled',
  'a handed-over reward is fulfilled');
select throws_ok($$ select api.reward_fulfil(null, pg_temp.id('rq_hanna')) $$, '22023',
  'WW-TSK-005 task not open', 'a waiting request cannot be fulfilled');

-- ---- streaks, jokers, the nightly close (September 2026, past days, deterministic) ---------------------
reset role;
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.set_setting(null, 'tasks.jokers_per_month', '2'::jsonb, pg_temp.id('hanna')) $$,
  'a guardian gives Hanna two jokers a month');
insert into ids select 'd_brot', (api.task_definition_save(null, jsonb_build_object('title', 'Brot holen',
  'rrule', 'FREQ=DAILY', 'assignment', 'fixed', 'assignee_profile_ids', jsonb_build_array(pg_temp.id('lotta')))) ->> 'id')::uuid;
insert into ids select 'd_hund', (api.task_definition_save(null, jsonb_build_object('title', 'Hund füttern',
  'rrule', 'FREQ=DAILY', 'assignment', 'fixed', 'assignee_profile_ids', jsonb_build_array(pg_temp.id('hanna')))) ->> 'id')::uuid;
insert into ids select 'd_vf', (api.task_definition_save(null, jsonb_build_object('title', 'Abtrocknen',
  'points', 2, 'requires_verification', true, 'rrule', 'FREQ=DAILY', 'assignment', 'fixed',
  'assignee_profile_ids', jsonb_build_array(pg_temp.id('lotta')))) ->> 'id')::uuid;
select is((select (api.tasks_materialise(pg_temp.id('hh_a'), jsonb_build_array(
  jsonb_build_object('definition_id', pg_temp.id('d_brot'), 'due_on', '2026-09-01'),
  jsonb_build_object('definition_id', pg_temp.id('d_brot'), 'due_on', '2026-09-02'),
  jsonb_build_object('definition_id', pg_temp.id('d_brot'), 'due_on', '2026-09-03'),
  jsonb_build_object('definition_id', pg_temp.id('d_brot'), 'due_on', '2026-09-04'),
  jsonb_build_object('definition_id', pg_temp.id('d_brot'), 'due_on', '2026-09-05'),
  jsonb_build_object('definition_id', pg_temp.id('d_brot'), 'due_on', '2026-09-06'),
  jsonb_build_object('definition_id', pg_temp.id('d_hund'), 'due_on', '2026-09-01'),
  jsonb_build_object('definition_id', pg_temp.id('d_hund'), 'due_on', '2026-09-02'),
  jsonb_build_object('definition_id', pg_temp.id('d_hund'), 'due_on', '2026-09-03'),
  jsonb_build_object('definition_id', pg_temp.id('d_hund'), 'due_on', '2026-09-04'),
  jsonb_build_object('definition_id', pg_temp.id('d_vf'), 'due_on', '2026-09-01')
  )) ->> 'created')::int), 11, 'the September days are materialised for the streak scenario');
reset role;
insert into ids select 'b_01', id from app.task_instance where definition_id = pg_temp.id('d_brot') and due_on = '2026-09-01';
insert into ids select 'b_02', id from app.task_instance where definition_id = pg_temp.id('d_brot') and due_on = '2026-09-02';
insert into ids select 'b_03', id from app.task_instance where definition_id = pg_temp.id('d_brot') and due_on = '2026-09-03';
insert into ids select 'b_04', id from app.task_instance where definition_id = pg_temp.id('d_brot') and due_on = '2026-09-04';
insert into ids select 'b_05', id from app.task_instance where definition_id = pg_temp.id('d_brot') and due_on = '2026-09-05';
insert into ids select 'b_06', id from app.task_instance where definition_id = pg_temp.id('d_brot') and due_on = '2026-09-06';
insert into ids select 'h_01', id from app.task_instance where definition_id = pg_temp.id('d_hund') and due_on = '2026-09-01';
insert into ids select 'h_02', id from app.task_instance where definition_id = pg_temp.id('d_hund') and due_on = '2026-09-02';
insert into ids select 'h_03', id from app.task_instance where definition_id = pg_temp.id('d_hund') and due_on = '2026-09-03';
insert into ids select 'h_04', id from app.task_instance where definition_id = pg_temp.id('d_hund') and due_on = '2026-09-04';
insert into ids select 'v_01', id from app.task_instance where definition_id = pg_temp.id('d_vf') and due_on = '2026-09-01';

reset role;
select pg_temp.act_as_dev('ipad');
select is((api.task_complete(pg_temp.id('lotta'), pg_temp.id('b_01')) ->> 'status'), 'done', 'Lotta ticks the bread on the first day');
select is((api.task_complete(pg_temp.id('hanna'), pg_temp.id('h_01')) ->> 'status'), 'done', 'Hanna feeds the dog on the first day');
select is((api.task_complete(pg_temp.id('lotta'), pg_temp.id('b_02')) ->> 'status'), 'done', 'Lotta ticks the bread on the second day');
select is((api.task_complete(pg_temp.id('lotta'), pg_temp.id('v_01')) ->> 'status'), 'done', 'the drying task is ticked and waits');
reset role;
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.task_verify(null, pg_temp.id('v_01'), false) $$, 'a guardian rejects the drying task');
select is((select status from api.task_instances where id = pg_temp.id('v_01')), 'open',
  'a rejected task is open again');
reset role;
select pg_temp.act_as_dev('ipad');
select is((api.task_complete(pg_temp.id('lotta'), pg_temp.id('v_01')) ->> 'status'), 'done', 'the drying task is ticked again');
reset role;
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.task_verify(null, pg_temp.id('v_01'), true) $$, 'a guardian approves the drying task');
select is((select balance from api.point_balances where profile_id = pg_temp.id('lotta')), 4,
  'the approved drying task credits its two points');

reset role;
select pg_temp.act_as_service();
select is((select (api.tasks_close_day(pg_temp.id('hh_a'), '2026-09-02') ->> 'expired')::int), 1,
  'closing the second day expires Hanna''s open dog task');
select is((select (api.tasks_close_day(pg_temp.id('hh_a'), '2026-09-02') ->> 'already_closed')::boolean), true,
  'the second run finds the day closed');
select is((select (api.tasks_close_day(pg_temp.id('hh_a'), '2026-09-02') ->> 'badges_awarded')::int), 0,
  'a closed day awards nothing again');
reset role;
select is((select current_length from api.streaks where profile_id = pg_temp.id('hanna')
             and definition_id = pg_temp.id('d_hund')), 1, 'a missed day with a joker keeps Hanna''s chain');

reset role;
select pg_temp.act_as_dev('ipad');
select is((api.task_complete(pg_temp.id('lotta'), pg_temp.id('b_03')) ->> 'status'), 'done', 'Lotta ticks the bread on the third day');
reset role;
select pg_temp.act_as_service();
select is((select (api.tasks_close_day(pg_temp.id('hh_a'), '2026-09-03') ->> 'expired')::int), 1,
  'closing the third day expires Hanna''s second dog task');
select is((select (api.tasks_close_day(pg_temp.id('hh_a'), '2026-09-03') ->> 'already_closed')::boolean), true,
  'the third day is closed once');
reset role;
select is((select current_length from api.streaks where profile_id = pg_temp.id('hanna')
             and definition_id = pg_temp.id('d_hund')), 1,
  'the second joker of the month keeps the chain, because Hanna has two');
select is((select jokers_used from api.streaks where profile_id = pg_temp.id('hanna')
             and definition_id = pg_temp.id('d_hund')), 2, 'both of Hanna''s jokers are used');
select pg_temp.act_as_service();
select is((select (api.tasks_close_day(pg_temp.id('hh_a'), '2026-09-03') ->> 'badges_awarded')::int), 0,
  'the closing run is idempotent');
reset role;
select is((select count(*)::int from api.point_transactions where reason = 'badge'), 1,
  'the streak badge with points writes one ledger row');
select is((select balance from api.point_balances where profile_id = pg_temp.id('lotta')), 15,
  'the badge points are credited to Lotta');

reset role;
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.task_skip(null, pg_temp.id('h_04')) $$, 'a guardian skips the dog task of the fourth day');
select is((select status from api.task_instances where id = pg_temp.id('h_04')), 'skipped',
  'a skipped task is skipped');
reset role;
select pg_temp.act_as_service();
select is((select (api.tasks_close_day(pg_temp.id('hh_a'), '2026-09-04') ->> 'expired')::int), 1,
  'closing the fourth day expires only the bread task');
reset role;
select is((select current_length from api.streaks where profile_id = pg_temp.id('hanna')
             and definition_id = pg_temp.id('d_hund')), 1, 'a skipped day never breaks a chain');
select is((select current_length from api.streaks where profile_id = pg_temp.id('lotta')
             and definition_id = pg_temp.id('d_brot')), 3, 'Lotta''s joker keeps the bread chain on the fourth day');
select is((select jokers_used from api.streaks where profile_id = pg_temp.id('lotta')
             and definition_id = pg_temp.id('d_brot')), 1, 'Lotta''s one joker of September is used');
select pg_temp.act_as_service();
select is((select (api.tasks_close_day(pg_temp.id('hh_a'), '2026-09-04') ->> 'already_closed')::boolean), true,
  'the fourth day is closed once');

reset role;
select pg_temp.act_as_dev('ipad');
select is((api.task_complete(pg_temp.id('lotta'), pg_temp.id('b_05')) ->> 'status'), 'done', 'Lotta ticks the bread on the fifth day');
reset role;
select pg_temp.act_as_service();
select is((select (api.tasks_close_day(pg_temp.id('hh_a'), '2026-09-06') ->> 'expired')::int), 1,
  'closing the sixth day expires the last bread task');
reset role;
select is((select current_length from api.streaks where profile_id = pg_temp.id('lotta')
             and definition_id = pg_temp.id('d_brot')), 0,
  'a second miss in the month breaks the bread chain');
select is((select longest_length from api.streaks where profile_id = pg_temp.id('lotta')
             and definition_id = pg_temp.id('d_brot')), 4, 'the longest chain is kept');
select pg_temp.act_as_service();
select is((select (api.tasks_close_day(pg_temp.id('hh_a'), '2026-09-07') ->> 'badges_awarded')::int), 0,
  'the next day awards no badge twice');
reset role;
select is((select count(*)::int from api.badge_awards where profile_id = pg_temp.id('lotta')), 3,
  'Lotta holds three badges, each awarded once');
select is((select count(*)::int from api.badge_awards where profile_id = pg_temp.id('hanna')), 2,
  'Hanna holds two badges');

-- ---- the board: open tasks per member -------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
select is((select jsonb_typeof(api.board_week() -> 'open_tasks')), 'array', 'the board carries open tasks as an array');
select is((select coalesce((select (x ->> 'count')::int from jsonb_array_elements(api.board_week() -> 'open_tasks') x
             where x ->> 'member_id' = pg_temp.id('hanna')::text), 0)), 1,
  'the board counts Hanna''s open task of today, not the one of tomorrow');
select is((select coalesce((select (x ->> 'count')::int from jsonb_array_elements(api.board_week() -> 'open_tasks') x
             where x ->> 'member_id' = pg_temp.id('lotta')::text), 0)), 0,
  'the board counts nothing for Lotta, whose tasks are all done or later');

-- ---- starter content ---------------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('b');
select is(api.tasks_seed_starter(null), '{"definitions":2,"rewards":3,"badges":4}'::jsonb,
  'a household without children gets the chores that need none, and the rewards and badges');
reset role;
insert into app.profile (household_id, display_name, role, kind)
  values (pg_temp.id('hh_b'), 'Kind B', 'member', 'child');
insert into ids select 'kind_b', id from app.profile where household_id = pg_temp.id('hh_b') and display_name = 'Kind B';
select pg_temp.act_as_dev('b');
select is(api.tasks_seed_starter(null), '{"definitions":3,"rewards":0,"badges":0}'::jsonb,
  'once a child exists the chores that rotate and repeat are added');
select is((select assignee_profile_ids from api.task_definitions where title = 'Tisch decken'),
  array[pg_temp.id('kind_b')], 'the starter rotation draws on the household''s children');
select is(api.tasks_seed_starter(null), '{"definitions":0,"rewards":0,"badges":0}'::jsonb,
  'the starter content is idempotent');

-- ---- another household sees and touches nothing of A -----------------------------------------------
reset role;
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.task_definitions where id = pg_temp.id('d_tisch')), 0,
  'another household sees none of the definitions of A');
select is((select count(*)::int from api.task_instances where id = pg_temp.id('i_tisch')), 0,
  'another household sees none of the instances of A');
select is((select count(*)::int from api.point_balances where profile_id = pg_temp.id('lotta')), 0,
  'another household sees none of the balances of A');
select is((select count(*)::int from api.point_transactions where profile_id = pg_temp.id('lotta')), 0,
  'another household sees none of the ledger of A');
select is((select count(*)::int from api.rewards where id = pg_temp.id('r_film')), 0,
  'another household sees none of the rewards of A');
select is((select count(*)::int from api.reward_redemptions where id = pg_temp.id('rq_hanna')), 0,
  'another household sees none of the redemptions of A');
select is((select count(*)::int from api.streaks where profile_id = pg_temp.id('lotta')), 0,
  'another household sees none of the streaks of A');
select is((select count(*)::int from api.badge_awards where profile_id = pg_temp.id('lotta')), 0,
  'another household sees none of the badges of A');
select throws_ok($$ select api.task_complete(null, pg_temp.id('i_muell')) $$, 'P0002', 'task not found',
  'another household cannot tick a task of A');
select throws_ok($$ select api.reward_decide(null, pg_temp.id('rq_hanna'), true, null) $$, 'P0002',
  'redemption not found', 'another household cannot decide a redemption of A');
select throws_ok($$ select api.task_definition_save(null, jsonb_build_object('id', pg_temp.id('d_tisch'),
  'title', 'Fremd', 'assignment', 'open')) $$, 'P0002', 'task not found',
  'another household cannot change a definition of A');
select throws_ok($$ select api.tasks_materialise(pg_temp.id('hh_a'), '[]'::jsonb) $$, '42501',
  'WW-TSK-002 task not yours', 'another household cannot materialise for A');

-- ---- a kiosk never writes what the wall does not do ---------------------------------------------------
reset role;
select pg_temp.act_as_dev('kiosk');
select throws_ok($$ select api.task_definition_save(pg_temp.id('lotta'), '{"title":"Kiosk","assignment":"open"}'::jsonb) $$,
  '42501', 'not allowed on a kiosk', 'a kiosk cannot save a definition');
select throws_ok($$ select api.points_adjust(pg_temp.id('papa'), pg_temp.id('lotta'), 1, 'Kiosk') $$,
  '42501', 'not allowed on a kiosk', 'a kiosk cannot adjust a balance');

-- ---- a revoked phone -----------------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('old');
select is((select count(*)::int from api.task_instances), 0, 'a revoked phone reads no tasks');
select is((select count(*)::int from api.point_balances), 0, 'a revoked phone reads no balances');
select throws_ok($$ select api.task_complete(pg_temp.id('lotta'), pg_temp.id('i_muell')) $$, '42501',
  'device not usable', 'a revoked phone cannot tick a task');
select throws_ok($$ select api.tasks_schedule() $$, '42501', 'device not usable',
  'a revoked phone reads no schedule');

-- ---- anonymous callers -----------------------------------------------------------------------------------
reset role;
set local role anon;
select throws_ok('select count(*) from api.task_instances', '42501', 'permission denied for view task_instances',
  'anonymous callers cannot read tasks');
select throws_ok($$ select api.task_complete(null, '00000000-0000-4000-8000-000000000000') $$, '42501',
  'permission denied for function task_complete', 'anonymous callers cannot tick a task');
reset role;

-- ---- audit ---------------------------------------------------------------------------------------------------
select ok(exists (select 1 from app.audit_log where entity_type = 'task_instance' and action = 'complete'
                  and household_id = pg_temp.id('hh_a')), 'a tick is audited');
select ok(exists (select 1 from app.audit_log where entity_type = 'reward_redemption' and action = 'approve'
                  and household_id = pg_temp.id('hh_a')), 'a reward approval is audited');
select ok(exists (select 1 from app.audit_log where entity_type = 'profile' and action = 'points_adjust'
                  and household_id = pg_temp.id('hh_a')), 'a balance correction is audited');

select * from finish();
rollback;
