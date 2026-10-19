begin;
select plan(32);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

-- Named things of the test: profiles and households (ids), devices (devs), auth users (users),
-- shortcut tokens as created (tok) and answers as the service role saw them (snap).
create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;
create temp table tok (name text primary key, id uuid, token text);
grant all on tok to public;
create temp table snap (k text primary key, v jsonb);
grant all on snap to public;

create function pg_temp.id(p_name text) returns uuid language sql as $$
  select id from ids where name = p_name
$$;

create function pg_temp.token(p_name text) returns text language sql as $$
  select token from tok where name = p_name
$$;

-- Switches to the device's Auth user, as PostgREST would with its JWT.
create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- Switches to the service role, as the Edge Function's client would.
create function pg_temp.act_as_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  perform set_config('role', 'service_role', true);
end $$;

-- The hint of the error a statement raises, or 'no error'.
create function pg_temp.error_hint(p_sql text) returns text language plpgsql as $$
declare v_hint text;
begin
  execute p_sql;
  return 'no error';
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint;
  return v_hint;
end $$;

-- ---- household A: Papa (guardian, phone), Paul (member, phone), Emma (child), a kiosk ------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;
insert into users values
  ('paul', app.create_auth_user('paul@example.org', 'longpassword1')),
  ('kiosk', app.create_auth_user('kiosk@devices.invalid', 'x1234567890')),
  ('old', app.create_auth_user('old@example.org', 'longpassword1'));
insert into app.profile (household_id, display_name, role, kind, auth_user_id)
  values (pg_temp.id('hh_a'), 'Paul', 'member', 'adult', (select usr from users where name = 'paul')),
         (pg_temp.id('hh_a'), 'Emma', 'member', 'child', null);
insert into ids select lower(p.display_name), p.id from app.profile p
 where p.household_id = pg_temp.id('hh_a') and p.display_name in ('Paul', 'Emma');

insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.id('hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = pg_temp.id('papa');
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  values (pg_temp.id('hh_a'), (select usr from users where name = 'paul'), 'Paul-Phone', 'personal',
          'adult', pg_temp.id('paul'));
insert into app.device (household_id, auth_user_id, label, class, register)
  values (pg_temp.id('hh_a'), (select usr from users where name = 'kiosk'), 'Kiosk', 'kiosk', 'kiosk');
insert into app.device (household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  values (pg_temp.id('hh_a'), (select usr from users where name = 'old'), 'Old-Phone', 'personal', 'adult',
          pg_temp.id('papa'), now());

-- ---- household B, made by hand (setup closes after the first household) -----------------------
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into users values ('b', app.create_auth_user('b@example.org', 'longpassword1'));
insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_b'), 'Bea', 'guardian', usr from users where name = 'b';
insert into ids select 'bea', p.id from app.profile p where p.display_name = 'Bea';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.id('hh_b'), u.usr, 'B-Phone', 'personal', 'adult', pg_temp.id('bea')
    from users u where u.name = 'b';

insert into devs
  select n, d.auth_user_id, d.id, d.household_id, d.class
    from (values ('papa', 'A-Phone'), ('paul', 'Paul-Phone'), ('kiosk', 'Kiosk'), ('old', 'Old-Phone'),
                 ('b', 'B-Phone')) v(n, label)
    join app.device d on d.label = v.label;

-- ---- data the answers are read from: an event each, chores, a meal ---------------------------
insert into app.event (household_id, calendar_id, title, kind, is_all_day, start_date, end_date, timezone, uid)
  select pg_temp.id('hh_a'), c.id, 'Elternabend', 'appointment', true, current_date, current_date,
         'Europe/Berlin', 'a-evt@wuselwall.app'
    from app.calendar c where c.household_id = pg_temp.id('hh_a');
insert into app.calendar (household_id, name, colour_hex) select pg_temp.id('hh_b'), 'B', '#336699'
 where not exists (select 1 from app.calendar where household_id = pg_temp.id('hh_b'));
insert into app.event (household_id, calendar_id, title, kind, is_all_day, start_date, end_date, timezone, uid)
  select pg_temp.id('hh_b'), c.id, 'Secret of B', 'appointment', true, current_date, current_date,
         'Europe/Berlin', 'b-evt@wuselwall.app'
    from app.calendar c where c.household_id = pg_temp.id('hh_b');

insert into app.task_instance (household_id, title, points, kind, due_on, opens_on, closes_on, assigned_profile_id)
  values (pg_temp.id('hh_a'), 'Spülmaschine ausräumen', 3, 'duty', current_date, current_date, current_date,
          pg_temp.id('paul')),
         (pg_temp.id('hh_a'), 'Zimmer aufräumen', 2, 'duty', current_date, current_date, current_date,
          pg_temp.id('emma')),
         (pg_temp.id('hh_b'), 'B chore', 5, 'duty', current_date, current_date, current_date,
          pg_temp.id('bea'));
insert into ids select 'task_paul', id from app.task_instance where title = 'Spülmaschine ausräumen';
insert into ids select 'task_emma', id from app.task_instance where title = 'Zimmer aufräumen';
insert into ids select 'task_b', id from app.task_instance where title = 'B chore';

insert into app.meal_plan_entry (household_id, on_date, slot, free_text)
  values (pg_temp.id('hh_a'), current_date, 'dinner', 'Spaghetti'),
         (pg_temp.id('hh_b'), current_date, 'dinner', 'B dinner');

-- Extra rows the assistant reads: a shopping item and a recipe in each household, a ledger row.
insert into app.shopping_list (household_id, name, is_default, sort_order) values (pg_temp.id('hh_b'), 'B-Liste', true, 0);
select app.shopping_ensure_lists(pg_temp.id('hh_a'));
insert into app.shopping_item (list_id, household_id, name, folded_name, added_by)
  select l.id, l.household_id, n, lower(n), null from app.shopping_list l
    join (values ('hh_a', 'Milch'), ('hh_b', 'B-Käse')) v(hh, n) on l.household_id = pg_temp.id(v.hh) and l.is_default;
insert into app.recipe (household_id, title) values (pg_temp.id('hh_a'), 'Spaghetti Bolognese'), (pg_temp.id('hh_b'), 'B-Rezept');
insert into app.point_transaction (household_id, profile_id, amount, reason, source_type, source_id)
  values (pg_temp.id('hh_a'), pg_temp.id('emma'), 4, 'adjustment', 'adjustment', 'x1');

-- ---- issuing ----------------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
insert into tok (name, id, token)
  select 'papa', (r ->> 'id')::uuid, r ->> 'token' from (select api.assistant_key_create(null, null, 'Claude') r) s;
insert into tok (name, id, token)
  select 'papa_sc', (r ->> 'id')::uuid, r ->> 'token' from (select api.shortcut_token_create(null, null, 'iPhone') r) s;

select ok(pg_temp.token('papa') ~ '^wwa_[A-Za-z0-9_-]{43}$', 'an assistant key is wwa_ and base64url');
select ok(pg_temp.token('papa_sc') ~ '^wws_[A-Za-z0-9_-]{43}$', 'a shortcut key still is wws_');
select is((select kind from api.shortcut_tokens where id = (select id from tok where name = 'papa')), 'assistant',
  'the list says which kind a key is');
select is((select kind from api.shortcut_tokens where id = (select id from tok where name = 'papa_sc')), 'shortcut',
  'and a shortcut key is a shortcut key');
select is(pg_temp.error_hint($$ select api.assistant_key_create(null, pg_temp.id('emma'), 'For Emma') $$),
  'assistant_adult_only', 'an assistant key is for adults only');
select is(pg_temp.error_hint($$ select api.assistant_key_create(null, pg_temp.id('bea'), 'B') $$),
  'profile_not_found', 'a member of another household is refused');

reset role;
select pg_temp.act_as_dev('paul');
insert into tok (name, id, token)
  select 'paul', (r ->> 'id')::uuid, r ->> 'token' from (select api.assistant_key_create(null, null, 'Laptop') r) s;
select is((select profile_id from api.shortcut_tokens where id = (select id from tok where name = 'paul')),
  pg_temp.id('paul'), 'an adult member issues his own assistant key');
select is(pg_temp.error_hint($$ select api.assistant_key_create(null, pg_temp.id('papa'), 'For Papa') $$),
  'guardian_required', 'but not one for someone else');

reset role;
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.error_hint(format($$ select api.assistant_key_create(%L, null, 'Wall') $$, pg_temp.id('papa'))),
  'kiosk_forbidden', 'the kiosk cannot issue one');

-- ---- who may run the MCP read ------------------------------------------------------------------
reset role;
set local role anon;
select throws_ok($$ select api.mcp_context('x', '{}', null, 1) $$, '42501',
  'permission denied for function mcp_context', 'anonymous callers cannot read');
reset role;
select pg_temp.act_as_dev('papa');
select throws_ok(format($$ select api.mcp_context(%L, '{}', null, 1) $$, pg_temp.token('papa')), '42501',
  'permission denied for function mcp_context', 'a signed-in device cannot run the MCP read');

reset role;
select pg_temp.act_as_service();
select is(pg_temp.error_hint(format($$ select api.mcp_context(%L, '{}', null, 1) $$, pg_temp.token('papa_sc'))),
  'shortcut_token_invalid', 'a shortcut key is no assistant key');
select is(pg_temp.error_hint(format($$ select api.shortcut_context(%L, '{}', null, 1) $$, pg_temp.token('papa'))),
  'shortcut_token_invalid', 'an assistant key runs no shortcut');
select is(pg_temp.error_hint(format($$ select api.shortcut_shopping_add(%L, '[{"name":"x"}]', null, null) $$,
  pg_temp.token('papa'))), 'shortcut_token_invalid', 'an assistant key adds nothing');
select is(pg_temp.error_hint(format($$ select api.shortcut_task_complete(%L, %L) $$, pg_temp.token('papa'),
  pg_temp.id('task_paul'))), 'shortcut_token_invalid', 'and ticks nothing');

-- ---- what an assistant reads ---------------------------------------------------------------------
insert into snap select 'ctx', api.mcp_context(pg_temp.token('papa'),
  array['calendar', 'school', 'meals', 'tasks_all', 'shopping', 'points', 'recipes'], null, 7);
select is((select v -> 'holder' ->> 'display_name' from snap where k = 'ctx'), 'Papa', 'the context names its holder');
select is((select jsonb_agg(t ->> 'title' order by t ->> 'title') from snap, jsonb_array_elements(v -> 'tasks_all') t
            where k = 'ctx'), '["Spülmaschine ausräumen", "Zimmer aufräumen"]'::jsonb,
  'every task of the household, anyone''s');
select is((select jsonb_agg(i ->> 'name') from snap, jsonb_array_elements(v -> 'shopping_items') i where k = 'ctx'),
  '["Milch"]'::jsonb, 'the open shopping items of the household');
select ok((select jsonb_array_length(v -> 'shopping_categories') > 0 from snap where k = 'ctx'),
  'with the categories to group them');
select is((select (b ->> 'balance')::int from snap, jsonb_array_elements(v -> 'balances') b
            where k = 'ctx' and b ->> 'profile_id' = pg_temp.id('emma')::text), 4, 'every member''s balance');
select is((select jsonb_array_length(v -> 'ledger') from snap where k = 'ctx'), 1, 'the recent ledger');
select is((select jsonb_agg(r ->> 'title') from snap, jsonb_array_elements(v -> 'recipes') r where k = 'ctx'),
  '["Spaghetti Bolognese"]'::jsonb, 'the household''s recipes');
select ok((select not (v::text like '%B-Käse%') and not (v::text like '%B-Rezept%') and not (v::text like '%Secret of B%')
             and not (v::text like '%B chore%') from snap where k = 'ctx'),
  'nothing of another household reaches an assistant');

insert into snap select 'sc', api.shortcut_context(pg_temp.token('papa_sc'), array['tasks_all', 'points', 'tasks'], null, 1);
select ok((select not (v ? 'tasks_all') and not (v ? 'balances') and v ? 'tasks' from snap where k = 'sc'),
  'a shortcut reads only its own parts');

-- ---- an assistant never writes and is no guardian ------------------------------------------------
reset role;
select is((select use_count from app.shortcut_token where id = (select id from tok where name = 'papa')), 1,
  'the read is counted');
select is(pg_temp.error_hint(format($$ select app.key_actor(%L, 'assistant', true) $$, pg_temp.token('papa'))),
  'key_read_only', 'an assistant key refuses every write');
select is(pg_temp.error_hint(format($$ select app.require_guardian(app.key_actor(%L, 'assistant', false)) $$,
  pg_temp.token('papa'))), 'guardian_required', 'and is no guardian');
select is((app.key_actor(pg_temp.token('papa'), 'assistant', false)).origin, 'mcp', 'its origin is mcp');

-- ---- revoking --------------------------------------------------------------------------------------
select pg_temp.act_as_dev('papa');
select lives_ok(format($$ select api.shortcut_token_revoke(null, %L) $$, (select id from tok where name = 'paul')),
  'a guardian revokes an assistant key');
reset role;
select pg_temp.act_as_service();
select is(pg_temp.error_hint(format($$ select api.mcp_context(%L, '{}', null, 1) $$, pg_temp.token('paul'))),
  'shortcut_token_invalid', 'a revoked assistant key reads nothing');

-- ---- the export ------------------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
insert into snap select 'export', api.household_export(null);
-- Keyed by label, not sorted by it: 'iPhone' sorts after 'Laptop' under the C collation and
-- between 'Claude' and 'Laptop' under en_US, so an ordered list depended on the database's locale.
select is((select jsonb_object_agg(t ->> 'label', t ->> 'kind') from snap, jsonb_array_elements(v -> 'tables' -> 'shortcut_token') t
            where k = 'export'), '{"Claude": "assistant", "Laptop": "assistant", "iPhone": "shortcut"}'::jsonb,
  'the export carries the kind');
select is((select count(*)::int from snap, jsonb_array_elements(v -> 'tables' -> 'shortcut_token') t
             join app.shortcut_token s on s.id = (t ->> 'id')::uuid
            where k = 'export' and s.kind = t ->> 'kind' and s.household_id = pg_temp.id('hh_a')),
  (select count(*)::int from app.shortcut_token where household_id = pg_temp.id('hh_a')),
  'every key of the household is exported once, with its own kind');

select * from finish();
rollback;
