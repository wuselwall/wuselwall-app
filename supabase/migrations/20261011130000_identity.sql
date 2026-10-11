-- M0.1 Identity (specs/08, ADR-004, ADR-010).
-- Two layers: a device session (one Auth user per device) and an acting profile chosen
-- by tapping. Guardian actions need a PIN step-up recorded server-side on the device row.

-- ---------------------------------------------------------------- tables

create table app.household (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (length(btrim(name)) > 0),
  timezone   text not null default 'Europe/Berlin',
  locale     text not null default 'de-DE',
  created_at timestamptz not null default now()
);

create table app.profile (
  id               uuid primary key default gen_random_uuid(),
  household_id     uuid not null references app.household on delete cascade,
  display_name     text not null check (length(btrim(display_name)) > 0),
  color            text not null default '#2E7D6B' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  role             text not null check (role in ('guardian', 'member')),
  auth_user_id     uuid unique references auth.users on delete set null,
  pin_hash         text,
  pin_failures     int not null default 0,
  pin_locked_until timestamptz,
  active           boolean not null default true,
  created_at       timestamptz not null default now()
);
create index on app.profile (household_id);

create table app.device (
  id                      uuid primary key default gen_random_uuid(),
  household_id            uuid not null references app.household on delete cascade,
  auth_user_id            uuid not null unique references auth.users on delete cascade,
  label                   text not null,
  class                   text not null check (class in ('personal', 'shared', 'kiosk')),
  register                text not null check (register in ('adult', 'kid', 'kiosk')),
  profile_id              uuid references app.profile on delete set null,
  guardian_verified_until timestamptz,
  last_seen_at            timestamptz,
  revoked_at              timestamptz,
  created_at              timestamptz not null default now(),
  check (class <> 'personal' or profile_id is not null)
);
create index on app.device (household_id);

create table app.enrolment_code (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references app.household on delete cascade,
  code_hash    text not null unique,
  label        text not null,
  class        text not null check (class in ('shared', 'kiosk')),
  register     text not null check (register in ('adult', 'kid', 'kiosk')),
  created_by   uuid references app.profile on delete set null,
  expires_at   timestamptz not null,
  consumed_at  timestamptz
);

-- One row at deploy time; the setup call must present the matching token (specs/08).
create table app.setup_token (
  token_hash  text primary key,
  consumed_at timestamptz
);

create table app.audit_log (
  id               bigint generated always as identity primary key,
  occurred_at      timestamptz not null default now(),
  household_id     uuid references app.household on delete cascade,
  actor_profile_id uuid,
  device_id        uuid,
  origin           text not null default 'ui',
  entity_type      text not null,
  entity_id        uuid,
  action           text not null,
  diff             jsonb
);
create index on app.audit_log (household_id, occurred_at desc);

-- ---------------------------------------------------------------- helpers

create type app.actor_t as (
  household_id            uuid,
  profile_id              uuid,
  profile_role            text,
  device_id               uuid,
  device_class            text,
  origin                  text,
  guardian_verified_until timestamptz
);

create function app.jwt_household() returns uuid
language sql stable set search_path = '' as $$
  select nullif(auth.jwt() ->> 'household_id', '')::uuid
$$;

create function app.jwt_device() returns uuid
language sql stable set search_path = '' as $$
  select nullif(auth.jwt() ->> 'device_id', '')::uuid
$$;

-- True while the calling device exists and is not revoked. Every policy checks it, so a
-- revoked device loses access on its very next request, not at token expiry.
create function app.device_ok() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from app.device d
    where d.id = app.jwt_device()
      and d.household_id = app.jwt_household()
      and d.revoked_at is null
  )
$$;

-- First line of every api write function: who is acting, and may they on this device?
create function app.actor(p_profile uuid default null) returns app.actor_t
language plpgsql stable security definer set search_path = '' as $$
declare
  v_dev  app.device;
  v_prof app.profile;
begin
  select * into v_dev from app.device
   where id = app.jwt_device() and household_id = app.jwt_household();
  if not found or v_dev.revoked_at is not null then
    raise exception 'device not usable' using errcode = '42501', hint = 'device_revoked';
  end if;

  if v_dev.class = 'personal' then
    select * into v_prof from app.profile where id = v_dev.profile_id;
  else
    if p_profile is null then
      raise exception 'acting profile required' using errcode = '22023', hint = 'actor_required';
    end if;
    select * into v_prof from app.profile
     where id = p_profile and household_id = v_dev.household_id and active;
  end if;
  if not found then
    raise exception 'unknown acting profile' using errcode = '42501', hint = 'actor_invalid';
  end if;

  return row(v_dev.household_id, v_prof.id, v_prof.role, v_dev.id, v_dev.class,
             'ui', v_dev.guardian_verified_until)::app.actor_t;
end $$;

create function app.require_guardian(a app.actor_t) returns void
language plpgsql stable set search_path = '' as $$
begin
  if a.profile_role = 'guardian'
     and (a.device_class = 'personal' or coalesce(a.guardian_verified_until, '-infinity') > now()) then
    return;
  end if;
  raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
end $$;

create function app.audit(a app.actor_t, p_entity text, p_id uuid, p_action text, p_diff jsonb default null)
returns void language sql security definer set search_path = '' as $$
  insert into app.audit_log (household_id, actor_profile_id, device_id, origin, entity_type, entity_id, action, diff)
  values (a.household_id, a.profile_id, a.device_id, a.origin, p_entity, p_id, p_action, p_diff)
$$;

-- Creates an Auth user directly (no admin API, so this also works where Edge Functions
-- cannot be served). Mirrors what GoTrue writes for an email/password user.
create function app.create_auth_user(p_email text, p_password text, p_meta jsonb default '{}')
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change)
  values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    lower(p_email), extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', p_meta, now(), now(), '', '', '', '');
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, created_at, updated_at, last_sign_in_at)
  values (gen_random_uuid(), v_id, v_id::text, 'email',
          jsonb_build_object('sub', v_id::text, 'email', lower(p_email), 'email_verified', true),
          now(), now(), now());
  return v_id;
end $$;

-- ---------------------------------------------------------------- access-token hook

create function app.custom_access_token_hook(event jsonb) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_dev  app.device;
  claims jsonb := event -> 'claims';
begin
  select * into v_dev from app.device
   where auth_user_id = (event ->> 'user_id')::uuid and revoked_at is null;
  if found then
    claims := claims || jsonb_build_object(
      'household_id', v_dev.household_id,
      'device_id',    v_dev.id,
      'device_class', v_dev.class,
      'profile_id',   case when v_dev.class = 'personal' then v_dev.profile_id end);
  end if;
  return jsonb_set(event, '{claims}', claims);
end $$;

grant usage on schema app to supabase_auth_admin;
grant execute on function app.custom_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function app.custom_access_token_hook(jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------- RLS

alter table app.household       enable row level security;
alter table app.profile         enable row level security;
alter table app.device          enable row level security;
alter table app.enrolment_code  enable row level security;
alter table app.setup_token     enable row level security;
alter table app.audit_log       enable row level security;
alter table app.household       force row level security;
alter table app.profile         force row level security;
alter table app.device          force row level security;
alter table app.enrolment_code  force row level security;
alter table app.setup_token     force row level security;
alter table app.audit_log       force row level security;

create policy household_read on app.household for select to authenticated
  using (id = app.jwt_household() and app.device_ok());
create policy profile_read on app.profile for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy device_read on app.device for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy audit_read on app.audit_log for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());

-- The definer functions run as their owner; policies for the owner role keep FORCE
-- from locking the functions out of their own tables.
create policy owner_all on app.household      to postgres using (true) with check (true);
create policy owner_all on app.profile        to postgres using (true) with check (true);
create policy owner_all on app.device         to postgres using (true) with check (true);
create policy owner_all on app.enrolment_code to postgres using (true) with check (true);
create policy owner_all on app.setup_token    to postgres using (true) with check (true);
create policy owner_all on app.audit_log      to postgres using (true) with check (true);

-- The hook reads devices as the Auth service role.
create policy auth_admin_read on app.device for select to supabase_auth_admin using (true);
grant select on app.device to supabase_auth_admin;

-- Clients read through api views, which run as the caller; no one gets write grants.
grant usage on schema app to authenticated;
grant select on app.household, app.device, app.audit_log to authenticated;
grant select (id, household_id, display_name, color, role, active) on app.profile to authenticated;
revoke all on app.audit_log from public;

-- ---------------------------------------------------------------- api: reads

create view api.members with (security_invoker = true) as
  select id, household_id, display_name, color, role, active from app.profile;

create view api.devices with (security_invoker = true) as
  select id, household_id, label, class, register, profile_id, last_seen_at, revoked_at, created_at
    from app.device;

create view api.audit_log with (security_invoker = true) as
  select id, occurred_at, actor_profile_id, device_id, origin, entity_type, entity_id, action, diff
    from app.audit_log;

grant select on api.members, api.devices to authenticated;
grant select (id, household_id, label, class, register, profile_id, last_seen_at, revoked_at, created_at)
  on app.device to authenticated;
grant select on api.audit_log to authenticated;

-- The calling device and its bound profile, looked up by Auth user rather than by JWT
-- claim so it works on the very first call after enrolment. Null when not enrolled.
create function api.current_device() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'device_id',    d.id,
    'household_id', d.household_id,
    'label',        d.label,
    'class',        d.class,
    'register',     d.register,
    'profile_id',   d.profile_id,
    'revoked',      d.revoked_at is not null,
    'guardian_verified_until', d.guardian_verified_until)
  from app.device d
  where d.auth_user_id = auth.uid()
$$;

-- ---------------------------------------------------------------- api: setup

create function api.setup_household(
  p_token text, p_household_name text, p_email text, p_password text,
  p_display_name text, p_color text, p_pin text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_hash text := encode(extensions.digest(p_token, 'sha256'), 'hex');
  v_hh   uuid;
  v_user uuid;
  v_prof uuid;
  v_dev  uuid;
begin
  lock table app.household in exclusive mode;
  if exists (select 1 from app.household) then
    raise exception 'already set up' using errcode = '42501', hint = 'setup_closed';
  end if;
  if not exists (select 1 from app.setup_token where token_hash = v_hash and consumed_at is null) then
    raise exception 'invalid setup token' using errcode = '42501', hint = 'setup_token_invalid';
  end if;
  if length(coalesce(p_password, '')) < 10 then
    raise exception 'password too short' using errcode = '22023', hint = 'password_too_short';
  end if;
  if p_pin !~ '^[0-9]{6}$' then
    raise exception 'PIN must be 6 digits' using errcode = '22023', hint = 'pin_format';
  end if;

  insert into app.household (name) values (p_household_name) returning id into v_hh;
  v_user := app.create_auth_user(p_email, p_password);
  insert into app.profile (household_id, display_name, color, role, auth_user_id, pin_hash)
  values (v_hh, p_display_name, coalesce(p_color, '#2E7D6B'), 'guardian', v_user,
          extensions.crypt(p_pin, extensions.gen_salt('bf')))
  returning id into v_prof;
  insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  values (v_hh, v_user, 'Erstes Gerät', 'personal', 'adult', v_prof)
  returning id into v_dev;
  update app.setup_token set consumed_at = now() where token_hash = v_hash;

  insert into app.audit_log (household_id, actor_profile_id, device_id, entity_type, entity_id, action)
  values (v_hh, v_prof, v_dev, 'household', v_hh, 'setup');
  return jsonb_build_object('household_id', v_hh, 'profile_id', v_prof);
end $$;

-- ---------------------------------------------------------------- api: members

create function api.members_add(p_actor uuid, p_display_name text, p_color text, p_role text default 'member')
returns uuid language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_id uuid;
begin
  perform app.require_guardian(a);
  if p_role <> 'member' then
    raise exception 'only members can be added here' using errcode = '22023', hint = 'role_invalid';
  end if;
  insert into app.profile (household_id, display_name, color, role)
  values (a.household_id, p_display_name, coalesce(p_color, '#2E7D6B'), 'member')
  returning id into v_id;
  perform app.audit(a, 'profile', v_id, 'create', jsonb_build_object('display_name', p_display_name));
  return v_id;
end $$;

-- ---------------------------------------------------------------- api: devices

create function api.devices_create_enrolment_code(
  p_actor uuid, p_label text, p_class text, p_register text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.actor(p_actor);
  v_alpha  constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- no 0/O/1/I
  v_code   text := '';
  v_expiry timestamptz := now() + interval '10 minutes';
begin
  perform app.require_guardian(a);
  for i in 1..8 loop
    v_code := v_code || substr(v_alpha, 1 + floor(random() * length(v_alpha))::int, 1);
  end loop;
  insert into app.enrolment_code (household_id, code_hash, label, class, register, created_by, expires_at)
  values (a.household_id, encode(extensions.digest(v_code, 'sha256'), 'hex'),
          p_label, p_class, p_register, a.profile_id, v_expiry);
  perform app.audit(a, 'enrolment_code', null, 'create', jsonb_build_object('label', p_label, 'class', p_class));
  return jsonb_build_object('code', v_code, 'expires_at', v_expiry);
end $$;

-- Consumes a code and returns throwaway credentials for the new device's Auth user.
-- The client signs in once and keeps only the session; it never stores the password.
create function api.enrol_device(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_code app.enrolment_code;
  v_pw   text := encode(extensions.gen_random_bytes(24), 'hex');
  v_id   uuid := gen_random_uuid();
  v_mail text;
  v_user uuid;
begin
  select * into v_code from app.enrolment_code
   where code_hash = encode(extensions.digest(upper(btrim(p_code)), 'sha256'), 'hex')
     and consumed_at is null and expires_at > now()
   for update;
  if not found then
    raise exception 'invalid or expired code' using errcode = '42501', hint = 'code_invalid';
  end if;

  v_mail := 'device-' || v_id || '@devices.wuselwall.invalid';
  v_user := app.create_auth_user(v_mail, v_pw, jsonb_build_object('device', true));
  insert into app.device (id, household_id, auth_user_id, label, class, register)
  values (v_id, v_code.household_id, v_user, v_code.label, v_code.class, v_code.register);
  update app.enrolment_code set consumed_at = now() where id = v_code.id;
  insert into app.audit_log (household_id, actor_profile_id, device_id, entity_type, entity_id, action)
  values (v_code.household_id, v_code.created_by, v_id, 'device', v_id, 'enrol');
  return jsonb_build_object('email', v_mail, 'password', v_pw);
end $$;

create function api.devices_revoke(p_actor uuid, p_device uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_dev app.device;
begin
  perform app.require_guardian(a);
  select * into v_dev from app.device where id = p_device and household_id = a.household_id;
  if not found then
    raise exception 'device not found' using errcode = 'P0002', hint = 'device_not_found';
  end if;
  update app.device set revoked_at = now() where id = p_device;
  -- Kill every session so the refresh token stops working immediately.
  delete from auth.sessions where user_id = v_dev.auth_user_id;
  perform app.audit(a, 'device', p_device, 'revoke');
end $$;

-- ---------------------------------------------------------------- api: guardian PIN

-- Returns a result instead of raising on a wrong PIN: a raise would roll back the
-- failure counter and make the lockout meaningless.
create function api.guardian_verify_pin(p_profile uuid, p_pin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_dev  app.device;
  v_prof app.profile;
  v_fail int;
begin
  select * into v_dev from app.device
   where id = app.jwt_device() and household_id = app.jwt_household() and revoked_at is null;
  if not found then
    raise exception 'device not usable' using errcode = '42501', hint = 'device_revoked';
  end if;
  select * into v_prof from app.profile
   where id = p_profile and household_id = v_dev.household_id and role = 'guardian' and active;
  if not found or v_prof.pin_hash is null then
    return jsonb_build_object('ok', false, 'reason', 'pin_invalid');
  end if;
  if v_prof.pin_locked_until is not null and v_prof.pin_locked_until > now() then
    return jsonb_build_object('ok', false, 'reason',
      case when v_prof.pin_locked_until = 'infinity' then 'pin_locked' else 'pin_backoff' end,
      'retry_at', case when v_prof.pin_locked_until = 'infinity' then null else v_prof.pin_locked_until end);
  end if;

  if extensions.crypt(p_pin, v_prof.pin_hash) = v_prof.pin_hash then
    update app.profile set pin_failures = 0, pin_locked_until = null where id = v_prof.id;
    update app.device set guardian_verified_until = now() + interval '15 minutes'
     where id = v_dev.id returning guardian_verified_until into v_dev.guardian_verified_until;
    insert into app.audit_log (household_id, actor_profile_id, device_id, entity_type, entity_id, action)
    values (v_dev.household_id, v_prof.id, v_dev.id, 'profile', v_prof.id, 'pin_verified');
    return jsonb_build_object('ok', true, 'verified_until', v_dev.guardian_verified_until);
  end if;

  v_fail := v_prof.pin_failures + 1;
  update app.profile set
    pin_failures = v_fail,
    pin_locked_until = case
      when v_fail >= 10 then 'infinity'::timestamptz               -- hard lock
      when v_fail >= 3  then now() + make_interval(secs => 5 * power(2, v_fail - 3))
    end
   where id = v_prof.id;
  insert into app.audit_log (household_id, actor_profile_id, device_id, entity_type, entity_id, action, diff)
  values (v_dev.household_id, v_prof.id, v_dev.id, 'profile', v_prof.id, 'pin_failed',
          jsonb_build_object('failures', v_fail));
  return jsonb_build_object('ok', false, 'reason', 'pin_invalid', 'attempts_left', greatest(10 - v_fail, 0));
end $$;

-- ---------------------------------------------------------------- grants

revoke execute on all functions in schema api from public, anon, authenticated;
grant execute on function api.health() to anon, authenticated;
grant execute on function api.setup_household(text, text, text, text, text, text, text) to anon;
grant execute on function api.enrol_device(text) to anon;
grant execute on function api.current_device() to authenticated;
grant execute on function api.members_add(uuid, text, text, text) to authenticated;
grant execute on function api.devices_create_enrolment_code(uuid, text, text, text) to authenticated;
grant execute on function api.devices_revoke(uuid, uuid) to authenticated;
grant execute on function api.guardian_verify_pin(uuid, text) to authenticated;

revoke execute on all functions in schema app from public, anon, authenticated;
grant execute on function app.jwt_household(), app.jwt_device(), app.device_ok() to authenticated;
