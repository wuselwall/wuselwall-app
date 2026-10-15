-- Pairing (onboarding J3/J5, specs/20 and specs/08 "Device pairing", ADR-014).
-- The new device shows a code and a guardian's personal phone approves it. The display code
-- grants nothing on its own: only the device that holds the request's secret can collect the
-- credentials, and only after an approval by a guardian on a personal device. Secrets and codes
-- are stored as sha256 hashes, like app.enrolment_code.
--
-- Additive for api_version: new table and functions; api.enrol_device stays for one release.

-- ------------------------------------------------------------ table

create table app.pairing_request (
  id                     uuid primary key default gen_random_uuid(),
  secret_hash            text not null,
  code_hash              text not null unique,
  expires_at             timestamptz not null,
  created_at             timestamptz not null default now(),
  client_key             text not null,
  status                 text not null default 'pending'
                         check (status in ('pending', 'approved', 'claimed')),
  household_id           uuid references app.household on delete cascade,
  device_id              uuid references app.device on delete set null,
  auth_user_id           uuid references auth.users on delete set null,
  approved_by_profile_id uuid references app.profile on delete set null,
  approved_at            timestamptz,
  claimed_at             timestamptz,
  check (status = 'pending' or (household_id is not null and auth_user_id is not null and approved_at is not null)),
  check (status <> 'claimed' or claimed_at is not null)
);

alter table app.pairing_request enable row level security;
alter table app.pairing_request force row level security;
create policy owner_all on app.pairing_request to postgres using (true) with check (true);
-- No grants to anon or authenticated: the api functions below are the only way in.
revoke all on app.pairing_request from public, anon, authenticated;

-- Pairing's own attempt log (rate limits for start, poll and approve). Kept apart from
-- app.pairing_attempt: api.enrol_device counts every failure there toward its global limit, so
-- failed pairings must not land in it.
create table app.pairing_attempt (
  id           bigint generated always as identity primary key,
  attempted_at timestamptz not null default now(),
  client_key   text not null,
  success      boolean not null
);
create index on app.pairing_attempt (client_key, attempted_at desc);
alter table app.pairing_attempt enable row level security;
alter table app.pairing_attempt force row level security;
create policy owner_all on app.pairing_attempt to postgres using (true) with check (true);
revoke all on app.pairing_attempt from public, anon, authenticated;

-- ------------------------------------------------------------ internals

create function app.pairing_hash(p_value text) returns text
language sql immutable set search_path = '' as $$
  select encode(extensions.digest(p_value, 'sha256'), 'hex')
$$;

-- The forwarded-for client, as api.enrol_device keys its attempt log.
create function app.client_key() returns text
language sql stable set search_path = '' as $$
  select coalesce(nullif(split_part(coalesce(
           (nullif(current_setting('request.headers', true), '')::json) ->> 'x-forwarded-for', ''), ',', 1), ''),
         'unknown')
$$;

-- Writes the password of an Auth user the way GoTrue does (bcrypt, cost 10 as in
-- app.create_auth_user). Used once per pairing, for the device's throwaway password.
create function app.set_auth_user_password(p_user uuid, p_password text) returns void
language sql security definer set search_path = '' as $$
  update auth.users
     set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf', 10)),
         updated_at = now()
   where id = p_user
$$;

revoke execute on function app.pairing_hash(text), app.client_key(), app.set_auth_user_password(uuid, text)
  from public, anon, authenticated;

-- ------------------------------------------------------------ api: the new device

-- Starts a request. Rate limited per forwarded-for client (10 starts or failures in 10
-- minutes) and overall (200 in 10 minutes); a refusal is a result, not an error.
create function api.pairing_start() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_client  text := app.client_key();
  v_key     text := 'pair:' || v_client;
  v_alpha   constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- no 0/O/1/I
  v_bytes   bytea;
  v_code    text;
  v_secret  text := encode(extensions.gen_random_bytes(32), 'hex');
  v_expires timestamptz := now() + interval '10 minutes';
  v_id      uuid;
begin
  if (select count(*) from app.pairing_attempt
       where client_key = v_key and attempted_at > now() - interval '10 minutes') >= 10
     or (select count(*) from app.pairing_attempt
          where client_key like 'pair:%' and attempted_at > now() - interval '10 minutes') >= 200 then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;

  -- 8 characters from 32 symbols: a byte modulo 32 is unbiased (256 = 8 * 32).
  loop
    v_bytes := extensions.gen_random_bytes(8);
    v_code := '';
    for i in 0..7 loop
      v_code := v_code || substr(v_alpha, 1 + (get_byte(v_bytes, i) % 32), 1);
    end loop;
    exit when not exists (select 1 from app.pairing_request where code_hash = app.pairing_hash(v_code));
  end loop;

  insert into app.pairing_request (secret_hash, code_hash, expires_at, client_key)
  values (app.pairing_hash(v_secret), app.pairing_hash(v_code), v_expires, v_client)
  returning id into v_id;
  insert into app.pairing_attempt (client_key, success) values (v_key, true);

  return jsonb_build_object('ok', true, 'request_id', v_id, 'secret', v_secret,
                            'code', v_code, 'expires_at', v_expires);
end $$;

-- Polled by the new device every few seconds with the secret it was given. The first poll
-- after an approval collects the credentials; a claimed request answers invalid from then on.
create function api.pairing_poll(p_request_id uuid, p_secret text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_key  text := 'pair:' || app.client_key();
  v_req  app.pairing_request;
  v_dev  app.device;
  v_mail text;
  v_pw   text := encode(extensions.gen_random_bytes(24), 'hex');
begin
  if (select count(*) from app.pairing_attempt
       where client_key = v_key and not success and attempted_at > now() - interval '10 minutes') >= 10
     or (select count(*) from app.pairing_attempt
          where client_key like 'pair:%' and not success and attempted_at > now() - interval '10 minutes') >= 200 then
    return jsonb_build_object('status', 'rate_limited');
  end if;

  select * into v_req from app.pairing_request where id = p_request_id for update;
  if not found then
    insert into app.pairing_attempt (client_key, success) values (v_key, false);
    return jsonb_build_object('status', 'invalid');
  end if;
  if v_req.secret_hash <> app.pairing_hash(coalesce(p_secret, '')) then
    insert into app.pairing_attempt (client_key, success) values (v_key, false);
    return jsonb_build_object('status', 'invalid');
  end if;

  if v_req.status = 'pending' then
    return jsonb_build_object('status', case when v_req.expires_at > now() then 'pending' else 'expired' end);
  end if;
  if v_req.status = 'claimed' then
    return jsonb_build_object('status', 'invalid');
  end if;

  -- Approved: the credentials are handed out once, within the request's lifetime.
  if v_req.expires_at <= now() then
    return jsonb_build_object('status', 'expired');
  end if;
  select * into v_dev from app.device where id = v_req.device_id;
  if not found or v_dev.revoked_at is not null then
    return jsonb_build_object('status', 'invalid');
  end if;

  select email into v_mail from auth.users where id = v_req.auth_user_id;
  perform app.set_auth_user_password(v_req.auth_user_id, v_pw);
  update app.pairing_request set status = 'claimed', claimed_at = now() where id = v_req.id;

  return jsonb_build_object(
    'status', 'approved', 'email', v_mail, 'password', v_pw,
    'household_name', (select name from app.household where id = v_req.household_id),
    'class', v_dev.class, 'register', v_dev.register);
end $$;

-- ------------------------------------------------------------ api: the guardian's phone

-- A guardian on a personal device binds a pending request to the household and says what the
-- device is. Kinds: wall_display (kiosk), kid_tablet (shared, kid), family_tablet (shared,
-- adult), child_phone (personal, bound to the child p_profile).
create function api.pairing_approve(p_actor uuid, p_code text, p_label text, p_kind text, p_profile uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  v_code  text := regexp_replace(upper(coalesce(p_code, '')), '[^A-Z0-9]', '', 'g');
  v_label text := btrim(coalesce(p_label, ''));
  v_class text;
  v_reg   text;
  v_bound uuid;
  v_req   app.pairing_request;
  v_dev   uuid := gen_random_uuid();
  v_user  uuid;
  v_mail  text;
begin
  if a.device_class <> 'personal' or a.profile_role <> 'guardian' then
    raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
  end if;
  if length(v_label) < 1 or length(v_label) > 40 then
    raise exception 'label required' using errcode = '22023', hint = 'label_invalid';
  end if;

  case p_kind
    when 'wall_display'   then v_class := 'kiosk';   v_reg := 'kiosk';
    when 'kid_tablet'     then v_class := 'shared';  v_reg := 'kid';
    when 'family_tablet'  then v_class := 'shared';  v_reg := 'adult';
    when 'child_phone'    then v_class := 'personal'; v_reg := 'kid';
    else raise exception 'kind invalid' using errcode = '22023', hint = 'pairing_kind_invalid';
  end case;
  if p_kind = 'child_phone' then
    select id into v_bound from app.profile
     where id = p_profile and household_id = a.household_id and role = 'member' and active;
    if not found then
      raise exception 'child required' using errcode = '22023', hint = 'child_required';
    end if;
  end if;

  -- Five wrong codes per guardian in ten minutes, then refused: a code is 8 symbols.
  if (select count(*) from app.pairing_attempt
       where client_key = 'approve:' || a.profile_id::text and not success
         and attempted_at > now() - interval '10 minutes') >= 5 then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;

  select * into v_req from app.pairing_request
   where code_hash = app.pairing_hash(v_code) and status = 'pending' and expires_at > now()
   for update;
  if not found then
    insert into app.pairing_attempt (client_key, success) values ('approve:' || a.profile_id::text, false);
    return jsonb_build_object('ok', false, 'reason', 'code_invalid');
  end if;

  -- The device's own Auth user; its password is set only when the device collects it.
  v_mail := 'device-' || v_dev || '@devices.wuselwall.invalid';
  v_user := app.create_auth_user(v_mail, encode(extensions.gen_random_bytes(32), 'hex'),
                                 jsonb_build_object('device', true));
  insert into app.device (id, household_id, auth_user_id, label, class, register, profile_id)
  values (v_dev, a.household_id, v_user, v_label, v_class, v_reg, v_bound);

  update app.pairing_request set
    status = 'approved', household_id = a.household_id, device_id = v_dev, auth_user_id = v_user,
    approved_by_profile_id = a.profile_id, approved_at = now()
   where id = v_req.id;

  perform app.audit(a, 'device', v_dev, 'pair',
                    jsonb_build_object('kind', p_kind, 'class', v_class, 'register', v_reg));
  return jsonb_build_object(
    'ok', true, 'device_id', v_dev, 'label', v_label,
    'needs_pin', (select pin_hash is null from app.profile where id = a.profile_id));
end $$;

-- ------------------------------------------------------------ grants

revoke execute on function api.pairing_start(), api.pairing_poll(uuid, text),
  api.pairing_approve(uuid, text, text, text, uuid) from public, anon, authenticated;
grant execute on function api.pairing_start(), api.pairing_poll(uuid, text) to anon, authenticated;
grant execute on function api.pairing_approve(uuid, text, text, text, uuid) to authenticated;
