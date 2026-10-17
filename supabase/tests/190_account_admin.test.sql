begin;
select plan(56);

-- C1 account administration (specs/20 J6 "Konto löschen", J4 "Zwei-Faktor zurücksetzen";
-- specs/16 step 9.6): the service-role functions behind account-delete and mfa-reset, and
-- the guardian functions behind Mitglieder. Start from an empty system, all rolled back.
delete from app.household;

create temp table pp (name text primary key, uid uuid, prof uuid, hh uuid, sid uuid);
create temp table dd (name text primary key, id uuid, hh uuid, cls text, sid uuid, uid uuid, prof uuid);
create temp table hh (name text primary key, id uuid);
create temp table res (r jsonb);
grant all on pp, dd, hh, res to public;

-- A profile; with an email it gets an Auth user and a live session.
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

-- A personal phone: its session is the account's session.
create function pg_temp.phone(p_person text, p_label text, p_register text) returns void
language plpgsql as $$
declare p pp; v_dev uuid := gen_random_uuid();
begin
  select * into p from pp where name = p_person;
  insert into app.device (id, household_id, auth_user_id, auth_session_id, label, class, register, profile_id)
  values (v_dev, p.hh, p.uid, p.sid, p_label, 'personal', p_register, p.prof);
  insert into dd values (p_label, v_dev, p.hh, 'personal', p.sid, p.uid, p.prof);
end $$;

-- A shared tablet or a kiosk: its own device user, with the device address.
create function pg_temp.device_user(p_label text, p_hh uuid, p_cls text) returns void
language plpgsql as $$
declare v_uid uuid; v_dev uuid := gen_random_uuid();
begin
  v_uid := app.create_auth_user('device-' || v_dev || '@devices.wuselwall.invalid', 'x1234567890', '{"device":true}');
  insert into app.device (id, household_id, auth_user_id, label, class, register)
  values (v_dev, p_hh, v_uid, p_label, p_cls, case when p_cls = 'kiosk' then 'kiosk' else 'kid' end);
  insert into dd values (p_label, v_dev, p_hh, p_cls, null, v_uid, null);
end $$;

-- Claims as the access-token hook sets them for a phone, a device user, or a bare account.
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

-- The Edge Functions' service role: claims role service_role, the database role service_role.
create function pg_temp.as_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
  perform set_config('role', 'service_role', true);
end $$;

-- A service-role claim on a user role: the function's own check must refuse it.
create function pg_temp.as_fake_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'authenticated')::text, true);
  perform set_config('role', 'service_role', true);
end $$;

create function pg_temp.owner() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'none', true);
end $$;

create function pg_temp.uid(p_name text) returns uuid language sql as $$
  select uid from pp where name = p_name $$;
create function pg_temp.prof(p_name text) returns uuid language sql as $$
  select prof from pp where name = p_name $$;

-- ============================================================ households and people
insert into hh (name, id) select n, gen_random_uuid()
  from unnest(array['Ma', 'Mb', 'Solo1', 'Mc', 'Rita', 'Me']) n;
insert into app.household (id, name) select id, name from hh;
update app.household set deleted_at = now() - interval '1 day' where name = 'Rita';

-- Ma: Gert (guardian, phone), Vera (guardian, no account), Ole (adult member, phone),
-- Kid (child), a shared tablet and a kiosk.
select pg_temp.person('Gert', (select id from hh where name = 'Ma'), 'guardian', 'adult', 'gert@example.org');
select pg_temp.phone('Gert', 'Gert-Phone', 'adult');
select pg_temp.person('Vera', (select id from hh where name = 'Ma'), 'guardian', 'adult', null);
select pg_temp.person('Ole', (select id from hh where name = 'Ma'), 'member', 'adult', 'ole@example.org');
select pg_temp.phone('Ole', 'Ole-Phone', 'adult');
select pg_temp.person('Kid', (select id from hh where name = 'Ma'), 'member', 'child', null);
select pg_temp.device_user('Ma-iPad', (select id from hh where name = 'Ma'), 'shared');
select pg_temp.device_user('Ma-Kiosk', (select id from hh where name = 'Ma'), 'kiosk');

-- Mb: Fritz, the guardian of another family.
select pg_temp.person('Fritz', (select id from hh where name = 'Mb'), 'guardian', 'adult', 'fritz@example.org');
select pg_temp.phone('Fritz', 'Fritz-Phone', 'adult');

-- Solo1: Nina is the only person of her family.
select pg_temp.person('Nina', (select id from hh where name = 'Solo1'), 'guardian', 'adult', 'nina@example.org');
select pg_temp.phone('Nina', 'Nina-Phone', 'adult');

-- Mc: Paul and Quirin, both guardians with accounts.
select pg_temp.person('Paul', (select id from hh where name = 'Mc'), 'guardian', 'adult', 'paul@example.org');
select pg_temp.phone('Paul', 'Paul-Phone', 'adult');
select pg_temp.person('Quirin', (select id from hh where name = 'Mc'), 'guardian', 'adult', 'quirin@example.org');
select pg_temp.phone('Quirin', 'Quirin-Phone', 'adult');

-- Rita: a family deleted yesterday, its guardian still has an account.
select pg_temp.person('Rita', (select id from hh where name = 'Rita'), 'guardian', 'adult', 'rita@example.org');
select pg_temp.phone('Rita', 'Rita-Phone', 'adult');

-- Solo: an account in no family.
do $$ declare v_uid uuid := app.create_auth_user('solo@example.org', 'longpassword1', '{}'); v_sid uuid := gen_random_uuid();
begin
  insert into auth.sessions (id, user_id, created_at, updated_at) values (v_sid, v_uid, now(), now());
  insert into pp values ('Solo', v_uid, null, null, v_sid);
end $$;

-- Me: Hugo (guardian, phone), Ida (guardian with an account and a verified authenticator),
-- Kurt (guardian, no account), Jule (adult member, phone), Lina (child), and a shared tablet.
select pg_temp.person('Hugo', (select id from hh where name = 'Me'), 'guardian', 'adult', 'hugo@example.org');
select pg_temp.phone('Hugo', 'Hugo-Phone', 'adult');
select pg_temp.person('Ida', (select id from hh where name = 'Me'), 'guardian', 'adult', 'ida@example.org');
select pg_temp.person('Kurt', (select id from hh where name = 'Me'), 'guardian', 'adult', null);
select pg_temp.person('Jule', (select id from hh where name = 'Me'), 'member', 'adult', 'jule@example.org');
select pg_temp.phone('Jule', 'Jule-Phone', 'adult');
select pg_temp.person('Lina', (select id from hh where name = 'Me'), 'member', 'child', null);
select pg_temp.device_user('Me-iPad', (select id from hh where name = 'Me'), 'shared');
insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at)
  values (gen_random_uuid(), pg_temp.uid('Ida'), 'Ida-App', 'totp', 'verified', now(), now());

-- ============================================================ account_delete_prepare: service only
select pg_temp.as_phone('Gert-Phone');
select throws_ok(format($$ select api.account_delete_prepare(%L) $$, pg_temp.uid('Gert')),
  '42501', null, 'a signed-in account cannot call the account-deletion function');
select pg_temp.as_fake_service();
select throws_ok(format($$ select api.account_delete_prepare(%L) $$, pg_temp.uid('Gert')),
  '42501', 'service role required', 'a user claim is refused even on the service role');
select pg_temp.owner();
select throws_ok($$ set role anon; select api.account_delete_prepare(null) $$,
  '42501', null, 'anon cannot call the account-deletion function');
select pg_temp.owner();
select pg_temp.as_service();
select throws_ok('select api.account_delete_prepare(null)', '22023', 'user required',
  'no user, no action');

-- A shared tablet's user is never an adult account: refused, nothing changes.
select is((api.account_delete_prepare((select uid from dd where name = 'Ma-iPad')) ->> 'reason'),
  'device_account', 'a shared tablet is not an account and is refused');
select pg_temp.owner();
select is((select count(*) from app.device where label = 'Ma-iPad' and revoked_at is null), 1::bigint,
  'the refused tablet keeps its device');

-- Gert is the last guardian with an account while Vera (no account) and others remain: refused.
select pg_temp.as_service();
select is((api.account_delete_prepare(pg_temp.uid('Gert')) ->> 'reason'), 'last_guardian',
  'the last guardian with an account is refused while others are in the family');
select pg_temp.owner();
select is((select auth_user_id is not null from app.profile where display_name = 'Gert'), true,
  'a refused deletion keeps the profile linked');
select is((select count(*) from app.device where label = 'Gert-Phone' and revoked_at is null), 1::bigint,
  'a refused deletion keeps the phone live');
select is((select count(*) from app.audit_log where action = 'account_delete'), 0::bigint,
  'a refused deletion writes no audit row');

-- A member with an account leaves the account behind: profile unlinked, phone revoked.
select pg_temp.as_service();
select is((api.account_delete_prepare(pg_temp.uid('Ole')) ->> 'ok'), 'true',
  'an adult member may delete the account');
select pg_temp.owner();
select is((select auth_user_id from app.profile where display_name = 'Ole'), null::uuid,
  'the member profile stays in the family, unlinked');
select is((select count(*) from app.profile where display_name = 'Ole'), 1::bigint,
  'the profile keeps its history');
select is((select revoked_at is not null from app.device where label = 'Ole-Phone'), true,
  'the member phone is revoked');
select is((select count(*) from app.household where name = 'Ma' and deleted_at is null), 1::bigint,
  'the family goes on with its guardian');
select is((select count(*) from app.audit_log where action = 'account_delete' and entity_id = pg_temp.prof('Ole')),
  1::bigint, 'the deletion is audited against the profile');

-- A second guardian with an account: the first may go, the family stays.
select pg_temp.as_service();
select is((api.account_delete_prepare(pg_temp.uid('Paul')) ->> 'household_deleted'), 'false',
  'the first of two guardians with accounts may delete the account');
select pg_temp.owner();
select is((select auth_user_id from app.profile where display_name = 'Paul'), null::uuid,
  'and its profile stays, unlinked');
select is((select count(*) from app.household where name = 'Mc' and deleted_at is null), 1::bigint,
  'the family of Paul and Quirin is not deleted');
select is((select count(*) from app.device where label = 'Paul-Phone' and revoked_at is null), 0::bigint,
  'the phone of the deleted account is revoked');
select is((select count(*) from app.device where label = 'Quirin-Phone' and revoked_at is null), 1::bigint,
  'the other guardian keeps the phone');

-- The sole person: the family is marked deleted, the way household_delete does it.
select pg_temp.as_service();
select is((api.account_delete_prepare(pg_temp.uid('Nina')) ->> 'household_deleted'), 'true',
  'the only person of a family deletes the account, and the family is marked deleted');
select pg_temp.owner();
select is((select count(*) from app.household where name = 'Solo1' and deleted_at is not null), 1::bigint,
  'the family is marked deleted');
select is((select count(*) from app.device where label = 'Nina-Phone' and revoked_at is null), 0::bigint,
  'every device of that family is revoked');
select is((select count(*) from auth.sessions where id = (select sid from pp where name = 'Nina')), 0::bigint,
  'its sessions are gone');
select is((select count(*) from app.audit_log where action = 'delete' and entity_id = (select id from hh where name = 'Solo1')),
  0::bigint, 'the family deletion is not audited as a family delete (the account deletion is)');
select is((select count(*) from app.audit_log where action = 'account_delete' and entity_id = pg_temp.prof('Nina')),
  1::bigint, 'the account deletion of the sole person is audited');

-- A bare account, and a family already deleted: nothing to close, the call succeeds.
select pg_temp.as_service();
select is((api.account_delete_prepare(pg_temp.uid('Solo')) ->> 'ok'), 'true',
  'an account in no family may be deleted');
select is((api.account_delete_prepare(pg_temp.uid('Rita')) ->> 'household_deleted'), 'false',
  'a deleted family is not marked again');
select pg_temp.owner();
select is((select count(*) from app.household where name = 'Rita' and deleted_at is not null), 1::bigint,
  'the deleted family stays deleted');
select is((select count(*) from app.household where name = 'Mb' and deleted_at is null), 1::bigint,
  'another family is untouched');
select is((select count(*) from app.device where label = 'Fritz-Phone' and revoked_at is null), 1::bigint,
  'and its guardian keeps the phone');

-- ============================================================ apple tokens: service only, read only
-- Social sign-in was removed (20261017100000): nothing stores a token, account-delete only reads
-- what accounts from before may hold.
select pg_temp.as_phone('Hugo-Phone');
select throws_ok(format($$ select api.apple_token_get(%L) $$, pg_temp.uid('Hugo')),
  '42501', null, 'a signed-in account cannot read an Apple token');
select throws_ok('select count(*) from app.apple_token', '42501', null,
  'and cannot read the token table');
select pg_temp.as_fake_service();
select throws_ok(format($$ select api.apple_token_get(%L) $$, pg_temp.uid('Hugo')),
  '42501', 'service role required', 'a user claim is refused by apple_token_get');
select pg_temp.owner();
select hasnt_function('api', 'apple_token_put', array['uuid', 'text'],
  'no function stores an Apple token any more');
select pg_temp.as_service();
select is((select api.apple_token_get(pg_temp.uid('Hugo'))), null::text, 'no token stored reads as null');
select pg_temp.owner();
insert into app.apple_token (user_id, refresh_token_enc) values (pg_temp.uid('Hugo'), 'enc-legacy');
select pg_temp.as_service();
select is((select api.apple_token_get(pg_temp.uid('Hugo')))::text, 'enc-legacy',
  'a token stored before the removal is still read, for the revocation');

-- The Apple token row is gone with its account (cascade).
select pg_temp.owner();
insert into app.apple_token (user_id, refresh_token_enc) values (pg_temp.uid('Quirin'), 'enc-q');
select is((select count(*) from app.apple_token where user_id = pg_temp.uid('Quirin')), 1::bigint,
  'a stored Apple token is kept until the account goes');
delete from auth.users where id = pg_temp.uid('Quirin');
select is((select count(*) from app.apple_token where user_id = pg_temp.uid('Quirin')), 0::bigint,
  'and is removed with the account');

-- ============================================================ mfa_reset_check
-- Hugo (guardian, phone) resets Ida's authenticator.
select pg_temp.as_phone('Hugo-Phone');
select throws_ok(format($$ select api.mfa_reset_check(%L, %L) $$, pg_temp.prof('Hugo'), pg_temp.prof('Hugo')),
  '22023', 'own factor', 'a guardian cannot reset their own factor here');
select throws_ok(format($$ select api.mfa_reset_check(%L, %L) $$, pg_temp.prof('Hugo'), pg_temp.prof('Jule')),
  '22023', 'target not a guardian', 'a member is not a target');
select throws_ok(format($$ select api.mfa_reset_check(%L, %L) $$, pg_temp.prof('Hugo'), pg_temp.prof('Kurt')),
  '22023', 'target has no account', 'a guardian without an account has no factor to reset');
select throws_ok(format($$ select api.mfa_reset_check(%L, %L) $$, pg_temp.prof('Hugo'), pg_temp.prof('Fritz')),
  'P0002', 'profile not found', 'a guardian of another family is not found');
select throws_ok(format($$ select api.mfa_reset_check(%L, %L) $$, pg_temp.prof('Hugo'), gen_random_uuid()),
  'P0002', 'profile not found', 'an unknown profile is not found');
select is((api.mfa_reset_check(pg_temp.prof('Hugo'), pg_temp.prof('Ida')) ->> 'user_id')::uuid,
  pg_temp.uid('Ida'), 'a co-guardian with an account is approved, with its Auth user');
select is((select count(*) from app.audit_log where action = 'mfa_reset' and entity_id = pg_temp.prof('Ida')),
  1::bigint, 'the reset is audited against the target');

-- Jule (a member) and a shared tablet cannot.
select pg_temp.as_phone('Jule-Phone');
select throws_ok(format($$ select api.mfa_reset_check(%L, %L) $$, pg_temp.prof('Jule'), pg_temp.prof('Ida')),
  '42501', 'guardian required', 'a member cannot reset a guardian factor');
select pg_temp.as_device('Me-iPad');
select throws_ok(format($$ select api.mfa_reset_check(%L, %L) $$, pg_temp.prof('Hugo'), pg_temp.prof('Ida')),
  '42501', 'personal device required', 'a shared tablet cannot reset a factor');
select pg_temp.owner();
select throws_ok(format($$ select api.mfa_reset_check(%L, %L) $$, pg_temp.prof('Hugo'), pg_temp.prof('Ida')),
  '42501', null, 'a signed-out caller cannot reset a factor');

-- ============================================================ member_security
select pg_temp.as_phone('Hugo-Phone');
select is((select jsonb_array_length(api.member_security(pg_temp.prof('Hugo'))))::int, 4,
  'the adults of the family are listed, the child is not');
select is((select (r ->> 'has_mfa')::boolean from (select jsonb_array_elements(api.member_security(pg_temp.prof('Hugo')))
  as r) x where (r ->> 'profile_id')::uuid = pg_temp.prof('Ida')), true,
  'a verified authenticator shows as has_mfa');
select is((select (r ->> 'has_mfa')::boolean from (select jsonb_array_elements(api.member_security(pg_temp.prof('Hugo')))
  as r) x where (r ->> 'profile_id')::uuid = pg_temp.prof('Hugo')), false,
  'no authenticator shows as has_mfa false');
select is((select (r ->> 'has_account')::boolean from (select jsonb_array_elements(api.member_security(pg_temp.prof('Hugo')))
  as r) x where (r ->> 'profile_id')::uuid = pg_temp.prof('Kurt')), false,
  'a guardian without an account shows as has_account false');
select pg_temp.as_phone('Jule-Phone');
select throws_ok(format($$ select api.member_security(%L) $$, pg_temp.prof('Jule')),
  '42501', 'guardian required', 'a member cannot read the second-factor state');
select pg_temp.owner();
select throws_ok(format($$ select api.member_security(%L) $$, pg_temp.prof('Hugo')),
  '42501', null, 'an anonymous caller cannot read it either');

select * from finish();
rollback;
