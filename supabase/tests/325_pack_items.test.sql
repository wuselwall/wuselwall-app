begin;
select plan(59);

-- One-off things to bring (specs/15), migrations/20261117100000_pack_items.sql: the table and its
-- view, who may save and delete what, the refusals, the audit, the export and the announcement.
-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;
create temp table snaps (name text primary key, v text);
grant all on snaps to public;

create function pg_temp.id(p_name text) returns uuid language sql as $$
  select id from ids where name = p_name
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

create function pg_temp.add_dev(p_name text, p_user text, p_hh text, p_profile text, p_class text,
  p_register text, p_revoked boolean default false) returns void language plpgsql as $$
declare
  v_id  uuid := gen_random_uuid();
  v_usr uuid := (select usr from users where name = p_user);
  v_hh  uuid := pg_temp.id(p_hh);
begin
  insert into app.device (id, household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  values (v_id, v_hh, v_usr, p_name, p_class, p_register, pg_temp.id(p_profile),
          case when p_revoked then now() end);
  insert into devs values (p_name, v_usr, v_id, v_hh, p_class);
end $$;

-- Saves a thing as device p_dev (acting p_actor on a shared device or the wall) and keeps its id
-- under p_name. Answers the function's result.
create function pg_temp.save(p_name text, p_dev text, p_actor text, p_id text, p_child text,
  p_date date, p_title text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as_dev(p_dev);
  r := api.pack_item_save(pg_temp.id(p_actor), pg_temp.id(p_id), pg_temp.id(p_child), p_date, p_title);
  reset role;
  if p_name is not null then
    insert into ids values (p_name, (r ->> 'id')::uuid) on conflict (name) do update set id = excluded.id;
  end if;
  return r;
end $$;

-- The hint of the error p_sql raises as device p_dev, or 'no error'.
create function pg_temp.hint(p_dev text, p_sql text) returns text language plpgsql as $$
declare v_hint text;
begin
  perform pg_temp.act_as_dev(p_dev);
  begin
    execute p_sql;
    v_hint := 'no error';
  exception when others then
    get stacked diagnostics v_hint = pg_exception_hint;
  end;
  reset role;
  return v_hint;
end $$;

-- The hint of saving, as p_dev.
create function pg_temp.bad(p_dev text, p_actor text, p_id text, p_child text, p_date date,
  p_title text) returns text language sql as $$
  select pg_temp.hint(p_dev, format('select api.pack_item_save(%L, %L, %L, %L, %L)',
    pg_temp.id(p_actor), pg_temp.id(p_id), pg_temp.id(p_child), p_date, p_title))
$$;

-- The SQLSTATE of the error p_sql raises (as the current role), or 'ok'.
create function pg_temp.state(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end $$;

create function pg_temp.snap() returns text language sql as $$
  select (select count(*) from app.pack_item)::text || '/' || (select count(*) from app.audit_log)
      || '/' || (select coalesce(string_agg(title || '@' || on_date, ',' order by id), '') from app.pack_item)
$$;

-- ---- household A: Papa (guardian), Opa (an adult member), two children, a child who left;
-- ---- household B: Bea and her child --------------------------------------------------------------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;
insert into users select 'papa', auth_user_id from app.profile where id = pg_temp.id('papa');
insert into users select n, app.create_auth_user(n || '@example.org', 'longpassword1')
  from unnest(array['bea', 'opa', 'kind', 'papa_old', 'ipad', 'kiosk']) n;

insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
with ins as (insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_b'), 'Bea', 'guardian', usr from users where name = 'bea' returning id)
insert into ids select 'bea', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_a'), 'Opa', 'member', usr from users where name = 'opa' returning id)
insert into ids select 'opa', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, kind)
  select pg_temp.id('hh_a'), 'Kind', 'member', 'child' returning id)
insert into ids select 'kind', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, kind)
  select pg_temp.id('hh_a'), 'Kind2', 'member', 'child' returning id)
insert into ids select 'kind2', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, kind, active)
  select pg_temp.id('hh_a'), 'Ex', 'member', 'child', false returning id)
insert into ids select 'ex', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, kind)
  select pg_temp.id('hh_b'), 'BKind', 'member', 'child' returning id)
insert into ids select 'bkind', id from ins;

select pg_temp.add_dev('papa', 'papa', 'hh_a', 'papa', 'personal', 'adult');
select pg_temp.add_dev('bea', 'bea', 'hh_b', 'bea', 'personal', 'adult');
select pg_temp.add_dev('opa', 'opa', 'hh_a', 'opa', 'personal', 'adult');
select pg_temp.add_dev('kind', 'kind', 'hh_a', 'kind', 'personal', 'kid');
select pg_temp.add_dev('ipad', 'ipad', 'hh_a', null, 'shared', 'adult');
select pg_temp.add_dev('kiosk', 'kiosk', 'hh_a', null, 'kiosk', 'kiosk');
select pg_temp.add_dev('papa_old', 'papa_old', 'hh_a', 'papa', 'personal', 'adult', true);

-- ---- 1. The announcement and the shape -------------------------------------------------------------------
select ok(api.server_info() -> 'features' ? 'pack-items', 'the server announces pack-items');
select ok(api.server_info() -> 'features' ?& array['trips', 'event-reminder'], 'and keeps what it announced before');
select is((select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns
            where table_schema = 'api' and table_name = 'pack_items'),
  'id,profile_id,on_date,title,created_by_profile_id,created_at,updated_at', 'api.pack_items');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'app.pack_item'::regclass),
  'RLS is enabled and forced on app.pack_item');
select is((select count(*)::int from app.export_table where name = 'pack_item'), 1, 'the export carries the table');

-- ---- 2. Saving -------------------------------------------------------------------------------------------
select is(pg_temp.save('t1', 'papa', null, null, 'kind', current_date + 1, '  Turnbeutel ') ? 'id', true,
  'a parent notes a thing for a child and gets its id');
select is((select title || '|' || on_date || '|' || profile_id || '|' || created_by_profile_id from app.pack_item where id = pg_temp.id('t1')),
  'Turnbeutel|' || (current_date + 1) || '|' || pg_temp.id('kind') || '|' || pg_temp.id('papa'),
  'trimmed, for the child, on the day, by the parent');
select is(pg_temp.save(null, 'papa', null, null, 'kind', current_date + 1, 'turnbeutel'),
  jsonb_build_object('id', pg_temp.id('t1')), 'the same thing again (any case) answers the one that is there');
select is((select count(*)::int from app.pack_item where profile_id = pg_temp.id('kind')), 1, 'and adds nothing');
select is(pg_temp.save('t2', 'opa', null, null, 'kind2', current_date + 1, 'Zettel unterschrieben') ? 'id', true,
  'an adult who is no guardian notes one too');
select is(pg_temp.save('t3', 'kind', null, null, 'kind', current_date + 2, 'Bastelsachen') ? 'id', true,
  'a child notes one for itself');
select is(pg_temp.save('t4', 'ipad', 'opa', null, 'kind', current_date, '5 Fr.') ? 'id', true,
  'at a shared device, for the acting adult');
select is(pg_temp.save('t5', 'kiosk', 'papa', null, 'kind2', current_date + 1, 'Regenjacke') ? 'id', true,
  'and on the wall, for its acting member');
select is(pg_temp.save('t6', 'ipad', 'kind', null, 'kind', current_date + 1, 'Pausenbrot') ? 'id', true,
  'a child acting at a shared device, for itself');

-- ---- 3. Changing -----------------------------------------------------------------------------------------
select is(pg_temp.save(null, 'papa', null, 't1', 'kind', current_date + 3, 'Turnsack'),
  jsonb_build_object('id', pg_temp.id('t1')), 'a thing is changed in place');
select is((select title || '|' || on_date from app.pack_item where id = pg_temp.id('t1')),
  'Turnsack|' || (current_date + 3), 'with its new title and day');
select ok((select updated_at >= created_at from app.pack_item where id = pg_temp.id('t1')), 'and its change time');
select is(pg_temp.save(null, 'papa', null, 't1', 'kind2', current_date + 3, 'Turnsack'),
  jsonb_build_object('id', pg_temp.id('t1')), 'an adult gives it to another child');
select is((select profile_id from app.pack_item where id = pg_temp.id('t1')), pg_temp.id('kind2'), 'which then has it');
select is(pg_temp.save('t7', 'papa', null, null, 'kind2', current_date + 3, 'Mütze') ? 'id', true, 'one more for the day');
select is(pg_temp.save(null, 'papa', null, 't7', 'kind2', current_date + 3, 'TURNSACK'),
  jsonb_build_object('id', pg_temp.id('t1')), 'changed into a thing the day has, it answers that one');
select is((select count(*)::int from app.pack_item where id = pg_temp.id('t7')), 0, 'and the changed one is gone: one is enough');

-- ---- 4. What a child may not do --------------------------------------------------------------------------
select is(pg_temp.bad('kind', null, null, 'kind2', current_date + 1, 'Ball'), 'pack_item_not_yours',
  'a child notes nothing for another child');
select is(pg_temp.bad('ipad', 'kind', null, 'kind2', current_date + 1, 'Ball'), 'pack_item_not_yours',
  'not at a shared device either');
select is(pg_temp.bad('kind', null, 't2', 'kind', current_date + 1, 'Ball'), 'pack_item_not_yours',
  'takes no other child''s thing for itself');
select is(pg_temp.bad('kind', null, 't3', 'kind2', current_date + 2, 'Bastelsachen'), 'pack_item_not_yours',
  'gives none of its own to another child');
select is(pg_temp.hint('kind', format('select api.pack_item_delete(null, %L)', pg_temp.id('t2'))), 'pack_item_not_yours',
  'and deletes no other child''s thing');

-- ---- 5. What is refused ----------------------------------------------------------------------------------
insert into snaps values ('refusals', pg_temp.snap());
select is(pg_temp.bad('papa', null, null, 'kind', current_date + 1, '   '), 'pack_item_invalid', 'no title');
select is(pg_temp.bad('papa', null, null, 'kind', current_date + 1, null), 'pack_item_invalid', 'a null title');
select is(pg_temp.bad('papa', null, null, 'kind', current_date + 1, repeat('x', 81)), 'pack_item_invalid', 'more than 80 characters');
select is(pg_temp.bad('papa', null, null, 'kind', null, 'x'), 'pack_item_invalid', 'no date');
select is(pg_temp.bad('papa', null, null, 'kind', current_date + 401, 'x'), 'pack_item_invalid', 'a date more than 400 days ahead');
select is(pg_temp.bad('papa', null, null, 'kind', current_date - 401, 'x'), 'pack_item_invalid', 'or back');
select is(pg_temp.bad('papa', null, null, null, current_date + 1, 'x'), 'pack_item_invalid', 'no child');
select is(pg_temp.bad('papa', null, null, 'opa', current_date + 1, 'x'), 'pack_item_invalid', 'an adult');
select is(pg_temp.bad('papa', null, null, 'ex', current_date + 1, 'x'), 'pack_item_invalid', 'a child who left');
select is(pg_temp.bad('papa', null, null, 'bkind', current_date + 1, 'x'), 'pack_item_invalid', 'another household''s child');
select is(pg_temp.bad('papa', null, 'bea', 'kind', current_date + 1, 'x'), 'pack_item_not_found', 'an id that is no thing');
select is(pg_temp.bad('ipad', null, null, 'kind', current_date + 1, 'x'), 'actor_required', 'a shared device must say who acts');
select is(pg_temp.bad('papa_old', null, null, 'kind', current_date + 1, 'x'), 'device_revoked', 'a revoked device writes nothing');
select is(pg_temp.snap(), (select v from snaps where name = 'refusals'), 'and none of those refusals wrote anything');
-- Twenty on a day, not twenty-one.
select pg_temp.save(null, 'papa', null, null, 'kind', current_date + 10, 'Ding ' || n) from generate_series(1, 20) n;
select is(pg_temp.bad('papa', null, null, 'kind', current_date + 10, 'Ding 21'), 'pack_item_invalid', 'a twenty-first thing on a day');
select is(pg_temp.bad('papa', null, 't3', 'kind', current_date + 10, 'Bastelsachen'), 'pack_item_invalid', 'nor moved there');

-- ---- 6. Another household --------------------------------------------------------------------------------
select is(pg_temp.bad('bea', null, 't2', 'bkind', current_date + 1, 'x'), 'pack_item_not_found', 'another household cannot change a thing');
select is(pg_temp.hint('bea', format('select api.pack_item_delete(null, %L)', pg_temp.id('t2'))), 'pack_item_not_found',
  'nor delete one');
select pg_temp.act_as_dev('bea');
select is((select count(*)::int from api.pack_items) + (select count(*)::int from app.pack_item), 0,
  'and reads none, neither in the view nor in the table');
select throws_ok($$ insert into app.pack_item (household_id, profile_id, on_date, title) select household_id, id, current_date, 'x' from app.profile limit 1 $$,
  '42501', null, 'nor writes one directly');

-- ---- 7. Reading ------------------------------------------------------------------------------------------
select pg_temp.act_as_dev('kiosk');
select is((select count(*)::int from api.pack_items), (select count(*)::int from app.pack_item where household_id = pg_temp.id('hh_a')),
  'the wall reads every thing of the household');
select pg_temp.act_as_dev('kind');
select is((select count(*)::int from api.pack_items where profile_id = pg_temp.id('kind2')), 3, 'a child reads its sibling''s things too');
select throws_ok($$ delete from app.pack_item $$, '42501', null, 'but deletes none directly');
select pg_temp.act_as_dev('papa_old');
select is((select count(*)::int from api.pack_items), 0, 'a revoked device reads nothing');
reset role;
set local role anon;
select is(pg_temp.state('select count(*) from api.pack_items') || '/' || pg_temp.state('select count(*) from app.pack_item'),
  '42501/42501', 'an anonymous caller reads neither the view nor the table');
select is(pg_temp.state(format('select api.pack_item_save(null, null, %L, current_date, ''x'')', pg_temp.id('kind'))),
  '42501', 'and may not save');
reset role;

-- ---- 8. Deleting and the audit ---------------------------------------------------------------------------
select is(pg_temp.hint('kind', format('select api.pack_item_delete(null, %L)', pg_temp.id('t3'))), 'no error', 'a child deletes its own thing');
select is((select count(*)::int from app.pack_item where id in (pg_temp.id('t3'), pg_temp.id('t2'))), 1, 'which is gone, the sibling''s stays');
select is((select coalesce(string_agg(w, ','), '') from unnest(array['create', 'update', 'delete']) w
            where not exists (select 1 from app.audit_log l where l.entity_type = 'pack_item' and l.action = w
                               and l.household_id = pg_temp.id('hh_a'))), '',
  'every kind of write left an audit row');

-- ---- 9. Siri's context ---------------------------------------------------------------------------------
create temp table tok (token text);
grant all on tok to public;
select pg_temp.act_as_dev('papa');
insert into tok select api.shortcut_token_create(null, null, 'iPhone') ->> 'token';
reset role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
create temp table ctx as
  select api.shortcut_context((select token from tok), array['school'], current_date + 1, 1) v
  union all
  select api.shortcut_context((select token from tok), array['meals'], current_date + 1, 1);
reset role;
select is((select jsonb_agg(e ->> 'title' order by e ->> 'title') from ctx, jsonb_array_elements(v -> 'pack') e
            where v ? 'school'),
  (select jsonb_agg(title order by title) from app.pack_item
    where household_id = pg_temp.id('hh_a') and on_date = current_date + 1),
  'with school, Siri''s context carries the household''s things of its window');
select ok((select bool_and(e ->> 'member_id' is not null and e ->> 'date' = (current_date + 1)::text)
             from ctx, jsonb_array_elements(v -> 'pack') e where v ? 'school'),
  'each with its child and day');
select ok((select not (v ? 'pack') from ctx where not (v ? 'school')), 'without school, none');

select * from finish();
rollback;
