-- Claiming the server (specs/20 "Claiming the server", migration 20261030100000): the setup
-- key announces the founder's address before sign-up, the Before User Created hook refuses
-- every other sign-up while no household exists, and the claim stands in for the key on
-- "Neue Familie".
begin;
select plan(37);

-- Start from an empty, unclaimed server, whatever the database holds (all rolled back).
delete from app.founder_attempt;
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));
update app.instance_setting set value = '"code"' where key = 'household_creation';

create function pg_temp.from_ip(p_ip text) returns void language plpgsql as $$
begin
  perform set_config('request.headers', jsonb_build_object('x-forwarded-for', p_ip)::text, true);
end $$;

-- What GoTrue sends the hook: the user about to be created, not yet in auth.users.
create function pg_temp.hook(p_email text) returns jsonb language sql as $$
  select app.before_user_created_hook(jsonb_build_object(
    'metadata', jsonb_build_object('name', 'before-user-created', 'ip_address', '10.0.0.9'),
    'user', jsonb_build_object('email', p_email, 'app_metadata', jsonb_build_object('provider', 'email'))))
$$;

-- ---- an unclaimed server ------------------------------------------------------
select is(api.server_info() ->> 'claimed', 'false', 'a server without a household is unclaimed');
select ok((api.server_info() -> 'features') ? 'claim', 'server_info announces the claim');
select is(pg_temp.hook('stranger@example.org') -> 'error' ->> 'message', 'setup_key_required',
  'while unclaimed, the hook refuses a sign-up that made no claim');
select is((pg_temp.hook('stranger@example.org') -> 'error' ->> 'http_code')::int, 403, 'the refusal is a 403');
select is(pg_temp.hook('') -> 'error' ->> 'message', 'setup_key_required', 'an empty address is refused too');

update app.instance_setting set value = '"open"' where key = 'household_creation';
select is(pg_temp.hook('stranger@example.org'), '{}'::jsonb, 'in open mode the hook lets every sign-up through');
update app.instance_setting set value = '"code"' where key = 'household_creation';

-- ---- the claim, as the app makes it before anyone is signed in ------------------
set local role anon;
select pg_temp.from_ip('10.0.0.1');
select is(api.setup_claim('', null) ->> 'reason', 'key_required', 'an empty key is refused');
select is(api.setup_claim('wrong', null) ->> 'reason', 'key_invalid', 'a wrong key is refused');
select is(api.setup_claim('dev-setup', 'not an address') ->> 'reason', 'email_invalid', 'a malformed address is refused');
select is(api.setup_claim('dev-setup', null) ->> 'ok', 'true', 'the key alone checks out');
select is(api.setup_claim('dev-setup', null) ->> 'claimed', 'false', 'a check without an address claims nothing');
select is(api.setup_claim('dev-setup', null) ->> 'server_claimed', 'false', 'the check says the server is unclaimed');
select is(api.setup_claim(' DEV-SETUP ', null) ->> 'ok', 'true', 'the key is trimmed and case-insensitive');

-- Guesses: 5 per client in 10 minutes, then rate_limited; another client still gets an answer.
select pg_temp.from_ip('10.0.0.2');
select api.setup_claim('guess-' || g, null) from generate_series(1, 5) g;
select is(api.setup_claim('dev-setup', null) ->> 'reason', 'rate_limited', 'five wrong keys lock the client out, even for the right key');
select pg_temp.from_ip('10.0.0.3');
select is(api.setup_claim('wrong', null) ->> 'reason', 'key_invalid', 'another client is not locked out');

select pg_temp.from_ip('10.0.0.1');
select is(api.setup_claim('dev-setup', ' Founder@Example.org ') ->> 'claimed', 'true', 'a key with an address claims');
reset role;
select is((select claimed_email from app.setup_token), 'founder@example.org', 'the address is stored trimmed and lower-case');
select ok((select claimed_at > now() - interval '1 minute' from app.setup_token), 'the claim is dated');

-- ---- the hook after the claim ---------------------------------------------------
select is(pg_temp.hook('Founder@Example.org'), '{}'::jsonb, 'the claimed address may sign up, whatever its case');
select is(pg_temp.hook('other@example.org') -> 'error' ->> 'message', 'setup_key_required', 'any other address is still refused');

update app.setup_token set claimed_at = now() - interval '16 minutes';
select is(pg_temp.hook('founder@example.org') -> 'error' ->> 'message', 'setup_key_required', 'a claim older than 15 minutes no longer opens sign-up');
set local role anon;
select is(api.setup_claim('dev-setup', 'founder@example.org') ->> 'ok', 'true', 'claiming again renews it');
reset role;
select is(pg_temp.hook('founder@example.org'), '{}'::jsonb, 'the renewed claim opens sign-up again');

-- ---- the founder signs in and starts the family without typing the key ------------
create temp table acc as
  select app.create_auth_user('founder@example.org', 'longpassword1', '{}'::jsonb) as uid,
         gen_random_uuid() as sess;
insert into auth.sessions (id, user_id, created_at, updated_at) select sess, uid, now(), now() from acc;
create function pg_temp.as_founder() returns void language plpgsql as $$
declare r acc;
begin
  select * into r from acc;
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', r.uid, 'role', 'authenticated', 'session_id', r.sess)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

select pg_temp.as_founder();
select pg_temp.from_ip('10.0.0.1');
select is(api.my_account() ->> 'setup_claimed', 'true', 'my_account says the address holds a claim');
select is(api.my_account() ->> 'has_household', 'false', 'and no household yet');
select is(api.household_create('Familie Test', 'Papa', '#2E7D6B', 'Europe/Berlin', 'de', 'not-the-key', false, 'Phone') ->> 'reason',
  'founder_code_invalid', 'a typed wrong code is still refused');
-- Older than a day: the claim no longer founds a family either.
reset role;
update app.setup_token set claimed_at = now() - interval '25 hours';
select pg_temp.as_founder();
select is(api.household_create('Familie Test', 'Papa', '#2E7D6B', 'Europe/Berlin', 'de', null, false, 'Phone') ->> 'reason',
  'founder_code_required', 'a claim older than a day does not found a family');
reset role;
update app.setup_token set claimed_at = now() - interval '2 hours';
select pg_temp.as_founder();
create temp table made as
  select api.household_create('Familie Test', 'Papa', '#2E7D6B', 'Europe/Berlin', 'de', null, false, 'Phone') as r;
select is((select r ->> 'ok' from made), 'true', 'the claim founds the family without a typed code');
reset role;
select ok((select consumed_at is not null from app.setup_token), 'the key is consumed');
select is((select consumed_by from app.setup_token), (select (r ->> 'profile_id')::uuid from made), 'and records who used it');
select is((select count(*)::int from app.household), 1, 'one household exists');

-- ---- a claimed server ------------------------------------------------------------
select is(api.server_info() ->> 'claimed', 'true', 'the server is claimed now');
select is(pg_temp.hook('anyone@example.org'), '{}'::jsonb, 'once claimed, the hook lets every sign-up through');
set local role anon;
select pg_temp.from_ip('10.0.0.4');
select is(api.setup_claim('dev-setup', null) ->> 'reason', 'key_used', 'the used key says so');
reset role;

-- A second adult (sign-up open now) without a claim still needs a founder code in code mode.
insert into app.setup_token (token_hash) values (encode(extensions.digest('founder-two', 'sha256'), 'hex'));
create temp table acc2 as
  select app.create_auth_user('other@example.org', 'longpassword1', '{}'::jsonb) as uid,
         gen_random_uuid() as sess;
insert into auth.sessions (id, user_id, created_at, updated_at) select sess, uid, now(), now() from acc2;
select set_config('request.jwt.claims',
  (select jsonb_build_object('sub', uid, 'role', 'authenticated', 'session_id', sess) from acc2)::text, true);
set local role authenticated;
select pg_temp.from_ip('10.0.0.5');
select is(api.my_account() ->> 'setup_claimed', 'false', 'an address without a claim has none');
select is(api.household_create('Zweite', 'Mama', '#2E7D6B', 'Europe/Berlin', 'de', null, false, 'Phone') ->> 'reason',
  'founder_code_required', 'without a claim a code is still required');
select is(api.household_create('Zweite', 'Mama', '#2E7D6B', 'Europe/Berlin', 'de', 'founder-two', false, 'Phone') ->> 'ok',
  'true', 'a typed founder code still founds a family');
reset role;

select * from finish();
rollback;
