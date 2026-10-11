begin;
select plan(5);

select has_schema('app', 'schema app exists');
select has_schema('api', 'schema api exists');

select is(
  (api.health() ->> 'status'),
  'ok',
  'api.health() reports ok'
);

select ok(
  has_function_privilege('anon', 'api.health()', 'execute'),
  'anon may call api.health()'
);

select ok(
  not has_schema_privilege('authenticated', 'app', 'create'),
  'authenticated cannot create objects in schema app'
);

select * from finish();
rollback;
