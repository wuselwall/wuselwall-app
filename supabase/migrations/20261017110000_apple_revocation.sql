-- Apple revocation obligations (specs/22 "Credential and external-client retirement", item 6).
--
-- Before this, account-delete read an account's stored Apple refresh token, deleted the Auth
-- user (which removed the token row by cascade) and only then asked Apple to revoke it. A
-- missing configuration, a decryption failure or Apple being unreachable lost the last copy
-- of the token, and with it any chance to revoke it later.
--
-- Now a token never disappears without leaving an obligation: whenever a row leaves
-- app.apple_token (an account deleted by account-delete, by an administrator in Studio, or
-- any other way), a trigger copies it into app.apple_revocation in the same transaction.
-- account-delete tries the revocation right after the deletion; the daily household-purge job
-- retries what is still open. A row goes only when Apple accepted the revocation, or when an
-- operator removes it by hand after resolving it (specs/10, "Retiring social sign-in").
-- Account deletion never waits for Apple.
--
-- The token stays encrypted (APPLE_TOKEN_KEY, which the database never sees). user_id is the
-- id of the deleted Auth user, kept only so account-delete can try its own obligation at once;
-- it has no foreign key because the user is gone.
--
-- api_version: unchanged. Service-role functions only, not part of the app–server contract.

create table app.apple_revocation (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null,
  refresh_token_enc text not null check (length(refresh_token_enc) > 0),
  created_at        timestamptz not null default now(),
  attempts          integer not null default 0,
  last_attempt_at   timestamptz,
  -- A short reason code (config_missing, decrypt_failed, unreachable, http_503, …); never
  -- a token or a response body.
  last_error        text check (last_error is null or length(last_error) <= 64)
);
create index apple_revocation_user on app.apple_revocation (user_id);
alter table app.apple_revocation enable row level security;
alter table app.apple_revocation force row level security;
create policy owner_all on app.apple_revocation to postgres using (true) with check (true);
revoke all on app.apple_revocation from public, anon, authenticated, service_role;

comment on table app.apple_revocation is
  'Apple refresh tokens (encrypted) of deleted accounts still to be revoked at Apple. Written by '
  'a trigger on app.apple_token; removed only after a successful revocation or by an operator.';

-- Runs as the table owner, so the copy also happens when the delete comes from Auth's cascade.
create function app.apple_token_retain() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into app.apple_revocation (user_id, refresh_token_enc)
  values (old.user_id, old.refresh_token_enc);
  return old;
end $$;
revoke execute on function app.apple_token_retain() from public, anon, authenticated, service_role;

create trigger apple_token_retain after delete on app.apple_token
  for each row execute function app.apple_token_retain();

-- The obligations to try now. With p_user: that deleted account's, whatever their last attempt
-- (account-delete, right after the deletion). Without: every obligation not tried in the last
-- 20 hours, oldest first (the daily job).
create function api.apple_revocation_due(p_user uuid default null, p_limit integer default 50)
returns table (id uuid, refresh_token_enc text, attempts integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  return query
    select r.id, r.refresh_token_enc, r.attempts
      from app.apple_revocation r
     where (p_user is not null and r.user_id = p_user)
        or (p_user is null and (r.last_attempt_at is null
                                or r.last_attempt_at < now() - interval '20 hours'))
     order by r.created_at
     limit greatest(1, least(coalesce(p_limit, 50), 500));
end $$;

-- The outcome of one attempt. p_error null: Apple accepted the revocation, the obligation is
-- met and goes. Otherwise it stays, with the attempt counted and the reason code kept.
create function api.apple_revocation_record(p_id uuid, p_error text default null)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  if p_error is null then
    delete from app.apple_revocation where id = p_id;
  else
    update app.apple_revocation
       set attempts = attempts + 1,
           last_attempt_at = now(),
           last_error = left(p_error, 64)
     where id = p_id;
  end if;
end $$;

revoke execute on function api.apple_revocation_due(uuid, integer),
  api.apple_revocation_record(uuid, text) from public, anon, authenticated;
grant execute on function api.apple_revocation_due(uuid, integer),
  api.apple_revocation_record(uuid, text) to service_role;
