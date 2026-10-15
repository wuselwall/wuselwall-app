begin;
select plan(6);

select ok(
  (api.server_info() ->> 'api_version')::int >= 1,
  'api.server_info() names an api_version'
);

select ok(
  (api.server_info() ->> 'min_app_version') ~ '^\d+\.\d+\.\d+$',
  'min_app_version is a semantic version'
);

select is(
  api.server_info() ->> 'household_creation',
  'token',
  'households are founded with a setup token'
);

select is(
  jsonb_typeof(api.server_info() -> 'features'),
  'array',
  'features is a list'
);

select ok(
  has_function_privilege('anon', 'api.server_info()', 'execute'),
  'anon may call api.server_info() (the front door asks before sign-in)'
);

select ok(
  not (api.server_info() ? 'households'),
  'server_info reveals nothing about households'
);

select * from finish();
rollback;
