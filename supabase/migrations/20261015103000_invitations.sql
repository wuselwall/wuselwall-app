-- Invitations (onboarding J2, specs/20 "J2 — Join a family", specs/16 step 9.3).
-- A guardian on a personal phone invites an adult of the household: the invitation names an
-- adult profile without an account, and the invitee's account becomes that profile. Three
-- equivalent forms: a token (the link's fragment), an 8-symbol code and, when given, the
-- invitee's email (matched on a confirmed address, which makes the code unnecessary).
-- Token and code are stored as sha256 hashes only, like app.pairing_request.
--
-- Additive for api_version: new tables, views and functions; `api.members` gains a column at
-- the end and `api.my_account` gains one field.

-- ------------------------------------------------------------ table

create table app.invitation (
  id                     uuid primary key default gen_random_uuid(),
  household_id           uuid not null references app.household on delete cascade,
  profile_id             uuid not null references app.profile on delete cascade,
  role                   text not null check (role in ('guardian', 'member')),
  email                  text check (email is null or email = lower(email)),
  token_hash             text not null unique,
  code_hash              text not null unique,
  created_by_profile_id  uuid references app.profile on delete set null,
  created_at             timestamptz not null default now(),
  expires_at             timestamptz not null,
  accepted_at            timestamptz,
  accepted_by_user       uuid references auth.users on delete set null,
  revoked_at             timestamptz,
  check (accepted_at is null or accepted_by_user is not null)
);
create index on app.invitation (household_id);
create index on app.invitation (email) where email is not null;

alter table app.invitation enable row level security;
alter table app.invitation force row level security;
create policy invitation_read on app.invitation for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.invitation to postgres using (true) with check (true);
-- Column grants: the hashes and the accepting Auth user never reach a client.
grant select (id, household_id, profile_id, role, email, created_by_profile_id, created_at,
              expires_at, accepted_at, revoked_at)
  on app.invitation to authenticated;

-- The invitations' own attempt log (preview and accept by code). Kept apart from the pairing
-- and enrolment logs, so that a stranger guessing codes uses up none of their budgets.
create table app.invitation_attempt (
  id           bigint generated always as identity primary key,
  attempted_at timestamptz not null default now(),
  client_key   text not null,
  success      boolean not null
);
create index on app.invitation_attempt (client_key, attempted_at desc);
alter table app.invitation_attempt enable row level security;
alter table app.invitation_attempt force row level security;
create policy owner_all on app.invitation_attempt to postgres using (true) with check (true);
revoke all on app.invitation_attempt from public, anon, authenticated;

-- ------------------------------------------------------------ internals

create function app.invitation_hash(p_value text) returns text
language sql immutable set search_path = '' as $$
  select encode(extensions.digest(p_value, 'sha256'), 'hex')
$$;

-- The invitation a token or a code names, or null. A token is 32 hex digits; a code is eight
-- symbols of the enrolment alphabet, typed in any case, with or without the hyphen.
create function app.invitation_lookup(p_token_or_code text) returns uuid
language plpgsql stable set search_path = '' as $$
declare
  v_s  text := regexp_replace(btrim(coalesce(p_token_or_code, '')), '[\s-]', '', 'g');
  v_id uuid;
begin
  if v_s ~ '^[0-9a-fA-F]{32}$' then
    select id into v_id from app.invitation where token_hash = app.invitation_hash(lower(v_s));
  elsif upper(v_s) ~ '^[A-Z0-9]{8}$' then
    select id into v_id from app.invitation where code_hash = app.invitation_hash(upper(v_s));
  end if;
  return v_id;
end $$;

-- Ten minutes: twenty calls per client, three hundred overall. Every call that gets as far as
-- a lookup is logged, so a guesser is stopped whether or not the guess is right.
create function app.invitation_rate_limited(p_client text) returns boolean
language sql stable set search_path = '' as $$
  select (select count(*) from app.invitation_attempt
           where client_key = 'invite:' || p_client and attempted_at > now() - interval '10 minutes') >= 20
      or (select count(*) from app.invitation_attempt
           where client_key like 'invite:%' and attempted_at > now() - interval '10 minutes') >= 300
$$;

create function app.invitation_log(p_client text, p_success boolean) returns void
language sql set search_path = '' as $$
  insert into app.invitation_attempt (client_key, success) values ('invite:' || p_client, p_success)
$$;

-- Whether an Auth user may be asked for a household's data at all: the profile is in the
-- caller's household. Used by api.members; the owner reads the column, the caller gets a boolean.
create function app.profile_has_account(p_profile uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from app.profile p
                  where p.id = p_profile and p.household_id = app.jwt_household()
                    and p.auth_user_id is not null)
$$;

revoke execute on function app.invitation_hash(text), app.invitation_lookup(text),
  app.invitation_rate_limited(text), app.invitation_log(text, boolean)
  from public, anon, authenticated;
revoke execute on function app.profile_has_account(uuid) from public, anon;
grant execute on function app.profile_has_account(uuid) to authenticated;

-- ------------------------------------------------------------ views

-- Open invitations of the household, and those accepted in the last thirty days. No hashes.
create view api.invitations with (security_invoker = true) as
  select i.id, i.household_id, i.profile_id, p.display_name as profile_name, i.role, i.email,
         i.created_by_profile_id, i.created_at, i.expires_at, i.accepted_at, i.revoked_at
    from app.invitation i
    join app.profile p on p.id = i.profile_id
   where (i.accepted_at is null and i.revoked_at is null and i.expires_at > now())
      or i.accepted_at > now() - interval '30 days';

grant select on api.invitations to authenticated;

-- api.members: one column appended. Whether the person has an account (an invitation is open
-- only for a profile without one).
create or replace view api.members with (security_invoker = true) as
  select id, household_id, display_name, color, role, active,
         sort_order, kind, default_presence_state, default_presence_label,
         app.profile_has_account(id) as has_account
    from app.profile;

-- ------------------------------------------------------------ api: my_account

-- Adds the invitations that name this account's confirmed email, and keeps every field.
create or replace function api.my_account() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'user_id',            u.id,
    'email',              u.email,
    -- A device user (a shared or kiosk tablet) has no profile but is not free to start one.
    'has_household',      p.id is not null or exists (select 1 from app.device d where d.auth_user_id = u.id),
    'household_id',       p.household_id,
    'profile_id',         p.id,
    'household_creation', app.household_creation_mode(),
    'full_name', nullif(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')), ''),
    'given_name', coalesce(
      nullif(btrim(coalesce(u.raw_user_meta_data ->> 'given_name', '')), ''),
      nullif(split_part(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')), ' ', 1), '')),
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
        join app.household h on h.id = i.household_id
        join app.profile ip on ip.id = i.profile_id
        left join app.profile inv on inv.id = i.created_by_profile_id
       where u.email_confirmed_at is not null
         and i.email = lower(u.email)
         and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()
         and ip.active and ip.auth_user_id is null), '[]'::jsonb))
    from auth.users u
    left join lateral (
      select pr.id, pr.household_id from app.profile pr
       where pr.auth_user_id = u.id and pr.active
       order by pr.created_at limit 1) p on true
   where u.id = auth.uid()
$$;

-- ------------------------------------------------------------ api: invite

-- A guardian on their own phone invites an adult: a new adult profile (with p_display_name,
-- p_role) or an existing adult of the household without an account (p_profile). Returns the
-- token and the code once; only their hashes are stored. Earlier open invitations of the same
-- profile are revoked, so re-sharing is this call again.
create function api.invitation_create(p_actor uuid, p_profile uuid, p_display_name text,
                                      p_role text, p_email text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_prof    app.profile;
  v_email   text := nullif(lower(btrim(coalesce(p_email, ''))), '');
  v_alpha   constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- no 0/O/1/I
  v_token   text := encode(extensions.gen_random_bytes(16), 'hex');
  v_bytes   bytea;
  v_code    text;
  v_expires timestamptz := now() + interval '7 days';
  v_id      uuid;
begin
  perform app.require_guardian(a);
  if a.device_class <> 'personal' then
    raise exception 'personal device required' using errcode = '42501', hint = 'personal_device_required';
  end if;
  if coalesce(p_role, '') not in ('guardian', 'member') then
    raise exception 'role invalid' using errcode = '22023', hint = 'invitation_role_invalid';
  end if;
  if v_email is not null and (length(v_email) > 254 or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$') then
    raise exception 'email invalid' using errcode = '22023', hint = 'email_invalid';
  end if;

  if p_profile is null then
    if length(btrim(coalesce(p_display_name, ''))) not between 1 and 40 then
      raise exception 'name invalid' using errcode = '22023', hint = 'name_invalid';
    end if;
    insert into app.profile (household_id, display_name, color, role, kind)
    values (a.household_id, btrim(p_display_name), app.next_member_color(a.household_id), p_role, 'adult')
    returning * into v_prof;
    perform app.audit(a, 'profile', v_prof.id, 'create',
                      jsonb_build_object('display_name', v_prof.display_name, 'kind', 'adult'));
  else
    select * into v_prof from app.profile
     where id = p_profile and household_id = a.household_id and active;
    if not found or v_prof.kind <> 'adult' then
      raise exception 'profile invalid' using errcode = '22023', hint = 'invitation_profile_invalid';
    end if;
    if v_prof.auth_user_id is not null then
      raise exception 'profile has an account' using errcode = '22023', hint = 'profile_has_account';
    end if;
  end if;

  update app.invitation set revoked_at = now()
   where profile_id = v_prof.id and accepted_at is null and revoked_at is null;

  -- 8 characters from 32 symbols: a byte modulo 32 is unbiased (256 = 8 * 32).
  loop
    v_bytes := extensions.gen_random_bytes(8);
    v_code := '';
    for i in 0..7 loop
      v_code := v_code || substr(v_alpha, 1 + (get_byte(v_bytes, i) % 32), 1);
    end loop;
    exit when not exists (select 1 from app.invitation where code_hash = app.invitation_hash(v_code));
  end loop;

  insert into app.invitation (household_id, profile_id, role, email, token_hash, code_hash,
                              created_by_profile_id, expires_at)
  values (a.household_id, v_prof.id, p_role, v_email, app.invitation_hash(v_token),
          app.invitation_hash(v_code), a.profile_id, v_expires)
  returning id into v_id;

  perform app.audit(a, 'invitation', v_id, 'create',
                    jsonb_build_object('profile_id', v_prof.id, 'role', p_role, 'email', v_email is not null));
  return jsonb_build_object('id', v_id, 'profile_id', v_prof.id, 'token', v_token,
                            'code', v_code, 'expires_at', v_expires);
end $$;

-- Withdraws an open invitation. Used by "Zurückziehen".
create function api.invitation_revoke(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  v_id uuid;
begin
  perform app.require_guardian(a);
  if a.device_class <> 'personal' then
    raise exception 'personal device required' using errcode = '42501', hint = 'personal_device_required';
  end if;
  update app.invitation set revoked_at = now()
   where id = p_id and household_id = a.household_id and accepted_at is null and revoked_at is null
  returning id into v_id;
  if v_id is null then
    raise exception 'invitation not open' using errcode = '22023', hint = 'invitation_not_open';
  end if;
  perform app.audit(a, 'invitation', v_id, 'revoke');
end $$;

-- What the invitee sees before signing in: the household's name and the inviter's first name,
-- the person's first name and the role. Nothing else. Failures are results, not raises, so the
-- attempt log survives them.
create function api.invitation_preview(p_token_or_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_client text := app.client_key();
  v_inv    app.invitation;
  v_ok     boolean := false;
  v_reason text;
  v_out    jsonb;
begin
  if app.invitation_rate_limited(v_client) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;

  select * into v_inv from app.invitation where id = app.invitation_lookup(p_token_or_code);
  if not found or v_inv.revoked_at is not null or v_inv.accepted_at is not null then
    v_reason := 'invalid';
  elsif v_inv.expires_at <= now() then
    v_reason := 'expired';
  else
    v_ok := true;
  end if;
  perform app.invitation_log(v_client, v_ok);

  if not v_ok then
    return jsonb_build_object('ok', false, 'reason', v_reason);
  end if;
  select jsonb_build_object(
           'ok', true,
           'household_name', h.name,
           'inviter_first_name', nullif(split_part(btrim(coalesce(inv.display_name, '')), ' ', 1), ''),
           'profile_name', p.display_name,
           'role', v_inv.role,
           'expires_at', v_inv.expires_at)
    into v_out
    from app.household h
    join app.profile p on p.id = v_inv.profile_id
    left join app.profile inv on inv.id = v_inv.created_by_profile_id
   where h.id = v_inv.household_id;
  return v_out;
end $$;

-- A signed-in account without a household (or device) becomes an adult of the household that
-- invited it: its profile is linked to the account, this session becomes the personal device,
-- and the invitation is spent. By the token or code (rate limited like the preview), or by the
-- invitation's id when its email is this account's confirmed address.
-- Refusals a person can correct come back as results; account state and the email check are
-- raises, since they count against nothing.
create function api.invitation_accept(p_token_or_code text, p_invitation_id uuid, p_display_name text,
                                      p_color text, p_device_label text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user      uuid := auth.uid();
  v_session   uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  v_client    text := app.client_key();
  v_confirmed timestamptz;
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
    select u.email_confirmed_at, lower(u.email) into v_confirmed, v_mail from auth.users u where u.id = v_user;
    if v_confirmed is null then
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

-- ------------------------------------------------------------ grants

revoke execute on function api.invitation_create(uuid, uuid, text, text, text),
  api.invitation_revoke(uuid, uuid), api.invitation_preview(text),
  api.invitation_accept(text, uuid, text, text, text) from public, anon, authenticated;
grant execute on function api.invitation_create(uuid, uuid, text, text, text),
  api.invitation_revoke(uuid, uuid), api.invitation_accept(text, uuid, text, text, text) to authenticated;
grant execute on function api.invitation_preview(text) to anon, authenticated;

