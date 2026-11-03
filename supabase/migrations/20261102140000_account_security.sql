-- Account security (security review 2026-11-01: F1, F3, F10, F12, F15, F19, F22, F23).
--
-- What changes, and why:
--
-- F1  The proven address is recorded, not inferred. app.proven_email used to return the
--     account's current address whenever email_confirmed_at and confirmation_sent_at were
--     set. Both stay set from the original sign-up after an email change, so an address
--     changed later (through GoTrue's PUT /user, which the app never calls but any client
--     can) counted as proven without anyone ever reading a mail at it. Now a trigger on
--     auth.users keeps app.proven_address: one row per account with the address a mailed
--     code was redeemed for. proven_email returns the current address only when it is the
--     recorded one. The approach chosen, and the alternatives:
--       * A trigger on auth.users is the documented way to react to Auth events on every
--         stack, hosted projects included (no superuser: postgres holds the TRIGGER privilege
--         on auth.users there). Its function is security definer, pins its search_path, and
--         never raises: a failure to record leaves the address unproven (closed), it never
--         blocks a sign-in.
--       * Comparing auth.users' timestamps alone cannot work: an autoconfirmed email change
--         (a server without mail, or one that switched mail off later) writes the new
--         address without touching email_confirmed_at, confirmation_sent_at or
--         email_change_sent_at, so nothing distinguishes it from the original sign-up.
--       * The address is recorded at exactly two moments. (1) The sign-up confirmation:
--         email_confirmed_at turns from null to a time while confirmation_sent_at is set and
--         younger than a day (an unconfirmed sign-up left behind on a server with mail must
--         not become proven when the operator later switches mail off and GoTrue confirms
--         the old row on the next sign-up).
--         (2) The second step of a secure email change: the address changes to the pending
--         one (old.email_change) while old.email_change_confirm_status says one side already
--         confirmed and the change was mailed within the last day. GoTrue sends both codes
--         for that change (one to each address; the fixed send-email hook delivers them
--         separately), so a completed change proves the new address. An autoconfirmed change
--         has status 0 and is not recorded; so is a change with secure email change off
--         (never the case on a WuselWall server). The residual: a half-confirmed mailed change
--         completed by autoconfirm within a day of mailing, which needs the operator to switch
--         mail off in that window.
--       * Existing accounts are backfilled from today's state (the rule in force until now):
--         the server cannot know better for the past; from now on the record is exact.
--     Refusing email changes outright was considered: GoTrue has no setting for it and the
--     Before User Created hook does not see updates. A trigger raising on an email change
--     would surface as an Auth server error; left as is.
--
-- F3  A guardian's reset code and the second-factor reset together let a co-guardian take
--     over a protected account in silence. Now: api.password_reset_create and
--     api.mfa_reset_check need a sign-in of the last five minutes (the JWT's amr claim) and
--     aal2 when the caller's account has a verified authenticator; each refuses when the same
--     guardian did the other reset for the same person within 7 days (hints
--     mfa_reset_recent and password_reset_recent); redeeming a code ends the target's
--     sessions (app.revoke_auth_sessions, F23 too); mfa-reset tells the target by mail
--     where the server has mail (Edge Function); and both resets show on Today as notices
--     (app.notices_for kinds mfa_reset and password_reset_issued) to the person concerned
--     and to the other guardians, so a reset nobody asked for is seen in the app whatever
--     the mail setup. The recent-sign-in check counts first-factor methods only (password,
--     code, OAuth, SSO): a second-factor step a stolen session just enrolled must not pass
--     as a fresh sign-in. Everything is audited as before, the redeem row now says how many
--     sessions ended.
--
-- F12 On a server without mail the claim alone founded the family: household_create's
--     no-code path accepted any account whose address equalled the claimed one, and such an
--     address is never proven. The no-code path now also needs either the proven address
--     (a server with mail: the founder redeemed the code) or a client in the same network as
--     the one that made the claim (app.setup_token.claimed_client, written by setup_claim;
--     compared as /24 for IPv4 and /64 for IPv6, since a phone's public address moves
--     between two requests behind carrier NAT or with IPv6 privacy addresses). The released
--     apps (1.9.0, 1.10.0) send no code after a claim, so the key itself cannot be demanded
--     yet without stranding their founders on a server without mail; the client binding
--     closes the window for them, and a typed or stored key keeps working as before (the
--     app now sends its stored key whenever it has one, and opens the key field when the
--     server asks for a code). Once 1.10.0 is the previous release the client binding can go.
--
-- F15 api.guardian_verify_pin locks the profile row before the hash check; that
--     redefinition lives in 20261102110000_household_trust.sql (same body, plus the shorter
--     window of a shared device), which this migration follows.
--
-- F19 household_restore, account_leave_deleted and register_personal_device need aal2 when
--     the account has a verified authenticator (hint mfa_required), as the access-token hook
--     already implies for everything else. my_account stays callable at aal1 but then
--     withholds the address, the names, the family name, the invitations and the deleted
--     family, and says mfa_required: the app shows the second-factor step before it reads
--     the account anyway.
--
-- F22 Once a household exists the Before User Created hook let every sign-up through. Now,
--     in code mode, it admits a sign-up only while an open, unexpired, unrevoked invitation
--     exists in a live family (named or not: an invited person may well sign up with another
--     address than the one typed on the invitation, and the released apps could not work
--     around a stricter rule), or while the address holds a live claim with an unconsumed key
--     (a further founder). With nothing pending nobody signs up (message
--     invitation_required). An address under the device-account marker domain is always
--     refused: device users are created by app.create_auth_user, never through GoTrue, and
--     personal devices belong to accounts that exist already. Open mode stays open.
--
-- api_version unchanged: no signature of an api function changes; the new fields of
-- my_account are additive and the new refusals carry hints the apps map as before.

-- ------------------------------------------------------------ JWT helpers

-- The assurance level of the caller's token: 'aal2' once the second factor was proven.
create function app.jwt_aal() returns text
language sql stable set search_path = '' as $$
  select coalesce(nullif(auth.jwt() ->> 'aal', ''), 'aal1')
$$;

create function app.has_verified_totp(p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from auth.mfa_factors f
                  where f.user_id = p_user and f.status = 'verified' and f.factor_type = 'totp')
$$;

-- The account has an authenticator but this token did not prove it.
create function app.mfa_locked(p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select app.has_verified_totp(p_user) and app.jwt_aal() <> 'aal2'
$$;

create function app.require_mfa_satisfied(p_user uuid) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if app.mfa_locked(p_user) then
    raise exception 'second factor required' using errcode = '42501', hint = 'mfa_required';
  end if;
end $$;

-- Whether a first-factor sign-in of the token (amr: password, code, OAuth, SSO, …) is
-- younger than p_max_age. A refreshed session keeps its entries, so only a fresh sign-in
-- counts; a second-factor step (totp, mfa/*) does not, since a stolen session could enrol
-- and prove a factor of its own. The second factor is checked separately (mfa_locked).
create function app.signed_in_recently(p_max_age interval) returns boolean
language sql stable set search_path = '' as $$
  select exists (
    select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) e
     where jsonb_typeof(e -> 'timestamp') = 'number'
       and e ->> 'method' in ('password', 'otp', 'magiclink', 'recovery', 'invite', 'email/signup',
                              'oauth', 'sso/saml', 'anonymous', 'passkey', 'web3')
       and to_timestamp((e ->> 'timestamp')::double precision) > now() - p_max_age)
$$;

create function app.require_recent_sign_in() returns void
language plpgsql stable set search_path = '' as $$
begin
  if not app.signed_in_recently(interval '5 minutes') then
    raise exception 'recent sign-in required' using errcode = '42501', hint = 'reauth_required';
  end if;
end $$;

-- Ends every session of an Auth user, as the Admin API's logout does. Refresh tokens hang
-- off sessions (on delete cascade in Auth's schema), so they go with them. Returns the count.
create function app.revoke_auth_sessions(p_user uuid) returns int
language plpgsql security definer set search_path = '' as $$
declare v_n int;
begin
  delete from auth.sessions where user_id = p_user;
  get diagnostics v_n = row_count;
  return v_n;
end $$;

revoke execute on function app.jwt_aal(), app.has_verified_totp(uuid), app.mfa_locked(uuid),
  app.require_mfa_satisfied(uuid), app.signed_in_recently(interval), app.require_recent_sign_in(),
  app.revoke_auth_sessions(uuid) from public, anon, authenticated;

-- ------------------------------------------------------------ F1: the proven address

create table app.proven_address (
  user_id   uuid primary key references auth.users on delete cascade,
  email     text not null check (email = lower(email)),
  proven_at timestamptz not null default now()
);
alter table app.proven_address enable row level security;
alter table app.proven_address force row level security;
create policy owner_all on app.proven_address to postgres using (true) with check (true);
revoke all on app.proven_address from public, anon, authenticated;

-- The trigger function. Runs as its owner so Auth's role needs no right on app tables, and
-- swallows every error: recording nothing leaves the address unproven, which is the safe
-- side, while raising here would turn a sign-in into an Auth server error.
create function app.record_proven_address() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_email text := nullif(lower(btrim(coalesce(new.email, ''))), '');
  v_prove boolean := false;
begin
  if v_email is null then
    return null;
  end if;
  if tg_op = 'INSERT' then
    v_prove := new.email_confirmed_at is not null and new.confirmation_sent_at is not null
               and new.confirmation_sent_at > now() - interval '1 day';
  else
    -- (1) The sign-up confirmation: a mailed code was redeemed for this address.
    if new.email_confirmed_at is not null and old.email_confirmed_at is null
       and new.confirmation_sent_at is not null
       and new.confirmation_sent_at > now() - interval '1 day' then
      v_prove := true;
    -- (2) The second step of a secure email change to this address: one side had already
    --     confirmed (status 1) and the codes were mailed within the last day.
    elsif lower(coalesce(old.email, '')) is distinct from v_email
       and lower(btrim(coalesce(old.email_change, ''))) = v_email
       and coalesce(old.email_change_confirm_status, 0) = 1
       and old.email_change_sent_at is not null
       and old.email_change_sent_at > now() - interval '1 day' then
      v_prove := true;
    end if;
  end if;
  if v_prove then
    insert into app.proven_address (user_id, email, proven_at)
    values (new.id, v_email, now())
    on conflict (user_id) do update set email = excluded.email, proven_at = excluded.proven_at;
  end if;
  return null;
exception when others then
  return null;
end $$;
revoke execute on function app.record_proven_address() from public, anon, authenticated;
grant execute on function app.record_proven_address() to supabase_auth_admin;

create trigger users_proven_address
  after insert or update of email, email_confirmed_at on auth.users
  for each row execute function app.record_proven_address();

-- Backfill from today's state, the rule in force until now.
insert into app.proven_address (user_id, email, proven_at)
select u.id, lower(u.email), coalesce(u.email_confirmed_at, now())
  from auth.users u
 where u.email is not null and u.email <> ''
   and u.email_confirmed_at is not null and u.confirmation_sent_at is not null
on conflict (user_id) do nothing;

-- The current address, only when it is the recorded proven one.
create or replace function app.proven_email(p_user uuid) returns text
language sql stable security definer set search_path = '' as $$
  select lower(u.email) from auth.users u
    join app.proven_address p on p.user_id = u.id
   where u.id = p_user
     and p.email = lower(u.email)
     and u.email_confirmed_at is not null and u.confirmation_sent_at is not null
$$;

-- ------------------------------------------------------------ F3: the guardian's resets

-- As in 20261026100000_mail_optional.sql, plus: a sign-in of the last five minutes, aal2
-- when the caller has an authenticator, and no code for a person whose authenticator this
-- guardian reset within 7 days.
create or replace function api.password_reset_create(p_actor uuid, p_profile uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.actor(p_actor);
  v_target app.profile;
begin
  if a.device_class <> 'personal' then
    raise exception 'personal device required' using errcode = '42501', hint = 'personal_device_required';
  end if;
  perform app.require_guardian(a);
  perform app.require_mfa_satisfied(auth.uid());
  perform app.require_recent_sign_in();

  if p_profile is null then
    raise exception 'profile required' using errcode = '22023', hint = 'profile_required';
  end if;
  if p_profile = a.profile_id then
    raise exception 'own password' using errcode = '22023', hint = 'not_self';
  end if;
  select * into v_target from app.profile
   where id = p_profile and household_id = a.household_id and active;
  if not found then
    raise exception 'profile not found' using errcode = 'P0002', hint = 'profile_not_found';
  end if;
  if v_target.kind <> 'adult' then
    raise exception 'target not an adult' using errcode = '22023', hint = 'target_not_adult';
  end if;
  if v_target.auth_user_id is null then
    raise exception 'target has no account' using errcode = '22023', hint = 'target_no_account';
  end if;
  if exists (select 1 from app.audit_log l
              where l.household_id = a.household_id and l.action = 'mfa_reset'
                and l.entity_id = v_target.id and l.actor_profile_id = a.profile_id
                and l.occurred_at > now() - interval '7 days') then
    raise exception 'second factor reset recently' using errcode = '42501', hint = 'mfa_reset_recent';
  end if;

  perform app.audit(a, 'profile', v_target.id, 'password_reset_code');
  return app.password_reset_issue(v_target.auth_user_id, a.household_id, v_target.id, a.profile_id);
end $$;

-- As in 20261015106000_account_admin.sql, plus the same three conditions, and the target's
-- address and name for the notice mfa-reset sends where the server has mail.
create or replace function api.mfa_reset_check(p_actor uuid, p_profile uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.actor(p_actor);
  v_target app.profile;
begin
  if a.device_class <> 'personal' then
    raise exception 'personal device required' using errcode = '42501', hint = 'personal_device_required';
  end if;
  perform app.require_guardian(a);
  perform app.require_mfa_satisfied(auth.uid());
  perform app.require_recent_sign_in();

  if p_profile is null then
    raise exception 'profile required' using errcode = '22023', hint = 'profile_required';
  end if;
  if p_profile = a.profile_id then
    raise exception 'own factor' using errcode = '22023', hint = 'not_self';
  end if;
  select * into v_target from app.profile
   where id = p_profile and household_id = a.household_id and active;
  if not found then
    raise exception 'profile not found' using errcode = 'P0002', hint = 'profile_not_found';
  end if;
  if v_target.role <> 'guardian' then
    raise exception 'target not a guardian' using errcode = '22023', hint = 'target_not_guardian';
  end if;
  if v_target.auth_user_id is null then
    raise exception 'target has no account' using errcode = '22023', hint = 'target_no_account';
  end if;
  if exists (select 1 from app.audit_log l
              where l.household_id = a.household_id and l.action = 'password_reset_code'
                and l.entity_id = v_target.id and l.actor_profile_id = a.profile_id
                and l.occurred_at > now() - interval '7 days') then
    raise exception 'password reset code issued recently' using errcode = '42501', hint = 'password_reset_recent';
  end if;

  perform app.audit(a, 'profile', v_target.id, 'mfa_reset');
  return jsonb_build_object('ok', true, 'user_id', v_target.auth_user_id, 'profile_id', v_target.id,
                            'email', (select lower(u.email) from auth.users u where u.id = v_target.auth_user_id),
                            'display_name', v_target.display_name);
end $$;

-- As in 20261026100000_mail_optional.sql, plus: every session of the account ends with the
-- password (F3, F23), and the audit row says how many. The per-client cap (10 failures in 10
-- minutes, keyed by app.client_key) stays the primary limit; the overall cap is 2000 in 10
-- minutes: a code is 40 bits and lives 10 minutes, so 2000 guesses are about 1 in 500 million.
create or replace function api.password_reset_redeem(p_email text, p_code text, p_password text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_key     text := 'reset:' || app.client_key();
  v_code    text := regexp_replace(upper(coalesce(p_code, '')), '[^A-Z0-9]', '', 'g');
  v_reset   app.password_reset;
  v_revoked int;
begin
  if (select count(*) from app.password_reset_attempt
       where client_key = v_key and not success and attempted_at > now() - interval '10 minutes') >= 10
     or (select count(*) from app.password_reset_attempt
          where not success and attempted_at > now() - interval '10 minutes') >= 2000 then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  if length(coalesce(p_password, '')) < 10 then
    return jsonb_build_object('ok', false, 'reason', 'password_too_short');
  end if;

  select r.* into v_reset from app.password_reset r join auth.users u on u.id = r.auth_user_id
   where r.code_hash = app.pairing_hash(v_code)
     and lower(u.email) = lower(btrim(coalesce(p_email, '')))
     for update of r;
  if not found or v_reset.used_at is not null then
    insert into app.password_reset_attempt (client_key, success) values (v_key, false);
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;
  if v_reset.expires_at <= now() then
    insert into app.password_reset_attempt (client_key, success) values (v_key, false);
    return jsonb_build_object('ok', false, 'reason', 'expired');
  end if;

  perform app.set_auth_user_password(v_reset.auth_user_id, p_password);
  update auth.users
     set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
                              || jsonb_build_object('has_password', true, 'sign_in_choice', 'password')
   where id = v_reset.auth_user_id;
  v_revoked := app.revoke_auth_sessions(v_reset.auth_user_id);
  update app.password_reset set used_at = now() where id = v_reset.id;
  insert into app.password_reset_attempt (client_key, success) values (v_key, true);
  if v_reset.profile_id is not null then
    perform app.audit(row(v_reset.household_id, v_reset.profile_id, null::text, null::uuid, null::text, 'ui',
                          null::timestamptz, null::uuid)::app.actor_t,
                      'profile', v_reset.profile_id, 'password_reset',
                      jsonb_build_object('sessions_revoked', v_revoked));
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- ------------------------------------------------------------ F12: the claim and the client

alter table app.setup_token add column claimed_client text;

-- The network a client key belongs to: /24 for an IPv4 address, /64 for IPv6, the key
-- itself when it is not an address ('unknown', which never matches anything).
create function app.client_prefix(p_key text) returns text
language plpgsql immutable set search_path = '' as $$
declare v inet;
begin
  begin
    v := btrim(p_key)::inet;
  exception when others then
    return null;
  end;
  return host(network(set_masklen(v, case when family(v) = 4 then 24 else 64 end)));
end $$;
revoke execute on function app.client_prefix(text) from public, anon, authenticated;

-- As in 20261030100000_claim_server.sql, plus: the claim records the client it came from.
create or replace function api.setup_claim(p_key text, p_email text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_client text := app.request_client_key();
  v_email  text := nullif(lower(btrim(coalesce(p_email, ''))), '');
  v_token  app.setup_token;
begin
  if coalesce(btrim(p_key), '') = '' then
    return jsonb_build_object('ok', false, 'reason', 'key_required');
  end if;
  if v_email is not null and (v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or length(v_email) > 254) then
    return jsonb_build_object('ok', false, 'reason', 'email_invalid');
  end if;
  if app.founder_attempts_exceeded(v_client) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  select * into v_token from app.setup_token
   where token_hash = encode(extensions.digest(lower(btrim(p_key)), 'sha256'), 'hex')
   for update;
  if not found then
    insert into app.founder_attempt (client_key, success) values (v_client, false);
    return jsonb_build_object('ok', false, 'reason', 'key_invalid');
  end if;
  if v_token.consumed_at is not null then
    insert into app.founder_attempt (client_key, success) values (v_client, false);
    return jsonb_build_object('ok', false, 'reason', 'key_used');
  end if;
  if v_email is not null then
    update app.setup_token set claimed_email = v_email, claimed_at = now(), claimed_client = v_client
     where token_hash = v_token.token_hash;
  end if;
  return jsonb_build_object(
    'ok', true,
    'claimed', v_email is not null,
    'server_claimed', app.server_claimed(),
    'household_creation', app.household_creation_mode());
end $$;

-- As in 20261030100000_claim_server.sql, with one change in the no-code path: the claim
-- stands in for the key only for a proven address, or from the network of the client that
-- made the claim. A typed or stored key is checked as before.
create or replace function api.household_create(
  p_name text, p_display_name text, p_color text, p_timezone text, p_locale text,
  p_founder_code text, p_seed_examples boolean, p_device_label text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user    uuid := auth.uid();
  v_session uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  v_key     text := app.request_client_key();
  v_mode    text := app.household_creation_mode();
  v_token   app.setup_token;
  v_hh      uuid;
  v_prof    uuid;
  v_dev     uuid;
  v_actor   app.actor_t;
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '42501', hint = 'auth_required';
  end if;
  if v_session is null or not exists (select 1 from auth.sessions where id = v_session and user_id = v_user) then
    raise exception 'no session' using errcode = '42501', hint = 'session_invalid';
  end if;
  -- Also refused for any device user (shared or kiosk tablets sign in as their own user), revoked or not.
  -- A phone row counts only while it is live: leaving a family revokes it.
  if exists (select 1 from app.profile where auth_user_id = v_user and active)
     or exists (select 1 from app.device where auth_user_id = v_user and (class <> 'personal' or revoked_at is null)) then
    raise exception 'already in a household' using errcode = '42501', hint = 'already_in_household';
  end if;

  if length(btrim(coalesce(p_name, ''))) not between 1 and 60 then
    raise exception 'household name invalid' using errcode = '22023', hint = 'household_name_invalid';
  end if;
  if length(btrim(coalesce(p_display_name, ''))) not between 1 and 40 then
    raise exception 'name invalid' using errcode = '22023', hint = 'name_invalid';
  end if;
  if coalesce(p_color, '') !~ '^#[0-9A-Fa-f]{6}$' then
    raise exception 'colour invalid' using errcode = '22023', hint = 'color_invalid';
  end if;
  if not exists (select 1 from pg_timezone_names where name = p_timezone) then
    raise exception 'timezone invalid' using errcode = '22023', hint = 'timezone_invalid';
  end if;
  if coalesce(p_locale, '') !~ '^[a-z]{2}(-[A-Z]{2})?$' then
    raise exception 'locale invalid' using errcode = '22023', hint = 'locale_invalid';
  end if;
  if length(btrim(coalesce(p_device_label, ''))) not between 1 and 60 then
    raise exception 'label required' using errcode = '22023', hint = 'label_invalid';
  end if;

  if v_mode = 'code' then
    if coalesce(btrim(p_founder_code), '') = '' then
      -- No code typed: the claim this account's address made before signing up stands in,
      -- when the address was proven by mail or the claim came from the same network as this
      -- call (a server without mail proves no address: security review 2026-11-01, F12).
      select t.* into v_token from app.setup_token t
       where t.consumed_at is null
         and t.claimed_email = (select lower(u.email) from auth.users u where u.id = v_user)
         and t.claimed_at > now() - interval '24 hours'
         and (t.claimed_email = app.proven_email(v_user)
              or (app.client_prefix(t.claimed_client) is not null
                  and app.client_prefix(t.claimed_client) = app.client_prefix(v_key)))
       order by t.claimed_at desc limit 1
       for update;
      if not found then
        return jsonb_build_object('ok', false, 'reason', 'founder_code_required');
      end if;
    else
      -- The founder code. Only a guess counts against the client: a missing code is not one.
      if app.founder_attempts_exceeded(v_key) then
        return jsonb_build_object('ok', false, 'reason', 'rate_limited');
      end if;
      select * into v_token from app.setup_token
       where token_hash = encode(extensions.digest(lower(btrim(p_founder_code)), 'sha256'), 'hex')
         and consumed_at is null
       for update;
      if not found then
        insert into app.founder_attempt (client_key, success) values (v_key, false);
        return jsonb_build_object('ok', false, 'reason', 'founder_code_invalid');
      end if;
    end if;
  end if;

  insert into app.household (name, timezone, locale)
  values (btrim(p_name), p_timezone, p_locale) returning id into v_hh;
  insert into app.profile (household_id, display_name, color, role, kind, auth_user_id)
  values (v_hh, btrim(p_display_name), upper(p_color), 'guardian', 'adult', v_user)
  returning id into v_prof;
  update app.household set created_by_profile_id = v_prof where id = v_hh;
  insert into app.device (household_id, auth_user_id, auth_session_id, label, class, register, profile_id)
  values (v_hh, v_user, v_session, btrim(p_device_label), 'personal', 'adult', v_prof)
  returning id into v_dev;

  if v_mode = 'code' then
    update app.setup_token set consumed_at = now(), consumed_by = v_prof where token_hash = v_token.token_hash;
    insert into app.founder_attempt (client_key, success) values (v_key, true);
  end if;

  perform app.shopping_ensure_lists(v_hh);
  v_actor := row(v_hh, v_prof, 'guardian', v_dev, 'personal', 'ui', null::timestamptz, null::uuid)::app.actor_t;
  if coalesce(p_seed_examples, false) then
    perform app.tasks_seed_starter_for(v_actor);
  end if;
  perform app.audit(v_actor, 'household', v_hh, 'create',
                    jsonb_build_object('examples', coalesce(p_seed_examples, false), 'founder_code', v_mode = 'code'));
  perform app.audit(v_actor, 'device', v_dev, 'register_personal');
  return jsonb_build_object('ok', true, 'household_id', v_hh, 'profile_id', v_prof, 'device_id', v_dev);
end $$;

-- ------------------------------------------------------------ F19: the account functions

-- As in 20261015104000_leave.sql, plus the second-factor requirement.
create or replace function api.household_restore() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_user    uuid := auth.uid();
  v_session uuid := app.caller_session();
  v_profile app.profile;
  v_hh      app.household;
  v_label   text;
  v_dev     uuid;
begin
  perform app.require_mfa_satisfied(v_user);
  if exists (select 1 from app.device where auth_user_id = v_user and class <> 'personal')
     or exists (select 1 from app.profile p join app.household h on h.id = p.household_id
                 where p.auth_user_id = v_user and p.active and h.deleted_at is null) then
    raise exception 'already in a household' using errcode = '42501', hint = 'already_in_household';
  end if;

  select p.* into v_profile from app.profile p
    join app.household h on h.id = p.household_id and h.deleted_at is not null
   where p.auth_user_id = v_user and p.active
   order by h.deleted_at desc limit 1 for update of p;
  if not found then
    raise exception 'no deleted household' using errcode = '42501', hint = 'not_deleted';
  end if;
  if v_profile.role <> 'guardian' then
    raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
  end if;

  select * into v_hh from app.household where id = v_profile.household_id for update;
  if now() >= v_hh.deleted_at + app.household_retention() then
    raise exception 'restore window passed' using errcode = '42501', hint = 'restore_expired';
  end if;

  update app.household set deleted_at = null where id = v_hh.id;
  select d.label into v_label from app.device d
   where d.profile_id = v_profile.id and d.class = 'personal'
   order by d.created_at desc limit 1;
  insert into app.device (household_id, auth_user_id, auth_session_id, label, class, register, profile_id)
  values (v_hh.id, v_user, v_session, coalesce(v_label, 'Erstes Gerät'), 'personal', 'adult', v_profile.id)
  returning id into v_dev;

  perform app.audit(row(v_hh.id, v_profile.id, 'guardian', v_dev, 'personal', 'ui', null::timestamptz,
                        null::uuid)::app.actor_t, 'household', v_hh.id, 'restore');
  return jsonb_build_object('ok', true, 'household_id', v_hh.id, 'profile_id', v_profile.id, 'device_id', v_dev);
end $$;

-- As in 20261015104000_leave.sql, plus the second-factor requirement.
create or replace function api.account_leave_deleted() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_user    uuid := auth.uid();
  v_profile app.profile;
begin
  perform app.caller_session();
  perform app.require_mfa_satisfied(v_user);
  select p.* into v_profile from app.profile p
    join app.household h on h.id = p.household_id and h.deleted_at is not null
   where p.auth_user_id = v_user and p.active
   order by h.deleted_at desc limit 1 for update of p;
  if not found then
    raise exception 'no deleted household' using errcode = '42501', hint = 'not_deleted';
  end if;

  update app.profile set auth_user_id = null where id = v_profile.id;
  update app.device set revoked_at = now() where auth_user_id = v_user and revoked_at is null;
  insert into app.audit_log (household_id, actor_profile_id, device_id, origin, entity_type, entity_id, action)
  values (v_profile.household_id, v_profile.id, null, 'ui', 'profile', v_profile.id, 'leave_deleted');
  return jsonb_build_object('ok', true);
end $$;

-- As in 20261015104000_leave.sql, plus the second-factor requirement.
create or replace function api.register_personal_device(p_label text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_session uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  v_prof    app.profile;
  v_id      uuid;
begin
  select * into v_prof from app.profile where auth_user_id = auth.uid() and active;
  if not found then
    raise exception 'not a guardian account' using errcode = '42501', hint = 'guardian_required';
  end if;
  if v_session is null or not exists (select 1 from auth.sessions where id = v_session and user_id = auth.uid()) then
    raise exception 'no session' using errcode = '42501', hint = 'session_invalid';
  end if;
  perform app.require_mfa_satisfied(auth.uid());
  if length(btrim(coalesce(p_label, ''))) = 0 then
    raise exception 'label required' using errcode = '22023', hint = 'name_required';
  end if;

  insert into app.device (household_id, auth_user_id, auth_session_id, label, class, register, profile_id)
  values (v_prof.household_id, v_prof.auth_user_id, v_session, btrim(p_label), 'personal', 'adult', v_prof.id)
  on conflict (auth_session_id) where auth_session_id is not null and revoked_at is null do nothing
  returning id into v_id;
  if v_id is not null then
    insert into app.audit_log (household_id, actor_profile_id, device_id, entity_type, entity_id, action)
    values (v_prof.household_id, v_prof.id, v_id, 'device', v_id, 'register_personal');
  end if;
  return api.current_device();
end $$;

-- As in 20261030100000_claim_server.sql, plus mfa_required: at aal1 an account with an
-- authenticator learns only that it has a household (or not) and which creation mode the
-- server runs; the address, the names, the family name, the invitations, the claim and the
-- deleted family wait for the second factor.
create or replace function api.my_account() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'user_id',            u.id,
    'mfa_required',       locked.v,
    'email',              case when locked.v then null else u.email end,
    -- A device user (a shared or kiosk tablet) has no profile but is not free to start one.
    -- A phone's own row counts only while it is live.
    'has_household',      (p.id is not null and p.deleted_at is null)
                          or exists (select 1 from app.device d where d.auth_user_id = u.id
                                      and (d.class <> 'personal' or d.revoked_at is null)),
    'household_id',       case when p.deleted_at is null and not locked.v then p.household_id end,
    -- The family's name, for the typed confirmation of a deletion.
    'household_name',     case when p.deleted_at is null and not locked.v then p.household_name end,
    'profile_id',         case when p.deleted_at is null and not locked.v then p.id end,
    'household_creation', app.household_creation_mode(),
    'setup_claimed',      not locked.v and exists (select 1 from app.setup_token t
                                   where t.consumed_at is null and t.claimed_email = lower(u.email)
                                     and t.claimed_at > now() - interval '24 hours'),
    'full_name', case when locked.v then null else
      nullif(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')), '') end,
    'given_name', case when locked.v then null else coalesce(
      nullif(btrim(coalesce(u.raw_user_meta_data ->> 'given_name', '')), ''),
      nullif(split_part(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')), ' ', 1), '')) end,
    -- Why the caller cannot leave the family, for the app to say so before the attempt.
    'leave_blocked', case when not locked.v and p.id is not null and p.deleted_at is null and p.role = 'guardian'
                          and exists (select 1 from app.profile o where o.household_id = p.household_id
                                       and o.active and o.id <> p.id)
                          and not exists (select 1 from app.profile o where o.household_id = p.household_id
                                       and o.active and o.id <> p.id and o.role = 'guardian'
                                       and o.auth_user_id is not null)
                        then 'last_guardian' end,
    -- Invitations naming this account's proven email, never into a deleted family.
    'pending_invitations', case when locked.v then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', i.id,
               'household_name', h.name,
               'inviter_first_name', nullif(split_part(btrim(coalesce(inv.display_name, '')), ' ', 1), ''),
               'profile_name', ip.display_name,
               'profile_color', ip.color,
               'role', i.role)
             order by i.created_at, i.id)
        from app.invitation i
        join app.household h on h.id = i.household_id and h.deleted_at is null
        join app.profile ip on ip.id = i.profile_id
        left join app.profile inv on inv.id = i.created_by_profile_id
       where i.email = app.proven_email(u.id)
         and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()
         and ip.active and ip.auth_user_id is null), '[]'::jsonb) end,
    'deleted_household', case when p.deleted_at is not null and not locked.v then jsonb_build_object(
      'id',         p.household_id,
      'name',       p.household_name,
      'deleted_at', p.deleted_at,
      'purge_after', p.deleted_at + app.household_retention(),
      'can_restore', p.role = 'guardian' and now() < p.deleted_at + app.household_retention())
    end)
    from auth.users u
    cross join lateral (select app.mfa_locked(u.id) as v) locked
    left join lateral (
      select pr.id, pr.household_id, pr.role, h.name as household_name, h.deleted_at
        from app.profile pr join app.household h on h.id = pr.household_id
       where pr.auth_user_id = u.id and pr.active
       order by (h.deleted_at is null) desc, pr.created_at limit 1) p on true
   where u.id = auth.uid()
$$;

-- ------------------------------------------------------------ F22: who may sign up

-- As in 20261030100000_claim_server.sql while the server is unclaimed. Once it is claimed,
-- in code mode, a sign-up needs a live claim with an unconsumed key for its address, or an
-- open invitation (any address: the invited person may sign up with another one than the
-- invitation names) in a live family. The device-account marker domain is never admitted:
-- device users are created by app.create_auth_user, not through GoTrue.
create or replace function app.before_user_created_hook(event jsonb) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_email text := lower(btrim(coalesce(event -> 'user' ->> 'email', '')));
begin
  if v_email like '%@devices.wuselwall.invalid' then
    return jsonb_build_object('error', jsonb_build_object(
      'message', 'email_reserved', 'http_code', 403));
  end if;
  if app.household_creation_mode() <> 'code' then
    return '{}'::jsonb;
  end if;
  if v_email <> '' and exists (
       select 1 from app.setup_token t
        where t.consumed_at is null and t.claimed_email = v_email
          and t.claimed_at > now() - interval '15 minutes') then
    return '{}'::jsonb;
  end if;
  if not app.server_claimed() then
    return jsonb_build_object('error', jsonb_build_object(
      'message', 'setup_key_required', 'http_code', 403));
  end if;
  if exists (
       select 1 from app.invitation i
         join app.household h on h.id = i.household_id and h.deleted_at is null
        where i.accepted_at is null and i.revoked_at is null and i.expires_at > now()) then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object('error', jsonb_build_object(
    'message', 'invitation_required', 'http_code', 403));
end $$;

-- ------------------------------------------------------------ F3: the resets on Today

-- Two more notice kinds. The dismissal keys follow.
alter table app.notice_dismissal drop constraint notice_dismissal_notice_key_check;
alter table app.notice_dismissal add constraint notice_dismissal_notice_key_check
  check (notice_key ~ '^(join|signin|mfa_reset|password_reset_issued):[0-9a-f-]{1,40}$');

-- As in 20261102110000_household_trust.sql, plus the reset notices: when a guardian resets
-- someone's second factor or issues a reset code for them, the person concerned and every
-- other guardian see it on Today for 14 days (`name` is the guardian who did it,
-- `profile_id` the person it was done for); the guardian who did it does not. The
-- operator's codes have no actor and make no notice.
create or replace function app.notices_for(a app.actor_t)
returns table (notice_key text, kind text, at timestamptz, name text, device_id uuid, profile_id uuid)
language plpgsql stable security definer set search_path = '' as $$
declare v_since timestamptz;
begin
  if a.device_class = 'kiosk' then
    return;
  end if;

  return query
  select 'join:' || l.id::text, 'join'::text, l.occurred_at, p.display_name, null::uuid, p.id
    from app.audit_log l
    join app.profile p on p.id = l.actor_profile_id and p.household_id = a.household_id
   where app.guardian_ok(a)
     and l.household_id = a.household_id
     and l.entity_type = 'invitation' and l.action = 'accept'
     and l.occurred_at > now() - interval '14 days'
     and l.actor_profile_id <> a.profile_id
     and not exists (select 1 from app.notice_dismissal d
                      where d.profile_id = a.profile_id and d.notice_key = 'join:' || l.id::text);

  return query
  select k.key, k.kind, l.occurred_at, p.display_name, null::uuid, l.entity_id
    from app.audit_log l
    join app.profile p on p.id = l.actor_profile_id and p.household_id = a.household_id
    cross join lateral (
      select case l.action when 'mfa_reset' then 'mfa_reset' else 'password_reset_issued' end as kind,
             case l.action when 'mfa_reset' then 'mfa_reset:' else 'password_reset_issued:' end || l.id::text as key) k
   where l.household_id = a.household_id
     and l.entity_type = 'profile' and l.action in ('mfa_reset', 'password_reset_code')
     and l.occurred_at > now() - interval '14 days'
     and l.actor_profile_id <> a.profile_id
     and (l.entity_id = a.profile_id or app.guardian_ok(a))
     and not exists (select 1 from app.notice_dismissal d
                      where d.profile_id = a.profile_id and d.notice_key = k.key);

  if a.device_class = 'personal' then
    select created_at into v_since from app.device where id = a.device_id;
    return query
    select 'signin:' || d.id::text, 'signin'::text, d.created_at, d.label, d.id, null::uuid
      from app.device d
     where d.household_id = a.household_id
       and d.profile_id = a.profile_id
       and d.class = 'personal'
       and d.revoked_at is null
       and d.id <> a.device_id
       and d.created_at > v_since
       and d.created_at > now() - interval '14 days'
       and not exists (select 1 from app.notice_dismissal x
                        where x.profile_id = a.profile_id and x.notice_key = 'signin:' || d.id::text);
  end if;
end $$;
