begin;
select plan(54);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d record;
begin
  select * into d from pg_temp.devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- Named devices of the test, so the act_as helper can find them.
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;

-- ---- household A: Papa (guardian, phone), Emma (child, phone), iPad, kiosk, revoked phone ----
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into app.profile (household_id, display_name, role, kind)
  select (r ->> 'household_id')::uuid, 'Emma', 'member', 'child' from sa;
create temp table users (name text primary key, usr uuid);
grant all on users to public;
insert into users values
  ('emma', app.create_auth_user('emma@example.org', 'longpassword1')),
  ('ipad', app.create_auth_user('ipad@devices.invalid', 'x1234567890')),
  ('kiosk', app.create_auth_user('kiosk@devices.invalid', 'x1234567890')),
  ('old', app.create_auth_user('old@example.org', 'longpassword1'));
update app.profile set auth_user_id = (select usr from users where name = 'emma')
 where display_name = 'Emma';

insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select p.household_id, p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.display_name = 'Papa';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select p.household_id, p.auth_user_id, 'Emma-Phone', 'personal', 'kid', p.id
    from app.profile p where p.display_name = 'Emma';
insert into app.device (household_id, auth_user_id, label, class, register)
  select p.household_id, u.usr, 'iPad', 'shared', 'kid' from users u
    cross join (select household_id from app.profile where display_name = 'Papa') p where u.name = 'ipad';
insert into app.device (household_id, auth_user_id, label, class, register)
  select p.household_id, u.usr, 'Kiosk', 'kiosk', 'kiosk' from users u
    cross join (select household_id from app.profile where display_name = 'Papa') p where u.name = 'kiosk';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  select p.household_id, u.usr, 'Old-Phone', 'personal', 'adult', p.id, now()
    from users u cross join (select household_id, id from app.profile where display_name = 'Papa') p
   where u.name = 'old';

-- Household data, including things that must never leave the database.
insert into app.shopping_list (household_id)
  select household_id from app.profile where display_name = 'Papa';
insert into app.shopping_item (list_id, household_id, name, folded_name)
  select l.id, l.household_id, 'Milch-A', 'milch-a' from app.shopping_list l;
insert into app.calendar_feed_token (household_id, label, token_hash)
  select household_id, 'Familienkalender', 'feedtokenhash-A-0123456789' from app.profile where display_name = 'Papa';

insert into devs
  select 'papa', p.auth_user_id, d.id, d.household_id, 'personal' from app.device d
    join app.profile p on p.id = d.profile_id where d.label = 'A-Phone'
  union all
  select 'emma', u.usr, d.id, d.household_id, 'personal' from app.device d
    join users u on u.usr = d.auth_user_id where u.name = 'emma'
  union all
  select 'ipad', u.usr, d.id, d.household_id, 'shared' from app.device d
    join users u on u.usr = d.auth_user_id where u.name = 'ipad'
  union all
  select 'kiosk', u.usr, d.id, d.household_id, 'kiosk' from app.device d
    join users u on u.usr = d.auth_user_id where u.name = 'kiosk'
  union all
  select 'old', u.usr, d.id, d.household_id, 'personal' from app.device d
    join users u on u.usr = d.auth_user_id where u.name = 'old';

-- ---- household B: Bruno (guardian), his phone and a shopping item -----------------------------
insert into app.household (name) values ('Bruno-Haushalt');
insert into users values ('bruno', app.create_auth_user('bruno@example.org', 'longpassword1'));
insert into app.profile (household_id, display_name, role, auth_user_id)
  select h.id, 'Bruno', 'guardian', (select usr from users where name = 'bruno')
    from app.household h where h.name = 'Bruno-Haushalt';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select p.household_id, p.auth_user_id, 'Bruno-Phone', 'personal', 'adult', p.id
    from app.profile p where p.display_name = 'Bruno';
insert into app.shopping_list (household_id)
  select household_id from app.profile where display_name = 'Bruno';
insert into app.shopping_item (list_id, household_id, name, folded_name)
  select l.id, l.household_id, 'Geheimes-B', 'geheimes-b' from app.shopping_list l
   where l.household_id = (select household_id from app.profile where display_name = 'Bruno');
insert into devs
  select 'bruno', p.auth_user_id, d.id, d.household_id, 'personal' from app.device d
    join app.profile p on p.id = d.profile_id where d.label = 'Bruno-Phone';

-- ---- the guardian on a personal phone gets the export --------------------------------------
select is((select count(*)::int from app.audit_log al join app.household h on h.id = al.household_id
            where h.name = 'A' and al.action = 'export'), 0, 'no export has been written yet');

select pg_temp.act_as_dev('papa');
select lives_ok($$ select set_config('test.export_papa', api.household_export(null)::text, false) $$,
  'a guardian on a personal phone exports the household');
reset role;

select is(current_setting('test.export_papa')::jsonb ->> 'format', 'wuselwall-export', 'the export is marked as a WuselWall export');
select is((current_setting('test.export_papa')::jsonb ->> 'version')::int, 1, 'the export carries format version 1');
select ok(current_setting('test.export_papa')::jsonb ->> 'exported_at' is not null, 'the export says when it was made');
select is(current_setting('test.export_papa')::jsonb #>> '{household,name}', 'A', 'the household itself is exported');
select is(jsonb_array_length(current_setting('test.export_papa')::jsonb #> '{tables,profile}'), 2,
  'both members are exported');
select is(jsonb_array_length(current_setting('test.export_papa')::jsonb #> '{tables,device}'), 5,
  'every device is listed, the revoked one too');
select is(jsonb_array_length(current_setting('test.export_papa')::jsonb #> '{tables,shopping_item}'), 1,
  'shopping items are exported');
select is(jsonb_array_length(current_setting('test.export_papa')::jsonb #> '{tables,calendar_feed_token}'), 1,
  'calendar feed tokens are exported without their secret');
select is((select count(*)::int
             from jsonb_each(current_setting('test.export_papa')::jsonb -> 'tables') t,
                  jsonb_array_elements(t.value) r
            where r ? 'household_id' and r ->> 'household_id' <> (select household_id::text from app.profile where display_name = 'Papa')),
  0, 'no row of another household appears in the export');
select is(position('Bruno' in current_setting('test.export_papa')) + position('Geheimes-B' in current_setting('test.export_papa')), 0,
  'nothing of household B appears in the export of household A');
select is((select count(*)::int from jsonb_array_elements(current_setting('test.export_papa')::jsonb #> '{tables,device}') d
            where d ->> 'label' = 'A-Phone'), 1, 'devices are exported with their label');
select is((select count(*)::int from jsonb_array_elements(current_setting('test.export_papa')::jsonb #> '{tables,device}') d
            where d ? 'auth_user_id' or d ? 'auth_session_id' or d ? 'guardian_verified_until'),
  0, 'devices carry no Auth ids or verification state');

select is((select coalesce(string_agg(k, ', '), '') from unnest(array[
  'pin_hash', 'pin_failures', 'pin_locked_until', 'auth_user_id', 'auth_session_id', 'token_hash', 'code_hash',
  '$2a$', '$2b$', 'feedtokenhash-A-0123456789', 'longpassword1',
  (select auth_user_id::text from app.profile where display_name = 'Papa')]) k
  where position(k in current_setting('test.export_papa')) > 0), '',
  'no secret, Auth id or token hash appears anywhere in the JSON');

select is((select count(*)::int from app.audit_log al join app.household h on h.id = al.household_id
            where h.name = 'A' and al.action = 'export' and al.entity_type = 'household' and al.entity_id = h.id),
  1, 'the export is written to the audit log');

select ok(not (current_setting('test.export_papa')::jsonb -> 'tables') ?| array['region', 'holiday_feed', 'holiday_feed_sync', 'setting_definition', 'enrolment_code'],
  'public reference data and one-time codes are not household data and are not exported');

-- ---- the paged export (format version 2) ------------------------------------------------------
-- Enough rows to need several pages: five shopping items, three closed days (a two-column key).
insert into app.shopping_item (list_id, household_id, name, folded_name)
  select l.id, l.household_id, 'Milch-A' || n, 'milch-a' || n from app.shopping_list l, generate_series(2, 5) n
   where l.household_id = (select household_id from app.profile where display_name = 'Papa');
insert into app.tasks_day_closed (household_id, day)
  select household_id, date '2024-01-01' + n from app.profile, generate_series(0, 2) n where display_name = 'Papa';

create temp table pages (tbl text, n int, page jsonb);
grant all on pages to public;
create function pg_temp.page_through(p_table text, p_limit int) returns void language plpgsql as $$
declare v_after jsonb; v_page jsonb; n int := 0;
begin
  loop
    v_page := api.household_export_page(null, p_table, v_after, p_limit);
    n := n + 1;
    insert into pg_temp.pages values (p_table, n, v_page);
    v_after := v_page -> 'next';
    exit when jsonb_typeof(v_after) is distinct from 'object' or n > 20;
  end loop;
end $$;

select pg_temp.act_as_dev('papa');
select lives_ok($$ select set_config('test.begin_papa', api.household_export_begin(null)::text, false) $$,
  'a guardian on a personal phone starts a paged export');
select pg_temp.page_through('shopping_item', 2);
select pg_temp.page_through('tasks_day_closed', 2);
select pg_temp.page_through('calendar_feed_token', 1000);
select pg_temp.page_through('device', 1000);
select throws_ok($$ select api.household_export_page(null, 'region') $$, '22023', 'unknown export table',
  'a table that is not on the export list is refused');
select throws_ok($$ select api.household_export_page(null, 'shopping_item', null, 0) $$, '22023', 'page size out of range',
  'a page size below one is refused');
select throws_ok($$ select api.household_export_page(null, 'shopping_item', null, 5001) $$, '22023', 'page size out of range',
  'a page size above 5000 is refused');
reset role;

select is((select count(*)::int from app.audit_log al join app.household h on h.id = al.household_id
            where h.name = 'A' and al.action = 'export'), 2, 'starting a paged export writes one audit row; pages write none');
select is((current_setting('test.begin_papa')::jsonb ->> 'version')::int, 2, 'the paged export is format version 2');
select is(current_setting('test.begin_papa')::jsonb #>> '{household,name}', 'A', 'the paged export starts with the household');
select is(current_setting('test.begin_papa')::jsonb -> 'tables',
  (select jsonb_agg(name order by position) from app.export_table), 'it names the tables to read, in order');

select is((select count(*)::int from pages where tbl = 'shopping_item'), 3, 'five rows in pages of two are three pages');
select is((select array_agg(jsonb_array_length(page -> 'rows') order by n) from pages where tbl = 'shopping_item'),
  array[2, 2, 1], 'every page but the last is full');
select is((select count(distinct r ->> 'id')::int from pages p, jsonb_array_elements(p.page -> 'rows') r where tbl = 'shopping_item'),
  5, 'every row comes exactly once across the pages');
select ok((select bool_and(prev is null or id > prev) from (
             select (r ->> 'id')::uuid id, lag((r ->> 'id')::uuid) over (order by p.n, o) prev
               from pages p, jsonb_array_elements(p.page -> 'rows') with ordinality e(r, o) where tbl = 'shopping_item') x),
  'the rows come in key order');
select is((select page -> 'next' from pages where tbl = 'shopping_item' and n = 3), 'null'::jsonb,
  'the last page has no cursor');
select is((select count(*)::int from pages p, jsonb_array_elements(p.page -> 'rows') r
            where tbl = 'shopping_item' and r ->> 'name' = 'Geheimes-B'), 0, 'pages carry no row of another household');
select is((select array_agg(r ->> 'day' order by p.n, o) from pages p, jsonb_array_elements(p.page -> 'rows') with ordinality e(r, o)
            where tbl = 'tasks_day_closed'), array['2024-01-01', '2024-01-02', '2024-01-03'],
  'a table with a two-column key pages through every row once, in order');
select is((select count(*)::int from pages p, jsonb_array_elements(p.page -> 'rows') r
            where tbl = 'calendar_feed_token' and (r ? 'token_hash' or r::text like '%feedtokenhash%')), 0,
  'pages carry no token hash');
select is((select count(*)::int from pages p, jsonb_array_elements(p.page -> 'rows') r
            where tbl = 'calendar_feed_token'), 1, 'the feed token itself is exported');
select is((select coalesce(string_agg(distinct k, ', '), '') from pages p, jsonb_array_elements(p.page -> 'rows') r, jsonb_object_keys(r) k
            where tbl = 'device' and k <> all (array['id', 'label', 'class', 'register', 'profile_id',
                                                      'created_at', 'last_seen_at', 'revoked_at'])), '',
  'device pages carry only label, class, holder and dates');
select is((select count(*)::int from pages p, jsonb_array_elements(p.page -> 'rows') r where tbl = 'device'), 5,
  'device pages list every device');

-- ---- household B's guardian gets only B -----------------------------------------------------
select pg_temp.act_as_dev('bruno');
select lives_ok($$ select set_config('test.export_bruno', api.household_export(null)::text, false) $$,
  'the guardian of another household exports only that household');
reset role;
select is(position('Milch-A' in current_setting('test.export_bruno')), 0, 'household A data is not in the export of B');
select is(position('Geheimes-B' in current_setting('test.export_bruno')) > 0, true, 'household B data is in the export of B');

-- ---- refusals ----------------------------------------------------------------------------------
select pg_temp.act_as_dev('emma');
select throws_ok($$ select api.household_export(null) $$, '42501', 'guardian required',
  'a child on a personal phone is refused');
reset role;

select pg_temp.act_as_dev('kiosk');
select throws_ok($$ select api.household_export((select id from app.profile where display_name = 'Papa')) $$, '42501',
  'guardian required', 'a kiosk is refused, even with a guardian as the acting profile');
reset role;

select pg_temp.act_as_dev('ipad');
select throws_ok($$ select api.household_export((select id from app.profile where display_name = 'Papa')) $$, '42501',
  'guardian required', 'a shared iPad without a guardian verification is refused');
reset role;

update app.device set guardian_verified_until = now() + interval '10 minutes',
       guardian_verified_profile = (select id from app.profile where display_name = 'Papa') where label = 'iPad';
select pg_temp.act_as_dev('ipad');
select throws_ok($$ select api.household_export((select id from app.profile where display_name = 'Papa')) $$, '42501',
  'personal device required', 'a shared device is refused even after a guardian verified it');
reset role;
update app.device set guardian_verified_until = null, guardian_verified_profile = null where label = 'iPad';

select pg_temp.act_as_dev('old');
select throws_ok($$ select api.household_export(null) $$, '42501', 'device not usable',
  'a revoked phone is refused');
reset role;

set local role anon;
select throws_ok($$ select api.household_export(null) $$, '42501', 'permission denied for function household_export',
  'anonymous callers cannot export');
reset role;

select pg_temp.act_as_dev('emma');
select throws_ok($$ select api.household_export_begin(null) $$, '42501', 'guardian required',
  'a child cannot start a paged export');
select throws_ok($$ select api.household_export_page(null, 'profile') $$, '42501', 'guardian required',
  'a child cannot read a page');
reset role;

select pg_temp.act_as_dev('ipad');
select throws_ok($$ select api.household_export_page((select id from app.profile where display_name = 'Papa'), 'profile') $$,
  '42501', 'guardian required', 'a shared iPad cannot read a page');
reset role;

set local role anon;
select throws_ok($$ select api.household_export_begin(null) $$, '42501', 'permission denied for function household_export_begin',
  'anonymous callers cannot start a paged export');
select throws_ok($$ select api.household_export_page(null, 'profile') $$, '42501', 'permission denied for function household_export_page',
  'anonymous callers cannot read a page');
reset role;

-- ---- the guard: no household table can be forgotten silently ----------------------------------
-- Every app table with a household_id column is either on the export list (app.export_table) or
-- listed here on purpose. A new table fails this test until someone decides which it is.
-- proposal (specs/24): an assistant's payload waiting for a verdict, gone after 14 days; what a
-- guardian applied is in the exported timetables.
select is((select coalesce(string_agg(c.relname, ', ' order by c.relname), '') from pg_attribute a
            join pg_class c on c.oid = a.attrelid join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'app' and c.relkind in ('r', 'p') and a.attname = 'household_id'
             and not a.attisdropped
             and c.relname <> all (array['enrolment_code', 'busy_until', 'shopping_op', 'shopping_item_alias',
                                       'getting_started_dismissal', 'notice_dismissal', 'external_occurrence',
                                       'pairing_request', 'proposal'])
             and not exists (select 1 from app.export_table t where t.name = c.relname)),
  '', 'every household table is exported or excluded on purpose');

select is((select array_agg(k order by k) from jsonb_object_keys(current_setting('test.export_papa')::jsonb -> 'tables') k),
  (select array_agg(name order by name) from app.export_table), 'the one-document export carries every table of the list');

select is((select coalesce(string_agg(name, ', '), '') from app.export_table k
            where not exists (select 1 from pg_attribute a join pg_class c on c.oid = a.attrelid
                                join pg_namespace n on n.oid = c.relnamespace
                               where n.nspname = 'app' and c.relname = k.name and a.attname = 'household_id' and not a.attisdropped)),
  '', 'every exported table is an app table with a household_id');

select is((select count(*)::int from information_schema.tables t
            where t.table_schema = 'app' and t.table_name in ('region', 'holiday_feed', 'holiday_feed_sync', 'setting_definition', 'enrolment_code')
              and t.table_name in (select name from app.export_table)),
  0, 'no reference table is exported');

select * from finish();
rollback;
