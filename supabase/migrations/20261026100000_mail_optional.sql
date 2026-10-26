-- Mail optional (specs/20 "Choosing the server", Q48, specs/16 step 10.4).
--
-- A server without SMTP autoconfirms addresses: whoever signs up with a password gets an
-- account whose email_confirmed_at is set without any mail being sent. Two things follow:
--
-- 1. An invitation is matched to an account by email (H0 and accepting by invitation id) only
--    when the server proved the address: GoTrue mailed a confirmation (confirmation_sent_at)
--    and it was confirmed. An autoconfirmed sign-up has no confirmation_sent_at, so an address
--    typed on a server without mail never matches. Links, QR and codes keep working.
-- 2. A forgotten password cannot be reset by mail. A guardian on a personal device creates a
--    one-time code for another adult of the household (ten minutes, single use); the adult
--    redeems it with their address and a new password. The operator can issue the same code
--    from the server's shell (app.password_reset_issue_for_email, used by `wuselwall password`).
--
-- Additive for api_version: new tables and functions; the feature 'password-reset' tells the
-- app the server has them.

-- ------------------------------------------------------------ the proven address

-- The account's address in lower case, only if GoTrue mailed a confirmation and it was
-- confirmed; null otherwise (an autoconfirmed sign-up, a device user, an unconfirmed one).
create function app.proven_email(p_user uuid) returns text
language sql stable security definer set search_path = '' as $$
  select lower(u.email) from auth.users u
   where u.id = p_user and u.email_confirmed_at is not null and u.confirmation_sent_at is not null
$$;

revoke execute on function app.proven_email(uuid) from public, anon, authenticated;

-- ------------------------------------------------------------ account: my_account

-- As in 20261015104000_leave.sql, with one change: pending invitations match the proven
-- address only.
create or replace function api.my_account() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'user_id',            u.id,
    'email',              u.email,
    -- A device user (a shared or kiosk tablet) has no profile but is not free to start one.
    -- A phone's own row counts only while it is live.
    'has_household',      (p.id is not null and p.deleted_at is null)
                          or exists (select 1 from app.device d where d.auth_user_id = u.id
                                      and (d.class <> 'personal' or d.revoked_at is null)),
    'household_id',       case when p.deleted_at is null then p.household_id end,
    -- The family's name, for the typed confirmation of a deletion.
    'household_name',     case when p.deleted_at is null then p.household_name end,
    'profile_id',         case when p.deleted_at is null then p.id end,
    'household_creation', app.household_creation_mode(),
    'full_name', nullif(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')), ''),
    'given_name', coalesce(
      nullif(btrim(coalesce(u.raw_user_meta_data ->> 'given_name', '')), ''),
      nullif(split_part(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')), ' ', 1), '')),
    -- Why the caller cannot leave the family, for the app to say so before the attempt.
    'leave_blocked', case when p.id is not null and p.deleted_at is null and p.role = 'guardian'
                          and exists (select 1 from app.profile o where o.household_id = p.household_id
                                       and o.active and o.id <> p.id)
                          and not exists (select 1 from app.profile o where o.household_id = p.household_id
                                       and o.active and o.id <> p.id and o.role = 'guardian'
                                       and o.auth_user_id is not null)
                        then 'last_guardian' end,
    -- Invitations naming this account's proven email, never into a deleted family.
    'pending_invitations', coalesce((
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
         and ip.active and ip.auth_user_id is null), '[]'::jsonb),
    'deleted_household', case when p.deleted_at is not null then jsonb_build_object(
      'id',         p.household_id,
      'name',       p.household_name,
      'deleted_at', p.deleted_at,
      'purge_after', p.deleted_at + app.household_retention(),
      'can_restore', p.role = 'guardian' and now() < p.deleted_at + app.household_retention())
    end)
    from auth.users u
    left join lateral (
      select pr.id, pr.household_id, pr.role, h.name as household_name, h.deleted_at
        from app.profile pr join app.household h on h.id = pr.household_id
       where pr.auth_user_id = u.id and pr.active
       order by (h.deleted_at is null) desc, pr.created_at limit 1) p on true
   where u.id = auth.uid()
$$;

-- ------------------------------------------------------------ account: invitation_accept

-- As in 20261015103000_invitations.sql, with one change: accepting by invitation id needs the
-- proven address (an autoconfirmed one counts as not confirmed).
create or replace function api.invitation_accept(p_token_or_code text, p_invitation_id uuid, p_display_name text,
                                                 p_color text, p_device_label text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user      uuid := auth.uid();
  v_session   uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  v_client    text := app.client_key();
  v_mail      text;
  v_inv       app.invitation;
  v_prof      app.profile;
  v_dev       uuid := gen_random_uuid();
  v_actor     app.actor_t;
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '42501', hint = 'auth_required';
  end if;
  if v_session is null or not exists (select 1 from auth.sessions where id = v_session and user_id = v_user) then
    raise exception 'no session' using errcode = '42501', hint = 'session_invalid';
  end if;
  -- One household per account, and no device user (a shared or kiosk tablet) starts one.
  if exists (select 1 from app.profile where auth_user_id = v_user and active)
     -- A phone revoked by leaving a family does not count (20261015104000_leave.sql).
     or exists (select 1 from app.device where auth_user_id = v_user
                 and (class <> 'personal' or revoked_at is null)) then
    raise exception 'already in a household' using errcode = '42501', hint = 'already_in_household';
  end if;

  if p_display_name is not null and length(btrim(p_display_name)) not between 1 and 40 then
    raise exception 'name invalid' using errcode = '22023', hint = 'name_invalid';
  end if;
  if p_color is not null and p_color !~ '^#[0-9A-Fa-f]{6}$' then
    raise exception 'colour invalid' using errcode = '22023', hint = 'color_invalid';
  end if;
  if length(btrim(coalesce(p_device_label, ''))) not between 1 and 60 then
    raise exception 'label required' using errcode = '22023', hint = 'label_invalid';
  end if;

  if p_invitation_id is not null then
    v_mail := app.proven_email(v_user);
    if v_mail is null then
      raise exception 'email not confirmed' using errcode = '42501', hint = 'email_not_confirmed';
    end if;
    select * into v_inv from app.invitation where id = p_invitation_id and email = v_mail;
    if not found then
      raise exception 'not invited' using errcode = '42501', hint = 'invitation_not_for_account';
    end if;
  else
    if app.invitation_rate_limited(v_client) then
      return jsonb_build_object('ok', false, 'reason', 'rate_limited');
    end if;
    select * into v_inv from app.invitation where id = app.invitation_lookup(p_token_or_code);
    if not found then
      perform app.invitation_log(v_client, false);
      return jsonb_build_object('ok', false, 'reason', 'invalid');
    end if;
    perform app.invitation_log(v_client, true);
  end if;

  if v_inv.revoked_at is not null or v_inv.accepted_at is not null then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;
  if v_inv.expires_at <= now() then
    return jsonb_build_object('ok', false, 'reason', 'expired');
  end if;

  select * into v_prof from app.profile where id = v_inv.profile_id for update;
  if not found or not v_prof.active or v_prof.auth_user_id is not null or v_prof.kind <> 'adult' then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;

  update app.profile set
    auth_user_id = v_user,
    role         = v_inv.role,
    display_name = coalesce(btrim(p_display_name), display_name),
    color        = coalesce(upper(p_color), color)
   where id = v_prof.id
  returning * into v_prof;

  insert into app.device (id, household_id, auth_user_id, auth_session_id, label, class, register, profile_id)
  values (v_dev, v_inv.household_id, v_user, v_session, btrim(p_device_label), 'personal', 'adult', v_prof.id);

  update app.invitation set accepted_at = now(), accepted_by_user = v_user where id = v_inv.id;

  v_actor := row(v_inv.household_id, v_prof.id, v_prof.role, v_dev, 'personal', 'ui',
                 null::timestamptz, null::uuid)::app.actor_t;
  perform app.audit(v_actor, 'invitation', v_inv.id, 'accept',
                    jsonb_build_object('inviter_profile_id', v_inv.created_by_profile_id));
  perform app.audit(v_actor, 'device', v_dev, 'register_personal');
  return jsonb_build_object('ok', true, 'household_id', v_inv.household_id,
                            'profile_id', v_prof.id, 'device_id', v_dev);
end $$;

-- ------------------------------------------------------------ password reset codes: tables

create table app.password_reset (
  id                    uuid primary key default gen_random_uuid(),
  auth_user_id          uuid not null references auth.users on delete cascade,
  -- The adult the code is for, and who made it; both null when the operator issued it.
  household_id          uuid references app.household on delete cascade,
  profile_id            uuid references app.profile on delete cascade,
  created_by_profile_id uuid references app.profile on delete set null,
  code_hash             text not null unique,
  created_at            timestamptz not null default now(),
  expires_at            timestamptz not null,
  used_at               timestamptz
);
create index on app.password_reset (auth_user_id) where used_at is null;

alter table app.password_reset enable row level security;
alter table app.password_reset force row level security;
create policy owner_all on app.password_reset to postgres using (true) with check (true);
-- No grants to anon or authenticated: the api functions below are the only way in.
revoke all on app.password_reset from public, anon, authenticated;

-- Redeem attempts, for the rate limit (as app.pairing_attempt).
create table app.password_reset_attempt (
  id           bigint generated always as identity primary key,
  attempted_at timestamptz not null default now(),
  client_key   text not null,
  success      boolean not null
);
create index on app.password_reset_attempt (client_key, attempted_at desc);
alter table app.password_reset_attempt enable row level security;
alter table app.password_reset_attempt force row level security;
create policy owner_all on app.password_reset_attempt to postgres using (true) with check (true);
revoke all on app.password_reset_attempt from public, anon, authenticated;

-- ------------------------------------------------------------ password reset codes: internals

-- A new code for one Auth user. Earlier open codes for that user stop working, so only the
-- code on screen counts. 8 characters from 32 symbols, as pairing; valid ten minutes.
create function app.password_reset_issue(p_user uuid, p_household uuid, p_profile uuid, p_by uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_alpha   constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- no 0/O/1/I
  v_bytes   bytea;
  v_code    text;
  v_expires timestamptz := now() + interval '10 minutes';
begin
  update app.password_reset set used_at = now() where auth_user_id = p_user and used_at is null;
  loop
    v_bytes := extensions.gen_random_bytes(8);
    v_code := '';
    for i in 0..7 loop
      v_code := v_code || substr(v_alpha, 1 + (get_byte(v_bytes, i) % 32), 1);
    end loop;
    exit when not exists (select 1 from app.password_reset where code_hash = app.pairing_hash(v_code));
  end loop;
  insert into app.password_reset (auth_user_id, household_id, profile_id, created_by_profile_id, code_hash, expires_at)
  values (p_user, p_household, p_profile, p_by, app.pairing_hash(v_code), v_expires);
  return jsonb_build_object('code', v_code, 'expires_at', v_expires);
end $$;

-- For the operator, from the server's shell (`wuselwall password <email>`): a code for any
-- account that is not a device user. Null when there is no such account.
create function app.password_reset_issue_for_email(p_email text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid;
  v_prof app.profile;
begin
  select u.id into v_user from auth.users u
   where lower(u.email) = lower(btrim(coalesce(p_email, '')))
     and not exists (select 1 from app.device d where d.auth_user_id = u.id and d.class <> 'personal');
  if v_user is null then
    return null;
  end if;
  select * into v_prof from app.profile where auth_user_id = v_user and active order by created_at limit 1;
  if v_prof.id is not null then
    perform app.audit(row(v_prof.household_id, null::uuid, null::text, null::uuid, null::text, 'operator',
                          null::timestamptz, null::uuid)::app.actor_t,
                      'profile', v_prof.id, 'password_reset_code');
  end if;
  return app.password_reset_issue(v_user, v_prof.household_id, v_prof.id, null);
end $$;

revoke execute on function app.password_reset_issue(uuid, uuid, uuid, uuid),
  app.password_reset_issue_for_email(text) from public, anon, authenticated;

-- ------------------------------------------------------------ api: the guardian's phone

-- A guardian on a personal device creates a code for another adult of the household who has an
-- account. The code is shown once, on the guardian's screen, and handed over in person.
-- A second factor still protects an account that has one: the code replaces only the password.
create function api.password_reset_create(p_actor uuid, p_profile uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.actor(p_actor);
  v_target app.profile;
begin
  if a.device_class <> 'personal' then
    raise exception 'personal device required' using errcode = '42501', hint = 'personal_device_required';
  end if;
  perform app.require_guardian(a);

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

  perform app.audit(a, 'profile', v_target.id, 'password_reset_code');
  return app.password_reset_issue(v_target.auth_user_id, a.household_id, v_target.id, a.profile_id);
end $$;

-- ------------------------------------------------------------ api: the signed-out device

-- The adult types their address, the code and a new password. Rate limited per forwarded-for
-- client (10 failures in 10 minutes) and overall (200 failures in 10 minutes); a refusal is a
-- result, not an error, so the attempt log is kept. The code is spent and the password set in
-- one transaction.
create function api.password_reset_redeem(p_email text, p_code text, p_password text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_key   text := 'reset:' || app.client_key();
  v_code  text := regexp_replace(upper(coalesce(p_code, '')), '[^A-Z0-9]', '', 'g');
  v_reset app.password_reset;
begin
  if (select count(*) from app.password_reset_attempt
       where client_key = v_key and not success and attempted_at > now() - interval '10 minutes') >= 10
     or (select count(*) from app.password_reset_attempt
          where not success and attempted_at > now() - interval '10 minutes') >= 200 then
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
  update app.password_reset set used_at = now() where id = v_reset.id;
  insert into app.password_reset_attempt (client_key, success) values (v_key, true);
  if v_reset.profile_id is not null then
    perform app.audit(row(v_reset.household_id, v_reset.profile_id, null::text, null::uuid, null::text, 'ui',
                          null::timestamptz, null::uuid)::app.actor_t,
                      'profile', v_reset.profile_id, 'password_reset');
  end if;
  return jsonb_build_object('ok', true);
end $$;

revoke execute on function api.password_reset_create(uuid, uuid),
  api.password_reset_redeem(text, text, text) from public, anon, authenticated;
grant execute on function api.password_reset_create(uuid, uuid) to authenticated;
grant execute on function api.password_reset_redeem(text, text, text) to anon, authenticated;

-- ------------------------------------------------------------ discovery

create or replace function api.server_info()
returns jsonb
language sql
immutable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'api_version', 1,
    'min_app_version', '1.0.0',
    'household_creation', 'token',
    'features', jsonb_build_array(
      'calendar', 'ics', 'calendar-import', 'school', 'tasks', 'meals', 'shopping', 'holidays',
      'lighter-day', 'event-templates', 'password-reset'
    )
  );
$$;
