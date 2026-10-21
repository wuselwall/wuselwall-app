begin;
select plan(91);

-- J6 Leave (specs/20, specs/16 step 9.6): leave, delete (at once), and for a family deleted before
-- deletion was immediate: restore, leave a deleted family, purge.
-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
update app.instance_setting set value = '"code"' where key = 'household_creation';

-- Named people, devices and sessions of the test (the test role owns them).
create temp table pp (name text primary key, uid uuid, prof uuid, hh uuid, sid uuid);
create temp table dd (name text primary key, id uuid, hh uuid, cls text, sid uuid, uid uuid, prof uuid);
create temp table hh (name text primary key, id uuid);
create temp table res (r jsonb);
create temp table res2 (r jsonb);
grant all on pp, dd, hh, res, res2 to public;

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

-- A new session for an account, as a fresh sign-in makes one.
create function pg_temp.new_session(p_name text) returns void language plpgsql as $$
declare v_sid uuid := gen_random_uuid(); p pp;
begin
  select * into p from pp where name = p_name;
  insert into auth.sessions (id, user_id, created_at, updated_at) values (v_sid, p.uid, now(), now());
  update pp set sid = v_sid where name = p_name;
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

create function pg_temp.as_account(p_name text) returns void language plpgsql as $$
declare p pp;
begin
  select * into p from pp where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p.uid, 'role', 'authenticated',
    'session_id', p.sid)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- Back to the test role (owner), without claims.
create function pg_temp.owner() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'none', true);
end $$;

-- Rows visible in every api view to the current role; views the role may not read count 0.
create function pg_temp.visible_rows() returns bigint language plpgsql as $$
declare v record; n bigint := 0; c bigint;
begin
  for v in select cl.relname from pg_class cl join pg_namespace s on s.oid = cl.relnamespace
            where s.nspname = 'api' and cl.relkind = 'v' loop
    begin
      execute format('select count(*) from api.%I', v.relname) into c;
      n := n + c;
    exception when insufficient_privilege then null;
    end;
  end loop;
  return n;
end $$;

-- The token hook's claims for an account on its current session.
create function pg_temp.hook_claims(p_name text) returns jsonb language plpgsql as $$
declare p pp;
begin
  select * into p from pp where name = p_name;
  return app.custom_access_token_hook(jsonb_build_object('user_id', p.uid,
    'claims', jsonb_build_object('session_id', p.sid)))->'claims';
end $$;

-- ============================================================ households and people
insert into hh (name, id) select n, gen_random_uuid() from unnest(array['Huser', 'Last', 'Bauer', 'Rest', 'Cora', 'Alt', 'Frisch', 'Live']) n;
insert into app.household (id, name) select id, name from hh;

-- Huser: Daniel (guardian, phone), Julia (guardian, no account), Paul (adult member, phone),
-- Emma (child), Kind (a child with an account, on a phone), an iPad and a kiosk.
select pg_temp.person('Daniel', (select id from hh where name = 'Huser'), 'guardian', 'adult', 'daniel@example.org');
select pg_temp.phone('Daniel', 'Daniel-Phone', 'adult');
select pg_temp.person('Julia', (select id from hh where name = 'Huser'), 'guardian', 'adult', null);
select pg_temp.person('Paul', (select id from hh where name = 'Huser'), 'member', 'adult', 'paul@example.org');
select pg_temp.phone('Paul', 'Paul-Phone', 'adult');
select pg_temp.person('Emma', (select id from hh where name = 'Huser'), 'member', 'child', null);
select pg_temp.person('Kind', (select id from hh where name = 'Huser'), 'member', 'child', 'kind@example.org');
select pg_temp.phone('Kind', 'Kind-Phone', 'kid');
select pg_temp.device_user('A-iPad', (select id from hh where name = 'Huser'), 'shared');
select pg_temp.device_user('A-Kiosk', (select id from hh where name = 'Huser'), 'kiosk');

-- Last: Daniel2 is the only guardian with an account; Emma2 is a child.
select pg_temp.person('Daniel2', (select id from hh where name = 'Last'), 'guardian', 'adult', 'daniel2@example.org');
select pg_temp.phone('Daniel2', 'Daniel2-Phone', 'adult');
select pg_temp.person('Emma2', (select id from hh where name = 'Last'), 'member', 'child', null);

-- Solo: an account in no family at all.
do $$ declare v_uid uuid := app.create_auth_user('solo@example.org', 'longpassword1', '{}'); v_sid uuid := gen_random_uuid();
begin
  insert into auth.sessions (id, user_id, created_at, updated_at) values (v_sid, v_uid, now(), now());
  insert into pp values ('Solo', v_uid, null, null, v_sid);
end $$;

-- ============================================================ leave (J6)
-- Refusals, raised with nothing written: a child, a kiosk, a shared tablet.
select pg_temp.as_phone('Kind-Phone');
select throws_ok(format($$ select api.account_leave(%L) $$, (select prof from pp where name = 'Kind')),
  '42501', 'only adults have an account', 'a child with an account cannot leave');
select pg_temp.as_device('A-Kiosk');
select throws_ok(format($$ select api.account_leave(%L) $$, (select prof from pp where name = 'Emma')),
  '42501', 'personal device required', 'a kiosk cannot leave an account');
select pg_temp.as_device('A-iPad');
select throws_ok(format($$ select api.account_leave(%L) $$, (select prof from pp where name = 'Emma')),
  '42501', 'personal device required', 'a shared tablet cannot leave an account');
select pg_temp.as_phone('Daniel2-Phone');
select throws_ok(format($$ select api.account_leave(%L) $$, (select prof from pp where name = 'Daniel2')),
  '42501', 'last guardian with an account', 'the last guardian with an account cannot leave while others are in the family');
select pg_temp.owner();
select is((select auth_user_id is not null from app.profile where display_name = 'Daniel2'), true,
  'a refused leave keeps the account linked');
select pg_temp.as_account('Daniel2');
select is(api.my_account() ->> 'household_name', 'Last', 'the family name is given to its guardians');
select is(api.my_account() ->> 'leave_blocked', 'last_guardian', 'the app is told why the last guardian cannot leave');
select pg_temp.owner();

-- An adult member leaves: the profile stays without the account, the devices are revoked.
select pg_temp.as_phone('Paul-Phone');
select is((api.account_leave((select prof from pp where name = 'Paul')) ->> 'ok'), 'true',
  'an adult member leaves the family');
select pg_temp.owner();
select is((select auth_user_id from app.profile where display_name = 'Paul'), null::uuid,
  'the profile is unlinked from the account');
select is((select count(*) from app.profile where display_name = 'Paul'), 1::bigint,
  'the profile stays in the family with its history');
select is((select count(*) from app.device where auth_user_id = (select uid from pp where name = 'Paul') and revoked_at is null),
  0::bigint, 'every device of the account is revoked');
select is((select count(*) from auth.sessions where id = (select sid from pp where name = 'Paul')), 1::bigint,
  'the session is kept, so the account stays signed in');
select is((select count(*) from app.audit_log where action = 'leave' and entity_id = (select prof from pp where name = 'Paul')),
  1::bigint, 'the leave is audited');
select pg_temp.as_account('Paul');
select is((api.my_account() ->> 'has_household')::boolean, false, 'the account has no household after leaving');
select is(api.my_account() ->> 'deleted_household', null, 'and no deleted household either');
select is(pg_temp.visible_rows(), 0::bigint, 'the account sees nothing in any api view');
select pg_temp.owner();
select is(pg_temp.hook_claims('Paul') ->> 'household_id', null, 'the token hook gives no household claims after leaving');

-- A second guardian with an account: the first guardian may leave.
select pg_temp.person('Julia2', (select id from hh where name = 'Last'), 'guardian', 'adult', 'julia2@example.org');
select pg_temp.as_phone('Daniel2-Phone');
select is((api.account_leave((select prof from pp where name = 'Daniel2')) ->> 'ok'), 'true',
  'the last guardian leaves once a second guardian has an account');
select pg_temp.owner();
select is((select auth_user_id from app.profile where display_name = 'Daniel2'), null::uuid,
  'the leaving guardian keeps the profile without the account');
select is((select count(*) from app.device where auth_user_id = (select uid from pp where name = 'Daniel2') and revoked_at is null),
  0::bigint, 'the leaving guardian is signed out of every device');

-- After leaving, the same session can start a family of its own (open creation).
update app.instance_setting set value = '"open"' where key = 'household_creation';
select pg_temp.as_account('Daniel2');
select is((api.household_create('Neue Familie', 'Daniel', '#7B3FE4', 'Europe/Berlin', 'de-DE', null, false, 'Mein Telefon') ->> 'ok'),
  'true', 'a left account on the same session can create a new family');
select pg_temp.owner();
select is((select count(*) from app.household where name = 'Last'), 1::bigint,
  'the family it left is still there');
select pg_temp.as_account('Daniel2');
select is((api.current_device() ->> 'revoked')::boolean, false, 'the new family phone is live on the same session');
select pg_temp.owner();

-- ============================================================ delete (J6)
-- Bauer: Bruno (guardian, phone), Mia (adult member, phone), a shared tablet and a kiosk, and
-- open codes, a feed token and a pairing request.
select pg_temp.person('Bruno', (select id from hh where name = 'Bauer'), 'guardian', 'adult', 'bruno@example.org');
select pg_temp.phone('Bruno', 'Bruno-Phone', 'adult');
select pg_temp.person('Mia', (select id from hh where name = 'Bauer'), 'member', 'adult', 'mia@example.org');
select pg_temp.phone('Mia', 'Mia-Phone', 'adult');
select pg_temp.device_user('B-iPad', (select id from hh where name = 'Bauer'), 'shared');
select pg_temp.device_user('B-Kiosk', (select id from hh where name = 'Bauer'), 'kiosk');
insert into app.enrolment_code (household_id, code_hash, label, class, register, expires_at)
  values ((select id from hh where name = 'Bauer'), 'codehash-bauer', 'Tablet', 'shared', 'kid', now() + interval '10 minutes');
insert into app.calendar_feed_token (household_id, label, token_hash)
  values ((select id from hh where name = 'Bauer'), 'Familienkalender', 'feedhash-bauer-0123456789');
insert into app.pairing_request (secret_hash, code_hash, expires_at, client_key, status, household_id,
                                 auth_user_id, approved_at)
  values ('secrethash-bauer', 'pairhash-bauer', now() + interval '5 minutes', 'test', 'approved',
          (select id from hh where name = 'Bauer'), (select uid from dd where name = 'B-Kiosk'), now());

select pg_temp.as_phone('Mia-Phone');
select throws_ok(format($$ select api.household_delete(%L, 'Bauer') $$, (select prof from pp where name = 'Mia')),
  '42501', 'guardian required', 'a member cannot delete the family');
select pg_temp.as_device('B-iPad');
select throws_ok(format($$ select api.household_delete(%L, 'Bauer') $$, (select prof from pp where name = 'Bruno')),
  '42501', 'personal device required', 'a shared tablet cannot delete the family');
select pg_temp.as_device('B-Kiosk');
select throws_ok(format($$ select api.household_delete(%L, 'Bauer') $$, (select prof from pp where name = 'Bruno')),
  '42501', 'personal device required', 'a kiosk cannot delete the family');
select pg_temp.as_phone('Bruno-Phone');
select throws_ok(format($$ select api.household_delete(%L, 'Bauerr') $$, (select prof from pp where name = 'Bruno')),
  '22023', 'family name does not match', 'a wrong name is refused');
select pg_temp.owner();
select is((select count(*) from app.household where name = 'Bauer' and deleted_at is null), 1::bigint,
  'a refused delete does not delete');
select pg_temp.as_phone('Bruno-Phone');
insert into res select api.household_delete((select prof from pp where name = 'Bruno'), '  bAUER ');
select pg_temp.owner();
select is((select r ->> 'ok' from res), 'true', 'the typed name, trimmed and in any case, deletes the family');
select is((select r ->> 'purge_after' from res) is not null, true, 'the answer keeps purge_after for the previous app');
select is((select count(*) from app.household where name = 'Bauer'), 0::bigint, 'the household is deleted at once');
select is((select count(*) from app.profile where household_id = (select id from hh where name = 'Bauer')), 0::bigint,
  'its profiles go with it');
select is((select count(*) from app.device where household_id = (select id from hh where name = 'Bauer')), 0::bigint,
  'its devices go with it');
select is((select count(*) from auth.sessions where id in ((select sid from pp where name = 'Bruno'), (select sid from pp where name = 'Mia'))),
  0::bigint, 'every session of the family is ended');
select is((select count(*) from auth.users where id in (select uid from dd where name in ('B-iPad', 'B-Kiosk'))),
  0::bigint, 'the Auth users of its shared tablet and kiosk are deleted');
select is((select count(*) from auth.users where id in (select uid from pp where name in ('Bruno', 'Mia'))),
  2::bigint, 'adult accounts are kept');
select is((select count(*) from app.enrolment_code where code_hash = 'codehash-bauer'), 0::bigint,
  'its enrolment codes are gone');
select is((select count(*) from app.calendar_feed_token where token_hash = 'feedhash-bauer-0123456789'), 0::bigint,
  'its calendar feed tokens are gone');
select is((select count(*) from app.pairing_request where code_hash = 'pairhash-bauer'), 0::bigint,
  'its pairing requests are gone');
select is((select count(*) from app.audit_log where household_id = (select id from hh where name = 'Bauer')), 0::bigint,
  'nothing of the family is kept, not even its audit rows');

-- Afterwards both accounts are in no family, with nothing to restore, and may start another.
select pg_temp.new_session('Bruno');
select pg_temp.as_account('Bruno');
select is((api.my_account() ->> 'has_household')::boolean, false, 'the guardian is in no family after the delete');
select is(api.my_account() ->> 'deleted_household', null, 'and has no deleted family to restore');
select throws_ok($$ select api.household_restore() $$, '42501', 'no deleted household', 'a deleted family cannot be restored');
select pg_temp.owner();
select pg_temp.new_session('Mia');
select pg_temp.as_account('Mia');
select is((api.household_create('Mia neu', 'Mia', '#08737F', 'Europe/Berlin', 'de-DE', null, false, 'Mias Telefon') ->> 'ok'),
  'true', 'a member of the deleted family starts a new family at once');
select pg_temp.owner();

-- ============================================================ a family deleted before (J6)
-- Rest: deleted the way household_delete did before 20261019120000 (marked, devices revoked),
-- still within its 14 days. Rita (guardian, phone), Max (adult member, phone).
select pg_temp.person('Rita', (select id from hh where name = 'Rest'), 'guardian', 'adult', 'rita@example.org');
select pg_temp.phone('Rita', 'Rita-Phone', 'adult');
select pg_temp.person('Max', (select id from hh where name = 'Rest'), 'member', 'adult', 'max@example.org');
select pg_temp.phone('Max', 'Max-Phone', 'adult');
update app.household set deleted_at = now() where name = 'Rest';
update app.device set revoked_at = now() where household_id = (select id from hh where name = 'Rest');

-- The token hook gives no claims for a deleted family, even for a device that is not revoked.
update app.device set revoked_at = null where label = 'Rita-Phone';
select is(pg_temp.hook_claims('Rita') ->> 'household_id', null, 'the token hook gives no claims for a deleted family');

-- Device access is closed in the database too: the actor refuses, and RLS hides every row.
select pg_temp.as_phone('Rita-Phone');
select throws_ok(format($$ select api.household_export(%L) $$, (select prof from pp where name = 'Rita')),
  '42501', 'household deleted', 'the actor refuses inside a deleted family');
select is(pg_temp.visible_rows(), 0::bigint, 'api views are empty for a deleted family');
select is((select count(*) from app.household), 0::bigint, 'the household row is unreadable through RLS');
select pg_temp.owner();
update app.device set revoked_at = now() where label = 'Rita-Phone';

-- The account view: a guardian may restore, a member may not.
select pg_temp.as_account('Rita');
select is((api.my_account() -> 'deleted_household' ->> 'can_restore')::boolean, true,
  'a guardian of a deleted family can restore it');
select is((api.my_account() ->> 'has_household')::boolean, false, 'a deleted family is not a household for the app');
select is(api.my_account() ->> 'household_id', null, 'and it has no household id');
select is((api.my_account() -> 'deleted_household' ->> 'name'), 'Rest', 'the deleted family is named');
select is((api.my_account() -> 'deleted_household' ->> 'purge_after') is not null, true, 'the purge date is given');
select pg_temp.as_account('Max');
select is((api.my_account() -> 'deleted_household' ->> 'can_restore')::boolean, false, 'a member cannot restore');
select is((select api.my_profile()) is null, true, 'a deleted family is not a profile for the app');
select throws_ok($$ select api.household_create('Max neu', 'Max', '#08737F', 'Europe/Berlin', 'de-DE', null, false, 'x') $$,
  '42501', 'already in a household', 'a deleted family blocks a new one until it is restored or left');
select throws_ok($$ select api.household_restore() $$, '42501', 'guardian required', 'a member cannot restore');

-- A member leaves the deleted family to start afresh.
select is((api.account_leave_deleted() ->> 'ok'), 'true', 'a member leaves a deleted family to start afresh');
select is((api.my_account() ->> 'has_household')::boolean, false, 'after that the account has no household');
select is(api.my_account() ->> 'deleted_household', null, 'and no deleted family is shown');
select pg_temp.owner();
select is((select auth_user_id from app.profile where display_name = 'Max'), null::uuid,
  'the leave unlinks the profile from the deleted family');
select pg_temp.new_session('Max');
select pg_temp.as_account('Max');
select is((api.household_create('Max neu', 'Max', '#08737F', 'Europe/Berlin', 'de-DE', null, false, 'Max Telefon') ->> 'ok'),
  'true', 'after that the account starts a new family');
select pg_temp.owner();
select pg_temp.as_account('Solo');
select throws_ok($$ select api.account_leave_deleted() $$, '42501', 'no deleted household',
  'nothing to leave when the account is in no deleted family');

-- ============================================================ restore (J6)
-- Rita restores within 14 days, on a new session.
select pg_temp.owner();
select pg_temp.new_session('Rita');
select pg_temp.as_account('Rita');
select is((api.household_restore() ->> 'ok'), 'true', 'a guardian restores the family within 14 days');
select pg_temp.owner();
select is((select deleted_at is null from app.household where name = 'Rest'), true, 'the family is live again');
select is((select count(*) from app.device where profile_id = (select prof from pp where name = 'Rita')
             and class = 'personal' and revoked_at is null and auth_session_id = (select sid from pp where name = 'Rita')),
  1::bigint, 'this session is the family phone');
select is((select label from app.device where profile_id = (select prof from pp where name = 'Rita')
             and class = 'personal' and revoked_at is null), 'Rita-Phone', 'the phone keeps its label');
select is((select count(*) from app.device where household_id = (select id from hh where name = 'Rest') and revoked_at is null),
  1::bigint, 'the other devices stay revoked');
select is(pg_temp.hook_claims('Rita') ->> 'household_id', (select id::text from hh where name = 'Rest'),
  'the restored session gets the family claims');
select pg_temp.as_account('Rita');
select throws_ok($$ select api.household_restore() $$, '42501', 'already in a household', 'a restored family is not restored again');

-- Cora: deleted 15 days ago, so the window is over.
select pg_temp.owner();
select pg_temp.person('Carla', (select id from hh where name = 'Cora'), 'guardian', 'adult', 'carla@example.org');
select pg_temp.phone('Carla', 'Carla-Phone', 'adult');
update app.household set deleted_at = now() - interval '15 days' where name = 'Cora';
update app.device set revoked_at = now() where label = 'Carla-Phone';
select pg_temp.new_session('Carla');
select pg_temp.as_account('Carla');
select is((api.my_account() -> 'deleted_household' ->> 'can_restore')::boolean, false,
  'after 14 days a guardian cannot restore any more');
select throws_ok($$ select api.household_restore() $$, '42501', 'restore window passed', 'a restore after 14 days is refused');
select pg_temp.owner();
select is((select deleted_at is not null from app.household where name = 'Cora'), true,
  'a refused restore keeps the family deleted');

-- An account in no deleted family has nothing to restore.
select pg_temp.as_account('Solo');
select throws_ok($$ select api.household_restore() $$, '42501', 'no deleted household', 'nothing to restore for an account in no family');
select pg_temp.owner();

-- ============================================================ purge (J6, the job)
-- Alt: deleted 15 days ago, with a shared tablet and an adult account (Anton) on a phone.
-- Frisch: deleted yesterday, with a tablet. Live: not deleted, with a tablet.
select pg_temp.person('Anton', (select id from hh where name = 'Alt'), 'member', 'adult', 'anton@example.org');
select pg_temp.phone('Anton', 'Anton-Phone', 'adult');
select pg_temp.device_user('Alt-iPad', (select id from hh where name = 'Alt'), 'shared');
select pg_temp.device_user('Frisch-iPad', (select id from hh where name = 'Frisch'), 'shared');
select pg_temp.device_user('Live-iPad', (select id from hh where name = 'Live'), 'shared');
update app.household set deleted_at = now() - interval '15 days' where name = 'Alt';
update app.household set deleted_at = now() - interval '1 day' where name = 'Frisch';

-- Only the service role runs the job: the grant refuses everyone else, and the function
-- checks the role itself too.
select pg_temp.as_account('Solo');
select throws_ok($$ select api.household_purge_due() $$, '42501', 'permission denied for function household_purge_due',
  'a signed-in account cannot run the purge');
select pg_temp.owner();
select set_config('role', 'anon', true);
select throws_ok($$ select api.household_purge_due() $$, '42501', 'permission denied for function household_purge_due',
  'anon cannot run the purge');
select pg_temp.owner();
select set_config('request.jwt.claims', jsonb_build_object('role', 'authenticated')::text, true);
select throws_ok($$ select api.household_purge_due() $$, '42501', 'service role required',
  'the function refuses a caller whose token is not the service role');
select pg_temp.owner();

select set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
select set_config('role', 'service_role', true);
insert into res2 select api.household_purge_due();
select pg_temp.owner();
select is((select r ->> 'households' from res2), '2', 'the purge removes the families deleted 14 days ago (Alt and Cora)');
select is((select r ->> 'device_accounts' from res2), '1', 'and the Auth user of the shared tablet of Alt (Cora had none)');
select is((select count(*) from app.household where name = 'Alt'), 0::bigint, 'the household row is gone');
select is((select count(*) from app.household where name = 'Cora'), 0::bigint, 'the family deleted 15 days ago is gone too');
select is((select count(*) from app.profile where display_name = 'Anton'), 0::bigint, 'its family rows cascade away');
select is((select count(*) from app.audit_log where household_id = (select id from hh where name = 'Alt')), 0::bigint,
  'its audit rows cascade away');
select is((select count(*) from auth.users where id = (select uid from dd where name = 'Alt-iPad')), 0::bigint,
  'the device user of the purged family is deleted');
select is((select count(*) from auth.users where id = (select uid from pp where name = 'Anton')), 1::bigint,
  'an adult account is never deleted by the purge');
select is((select count(*) from auth.sessions where user_id = (select uid from pp where name = 'Anton')), 1::bigint,
  'the adult account keeps its session');
select is((select count(*) from app.household where name = 'Frisch'), 1::bigint,
  'a family deleted yesterday is kept');
select is((select count(*) from auth.users where id = (select uid from dd where name = 'Frisch-iPad')), 1::bigint,
  'and so is its device user');
select is((select count(*) from app.household where name = 'Live'), 1::bigint, 'a live family is kept');
select is((select count(*) from auth.users where id = (select uid from dd where name = 'Live-iPad')), 1::bigint,
  'and so is its device user');
select is((select count(*) from app.household where name in ('Rest', 'Cora')), 1::bigint,
  'the restored family stays and Cora, deleted 15 days ago, is gone');

select * from finish();
rollback;
