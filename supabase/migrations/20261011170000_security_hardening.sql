-- Security review of 2026-10-11 (specs/19-security-and-architecture-review.md).

-- ------------------------------------------------ 1. enrolment codes from a CSPRNG
-- `random()` is a plain PRNG; a code is a credential. 256 is a multiple of the alphabet
-- size (32), so a byte modulo 32 is unbiased.
create or replace function api.devices_create_enrolment_code(
  p_actor uuid, p_label text, p_class text, p_register text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.actor(p_actor);
  v_alpha  constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- no 0/O/1/I
  v_bytes  bytea := extensions.gen_random_bytes(8);
  v_code   text := '';
  v_expiry timestamptz := now() + interval '10 minutes';
begin
  perform app.require_guardian(a);
  for i in 0..7 loop
    v_code := v_code || substr(v_alpha, 1 + (get_byte(v_bytes, i) % 32), 1);
  end loop;
  insert into app.enrolment_code (household_id, code_hash, label, class, register, created_by, expires_at)
  values (a.household_id, encode(extensions.digest(v_code, 'sha256'), 'hex'),
          p_label, p_class, p_register, a.profile_id, v_expiry);
  perform app.audit(a, 'enrolment_code', null, 'create', jsonb_build_object('label', p_label, 'class', p_class));
  return jsonb_build_object('code', v_code, 'expires_at', v_expiry);
end $$;

-- ------------------------------------------------ 2. bcrypt cost
-- gen_salt('bf') defaults to cost 6; GoTrue uses 10. Device passwords are 48 random hex
-- characters, but a guardian's is chosen by a person. PINs get 12: six digits are only a
-- million guesses, so every doubling of the cost counts if the database ever leaks.
create or replace function app.create_auth_user(p_email text, p_password text, p_meta jsonb default '{}')
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change)
  values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    lower(p_email), extensions.crypt(p_password, extensions.gen_salt('bf', 10)), now(),
    '{"provider":"email","providers":["email"]}', p_meta, now(), now(), '', '', '', '');
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, created_at, updated_at, last_sign_in_at)
  values (gen_random_uuid(), v_id, v_id::text, 'email',
          jsonb_build_object('sub', v_id::text, 'email', lower(p_email), 'email_verified', true),
          now(), now(), now());
  return v_id;
end $$;
revoke execute on function app.create_auth_user(text, text, jsonb) from public, anon, authenticated;

-- ------------------------------------------------ 3. the PIN window belongs to a profile
-- Until now `guardian_verified_until` was device-wide: after a guardian entered the PIN
-- on the shared iPad, any acting profile named in a call during the next 15 minutes
-- counted as verified. The window now records *who* verified.
alter table app.device add column guardian_verified_profile uuid references app.profile on delete set null;
alter type app.actor_t add attribute verified_profile uuid;

create or replace function app.actor(p_profile uuid default null) returns app.actor_t
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
             'ui', v_dev.guardian_verified_until, v_dev.guardian_verified_profile)::app.actor_t;
end $$;

create or replace function app.require_guardian(a app.actor_t) returns void
language plpgsql stable set search_path = '' as $$
begin
  if a.profile_role = 'guardian'
     and (a.device_class = 'personal'
          or (coalesce(a.guardian_verified_until, '-infinity') > now()
              and a.verified_profile = a.profile_id)) then
    return;
  end if;
  raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
end $$;

-- verify_pin: record the profile; compare in constant-ish time is not needed (bcrypt).
create or replace function api.guardian_verify_pin(p_profile uuid, p_pin text) returns jsonb
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
    update app.device set guardian_verified_until = now() + interval '15 minutes',
                          guardian_verified_profile = v_prof.id
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

-- ------------------------------------------------ 4. a way out of the hard lock
-- Ten wrong PINs lock the guardian's PIN for good, and nothing released it: a child at the
-- kiosk could lock every guardian out of step-up. The release is a full sign-in: only a
-- guardian's *own* personal device (password, and TOTP when enrolled) can set a new PIN,
-- which also clears the failure counter and the lock.
create function api.guardian_set_pin(p_actor uuid, p_new_pin text) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class <> 'personal' or a.profile_role <> 'guardian' then
    raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
  end if;
  if p_new_pin !~ '^[0-9]{6}$' then
    raise exception 'PIN must be 6 digits' using errcode = '22023', hint = 'pin_format';
  end if;
  update app.profile set pin_hash = extensions.crypt(p_new_pin, extensions.gen_salt('bf', 12)),
                         pin_failures = 0, pin_locked_until = null
   where id = a.profile_id;
  perform app.audit(a, 'profile', a.profile_id, 'pin_changed');
end $$;

-- setup: the first PIN at the same cost.
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
          extensions.crypt(p_pin, extensions.gen_salt('bf', 12)))
  returning id into v_prof;
  update app.setup_token set consumed_at = now() where token_hash = v_hash;
  insert into app.audit_log (household_id, actor_profile_id, entity_type, entity_id, action)
  values (v_hh, v_prof, 'household', v_hh, 'setup');
  return jsonb_build_object('household_id', v_hh, 'profile_id', v_prof);
end $$;

-- Re-assert the grants of the functions replaced above (CREATE OR REPLACE keeps them, but
-- guardian_set_pin is new): authenticated only, never anon.
revoke execute on function api.guardian_set_pin(uuid, text) from public, anon;
grant execute on function api.guardian_set_pin(uuid, text) to authenticated;
