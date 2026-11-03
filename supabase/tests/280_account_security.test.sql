begin;
select plan(91);

-- Account security (20261102140000, security review 2026-11-01): the recorded proven
-- address (F1), the guardian's resets (F3), the claim bound to its client (F12), the locked
-- PIN counter (F15), the second factor on the account functions (F19), the reward balance
-- (F21) and the sign-up gate once the server is claimed (F22). Everything runs as the
-- database owner except the calls under test. All rolled back.
delete from app.household;
delete from app.founder_attempt;
delete from app.password_reset_attempt;
delete from app.setup_token;
delete from auth.users where email like '%@example.org';
update app.instance_setting set value = '"code"' where key = 'household_creation';

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

-- The address was proven the way GoTrue proves it: a code was mailed, then redeemed.
create function pg_temp.prove(p_name text) returns void language plpgsql as $$
begin
  update auth.users set confirmation_sent_at = now() - interval '1 minute', email_confirmed_at = null
   where id = (select uid from pp where name = p_name);
  update auth.users set email_confirmed_at = now() where id = (select uid from pp where name = p_name);
end $$;

-- A phone's claims: the hook's household claims, the assurance level, and a sign-in a
-- minute ago when p_fresh (otherwise an hour ago, as a refreshed old session carries).
create function pg_temp.as_phone(p_label text, p_aal text default 'aal2', p_fresh boolean default true)
returns void language plpgsql as $$
declare d dd; v_at bigint;
begin
  select * into d from dd where name = p_label;
  v_at := extract(epoch from now() - case when p_fresh then interval '1 minute' else interval '1 hour' end)::bigint;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.uid, 'role', 'authenticated',
    'session_id', d.sid, 'household_id', d.hh, 'device_id', d.id, 'device_class', d.cls, 'aal', p_aal,
    'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', v_at)))::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- A bare account (no device claims): what the hook issues before the second factor, or to
-- an account without a household.
create function pg_temp.as_account(p_name text, p_aal text default 'aal1') returns void language plpgsql as $$
declare p pp;
begin
  select * into p from pp where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p.uid, 'role', 'authenticated',
    'session_id', p.sid, 'aal', p_aal)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function pg_temp.as_anon(p_ip text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
  perform set_config('request.headers', jsonb_build_object('x-forwarded-for', p_ip)::text, true);
  perform set_config('role', 'anon', true);
end $$;

create function pg_temp.from_ip(p_ip text) returns void language plpgsql as $$
begin
  perform set_config('request.headers', jsonb_build_object('x-forwarded-for', p_ip)::text, true);
end $$;

create function pg_temp.owner() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.headers', '', true);
  perform set_config('role', 'none', true);
end $$;

create function pg_temp.hook(p_email text) returns jsonb language sql as $$
  select app.before_user_created_hook(jsonb_build_object(
    'metadata', jsonb_build_object('name', 'before-user-created'),
    'user', jsonb_build_object('email', p_email, 'app_metadata', jsonb_build_object('provider', 'email'))))
$$;

create function pg_temp.prof(p_name text) returns uuid language sql as $$ select prof from pp where name = p_name $$;
create function pg_temp.uid(p_name text) returns uuid language sql as $$ select uid from pp where name = p_name $$;
create function pg_temp.code(p_name text) returns text language sql as $$ select r ->> 'code' from res where name = p_name $$;

-- ============================================================ people
-- Ma: Gert, Hugo and Ida are guardians with phones (Ida with an authenticator), Ole an adult
-- member with a phone, Kid a child with a phone, Vera an adult without an account.
insert into app.household (id, name) values (gen_random_uuid(), 'Ma');
select pg_temp.person('Gert', (select id from app.household where name = 'Ma'), 'guardian', 'adult', 'gert@example.org');
select pg_temp.phone('Gert', 'Gert-Phone', 'adult');
select pg_temp.person('Hugo', (select id from app.household where name = 'Ma'), 'guardian', 'adult', 'hugo@example.org');
select pg_temp.phone('Hugo', 'Hugo-Phone', 'adult');
select pg_temp.person('Ida', (select id from app.household where name = 'Ma'), 'guardian', 'adult', 'ida@example.org');
select pg_temp.phone('Ida', 'Ida-Phone', 'adult');
insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at)
  values (gen_random_uuid(), pg_temp.uid('Ida'), 'Ida-App', 'totp', 'verified', now(), now());
select pg_temp.person('Ole', (select id from app.household where name = 'Ma'), 'member', 'adult', 'ole@example.org');
select pg_temp.phone('Ole', 'Ole-Phone', 'adult');
select pg_temp.person('Kid', (select id from app.household where name = 'Ma'), 'member', 'child', 'kid@example.org');
select pg_temp.phone('Kid', 'Kid-Phone', 'kid');
select pg_temp.person('Vera', (select id from app.household where name = 'Ma'), 'guardian', 'adult', null);

-- ============================================================ F1: the proven address
-- An account created without a mail (a device user, an autoconfirmed sign-up): not proven.
select is(app.proven_email(pg_temp.uid('Ole')), null, 'an address confirmed without a mailed code is not proven');
select is((select count(*)::int from app.proven_address where user_id = pg_temp.uid('Ole')), 0,
  'and nothing is recorded for it');

-- The sign-up confirmation records the address.
select pg_temp.prove('Ole');
select is(app.proven_email(pg_temp.uid('Ole')), 'ole@example.org', 'redeeming the mailed code proves the address');
select is((select email from app.proven_address where user_id = pg_temp.uid('Ole')), 'ole@example.org',
  'the proven address is recorded');

-- An email change applied without a mail (a server without mail) is not proven.
update auth.users set email = 'ole-new@example.org' where id = pg_temp.uid('Ole');
select is(app.proven_email(pg_temp.uid('Ole')), null, 'an address changed without a mail is not proven');
select is((select email from app.proven_address where user_id = pg_temp.uid('Ole')), 'ole@example.org',
  'the record keeps the address that was proven');

-- An invitation naming the unproven new address is neither offered nor accepted.
insert into app.household (id, name) values (gen_random_uuid(), 'Mb');
select pg_temp.person('Fritz', (select id from app.household where name = 'Mb'), 'guardian', 'adult', 'fritz@example.org');
select pg_temp.phone('Fritz', 'Fritz-Phone', 'adult');
insert into app.profile (household_id, display_name, color, role, kind)
values ((select id from app.household where name = 'Mb'), 'Neu', '#7B3FE4', 'guardian', 'adult');
insert into app.invitation (id, household_id, profile_id, role, email, token_hash, code_hash, created_by_profile_id, expires_at)
values ('55555555-5555-4555-8555-555555555555', (select id from app.household where name = 'Mb'),
        (select id from app.profile where display_name = 'Neu'), 'guardian', 'ole-new@example.org',
        app.invitation_hash('tok-ole-new'), app.invitation_hash('CODEOLE1'), pg_temp.prof('Fritz'), now() + interval '1 day');
update app.profile set auth_user_id = null, active = false where id = pg_temp.prof('Ole');
update app.device set revoked_at = now() where label = 'Ole-Phone';
select pg_temp.as_account('Ole', 'aal2');
select is(jsonb_array_length(api.my_account() -> 'pending_invitations'), 0,
  'an invitation naming the unproven new address is not offered');
select throws_ok($$ select api.invitation_accept(null, '55555555-5555-4555-8555-555555555555', null, null, 'Handy') $$,
  '42501', 'email not confirmed', 'nor can it be accepted by id');
select pg_temp.owner();

-- A secure email change completed by both codes (status 1, mailed today) proves the new address.
update auth.users set email = 'ole@example.org', email_change = 'ole-next@example.org',
       email_change_sent_at = now() - interval '2 minutes', email_change_confirm_status = 1
 where id = pg_temp.uid('Ole');
update auth.users set email = 'ole-next@example.org', email_change = '', email_change_confirm_status = 0
 where id = pg_temp.uid('Ole');
select is(app.proven_email(pg_temp.uid('Ole')), 'ole-next@example.org',
  'an email change confirmed from both addresses proves the new one');

-- The same change without the first confirmation (an autoconfirmed change with a stale pending
-- address) and one mailed more than a day ago prove nothing.
update auth.users set email_change = 'ole-stale@example.org',
       email_change_sent_at = now() - interval '2 minutes', email_change_confirm_status = 0
 where id = pg_temp.uid('Ole');
update auth.users set email = 'ole-stale@example.org', email_change = '' where id = pg_temp.uid('Ole');
select is(app.proven_email(pg_temp.uid('Ole')), null, 'a change nobody confirmed by mail is not proven');
update auth.users set email_change = 'ole-late@example.org',
       email_change_sent_at = now() - interval '2 days', email_change_confirm_status = 1
 where id = pg_temp.uid('Ole');
update auth.users set email = 'ole-late@example.org', email_change = '', email_change_confirm_status = 0
 where id = pg_temp.uid('Ole');
select is(app.proven_email(pg_temp.uid('Ole')), null, 'a change mailed more than a day ago is not proven');

-- A confirmation mailed long ago (an unconfirmed sign-up left behind, confirmed later when the
-- server switched mail off) proves nothing.
select pg_temp.person('Stale', (select id from app.household where name = 'Ma'), 'member', 'adult', 'stale@example.org');
update auth.users set confirmation_sent_at = now() - interval '2 days', email_confirmed_at = null where id = pg_temp.uid('Stale');
update auth.users set email_confirmed_at = now() where id = pg_temp.uid('Stale');
select is(app.proven_email(pg_temp.uid('Stale')), null, 'a confirmation mailed more than a day ago proves nothing');

select ok(not has_table_privilege('authenticated', 'app.proven_address', 'select')
          and not has_table_privilege('anon', 'app.proven_address', 'select'),
  'the proven addresses are read by no client');
select ok(not has_function_privilege('authenticated', 'app.proven_email(uuid)', 'execute'),
  'proven_email is internal');

-- ============================================================ F3: the guardian's resets
-- A stale sign-in: refused, however old the phone's session.
select pg_temp.as_phone('Gert-Phone', 'aal2', false);
select throws_ok(format('select api.password_reset_create(%L, %L)', pg_temp.prof('Gert'), pg_temp.prof('Hugo')),
  '42501', 'recent sign-in required', 'a reset code needs a sign-in of the last five minutes');
select throws_ok(format('select api.mfa_reset_check(%L, %L)', pg_temp.prof('Gert'), pg_temp.prof('Hugo')),
  '42501', 'recent sign-in required', 'so does the second-factor reset');
select pg_temp.owner();

-- A fresh second-factor entry alone (a stolen session that enrolled an authenticator) is no sign-in.
select pg_temp.as_phone('Gert-Phone', 'aal2', false);
select set_config('request.jwt.claims', (current_setting('request.jwt.claims', true)::jsonb
  || jsonb_build_object('amr', jsonb_build_array(
       jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now() - interval '1 hour')::bigint),
       jsonb_build_object('method', 'totp', 'timestamp', extract(epoch from now() - interval '1 minute')::bigint))))::text, true);
select throws_ok(format('select api.password_reset_create(%L, %L)', pg_temp.prof('Gert'), pg_temp.prof('Hugo')),
  '42501', 'recent sign-in required', 'a fresh second-factor step is not a fresh sign-in');
select throws_ok(format('select api.mfa_reset_check(%L, %L)', pg_temp.prof('Gert'), pg_temp.prof('Hugo')),
  '42501', 'recent sign-in required', 'for the second-factor reset too');
select pg_temp.owner();

-- A guardian with an authenticator at aal1: refused even with a fresh sign-in.
select pg_temp.as_phone('Ida-Phone', 'aal1', true);
select throws_ok(format('select api.password_reset_create(%L, %L)', pg_temp.prof('Ida'), pg_temp.prof('Hugo')),
  '42501', 'second factor required', 'a guardian with an authenticator needs aal2 for a reset code');
select throws_ok(format('select api.mfa_reset_check(%L, %L)', pg_temp.prof('Ida'), pg_temp.prof('Hugo')),
  '42501', 'second factor required', 'and for a second-factor reset');
select pg_temp.as_phone('Ida-Phone', 'aal2', true);
insert into res select 'hugo-by-ida', api.password_reset_create(pg_temp.prof('Ida'), pg_temp.prof('Hugo'));
select matches(pg_temp.code('hugo-by-ida'), '^[A-HJ-NP-Z2-9]{8}$', 'at aal2 with a fresh sign-in the code is issued');
select pg_temp.owner();

-- Gert resets Ida's authenticator, then wants a code for her: refused for a day.
select pg_temp.as_phone('Gert-Phone');
insert into res select 'ida-mfa', api.mfa_reset_check(pg_temp.prof('Gert'), pg_temp.prof('Ida'));
select is((select r ->> 'email' from res where name = 'ida-mfa'), 'ida@example.org',
  'the approved reset names the address for the notice');
select is((select r ->> 'display_name' from res where name = 'ida-mfa'), 'Ida', 'and the person');
select throws_ok(format('select api.password_reset_create(%L, %L)', pg_temp.prof('Gert'), pg_temp.prof('Ida')),
  '42501', 'second factor reset recently', 'no code from the guardian who just reset the second factor');
select pg_temp.as_phone('Hugo-Phone');
insert into res select 'ida-by-hugo', api.password_reset_create(pg_temp.prof('Hugo'), pg_temp.prof('Ida'));
select matches(pg_temp.code('ida-by-hugo'), '^[A-HJ-NP-Z2-9]{8}$', 'another guardian may still issue the code');
select pg_temp.owner();
update app.audit_log set occurred_at = now() - interval '6 days'
 where action = 'mfa_reset' and entity_id = pg_temp.prof('Ida');
select pg_temp.as_phone('Gert-Phone');
select throws_ok(format('select api.password_reset_create(%L, %L)', pg_temp.prof('Gert'), pg_temp.prof('Ida')),
  '42501', 'second factor reset recently', 'six days later it is still refused');
select pg_temp.owner();
update app.audit_log set occurred_at = now() - interval '8 days'
 where action = 'mfa_reset' and entity_id = pg_temp.prof('Ida');
select pg_temp.as_phone('Gert-Phone');
insert into res select 'ida-by-gert', api.password_reset_create(pg_temp.prof('Gert'), pg_temp.prof('Ida'));
select matches(pg_temp.code('ida-by-gert'), '^[A-HJ-NP-Z2-9]{8}$', 'after a week the same guardian may');

-- The other order: a code for Hugo, then his second factor: refused for a day.
insert into res select 'hugo-by-gert', api.password_reset_create(pg_temp.prof('Gert'), pg_temp.prof('Hugo'));
select throws_ok(format('select api.mfa_reset_check(%L, %L)', pg_temp.prof('Gert'), pg_temp.prof('Hugo')),
  '42501', 'password reset code issued recently', 'no second-factor reset from the guardian who just issued a code');
select pg_temp.owner();

-- The resets show on Today: to the person concerned and the other guardians, not the doer.
update app.audit_log set occurred_at = now() - interval '1 hour' where action = 'mfa_reset' and entity_id = pg_temp.prof('Ida');
select pg_temp.as_phone('Ida-Phone');
select is((select count(*)::int from jsonb_array_elements(api.notices(pg_temp.prof('Ida'))) n
            where n ->> 'kind' = 'mfa_reset' and n ->> 'name' = 'Gert' and (n ->> 'profile_id')::uuid = pg_temp.prof('Ida')),
  1, 'the person whose second factor was reset sees the notice, with the guardian who did it');
select is((select count(*)::int from jsonb_array_elements(api.notices(pg_temp.prof('Ida'))) n
            where n ->> 'kind' = 'password_reset_issued' and n ->> 'name' = 'Hugo'), 1,
  'and the code Hugo issued for her');
select pg_temp.as_phone('Hugo-Phone');
select is((select count(*)::int from jsonb_array_elements(api.notices(pg_temp.prof('Hugo'))) n
            where n ->> 'kind' = 'mfa_reset' and (n ->> 'profile_id')::uuid = pg_temp.prof('Ida')), 1,
  'another guardian sees the reset too');
select is((select count(*)::int from jsonb_array_elements(api.notices(pg_temp.prof('Hugo'))) n
            where n ->> 'kind' = 'password_reset_issued' and n ->> 'name' = 'Hugo'), 0,
  'but not what he did himself');
select lives_ok(format('select api.notice_dismiss(%L, %L)', pg_temp.prof('Hugo'),
  (select n ->> 'key' from jsonb_array_elements(api.notices(pg_temp.prof('Hugo'))) n where n ->> 'kind' = 'mfa_reset' limit 1)),
  'a reset notice is dismissed like any other');
select is((select count(*)::int from jsonb_array_elements(api.notices(pg_temp.prof('Hugo'))) n where n ->> 'kind' = 'mfa_reset'),
  0, 'and gone for him');
select pg_temp.as_phone('Gert-Phone');
select is((select count(*)::int from jsonb_array_elements(api.notices(pg_temp.prof('Gert'))) n where n ->> 'kind' = 'mfa_reset'),
  0, 'the guardian who reset it is not told');
select pg_temp.as_phone('Kid-Phone');
select is((select count(*)::int from jsonb_array_elements(api.notices(pg_temp.prof('Kid'))) n
            where n ->> 'kind' in ('mfa_reset', 'password_reset_issued')), 0, 'a child sees none of it');
select pg_temp.owner();

-- Redeeming a code ends every session of the account.
insert into auth.sessions (id, user_id, created_at, updated_at) values (gen_random_uuid(), pg_temp.uid('Hugo'), now(), now());
select is((select count(*)::int from auth.sessions where user_id = pg_temp.uid('Hugo')), 2, 'Hugo has two sessions');
select pg_temp.as_anon('203.0.113.7');
select is(api.password_reset_redeem('hugo@example.org', pg_temp.code('hugo-by-gert'), 'a brand new password'), '{"ok": true}'::jsonb,
  'the code redeems');
select pg_temp.owner();
select is((select count(*)::int from auth.sessions where user_id = pg_temp.uid('Hugo')), 0,
  'and every session of the account is gone');
select is((select diff ->> 'sessions_revoked' from app.audit_log where action = 'password_reset' and entity_id = pg_temp.prof('Hugo')),
  '2', 'the audit row says how many sessions ended');
select ok(not has_function_privilege('authenticated', 'app.revoke_auth_sessions(uuid)', 'execute'),
  'ending sessions is internal');

-- ============================================================ F12: the claim and its client
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));
delete from app.household where name = 'Mb';
create temp table founder as
  select app.create_auth_user('founder@example.org', 'longpassword1', '{}'::jsonb) as uid, gen_random_uuid() as sess;
insert into auth.sessions (id, user_id, created_at, updated_at) select sess, uid, now(), now() from founder;
create function pg_temp.as_founder() returns void language plpgsql as $$
declare r founder;
begin
  select * into r from founder;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', r.uid, 'role', 'authenticated', 'session_id', r.sess)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

select pg_temp.as_anon('10.0.0.1');
select is(api.setup_claim('dev-setup', 'founder@example.org') ->> 'claimed', 'true', 'the founder claims from one client');
select pg_temp.owner();
select is((select claimed_client from app.setup_token), '10.0.0.1', 'the claim records its client');

-- An autoconfirmed account (no mailed code) from another network: the claim alone does not found.
select pg_temp.as_founder();
select pg_temp.from_ip('10.0.1.2');
select is(api.household_create('Familie Test', 'Papa', '#2E7D6B', 'Europe/Berlin', 'de', null, false, 'Phone') ->> 'reason',
  'founder_code_required', 'an unproven address from another network needs the key');
select pg_temp.from_ip('10.0.0.77');
select is(api.household_create('Familie Test', 'Papa', '#2E7D6B', 'Europe/Berlin', 'de', null, false, 'Phone') ->> 'ok',
  'true', 'from the claiming network (/24) the claim founds the family, whatever the exact address');
select pg_temp.owner();
delete from app.household where name = 'Familie Test';
update app.setup_token set consumed_at = null, consumed_by = null;

-- IPv6: the /64 counts, not the host part (privacy addresses rotate it).
update app.setup_token set claimed_client = '2001:db8:abcd:1234:aaaa:bbbb:cccc:dddd';
select pg_temp.as_founder();
select pg_temp.from_ip('2001:db8:abcd:1234:1:2:3:4');
select is(api.household_create('Familie Test', 'Papa', '#2E7D6B', 'Europe/Berlin', 'de', null, false, 'Phone') ->> 'ok',
  'true', 'the same IPv6 /64 founds the family');
select pg_temp.owner();
delete from app.household where name = 'Familie Test';
update app.setup_token set consumed_at = null, consumed_by = null, claimed_client = '2001:db8:abcd:1234:aaaa:bbbb:cccc:dddd';
select pg_temp.as_founder();
select pg_temp.from_ip('2001:db8:abcd:9999:1:2:3:4');
select is(api.household_create('Familie Test', 'Papa', '#2E7D6B', 'Europe/Berlin', 'de', null, false, 'Phone') ->> 'reason',
  'founder_code_required', 'another IPv6 /64 does not');
select pg_temp.owner();
select is(app.client_prefix('unknown'), null, 'a key that is no address has no network');
update app.setup_token set claimed_client = 'unknown';
select pg_temp.as_founder();
select pg_temp.from_ip('');
select is(api.household_create('Familie Test', 'Papa', '#2E7D6B', 'Europe/Berlin', 'de', null, false, 'Phone') ->> 'reason',
  'founder_code_required', 'two unknown clients never match each other');
select pg_temp.owner();
update app.setup_token set claimed_client = '10.0.0.1';

-- A proven address founds from any client.
update auth.users set confirmation_sent_at = now() - interval '1 minute', email_confirmed_at = null where id = (select uid from founder);
update auth.users set email_confirmed_at = now() where id = (select uid from founder);
select pg_temp.as_founder();
select pg_temp.from_ip('10.0.0.3');
select is(api.household_create('Familie Test', 'Papa', '#2E7D6B', 'Europe/Berlin', 'de', null, false, 'Phone') ->> 'ok',
  'true', 'a proven address founds the family from any client');
select pg_temp.owner();
delete from app.household where name = 'Familie Test';
update app.setup_token set consumed_at = null, consumed_by = null, claimed_client = null;

-- A typed key works as before, whatever the client.
select pg_temp.as_founder();
select pg_temp.from_ip('10.0.0.4');
select is(api.household_create('Familie Test', 'Papa', '#2E7D6B', 'Europe/Berlin', 'de', 'dev-setup', false, 'Phone') ->> 'ok',
  'true', 'the typed key founds the family');
select pg_temp.owner();
delete from app.household where name = 'Familie Test';
delete from app.setup_token;

-- ============================================================ F15: the PIN counter
insert into app.household (id, name) values (gen_random_uuid(), 'Mc');
select pg_temp.person('Paula', (select id from app.household where name = 'Mc'), 'guardian', 'adult', 'paula@example.org');
select pg_temp.phone('Paula', 'Paula-Phone', 'adult');
update app.profile set pin_hash = extensions.crypt('123456', extensions.gen_salt('bf', 4)), pin_failures = 0, pin_locked_until = null
 where id = pg_temp.prof('Paula');
select pg_temp.as_phone('Paula-Phone');
select is((api.guardian_verify_pin(pg_temp.prof('Paula'), '000000') ->> 'attempts_left')::int, 9, 'a wrong PIN spends one attempt');
select is((api.guardian_verify_pin(pg_temp.prof('Paula'), '000001') ->> 'attempts_left')::int, 8, 'and the next one another');
select pg_temp.owner();
select is((select pin_failures from app.profile where id = pg_temp.prof('Paula')), 2,
  'the counter is written from the locked row (parallel guesses cannot share a failure)');

-- ============================================================ F19: the second factor on the account functions
-- Ida (an authenticator) at aal1: my_account answers, but withholds what a password alone must not see.
select pg_temp.as_account('Ida', 'aal1');
select is(api.my_account() ->> 'mfa_required', 'true', 'at aal1 an account with an authenticator is told mfa_required');
select is(api.my_account() ->> 'email', null, 'its address is withheld');
select is(api.my_account() ->> 'household_name', null, 'so is the family name');
select is(api.my_account() ->> 'household_id', null, 'and the household');
select is(jsonb_array_length(api.my_account() -> 'pending_invitations'), 0, 'and the invitations');
select is(api.my_account() ->> 'has_household', 'true', 'whether there is a household is still said');
select throws_ok('select api.register_personal_device(''Idas zweites Handy'')', '42501', 'second factor required',
  'a personal device is not registered at aal1');
select throws_ok('select api.household_restore()', '42501', 'second factor required', 'nothing is restored at aal1');
select throws_ok('select api.account_leave_deleted()', '42501', 'second factor required', 'and nothing left at aal1');
select pg_temp.as_account('Ida', 'aal2');
select is(api.my_account() ->> 'mfa_required', 'false', 'at aal2 mfa_required is false');
select is(api.my_account() ->> 'email', 'ida@example.org', 'and the address is given');
select is(api.my_account() ->> 'household_name', 'Ma', 'with the family name');
select lives_ok('select api.register_personal_device(''Idas zweites Handy'')', 'a personal device is registered at aal2');
select pg_temp.owner();
-- An account without an authenticator is not held up at aal1.
select pg_temp.as_account('Gert', 'aal1');
select is(api.my_account() ->> 'mfa_required', 'false', 'an account without an authenticator is never mfa_required');
select is(api.my_account() ->> 'email', 'gert@example.org', 'and sees its address at aal1');
select pg_temp.owner();

-- ============================================================ F21: the reward balance
-- Kid has 10 points; a reward costs 8 and needs no approval. The second request finds the
-- balance spent. (Both requests lock the profile row, so two parallel requests serialise the
-- same way; parallelism itself cannot run inside one pgTAP transaction.)
insert into app.point_transaction (household_id, profile_id, amount, reason, source_type, source_id, created_by_profile_id)
values ((select id from app.household where name = 'Ma'), pg_temp.prof('Kid'), 10, 'bonus', 'test', 'kid-bonus', pg_temp.prof('Gert'));
insert into app.reward (id, household_id, title, cost_points, requires_approval)
values ('11111111-1111-4111-8111-111111111111', (select id from app.household where name = 'Ma'), 'Kino', 8, false),
       ('22222222-2222-4222-8222-222222222222', (select id from app.household where name = 'Ma'), 'Eis', 8, false);
select pg_temp.as_phone('Kid-Phone');
select is(api.reward_request(pg_temp.prof('Kid'), '11111111-1111-4111-8111-111111111111') ->> 'status', 'approved',
  'the first request within the balance is approved at once');
select is(api.reward_request(pg_temp.prof('Kid'), '22222222-2222-4222-8222-222222222222') ->> 'status', 'requested',
  'the second request finds the balance spent and waits for a guardian');
select pg_temp.owner();
select is(app.tasks_balance(pg_temp.prof('Kid')), 2, 'only one reward was debited');

-- ============================================================ F22: who may sign up once the server is claimed
select is(api.server_info() ->> 'claimed', 'true', 'the server has a family');
select is(pg_temp.hook('stranger@example.org') -> 'error' ->> 'message', 'invitation_required',
  'with no invitation open a stranger cannot sign up');
select is((pg_temp.hook('stranger@example.org') -> 'error' ->> 'http_code')::int, 403, 'the refusal is a 403');

-- An invitation naming an address admits sign-ups while it is open.
insert into app.profile (household_id, display_name, color, role, kind)
values ((select id from app.household where name = 'Ma'), 'Oma', '#7B3FE4', 'guardian', 'adult');
insert into app.invitation (id, household_id, profile_id, role, email, token_hash, code_hash, created_by_profile_id, expires_at)
values ('33333333-3333-4333-8333-333333333333', (select id from app.household where name = 'Ma'),
        (select id from app.profile where display_name = 'Oma'), 'guardian', 'oma@example.org',
        app.invitation_hash('tok-oma'), app.invitation_hash('CODEOMA1'), pg_temp.prof('Gert'), now() + interval '1 day');
select is(pg_temp.hook('Oma@Example.org'), '{}'::jsonb, 'the invited address may sign up, whatever its case');
select is(pg_temp.hook('oma-at-work@example.org'), '{}'::jsonb,
  'while an invitation is open, another address may sign up too (the invited person may use a different one)');
select is(pg_temp.hook('device-00000000-0000-4000-8000-000000000000@devices.wuselwall.invalid') -> 'error' ->> 'message',
  'email_reserved', 'the device-account marker domain is never admitted');
update app.invitation set revoked_at = now() where id = '33333333-3333-4333-8333-333333333333';
select is(pg_temp.hook('stranger@example.org') -> 'error' ->> 'message', 'invitation_required',
  'once that invitation is revoked the door is shut again');

-- An invitation without an address (link or code) admits anyone while it is open.
insert into app.profile (household_id, display_name, color, role, kind)
values ((select id from app.household where name = 'Ma'), 'Opa', '#7B3FE4', 'member', 'adult');
insert into app.invitation (id, household_id, profile_id, role, email, token_hash, code_hash, created_by_profile_id, expires_at)
values ('44444444-4444-4444-8444-444444444444', (select id from app.household where name = 'Ma'),
        (select id from app.profile where display_name = 'Opa'), 'member', null,
        app.invitation_hash('tok-opa'), app.invitation_hash('CODEOPA1'), pg_temp.prof('Gert'), now() + interval '1 day');
select is(pg_temp.hook('stranger@example.org'), '{}'::jsonb, 'an open invitation by link admits any address');
update app.invitation set revoked_at = now() where id = '44444444-4444-4444-8444-444444444444';
select is(pg_temp.hook('stranger@example.org') -> 'error' ->> 'message', 'invitation_required', 'a revoked one admits nobody');
update app.invitation set revoked_at = null, expires_at = now() - interval '1 second' where id = '44444444-4444-4444-8444-444444444444';
select is(pg_temp.hook('stranger@example.org') -> 'error' ->> 'message', 'invitation_required', 'nor an expired one');
update app.invitation set expires_at = now() + interval '1 day', accepted_at = now(), accepted_by_user = pg_temp.uid('Gert')
 where id = '44444444-4444-4444-8444-444444444444';
select is(pg_temp.hook('stranger@example.org') -> 'error' ->> 'message', 'invitation_required', 'nor a spent one');
update app.invitation set accepted_at = null, accepted_by_user = null where id = '44444444-4444-4444-8444-444444444444';
update app.household set deleted_at = now() where name = 'Ma';
select is(pg_temp.hook('stranger@example.org') -> 'error' ->> 'message', 'invitation_required',
  'an invitation into a deleted family admits nobody');
update app.household set deleted_at = null where name = 'Ma';
update app.invitation set revoked_at = now() where id = '44444444-4444-4444-8444-444444444444';
select is(pg_temp.hook('stranger@example.org') -> 'error' ->> 'message', 'invitation_required',
  'the door is shut again once the last open invitation is gone');

-- A further founder with a fresh key: the claim admits the address, as on an unclaimed server.
insert into app.setup_token (token_hash) values (encode(extensions.digest('second-key', 'sha256'), 'hex'));
select pg_temp.as_anon('10.0.0.9');
select is(api.setup_claim('second-key', 'second@example.org') ->> 'claimed', 'true', 'a second founder claims a further key');
select pg_temp.owner();
select is(pg_temp.hook('second@example.org'), '{}'::jsonb, 'the claimed address may sign up');
update app.setup_token set claimed_at = now() - interval '16 minutes';
select is(pg_temp.hook('second@example.org') -> 'error' ->> 'message', 'invitation_required',
  'a claim older than 15 minutes admits no longer');

-- Open mode admits everyone, as before.
update app.instance_setting set value = '"open"' where key = 'household_creation';
select is(pg_temp.hook('stranger@example.org'), '{}'::jsonb, 'open mode admits every sign-up');
update app.instance_setting set value = '"code"' where key = 'household_creation';

-- ============================================================ privileges
select ok(not has_function_privilege('authenticated', 'app.require_mfa_satisfied(uuid)', 'execute')
          and not has_function_privilege('authenticated', 'app.signed_in_recently(interval)', 'execute')
          and not has_function_privilege('authenticated', 'app.jwt_aal()', 'execute'),
  'the new helpers are internal');
select ok(has_function_privilege('supabase_auth_admin', 'app.record_proven_address()', 'execute'),
  'Auth may run the trigger function');

select * from finish();
rollback;
