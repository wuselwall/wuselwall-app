-- J6 Leave (specs/20 "J6 — Leave", specs/16 step 9.6): an adult leaves a family, a guardian
-- deletes it, a deleted family can be restored for 14 days and is then purged. Additive for
-- api_version: new functions, and create-or-replace of the functions below with the same
-- signatures and grants (their behaviour is unchanged except for deleted households).
--
-- A deleted household is closed at every door at once: no household claims in the access
-- token (the hook), no device (device_ok, actor), no enrolment code, feed token or pairing
-- request. The 14 days are a retention window, after which household_purge_due removes the
-- household and the Auth users of its shared and kiosk devices (never adult accounts).

-- ------------------------------------------------------------ retention and session helpers

create function app.household_retention() returns interval
language sql immutable set search_path = '' as $$
  -- Exact hours, not calendar days: a purge date must not move with a clock change.
  select interval '336 hours'
$$;

-- The caller's Auth session, checked to exist for the caller. Raises when not.
create function app.caller_session() returns uuid
language plpgsql stable set search_path = '' as $$
declare
  v_user    uuid := auth.uid();
  v_session uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '42501', hint = 'auth_required';
  end if;
  if v_session is null or not exists (select 1 from auth.sessions where id = v_session and user_id = v_user) then
    raise exception 'no session' using errcode = '42501', hint = 'session_invalid';
  end if;
  return v_session;
end $$;

-- ------------------------------------------------------------ closed doors for a deleted household

-- Every RLS policy that reads through device_ok sees nothing once the household is deleted,
-- even for a device row that somehow still is not revoked.
create or replace function app.device_ok() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from app.device d
      join app.household h on h.id = d.household_id and h.deleted_at is null
    where d.id = app.jwt_device()
      and d.household_id = app.jwt_household()
      and d.revoked_at is null
  )
$$;

-- First line of every api write function. A deleted household refuses first, with its own hint.
create or replace function app.actor(p_profile uuid default null) returns app.actor_t
language plpgsql stable security definer set search_path = '' as $$
declare
  v_dev  app.device;
  v_prof app.profile;
begin
  if exists (select 1 from app.household h
              where h.id = app.jwt_household() and h.deleted_at is not null) then
    raise exception 'household deleted' using errcode = '42501', hint = 'household_deleted';
  end if;

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

-- The token hook gives household claims only for a device of a live household. A deleted
-- household's devices are revoked anyway; this is the narrow place that also says so.
create or replace function app.custom_access_token_hook(event jsonb) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_user    uuid := (event ->> 'user_id')::uuid;
  v_session uuid := nullif(event -> 'claims' ->> 'session_id', '')::uuid;
  v_aal     text := coalesce(event -> 'claims' ->> 'aal', 'aal1');
  v_dev     app.device;
  claims    jsonb := event -> 'claims';
begin
  select d.* into v_dev from app.device d
    join app.household h on h.id = d.household_id and h.deleted_at is null
   where d.auth_user_id = v_user and d.revoked_at is null
     and (d.auth_session_id is null or d.auth_session_id = v_session)
   order by d.auth_session_id nulls last limit 1;

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

-- ------------------------------------------------------------ account: my_account

-- Adds deleted_household for an account whose adult profile sits in a deleted household. Such
-- an account has no household for the app (has_household false, household_id null) until it
-- restores the family or starts afresh.
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

-- ------------------------------------------------------------ account: household_create

-- Same as before, with one change: a phone's row from an earlier family (revoked after
-- leaving) does not count as being in a household. Device users still do, revoked or not.
create or replace function api.household_create(
  p_name text, p_display_name text, p_color text, p_timezone text, p_locale text,
  p_founder_code text, p_seed_examples boolean, p_device_label text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user    uuid := auth.uid();
  v_session uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  v_headers text := current_setting('request.headers', true);
  v_key     text := coalesce(nullif(split_part(coalesce(v_headers::json ->> 'x-forwarded-for', ''), ',', 1), ''), 'unknown');
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

  -- The founder code. Only a guess counts against the client: a missing code is not one.
  if v_mode = 'code' then
    if coalesce(btrim(p_founder_code), '') = '' then
      return jsonb_build_object('ok', false, 'reason', 'founder_code_required');
    end if;
    -- 5 failures per client and 50 overall per 10 minutes. The overall limit keeps a
    -- guessing stranger from ever reaching a code: it also refuses the honest founder.
    if (select count(*) from app.founder_attempt
         where client_key = v_key and not success and attempted_at > now() - interval '10 minutes') >= 5
       or (select count(*) from app.founder_attempt
            where not success and attempted_at > now() - interval '10 minutes') >= 50 then
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

-- ------------------------------------------------------------ account: leave a family

-- An adult with an account (a guardian or an adult member) leaves on a personal device. The
-- profile stays in the family with its history, without an account; the account's devices are
-- revoked. The session is kept: the account can start or join another family at once.
create function api.account_leave(p_actor uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_profile app.profile;
  v_others  int;
  v_guardians_with_account int;
begin
  if a.device_class <> 'personal' then
    raise exception 'personal device required' using errcode = '42501', hint = 'personal_device_required';
  end if;
  select * into v_profile from app.profile
   where id = a.profile_id and auth_user_id = auth.uid() for update;
  if not found then
    raise exception 'no account on this profile' using errcode = '42501', hint = 'account_not_linked';
  end if;
  if v_profile.kind <> 'adult' then
    raise exception 'only adults have an account' using errcode = '42501', hint = 'adult_required';
  end if;

  select count(*) into v_others from app.profile
   where household_id = a.household_id and active and id <> a.profile_id;
  select count(*) into v_guardians_with_account from app.profile
   where household_id = a.household_id and active and id <> a.profile_id
     and role = 'guardian' and auth_user_id is not null;
  if a.profile_role = 'guardian' and v_others > 0 and v_guardians_with_account = 0 then
    raise exception 'last guardian with an account' using errcode = '42501', hint = 'last_guardian';
  end if;

  update app.profile set auth_user_id = null where id = a.profile_id;
  update app.device set revoked_at = now()
   where auth_user_id = auth.uid() and revoked_at is null;
  perform app.audit(a, 'profile', a.profile_id, 'leave');
  return jsonb_build_object('ok', true);
end $$;

-- An account whose adult profile sits in a deleted family unlinks itself from it, to start
-- afresh. Any family member may do this; the deleted family's own rows stay as they are.
create function api.account_leave_deleted() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_user    uuid := auth.uid();
  v_profile app.profile;
begin
  perform app.caller_session();
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

-- ------------------------------------------------------------ household: delete

-- A guardian on a personal device deletes the family: the typed name must match. Every device
-- is revoked and every session of the family ends, and the household is marked deleted. The
-- family's codes, pairing requests and feed tokens are closed too.
create function api.household_delete(p_actor uuid, p_confirm_name text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v_hh   app.household;
  v_at   timestamptz;
begin
  if a.device_class <> 'personal' then
    raise exception 'personal device required' using errcode = '42501', hint = 'personal_device_required';
  end if;
  perform app.require_guardian(a);

  select * into v_hh from app.household where id = a.household_id for update;
  if lower(btrim(coalesce(p_confirm_name, ''))) is distinct from lower(btrim(v_hh.name)) then
    raise exception 'family name does not match' using errcode = '22023', hint = 'confirm_name_mismatch';
  end if;

  update app.household set deleted_at = now() where id = a.household_id returning deleted_at into v_at;

  -- Everyone is signed out: the sessions of phones, and of shared and kiosk device users.
  delete from auth.sessions s
   where s.id in (select d.auth_session_id from app.device d
                   where d.household_id = a.household_id and d.auth_session_id is not null)
      or s.user_id in (select d.auth_user_id from app.device d
                        where d.household_id = a.household_id and d.class <> 'personal');
  update app.device set revoked_at = coalesce(revoked_at, now()) where household_id = a.household_id;

  update app.enrolment_code set consumed_at = now()
   where household_id = a.household_id and consumed_at is null;
  update app.calendar_feed_token set revoked_at = now()
   where household_id = a.household_id and revoked_at is null;
  update app.pairing_request set status = 'claimed', claimed_at = coalesce(claimed_at, now())
   where household_id = a.household_id and status <> 'claimed';

  perform app.audit(a, 'household', a.household_id, 'delete',
                    jsonb_build_object('purge_after', v_at + app.household_retention()));
  return jsonb_build_object('ok', true, 'purge_after', v_at + app.household_retention());
end $$;

-- A guardian of a deleted family restores it, within the retention window, on this session:
-- the family is live again and this session is its personal device. Other devices stay revoked.
create function api.household_restore() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_user    uuid := auth.uid();
  v_session uuid := app.caller_session();
  v_profile app.profile;
  v_hh      app.household;
  v_label   text;
  v_dev     uuid;
begin
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

-- ------------------------------------------------------------ household: purge (job)

-- Called by the household-purge Edge Function once a day, with the service role. Removes the
-- households deleted more than 14 days ago (their rows cascade) and the Auth users of their
-- shared and kiosk devices. Adult accounts are never deleted here: they may belong to another
-- family by now.
create function api.household_purge_due() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_hh       uuid[];
  v_users    uuid[];
  v_families int := 0;
  v_accounts int := 0;
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;

  select coalesce(array_agg(h.id), '{}') into v_hh from app.household h
   where h.deleted_at is not null and h.deleted_at + app.household_retention() <= now();
  if cardinality(v_hh) = 0 then
    return jsonb_build_object('households', 0, 'device_accounts', 0);
  end if;

  select coalesce(array_agg(distinct d.auth_user_id), '{}') into v_users from app.device d
   where d.household_id = any(v_hh) and d.class <> 'personal' and d.auth_user_id is not null;

  delete from app.household where id = any(v_hh);
  get diagnostics v_families = row_count;

  -- Device accounts only: the address is the one app.enrol_device gives them.
  delete from auth.users u
   where u.id = any(v_users) and u.email like 'device-%@devices.wuselwall.invalid';
  get diagnostics v_accounts = row_count;

  return jsonb_build_object('households', v_families, 'device_accounts', v_accounts);
end $$;

-- A revoked phone row keeps its session. A left account that starts or restores a family on
-- the same session needs a new live row for it, so the session is unique among live rows only.
drop index app.device_session_unique;
create unique index device_session_unique on app.device (auth_session_id)
  where auth_session_id is not null and revoked_at is null;

-- A guardian's profile in a live family: a deleted family's profile is not a profile for the
-- app (its account gets the restore or fresh-start screen instead).
create or replace function api.my_profile() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('profile_id', p.id, 'display_name', p.display_name, 'role', p.role)
    from app.profile p
    join app.household h on h.id = p.household_id and h.deleted_at is null
   where p.auth_user_id = auth.uid() and p.active
$$;

-- The caller's device on this session. A live row wins over a revoked one left by a leave or
-- a deletion, so a family started again on the same session shows its new device.
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
  order by (d.revoked_at is null) desc, d.auth_session_id nulls last
  limit 1
$$;

-- The session's personal row is registered once while live. Same body as before; the conflict
-- target follows the live-only session index above.
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

-- ------------------------------------------------------------ grants

revoke execute on function app.household_retention(), app.caller_session()
  from public, anon, authenticated;

revoke execute on function api.account_leave(uuid), api.account_leave_deleted(),
  api.household_delete(uuid, text), api.household_restore(), api.household_purge_due()
  from public, anon;
grant execute on function api.account_leave(uuid), api.account_leave_deleted(),
  api.household_delete(uuid, text), api.household_restore() to authenticated;
-- Service role only (the job); the app and anon never reach it.
revoke execute on function api.household_purge_due() from authenticated;
grant execute on function api.household_purge_due() to service_role;
