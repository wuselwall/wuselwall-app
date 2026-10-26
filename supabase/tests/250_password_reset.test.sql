begin;
select plan(35);

-- Mail optional (20261026100000): a guardian's one-time code resets another adult's password on
-- a server without mail, and the operator can issue the same code from the shell. Everything
-- runs as the database owner except the calls under test. All rolled back.
delete from app.household;
delete from app.password_reset_attempt;

create temp table pp (name text primary key, uid uuid, prof uuid, hh uuid, sid uuid);
create temp table dd (name text primary key, id uuid, hh uuid, cls text, sid uuid, uid uuid, prof uuid);
create temp table res (name text primary key, r jsonb);
grant all on pp, dd, res to public;

create function pg_temp.person(p_name text, p_hh uuid, p_role text, p_kind text, p_email text)
returns void language plpgsql as $$
declare v_uid uuid; v_sid uuid; v_prof uuid;
begin
  if p_email is not null then
    v_uid := app.create_auth_user(p_email, 'longpassword1', '{}');
    v_sid := gen_random_uuid();
    insert into auth.sessions (id, user_id, created_at, updated_at) values (v_sid, v_uid, now(), now());
  end if;
  insert into app.profile (household_id, display_name, color, role, kind, auth_user_id)
  values (p_hh, p_name, '#7B3FE4', p_role, p_kind, v_uid) returning id into v_prof;
  insert into pp values (p_name, v_uid, v_prof, p_hh, v_sid);
end $$;

create function pg_temp.phone(p_person text, p_label text, p_register text) returns void
language plpgsql as $$
declare p pp; v_dev uuid := gen_random_uuid();
begin
  select * into p from pp where name = p_person;
  insert into app.device (id, household_id, auth_user_id, auth_session_id, label, class, register, profile_id)
  values (v_dev, p.hh, p.uid, p.sid, p_label, 'personal', p_register, p.prof);
  insert into dd values (p_label, v_dev, p.hh, 'personal', p.sid, p.uid, p.prof);
end $$;

create function pg_temp.device_user(p_label text, p_hh uuid, p_cls text) returns void
language plpgsql as $$
declare v_uid uuid; v_dev uuid := gen_random_uuid();
begin
  v_uid := app.create_auth_user('device-' || v_dev || '@devices.wuselwall.invalid', 'x1234567890', '{"device":true}');
  insert into app.device (id, household_id, auth_user_id, label, class, register)
  values (v_dev, p_hh, v_uid, p_label, p_cls, case when p_cls = 'kiosk' then 'kiosk' else 'kid' end);
  insert into dd values (p_label, v_dev, p_hh, p_cls, null, v_uid, null);
end $$;

create function pg_temp.as_phone(p_label text) returns void language plpgsql as $$
declare d dd;
begin
  select * into d from dd where name = p_label;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.uid, 'role', 'authenticated',
    'session_id', d.sid, 'household_id', d.hh, 'device_id', d.id, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function pg_temp.as_device(p_label text) returns void language plpgsql as $$
declare d dd;
begin
  select * into d from dd where name = p_label;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.uid, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.id, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- A signed-out device, from one forwarded-for address.
create function pg_temp.as_anon(p_ip text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  perform set_config('request.headers', jsonb_build_object('x-forwarded-for', p_ip)::text, true);
  perform set_config('role', 'anon', true);
end $$;

create function pg_temp.owner() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.headers', '', true);
  perform set_config('role', 'none', true);
end $$;

create function pg_temp.prof(p_name text) returns uuid language sql as $$ select prof from pp where name = p_name $$;
create function pg_temp.uid(p_name text) returns uuid language sql as $$ select uid from pp where name = p_name $$;
create function pg_temp.code(p_name text) returns text language sql as $$ select r ->> 'code' from res where name = p_name $$;
create function pg_temp.pw_ok(p_name text, p_password text) returns boolean language sql as $$
  select encrypted_password = extensions.crypt(p_password, encrypted_password) from auth.users where id = pg_temp.uid(p_name) $$;

-- ============================================================ people
-- Ma: Gert (guardian, phone), Ole (adult member, phone), Ida (guardian, phone), Vera (adult,
-- no account), Kid (child with an account), a shared tablet. Mb: Fritz, another family.
insert into app.household (id, name) values (gen_random_uuid(), 'Ma'), (gen_random_uuid(), 'Mb');
select pg_temp.person('Gert', (select id from app.household where name = 'Ma'), 'guardian', 'adult', 'gert@example.org');
select pg_temp.phone('Gert', 'Gert-Phone', 'adult');
select pg_temp.person('Ole', (select id from app.household where name = 'Ma'), 'member', 'adult', 'Ole@Example.org');
select pg_temp.phone('Ole', 'Ole-Phone', 'adult');
select pg_temp.person('Ida', (select id from app.household where name = 'Ma'), 'guardian', 'adult', 'ida@example.org');
select pg_temp.phone('Ida', 'Ida-Phone', 'adult');
select pg_temp.person('Vera', (select id from app.household where name = 'Ma'), 'guardian', 'adult', null);
select pg_temp.person('Kid', (select id from app.household where name = 'Ma'), 'member', 'child', 'kid@example.org');
select pg_temp.phone('Kid', 'Kid-Phone', 'kid');
select pg_temp.device_user('Ma-iPad', (select id from app.household where name = 'Ma'), 'shared');
select pg_temp.person('Fritz', (select id from app.household where name = 'Mb'), 'guardian', 'adult', 'fritz@example.org');
select pg_temp.phone('Fritz', 'Fritz-Phone', 'adult');

-- ============================================================ who may create a code
select pg_temp.as_phone('Ole-Phone');
select throws_ok(format('select api.password_reset_create(%L, %L)', pg_temp.prof('Ole'), pg_temp.prof('Gert')),
  '42501', 'guardian required', 'an adult member cannot create a code');
select pg_temp.owner();

select pg_temp.as_device('Ma-iPad');
select throws_ok(format('select api.password_reset_create(%L, %L)', pg_temp.prof('Gert'), pg_temp.prof('Ole')),
  '42501', null, 'a shared tablet cannot create a code');
select pg_temp.owner();

select pg_temp.as_phone('Gert-Phone');
select throws_ok(format('select api.password_reset_create(%L, %L)', pg_temp.prof('Gert'), pg_temp.prof('Gert')),
  '22023', 'own password', 'not for oneself (Settings changes one''s own password)');
select throws_ok(format('select api.password_reset_create(%L, %L)', pg_temp.prof('Gert'), pg_temp.prof('Kid')),
  '22023', 'target not an adult', 'not for a child');
select throws_ok(format('select api.password_reset_create(%L, %L)', pg_temp.prof('Gert'), pg_temp.prof('Vera')),
  '22023', 'target has no account', 'not for an adult without an account');
select throws_ok(format('select api.password_reset_create(%L, %L)', pg_temp.prof('Gert'), pg_temp.prof('Fritz')),
  'P0002', 'profile not found', 'not for someone in another family');
select throws_ok(format('select api.password_reset_create(%L, null)', pg_temp.prof('Gert')),
  '22023', 'profile required', 'a profile is required');

insert into res select 'ole1', api.password_reset_create(pg_temp.prof('Gert'), pg_temp.prof('Ole'));
select matches(pg_temp.code('ole1'), '^[A-HJ-NP-Z2-9]{8}$', 'the code is 8 symbols without look-alikes');
select ok((select (r ->> 'expires_at')::timestamptz between now() + interval '9 minutes' and now() + interval '11 minutes'
             from res where name = 'ole1'), 'the code is valid ten minutes');
insert into res select 'ida1', api.password_reset_create(pg_temp.prof('Gert'), pg_temp.prof('Ida'));
select pg_temp.owner();

select is((select count(*)::int from app.audit_log where entity_id = pg_temp.prof('Ole') and action = 'password_reset_code'
             and actor_profile_id = pg_temp.prof('Gert')), 1, 'creating a code is audited with the guardian as actor');
select is((select count(*)::int from app.password_reset where code_hash = app.pairing_hash(pg_temp.code('ole1'))
             and auth_user_id = pg_temp.uid('Ole')), 1, 'the code is stored as its hash, for Ole''s account');

-- A second code for Ole replaces the first.
select pg_temp.as_phone('Gert-Phone');
insert into res select 'ole2', api.password_reset_create(pg_temp.prof('Gert'), pg_temp.prof('Ole'));
select pg_temp.owner();

-- ============================================================ redeeming
select pg_temp.as_anon('203.0.113.7');
select is(api.password_reset_redeem('ole@example.org', pg_temp.code('ole1'), 'a brand new password') ->> 'reason', 'invalid',
  'a replaced code no longer works');
select is(api.password_reset_redeem('ole@example.org', pg_temp.code('ole2'), 'short') ->> 'reason', 'password_too_short',
  'the new password has at least 10 characters');
select is(api.password_reset_redeem('gert@example.org', pg_temp.code('ole2'), 'a brand new password') ->> 'reason', 'invalid',
  'the code works only with the address it was made for');
select is(api.password_reset_redeem(' OLE@example.ORG ', lower(substr(pg_temp.code('ole2'), 1, 4)) || '-' || substr(pg_temp.code('ole2'), 5),
  'a brand new password'), '{"ok": true}'::jsonb,
  'the code redeems with the address in any case, typed in lower case and with a dash');
select pg_temp.owner();

select ok(pg_temp.pw_ok('Ole', 'a brand new password'), 'Ole''s password is the new one');
select ok(not pg_temp.pw_ok('Ole', 'longpassword1'), 'the old password no longer works');
select is((select raw_user_meta_data ->> 'has_password' from auth.users where id = pg_temp.uid('Ole')), 'true',
  'the account is marked as having a password');
select is((select count(*)::int from app.audit_log where entity_id = pg_temp.prof('Ole') and action = 'password_reset'
             and actor_profile_id = pg_temp.prof('Ole')), 1, 'the reset is audited for Ole');

select pg_temp.as_anon('203.0.113.7');
select is(api.password_reset_redeem('ole@example.org', pg_temp.code('ole2'), 'yet another password') ->> 'reason', 'invalid',
  'a code works once');
select pg_temp.owner();
select ok(pg_temp.pw_ok('Ole', 'a brand new password'), 'a spent code changes nothing');

-- Expiry: Ida's code ran out.
update app.password_reset set expires_at = now() - interval '1 second'
 where auth_user_id = pg_temp.uid('Ida') and used_at is null;
select pg_temp.as_anon('203.0.113.8');
select is(api.password_reset_redeem('ida@example.org', pg_temp.code('ida1'), 'a brand new password') ->> 'reason', 'expired',
  'an expired code is refused');
select pg_temp.owner();
select ok(pg_temp.pw_ok('Ida', 'longpassword1'), 'an expired code changes nothing');

-- ============================================================ rate limit
select pg_temp.as_anon('198.51.100.9');
select is((select count(*)::int from generate_series(1, 10) g
            where api.password_reset_redeem('ida@example.org', 'WRONG' || g, 'a brand new password') ->> 'reason' = 'invalid'),
  10, 'ten wrong codes are refused as invalid');
select pg_temp.owner();
select pg_temp.as_phone('Gert-Phone');
insert into res select 'ida2', api.password_reset_create(pg_temp.prof('Gert'), pg_temp.prof('Ida'));
select pg_temp.as_anon('198.51.100.9');
select is(api.password_reset_redeem('ida@example.org', pg_temp.code('ida2'), 'a brand new password') ->> 'reason', 'rate_limited',
  'after ten failures in ten minutes even the right code waits');
select pg_temp.as_anon('198.51.100.10');
select is(api.password_reset_redeem('ida@example.org', pg_temp.code('ida2'), 'a brand new password') ->> 'ok', 'true',
  'another address is not held up');
select pg_temp.owner();
select is((select count(*)::int from app.password_reset_attempt where not success and client_key = 'reset:198.51.100.9'), 10,
  'refusals are logged (a refusal is a result, not an error)');

-- ============================================================ the operator's code
select is(app.password_reset_issue_for_email('nobody@example.org'), null, 'no code for an unknown address');
select is(app.password_reset_issue_for_email((select email from auth.users where id = (select uid from dd where name = 'Ma-iPad'))),
  null, 'no code for a shared tablet''s device user');
insert into res select 'gert-op', app.password_reset_issue_for_email(' GERT@example.org ');
select is((select count(*)::int from app.audit_log where entity_id = pg_temp.prof('Gert') and action = 'password_reset_code'
             and origin = 'operator'), 1, 'the operator''s code is audited as such');
select pg_temp.as_anon('203.0.113.20');
select is(api.password_reset_redeem('gert@example.org', pg_temp.code('gert-op'), 'the founder''s new one') ->> 'ok', 'true',
  'the operator''s code resets the only guardian''s password');
select pg_temp.owner();
select ok(pg_temp.pw_ok('Gert', 'the founder''s new one'), 'Gert''s password is the new one');

-- ============================================================ privileges and discovery
select ok(not has_function_privilege('anon', 'api.password_reset_create(uuid, uuid)', 'execute'),
  'anon cannot create a code');
select ok(not has_function_privilege('authenticated', 'app.password_reset_issue_for_email(text)', 'execute')
          and not has_function_privilege('anon', 'app.password_reset_issue_for_email(text)', 'execute'),
  'only the operator issues a code by address');
select ok(api.server_info() -> 'features' ? 'password-reset', 'the server announces the password reset');

select * from finish();
rollback;
