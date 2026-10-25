begin;
select plan(67);

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

-- The household's today (Europe/Berlin), not the database's UTC current_date: the two differ
-- every night from 22:00/23:00 UTC, and the answers are read for the household's day.
create function pg_temp.today() returns date language sql as $$
  select (now() at time zone 'Europe/Berlin')::date
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
  select pg_temp.id('hh_a'), c.id, 'Elternabend', 'appointment', true, pg_temp.today(), pg_temp.today(),
         'Europe/Berlin', 'a-evt@wuselwall.app'
    from app.calendar c where c.household_id = pg_temp.id('hh_a');
insert into app.calendar (household_id, name, colour_hex) select pg_temp.id('hh_b'), 'B', '#336699'
 where not exists (select 1 from app.calendar where household_id = pg_temp.id('hh_b'));
insert into app.event (household_id, calendar_id, title, kind, is_all_day, start_date, end_date, timezone, uid)
  select pg_temp.id('hh_b'), c.id, 'Secret of B', 'appointment', true, pg_temp.today(), pg_temp.today(),
         'Europe/Berlin', 'b-evt@wuselwall.app'
    from app.calendar c where c.household_id = pg_temp.id('hh_b');

insert into app.task_instance (household_id, title, points, kind, due_on, opens_on, closes_on, assigned_profile_id)
  values (pg_temp.id('hh_a'), 'Spülmaschine ausräumen', 3, 'duty', pg_temp.today(), pg_temp.today(), pg_temp.today(),
          pg_temp.id('paul')),
         (pg_temp.id('hh_a'), 'Zimmer aufräumen', 2, 'duty', pg_temp.today(), pg_temp.today(), pg_temp.today(),
          pg_temp.id('emma')),
         (pg_temp.id('hh_b'), 'B chore', 5, 'duty', pg_temp.today(), pg_temp.today(), pg_temp.today(),
          pg_temp.id('bea'));
insert into ids select 'task_paul', id from app.task_instance where title = 'Spülmaschine ausräumen';
insert into ids select 'task_emma', id from app.task_instance where title = 'Zimmer aufräumen';
insert into ids select 'task_b', id from app.task_instance where title = 'B chore';

insert into app.meal_plan_entry (household_id, on_date, slot, free_text)
  values (pg_temp.id('hh_a'), pg_temp.today(), 'dinner', 'Spaghetti'),
         (pg_temp.id('hh_b'), pg_temp.today(), 'dinner', 'B dinner');

-- ---- issuing ----------------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
insert into tok (name, id, token)
  select 'papa', (r ->> 'id')::uuid, r ->> 'token'
    from (select api.shortcut_token_create(null, null, 'iPhone') r) s;
insert into tok (name, id, token)
  select 'emma', (r ->> 'id')::uuid, r ->> 'token'
    from (select api.shortcut_token_create(null, pg_temp.id('emma'), 'Emmas iPad') r) s;

select is(length(pg_temp.token('papa')), 47, 'a token is 47 characters');
select ok(pg_temp.token('papa') ~ '^wws_[A-Za-z0-9_-]{43}$', 'a token is wws_ and base64url without padding');
select is((select profile_id from api.shortcut_tokens where id = (select id from tok where name = 'papa')),
  pg_temp.id('papa'), 'without a profile, the token is the guardian''s own');
select is((select profile_id from api.shortcut_tokens where id = (select id from tok where name = 'emma')),
  pg_temp.id('emma'), 'a guardian issues a token for a child');
select is((select count(*)::int from api.shortcut_tokens), 2, 'the household lists its tokens');
select throws_ok('select token_hash from app.shortcut_token', '42501', null,
  'the hash is not readable by the app');
select is(pg_temp.error_hint($$ select api.shortcut_token_create(null, null, '  ') $$),
  'shortcut_label_invalid', 'an empty label is refused');
select is(pg_temp.error_hint($$ select api.shortcut_token_create(null, pg_temp.id('bea'), 'B') $$),
  'profile_not_found', 'a member of another household is refused');

reset role;
select pg_temp.act_as_dev('paul');
insert into tok (name, id, token)
  select 'paul', (r ->> 'id')::uuid, r ->> 'token'
    from (select api.shortcut_token_create(null, null, 'Pauls iPhone') r) s;
select is((select profile_id from api.shortcut_tokens where id = (select id from tok where name = 'paul')),
  pg_temp.id('paul'), 'a member issues his own token on his phone');
select is(pg_temp.error_hint($$ select api.shortcut_token_create(null, pg_temp.id('emma'), 'For Emma') $$),
  'guardian_required', 'a member cannot issue a token for someone else');
select is(pg_temp.error_hint($$ select api.shortcut_token_revoke(null, (select id from tok where name = 'emma')) $$),
  'guardian_required', 'a member cannot revoke someone else''s token');

reset role;
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.error_hint(format($$ select api.shortcut_token_create(%L, null, 'Wall') $$, pg_temp.id('emma'))),
  'kiosk_forbidden', 'the kiosk cannot issue a token');

-- ---- other households, revoked devices, anonymous callers -------------------------------------
reset role;
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.shortcut_tokens), 0, 'another household lists none of these tokens');
select is(pg_temp.error_hint($$ select api.shortcut_token_revoke(null, (select id from tok where name = 'papa')) $$),
  'shortcut_token_not_found', 'another household cannot revoke a token');

reset role;
select pg_temp.act_as_dev('old');
select is((select count(*)::int from api.shortcut_tokens), 0, 'a revoked phone lists no tokens');

reset role;
set local role anon;
select throws_ok('select count(*) from api.shortcut_tokens', '42501', 'permission denied for view shortcut_tokens',
  'anonymous callers cannot read tokens');
select throws_ok($$ select api.shortcut_context('x', '{}', null, 1) $$, '42501',
  'permission denied for function shortcut_context', 'anonymous callers cannot run a shortcut');

reset role;
select pg_temp.act_as_dev('papa');
select throws_ok(format($$ select api.shortcut_context(%L, '{}', null, 1) $$, pg_temp.token('papa')), '42501',
  'permission denied for function shortcut_context', 'a signed-in device cannot run a shortcut');
select throws_ok(format($$ select api.shortcut_shopping_add(%L, '[{"name":"Milch"}]', null, null) $$,
  pg_temp.token('papa')), '42501', 'permission denied for function shortcut_shopping_add',
  'a signed-in device cannot add through a shortcut');
select throws_ok(format($$ select api.shortcut_task_complete(%L, %L) $$, pg_temp.token('papa'),
  pg_temp.id('task_paul')), '42501', 'permission denied for function shortcut_task_complete',
  'a signed-in device cannot tick through a shortcut');

-- ---- the service role: reading ----------------------------------------------------------------
reset role;
select pg_temp.act_as_service();
select is(pg_temp.error_hint($$ select api.shortcut_context('wws_unknown', '{}', null, 1) $$),
  'shortcut_token_invalid', 'an unknown token is refused');
select is(pg_temp.error_hint(format($$ select api.shortcut_context(%L, '{}', null, 1) $$,
  upper(pg_temp.token('papa')))), 'shortcut_token_invalid', 'a token is compared exactly');

insert into snap select 'ctx', api.shortcut_context(pg_temp.token('paul'),
  array['calendar', 'school', 'meals', 'tasks'], null, 1);
select is((select v -> 'holder' ->> 'display_name' from snap where k = 'ctx'), 'Paul',
  'the context names its holder');
select is((select v -> 'household' ->> 'name' from snap where k = 'ctx'), 'A', 'and the holder''s household');
select is((select v -> 'household' ->> 'today' from snap where k = 'ctx'),
  ((now() at time zone 'Europe/Berlin')::date)::text, 'today is the household''s');
select is((select jsonb_array_length(v -> 'members') from snap where k = 'ctx'), 3,
  'the members are the household''s three');
select ok((select not (v::text like '%Bea%') from snap where k = 'ctx'), 'no member of another household');
select is((select jsonb_agg(e ->> 'title') from snap, jsonb_array_elements(v -> 'events') e where k = 'ctx'),
  '["Elternabend"]'::jsonb, 'the events are the household''s own');
select ok((select not (v::text like '%Secret of B%') and not (v::text like '%B dinner%') from snap where k = 'ctx'),
  'nothing of another household reaches the context');
select is((select v -> 'events' -> 0 -> 'attendee_ids' from snap where k = 'ctx'), '[]'::jsonb,
  'events have the api view''s shape');
select is((select jsonb_agg(m ->> 'title') from snap, jsonb_array_elements(v -> 'meals') m where k = 'ctx'),
  '["Spaghetti"]'::jsonb, 'the meals are the household''s');
select is((select jsonb_agg(t ->> 'title') from snap, jsonb_array_elements(v -> 'tasks') t where k = 'ctx'),
  '["Spülmaschine ausräumen"]'::jsonb, 'the tasks are the holder''s own, not the child''s');
select ok((select v ? 'school' and v -> 'school' ? 'lessons' from snap where k = 'ctx'),
  'the school rows come back when asked for');
select is((select (v ->> 'points')::int from snap where k = 'ctx'), 0, 'the holder has no points yet');

insert into snap select 'slim', api.shortcut_context(pg_temp.token('paul'), '{}', null, 1);
select ok((select not (v ? 'events') and not (v ? 'school') and not (v ? 'meals') and not (v ? 'tasks')
             from snap where k = 'slim'), 'parts not asked for are not loaded');
select is(pg_temp.error_hint(format($$ select api.shortcut_context(%L, '{}', null, 63) $$, pg_temp.token('paul'))),
  'window_invalid', 'a window is at most 62 days');
reset role;
select is((select use_count from app.shortcut_token where id = (select id from tok where name = 'paul')), 2,
  'every use is counted');

-- ---- the service role: adding to the shopping list --------------------------------------------
select pg_temp.act_as_service();
insert into snap select 'add1', api.shortcut_shopping_add(pg_temp.token('paul'),
  '[{"name":"Milch","quantity":"2 l"},{"name":"Äpfel","count":3}]', null, 'aaaaaaaa-0000-4000-8000-000000000001');
select is((select v ->> 'status' from snap where k = 'add1'), 'applied', 'the items are added');
select is((select v ->> 'list' from snap where k = 'add1'), 'Supermarkt', 'to the default list');
reset role;
select is((select count::int from app.shopping_item where household_id = pg_temp.id('hh_a') and name = 'Äpfel'), 3,
  'a count is kept');
select is((select quantity from app.shopping_item where household_id = pg_temp.id('hh_a') and name = 'Milch'), '2 l',
  'a quantity is kept');
select is((select added_by from app.shopping_item where household_id = pg_temp.id('hh_a') and name = 'Milch'),
  pg_temp.id('paul'), 'the holder added it');
select is((select origin from app.audit_log where entity_type = 'shopping_item' and household_id = pg_temp.id('hh_a')
            order by id limit 1), 'shortcut', 'the audit log says a shortcut did it');

select pg_temp.act_as_service();
insert into snap select 'add2', api.shortcut_shopping_add(pg_temp.token('paul'),
  '[{"name":"Milch","quantity":"2 l"},{"name":"Äpfel","count":3}]', null, 'aaaaaaaa-0000-4000-8000-000000000001');
select is((select v ->> 'status' from snap where k = 'add2'), 'duplicate', 'a replay is recognised');
reset role;
select is((select count::int from app.shopping_item where household_id = pg_temp.id('hh_a') and name = 'Äpfel'), 3,
  'and changes nothing');

select pg_temp.act_as_service();
insert into snap select 'add3', api.shortcut_shopping_add(pg_temp.token('paul'), '[{"name":"milch"}]', null, null);
select is((select (v -> 'items' -> 0 ->> 'merged')::boolean from snap where k = 'add3'), true,
  'an item already open is counted up, not duplicated');
reset role;
select is((select count(*)::int from app.shopping_item where household_id = pg_temp.id('hh_a')), 2,
  'two items are on the list');
select pg_temp.act_as_service();
select is(pg_temp.error_hint(format($$ select api.shortcut_shopping_add(%L, '[{"name":"Brot"}]', 'Baumarkt', null) $$,
  pg_temp.token('paul'))), 'list_not_found', 'an unknown list is refused');
select is(pg_temp.error_hint(format($$ select api.shortcut_shopping_add(%L, '[]', null, null) $$,
  pg_temp.token('paul'))), 'items_invalid', 'no items is refused');
select is(pg_temp.error_hint(format($$ select api.shortcut_shopping_add(%L, '[{"name":"x","count":0}]', null, null) $$,
  pg_temp.token('paul'))), 'items_invalid', 'a count of zero is refused');

-- ---- the service role: ticking a chore ---------------------------------------------------------
insert into snap select 'done', api.shortcut_task_complete(pg_temp.token('paul'), pg_temp.id('task_paul'));
select is((select v ->> 'status' from snap where k = 'done'), 'done', 'the holder ticks his chore');
select is((select (v ->> 'points_credited')::int from snap where k = 'done'), 3, 'and is credited');
reset role;
select is(app.tasks_balance(pg_temp.id('paul')), 3, 'the ledger has the points');
select pg_temp.act_as_service();
select is(pg_temp.error_hint(format($$ select api.shortcut_task_complete(%L, %L) $$, pg_temp.token('papa'),
  pg_temp.id('task_emma'))), 'task_not_yours', 'a guardian''s shortcut does not tick a child''s chore');
select is(pg_temp.error_hint(format($$ select api.shortcut_task_complete(%L, %L) $$, pg_temp.token('paul'),
  pg_temp.id('task_b'))), 'task_not_found', 'another household''s chore does not exist');

-- ---- a shortcut cannot manage anything ---------------------------------------------------------
reset role;
select is(pg_temp.error_hint(format($$ select app.require_guardian(app.shortcut_actor(%L)) $$, pg_temp.token('papa'))),
  'guardian_required', 'even a guardian''s shortcut is no guardian');

-- ---- the daily cap ------------------------------------------------------------------------------
reset role;
update app.shortcut_token set writes_on = app.tasks_today(pg_temp.id('hh_a')), writes_count = 100
 where id = (select id from tok where name = 'paul');
select pg_temp.act_as_service();
select is(pg_temp.error_hint(format($$ select api.shortcut_shopping_add(%L, '[{"name":"Brot"}]', null, null) $$,
  pg_temp.token('paul'))), 'shortcut_rate_limited', 'writes stop at the daily cap');
select is(pg_temp.error_hint(format($$ select api.shortcut_context(%L, '{}', null, 1) $$, pg_temp.token('paul'))),
  'no error', 'reads go on');

-- ---- revoking ----------------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('paul');
select lives_ok(format($$ select api.shortcut_token_revoke(null, %L) $$, (select id from tok where name = 'paul')),
  'a holder revokes his own token');
select lives_ok(format($$ select api.shortcut_token_revoke(null, %L) $$, (select id from tok where name = 'paul')),
  'revoking a revoked token is harmless');
reset role;
select pg_temp.act_as_service();
select is(pg_temp.error_hint(format($$ select api.shortcut_context(%L, '{}', null, 1) $$, pg_temp.token('paul'))),
  'shortcut_token_invalid', 'a revoked token is refused like an unknown one');

-- ---- tokens follow their holder and their household ---------------------------------------------
reset role;
update app.profile set active = false where id = pg_temp.id('emma');
select ok((select revoked_at is not null from app.shortcut_token where id = (select id from tok where name = 'emma')),
  'a deactivated profile''s tokens are revoked');

-- Papa leaves: his account is detached from the profile (specs/20 J6).
update app.profile set auth_user_id = null where id = pg_temp.id('papa');
select ok((select revoked_at is not null from app.shortcut_token where id = (select id from tok where name = 'papa')),
  'an adult who leaves loses his tokens');

insert into tok (name, id, token) values ('fresh', gen_random_uuid(), 'wws_fresh-token-for-the-deletion-test-0000000');
insert into app.shortcut_token (id, household_id, profile_id, label, token_hash)
  select id, pg_temp.id('hh_a'), pg_temp.id('paul'), 'Fresh', encode(extensions.digest(token, 'sha256'), 'hex')
    from tok where name = 'fresh';
update app.household set deleted_at = now() where id = pg_temp.id('hh_a');
select ok((select revoked_at is not null from app.shortcut_token where id = (select id from tok where name = 'fresh')),
  'a deleted family''s tokens are revoked');
update app.household set deleted_at = null where id = pg_temp.id('hh_a');
select ok((select revoked_at is not null from app.shortcut_token where id = (select id from tok where name = 'fresh')),
  'and stay revoked when the family is restored');

-- ---- the export ---------------------------------------------------------------------------------
reset role;
update app.profile set auth_user_id = (select auth_user_id from app.device where label = 'A-Phone')
 where id = pg_temp.id('papa');
select pg_temp.act_as_dev('papa');
insert into snap select 'export', api.household_export(null);
select is((select jsonb_array_length(v -> 'tables' -> 'shortcut_token') from snap where k = 'export'), 4,
  'the export lists the shortcut tokens');
select ok((select not (v -> 'tables' -> 'shortcut_token' -> 0 ? 'token_hash') from snap where k = 'export'),
  'without their hash');

select * from finish();
rollback;
