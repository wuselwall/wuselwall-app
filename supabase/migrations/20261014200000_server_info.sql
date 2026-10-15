-- What this server is, for the app's front door (ADR-018, decisions 3 and 5).
--
-- The store app has no server compiled in. It reads the discovery document that the
-- server-info Edge Function builds from this function and from Auth's public settings,
-- and refuses a server whose contract it does not speak.
--
--   api_version      raised by every migration that changes the app–server contract
--                    (CLAUDE.md). Each app release supports this version and the one
--                    before it. Raise it with `create or replace` in that migration.
--   min_app_version  the oldest app release this server still works with.
--   household_creation  'token': a household is founded with the operator's single-use
--                    setup token (scripts/remote-setup-token.sh); after the first one the
--                    server is closed for good.
--   features         what this server can do beyond the core. An app hides a module the
--                    server lacks rather than failing on it.
--
-- Callable without a session: the app asks before anyone signs in. Nothing here is
-- about a household; whether one exists is not revealed.
create or replace function api.server_info()
returns jsonb
language sql
immutable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'api_version', 1,
    'min_app_version', '1.0.0',
    'household_creation', 'token',
    'features', jsonb_build_array(
      'calendar', 'ics', 'school', 'tasks', 'meals', 'shopping', 'holidays'
    )
  );
$$;

revoke all on function api.server_info() from public;
grant execute on function api.server_info() to anon, authenticated;
