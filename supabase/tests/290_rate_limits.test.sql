begin;
select plan(56);

-- Rate limits and the client key (20261102120000, security review 2026-11-01 F5 and F14): the
-- per-client key comes from a header the gateway sets, never from the first forwarded entry;
-- the global buckets count failures only; the timetable scan needs a household device.

delete from app.enrol_attempt;
delete from app.pairing_attempt;
delete from app.invitation_attempt;
delete from app.founder_attempt;
delete from app.timetable_scan_attempt;

create function pg_temp.headers(p jsonb) returns void language plpgsql as $$
begin
  perform set_config('request.headers', p::text, true);
end $$;

-- ---- the client key ---------------------------------------------------------------------------
-- Without the stack's setting, the gateway header is ignored (a client could have sent it).
select set_config('app.client_ip_header', '', true);
select pg_temp.headers('{}'::jsonb);
select is(app.request_client_key(), 'unknown', 'no header at all: unknown');
select pg_temp.headers('{"x-forwarded-for": "203.0.113.5"}'::jsonb);
select is(app.request_client_key(), '203.0.113.5', 'a single forwarded entry is the key');
select is(app.client_key(), '203.0.113.5', 'client_key is the same key under its older name');
select pg_temp.headers('{"x-forwarded-for": "198.51.100.7, 203.0.113.5, 172.18.0.2"}'::jsonb);
select is(app.request_client_key(), '203.0.113.5',
  'the last public entry wins, not the first one (which the client wrote) and not the proxy behind it');
select pg_temp.headers('{"x-forwarded-for": "198.51.100.7, 10.0.0.9"}'::jsonb);
select is(app.request_client_key(), '198.51.100.7', 'a private last entry is skipped for the public one before it');
select pg_temp.headers('{"x-forwarded-for": "10.0.0.9"}'::jsonb);
select is(app.request_client_key(), '10.0.0.9', 'only private entries: the last one');
select pg_temp.headers('{"x-forwarded-for": "spoof, 2001:db8::7, fe80::1"}'::jsonb);
select is(app.request_client_key(), '2001:db8::/64', 'IPv6: the last public entry, as its /64; link-local is private');
select pg_temp.headers('{"x-forwarded-for": "198.51.100.7, 172.18.0.2", "x-wuselwall-client-ip": "203.0.113.77"}'::jsonb);
select is(app.request_client_key(), '198.51.100.7', 'without the setting the gateway header is ignored');
select pg_temp.headers('{"x-forwarded-for": "198.51.100.7, 172.18.0.2", "x-wuselwall-client-ip": "203.0.113.77", "cf-connecting-ip": "203.0.113.9"}'::jsonb);
select is(app.request_client_key(), '203.0.113.9', 'without the setting, Cloudflare''s header wins over X-Forwarded-For');
-- With the setting (volumes/wuselwall/client-ip.sql on the compose stack) the gateway header wins.
select set_config('app.client_ip_header', 'x-wuselwall-client-ip', true);
select is(app.request_client_key(), '203.0.113.77', 'with the setting the gateway header wins over everything');
select pg_temp.headers('{"x-wuselwall-client-ip": "  ", "cf-connecting-ip": "203.0.113.9"}'::jsonb);
select is(app.request_client_key(), '203.0.113.9', 'a blank gateway header is as good as none');
select pg_temp.headers('{"x-wuselwall-client-ip": "2001:db8:1:2:3:4:5:6"}'::jsonb);
select is(app.request_client_key(), '2001:db8:1:2::/64', 'an IPv6 client is keyed by its /64');
select pg_temp.headers('{"x-wuselwall-client-ip": "2001:db8:1:2:ffff::1"}'::jsonb);
select is(app.request_client_key(), '2001:db8:1:2::/64', 'another address of the same /64 is the same key');
select is(app.client_bucket_key('203.0.113.5'), '203.0.113.5', 'an IPv4 key is the address');
select is(app.client_bucket_key(' nonsense '), 'nonsense', 'a non-address is kept as it is');
select ok(not app.public_address('192.168.1.4') and not app.public_address('100.64.3.3') and not app.public_address('nonsense'),
  'private ranges and non-addresses are not public');
select ok(app.public_address('203.0.113.5') and app.public_address('2001:db8::1'), 'public addresses are public');

-- ---- fixtures: one household, a guardian's phone, a kid tablet ---------------------------------
create temp table fx (name text primary key, id uuid not null);
insert into fx select n, gen_random_uuid() from unnest(array['hh', 'gp', 'dg', 'dt', 'u_g', 'u_t', 'u_x']) n;
update fx set id = app.create_auth_user(name || '@example.org', 'longpassword1') where name like 'u\_%';
create function pg_temp.fid(p text) returns uuid language sql as $$ select id from fx where name = p $$;

insert into app.household (id, name) values (pg_temp.fid('hh'), 'Limits');
insert into app.profile (id, household_id, display_name, color, role, auth_user_id) values
  (pg_temp.fid('gp'), pg_temp.fid('hh'), 'Papa', '#112233', 'guardian', pg_temp.fid('u_g'));
insert into app.device (id, household_id, auth_user_id, label, class, register, profile_id) values
  (pg_temp.fid('dg'), pg_temp.fid('hh'), pg_temp.fid('u_g'), 'Papas Handy', 'personal', 'adult', pg_temp.fid('gp')),
  (pg_temp.fid('dt'), pg_temp.fid('hh'), pg_temp.fid('u_t'), 'Kinder-iPad', 'shared', 'kid', null);

-- A device of the household, with its claims.
create function pg_temp.as_device(p_user text, p_dev text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.fid(p_user), 'role', 'authenticated',
    'household_id', pg_temp.fid('hh'), 'device_id', pg_temp.fid(p_dev))::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
-- A signed-in account without any household claims (sign-up is open once a family exists).
create function pg_temp.as_stranger() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.fid('u_x'), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
create function pg_temp.as_anon(p_key text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  perform pg_temp.headers(jsonb_build_object('x-wuselwall-client-ip', p_key));
  perform set_config('role', 'anon', true);
end $$;
create function pg_temp.owner() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.headers', '', true);
  perform set_config('role', 'none', true);
end $$;

-- ---- the legacy enrolment keys by the gateway's header -----------------------------------------
select pg_temp.as_anon('203.0.113.1');
select pg_temp.headers('{"x-wuselwall-client-ip": "203.0.113.1", "x-forwarded-for": "198.51.100.1"}'::jsonb);
select api.enrol_device('WRONG' || g) from generate_series(1, 5) g;
select pg_temp.headers('{"x-wuselwall-client-ip": "203.0.113.1", "x-forwarded-for": "198.51.100.2"}'::jsonb);
select is(api.enrol_device('WRONG6') ->> 'reason', 'rate_limited',
  'five failures lock the client the gateway names, whatever X-Forwarded-For says');
select pg_temp.headers('{"x-wuselwall-client-ip": "203.0.113.2", "x-forwarded-for": "198.51.100.1"}'::jsonb);
select is(api.enrol_device('WRONG7') ->> 'reason', 'code_invalid', 'another client is answered');
select api.enrol_device('WRONG' || g) from generate_series(1, 5) g, lateral pg_temp.headers(jsonb_build_object('x-wuselwall-client-ip', '2001:db8:9:9::' || g));
select pg_temp.headers('{"x-wuselwall-client-ip": "2001:db8:9:9:abcd::1"}'::jsonb);
select is(api.enrol_device('WRONG6') ->> 'reason', 'rate_limited',
  'five failures from five addresses of one IPv6 /64 lock the whole /64');
select pg_temp.owner();
select is((select count(*)::int from app.enrol_attempt where client_key = '203.0.113.1' and not success), 5,
  'the attempts are logged under the gateway key');
insert into app.enrol_attempt (client_key, success) select 'other-' || g, false from generate_series(1, 100) g;
select pg_temp.as_anon('203.0.113.3');
select is(api.enrol_device('WRONG8') ->> 'reason', 'code_invalid', 'a hundred failures from elsewhere do not stop enrolment');
select pg_temp.owner();
insert into app.enrol_attempt (client_key, success) select 'other-' || g, false from generate_series(101, 1000) g;
select pg_temp.as_anon('203.0.113.4');
select is(api.enrol_device('WRONG9') ->> 'reason', 'rate_limited', 'a thousand recent failures do');
select pg_temp.owner();
delete from app.enrol_attempt;

-- ---- pairing: starts count starts, polls count failures per client and per request ------------
create function pg_temp.start(p_key text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.as_anon(p_key);
  r := api.pairing_start();
  perform pg_temp.owner();
  return r;
end $$;
create function pg_temp.poll(p_key text, p_id uuid, p_secret text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.as_anon(p_key);
  r := api.pairing_poll(p_id, p_secret);
  perform pg_temp.owner();
  return r;
end $$;

create temp table req as select pg_temp.start('203.0.113.10') as r;
select is((select r ->> 'ok' from req), 'true', 'a device starts a pairing');

-- Random ids from many addresses: the device still polls, and starts still work.
insert into app.pairing_attempt (client_key, success) select 'poll:198.51.100.' || g, false from generate_series(1, 250) g;
select is(pg_temp.poll('203.0.113.10', (select (r ->> 'request_id')::uuid from req), (select r ->> 'secret' from req)) ->> 'status',
  'pending', 'failed polls from elsewhere do not stop the device''s own poll');
select is(pg_temp.start('203.0.113.11') ->> 'ok', 'true', 'failed polls from elsewhere do not stop a start');
select is((select count(*) from app.pairing_request where client_key = '203.0.113.11'), 1::bigint,
  'the start is keyed by the gateway header');

-- Wrong secrets against one request from many addresses: that request is held, others are not.
select count(*) from generate_series(1, 20) g,
  lateral pg_temp.poll('198.51.100.' || g, (select (r ->> 'request_id')::uuid from req), 'nope');
select is(pg_temp.poll('203.0.113.10', (select (r ->> 'request_id')::uuid from req), (select r ->> 'secret' from req)) ->> 'status',
  'rate_limited', 'twenty wrong secrets against one request hold that request for a while');
create temp table req2 as select pg_temp.start('203.0.113.12') as r;
select is(pg_temp.poll('203.0.113.12', (select (r ->> 'request_id')::uuid from req2), (select r ->> 'secret' from req2)) ->> 'status',
  'pending', 'another request polls as usual');
select is((select count(*)::int from app.pairing_attempt where client_key = 'pollreq:' || (select r ->> 'request_id' from req)), 20,
  'the request''s own bucket holds the failures');

-- Ten wrong polls from one client lock that client, with random ids too.
select count(*) from generate_series(1, 10) g, lateral pg_temp.poll('203.0.113.13', gen_random_uuid(), 'nope' || g);
select is(pg_temp.poll('203.0.113.13', (select (r ->> 'request_id')::uuid from req2), (select r ->> 'secret' from req2)) ->> 'status',
  'rate_limited', 'ten failures from one client lock it');
select is(pg_temp.start('203.0.113.13') ->> 'ok', 'true', 'but not its starts: polls and starts are separate buckets');

-- A flood of starts is bounded overall.
insert into app.pairing_attempt (client_key, success) select 'pair:198.51.100.' || g, true from generate_series(1, 2000) g;
select is(pg_temp.start('203.0.113.14') ->> 'reason', 'rate_limited', 'two thousand starts in ten minutes stop new ones');
-- Expired requests nobody collected are dropped by the next start.
update app.pairing_request set expires_at = now() - interval '2 days' where client_key = '203.0.113.11';
delete from app.pairing_attempt where client_key like 'pair:198.51.100.%';
select pg_temp.start('203.0.113.15');
select is((select count(*) from app.pairing_request where client_key = '203.0.113.11'), 0::bigint,
  'a pending request expired for more than a day is dropped');
delete from app.pairing_attempt;

-- ---- invitations: failures only ------------------------------------------------------------------
insert into app.invitation_attempt (client_key, success) select 'invite:198.51.100.' || g, true from generate_series(1, 2500) g;
select is(app.invitation_rate_limited('203.0.113.20'), false, 'successful lookups never count, however many');
insert into app.invitation_attempt (client_key, success) select 'invite:198.51.100.' || g, false from generate_series(1, 2999) g;
select is(app.invitation_rate_limited('203.0.113.20'), false, '2999 failures from elsewhere do not stop a client');
insert into app.invitation_attempt (client_key, success) values ('invite:198.51.100.9', false);
select is(app.invitation_rate_limited('203.0.113.20'), true, 'three thousand do');
delete from app.invitation_attempt;
insert into app.invitation_attempt (client_key, success) select 'invite:203.0.113.21', true from generate_series(1, 30) g;
select is(app.invitation_rate_limited('203.0.113.21'), false, 'thirty successes of one client do not limit it');
insert into app.invitation_attempt (client_key, success) select 'invite:203.0.113.21', false from generate_series(1, 20) g;
select is(app.invitation_rate_limited('203.0.113.21'), true, 'twenty failures of one client do');
delete from app.invitation_attempt;

-- ---- founder codes and claims: failures only ------------------------------------------------------
insert into app.founder_attempt (client_key, success) select '198.51.100.' || g, true from generate_series(1, 600) g;
select is(app.founder_attempts_exceeded('203.0.113.30'), false, 'successes never count');
insert into app.founder_attempt (client_key, success) select '198.51.100.' || g, false from generate_series(1, 999) g;
select is(app.founder_attempts_exceeded('203.0.113.30'), false, '999 failures from elsewhere do not stop a client');
insert into app.founder_attempt (client_key, success) values ('198.51.100.9', false);
select is(app.founder_attempts_exceeded('203.0.113.30'), true, 'a thousand do');
delete from app.founder_attempt;
insert into app.founder_attempt (client_key, success) select '203.0.113.31', false from generate_series(1, 5) g;
select is(app.founder_attempts_exceeded('203.0.113.31'), true, 'five failures of one client lock it');
select is(app.founder_attempts_exceeded('203.0.113.32'), false, 'and no other');
delete from app.founder_attempt;

-- ---- the timetable scan needs a household device (F14) -------------------------------------------
set local role anon;
select throws_ok($$ select api.timetable_scan_claim() $$, '42501', null, 'anon cannot ask for a scan');
reset role;
select pg_temp.as_stranger();
select throws_ok($$ select api.timetable_scan_claim() $$, '42501', 'WW-SCH-005 household device required',
  'a signed-in account without a household is refused');
select pg_temp.owner();
select pg_temp.as_device('u_g', 'dg');
select is(api.timetable_scan_claim() ->> 'ok', 'true', 'a guardian''s phone may scan');
select pg_temp.owner();
select pg_temp.as_device('u_t', 'dt');
create temp table scans as select api.timetable_scan_claim() as r from generate_series(1, 9) g;
select is((select count(*)::int from scans where r ->> 'ok' = 'true'), 9, 'a tablet may scan too, nine more times');
select is(api.timetable_scan_claim() ->> 'ok', 'true', 'the tenth scan in ten minutes is allowed');
select is(api.timetable_scan_claim() ->> 'reason', 'rate_limited', 'the eleventh is not');
select pg_temp.owner();
select pg_temp.as_device('u_g', 'dg');
select is(api.timetable_scan_claim() ->> 'ok', 'true', 'another account is not held up');
select pg_temp.owner();
select is((select count(*)::int from app.timetable_scan_attempt where auth_user_id = pg_temp.fid('u_t')), 10,
  'ten allowed scans are logged for the tablet');
update app.timetable_scan_attempt set attempted_at = now() - interval '2 days' where auth_user_id = pg_temp.fid('u_t');
select pg_temp.as_device('u_t', 'dt');
select is(api.timetable_scan_claim() ->> 'ok', 'true', 'after the window the tablet scans again');
select pg_temp.owner();
select is((select count(*)::int from app.timetable_scan_attempt where auth_user_id = pg_temp.fid('u_t')), 1,
  'and the old rows are gone');
update app.device set revoked_at = now() where id = pg_temp.fid('dt');
select pg_temp.as_device('u_t', 'dt');
select throws_ok($$ select api.timetable_scan_claim() $$, '42501', 'WW-SCH-005 household device required',
  'a revoked device is refused');
select pg_temp.owner();
set local role authenticated;
select throws_ok($$ select count(*) from app.timetable_scan_attempt $$, '42501', null, 'a device cannot read the scan log');
reset role;

select * from finish();
rollback;
