-- The discovery document reports the household_creation mode the server really has
-- (specs/20 "Claiming the server").
--
-- It always said 'token', so an app could not tell, before anyone signed in, that a server
-- set to `open` by hand lets everyone sign up: it sent that server's founder through the
-- setup key too. `token` still means `code`: the word is the document's, and it mirrors the
-- gates (app.before_user_created_hook, api.household_create), to which only `code` closes.
--
-- Additive for api_version: older apps only store this value, and the mode is no secret,
-- since a stranger's sign-up finds it out anyway.

-- As in 20261031151000_local_matching.sql, with the mode read from the setting.
create or replace function api.server_info()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'api_version', 1,
    'min_app_version', '1.0.0',
    'household_creation', case when app.household_creation_mode() = 'code' then 'token' else 'open' end,
    'claimed', app.server_claimed(),
    'features', jsonb_build_array(
      'calendar', 'ics', 'calendar-import', 'school', 'tasks', 'meals', 'shopping', 'holidays',
      'lighter-day', 'event-templates', 'password-reset', 'claim', 'local-matching'
    )
  );
$$;
