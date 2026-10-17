-- Fair daily retries of Apple revocation obligations (specs/22 item 6; follows 20261017110000).
--
-- api.apple_revocation_due ordered the daily batch by created_at alone. With more than one
-- batch (50) of obligations and the oldest 50 failing every day (a token Apple keeps refusing,
-- one that no longer decrypts), each daily run picked the same 50 again and never reached the
-- rest: obligations behind them were never tried at all.
--
-- Now the daily batch takes the obligations that have waited longest since their last attempt:
-- never tried first, then the least recently tried, created_at as the tie-break. A run moves the
-- rows it tried to the back of the queue, so N due obligations are each tried within
-- ceil(N / limit) daily runs, whatever keeps failing. The account-delete path (p_user) is
-- unchanged.
--
-- Same signature and security: service role only, checked inside, grants untouched by
-- create or replace. api_version: unchanged (service-role functions, not the app contract).

create or replace function api.apple_revocation_due(p_user uuid default null, p_limit integer default 50)
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
     order by r.last_attempt_at asc nulls first, r.created_at, r.id
     limit greatest(1, least(coalesce(p_limit, 50), 500));
end $$;

-- Restated for clarity; create or replace keeps the existing privileges.
revoke execute on function api.apple_revocation_due(uuid, integer) from public, anon, authenticated;
grant execute on function api.apple_revocation_due(uuid, integer) to service_role;
