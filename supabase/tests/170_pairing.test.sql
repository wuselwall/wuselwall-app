begin;
select plan(53);

-- Pairing (J3/J5): the new device starts a request, a guardian approves it, the device collects
-- its credentials once. Everything runs as the database owner except the calls made by the
-- device (anon) and by a guardian's phone (authenticated), which switch role inside the helpers.

delete from app.enrol_attempt;

-- ---- fixtures: two households, guardians on personal phones, a child, a shared tablet, a kiosk
create temp table fx (name text primary key, id uuid not null);
insert into fx select n, gen_random_uuid() from unnest(array[
  'hh1', 'hh2', 'gp1', 'gp2', 'gp3', 'cp1', 'dg1', 'dg2', 'dg3', 'dchild', 'dshared', 'dkiosk',
  'u_g1', 'u_g2', 'u_g3', 'u_child', 'u_s', 'u_k']) n;
update fx set id = app.create_auth_user(name || '@example.org', 'longpassword1') where name like 'u\_%';

create function pg_temp.fid(p text) returns uuid language sql as $$
  select id from fx where name = p
$$;

insert into app.household (id, name) values (pg_temp.fid('hh1'), 'Huser'), (pg_temp.fid('hh2'), 'Nachbarn');
insert into app.profile (id, household_id, display_name, color, role, auth_user_id, pin_hash) values
  (pg_temp.fid('gp1'), pg_temp.fid('hh1'), 'Papa', '#112233', 'guardian', pg_temp.fid('u_g1'), null),
  (pg_temp.fid('gp2'), pg_temp.fid('hh2'), 'Nachbar', '#112233', 'guardian', pg_temp.fid('u_g2'), null),
  (pg_temp.fid('gp3'), pg_temp.fid('hh1'), 'Mama', '#112233', 'guardian', pg_temp.fid('u_g3'), null),
  (pg_temp.fid('cp1'), pg_temp.fid('hh1'), 'Anna', '#ff8800', 'member', null, null);
insert into app.device (id, household_id, auth_user_id, label, class, register, profile_id) values
  (pg_temp.fid('dg1'), pg_temp.fid('hh1'), pg_temp.fid('u_g1'), 'Papas Handy', 'personal', 'adult', pg_temp.fid('gp1')),
  (pg_temp.fid('dg2'), pg_temp.fid('hh2'), pg_temp.fid('u_g2'), 'Nachbar Handy', 'personal', 'adult', pg_temp.fid('gp2')),
  (pg_temp.fid('dg3'), pg_temp.fid('hh1'), pg_temp.fid('u_g3'), 'Mamas Handy', 'personal', 'adult', pg_temp.fid('gp3')),
  (pg_temp.fid('dchild'), pg_temp.fid('hh1'), pg_temp.fid('u_child'), 'Annas Handy', 'personal', 'kid', pg_temp.fid('cp1')),
  (pg_temp.fid('dshared'), pg_temp.fid('hh1'), pg_temp.fid('u_s'), 'Kinder-iPad', 'shared', 'kid', null),
  (pg_temp.fid('dkiosk'), pg_temp.fid('hh1'), pg_temp.fid('u_k'), 'Wand', 'kiosk', 'kiosk', null);

-- ---- helpers --------------------------------------------------------------------------------
create temp table rq (name text primary key, id uuid, secret text, code text);

-- A start from one forwarded-for client, as the device calls it (anon).
create function pg_temp.start_raw(p_ip text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.headers', jsonb_build_object('x-forwarded-for', p_ip)::text, true);
  execute 'set local role anon';
  r := api.pairing_start();
  execute 'reset role';
  return r;
end $$;

create function pg_temp.start_req(p_name text, p_ip text) returns void language plpgsql as $$
declare r jsonb := pg_temp.start_raw(p_ip);
begin
  insert into rq values (p_name, (r ->> 'request_id')::uuid, r ->> 'secret', r ->> 'code');
end $$;

create function pg_temp.poll_raw(p_id uuid, p_secret text, p_ip text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.headers', jsonb_build_object('x-forwarded-for', p_ip)::text, true);
  execute 'set local role anon';
  r := api.pairing_poll(p_id, p_secret);
  execute 'reset role';
  return r;
end $$;

-- Polls a named request with its own secret, or with a wrong one when p_wrong.
create function pg_temp.poll(p_name text, p_ip text, p_wrong boolean default false) returns jsonb
language plpgsql as $$
declare q rq;
begin
  select * into q from rq where name = p_name;
  return pg_temp.poll_raw(q.id, case when p_wrong then 'wrong' else q.secret end, p_ip);
end $$;

-- A guardian's phone approves (authenticated, with the device's claims).
create function pg_temp.approve(p_dev uuid, p_hh uuid, p_code text, p_label text, p_kind text, p_profile uuid,
                                p_actor uuid default null)
returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('role', 'authenticated', 'household_id', p_hh, 'device_id', p_dev)::text, true);
  execute 'set local role authenticated';
  r := api.pairing_approve(p_actor, p_code, p_label, p_kind, p_profile);
  execute 'reset role';
  return r;
end $$;

create function pg_temp.approve_raw(p_dev uuid, p_hh uuid, p_code text) returns jsonb
language plpgsql as $$
begin
  return pg_temp.approve(p_dev, p_hh, p_code, 'Tablet', 'family_tablet', null);
end $$;

-- Makes the grants of the helpers' tables available to the roles that run the calls.
grant all on fx, rq to public;

-- ---- start ------------------------------------------------------------------------------------
select pg_temp.start_req('R1', '198.51.100.1');
select ok((select secret from rq where name = 'R1') ~ '^[0-9a-f]{64}$', 'the secret is 32 random bytes, hex');
select ok((select code from rq where name = 'R1') ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$',
  'the code has 8 characters from the unambiguous alphabet');
select ok(exists (select 1 from app.pairing_request r join rq on rq.id = r.id
                   where rq.name = 'R1' and r.secret_hash = app.pairing_hash(rq.secret)
                     and r.code_hash = app.pairing_hash(rq.code)),
  'the request stores the sha256 of the secret and of the code');
select ok(not exists (select 1 from app.pairing_request r join rq on true
                       where r.secret_hash = rq.secret or r.code_hash = rq.code),
  'neither the secret nor the code is stored in clear');
select ok((select expires_at from app.pairing_request where id = (select id from rq where name = 'R1'))
            between now() + interval '9 minutes 50 seconds' and now() + interval '10 minutes 10 seconds',
  'a request lives ten minutes');

-- ---- poll: invalid, pending, expired -------------------------------------------------------
select is(pg_temp.poll('R1', '198.51.100.1', true) ->> 'status', 'invalid', 'a wrong secret is invalid');
select is(pg_temp.poll_raw(gen_random_uuid(), (select secret from rq where name = 'R1'), '198.51.100.1') ->> 'status',
  'invalid', 'an unknown request id is invalid');
select is(pg_temp.poll('R1', '198.51.100.1') ->> 'status', 'pending', 'a fresh request polls as pending');

select pg_temp.start_req('R2', '198.51.100.2');
update app.pairing_request set expires_at = now() - interval '1 minute'
 where id = (select id from rq where name = 'R2');
select is(pg_temp.poll('R2', '198.51.100.2') ->> 'status', 'expired', 'an expired request polls as expired');

-- ---- approval refusals ----------------------------------------------------------------------
select throws_ok(
  format($$ select pg_temp.approve(%L, %L, %L, 'Tablet', 'kid_tablet', null) $$,
    pg_temp.fid('dchild'), pg_temp.fid('hh1'), (select code from rq where name = 'R1')),
  '42501', 'guardian required', 'a child on a personal phone cannot approve');
select throws_ok(
  format($$ select pg_temp.approve(%L, %L, %L, 'Tablet', 'kid_tablet', null, %L) $$,
    pg_temp.fid('dshared'), pg_temp.fid('hh1'), (select code from rq where name = 'R1'), pg_temp.fid('gp1')),
  '42501', 'guardian required', 'a shared device cannot approve');
select throws_ok(
  format($$ select pg_temp.approve(%L, %L, %L, 'Tablet', 'kid_tablet', null, %L) $$,
    pg_temp.fid('dkiosk'), pg_temp.fid('hh1'), (select code from rq where name = 'R1'), pg_temp.fid('gp1')),
  '42501', 'guardian required', 'a kiosk cannot approve');
select throws_ok(
  format($$ select pg_temp.approve(%L, %L, %L, 'Tablet', 'tablet_for_pets', null) $$,
    pg_temp.fid('dg1'), pg_temp.fid('hh1'), (select code from rq where name = 'R1')),
  '22023', 'kind invalid', 'an unknown kind is refused');
select throws_ok(
  format($$ select pg_temp.approve(%L, %L, %L, '   ', 'kid_tablet', null) $$,
    pg_temp.fid('dg1'), pg_temp.fid('hh1'), (select code from rq where name = 'R1')),
  '22023', 'label required', 'an empty name is refused');
select throws_ok(
  format($$ select pg_temp.approve(%L, %L, %L, 'Handy', 'child_phone', %L) $$,
    pg_temp.fid('dg1'), pg_temp.fid('hh1'), (select code from rq where name = 'R1'), pg_temp.fid('gp1')),
  '22023', 'child required', 'a child phone needs a child of the household, not a guardian');
select is(
  pg_temp.approve(pg_temp.fid('dg1'), pg_temp.fid('hh1'), 'ZZZZZZZZ', 'Tablet', 'kid_tablet', null) ->> 'reason',
  'code_invalid', 'a wrong code is reported, not raised');
select is(
  pg_temp.approve(pg_temp.fid('dg1'), pg_temp.fid('hh1'), (select code from rq where name = 'R2'), 'Tablet', 'kid_tablet', null) ->> 'reason',
  'code_invalid', 'an expired request cannot be approved');

-- ---- a successful approval of a kid's tablet -------------------------------------------------
create temp table ap1 as select pg_temp.approve(pg_temp.fid('dg1'), pg_temp.fid('hh1'),
  (select lower(substr(code, 1, 4) || '-' || substr(code, 5)) from rq where name = 'R1'),
  'Kinder-iPad', 'kid_tablet', null) r;
grant all on ap1 to public;
select is((select r ->> 'ok' from ap1), 'true', 'a guardian approves with the code in any form (lower case, hyphen)');
select is((select r ->> 'needs_pin' from ap1), 'true', 'a guardian without a PIN is asked to set one');
select ok(exists (select 1 from app.device where id = (select (r ->> 'device_id')::uuid from ap1)
                   and household_id = pg_temp.fid('hh1') and class = 'shared' and register = 'kid'
                   and profile_id is null and label = 'Kinder-iPad'),
  'kid tablet: shared device, kid register, no bound profile');
select is((select count(*)::int from app.audit_log
            where action = 'pair' and entity_id = (select (r ->> 'device_id')::uuid from ap1)), 1,
  'the approval is audited');
select is((select pg_temp.approve(pg_temp.fid('dg2'), pg_temp.fid('hh2'),
             (select code from rq where name = 'R1'), 'Tablet', 'kid_tablet', null) ->> 'reason'),
  'code_invalid', 'a guardian of another household cannot approve a request already approved');

-- The device collects its credentials: once.
create temp table got as select pg_temp.poll('R1', '198.51.100.1') r;
grant all on got to public;
select is((select r ->> 'status' from got), 'approved', 'the device collects the approval');
select is((select r ->> 'class' from got), 'shared', 'credentials come with the device class');
select is((select r ->> 'register' from got), 'kid', 'and its register');
select is((select r ->> 'household_name' from got), 'Huser', 'and the household name');
select ok((select r ->> 'email' from got) = 'device-' || (select (r ->> 'device_id')::uuid::text from ap1) || '@devices.wuselwall.invalid',
  'the device signs in with its own Auth user');
select ok((select encrypted_password = extensions.crypt((select r ->> 'password' from got), encrypted_password)
             from auth.users where email = (select r ->> 'email' from got)),
  'the password is set on the Auth user, bcrypt-hashed');
select is(pg_temp.poll('R1', '198.51.100.1') ->> 'status', 'invalid', 'the credentials come once: the next poll is invalid');

-- The access-token hook gives the device its household claims.
select is((app.custom_access_token_hook(jsonb_build_object(
             'user_id', (select auth_user_id from app.device where id = (select (r ->> 'device_id')::uuid from ap1)),
             'claims', '{}'::jsonb)) -> 'claims' ->> 'household_id'),
  pg_temp.fid('hh1')::text, 'the created device gets household claims from the access-token hook');
select is((app.custom_access_token_hook(jsonb_build_object(
             'user_id', (select auth_user_id from app.device where id = (select (r ->> 'device_id')::uuid from ap1)),
             'claims', '{}'::jsonb)) -> 'claims' ->> 'device_class'),
  'shared', 'and its class');

-- ---- the other kinds, and the PIN question ---------------------------------------------------
select pg_temp.start_req('R3', '198.51.100.3');
select pg_temp.start_req('R4', '198.51.100.4');
select pg_temp.start_req('R5', '198.51.100.5');

create temp table ap3 as select pg_temp.approve(pg_temp.fid('dg1'), pg_temp.fid('hh1'),
  (select code from rq where name = 'R3'), 'Wanddisplay', 'wall_display', null) r;
grant all on ap3 to public;
select is((select r ->> 'ok' from ap3), 'true', 'wall display: approved');
select ok(exists (select 1 from app.device where id = (select (r ->> 'device_id')::uuid from ap3)
                   and class = 'kiosk' and register = 'kiosk'), 'wall display: kiosk class and register');
select is((select r ->> 'status' from (select pg_temp.poll('R3', '198.51.100.3') r) x), 'approved',
  'wall display: collected by the device');

create temp table ap4 as select pg_temp.approve(pg_temp.fid('dg1'), pg_temp.fid('hh1'),
  (select code from rq where name = 'R4'), 'Annas Handy', 'child_phone', pg_temp.fid('cp1')) r;
grant all on ap4 to public;
select ok(exists (select 1 from app.device where id = (select (r ->> 'device_id')::uuid from ap4)
                   and class = 'personal' and register = 'kid' and profile_id = pg_temp.fid('cp1')),
  'child phone: personal device, kid register, bound to the child');
select is((app.custom_access_token_hook(jsonb_build_object(
             'user_id', (select auth_user_id from app.device where id = (select (r ->> 'device_id')::uuid from ap4)),
             'claims', '{}'::jsonb)) -> 'claims' ->> 'profile_id'),
  pg_temp.fid('cp1')::text, 'child phone: the hook binds the profile');

update app.profile set pin_hash = extensions.crypt('123456', extensions.gen_salt('bf', 4))
 where id = pg_temp.fid('gp1');
create temp table ap5 as select pg_temp.approve(pg_temp.fid('dg1'), pg_temp.fid('hh1'),
  (select code from rq where name = 'R5'), 'Tablet', 'family_tablet', null) r;
grant all on ap5 to public;
select is((select r ->> 'needs_pin' from ap5), 'false', 'a guardian with a PIN is not asked again');
select ok(exists (select 1 from app.device where id = (select (r ->> 'device_id')::uuid from ap5)
                   and class = 'shared' and register = 'adult'), 'family tablet: shared device, adult register');

-- ---- guardian rate limit: five wrong codes, then refused even for the right one -------------
select pg_temp.start_req('R6', '198.51.100.6');
create temp table wrong as select pg_temp.approve_raw(pg_temp.fid('dg3'), pg_temp.fid('hh1'), 'ZZZZZZZZ') r
  from generate_series(1, 5);
grant all on wrong to public;
select is((select count(*) from wrong where r ->> 'reason' = 'code_invalid'), 5::bigint,
  'five wrong codes are counted');
select is(pg_temp.approve_raw(pg_temp.fid('dg3'), pg_temp.fid('hh1'), (select code from rq where name = 'R6')) ->> 'reason',
  'rate_limited', 'after five wrong codes even the right one is refused');
select is(pg_temp.poll('R6', '198.51.100.6') ->> 'status', 'pending', 'the refused request stays pending');

-- ---- device poll rate limit -----------------------------------------------------------------
select pg_temp.start_req('R7', '198.51.100.9');
create temp table wpoll as select pg_temp.poll_raw((select id from rq where name = 'R7'), 'nope', '198.51.100.9') r
  from generate_series(1, 10);
grant all on wpoll to public;
select is((select count(*) from wpoll where r ->> 'status' = 'invalid'), 10::bigint, 'ten wrong secrets are counted');
select is(pg_temp.poll('R7', '198.51.100.9') ->> 'status', 'rate_limited', 'then the poll is rate limited');

-- ---- approved, then expired before collection; revoked before collection --------------------
select pg_temp.start_req('R8', '198.51.100.8');
select pg_temp.approve(pg_temp.fid('dg1'), pg_temp.fid('hh1'), (select code from rq where name = 'R8'), 'Tablet', 'family_tablet', null);
update app.pairing_request set expires_at = now() - interval '1 minute' where id = (select id from rq where name = 'R8');
select is(pg_temp.poll('R8', '198.51.100.8') ->> 'status', 'expired', 'an approval not collected in time expires');

select pg_temp.start_req('R9', '198.51.100.12');
select pg_temp.approve(pg_temp.fid('dg1'), pg_temp.fid('hh1'), (select code from rq where name = 'R9'), 'Tablet', 'family_tablet', null);
select is(pg_temp.poll('R9', '198.51.100.12') ->> 'status', 'approved', 'an approved request is collected');
select pg_temp.start_req('R10', '198.51.100.13');
create temp table rev as select (pg_temp.approve(pg_temp.fid('dg1'), pg_temp.fid('hh1'), (select code from rq where name = 'R10'), 'Tablet', 'family_tablet', null) ->> 'device_id')::uuid d;
grant all on rev to public;
update app.device set revoked_at = now() where id = (select d from rev);
select is(pg_temp.poll('R10', '198.51.100.13') ->> 'status', 'invalid', 'a device revoked before collection gets nothing');

-- A revoked guardian phone is refused on its next call.
update app.device set revoked_at = now() where id = pg_temp.fid('dg3');
select throws_ok(
  format($$ select pg_temp.approve(%L, %L, %L, 'Tablet', 'family_tablet', null) $$,
    pg_temp.fid('dg3'), pg_temp.fid('hh1'), (select code from rq where name = 'R1')),
  '42501', 'device not usable', 'a revoked phone cannot approve');

-- ---- the legacy enrolment keeps its own bucket ----------------------------------------------
insert into app.enrol_attempt (client_key, success)
  select 'pair:192.0.2.5', false from generate_series(1, 30);
select is((select api.enrol_device('AAAAAAA1') ->> 'reason'), 'code_invalid',
  'pairing failures do not lock out the legacy code entry');

-- ---- the start limits -----------------------------------------------------------------------
create temp table sx as select pg_temp.start_raw('198.51.100.20') r from generate_series(1, 11);
grant all on sx to public;
select is((select count(*) from sx where r ->> 'ok' = 'true'), 10::bigint, 'ten requests per client in ten minutes');
select is((select count(*) from sx where r ->> 'reason' = 'rate_limited'), 1::bigint, 'the eleventh is refused, not raised');
insert into app.enrol_attempt (client_key, success)
  select 'pair:203.0.113.99', true from generate_series(1, 300);
select is(pg_temp.start_raw('198.51.100.21') ->> 'reason', 'rate_limited', 'overall, two hundred requests in ten minutes stop new ones');

-- ---- row level security: nothing reads the requests but the owner ---------------------------
set local role anon;
select throws_ok($$ select count(*) from app.pairing_request $$, '42501', null, 'anon cannot read pairing requests');
reset role;
set local role authenticated;
select throws_ok($$ select count(*) from app.pairing_request $$, '42501', null, 'a signed-in phone cannot read pairing requests');
reset role;

select * from finish();
rollback;
