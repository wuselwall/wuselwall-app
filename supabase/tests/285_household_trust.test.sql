begin;
select plan(62);

-- Trust inside the household (20261102110000_household_trust.sql; security review 2026-11-01,
-- F4, F11, F13, F16, F17, F18, F20): a child's phone is never a guardian, someone else's task
-- needs the PIN window on a shared device, the window is short and can be ended, a closed day
-- takes no tick, feed tokens follow their maker, device accounts go with the family, and the
-- old founding call counts its failures.

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
delete from app.founder_attempt;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;

create function pg_temp.id(p_name text) returns uuid language sql stable as $$
  select i.id from ids i where i.name = p_name
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

create function pg_temp.act_as_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  perform set_config('role', 'service_role', true);
end $$;

-- A device of the household: a person's own account, or a device account as app.enrol_device
-- and api.pairing_approve make them (the address is the marker app.is_device_account reads).
create function pg_temp.add_dev(p_name text, p_hh text, p_profile text, p_class text, p_register text,
  p_device_account boolean) returns void language plpgsql as $$
declare
  v_id  uuid := gen_random_uuid();
  v_usr uuid;
begin
  if p_device_account then
    v_usr := app.create_auth_user('device-' || v_id || '@devices.wuselwall.invalid', 'x1234567890',
                                  jsonb_build_object('device', true));
  else
    v_usr := (select auth_user_id from app.profile where id = pg_temp.id(p_profile));
  end if;
  insert into app.device (id, household_id, auth_user_id, label, class, register, profile_id)
  values (v_id, pg_temp.id(p_hh), v_usr, p_name, p_class, p_register, pg_temp.id(p_profile));
  insert into devs values (p_name, v_usr, v_id, pg_temp.id(p_hh), p_class);
end $$;

-- The job materialises with the service role; the test goes on as whoever it was.
create function pg_temp.materialise(p_hh uuid, p_items jsonb) returns int language plpgsql as $$
declare
  v_claims text := current_setting('request.jwt.claims', true);
  v_role   text := current_setting('role', true);
  v_n      int;
begin
  perform set_config('role', 'none', true);
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  perform set_config('role', 'service_role', true);
  v_n := (api.tasks_materialise(p_hh, p_items) ->> 'created')::int;
  perform set_config('role', 'none', true);
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  if coalesce(v_role, 'none') <> 'none' then
    perform set_config('role', v_role, true);
  end if;
  return v_n;
end $$;

-- ---- F20: the old founding counts its failures -------------------------------------------------
set local role anon;
select is(api.setup_household('wrong', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456'),
  '{"ok": false, "reason": "setup_token_invalid"}'::jsonb, 'a wrong setup token is answered, not raised');
reset role;
select is((select count(*)::int from app.founder_attempt where not success), 1,
  'the wrong token is counted in the founder bucket');
set local role anon;
select api.setup_household('wrong', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456');
select api.setup_household('wrong', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456');
select api.setup_household('wrong', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456');
select api.setup_household('wrong', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456');
select throws_ok($$ select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') $$,
  '42501', 'too many attempts', 'after five wrong tokens the client is refused, the right token included');
reset role;
delete from app.founder_attempt;

-- ---- household A: Papa and Mama (guardians with accounts), Oma (adult member), Emma (child) ----------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
select is((select (r ->> 'ok')::boolean from sa), true, 'the right token founds the family');
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;
-- The days of the test in the household's own time zone (app.tasks_today is internal).
create temp table dt (k text primary key, d date);
grant all on dt to public;
insert into dt select 'today', (now() at time zone h.timezone)::date from app.household h where h.id = pg_temp.id('hh_a');
insert into dt select 'yesterday', d - 1 from dt where k = 'today';
with ins as (insert into app.profile (household_id, display_name, role, kind, auth_user_id, pin_hash)
  values (pg_temp.id('hh_a'), 'Mama', 'guardian', 'adult', app.create_auth_user('mama@example.org', 'longpassword1'),
          extensions.crypt('654321', extensions.gen_salt('bf', 4))) returning id)
insert into ids select 'mama', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, kind)
  values (pg_temp.id('hh_a'), 'Oma', 'member', 'adult') returning id)
insert into ids select 'oma', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, kind)
  values (pg_temp.id('hh_a'), 'Emma', 'member', 'child') returning id)
insert into ids select 'emma', id from ins;

select pg_temp.add_dev('papa', 'hh_a', 'papa', 'personal', 'adult', false);
select pg_temp.add_dev('mama', 'hh_a', 'mama', 'personal', 'adult', false);
select pg_temp.add_dev('ipad', 'hh_a', null, 'shared', 'kid', true);
select pg_temp.add_dev('kiosk', 'hh_a', null, 'kiosk', 'kiosk', true);
-- The child's phone and Oma's phone: personal devices with a device user (pairing kind child_phone).
select pg_temp.add_dev('emma_phone', 'hh_a', 'emma', 'personal', 'kid', true);
select pg_temp.add_dev('oma_phone', 'hh_a', 'oma', 'personal', 'adult', true);
-- Their device users are signed in, like a phone that stays in a pocket.
insert into auth.sessions (id, user_id, created_at, updated_at) select gen_random_uuid(), usr, now(), now() from devs where name in ('emma_phone', 'oma_phone', 'ipad');

-- A daily chore for Emma, and one for Oma.
select pg_temp.act_as_dev('papa');
insert into ids select 'd_emma', (api.task_definition_save(null, jsonb_build_object('title', 'Tisch decken',
  'points', 2, 'rrule', 'FREQ=DAILY', 'assignment', 'fixed',
  'assignee_profile_ids', jsonb_build_array(pg_temp.id('emma')))) ->> 'id')::uuid;
insert into ids select 'd_oma', (api.task_definition_save(null, jsonb_build_object('title', 'Blumen giessen',
  'points', 1, 'rrule', 'FREQ=DAILY', 'assignment', 'fixed',
  'assignee_profile_ids', jsonb_build_array(pg_temp.id('oma')))) ->> 'id')::uuid;
select is(pg_temp.materialise(pg_temp.id('hh_a'), jsonb_build_array(
  jsonb_build_object('definition_id', pg_temp.id('d_emma'), 'due_on', (select d from dt where k = 'today')),
  jsonb_build_object('definition_id', pg_temp.id('d_emma'), 'due_on', (select d from dt where k = 'yesterday')),
  jsonb_build_object('definition_id', pg_temp.id('d_oma'), 'due_on', (select d from dt where k = 'today')))), 3,
  'the job materialises today and yesterday');
reset role;
insert into ids select 'i_emma', id from app.task_instance where definition_id = pg_temp.id('d_emma')
  and due_on = (select d from dt where k = 'today');
insert into ids select 'i_emma_y', id from app.task_instance where definition_id = pg_temp.id('d_emma')
  and due_on = (select d from dt where k = 'yesterday');
insert into ids select 'i_oma', id from app.task_instance where definition_id = pg_temp.id('d_oma');

-- ---- F17: someone else's task is a guardian action, PIN included ----------------------------------
select pg_temp.act_as_dev('ipad');
select throws_ok($$ select api.task_complete(pg_temp.id('papa'), pg_temp.id('i_emma')) $$,
  '42501', 'WW-TSK-002 task not yours', 'on the shared tablet Papa''s avatar alone does not tick Emma''s task');
select is((api.task_complete(pg_temp.id('emma'), pg_temp.id('i_emma')) ->> 'status'), 'done',
  'Emma ticks her own task without any PIN');
select throws_ok($$ select api.task_undo(pg_temp.id('papa'), pg_temp.id('i_emma')) $$,
  '42501', 'WW-TSK-002 task not yours', 'nor does the avatar alone take her tick back');
select is((api.guardian_verify_pin(pg_temp.id('papa'), '123456')) ->> 'ok', 'true', 'Papa enters his PIN on the tablet');
select lives_ok($$ select api.task_undo(pg_temp.id('papa'), pg_temp.id('i_emma')) $$,
  'with the PIN window open Papa takes the tick back');
select is((api.task_complete(pg_temp.id('papa'), pg_temp.id('i_emma')) ->> 'status'), 'done',
  'and ticks Emma''s task for her');
select throws_ok($$ select api.task_undo(pg_temp.id('mama'), pg_temp.id('i_emma')) $$,
  '42501', 'WW-TSK-002 task not yours', 'the window is Papa''s: Mama''s avatar gains nothing from it');
select lives_ok($$ select api.task_undo(pg_temp.id('papa'), pg_temp.id('i_emma')) $$, 'Papa undoes again');

-- ---- F13: a short window, and a way to end it ---------------------------------------------------------
select ok((select guardian_verified_until from app.device where id = (select dev from devs where name = 'ipad'))
          between now() + interval '4 minutes' and now() + interval '6 minutes',
  'on a shared device the PIN window is five minutes');
select lives_ok($$ select api.guardian_step_down() $$, 'the tablet steps down');
select is((select guardian_verified_until is null and guardian_verified_profile is null
             from app.device where id = (select dev from devs where name = 'ipad')), true,
  'stepping down clears the window and the verified profile');
select throws_ok($$ select api.task_complete(pg_temp.id('papa'), pg_temp.id('i_emma')) $$,
  '42501', 'WW-TSK-002 task not yours', 'after stepping down the avatar is an avatar again');
select lives_ok($$ select api.guardian_step_down() $$, 'stepping down twice is harmless');
reset role;
select pg_temp.act_as_dev('papa');
select is((api.guardian_verify_pin(pg_temp.id('papa'), '123456')) ->> 'ok', 'true', 'Papa verifies on his own phone');
select ok((select guardian_verified_until from app.device where id = (select dev from devs where name = 'papa'))
          between now() + interval '14 minutes' and now() + interval '16 minutes',
  'on a personal device the window stays fifteen minutes');
reset role;
update app.device set revoked_at = now() where id = (select dev from devs where name = 'kiosk');
select pg_temp.act_as_dev('kiosk');
select throws_ok($$ select api.guardian_step_down() $$, '42501', 'device not usable',
  'a revoked device cannot step down (it has nothing left to do)');
reset role;
update app.device set revoked_at = null where id = (select dev from devs where name = 'kiosk');
set local role anon;
select throws_ok($$ select api.guardian_step_down() $$, '42501', 'permission denied for function guardian_step_down',
  'anon cannot call step down');
reset role;

-- ---- F16: a child's phone is never a guardian ---------------------------------------------------------
select pg_temp.act_as_dev('emma_phone');
select is((api.task_complete(null, pg_temp.id('i_emma')) ->> 'status'), 'done',
  'Emma''s phone ticks her task: a personal device acts for its profile');
select lives_ok($$ select api.task_undo(null, pg_temp.id('i_emma')) $$, 'and takes it back');
reset role;
-- Oma is made a guardian by hand (the old state: a promoted member keeps the phone).
update app.profile set role = 'guardian' where id = pg_temp.id('oma');
select pg_temp.act_as_dev('oma_phone');
select throws_ok($$ select api.devices_revoke(null, (select dev from devs where name = 'ipad')) $$,
  '42501', 'guardian required', 'a guardian''s phone with a device user cannot do guardian actions');
select throws_ok($$ select api.task_complete(null, pg_temp.id('i_emma')) $$,
  '42501', 'WW-TSK-002 task not yours', 'nor tick someone else''s task');
select is((api.task_complete(null, pg_temp.id('i_oma')) ->> 'status'), 'done', 'her own task, yes');
reset role;
update app.profile set role = 'member' where id = pg_temp.id('oma');

-- Promotion by the API revokes such phones; the person signs in with an account instead.
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.member_set_role(null, pg_temp.id('oma'), 'guardian') $$, 'Papa makes Oma a guardian');
reset role;
select is((select revoked_at is not null from app.device where id = (select dev from devs where name = 'oma_phone')), true,
  'promoting Oma revokes her phone with the device user');
select is((select count(*)::int from auth.sessions where user_id = (select usr from devs where name = 'oma_phone')), 0,
  'and ends its session');
select is((select revoked_at is null from app.device where id = (select dev from devs where name = 'papa')), true,
  'an account''s own phone is untouched by a role change');
select pg_temp.act_as_dev('oma_phone');
select throws_ok($$ select api.task_complete(null, pg_temp.id('i_oma')) $$, '42501', 'device not usable',
  'the revoked phone is out');
reset role;

-- A personal device acts for its profile only while that profile is active.
update app.profile set active = false where id = pg_temp.id('emma');
select pg_temp.act_as_dev('emma_phone');
select throws_ok($$ select api.task_complete(null, pg_temp.id('i_emma')) $$, '42501', 'unknown acting profile',
  'a personal device of an inactive profile cannot act');
reset role;
update app.profile set active = true where id = pg_temp.id('emma');

-- "Nicht mehr dabei" revokes the child's phone and ends its session.
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.member_deactivate(null, pg_temp.id('emma')) $$, 'Papa retires Emma');
reset role;
select is((select revoked_at is not null from app.device where id = (select dev from devs where name = 'emma_phone')), true,
  'deactivating Emma revokes her phone');
select is((select count(*)::int from auth.sessions where user_id = (select usr from devs where name = 'emma_phone')), 0,
  'and ends its session');
select is((select count(*)::int from auth.sessions where user_id = (select usr from devs where name = 'ipad')), 1,
  'the shared tablet keeps its session');
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.member_reactivate(null, pg_temp.id('emma')) $$, 'Emma is back');
reset role;
select is((select revoked_at is not null from app.device where id = (select dev from devs where name = 'emma_phone')), true,
  'reactivating her does not revive the phone: it is paired again');

-- ---- F4: a closed day takes no tick ------------------------------------------------------------------
select pg_temp.act_as_dev('ipad');
select is((api.task_complete(pg_temp.id('emma'), pg_temp.id('i_emma_y')) ->> 'status'), 'done',
  'yesterday''s task can still be ticked while its day is not closed (a late tick)');
select lives_ok($$ select api.task_undo(pg_temp.id('emma'), pg_temp.id('i_emma_y')) $$, 'and taken back');
reset role;
select pg_temp.act_as_service();
select is((select (api.tasks_close_day(pg_temp.id('hh_a'), (select d from dt where k = 'yesterday')) ->> 'expired')::int), 1,
  'the nightly close expires the open task of yesterday');
reset role;
-- An instance that turns up for a closed day can only have been created afterwards.
select is(pg_temp.materialise(pg_temp.id('hh_a'), jsonb_build_array(
  jsonb_build_object('definition_id', pg_temp.id('d_oma'), 'due_on', (select d from dt where k = 'yesterday')))), 1,
  'the job writes an instance for the closed day (the test stands in for a stale run)');
insert into ids select 'i_oma_y', id from app.task_instance where definition_id = pg_temp.id('d_oma')
  and due_on = (select d from dt where k = 'yesterday');
select pg_temp.act_as_dev('ipad');
select throws_ok($$ select api.task_complete(pg_temp.id('oma'), pg_temp.id('i_oma_y')) $$,
  '22023', 'WW-TSK-005 task not open', 'a task of a closed day cannot be ticked');
reset role;
select is((select count(*)::int from app.point_transaction where profile_id = pg_temp.id('oma') and reason = 'task'), 1,
  'no points were minted for the closed day (only Oma''s one tick of today)');

-- ---- F11: feed tokens follow their maker ----------------------------------------------------------------
select pg_temp.act_as_dev('papa');
insert into ids select 'ft_papa', (api.feed_token_create(null, 'Papas Kalender', null) ->> 'id')::uuid;
reset role;
select pg_temp.act_as_dev('mama');
insert into ids select 'ft_mama', (api.feed_token_create(null, 'Mamas Kalender', null) ->> 'id')::uuid;
select is((select created_by_profile_id from api.feed_tokens where id = pg_temp.id('ft_mama')), pg_temp.id('mama'),
  'the feed token list names its maker');
reset role;
-- Mama leaves: her account is unlinked, as api.account_leave does.
update app.profile set auth_user_id = null where id = pg_temp.id('mama');
select is((select revoked_at is not null from app.calendar_feed_token where id = pg_temp.id('ft_mama')), true,
  'unlinking the account revokes her feed tokens');
select is((select revoked_at is null from app.calendar_feed_token where id = pg_temp.id('ft_papa')), true,
  'Papa''s token stays');
insert into app.calendar_feed_token (household_id, label, token_hash, created_by_profile_id)
  values (pg_temp.id('hh_a'), 'Omas Kalender', encode(extensions.digest('oma-token', 'sha256'), 'hex'), pg_temp.id('oma'));
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.member_set_role(null, pg_temp.id('oma'), 'member') $$, 'Oma is a member again');
select lives_ok($$ select api.member_deactivate(null, pg_temp.id('oma')) $$, 'and retires');
reset role;
select is((select revoked_at is not null from app.calendar_feed_token where label = 'Omas Kalender'), true,
  'deactivating a profile revokes its feed tokens');
select is(api.ics_feed('oma-token'), null, 'the revoked token answers nothing');

-- ---- F18: device accounts go with the family, a child''s phone included ---------------------------------
-- Closing (account deletion of the last person) ends every device account's session.
select pg_temp.act_as_dev('ipad');
reset role;
insert into auth.sessions (id, user_id, created_at, updated_at) select gen_random_uuid(), usr, now(), now() from devs where name = 'emma_phone';
select is((select count(*)::int from auth.sessions where user_id in (select usr from devs where name in ('ipad', 'emma_phone'))), 2,
  'two device sessions before the family closes');
select isnt(app.household_close(pg_temp.id('hh_a')), null, 'the family is closed');
select is((select count(*)::int from auth.sessions where user_id in (select usr from devs where name in ('ipad', 'emma_phone'))), 0,
  'closing ends the sessions of the tablet and of the child''s phone');
-- The purge removes the device accounts, the child's phone's included; Papa's account stays.
update app.household set deleted_at = now() - interval '15 days' where id = pg_temp.id('hh_a');
select pg_temp.act_as_service();
select is((api.household_purge_due() ->> 'device_accounts')::int, 4,
  'the purge removes the four device accounts: tablet, wall and the two phones with a device user');
reset role;
select is((select count(*)::int from auth.users where id in (select usr from devs where name in ('ipad', 'kiosk', 'emma_phone', 'oma_phone'))), 0,
  'the device accounts are gone');
select is((select count(*)::int from auth.users where id in (select usr from devs where name in ('papa', 'mama'))), 2,
  'the adults'' accounts stay');

-- Deleting a family at once (household_delete) removes the child's phone's account as well.
reset role;
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
with ins as (insert into app.profile (household_id, display_name, role, kind, auth_user_id)
  values (pg_temp.id('hh_b'), 'Bea', 'guardian', 'adult', app.create_auth_user('bea@example.org', 'longpassword1')) returning id)
insert into ids select 'bea', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, kind)
  values (pg_temp.id('hh_b'), 'Ben', 'member', 'child') returning id)
insert into ids select 'ben', id from ins;
select pg_temp.add_dev('bea', 'hh_b', 'bea', 'personal', 'adult', false);
select pg_temp.add_dev('ben_phone', 'hh_b', 'ben', 'personal', 'kid', true);
insert into auth.sessions (id, user_id, created_at, updated_at) select gen_random_uuid(), usr, now(), now() from devs where name = 'ben_phone';
select pg_temp.act_as_dev('bea');
select is((api.household_delete(null, 'B') ->> 'ok')::boolean, true, 'Bea deletes family B');
reset role;
select is((select count(*)::int from auth.users where id = (select usr from devs where name = 'ben_phone')), 0,
  'the child''s phone''s account went with the family');
select is((select count(*)::int from auth.sessions where user_id = (select usr from devs where name = 'ben_phone')), 0,
  'and so did its session');
select is((select count(*)::int from auth.users where id = (select usr from devs where name = 'bea')), 1,
  'Bea''s account stays');

select * from finish();
rollback;
