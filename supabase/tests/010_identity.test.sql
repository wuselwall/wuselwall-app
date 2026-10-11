begin;
select plan(33);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

-- Helper: act as an authenticated Auth user whose JWT carries the given claims.
create function pg_temp.act_as(p_sub uuid, p_claims jsonb) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_sub, 'role', 'authenticated') || p_claims)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- ---- setup -----------------------------------------------------------------
set local role anon;
select throws_ok(
  $$ select api.setup_household('wrong', 'Haus', 'g@example.org', 'longpassword1', 'Papa', '#112233', '123456') $$,
  '42501', 'invalid setup token', 'setup refuses a wrong token');
select throws_ok(
  $$ select api.setup_household('dev-setup', 'Haus', 'g@example.org', 'short', 'Papa', '#112233', '123456') $$,
  '22023', 'password too short', 'setup refuses a short password');

create temp table ctx as
  select api.setup_household('dev-setup', 'Haus', 'g@example.org', 'longpassword1', 'Papa', '#112233', '123456') as r;
grant all on ctx to public;
reset role;

select ok((select (r ->> 'household_id') is not null from ctx), 'setup returns the household');
select throws_ok(
  $$ select api.setup_household('dev-setup', 'Zweites', 'x@example.org', 'longpassword1', 'X', '#112233', '123456') $$,
  '42501', 'already set up', 'setup closes after the first household');

-- ---- the guardian's phone: sign in (a session), then register it as a device ----
create temp table ids as
  select (r ->> 'household_id')::uuid hh, (r ->> 'profile_id')::uuid guardian,
         (select auth_user_id from app.profile where id = (r ->> 'profile_id')::uuid) guardian_user,
         gen_random_uuid() sess1, gen_random_uuid() sess2
  from ctx;
grant all on ids to public;
insert into auth.sessions (id, user_id, created_at, updated_at) select sess1, guardian_user, now(), now() from ids;
insert into auth.sessions (id, user_id, created_at, updated_at) select sess2, guardian_user, now(), now() from ids;

select is((select count(*)::int from app.device), 0, 'setup creates no device (phones register themselves)');

select pg_temp.act_as((select guardian_user from ids), jsonb_build_object('session_id', (select sess1 from ids)));
select is((api.my_profile() ->> 'role'), 'guardian', 'a signed-in guardian can read their profile');
select is(api.current_device(), null::jsonb, 'before registering there is no device for the session');
create temp table dev1 as select api.register_personal_device('Papas Handy') r;
grant all on dev1 to public;
select is((select r ->> 'class' from dev1), 'personal', 'registering creates a personal device');
select is((api.register_personal_device('again') ->> 'device_id'), (select r ->> 'device_id' from dev1), 'registering twice is idempotent');
reset role;

-- ---- access-token hook --------------------------------------------------------
select is(
  (app.custom_access_token_hook(jsonb_build_object(
     'user_id', (select guardian_user from ids),
     'claims', jsonb_build_object('session_id', (select sess1 from ids)))) -> 'claims' ->> 'device_class'),
  'personal', 'hook adds device_class for the registered session');
select is(
  (app.custom_access_token_hook(jsonb_build_object(
     'user_id', (select guardian_user from ids),
     'claims', jsonb_build_object('session_id', (select sess2 from ids)))) -> 'claims' ->> 'device_class'),
  null, 'another session of the same user has no device claims until it registers');

insert into auth.mfa_factors (id, user_id, factor_type, status, created_at, updated_at)
  select gen_random_uuid(), guardian_user, 'totp', 'verified', now(), now() from ids;
select is(
  (app.custom_access_token_hook(jsonb_build_object(
     'user_id', (select guardian_user from ids),
     'claims', jsonb_build_object('session_id', (select sess1 from ids), 'aal', 'aal1'))) -> 'claims' ->> 'household_id'),
  null, 'with a verified TOTP factor, an aal1 session gets no household claims');
select is(
  (app.custom_access_token_hook(jsonb_build_object(
     'user_id', (select guardian_user from ids),
     'claims', jsonb_build_object('session_id', (select sess1 from ids), 'aal', 'aal2'))) -> 'claims' ->> 'household_id'),
  (select hh::text from ids), 'an aal2 session gets them');
delete from auth.mfa_factors;

create temp table devids as select (r ->> 'device_id')::uuid guardian_dev from dev1;
grant all on devids to public;

-- ---- guardian on a personal device ----------------------------------------------
select pg_temp.act_as((select guardian_user from ids), jsonb_build_object(
  'session_id', (select sess1 from ids),
  'household_id', (select hh from ids), 'device_id', (select guardian_dev from devids), 'device_class', 'personal'));

select is((select count(*)::int from api.members), 1, 'guardian sees the household members');
select ok((select r from (select api.current_device() r) x) ->> 'class' = 'personal', 'current_device reports class');

create temp table kid as select api.members_add(null, 'Anna', '#ff8800') as id;
grant all on kid to public;
select is((select count(*)::int from api.members), 2, 'guardian adds a member');

create temp table enrol as
  select api.devices_create_enrolment_code(null, 'Kinder-iPad', 'shared', 'kid') as r;
grant all on enrol to public;
select is(length((select r ->> 'code' from enrol)), 8, 'enrolment code has 8 characters');

-- ---- enrol a shared device -------------------------------------------------------
reset role;
set local role anon;
select is((api.enrol_device('NOTACODE') ->> 'reason'), 'code_invalid', 'wrong code is reported, not raised');
create temp table creds as select api.enrol_device((select r ->> 'code' from enrol)) as r;
grant all on creds to public;
select ok((select r ->> 'email' from creds) like 'device-%@devices.wuselwall.invalid', 'enrolment returns credentials');
select is((api.enrol_device((select r ->> 'code' from enrol)) ->> 'reason'), 'code_invalid', 'a code is single use');
-- rate limit: the failures above plus these reach 5 within the window
do $$ begin perform api.enrol_device('AAAAAAA1'); perform api.enrol_device('AAAAAAA2'); perform api.enrol_device('AAAAAAA3'); end $$;
select is((api.enrol_device('AAAAAAA4') ->> 'reason'), 'rate_limited', 'too many failed attempts are rate limited');
reset role;
delete from app.enrol_attempt;

create temp table ids2 as
  select d.id dev, d.auth_user_id usr from app.device d where d.label = 'Kinder-iPad';
grant all on ids2 to public;

-- ---- member on a shared device ---------------------------------------------------
select pg_temp.act_as((select usr from ids2), jsonb_build_object(
  'household_id', (select hh from ids), 'device_id', (select dev from ids2), 'device_class', 'shared'));

select throws_ok($$ select api.members_add(null, 'Z', '#000000') $$, '22023', 'acting profile required',
  'shared device needs an acting profile');
select throws_ok(
  format($$ select api.devices_create_enrolment_code(%L, 'x', 'shared', 'kid') $$, (select id from kid)),
  '42501', 'guardian required', 'a member cannot create an enrolment code');
select throws_ok(
  format($$ select api.devices_create_enrolment_code(%L, 'x', 'shared', 'kid') $$, (select guardian from ids)),
  '42501', 'guardian required', 'a guardian on a shared device needs the PIN first');

-- ---- PIN step-up --------------------------------------------------------------------
select is((api.guardian_verify_pin((select guardian from ids), '000000')) ->> 'reason', 'pin_invalid', 'wrong PIN fails');
select is(((api.guardian_verify_pin((select guardian from ids), '000000')) ->> 'attempts_left')::int, 8, 'failures are counted');
select is((api.guardian_verify_pin((select guardian from ids), '123456')) ->> 'ok', 'true', 'correct PIN verifies');
select lives_ok(
  format($$ select api.devices_create_enrolment_code(%L, 'x', 'shared', 'kid') $$, (select guardian from ids)),
  'after PIN a guardian can act on a shared device');

-- ---- revocation -------------------------------------------------------------------------
select lives_ok(format($$ select api.devices_revoke(%L, %L) $$, (select guardian from ids), (select dev from ids2)),
  'guardian revokes a device');
select throws_ok(
  format($$ select api.members_add(%L, 'Y', '#000000') $$, (select guardian from ids)),
  '42501', 'device not usable', 'a revoked device is refused on its next call');
select is((select count(*)::int from api.members), 0, 'a revoked device reads nothing (RLS)');

-- Revoking one personal phone ends only that phone's session.
reset role;
select pg_temp.act_as((select guardian_user from ids), jsonb_build_object('session_id', (select sess2 from ids)));
create temp table dev2 as select api.register_personal_device('Mamas Handy') r;
grant all on dev2 to public;
reset role;
select pg_temp.act_as((select guardian_user from ids), jsonb_build_object(
  'session_id', (select sess1 from ids),
  'household_id', (select hh from ids), 'device_id', (select guardian_dev from devids), 'device_class', 'personal'));
select api.devices_revoke(null, (select (r ->> 'device_id')::uuid from dev2));
reset role;
select is((select count(*)::int from auth.sessions where id = (select sess2 from ids)), 0, 'the revoked phone loses its session');
select is((select count(*)::int from auth.sessions where id = (select sess1 from ids)), 1, 'the guardian''s other phone keeps its session');

select * from finish();
rollback;
