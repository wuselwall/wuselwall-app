-- Rate limits and the client key (security review 2026-11-01, F5 and F14).
--
-- The anon-callable functions keep brute-force buckets in attempt tables: a bucket per
-- client and one for the whole server. Two things were wrong with them.
--
-- 1. The global buckets counted calls, not failures (pairing_start counted every start and
--    every failed poll, the invitation lookups counted every preview), and their caps were
--    small (50 to 300 in ten minutes). A stranger with the publishable key could keep them
--    full from the internet and so stop pairing, invitations and claims for the family.
--    Now every global bucket counts failures only, the per-client bucket is the primary
--    limit, and each remaining global cap is set where one family never reaches it but a
--    guesser still gets nowhere (the arithmetic is in the comments below). The poll has no
--    global bucket any more: it guesses a 256-bit secret, which no cap needs to protect.
-- 2. The per-client key was the FIRST entry of X-Forwarded-For, which the client writes
--    itself when an operator's reverse proxy appends instead of replacing the header. Now the
--    key comes, in this order, from: X-WuselWall-Client-IP, but only on a stack whose database
--    setting app.client_ip_header names that header (the compose stack's gateway, Envoy, sets
--    it in every request and overwrites what a client sent; the setting is made by the stack,
--    never by a migration, because migrations also run on hosted projects where no gateway
--    sets the header and a client could); then cf-connecting-ip (a hosted project sits behind
--    Cloudflare, which overwrites it); then the LAST public entry of X-Forwarded-For (proxies
--    append, so the end of the list is what proxies wrote and the start is what the client
--    sent); then 'unknown'. An IPv6 key is its /64: one connection usually owns a whole /64,
--    so per-address keys would hand an attacker 2^64 buckets.
--
-- F14: the timetable-scan Edge Function accepted any Auth account. api.timetable_scan_claim
-- gives it a check that the caller is a live device of a household, and ten scans per
-- account in ten minutes.
--
-- api_version: unchanged (1). No released function changes its signature or its answers in
-- the honest case; api.enrol_device is redefined with the same signature; one api function
-- (timetable_scan_claim) and one app table are added.

-- ------------------------------------------------------------ the client key

-- True for an address of a private, loopback, link-local or carrier-grade-NAT range, i.e. one
-- a proxy in front of the gateway would have, never a client on the internet. Anything that
-- is not an address at all is "not public" too.
create function app.public_address(p_address text) returns boolean
language plpgsql immutable set search_path = '' as $$
declare
  v inet;
begin
  begin
    v := btrim(p_address)::inet;
  exception when others then
    return false;
  end;
  return not (v <<= '10.0.0.0/8'::inet or v <<= '172.16.0.0/12'::inet or v <<= '192.168.0.0/16'::inet
           or v <<= '127.0.0.0/8'::inet or v <<= '169.254.0.0/16'::inet or v <<= '100.64.0.0/10'::inet
           or v <<= '0.0.0.0/8'::inet
           or v <<= 'fc00::/7'::inet or v <<= 'fe80::/10'::inet or v <<= '::1/128'::inet
           or v <<= '::/128'::inet);
end $$;
revoke execute on function app.public_address(text) from public, anon, authenticated;

-- The bucket an address counts in: an IPv6 address as its /64 ('2001:db8::/64'), an IPv4
-- address as it is, anything else (not an address) trimmed as it is.
create function app.client_bucket_key(p_address text) returns text
language plpgsql immutable set search_path = '' as $$
declare
  v inet;
begin
  begin
    v := btrim(p_address)::inet;
  exception when others then
    return btrim(p_address);
  end;
  if family(v) = 6 then
    return network(set_masklen(v, 64))::text;
  end if;
  return host(v);
end $$;
revoke execute on function app.client_bucket_key(text) from public, anon, authenticated;

-- The client a request came from, for the per-client buckets (the order and the reasons are
-- in the header of this migration). The database setting app.client_ip_header names the
-- header the stack's own gateway sets; the compose stack sets it with
-- infra/supabase/volumes/wuselwall/client-ip.sql (new databases at their first start, existing
-- ones in the release tool's update). Without it the header is ignored, since a client could
-- have sent it. 'unknown' when nothing is known; then every client shares one bucket.
create or replace function app.request_client_key() returns text
language plpgsql stable set search_path = '' as $$
declare
  v_headers jsonb := coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb);
  v_name    text := nullif(lower(btrim(coalesce(current_setting('app.client_ip_header', true), ''))), '');
  v_direct  text := case when v_name is null then null
                         else nullif(btrim(coalesce(v_headers ->> v_name, '')), '') end;
  v_cf      text := nullif(btrim(coalesce(v_headers ->> 'cf-connecting-ip', '')), '');
  v_entries text[] := regexp_split_to_array(coalesce(v_headers ->> 'x-forwarded-for', ''), ',');
  v_last    text;
begin
  if v_direct is not null then
    return app.client_bucket_key(v_direct);
  end if;
  if v_cf is not null then
    return app.client_bucket_key(v_cf);
  end if;
  for i in reverse coalesce(array_length(v_entries, 1), 0)..1 loop
    if btrim(v_entries[i]) <> '' then
      v_last := coalesce(v_last, btrim(v_entries[i]));
      if app.public_address(v_entries[i]) then
        return app.client_bucket_key(v_entries[i]);
      end if;
    end if;
  end loop;
  return coalesce(app.client_bucket_key(v_last), 'unknown');
end $$;

-- The same key under its older name (pairing, invitations, password resets).
create or replace function app.client_key() returns text
language sql stable set search_path = '' as $$
  select app.request_client_key()
$$;

-- ------------------------------------------------------------ device enrolment (legacy)

-- As in 20261011150000, with the client key from app.client_key() and the global cap raised
-- from 30 to 1000 failures in ten minutes. A code is 8 symbols of 32 (2^40 possibilities) and
-- lives ten minutes: 1000 guesses find it with a chance of 1 in a billion, while 30 failures
-- from anywhere used to stop every enrolment for the family. Filling the global bucket now
-- takes 200 addresses (or IPv6 /64s) failing five times each within ten minutes, and holds
-- for ten minutes.
create or replace function api.enrol_device(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_key     text := app.client_key();
  v_code    app.enrolment_code;
  v_pw      text := encode(extensions.gen_random_bytes(24), 'hex');
  v_id      uuid := gen_random_uuid();
  v_mail    text;
  v_user    uuid;
begin
  -- 5 failures per client and 1000 overall per 10 minutes.
  if (select count(*) from app.enrol_attempt
       where client_key = v_key and not success and attempted_at > now() - interval '10 minutes') >= 5
     or (select count(*) from app.enrol_attempt
          where not success and attempted_at > now() - interval '10 minutes') >= 1000 then
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

-- ------------------------------------------------------------ pairing

-- As in 20261015102000_pairing.sql. A start never fails, so its buckets count starts: 10 per
-- client in ten minutes as before, and 2000 overall (was 200, and that bucket also counted
-- failed polls). The overall cap only bounds the rows a flood can create; a start guesses
-- nothing, the code it hands out is guessed through pairing_approve, which has its own
-- per-guardian limit. One family starts a handful of pairings a day; stopping its starts
-- for ten minutes takes 200 addresses (or IPv6 /64s) starting ten each. Expired requests
-- that nobody collected are dropped after a day, so a flood leaves nothing behind.
create or replace function api.pairing_start() returns jsonb
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
       where client_key = v_key and success and attempted_at > now() - interval '10 minutes') >= 10
     or (select count(*) from app.pairing_attempt
          where client_key like 'pair:%' and success and attempted_at > now() - interval '10 minutes') >= 2000 then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;

  delete from app.pairing_request where status = 'pending' and expires_at < now() - interval '1 day';

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

-- As before, with the buckets changed: failures are logged under 'poll:<client>' (10 in ten
-- minutes per client, as before) and, when the request exists, under 'pollreq:<request id>'
-- (20 in ten minutes), so that one request cannot be guessed at from many addresses. No
-- overall bucket: a poll guesses a 256-bit secret for a request id it would have to guess
-- too, so an overall cap protected nothing and let 200 failures from anywhere stop every
-- device from collecting its credentials.
create or replace function api.pairing_poll(p_request_id uuid, p_secret text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_key  text := 'poll:' || app.client_key();
  v_rkey text := 'pollreq:' || coalesce(p_request_id::text, '');
  v_req  app.pairing_request;
  v_dev  app.device;
  v_mail text;
  v_pw   text := encode(extensions.gen_random_bytes(24), 'hex');
begin
  if (select count(*) from app.pairing_attempt
       where client_key = v_key and not success and attempted_at > now() - interval '10 minutes') >= 10
     or (select count(*) from app.pairing_attempt
          where client_key = v_rkey and not success and attempted_at > now() - interval '10 minutes') >= 20 then
    return jsonb_build_object('status', 'rate_limited');
  end if;

  select * into v_req from app.pairing_request where id = p_request_id for update;
  if not found then
    insert into app.pairing_attempt (client_key, success) values (v_key, false);
    return jsonb_build_object('status', 'invalid');
  end if;
  if v_req.secret_hash <> app.pairing_hash(coalesce(p_secret, '')) then
    insert into app.pairing_attempt (client_key, success) values (v_key, false), (v_rkey, false);
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

-- ------------------------------------------------------------ invitations

-- Failures only: 20 per client and 3000 overall in ten minutes (every call counted before,
-- at 20 and 300, so 300 previews from anywhere stopped previews and accepts for everyone).
-- A code is 8 symbols of 32 (2^40 possibilities) and an invitation lives seven days: at 3000
-- failures per ten minutes a guesser gets 3 million tries in those days, a chance of about
-- 1 in 360 000 per open invitation. Filling the global bucket takes 150 addresses (or IPv6
-- /64s) failing twenty times each within ten minutes, and stops lookups for ten minutes; a
-- family's own failures are a handful. The successful preview a family makes a few times a
-- day is not counted. api.invitation_preview and api.invitation_accept keep calling this.
create or replace function app.invitation_rate_limited(p_client text) returns boolean
language sql stable set search_path = '' as $$
  select (select count(*) from app.invitation_attempt
           where client_key = 'invite:' || p_client and not success
             and attempted_at > now() - interval '10 minutes') >= 20
      or (select count(*) from app.invitation_attempt
           where client_key like 'invite:%' and not success
             and attempted_at > now() - interval '10 minutes') >= 3000
$$;

-- ------------------------------------------------------------ founder codes and the claim

-- 5 failures per client as before; overall 1000 in ten minutes (was 50, which 50 wrong
-- claims from anywhere filled, so the honest founder could be kept from the setup page).
-- A setup key is 96 random bits (`wuselwall setup-token`), beyond any cap; the overall cap
-- is kept for a key an operator chose by hand (144 000 guesses a day at most). Filling it
-- takes 200 addresses (or IPv6 /64s) failing five times each within ten minutes. Successes
-- never count.
create or replace function app.founder_attempts_exceeded(p_client_key text) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select count(*) from app.founder_attempt
           where client_key = p_client_key and not success
             and attempted_at > now() - interval '10 minutes') >= 5
      or (select count(*) from app.founder_attempt
           where not success and attempted_at > now() - interval '10 minutes') >= 1000
$$;

-- ------------------------------------------------------------ the timetable scan (F14)

-- One row per scan an account was allowed, for the per-account limit.
create table app.timetable_scan_attempt (
  id           bigint generated always as identity primary key,
  attempted_at timestamptz not null default now(),
  auth_user_id uuid not null
);
create index on app.timetable_scan_attempt (auth_user_id, attempted_at desc);
alter table app.timetable_scan_attempt enable row level security;
alter table app.timetable_scan_attempt force row level security;
create policy owner_all on app.timetable_scan_attempt to postgres using (true) with check (true);
revoke all on app.timetable_scan_attempt from public, anon, authenticated;

-- Called by the timetable-scan Edge Function, as the caller, before it reads the picture.
-- The caller must be a live device of a household that exists (the household and device
-- claims of its JWT, checked as app.device_ok does); any other account, a household-less
-- one included, is refused with WW-SCH-005. Then at most ten scans per account in ten
-- minutes; the eleventh is a result, not an error. Rows older than a day are dropped.
create function api.timetable_scan_claim() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null or not app.device_ok() then
    raise exception 'WW-SCH-005 household device required' using errcode = '42501', hint = 'device_revoked';
  end if;
  if (select count(*) from app.timetable_scan_attempt
       where auth_user_id = v_user and attempted_at > now() - interval '10 minutes') >= 10 then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  delete from app.timetable_scan_attempt where attempted_at < now() - interval '1 day';
  insert into app.timetable_scan_attempt (auth_user_id) values (v_user);
  return jsonb_build_object('ok', true);
end $$;
revoke execute on function api.timetable_scan_claim() from public, anon;
grant execute on function api.timetable_scan_claim() to authenticated;
