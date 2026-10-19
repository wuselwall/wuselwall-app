begin;
select plan(94);

-- Invitations (onboarding J2): a guardian invites an adult of the household, the invitee signs
-- in and joins. Everything runs as the database owner, except the invitee's calls (anon for the
-- preview, authenticated for accept and my_account) and the family's phones (authenticated on
-- their device's claims). Fixtures are named "inv-test" and the file never touches other rows.

delete from app.invitation_attempt;

-- ---- fixtures: two households, phones, a child, a shared tablet, a kiosk, a revoked phone ---
create temp table fx (name text primary key, id uuid not null);
grant all on fx to public;
insert into fx select n, gen_random_uuid() from unnest(array[
  'hh', 'hh2', 'papa', 'nb', 'julia', 'emma', 'd_papa', 'd_old', 'd_nb', 'd_emma', 'd_s', 'd_k',
  'sess_papa', 'sess_old', 'sess_nb', 'sess_emma', 'sess_s', 'sess_k', 'sess_julia', 'sess_other',
  'sess_hans', 'sess_eva']) n;
create function pg_temp.fid(p text) returns uuid language sql as $$ select id from fx where name = p $$;

create temp table users_made (name text primary key, uid uuid);
grant all on users_made to public;
insert into users_made values
  ('papa', app.create_auth_user('inv-test-papa@example.org', 'longpassword1')),
  ('old', app.create_auth_user('inv-test-old@example.org', 'longpassword1')),
  ('nb', app.create_auth_user('inv-test-nb@example.org', 'longpassword1')),
  ('emma', app.create_auth_user('inv-test-emma@example.org', 'longpassword1')),
  ('s', app.create_auth_user('inv-test-s@example.org', 'longpassword1')),
  ('k', app.create_auth_user('inv-test-k@example.org', 'longpassword1')),
  ('julia', app.create_auth_user('inv-test-julia@example.org', 'longpassword1')),
  ('other', app.create_auth_user('inv-test-other@example.org', 'longpassword1')),
  ('hans', app.create_auth_user('inv-test-hans@example.org', 'longpassword1')),
  ('eva', app.create_auth_user('inv-test-eva@example.org', 'longpassword1'));
-- Hans's address is not confirmed yet: he can only join once it is.
update auth.users set email_confirmed_at = null where email = 'inv-test-hans@example.org';
create function pg_temp.uid(p text) returns uuid language sql as $$ select uid from users_made where name = p $$;

insert into auth.sessions (id, user_id, created_at, updated_at) values
  (pg_temp.fid('sess_papa'), pg_temp.uid('papa'), now(), now()),
  (pg_temp.fid('sess_old'), pg_temp.uid('old'), now(), now()),
  (pg_temp.fid('sess_nb'), pg_temp.uid('nb'), now(), now()),
  (pg_temp.fid('sess_emma'), pg_temp.uid('emma'), now(), now()),
  (pg_temp.fid('sess_s'), pg_temp.uid('s'), now(), now()),
  (pg_temp.fid('sess_k'), pg_temp.uid('k'), now(), now()),
  (pg_temp.fid('sess_julia'), pg_temp.uid('julia'), now(), now()),
  (pg_temp.fid('sess_other'), pg_temp.uid('other'), now(), now()),
  (pg_temp.fid('sess_hans'), pg_temp.uid('hans'), now(), now()),
  (pg_temp.fid('sess_eva'), pg_temp.uid('eva'), now(), now());

insert into app.household (id, name) values (pg_temp.fid('hh'), 'Familie Huser'), (pg_temp.fid('hh2'), 'Nachbarn');
insert into app.profile (id, household_id, display_name, color, role, kind, auth_user_id) values
  (pg_temp.fid('papa'), pg_temp.fid('hh'), 'Papa Daniel', '#112233', 'guardian', 'adult', pg_temp.uid('papa')),
  (pg_temp.fid('nb'), pg_temp.fid('hh2'), 'Nachbar', '#112233', 'guardian', 'adult', pg_temp.uid('nb')),
  (pg_temp.fid('emma'), pg_temp.fid('hh'), 'Emma', '#ff8800', 'member', 'child', pg_temp.uid('emma')),
  (pg_temp.fid('julia'), pg_temp.fid('hh'), 'Julia', '#7B3FE4', 'member', 'adult', null);
insert into app.device (id, household_id, auth_user_id, auth_session_id, label, class, register, profile_id, revoked_at) values
  (pg_temp.fid('d_papa'), pg_temp.fid('hh'), pg_temp.uid('papa'), pg_temp.fid('sess_papa'), 'Papas Handy', 'personal', 'adult', pg_temp.fid('papa'), null),
  (pg_temp.fid('d_old'), pg_temp.fid('hh'), pg_temp.uid('old'), pg_temp.fid('sess_old'), 'Alter Handy', 'personal', 'adult', pg_temp.fid('papa'), now()),
  (pg_temp.fid('d_nb'), pg_temp.fid('hh2'), pg_temp.uid('nb'), pg_temp.fid('sess_nb'), 'Nachbar Handy', 'personal', 'adult', pg_temp.fid('nb'), null),
  (pg_temp.fid('d_emma'), pg_temp.fid('hh'), pg_temp.uid('emma'), pg_temp.fid('sess_emma'), 'Emmas Handy', 'personal', 'kid', pg_temp.fid('emma'), null),
  (pg_temp.fid('d_s'), pg_temp.fid('hh'), pg_temp.uid('s'), pg_temp.fid('sess_s'), 'Kinder-iPad', 'shared', 'kid', null, null),
  (pg_temp.fid('d_k'), pg_temp.fid('hh'), pg_temp.uid('k'), pg_temp.fid('sess_k'), 'Wand', 'kiosk', 'kiosk', null, null);

-- ---- helpers ------------------------------------------------------------------------------
-- Claims of one of the devices above, as the access-token hook would give them.
create function pg_temp.as(p_device text) returns void language plpgsql as $$
declare r app.device;
begin
  select * into r from app.device where id = pg_temp.fid(p_device);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', r.auth_user_id, 'role', 'authenticated',
    'session_id', r.auth_session_id, 'household_id', r.household_id, 'device_id', r.id, 'device_class', r.class)::text, true);
end $$;

-- Claims of an account with no household yet (no device claims).
create function pg_temp.account(p_user text, p_sess text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.uid(p_user), 'role', 'authenticated',
    'session_id', pg_temp.fid(p_sess))::text, true);
end $$;

create function pg_temp.from_ip(p_ip text) returns void language plpgsql as $$
begin
  perform set_config('request.headers', jsonb_build_object('x-forwarded-for', p_ip)::text, true);
end $$;

-- The invitee's anon preview, from one address.
create function pg_temp.preview(p_ip text, p_secret text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.from_ip(p_ip);
  execute 'set local role anon';
  r := api.invitation_preview(p_secret);
  execute 'reset role';
  return r;
end $$;

create temp table inv (name text primary key, id uuid, token text, code text, profile uuid);
grant all on inv to public;

-- Creates an invitation as the named device, acting as p_actor (a profile, needed on shared
-- devices), and remembers what the call returned under p_name.
create function pg_temp.create_inv(p_name text, p_device text, p_actor uuid, p_profile uuid,
                                   p_display text, p_role text, p_email text)
returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.as(p_device);
  r := api.invitation_create(p_actor, p_profile, p_display, p_role, p_email);
  if r ? 'token' then
    insert into inv values (p_name, (r ->> 'id')::uuid, r ->> 'token', r ->> 'code', (r ->> 'profile_id')::uuid);
  end if;
  return r;
end $$;

-- ---- create: who may invite ---------------------------------------------------------------
select throws_ok(format($$ select pg_temp.create_inv('x', 'd_emma', null, %L, null, 'member', null) $$, pg_temp.fid('julia')),
  '42501', 'guardian required', 'a child on a personal phone cannot invite');
select throws_ok(format($$ select pg_temp.create_inv('x', 'd_s', null, %L, null, 'member', null) $$, pg_temp.fid('julia')),
  '22023', 'acting profile required', 'a shared tablet needs an acting guardian');
select throws_ok(format($$ select pg_temp.create_inv('x', 'd_s', %L, %L, null, 'member', null) $$, pg_temp.fid('papa'), pg_temp.fid('julia')),
  '42501', 'guardian required', 'a shared tablet cannot invite without a guardian verification');
select throws_ok(format($$ select pg_temp.create_inv('x', 'd_k', %L, %L, null, 'member', null) $$, pg_temp.fid('papa'), pg_temp.fid('julia')),
  '42501', 'guardian required', 'a kiosk cannot invite');
update app.device set guardian_verified_until = now() + interval '10 minutes', guardian_verified_profile = pg_temp.fid('papa') where id = pg_temp.fid('d_s');
select throws_ok(format($$ select pg_temp.create_inv('x', 'd_s', %L, %L, null, 'member', null) $$, pg_temp.fid('papa'), pg_temp.fid('julia')),
  '42501', 'personal device required', 'a verified guardian on a shared tablet still cannot invite (personal phones only)');
update app.device set guardian_verified_until = null, guardian_verified_profile = null where id = pg_temp.fid('d_s');
select throws_ok(format($$ select pg_temp.create_inv('x', 'd_papa', null, %L, null, 'member', null) $$, pg_temp.fid('nb')),
  '22023', 'profile invalid', 'a profile of another household is refused');
select throws_ok(format($$ select pg_temp.create_inv('x', 'd_papa', null, %L, null, 'member', null) $$, pg_temp.fid('papa')),
  '22023', 'profile has an account', 'a profile that already has an account is refused');
select throws_ok(format($$ select pg_temp.create_inv('x', 'd_papa', null, %L, null, 'member', null) $$, pg_temp.fid('emma')),
  '22023', 'profile invalid', 'a child profile is refused');
select throws_ok($$ select pg_temp.create_inv('x', 'd_papa', null, null, 'Opa', 'owner', null) $$,
  '22023', 'role invalid', 'a role other than guardian or member is refused');
select throws_ok($$ select pg_temp.create_inv('x', 'd_papa', null, null, '  ', 'member', null) $$,
  '22023', 'name invalid', 'a new adult needs a name');
select throws_ok($$ select pg_temp.create_inv('x', 'd_papa', null, null, 'Opa', 'member', 'keine adresse') $$,
  '22023', 'email invalid', 'a malformed email is refused');
select is((select count(*)::int from app.invitation), 0, 'no refused call leaves an invitation behind');

-- ---- create: the family's forms ---------------------------------------------------------
-- Julia: an existing adult without an account, invited from Papa's phone.
create temp table r_julia as select pg_temp.create_inv('julia', 'd_papa', null, pg_temp.fid('julia'), null, 'guardian', null) r;
grant all on r_julia to public;
select ok((select r ->> 'token' from r_julia) ~ '^[0-9a-f]{32}$', 'the token is 128 random bits, as 32 hex digits');
select ok((select r ->> 'code' from r_julia) ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$', 'the code has 8 symbols of the unambiguous alphabet');
select ok((select (r ->> 'expires_at')::timestamptz from r_julia) between now() + interval '6 days 23 hours' and now() + interval '7 days 1 minute',
  'an invitation is valid for seven days');
select ok(exists (select 1 from app.invitation i join inv on inv.name = 'julia' and inv.id = i.id
                   where i.token_hash = app.invitation_hash(inv.token) and i.code_hash = app.invitation_hash(inv.code)),
  'the invitation stores the sha256 of the token and of the code');
select ok(not exists (select 1 from app.invitation i join inv on true
                       where i.token_hash = inv.token or i.code_hash = inv.code or i.token_hash = inv.code),
  'neither the token nor the code is stored in clear');
select is((select created_by_profile_id from app.invitation where id = (select id from inv where name = 'julia')), pg_temp.fid('papa'),
  'the inviter is recorded');
select is((select count(*)::int from app.audit_log where entity_type = 'invitation' and action = 'create'
            and entity_id = (select id from inv where name = 'julia')), 1, 'the creation is audited');
select ok(not exists (select 1 from app.audit_log where entity_type = 'invitation'
                        and diff::text like '%' || (select token from inv where name = 'julia') || '%'),
  'the token never reaches the audit log');

-- Re-sharing: a second invitation for Julia closes the first; the email is stored lower-cased.
create temp table r_julia2 as select pg_temp.create_inv('julia2', 'd_papa', null, pg_temp.fid('julia'), null, 'guardian', 'Julia@Example.org') r;
grant all on r_julia2 to public;
select is((select revoked_at is not null from app.invitation where id = (select id from inv where name = 'julia')), true,
  'a new invitation for the same adult revokes the open one');
select is((select email from app.invitation where id = (select id from inv where name = 'julia2')), 'julia@example.org',
  'the email is stored lower-cased');
select is((select count(*)::int from app.invitation where profile_id = pg_temp.fid('julia') and revoked_at is null), 1,
  'only one invitation for Julia is open');

-- Hans: a new adult, created on the way, with an email address (matched automatically).
create temp table r_hans as select pg_temp.create_inv('hans', 'd_papa', null, null, 'Hans', 'member', 'Inv-Test-Hans@example.org') r;
grant all on r_hans to public;
select is((select kind || ':' || role || ':' || (auth_user_id is null)::text from app.profile
            where id = (select profile from inv where name = 'hans')),
  'adult:member:true', 'a new profile is an adult member without an account');
select is((select email from app.invitation where id = (select id from inv where name = 'hans')), 'inv-test-hans@example.org',
  'the email matches the account case-insensitively (stored lower-cased)');

-- Eva: an adult invited by a token only (no email), then withdrawn.
create temp table r_eva as select pg_temp.create_inv('eva', 'd_papa', null, null, 'Eva', 'guardian', null) r;
grant all on r_eva to public;
select is((select email from app.invitation where id = (select id from inv where name = 'eva')), null, 'an invitation without an email has none');

-- ---- the list and the members ---------------------------------------------------------------
select pg_temp.as('d_papa');
set local role authenticated;
select is((select count(*)::int from api.invitations where household_id = pg_temp.fid('hh') and accepted_at is null), 3,
  'the guardian sees the open invitations of the household');
select ok(not exists (select 1 from information_schema.columns where table_schema = 'api' and table_name = 'invitations'
                        and column_name in ('token_hash', 'code_hash')),
  'the invitations view has no hashes');
select is((select has_account from api.members where id = pg_temp.fid('julia')), false, 'an adult without an account is reported as such');
select is((select has_account from api.members where id = pg_temp.fid('papa')), true, 'an adult with an account is reported as such');
reset role;

-- ---- revoke ------------------------------------------------------------------------------------
select pg_temp.as('d_papa');
select lives_ok(format($$ select api.invitation_revoke(null, %L) $$, (select id from inv where name = 'eva')),
  'a guardian can withdraw an open invitation');
select is((select revoked_at is not null from app.invitation where id = (select id from inv where name = 'eva')), true,
  'the withdrawn invitation is revoked');
select throws_ok(format($$ select api.invitation_revoke(null, %L) $$, (select id from inv where name = 'eva')),
  '22023', 'invitation not open', 'an invitation cannot be withdrawn twice');
select pg_temp.as('d_emma');
select throws_ok(format($$ select api.invitation_revoke(null, %L) $$, (select id from inv where name = 'julia2')),
  '42501', 'guardian required', 'a child cannot withdraw an invitation');

-- Eva again, a fresh token for the same adult.
select pg_temp.as('d_papa');
create temp table r_eva2 as select pg_temp.create_inv('eva2', 'd_papa', null, (select profile from inv where name = 'eva'), null, 'guardian', null) r;
grant all on r_eva2 to public;

-- ---- preview (anon): valid, forms, expired, withdrawn, garbage ---------------------------------
create temp table pv as select pg_temp.preview('198.51.100.2', (select code from inv where name = 'julia2')) p;
grant all on pv to public;
select is((select p ->> 'ok' from pv), 'true', 'a valid code previews');
select is((select p ->> 'household_name' from pv), 'Familie Huser', 'the preview names the household');
select is((select p ->> 'inviter_first_name' from pv), 'Papa', 'the preview names the inviter by first name only');
select is((select p ->> 'profile_name' from pv), 'Julia', 'the preview names the person');
select is((select p ->> 'role' from pv), 'guardian', 'the preview names the role');
select is((select array_agg(k order by k) from pv, jsonb_object_keys(p) k),
  array['expires_at', 'household_name', 'inviter_first_name', 'ok', 'profile_name', 'role'], 'the preview reveals nothing else');
select is(pg_temp.preview('198.51.100.3', lower(substr((select code from inv where name = 'julia2'), 1, 4) || '-'
            || substr((select code from inv where name = 'julia2'), 5)))  ->> 'ok',
  'true', 'a code typed in lower case with a hyphen previews');
select is(pg_temp.preview('198.51.100.4', (select token from inv where name = 'julia2')) ->> 'ok', 'true', 'the token previews too');
select is(pg_temp.preview('198.51.100.5', (select token from inv where name = 'julia')) ->> 'reason', 'invalid',
  'a replaced invitation previews as invalid');
select is(pg_temp.preview('198.51.100.6', 'NICHTCODE') ->> 'reason', 'invalid', 'garbage previews as invalid');
select is(pg_temp.preview('198.51.100.6', '') ->> 'reason', 'invalid', 'an empty secret previews as invalid');
select is(pg_temp.preview('198.51.100.6', null) ->> 'reason', 'invalid', 'a missing secret is invalid, not an error');
update app.invitation set expires_at = now() - interval '1 minute' where id = (select id from inv where name = 'hans');
select is(pg_temp.preview('198.51.100.7', (select token from inv where name = 'hans')) ->> 'reason', 'expired',
  'an expired invitation previews as expired');
update app.invitation set expires_at = now() + interval '7 days' where id = (select id from inv where name = 'hans');
select is(pg_temp.preview('198.51.100.8', (select code from inv where name = 'eva')) ->> 'reason', 'invalid',
  'a withdrawn invitation previews as invalid');
select is((select count(*)::int from app.invitation_attempt where client_key = 'invite:198.51.100.8'), 1,
  'every preview that gets to a lookup is logged');

-- Anon cannot create or read the list.
select pg_temp.from_ip('198.51.100.10');
set local role anon;
select throws_ok($$ select api.invitation_create(null, null, 'X', 'member', null) $$, '42501',
  'permission denied for function invitation_create', 'anon cannot create an invitation');
select throws_ok($$ select count(*) from api.invitations $$, '42501', 'permission denied for view invitations',
  'anon cannot read the invitations');
reset role;

-- The preview's rate limit: twenty calls per address, then refused; the refusal is not logged.
create temp table rl as select pg_temp.preview('198.51.100.20', 'NICHTCODE') p from generate_series(1, 20);
grant all on rl to public;
select is((select count(*)::int from rl where p ->> 'reason' = 'invalid'), 20, 'twenty previews from one address are answered');
select is(pg_temp.preview('198.51.100.20', (select code from inv where name = 'julia2')) ->> 'reason', 'rate_limited',
  'the twenty-first preview from the same address is refused, even with a valid code');
select is(pg_temp.preview('198.51.100.21', (select code from inv where name = 'julia2')) ->> 'ok', 'true',
  'another address is not affected');

-- ---- accept: account state first ----------------------------------------------------------------
-- Papa's account already has a household: refused whatever it presents.
select pg_temp.account('papa', 'sess_papa');
set local role authenticated;
select throws_ok(format($$ select api.invitation_accept(%L, null, null, null, 'Handy') $$, (select code from inv where name = 'julia2')),
  '42501', 'already in a household', 'an account with a household cannot accept another');
reset role;
-- A shared tablet's own user is a device, not a person who can start a family.
select pg_temp.account('s', 'sess_s');
set local role authenticated;
select throws_ok(format($$ select api.invitation_accept(%L, null, null, null, 'Tablet') $$, (select code from inv where name = 'julia2')),
  '42501', 'already in a household', 'a device user cannot accept an invitation');
reset role;
-- Input checks come first, and write nothing.
select pg_temp.account('julia', 'sess_julia');
set local role authenticated;
select throws_ok(format($$ select api.invitation_accept(%L, null, null, null, '  ') $$, (select code from inv where name = 'julia2')),
  '22023', 'label required', 'the device label is required');
select throws_ok(format($$ select api.invitation_accept(%L, null, '   ', null, 'Handy') $$, (select code from inv where name = 'julia2')),
  '22023', 'name invalid', 'a blank name is refused');
select throws_ok(format($$ select api.invitation_accept(%L, null, null, 'rot', 'Handy') $$, (select code from inv where name = 'julia2')),
  '22023', 'colour invalid', 'a colour that is not hex is refused');
reset role;
select is((select accepted_at is null from app.invitation where id = (select id from inv where name = 'julia2')), true,
  'refused accepts spend nothing');

-- ---- accept by email: confirmed address only, and the right one ----------------------------------
select pg_temp.account('hans', 'sess_hans');
set local role authenticated;
select throws_ok(format($$ select api.invitation_accept(null, %L, null, null, 'Handy') $$, (select id from inv where name = 'hans')),
  '42501', 'email not confirmed', 'an unconfirmed address cannot accept by email');
reset role;
select pg_temp.account('other', 'sess_other');
set local role authenticated;
select throws_ok(format($$ select api.invitation_accept(null, %L, null, null, 'Handy') $$, (select id from inv where name = 'hans')),
  '42501', 'not invited', 'another address cannot accept an invitation made for Hans');
reset role;

-- Unconfirmed, the invitation naming Hans's address is not offered on his account.
select pg_temp.account('hans', 'sess_hans');
set local role authenticated;
select is(jsonb_array_length(api.my_account() -> 'pending_invitations'), 0,
  'an unconfirmed address is offered no invitation');
reset role;

-- Hans confirms his address: the waiting invitation shows on his account (H0).
update auth.users set email_confirmed_at = now() where id = pg_temp.uid('hans');
select pg_temp.account('hans', 'sess_hans');
set local role authenticated;
select is((api.my_account() -> 'pending_invitations' -> 0 ->> 'household_name'), 'Familie Huser',
  'a confirmed address sees the invitation that names it');
select is((api.my_account() -> 'pending_invitations' -> 0 ->> 'inviter_first_name'), 'Papa',
  'the waiting invitation names the inviter by first name');
select is((api.my_account() -> 'pending_invitations' -> 0 ->> 'profile_name'), 'Hans', 'and the person it is for');
select is((api.my_account() ->> 'has_household')::boolean, false, 'the account still has no household');
select ok(api.my_account() ? 'household_creation' and api.my_account() ? 'full_name' and api.my_account() ? 'user_id',
  'my_account keeps its fields');
select lives_ok(format($$ select api.invitation_accept(null, %L, 'Hans Huser', '#1A4FA8', 'Hans iPhone') $$, (select id from inv where name = 'hans')),
  'a confirmed address accepts by invitation id');
reset role;
select is((select p.display_name || ' ' || p.color || ' ' || p.role from app.profile p
            where p.id = (select profile from inv where name = 'hans')),
  'Hans Huser #1A4FA8 member', 'the edited name and colour, and the invited role, apply');
select is((select accepted_at is not null from app.invitation where id = (select id from inv where name = 'hans')), true,
  'the invitation is spent');

-- Accept by code: Julia. Her own name and colour, edited on the way in.
select pg_temp.account('julia', 'sess_julia');
set local role authenticated;
select is((api.invitation_accept((select code from inv where name = 'julia2'), null, 'Julia S.', '#08737F', 'Julias iPhone') ->> 'ok'),
  'true', 'a code joins the family');
reset role;
select is((select p.display_name || ' ' || p.color from app.profile p where p.id = pg_temp.fid('julia')), 'Julia S. #08737F',
  'the edited name and colour are kept');
select is((select auth_user_id = pg_temp.uid('julia') from app.profile where id = pg_temp.fid('julia')), true,
  'the profile is linked to the account');
select is((select count(*)::int from app.device where auth_user_id = pg_temp.uid('julia') and class = 'personal'
            and profile_id = pg_temp.fid('julia') and household_id = pg_temp.fid('hh') and auth_session_id = pg_temp.fid('sess_julia')), 1,
  'this session is the personal device of the new member');
select is((select accepted_by_user from app.invitation where id = (select id from inv where name = 'julia2')), pg_temp.uid('julia'),
  'the invitation records who accepted it');
select is((select count(*)::int from app.audit_log where entity_type = 'invitation' and action = 'accept'
            and entity_id = (select id from inv where name = 'julia2') and diff ->> 'inviter_profile_id' = pg_temp.fid('papa')::text), 1,
  'the acceptance is audited with the inviter');
select is((select c ->> 'household_id' from (select app.custom_access_token_hook(jsonb_build_object(
            'user_id', pg_temp.uid('julia'), 'claims', jsonb_build_object('session_id', pg_temp.fid('sess_julia')))) -> 'claims' as c) x),
  pg_temp.fid('hh')::text, 'the token gives the household claims after joining');

-- Single use: a spent code answers invalid for another account; Julia cannot join twice.
select pg_temp.account('other', 'sess_other');
set local role authenticated;
select is((api.invitation_accept((select code from inv where name = 'julia2'), null, null, null, 'Handy') ->> 'reason'),
  'invalid', 'a spent code is refused for another account');
reset role;
select pg_temp.account('julia', 'sess_julia');
set local role authenticated;
select throws_ok(format($$ select api.invitation_accept(%L, null, null, null, 'Handy') $$, (select code from inv where name = 'julia2')),
  '42501', 'already in a household', 'Julia, now a member, cannot accept a second household');
reset role;
select pg_temp.as('d_papa');
set local role authenticated;
select is((select has_account from api.members where id = pg_temp.fid('julia')), true, 'the member now has an account');
reset role;

-- ---- accept by token; expired refused ----------------------------------------------------------
select pg_temp.account('eva', 'sess_eva');
set local role authenticated;
select is((api.invitation_accept((select token from inv where name = 'eva2'), null, null, null, 'Evas Handy') ->> 'ok'),
  'true', 'a token joins the family');
reset role;
select is((select profile from inv where name = 'eva2'), (select profile from inv where name = 'eva'),
  'the token belongs to the profile of the earlier invitation');

create temp table r_old as select pg_temp.create_inv('old', 'd_papa', null, null, 'Onkel', 'member', null) r;
grant all on r_old to public;
update app.invitation set expires_at = now() - interval '1 minute' where id = (select id from inv where name = 'old');
select pg_temp.account('other', 'sess_other');
set local role authenticated;
select is((api.invitation_accept((select code from inv where name = 'old'), null, null, null, 'Handy') ->> 'reason'),
  'expired', 'an expired invitation is refused');
reset role;
select is((select accepted_at is null from app.invitation where id = (select id from inv where name = 'old')), true,
  'an expired invitation stays unspent');

-- ---- other households, a revoked phone, the export ------------------------------------------------
select pg_temp.as('d_nb');
set local role authenticated;
select is((select count(*)::int from api.invitations where household_id = pg_temp.fid('hh')), 0,
  'another household does not see these invitations');
reset role;
select pg_temp.as('d_old');
set local role authenticated;
select is((select count(*)::int from api.invitations where household_id = pg_temp.fid('hh')), 0,
  'a revoked phone sees no invitations');
reset role;
select pg_temp.as('d_papa');
select ok(api.household_export(null) -> 'tables' ? 'invitation', 'the export has the invitations');
select ok(not (api.household_export(null) -> 'tables' -> 'invitation')::text like '%token_hash%', 'the export carries no token hash');
select ok(not (api.household_export(null) -> 'tables' -> 'invitation')::text like '%code_hash%', 'the export carries no code hash');
select ok(not (api.household_export(null) -> 'tables' -> 'invitation')::text like '%accepted_by_user%', 'the export carries no Auth user id');

select is((select name from api.household where id = pg_temp.fid('hh')), 'Familie Huser',
  'the household name is readable to its members');
select pg_temp.as('d_nb');
set local role authenticated;
select is((select count(*)::int from api.household where id = pg_temp.fid('hh')), 0,
  'another household does not see the name');
reset role;

-- ---- overall limit: three hundred calls in ten minutes stop the lookups for everyone -------------
insert into app.invitation_attempt (client_key, success)
  select 'invite:203.0.113.99', true from generate_series(1, 300);
select is(pg_temp.preview('198.51.100.90', (select code from inv where name = 'julia2')) ->> 'reason', 'rate_limited',
  'overall, three hundred calls in ten minutes stop the invitation lookups for everyone');

select * from finish();
rollback;
