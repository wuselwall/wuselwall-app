-- Foundation: the two schemas of ADR-010 and the first callable function.
--   app  - tables, internal functions. Never exposed through the API.
--   api  - security_invoker views and one function per use case. The only exposed schema.

create schema if not exists app;
create schema if not exists api;

-- Clients may call functions in api, but cannot touch app at all.
revoke all on schema app from public, anon, authenticated;
grant usage on schema api to anon, authenticated;

alter default privileges in schema api revoke execute on functions from public;
alter default privileges in schema api grant execute on functions to authenticated;

-- Liveness probe used by the app's System page and by CI smoke tests. Callable without a
-- session so a device can verify it reaches the backend before it is enrolled.
create or replace function api.health()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'status', 'ok',
    'server_time', now(),
    'db_version', current_setting('server_version')
  );
$$;

revoke all on function api.health() from public;
grant execute on function api.health() to anon, authenticated;
