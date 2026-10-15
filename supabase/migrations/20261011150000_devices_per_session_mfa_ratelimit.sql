-- Hardening of identity (ADR-010 implementation notes):
--  1. enrolment rate limiting
--  2. per-phone personal devices (a device row bound to an Auth *session*)
--  3. TOTP: a guardian with a verified factor gets household claims only at aal2

-- ------------------------------------------------------------ 1. rate limiting

create table app.enrol_attempt (
  id          bigint generated always as identity primary key,
  attempted_at timestamptz not null default now(),
  client_key  text not null,
  success     boolean not null
);
create index on app.enrol_attempt (client_key, attempted_at desc);
alter table app.enrol_attempt enable row level security;
alter table app.enrol_attempt force row level security;
create policy owner_all on app.enrol_attempt to postgres using (true) with check (true);

-- Replaces the raising version: a raise would roll back the attempt log, which is the
-- whole point. Failures are now a result: {ok:false, reason}.
drop function api.enrol_device(text);
create function api.enrol_device(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_headers text := current_setting('request.headers', true);
  v_key     text := coalesce(nullif(split_part(coalesce(v_headers::json ->> 'x-forwarded-for', ''), ',', 1), ''), 'unknown');
  v_code    app.enrolment_code;
  v_pw      text := encode(extensions.gen_random_bytes(24), 'hex');
  v_id      uuid := gen_random_uuid();
  v_mail    text;
  v_user    uuid;
begin
  -- 5 failures per client and 30 overall per 10 minutes. Behind a proxy the client key
  -- is the forwarded address; without one all clients share the bucket "unknown".
  if (select count(*) from app.enrol_attempt
       where client_key = v_key and not success and attempted_at > now() - interval '10 minutes') >= 5
     or (select count(*) from app.enrol_attempt
          where not success and attempted_at > now() - interval '10 minutes') >= 30 then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;

  select * into v_code from app.enrolment_code
   where code_hash = encode(extensions.digest(upper(btrim(p_code)), 'sha256'), 'hex')
     and consumed_at is null and expires_at > now()
   for update;
  if not found then
    insert into app.enrol_attempt (client_key, success) values (v_key, false);
    return jsonb_build_object('ok', false, 'reason', 'code_invalid');
  end if;

  v_mail := 'device-' || v_id || '@devices.wuselwall.invalid';
  v_user := app.create_auth_user(v_mail, v_pw, jsonb_build_object('device', true));
  insert into app.device (id, household_id, auth_user_id, label, class, register)
  values (v_id, v_code.household_id, v_user, v_code.label, v_code.class, v_code.register);
  update app.enrolment_code set consumed_at = now() where id = v_code.id;
  insert into app.enrol_attempt (client_key, success) values (v_key, true);
  insert into app.audit_log (household_id, actor_profile_id, device_id, entity_type, entity_id, action)
  values (v_code.household_id, v_code.created_by, v_id, 'device', v_id, 'enrol');
  return jsonb_build_object('ok', true, 'email', v_mail, 'password', v_pw);
end $$;
grant execute on function api.enrol_device(text) to anon;

-- ------------------------------------------------------------ 2. per-phone devices

alter table app.device add column auth_session_id uuid;
alter table app.device drop constraint device_auth_user_id_key;
-- Shared/kiosk devices own their Auth user; personal devices own an Auth session.
create unique index device_user_owned on app.device (auth_user_id) where auth_session_id is null;
create unique index device_session_unique on app.device (auth_session_id) where auth_session_id is not null;

-- True while a session still exists; lets views hide phones that signed out long ago.
create function app.session_alive(p_session uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select p_session is null or exists (select 1 from auth.sessions s where s.id = p_session)
$$;
grant execute on function app.session_alive(uuid) to authenticated;

create or replace view api.devices with (security_invoker = true) as
  select id, household_id, label, class, register, profile_id, last_seen_at, revoked_at, created_at
    from app.device
   where revoked_at is not null or app.session_alive(auth_session_id);
grant select (auth_session_id) on app.device to authenticated; -- needed by the view's filter

-- Hook: user-owned devices match any session; personal devices only their own. A guardian
-- with a verified TOTP factor gets no household claims until the session is aal2.
create or replace function app.custom_access_token_hook(event jsonb) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_user    uuid := (event ->> 'user_id')::uuid;
  v_session uuid := nullif(event -> 'claims' ->> 'session_id', '')::uuid;
  v_aal     text := coalesce(event -> 'claims' ->> 'aal', 'aal1');
  v_dev     app.device;
  claims    jsonb := event -> 'claims';
begin
  select * into v_dev from app.device
   where auth_user_id = v_user and revoked_at is null
     and (auth_session_id is null or auth_session_id = v_session)
   order by auth_session_id nulls last limit 1;

  if found and not (
       v_aal <> 'aal2' and exists (
         select 1 from auth.mfa_factors f
          where f.user_id = v_user and f.status = 'verified' and f.factor_type = 'totp')
     ) then
    claims := claims || jsonb_build_object(
      'household_id', v_dev.household_id,
      'device_id',    v_dev.id,
      'device_class', v_dev.class,
      'profile_id',   case when v_dev.class = 'personal' then v_dev.profile_id end);
  end if;
  return jsonb_set(event, '{claims}', claims);
end $$;
-- Auth owns auth.mfa_factors, so this grant is a no-op wherever it is refused. A hosted
-- Supabase project may refuse grants on the auth schema to the migration role; the
-- install must not fail on it (ADR-018: any Supabase stack is a WuselWall server).
do $$ begin
  grant select on auth.mfa_factors to supabase_auth_admin;
exception when insufficient_privilege then
  raise notice 'grant on auth.mfa_factors refused; Auth owns the table anyway';
end $$;

-- The caller's device: by session for personal phones, by user for shared/kiosk devices.
create or replace function api.current_device() returns jsonb
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
    and (d.auth_session_id is null
         or d.auth_session_id = nullif(auth.jwt() ->> 'session_id', '')::uuid)
  order by d.auth_session_id nulls last
  limit 1
$$;

-- A signed-in guardian without a device on this session (a new phone, or a fresh sign-in).
create function api.my_profile() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('profile_id', p.id, 'display_name', p.display_name, 'role', p.role)
    from app.profile p where p.auth_user_id = auth.uid() and p.active
$$;

-- Registers *this session* as a personal device. The app refreshes the session afterwards
-- so the new token carries the device claims.
create function api.register_personal_device(p_label text) returns jsonb
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
  if length(btrim(coalesce(p_label, ''))) = 0 then
    raise exception 'label required' using errcode = '22023', hint = 'name_required';
  end if;

  insert into app.device (household_id, auth_user_id, auth_session_id, label, class, register, profile_id)
  values (v_prof.household_id, v_prof.auth_user_id, v_session, btrim(p_label), 'personal', 'adult', v_prof.id)
  on conflict (auth_session_id) where auth_session_id is not null do nothing
  returning id into v_id;
  if v_id is not null then
    insert into app.audit_log (household_id, actor_profile_id, device_id, entity_type, entity_id, action)
    values (v_prof.household_id, v_prof.id, v_id, 'device', v_id, 'register_personal');
  end if;
  return api.current_device();
end $$;

-- Called by a personal phone before it signs out, so the device list stays tidy.
create function api.device_sign_out() returns void
language plpgsql security definer set search_path = '' as $$
begin
  update app.device set revoked_at = now()
   where auth_user_id = auth.uid()
     and auth_session_id = nullif(auth.jwt() ->> 'session_id', '')::uuid
     and revoked_at is null;
end $$;

-- Revocation now ends only the revoked phone's session, not every session of a guardian.
create or replace function api.devices_revoke(p_actor uuid, p_device uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_dev app.device;
begin
  perform app.require_guardian(a);
  select * into v_dev from app.device where id = p_device and household_id = a.household_id;
  if not found then
    raise exception 'device not found' using errcode = 'P0002', hint = 'device_not_found';
  end if;
  update app.device set revoked_at = now() where id = p_device;
  if v_dev.auth_session_id is not null then
    delete from auth.sessions where id = v_dev.auth_session_id;
  else
    delete from auth.sessions where user_id = v_dev.auth_user_id;
  end if;
  perform app.audit(a, 'device', p_device, 'revoke');
end $$;

-- Setup no longer creates a device: the guardian's phone registers itself after signing in.
create or replace function api.setup_household(
  p_token text, p_household_name text, p_email text, p_password text,
  p_display_name text, p_color text, p_pin text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_hash text := encode(extensions.digest(p_token, 'sha256'), 'hex');
  v_hh   uuid;
  v_user uuid;
  v_prof uuid;
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
  update app.setup_token set consumed_at = now() where token_hash = v_hash;
  insert into app.audit_log (household_id, actor_profile_id, entity_type, entity_id, action)
  values (v_hh, v_prof, 'household', v_hh, 'setup');
  return jsonb_build_object('household_id', v_hh, 'profile_id', v_prof);
end $$;
grant execute on function api.setup_household(text, text, text, text, text, text, text) to anon;

revoke execute on all functions in schema api from public;
grant execute on function api.health() to anon, authenticated;
grant execute on function api.setup_household(text, text, text, text, text, text, text) to anon;
grant execute on function api.enrol_device(text) to anon;
grant execute on function api.current_device() to authenticated;
grant execute on function api.my_profile() to authenticated;
grant execute on function api.register_personal_device(text) to authenticated;
grant execute on function api.device_sign_out() to authenticated;
grant execute on function api.members_add(uuid, text, text, text) to authenticated;
grant execute on function api.devices_create_enrolment_code(uuid, text, text, text) to authenticated;
grant execute on function api.devices_revoke(uuid, uuid) to authenticated;
grant execute on function api.guardian_verify_pin(uuid, text) to authenticated;
grant execute on function api.shopping_add_item(uuid, text, text) to authenticated;
grant execute on function api.shopping_toggle_item(uuid, uuid) to authenticated;
grant execute on function api.shopping_finish(uuid) to authenticated;
revoke execute on function api.setup_household(text, text, text, text, text, text, text), api.enrol_device(text) from authenticated;
