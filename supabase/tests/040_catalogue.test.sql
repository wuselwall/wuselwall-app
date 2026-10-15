begin;
select plan(8);

-- The perimeter, checked structurally (specs/19). A future migration that adds a table or
-- function and forgets one of these fails here, not in production.

select is((select coalesce(string_agg(c.relname, ', '), '') from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'app' and c.relkind in ('r', 'p')
             and not (c.relrowsecurity and c.relforcerowsecurity)),
  '', 'every app table has RLS enabled and forced');

select is((select coalesce(string_agg(c.relname, ', '), '') from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'app' and c.relkind in ('r', 'p')
             and (has_table_privilege('anon', c.oid, 'select,insert,update,delete')
                  or has_any_column_privilege('anon', c.oid, 'select,insert,update'))),
  '', 'anon has no privilege on any app table');

select is((select coalesce(string_agg(c.relname || ':' || p, ', '), '') from pg_class c
            join pg_namespace n on n.oid = c.relnamespace,
            unnest(array['insert', 'update', 'delete', 'truncate']) p
           where n.nspname = 'app' and c.relkind in ('r', 'p')
             and has_table_privilege('authenticated', c.oid, p)),
  '', 'authenticated can only read app tables (writes go through api functions)');

select is((select coalesce(string_agg(c.relname, ', '), '') from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'api' and c.relkind = 'v'
             and not coalesce((select option_value = 'true'
                                 from pg_options_to_table(c.reloptions)
                                where option_name = 'security_invoker'), false)),
  '', 'every api view is security_invoker');

select is((select coalesce(string_agg(c.relname, ', '), '') from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'api' and c.relkind = 'v'
             and has_table_privilege('anon', c.oid, 'select')),
  '', 'anon reads no api view');

select is((select coalesce(string_agg(p.proname, ', ' order by p.proname), '') from pg_proc p
            join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'api' and has_function_privilege('anon', p.oid, 'execute')),
  'enrol_device, health, server_info, setup_household', 'anon can call exactly health, server_info, setup_household and enrol_device');

select is((select coalesce(string_agg(n.nspname || '.' || p.proname, ', '), '') from pg_proc p
            join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('api', 'app') and p.prosecdef
             and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) cfg where cfg like 'search_path=%')),
  '', 'every security definer function pins its search_path');

select is((select coalesce(string_agg(p.proname, ', '), '') from pg_proc p
            join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'app'
             and has_function_privilege('authenticated', p.oid, 'execute')
             and p.proname not in ('jwt_household', 'jwt_device', 'device_ok', 'session_alive')),
  '', 'authenticated can execute only the RLS helpers in app');

select * from finish();
rollback;
