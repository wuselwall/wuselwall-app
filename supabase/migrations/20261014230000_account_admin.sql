-- C1 Account administration (specs/20 "J6 — Leave" Konto löschen, "J4 — Come back" second
-- factor, "Server side"; specs/16 step 9.6, Auth part). Additive for api_version: new tables
-- and functions. household_delete changes only in its internals (the closing moved into
-- app.household_close, unchanged in behaviour), and keeps its signature and grants.
--
-- Outbound HTTP (Apple's revoke and token endpoints, the Auth Admin API) is never in SQL. The
-- Edge Functions account-delete, apple-token and mfa-reset do that work. The functions here
-- decide who may act, and are the only place that writes the rows.

-- ------------------------------------------------------------ Apple refresh tokens

-- Apple's refresh token of an account that signed in with Apple (specs/20, "Server side").
-- Encrypted by apple-token (AES-GCM, key in APPLE_TOKEN_KEY); the database never sees the key.
-- Written and read only by service-role functions: no grants to anon or authenticated.
create table app.apple_token (
  user_id           uuid primary key references auth.users on delete cascade,
  refresh_token_enc text not null check (length(refresh_token_enc) > 0),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
alter table app.apple_token enable row level security;
alter table app.apple_token force row level security;
create policy owner_all on app.apple_token to postgres using (true) with check (true);
revoke all on app.apple_token from public, anon, authenticated;

-- ------------------------------------------------------------ closing a family (shared)

-- Marks a family deleted and closes every door at once. Used by household_delete and by
-- account_delete_prepare when the account's profile was the family's only one. Returns the
-- moment of deletion. The 14-day window and the purge are in the leave migration.
create function app.household_close(p_household uuid) returns timestamptz
language plpgsql security definer set search_path = '' as $$
declare
  v_at timestamptz;
begin
  update app.household set deleted_at = now() where id = p_household returning deleted_at into v_at;

  -- Everyone is signed out: the sessions of phones, and of shared and kiosk device users.
  delete from auth.sessions s
   where s.id in (select d.auth_session_id from app.device d
                   where d.household_id = p_household and d.auth_session_id is not null)
      or s.user_id in (select d.auth_user_id from app.device d
                        where d.household_id = p_household and d.class <> 'personal');
  update app.device set revoked_at = coalesce(revoked_at, now()) where household_id = p_household;

  update app.enrolment_code set consumed_at = now()
   where household_id = p_household and consumed_at is null;
  update app.calendar_feed_token set revoked_at = now()
   where household_id = p_household and revoked_at is null;
  update app.pairing_request set status = 'claimed', claimed_at = coalesce(claimed_at, now())
   where household_id = p_household and status <> 'claimed';
  return v_at;
end $$;

-- Same behaviour as in 20261014220000_leave.sql; the closing is now app.household_close.
create or replace function api.household_delete(p_actor uuid, p_confirm_name text) returns jsonb
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

  v_at := app.household_close(a.household_id);

  perform app.audit(a, 'household', a.household_id, 'delete',
                    jsonb_build_object('purge_after', v_at + app.household_retention()));
  return jsonb_build_object('ok', true, 'purge_after', v_at + app.household_retention());
end $$;

-- ------------------------------------------------------------ Apple token store (service role)

-- Stores (or replaces) the encrypted refresh token of an account. Called by apple-token after
-- it verified the caller's JWT.
create function api.apple_token_put(p_user uuid, p_enc text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  if coalesce(p_enc, '') = '' then
    raise exception 'token missing' using errcode = '22023', hint = 'apple_token_invalid';
  end if;
  insert into app.apple_token (user_id, refresh_token_enc)
  values (p_user, p_enc)
  on conflict (user_id) do update
    set refresh_token_enc = excluded.refresh_token_enc, updated_at = now();
end $$;

-- The encrypted refresh token of an account, or null. Called by account-delete.
create function api.apple_token_get(p_user uuid) returns text
language plpgsql stable security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  return (select t.refresh_token_enc from app.apple_token t where t.user_id = p_user);
end $$;

-- ------------------------------------------------------------ account deletion (service role)

-- Called by account-delete with the Auth user the Edge Function verified from the caller's
-- JWT (and only that user). Decides whether the account may go, and if so unlinks its profile
-- and revokes its devices. The profile stays in the family with its history, as a member
-- without an account (specs/20 J6). Refusals are returned, not raised.
--   reason 'last_guardian': the last guardian with an account in a live family that has other
--                           active members (they delete the family or hand over first);
--   reason 'device_account': the user is a shared or kiosk tablet, never an adult account.
-- When the profile was the family's only active profile, the family is marked deleted, as
-- household_delete does, so the purge removes it.
create function api.account_delete_prepare(p_user uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_prof              app.profile;
  v_hh                app.household;
  v_others            int;
  v_guardians         int;
  v_at                timestamptz;
  v_household_deleted boolean := false;
  a                   app.actor_t;
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  if p_user is null then
    raise exception 'user required' using errcode = '22023', hint = 'user_required';
  end if;
  if exists (select 1 from app.device where auth_user_id = p_user and class <> 'personal') then
    return jsonb_build_object('ok', false, 'reason', 'device_account');
  end if;

  select * into v_prof from app.profile where auth_user_id = p_user and active for update;
  if not found then
    -- A bare account (no family yet, or one whose profile was removed): nothing to unlink.
    update app.device set revoked_at = coalesce(revoked_at, now())
     where auth_user_id = p_user and revoked_at is null;
    return jsonb_build_object('ok', true, 'household_deleted', false);
  end if;

  select * into v_hh from app.household where id = v_prof.household_id for update;
  select count(*) into v_others from app.profile
   where household_id = v_prof.household_id and active and id <> v_prof.id;
  select count(*) into v_guardians from app.profile
   where household_id = v_prof.household_id and active and id <> v_prof.id
     and role = 'guardian' and auth_user_id is not null;

  if v_hh.deleted_at is null and v_prof.role = 'guardian' and v_others > 0 and v_guardians = 0 then
    return jsonb_build_object('ok', false, 'reason', 'last_guardian');
  end if;

  a := row(v_prof.household_id, v_prof.id, v_prof.role, null::uuid, 'personal', 'ui',
           null::timestamptz, null::uuid)::app.actor_t;

  update app.device set revoked_at = coalesce(revoked_at, now())
   where auth_user_id = p_user and revoked_at is null;
  update app.profile set auth_user_id = null where id = v_prof.id;

  if v_hh.deleted_at is null and v_others = 0 then
    v_at := app.household_close(v_prof.household_id);
    v_household_deleted := true;
  end if;

  perform app.audit(a, 'profile', v_prof.id, 'account_delete',
                    jsonb_build_object('household_deleted', v_household_deleted));
  return jsonb_build_object('ok', true, 'household_deleted', v_household_deleted);
end $$;

-- ------------------------------------------------------------ second factor reset (guardian)

-- A guardian on a personal device asks to reset another guardian's authenticator. The target
-- must be an active guardian of the same family with an account, and not the caller. Runs as
-- the caller: the SQL decides, and mfa-reset then removes the factors with the Admin API,
-- acting only on the user returned here.
create function api.mfa_reset_check(p_actor uuid, p_profile uuid) returns jsonb
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

  perform app.audit(a, 'profile', v_target.id, 'mfa_reset');
  return jsonb_build_object('ok', true, 'user_id', v_target.auth_user_id, 'profile_id', v_target.id);
end $$;

-- ------------------------------------------------------------ who has a second factor (guardian)

-- The household's adults, for Mitglieder: whether each has an account and a verified
-- authenticator (TOTP). Reads Auth's factor table, so it is security definer, and returns
-- booleans only.
create function api.member_security(p_actor uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
begin
  perform app.require_guardian(a);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'profile_id', p.id,
             'has_account', p.auth_user_id is not null,
             'has_mfa', exists (select 1 from auth.mfa_factors f
                                 where f.user_id = p.auth_user_id
                                   and f.status = 'verified' and f.factor_type = 'totp'))
           order by p.created_at, p.id)
      from app.profile p
     where p.household_id = a.household_id and p.active and p.kind = 'adult'), '[]'::jsonb);
end $$;

-- ------------------------------------------------------------ grants

revoke execute on function app.household_close(uuid) from public, anon, authenticated;

revoke execute on function api.apple_token_put(uuid, text), api.apple_token_get(uuid),
  api.account_delete_prepare(uuid) from public, anon, authenticated;
grant execute on function api.apple_token_put(uuid, text), api.apple_token_get(uuid),
  api.account_delete_prepare(uuid) to service_role;

revoke execute on function api.mfa_reset_check(uuid, uuid), api.member_security(uuid) from public, anon;
grant execute on function api.mfa_reset_check(uuid, uuid), api.member_security(uuid) to authenticated;
