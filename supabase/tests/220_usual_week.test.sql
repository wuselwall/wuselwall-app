begin;
select plan(44);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

-- Named things of the test: profiles and households (ids), devices (devs), auth users (users).
create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;
create temp table snap (k text primary key, v jsonb);
grant all on snap to public;

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

-- The hint a statement fails with, or null when it succeeds.
create function pg_temp.error_hint(p_sql text) returns text language plpgsql as $$
declare v_hint text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint;
  return v_hint;
end $$;

-- Paul's week as the caller sees it.
create function pg_temp.week(p_name text) returns jsonb language sql as $$
  select slots from api.usual_weeks where profile_id = pg_temp.id(p_name)
$$;

-- Sets Paul's week as the caller, with the anchor and the slots given.
create function pg_temp.set_week(p_anchor date, p_slots jsonb) returns text language sql as $$
  select pg_temp.error_hint(format($q$ select api.member_usual_week_set(null, %L, %L, %L) $q$,
                                   pg_temp.id('paul'), p_anchor, p_slots))
$$;

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
 where p.household_id = pg_temp.id('hh_a');

insert into users values
  ('ipad', app.create_auth_user('ipad@devices.invalid', 'x1234567890')),
  ('kiosk', app.create_auth_user('kiosk@devices.invalid', 'x1234567890')),
  ('old', app.create_auth_user('old@example.org', 'longpassword1'));

insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.id('hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = pg_temp.id('papa');
insert into app.device (household_id, auth_user_id, label, class, register)
  select pg_temp.id('hh_a'), usr, 'iPad', 'shared', 'kid' from users where name = 'ipad';
insert into app.device (household_id, auth_user_id, label, class, register)
  select pg_temp.id('hh_a'), usr, 'Kiosk', 'kiosk', 'kiosk' from users where name = 'kiosk';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  select pg_temp.id('hh_a'), usr, 'Old-Phone', 'personal', 'adult', pg_temp.id('papa'), now()
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
  select pg_temp.id('hh_b'), 'B', 'guardian', usr from users where name = 'b';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.id('hh_b'), u.usr, 'B-Phone', 'personal', 'adult', p.id
    from users u join app.profile p on p.auth_user_id = u.usr where u.name = 'b';
insert into devs
  select 'b', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id
   where u.name = 'b';

-- ---- a guardian writes a week with one place per day and a day of slots ------------------------
select pg_temp.act_as_dev('papa');

select is(pg_temp.set_week(null, '[
  {"weekday": 1, "state": "working", "label": "Büro"},
  {"weekday": 2, "state": "home_office"},
  {"weekday": 3, "state": "home_office", "starts": "13:00", "ends": "17:00"},
  {"weekday": 3, "state": "working", "label": " Büro ", "starts": "08:00", "ends": "12:00"}
]'), null, 'a guardian sets a member''s usual week');
select is(jsonb_array_length(pg_temp.week('paul')), 4, 'every place of the week is listed');
select is((select jsonb_agg(s ->> 'starts' order by (s ->> 'position')::int) from jsonb_array_elements(pg_temp.week('paul')) s
            where (s ->> 'weekday')::int = 3), '["08:00", "13:00"]'::jsonb,
  'a day''s slots are numbered in time order');
select is((select s ->> 'label' from jsonb_array_elements(pg_temp.week('paul')) s
            where (s ->> 'weekday')::int = 3 and s ->> 'starts' = '08:00'), 'Büro', 'labels are trimmed');
select is((select s -> 'starts' from jsonb_array_elements(pg_temp.week('paul')) s
            where (s ->> 'weekday')::int = 1), 'null'::jsonb, 'a whole-day place has no times');
select is((select anchor from api.usual_weeks where profile_id = pg_temp.id('paul')), null::date,
  'without an anchor the week is the same every week');
-- Büro twice (Monday, Wednesday morning) and Homeoffice twice: a tie goes to the earliest day.
select is((select default_presence_state || ' ' || default_presence_label from api.members where id = pg_temp.id('paul')),
  'working Büro', 'the previous app''s single baseline is the week''s most common place');
select is((select count(*)::int from app.audit_log where entity_id = pg_temp.id('paul') and action = 'usual_week_set'),
  1, 'the write is audited');

-- ---- what is refused ---------------------------------------------------------------------------
select is(pg_temp.set_week(null, '[{"weekday": 1, "state": "working", "starts": "08:00", "ends": "12:00"},
                                   {"weekday": 1, "state": "off", "starts": "11:00", "ends": "14:00"}]'),
  'usual_week_invalid', 'overlapping slots are refused');
select is(pg_temp.set_week(null, '[{"weekday": 1, "state": "working", "starts": "08:00", "ends": "09:00"},
                                   {"weekday": 1, "state": "off", "starts": "09:00", "ends": "10:00"},
                                   {"weekday": 1, "state": "working", "starts": "10:00", "ends": "11:00"},
                                   {"weekday": 1, "state": "off", "starts": "11:00", "ends": "12:00"}]'),
  'usual_week_invalid', 'a fourth slot on a day is refused');
select is(pg_temp.set_week(null, '[{"weekday": 1, "state": "working"},
                                   {"weekday": 1, "state": "off", "starts": "11:00", "ends": "14:00"}]'),
  'usual_week_invalid', 'a whole-day place is the day''s only one');
select is(pg_temp.set_week('2026-10-20', '[]'), 'usual_week_invalid', 'the anchor is a Monday');
select is(pg_temp.set_week(null, '[{"weekday": 1, "state": "working", "starts": "12:00", "ends": "08:00"}]'),
  'usual_week_invalid', 'a slot ends after it starts');
select is(pg_temp.set_week(null, '[{"weekday": 1, "state": "working", "starts": "12:00"}]'),
  'usual_week_invalid', 'a slot has both times or neither');
select is(pg_temp.set_week(null, '[{"weekday": 1, "state": "sleeping"}]'),
  'usual_week_invalid', 'the six presence states only');
select is(pg_temp.set_week(null, jsonb_build_array(jsonb_build_object('weekday', 1, 'state', 'off',
                                   'label', repeat('x', 41)))),
  'usual_week_invalid', 'a label has at most 40 characters');
select is(pg_temp.set_week(null, '[{"weekday": 8, "state": "off"}]'), 'usual_week_invalid', 'weekdays are 1 to 7');
select is(pg_temp.set_week(null, '[{"weekday": 1, "state": "off", "starts": "noon", "ends": "13:00"}]'),
  'usual_week_invalid', 'a time that is not one is refused, not an internal error');
select is(pg_temp.set_week(null, '{"weekday": 1}'), 'usual_week_invalid', 'the slots are an array');
select is(jsonb_array_length(pg_temp.week('paul')), 4, 'a refused write changes nothing');

-- ---- alternating weeks ---------------------------------------------------------------------------
select is(pg_temp.set_week('2026-10-19', '[{"week": 0, "weekday": 1, "state": "working"},
                                           {"week": 1, "weekday": 1, "state": "off"}]'),
  null, 'weeks A and B are set with an anchor');
select is((select anchor from api.usual_weeks where profile_id = pg_temp.id('paul')), '2026-10-19'::date,
  'the anchor is listed');
select is((select jsonb_agg(s ->> 'state' order by (s ->> 'week')::int) from jsonb_array_elements(pg_temp.week('paul')) s),
  '["working", "off"]'::jsonb, 'each week has its own place');
select is((select default_presence_state from api.members where id = pg_temp.id('paul')), 'working',
  'the single baseline is taken from week A');

select is(pg_temp.set_week(null, '[{"week": 0, "weekday": 1, "state": "working"},
                                   {"week": 1, "weekday": 1, "state": "off"}]'),
  null, 'alternating is switched off with week B still in the week');
select is((select anchor from api.usual_weeks where profile_id = pg_temp.id('paul')), null::date,
  'the anchor is gone');
select is((select jsonb_agg((s ->> 'week')::int order by (s ->> 'week')::int) from jsonb_array_elements(pg_temp.week('paul')) s),
  '[0, 1]'::jsonb, 'week B is kept for when alternating is switched on again');

select is(pg_temp.set_week(null, '[]'), null, 'an empty week clears it');
select is(pg_temp.week('paul'), '[]'::jsonb, 'nothing is left');
select is((select default_presence_state from api.members where id = pg_temp.id('paul')), null::text,
  'and the single baseline is cleared too');

-- ---- the previous app release's single baseline ------------------------------------------------
select lives_ok(format($$ select api.member_baseline_set(null, %L, 'home_office', 'HO') $$, pg_temp.id('paul')),
  'the single baseline is still written');
select is((select jsonb_agg((s ->> 'weekday')::int order by (s ->> 'weekday')::int)
             from jsonb_array_elements(pg_temp.week('paul')) s where s ->> 'label' = 'HO'),
  '[1, 2, 3, 4, 5]'::jsonb, 'it becomes the usual place from Monday to Friday');
select lives_ok(format($$ select api.member_baseline_set(null, %L, null, null) $$, pg_temp.id('paul')),
  'a null baseline is written');
select is(pg_temp.week('paul'), '[]'::jsonb, 'and clears the week');

-- ---- who may write -------------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.error_hint(format($$ select api.member_usual_week_set(%L, %L, null, '[]') $$,
                                    pg_temp.id('papa'), pg_temp.id('paul'))),
  'kiosk_forbidden', 'a kiosk changes no usual week');

reset role;
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($$ select api.member_usual_week_set(%L, %L, null, '[]') $$,
                                    pg_temp.id('emma'), pg_temp.id('paul'))),
  'guardian_required', 'a member does not set someone else''s week');
select is(pg_temp.error_hint(format($$ select api.member_usual_week_set(%L, %L, null,
                                    '[{"weekday": 4, "state": "off"}]') $$, pg_temp.id('paul'), pg_temp.id('paul'))),
  null, 'a member sets their own');

reset role;
select pg_temp.act_as_dev('b');
select is(pg_temp.set_week(null, '[]'), 'profile_not_found', 'another household''s member is not found');

-- ---- who may read --------------------------------------------------------------------------------
select is((select count(*)::int from api.usual_weeks where profile_id = pg_temp.id('paul')), 0,
  'another household sees no usual week of this one');
select is((select count(*)::int from app.usual_presence), 0, 'nor its rows');

reset role;
select pg_temp.act_as_dev('old');
select is((select count(*)::int from app.usual_presence), 0, 'a revoked device reads nothing');

reset role;
set local role anon;
select throws_ok($$ select * from api.usual_weeks $$, '42501', null, 'anonymous callers cannot read');
reset role;

-- ---- the assistant reads the usual weeks ---------------------------------------------------------
select pg_temp.act_as_dev('papa');
insert into snap select 'key', api.assistant_key_create(null, null, 'Claude');
reset role;
insert into snap select 'ctx', api.mcp_context((select v ->> 'token' from snap where k = 'key'), array['usual'], null, 1);
select is((select (u -> 'slots' -> 0 ->> 'state') from snap, jsonb_array_elements(v -> 'usual_weeks') u
            where k = 'ctx' and (u ->> 'profile_id')::uuid = pg_temp.id('paul')), 'off',
  'the part usual carries each member''s week');
insert into snap select 'ctx_plain', api.mcp_context((select v ->> 'token' from snap where k = 'key'), '{}', null, 1);
select ok(not ((select v from snap where k = 'ctx_plain') ? 'usual_weeks'), 'and only when asked for');

select * from finish();
rollback;
