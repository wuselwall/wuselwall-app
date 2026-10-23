begin;
select plan(34);

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
create temp table tok (name text primary key, id uuid, token text);
grant all on tok to public;
create temp table snap (k text primary key, v jsonb);
grant all on snap to public;

create function pg_temp.id(p_name text) returns uuid language sql as $$
  select id from ids where name = p_name
$$;
create function pg_temp.token(p_name text) returns text language sql as $$
  select token from tok where name = p_name
$$;

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

create function pg_temp.error_hint(p_sql text) returns text language plpgsql as $$
declare v_hint text;
begin
  execute p_sql;
  return 'no error';
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint;
  return v_hint;
end $$;

-- A valid payload: the sheet of specs/24, two lessons and a care row.
create function pg_temp.payload() returns jsonb language sql as $$
  select '{"format": "wuselwall-timetable/1", "member": "Emma", "class": "3b",
           "lessons": [{"day": "Mo", "period": 1, "subject": "Ma", "room": "R1"},
                       {"day": 2, "starts": "08:50", "ends": "09:35", "subject": "D"}],
           "care": [{"title": "Hort", "days": [1, 2], "starts": "13:30", "ends": "15:30"}]}'::jsonb
$$;

-- ---- household A: Papa (guardian, phone), Paul (adult member, phone), Emma (child), a kiosk ----
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;
insert into users values
  ('paul', app.create_auth_user('paul@example.org', 'longpassword1')),
  ('kiosk', app.create_auth_user('kiosk@devices.invalid', 'x1234567890'));
insert into app.profile (household_id, display_name, role, kind, auth_user_id)
  values (pg_temp.id('hh_a'), 'Paul', 'member', 'adult', (select usr from users where name = 'paul')),
         (pg_temp.id('hh_a'), 'Emma', 'member', 'child', null);
insert into ids select lower(p.display_name), p.id from app.profile p
 where p.household_id = pg_temp.id('hh_a') and p.display_name in ('Paul', 'Emma');

insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.id('hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = pg_temp.id('papa');
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  values (pg_temp.id('hh_a'), (select usr from users where name = 'paul'), 'Paul-Phone', 'personal',
          'adult', pg_temp.id('paul'));
insert into app.device (household_id, auth_user_id, label, class, register)
  values (pg_temp.id('hh_a'), (select usr from users where name = 'kiosk'), 'Kiosk', 'kiosk', 'kiosk');

-- ---- household B, made by hand ------------------------------------------------------------------
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into users values ('b', app.create_auth_user('b@example.org', 'longpassword1'));
insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_b'), 'Bea', 'guardian', usr from users where name = 'b';
insert into ids select 'bea', p.id from app.profile p where p.display_name = 'Bea';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.id('hh_b'), u.usr, 'B-Phone', 'personal', 'adult', pg_temp.id('bea')
    from users u where u.name = 'b';

insert into devs
  select n, d.auth_user_id, d.id, d.household_id, d.class
    from (values ('papa', 'A-Phone'), ('paul', 'Paul-Phone'), ('kiosk', 'Kiosk'), ('b', 'B-Phone')) v(n, label)
    join app.device d on d.label = v.label;

-- ---- keys ---------------------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
insert into tok (name, id, token)
  select 'papa', (r ->> 'id')::uuid, r ->> 'token' from (select api.assistant_key_create(null, null, 'Claude') r) s;
insert into tok (name, id, token)
  select 'papa_sc', (r ->> 'id')::uuid, r ->> 'token' from (select api.shortcut_token_create(null, null, 'iPhone') r) s;
reset role;
select pg_temp.act_as_dev('b');
insert into tok (name, id, token)
  select 'bea', (r ->> 'id')::uuid, r ->> 'token' from (select api.assistant_key_create(null, null, 'Bea''s') r) s;

-- ---- who may propose ----------------------------------------------------------------------------
reset role;
set local role anon;
select throws_ok(format($$ select api.mcp_propose(%L, 'timetable', '{}'::jsonb) $$, pg_temp.token('papa')), '42501',
  'permission denied for function mcp_propose', 'anonymous callers cannot propose');
reset role;
select pg_temp.act_as_dev('papa');
select throws_ok(format($$ select api.mcp_propose(%L, 'timetable', '{}'::jsonb) $$, pg_temp.token('papa')), '42501',
  'permission denied for function mcp_propose', 'a signed-in device does not call the assistant''s function');

reset role;
select pg_temp.act_as_service();
select is(pg_temp.error_hint(format($$ select api.mcp_propose(%L, 'timetable', %L::jsonb) $$,
  pg_temp.token('papa_sc'), pg_temp.payload()::text)), 'shortcut_token_invalid', 'a shortcut key is no assistant key');
select is(pg_temp.error_hint(format($$ select api.mcp_propose(%L, 'timetable', %L::jsonb) $$,
  'wwa_nope', pg_temp.payload()::text)), 'shortcut_token_invalid', 'an unknown key is refused');

-- ---- the shape check ----------------------------------------------------------------------------
select is(pg_temp.error_hint(format($$ select api.mcp_propose(%L, 'shopping', %L::jsonb) $$,
  pg_temp.token('papa'), pg_temp.payload()::text)), 'proposal_invalid', 'only timetables for now');
select is(pg_temp.error_hint(format($$ select api.mcp_propose(%L, 'timetable', '{"member": "Emma"}'::jsonb) $$,
  pg_temp.token('papa'))), 'proposal_invalid', 'no lessons, no proposal');
select is(pg_temp.error_hint(format($$ select api.mcp_propose(%L, 'timetable', '{"lessons": [{"period": 1, "subject": "Ma"}]}'::jsonb) $$,
  pg_temp.token('papa'))), 'proposal_invalid', 'a lesson needs a day');
select is(pg_temp.error_hint(format($$ select api.mcp_propose(%L, 'timetable', '{"lessons": [{"day": 9, "period": 1, "subject": "Ma"}]}'::jsonb) $$,
  pg_temp.token('papa'))), 'proposal_invalid', 'a day is 1-7 or a name');
select is(pg_temp.error_hint(format($$ select api.mcp_propose(%L, 'timetable',
  jsonb_build_object('lessons', jsonb_build_array(jsonb_build_object('day', 1, 'period', 1, 'subject', repeat('x', 61))))) $$,
  pg_temp.token('papa'))), 'proposal_invalid', 'strings are bounded');
select is(pg_temp.error_hint(format($$ select api.mcp_propose(%L, 'timetable',
  (select jsonb_build_object('lessons', jsonb_agg(jsonb_build_object('day', 1, 'period', 1, 'subject', 'Ma'))) from generate_series(1, 201))) $$,
  pg_temp.token('papa'))), 'proposal_invalid', 'at most 200 lessons');
select is(pg_temp.error_hint(format($$ select api.mcp_propose(%L, 'timetable', '{"format": "something-else/9", "lessons": [{"day": 1, "period": 1, "subject": "Ma"}]}'::jsonb) $$,
  pg_temp.token('papa'))), 'proposal_invalid', 'another format is refused');
select is(pg_temp.error_hint(format($$ select api.mcp_propose(%L, 'timetable', '{"grid": {"Mo": ["Ma", null, "D"], "Di": []}}'::jsonb) $$,
  pg_temp.token('papa'))), 'no error', 'a grid is a payload too');
reset role;
select is((select count(*) from app.proposal), 1::bigint, 'and it was stored');
delete from app.proposal;
select pg_temp.act_as_service();

-- ---- a proposal ---------------------------------------------------------------------------------
insert into snap select 'first', api.mcp_propose(pg_temp.token('papa'), 'timetable', pg_temp.payload(),
  'Stundenplan Emma, 2 Stunden', 'claude-1');
select is((select v ->> 'created' from snap where k = 'first'), 'true', 'the first call creates');
insert into snap select 'again', api.mcp_propose(pg_temp.token('papa'), 'timetable', pg_temp.payload(),
  'Stundenplan Emma, 2 Stunden', 'claude-1');
select is((select v ->> 'created' from snap where k = 'again'), 'false', 'the same client key creates nothing');
select is((select v ->> 'id' from snap where k = 'again'), (select v ->> 'id' from snap where k = 'first'),
  'and returns the first proposal');
reset role;
select is((select count(*) from app.proposal where household_id = pg_temp.id('hh_a')), 1::bigint, 'one row');
select is((select assistant_label from app.proposal where household_id = pg_temp.id('hh_a')), 'Claude',
  'the proposal names the key, so the family knows which assistant spoke');
select is((select proposed_by_profile_id from app.proposal where household_id = pg_temp.id('hh_a')), pg_temp.id('papa'),
  'and the person whose key it is');
select is((select count(*) from app.audit_log where entity_type = 'proposal' and action = 'create' and origin = 'mcp'
             and actor_profile_id = pg_temp.id('papa')
             and entity_id = (select (v ->> 'id')::uuid from snap where k = 'first')), 1::bigint,
  'the audit row says mcp, on Papa''s behalf');
select is((select count(*) from app.timetable), 0::bigint, 'nothing of the household changed');

-- Five open proposals per person, then the limit.
select pg_temp.act_as_service();
select api.mcp_propose(pg_temp.token('papa'), 'timetable', pg_temp.payload(), null, 'k2');
select api.mcp_propose(pg_temp.token('papa'), 'timetable', pg_temp.payload(), null, 'k3');
select api.mcp_propose(pg_temp.token('papa'), 'timetable', pg_temp.payload(), null, 'k4');
select api.mcp_propose(pg_temp.token('papa'), 'timetable', pg_temp.payload(), null, 'k5');
select is(pg_temp.error_hint(format($$ select api.mcp_propose(%L, 'timetable', %L::jsonb, null, 'k6') $$,
  pg_temp.token('papa'), pg_temp.payload()::text)), 'proposal_limit', 'the sixth open proposal is refused');
reset role;
delete from app.proposal where client_key in ('k2', 'k3', 'k4', 'k5');

-- ---- who sees it --------------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
select is((select count(*) from api.proposals), 1::bigint, 'Papa sees the proposal');
select is((select status from api.proposals), 'open', 'as open');
reset role;
select pg_temp.act_as_dev('b');
select is((select count(*) from api.proposals), 0::bigint, 'another household sees nothing');

-- ---- the verdict --------------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.error_hint(format($$ select api.proposal_resolve(%L, %L, 'applied') $$, pg_temp.id('papa'),
  (select v ->> 'id' from snap where k = 'first'))), 'kiosk_forbidden', 'not from the wall');
reset role;
select pg_temp.act_as_dev('paul');
select is(pg_temp.error_hint(format($$ select api.proposal_resolve(null, %L, 'applied') $$,
  (select v ->> 'id' from snap where k = 'first'))), 'guardian_required', 'a member decides nothing');
reset role;
select pg_temp.act_as_dev('b');
select is(pg_temp.error_hint(format($$ select api.proposal_resolve(null, %L, 'applied') $$,
  (select v ->> 'id' from snap where k = 'first'))), 'proposal_not_found', 'another household''s guardian neither');
reset role;
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($$ select api.proposal_resolve(null, %L, 'maybe') $$,
  (select v ->> 'id' from snap where k = 'first'))), 'proposal_invalid', 'applied or rejected, nothing else');
select is(pg_temp.error_hint(format($$ select api.proposal_resolve(null, %L, 'applied') $$,
  (select v ->> 'id' from snap where k = 'first'))), 'no error', 'Papa applies it');
select is((select status from api.proposals), 'applied', 'and the view says so');
select is(pg_temp.error_hint(format($$ select api.proposal_resolve(null, %L, 'rejected') $$,
  (select v ->> 'id' from snap where k = 'first'))), 'proposal_not_open', 'a verdict is given once');
reset role;
select is((select count(*) from app.audit_log where entity_type = 'proposal' and action = 'apply' and origin = 'ui'
             and actor_profile_id = pg_temp.id('papa')), 1::bigint, 'the apply is Papa''s own act in the audit log');

-- An open proposal past its date reads as expired, and cannot be resolved.
reset role;
update app.proposal set status = 'open', expires_at = now() - interval '1 day'
 where id = (select (v ->> 'id')::uuid from snap where k = 'first');
select pg_temp.act_as_dev('papa');
select is((select status from api.proposals), 'expired', 'an old proposal reads as expired');

select * from finish();
rollback;
