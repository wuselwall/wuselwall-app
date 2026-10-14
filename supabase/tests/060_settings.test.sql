begin;
select plan(46);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create function pg_temp.act_as(p_sub uuid, p_claims jsonb) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_sub, 'role', 'authenticated') || p_claims)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- ---- the catalogue, as the owner ---------------------------------------------------------
select is((select count(*)::int from app.setting_definition), 26, 'the catalogue holds the 26 settings (specs/21 and household.region)');
select is((select count(*)::int from app.setting_definition d where not app.setting_valid(d, d.default_value)),
  0, 'every default satisfies its own constraints');
select ok(not (select app.setting_valid(d, '4'::jsonb) from app.setting_definition d where d.key = 'tasks.points.duty_default'),
  'a value above the maximum is invalid');
select ok(not (select app.setting_valid(d, 'null'::jsonb) from app.setting_definition d where d.key = 'tasks.points.duty_default'),
  'JSON null is invalid where the constraints do not allow it');
select ok((select app.setting_valid(d, 'null'::jsonb) from app.setting_definition d where d.key = 'notify.event_reminder'),
  'JSON null switches a nullable setting off');
select ok(not (select app.setting_valid(d, '1.5'::jsonb) from app.setting_definition d where d.key = 'device.idle_revert_seconds'),
  'an integer must be whole');
select ok(not (select app.setting_valid(d, '"24:00"'::jsonb) from app.setting_definition d where d.key = 'meals.care_lunch_cutoff'),
  'a time of 24:00 is invalid');
select ok(not (select app.setting_valid(d, '["17:00","12:00"]'::jsonb) from app.setting_definition d where d.key = 'board.day_parts'),
  'day parts must ascend');
select ok(not (select app.setting_valid(d, '{"weekday":8,"time":"12:00"}'::jsonb) from app.setting_definition d where d.key = 'board.rollover'),
  'a weekday outside 1-7 is invalid');

-- ---- households: A with a guardian's phone, a child and a shared iPad; B by hand ----------
create temp table a as select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on a to public;
insert into app.profile (household_id, display_name, role)
  select (r ->> 'household_id')::uuid, 'Kid', 'member' from a;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (r ->> 'household_id')::uuid, p.auth_user_id, 'Papa-Phone', 'personal', 'adult', p.id
    from a join app.profile p on p.id = (a.r ->> 'profile_id')::uuid;
create temp table ipad_user as select app.create_auth_user('ipad@devices.invalid', 'x1234567890') usr;
grant all on ipad_user to public;
insert into app.device (household_id, auth_user_id, label, class, register)
  select (r ->> 'household_id')::uuid, (select usr from ipad_user), 'iPad', 'shared', 'kid' from a;
create temp table old_user as select app.create_auth_user('old@example.org', 'longpassword1') usr;
grant all on old_user to public;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  select (r ->> 'household_id')::uuid, (select usr from old_user), 'Old-Phone', 'personal', 'adult',
         (a.r ->> 'profile_id')::uuid, now()
    from a;

create temp table ids as
  select (a.r ->> 'household_id')::uuid hh,
         (a.r ->> 'profile_id')::uuid guardian,
         (select auth_user_id from app.profile where id = (a.r ->> 'profile_id')::uuid) guser,
         (select id from app.profile where display_name = 'Kid') kid,
         (select id from app.device where label = 'Papa-Phone') phone,
         (select id from app.device where label = 'iPad') ipad,
         (select id from app.device where label = 'Old-Phone') old_phone
    from a;
grant all on ids to public;

insert into app.household (name) values ('B');
create temp table b as
  select h.id hh, app.create_auth_user('b@example.org', 'longpassword1') usr from app.household h where h.name = 'B';
grant all on b to public;
insert into app.profile (household_id, display_name, role, auth_user_id)
  select hh, 'B', 'guardian', usr from b;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select b.hh, b.usr, 'B-Phone', 'personal', 'adult', (select id from app.profile where auth_user_id = b.usr) from b;

-- ---- guardian on a personal phone -----------------------------------------------------------
select pg_temp.act_as((select guser from ids), jsonb_build_object(
  'household_id', (select hh from ids), 'device_id', (select phone from ids), 'device_class', 'personal'));

select is((select count(*)::int from api.settings), 26, 'api.settings lists every definition for a fresh household');
select is((select bool_and(is_default) from api.settings), true, 'a fresh household is on every default');
select is((select value from api.settings where key = 'board.rollover'), '{"weekday":6,"time":"12:00"}'::jsonb,
  'the rollover shows its curated default');

select lives_ok($$ select api.set_setting(null, 'board.rollover', '{"weekday":7,"time":"18:00"}') $$,
  'a guardian on a personal phone sets the rollover');
select is((select is_default from api.settings where key = 'board.rollover'), false, 'a changed setting is no longer on its default');
select is((select value from api.settings where key = 'board.rollover'), '{"weekday":7,"time":"18:00"}'::jsonb,
  'the changed value is what api.settings shows');

select throws_ok($$ select api.set_setting(null, 'tasks.points.bonus_default', '51') $$,
  '22023', 'WW-SET-001 setting value out of range', 'a value above the range is refused');
select throws_ok($$ select api.set_setting(null, 'tasks.verification_default', '"yes"') $$,
  '22023', 'WW-SET-001 setting value out of range', 'a value of the wrong type is refused');
select throws_ok($$ select api.set_setting(null, 'no.such.key', 'true') $$,
  '22023', 'WW-SET-002 unknown setting', 'an unknown key is refused');

select lives_ok(format($$ select api.set_setting(null, 'tasks.jokers_per_month', '3', %L) $$, (select kid from ids)),
  'a guardian gives a child more jokers');
select is((select value from api.settings where key = 'tasks.jokers_per_month' and profile_id = (select kid from ids)),
  '3'::jsonb, 'the member override is listed for that member');
select is((select count(*)::int from api.settings where key = 'tasks.jokers_per_month'), 2,
  'the household row and the member row are both listed');
select throws_ok(format($$ select api.set_setting(null, 'board.day_parts', '["12:00","17:00"]', %L) $$, (select kid from ids)),
  '22023', 'WW-SET-003 setting target invalid', 'a household setting that is not per member has no member rows');

select lives_ok(format($$ select api.set_setting(null, 'device.idle_revert_seconds', '90', null, %L) $$, (select ipad from ids)),
  'a guardian sets a device-level setting');
select is((select value from api.settings where key = 'device.idle_revert_seconds' and device_id = (select ipad from ids)),
  '90'::jsonb, 'the device override is listed for that device');

select lives_ok($$ select api.reset_setting(null, 'board.rollover') $$, 'a guardian resets a setting');
select is((select is_default from api.settings where key = 'board.rollover'), true, 'reset restores the default');
select lives_ok($$ select api.set_setting(null, 'board.day_parts', '["09:00","15:00"]') $$,
  'a guardian changes the day parts for the household');

-- ---- a revoked phone ---------------------------------------------------------------------------
reset role;
select pg_temp.act_as((select usr from old_user), jsonb_build_object(
  'household_id', (select hh from ids), 'device_id', (select old_phone from ids), 'device_class', 'personal'));
select is((select count(*)::int from api.settings), 0, 'a revoked phone reads no settings');
select throws_ok($$ select api.set_setting(null, 'board.day_parts', '["10:00","15:00"]') $$,
  '42501', 'device not usable', 'a revoked phone cannot change a setting');

-- ---- a member on the shared iPad -----------------------------------------------------------------
reset role;
select pg_temp.act_as((select usr from ipad_user), jsonb_build_object(
  'household_id', (select hh from ids), 'device_id', (select ipad from ids), 'device_class', 'shared'));
select throws_ok(format($$ select api.set_setting(%L, 'board.day_parts', '["10:00","15:00"]') $$, (select kid from ids)),
  '42501', 'guardian required', 'a member on a shared device cannot change a household setting');
select lives_ok(format($$ select api.set_setting(%L, 'member.completion_sound', 'false', %L) $$,
  (select kid from ids), (select kid from ids)), 'a member switches their own completion sound off');
select is((select value from api.settings where key = 'member.completion_sound' and profile_id = (select kid from ids)),
  'false'::jsonb, 'the member sees the value they set');
select throws_ok(format($$ select api.set_setting(%L, 'member.completion_sound', 'false', %L) $$,
  (select kid from ids), (select guardian from ids)),
  '42501', 'guardian required', 'a member cannot change the setting of another profile');
select lives_ok(format($$ select api.set_setting(%L, 'notify.task_verified', 'true', %L) $$,
  (select kid from ids), (select kid from ids)), 'a member turns on their own verification push');
select throws_ok(format($$ select api.set_setting(%L, 'notify.task_verified', '"maybe"', %L) $$,
  (select kid from ids), (select kid from ids)), '22023', 'WW-SET-001 setting value out of range',
  'a member gets the value check too');

-- ---- anonymous callers -------------------------------------------------------------------------
reset role;
set local role anon;
select throws_ok('select count(*) from api.settings', '42501', 'permission denied for view settings',
  'anonymous callers cannot read settings');
select throws_ok($$ select api.set_setting(null, 'board.day_parts', '["10:00","15:00"]') $$,
  '42501', 'permission denied for function set_setting', 'anonymous callers cannot change settings');
reset role;

-- ---- household B ---------------------------------------------------------------------------------
select pg_temp.act_as((select usr from b), jsonb_build_object(
  'household_id', (select hh from b), 'device_id', (select id from app.device where auth_user_id = (select usr from b)),
  'device_class', 'personal'));
select is((select count(*)::int from api.settings where profile_id is not null or device_id is not null), 0,
  'another household sees none of the overrides (RLS)');
select is((select value from api.settings where key = 'board.day_parts'), '["12:00","17:00"]'::jsonb,
  'another household keeps its own defaults');
select is((select count(*)::int from api.settings), 26, 'another household sees every definition');
select throws_ok(format($$ select api.set_setting(null, 'member.completion_sound', 'false', %L) $$, (select kid from ids)),
  '22023', 'WW-SET-003 setting target invalid', 'a profile of another household cannot be changed');
select throws_ok(format($$ select api.reset_setting(null, 'device.idle_revert_seconds', null, %L) $$, (select ipad from ids)),
  '22023', 'WW-SET-003 setting target invalid', 'a device of another household cannot be reset');

-- ---- the owner's view: audit and grants ----------------------------------------------------------
reset role;
select ok(exists (select 1 from app.audit_log where entity_type = 'setting' and action = 'set'
                  and household_id = (select hh from ids)), 'setting writes are audited');
select ok(exists (select 1 from app.audit_log where entity_type = 'setting' and action = 'reset'),
  'resets are audited');
select ok(not has_function_privilege('authenticated', 'app.setting_valid(app.setting_definition, jsonb)', 'execute'),
  'the validator is not callable by clients');
select ok(not has_table_privilege('authenticated', 'app.household_setting', 'insert,update,delete'),
  'clients cannot write household_setting directly');

select * from finish();
rollback;
