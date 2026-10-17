begin;
select plan(38);

-- Apple revocation obligations (20261017110000 and 20261017120000, specs/22 item 6): a stored Apple token never
-- disappears without an obligation to revoke it, and only the service role sees or settles them.
-- Starts from an empty system, all rolled back.
delete from app.household;
delete from app.apple_revocation;
delete from app.apple_token;

create temp table ids (name text primary key, id uuid);
grant all on ids to public;

create function pg_temp.id(p_name text) returns uuid language sql as $$
  select id from ids where name = p_name $$;

create function pg_temp.as_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
  perform set_config('role', 'service_role', true);
end $$;

-- A service-role database role with a user's claims: the functions' own check must refuse it.
create function pg_temp.as_fake_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'authenticated')::text, true);
  perform set_config('role', 'service_role', true);
end $$;

create function pg_temp.as_member(p_device text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', pg_temp.id('uid-' || p_device), 'role', 'authenticated',
    'household_id', pg_temp.id('hh'), 'device_id', pg_temp.id(p_device),
    'device_class', 'personal', 'session_id', gen_random_uuid())::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function pg_temp.as_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  perform set_config('role', 'anon', true);
end $$;

create function pg_temp.owner() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'none', true);
end $$;

-- One family; two accounts with a phone each, the second phone revoked.
insert into ids values ('hh', gen_random_uuid()), ('phone-a', gen_random_uuid()), ('phone-b', gen_random_uuid());
insert into app.household (id, name) values (pg_temp.id('hh'), 'Revocation');
insert into ids values
  ('uid-phone-a', app.create_auth_user('rev-a@example.org', 'longpassword1', '{}')),
  ('uid-phone-b', app.create_auth_user('rev-b@privaterelay.appleid.com', 'longpassword1', '{}')),
  ('uid-c', app.create_auth_user('rev-c@example.org', 'longpassword1', '{}'));
insert into app.profile (household_id, display_name, color, role, kind, auth_user_id)
values (pg_temp.id('hh'), 'A', '#7B3FE4', 'guardian', 'adult', pg_temp.id('uid-phone-a')),
       (pg_temp.id('hh'), 'B', '#7B3FE4', 'guardian', 'adult', pg_temp.id('uid-phone-b'));
insert into app.device (id, household_id, auth_user_id, label, class, register, profile_id, revoked_at)
select pg_temp.id('phone-a'), pg_temp.id('hh'), pg_temp.id('uid-phone-a'), 'A-Phone', 'personal', 'adult',
       (select id from app.profile where auth_user_id = pg_temp.id('uid-phone-a')), null
union all
select pg_temp.id('phone-b'), pg_temp.id('hh'), pg_temp.id('uid-phone-b'), 'B-Phone', 'personal', 'adult',
       (select id from app.profile where auth_user_id = pg_temp.id('uid-phone-b')), now();

insert into app.apple_token (user_id, refresh_token_enc) values
  (pg_temp.id('uid-phone-a'), 'enc-a'), (pg_temp.id('uid-phone-b'), 'enc-b'), (pg_temp.id('uid-c'), 'enc-c');

-- ============================================================ the table is closed
select ok((select relrowsecurity and relforcerowsecurity from pg_class
            where oid = 'app.apple_revocation'::regclass), 'RLS is enabled and forced');

select pg_temp.as_member('phone-a');
select throws_ok('select count(*) from app.apple_revocation', '42501', null,
  'a signed-in member cannot read the obligations');
select throws_ok($$ select * from api.apple_revocation_due() $$, '42501', null,
  'nor list them through the api');
select throws_ok(format($$ select api.apple_revocation_record(%L) $$, gen_random_uuid()), '42501', null,
  'nor settle one');
select pg_temp.as_member('phone-b');
select throws_ok('select count(*) from app.apple_revocation', '42501', null,
  'a revoked device cannot read them');
select throws_ok($$ select * from api.apple_revocation_due() $$, '42501', null,
  'nor list them');
select pg_temp.as_anon();
select throws_ok('select count(*) from app.apple_revocation', '42501', null,
  'an anonymous caller cannot read them');
select throws_ok($$ select * from api.apple_revocation_due() $$, '42501', null,
  'nor list them');
select pg_temp.as_service();
select throws_ok('select count(*) from app.apple_revocation', '42501', null,
  'the service role reads them only through the functions');
select pg_temp.as_fake_service();
select throws_ok($$ select * from api.apple_revocation_due() $$, '42501', 'service role required',
  'a user claim on the service role is refused by apple_revocation_due');
select throws_ok(format($$ select api.apple_revocation_record(%L) $$, gen_random_uuid()),
  '42501', 'service role required', 'and by apple_revocation_record');

-- ============================================================ a deleted account leaves an obligation
select pg_temp.owner();
select is((select count(*) from app.apple_revocation), 0::bigint, 'no obligation while the accounts live');

delete from auth.users where id = pg_temp.id('uid-phone-a');
select is((select count(*) from app.apple_token where user_id = pg_temp.id('uid-phone-a')), 0::bigint,
  'the token row goes with its account (cascade)');
select is((select refresh_token_enc from app.apple_revocation where user_id = pg_temp.id('uid-phone-a')),
  'enc-a', 'and its encrypted token is kept as an obligation in the same transaction');
select is((select attempts from app.apple_revocation where user_id = pg_temp.id('uid-phone-a')), 0,
  'not tried yet');

-- A relay-address account removed some other way (e.g. by hand) is covered too.
delete from app.apple_token where user_id = pg_temp.id('uid-phone-b');
select is((select count(*) from app.apple_revocation where user_id = pg_temp.id('uid-phone-b')), 1::bigint,
  'a token deleted directly is kept as an obligation as well');
select is((select count(*) from app.apple_token where user_id = pg_temp.id('uid-c')), 1::bigint,
  'a living account keeps its token and has no obligation');

-- ============================================================ trying and settling
select pg_temp.as_service();
select is((select count(*) from api.apple_revocation_due(pg_temp.id('uid-phone-a'))), 1::bigint,
  'account-delete finds the obligation of the account it just deleted');
select is((select count(*) from api.apple_revocation_due()), 2::bigint,
  'the daily job finds every untried obligation');

-- Apple unreachable: the obligation stays, counted, with its reason.
select api.apple_revocation_record(
  (select id from api.apple_revocation_due(pg_temp.id('uid-phone-a'))), 'unreachable');
select pg_temp.owner();
select is((select attempts from app.apple_revocation where user_id = pg_temp.id('uid-phone-a')), 1,
  'a failed attempt is counted');
select is((select last_error from app.apple_revocation where user_id = pg_temp.id('uid-phone-a')),
  'unreachable', 'with its reason code');
select is((select refresh_token_enc from app.apple_revocation where user_id = pg_temp.id('uid-phone-a')),
  'enc-a', 'and the token is still there to retry');

select pg_temp.as_service();
select is((select count(*) from api.apple_revocation_due()), 1::bigint,
  'the daily job skips what was tried within 20 hours');
select pg_temp.owner();
update app.apple_revocation set last_attempt_at = now() - interval '21 hours'
 where user_id = pg_temp.id('uid-phone-a');
select pg_temp.as_service();
select is((select count(*) from api.apple_revocation_due()), 2::bigint,
  'and retries it the next day');

-- Missing configuration and a key that cannot decrypt are kept, too.
select api.apple_revocation_record(
  (select id from api.apple_revocation_due(pg_temp.id('uid-phone-b'))), 'config_missing');
select api.apple_revocation_record(
  (select id from api.apple_revocation_due(pg_temp.id('uid-phone-b'))), 'decrypt_failed');
select pg_temp.owner();
select is((select attempts || ':' || last_error from app.apple_revocation where user_id = pg_temp.id('uid-phone-b')),
  '2:decrypt_failed', 'missing configuration and decryption failures leave the obligation in place');

-- An overlong reason is cut, never stored whole (no response bodies in the table).
select pg_temp.as_service();
select api.apple_revocation_record(
  (select id from api.apple_revocation_due(pg_temp.id('uid-phone-b'))), repeat('x', 200));
select pg_temp.owner();
select is((select length(last_error) from app.apple_revocation where user_id = pg_temp.id('uid-phone-b')), 64,
  'reason codes are at most 64 characters');

-- Apple accepted: the obligation is met.
select pg_temp.as_service();
select api.apple_revocation_record((select id from api.apple_revocation_due(pg_temp.id('uid-phone-a'))));
select pg_temp.owner();
select is((select count(*) from app.apple_revocation where user_id = pg_temp.id('uid-phone-a')), 0::bigint,
  'a successful revocation removes the obligation');
select is((select count(*) from app.apple_revocation), 1::bigint, 'and only that one');

-- ============================================================ fair daily retries (20261017120000)
-- 51 obligations, a batch of 50, and every attempt fails (Apple keeps refusing). The daily job
-- must not pick the same oldest 50 every day: what waited longest since its last try goes first.
-- record() stamps now(), constant in this transaction, so each "next day" moves every attempt
-- 24 hours back.
delete from app.apple_revocation;
create temp table fair (n integer primary key, id uuid);
grant all on fair to public;
with ins as (
  insert into app.apple_revocation (user_id, refresh_token_enc, created_at)
  select gen_random_uuid(), 'enc-fair-' || n, now() - interval '30 days' + n * interval '1 minute'
    from generate_series(1, 51) n
  returning id, refresh_token_enc)
insert into fair select substr(refresh_token_enc, 10)::integer, id from ins;

create function pg_temp.daily_run() returns setof integer language plpgsql as $$
declare r record;
begin
  perform pg_temp.as_service();
  for r in select d.id from api.apple_revocation_due() d loop
    perform api.apple_revocation_record(r.id, 'http_400');
    return next (select n from fair where fair.id = r.id);
  end loop;
  perform pg_temp.owner();
  update app.apple_revocation set last_attempt_at = last_attempt_at - interval '24 hours'
   where last_attempt_at is not null;
end $$;

create temp table day1 as select n from pg_temp.daily_run() n;
create temp table day2 as select n from pg_temp.daily_run() n;
create temp table day3 as select n from pg_temp.daily_run() n;

select is((select count(*) from day1), 50::bigint, 'day 1 tries a full batch');
select ok(not exists (select 1 from day1 where n = 51), 'day 1 takes the oldest 50');
select ok(exists (select 1 from day2 where n = 51),
  'day 2 tries the obligation that was never tried, although the oldest 50 keep failing');
select is((select count(*) from day2), 50::bigint, 'day 2 tries a full batch as well');
select is((select array_agg(n order by n) from fair where n not in (select n from day2)), array[50],
  'day 2 leaves out only the newest of the first batch');
select ok(exists (select 1 from day3 where n = 50), 'day 3 reaches the one day 2 left out');
select is((select count(distinct n) from (select n from day1 union all select n from day2) d), 51::bigint,
  'within two daily runs every obligation was tried');
select is((select min(attempts) from app.apple_revocation), 1,
  'no obligation is starved: each has at least one attempt');
select is((select count(*) from app.apple_revocation where refresh_token_enc like 'enc-fair-%'), 51::bigint,
  'failed attempts keep every encrypted token');
select pg_temp.as_member('phone-a');
select throws_ok($$ select * from api.apple_revocation_due() $$, '42501', null,
  'the fair batch is still closed to members');

select * from finish();
rollback;
