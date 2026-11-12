begin;
select plan(56);

-- Receiving an event as a calendar file, migrations/20261112100000_event_import.sql: the origin
-- columns, api.event_import_lookup and api.event_import. Start from an empty system, whatever the
-- database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;
create temp table snap (k text primary key, v text);
grant all on snap to public;

-- Switches to the device's Auth user, as PostgREST would with its JWT.
create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
create function pg_temp.pid(p_name text) returns uuid language sql as $$
  select id from ids where name = p_name
$$;
-- A timed appointment as the app would send it after reading a file.
create function pg_temp.ev(p_title text, p_id uuid default null) returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', p_id, 'title', p_title, 'kind', 'appointment', 'is_all_day', false,
    'starts_at', '2026-11-20T14:00:00+01:00', 'ends_at', '2026-11-20T15:00:00+01:00'))
$$;

-- ---- household A: Papa (guardian, personal phone), Emma (child on the shared iPad), a kiosk, an old phone
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into app.profile (household_id, display_name, role, kind)
  select (r ->> 'household_id')::uuid, 'Emma', 'member', 'child' from sa;
insert into ids select lower(p.display_name), p.id from app.profile p where p.household_id = pg_temp.pid('hh_a');

insert into users values
  ('ipad', app.create_auth_user('ipad@devices.invalid', 'x1234567890')),
  ('kiosk', app.create_auth_user('kiosk@devices.invalid', 'x1234567890')),
  ('old', app.create_auth_user('old@example.org', 'longpassword1'));
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.pid('hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = pg_temp.pid('papa');
insert into app.device (household_id, auth_user_id, label, class, register)
  select pg_temp.pid('hh_a'), usr, 'iPad', 'shared', 'kid' from users where name = 'ipad';
insert into app.device (household_id, auth_user_id, label, class, register)
  select pg_temp.pid('hh_a'), usr, 'Kiosk', 'kiosk', 'kiosk' from users where name = 'kiosk';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  select pg_temp.pid('hh_a'), usr, 'Old-Phone', 'personal', 'adult', pg_temp.pid('papa'), now()
    from users where name = 'old';
insert into devs
  select 'papa', d.auth_user_id, d.id, d.household_id, 'personal' from app.device d where d.label = 'A-Phone'
  union all
  select 'ipad', u.usr, d.id, d.household_id, 'shared' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'ipad'
  union all
  select 'kiosk', u.usr, d.id, d.household_id, 'kiosk' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'kiosk'
  union all
  select 'old', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'old';

-- ---- household B, made by hand (setup closes after the first household) -------------------------------
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into users select 'b', app.create_auth_user('b@example.org', 'longpassword1');
insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.pid('hh_b'), 'B', 'guardian', usr from users where name = 'b';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.pid('hh_b'), u.usr, 'B-Phone', 'personal', 'adult', p.id
    from users u join app.profile p on p.auth_user_id = u.usr where u.name = 'b';
insert into devs
  select 'b', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id
   where u.name = 'b';

-- ---- the columns -----------------------------------------------------------------------------------------
select is((select string_agg(column_name, ', ' order by column_name) from information_schema.columns
            where table_schema = 'app' and table_name = 'event' and column_name like 'source\_%'),
  'source_sequence, source_uid', 'app.event carries source_uid and source_sequence');
select is((select count(*)::int from information_schema.columns
            where table_schema = 'api' and table_name = 'events' and column_name like 'source\_%'),
  0, 'api.events does not expose the origin');

-- ---- an import by a guardian -----------------------------------------------------------------------------
select pg_temp.act_as_dev('papa');
select lives_ok($$ insert into ids select 'imp', (api.event_import(null, pg_temp.ev('Elternabend'),
  'abc-123@school.example', 4) ->> 'id')::uuid $$, 'a guardian imports an event');
reset role;
select is((select source_uid from app.event where id = pg_temp.pid('imp')), 'abc-123@school.example',
  'the row keeps the file''s UID');
select is((select source_sequence from app.event where id = pg_temp.pid('imp')), 4,
  'and the file''s SEQUENCE');
select is((select uid from app.event where id = pg_temp.pid('imp')), pg_temp.pid('imp')::text || '@wuselwall.app',
  'the row keeps a uid of its own');
select is((select title from app.event where id = pg_temp.pid('imp')), 'Elternabend', 'the event is saved as sent');
select ok(exists (select 1 from app.audit_log where entity_type = 'event' and entity_id = pg_temp.pid('imp')
                    and action = 'import' and household_id = pg_temp.pid('hh_a')),
  'the import is written to the audit log');
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from api.events where id = pg_temp.pid('imp')), 1, 'the household sees the imported event');
select is(api.event_import_lookup(null, 'abc-123@school.example') ->> 'id', pg_temp.pid('imp')::text,
  'the lookup finds the imported event');
select is((api.event_import_lookup(null, 'abc-123@school.example') ->> 'sequence')::int, 4,
  'with the sequence it was received with');
select is((api.event_import_lookup(null, 'abc-123@school.example') ->> 'own')::boolean, false,
  'and it is not the household''s own');
select is((api.event_import_lookup(null, '  abc-123@school.example  ') ->> 'id'), pg_temp.pid('imp')::text,
  'surrounding blanks in the uid are ignored');
select is(api.event_import_lookup(null, 'unknown@elsewhere'), null::jsonb, 'an unknown uid finds nothing');
select is(api.event_import_lookup(null, ''), null::jsonb, 'an empty uid finds nothing');
select is(api.event_import_lookup(null, repeat('x', 513)), null::jsonb, 'a uid over 512 characters finds nothing');
select is(api.event_import_lookup(null, null), null::jsonb, 'a missing uid finds nothing');

-- ---- an event the household made itself ---------------------------------------------------------------------
insert into ids select 'own', (api.event_save(null, pg_temp.ev('Zahnarzt')) ->> 'id')::uuid;
reset role;
insert into snap select 'own_uid', uid from app.event where id = pg_temp.pid('own');
select pg_temp.act_as_dev('papa');
select is(api.event_import_lookup(null, (select v from snap where k = 'own_uid')) ->> 'id', pg_temp.pid('own')::text,
  'the lookup finds an event by its own uid');
select is((api.event_import_lookup(null, (select v from snap where k = 'own_uid')) ->> 'own')::boolean, true,
  'and reports it as the household''s own');
select is(api.event_import_lookup(null, (select v from snap where k = 'own_uid')) -> 'sequence', 'null'::jsonb,
  'an own event has no received sequence');

-- ---- an update -------------------------------------------------------------------------------------------------
select lives_ok($$ select api.event_import(null, pg_temp.ev('Elternabend (neu)', pg_temp.pid('imp')),
  'abc-123@school.example', 5) $$, 'an event received again is taken as an update of its row');
reset role;
select is((select title from app.event where id = pg_temp.pid('imp')), 'Elternabend (neu)', 'the update changes the title');
select is((select source_sequence from app.event where id = pg_temp.pid('imp')), 5, 'and the received sequence');
select is((select count(*)::int from app.event where household_id = pg_temp.pid('hh_a') and source_uid = 'abc-123@school.example'),
  1, 'there is still one row with that source uid');
select is((select uid from app.event where id = pg_temp.pid('imp')), pg_temp.pid('imp')::text || '@wuselwall.app',
  'an update keeps the row''s own uid');

-- ---- an id that was not received with that uid ---------------------------------------------------------------
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.event_import(null, pg_temp.ev('Zahnarzt', pg_temp.pid('own')), 'abc-123@school.example', 6) $$,
  'P0002', 'event not found', 'an own event is not updated through an import');
select throws_ok($$ select api.event_import(null, pg_temp.ev('Fremd', pg_temp.pid('imp')), 'other@school.example', 6) $$,
  'P0002', 'event not found', 'a row received with another uid is not updated');
select throws_ok($$ select api.event_import(null, pg_temp.ev('Nichts', gen_random_uuid()), 'abc-123@school.example', 6) $$,
  'P0002', 'event not found', 'an id that does not exist is not updated');
reset role;
select is((select title from app.event where id = pg_temp.pid('own')), 'Zahnarzt', 'the refused update changed nothing');

-- ---- refusals ----------------------------------------------------------------------------------------------------
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.event_import(null, pg_temp.ev('Leer'), '', 1) $$,
  '22023', 'WW-CAL-001 invalid event', 'an empty uid is refused');
select throws_ok($$ select api.event_import(null, pg_temp.ev('Leer'), '   ', 1) $$,
  '22023', 'WW-CAL-001 invalid event', 'a blank uid is refused');
select throws_ok($$ select api.event_import(null, pg_temp.ev('Lang'), repeat('x', 513), 1) $$,
  '22023', 'WW-CAL-001 invalid event', 'a uid over 512 characters is refused');
select throws_ok($$ select api.event_import(null, '{"title":"Da","kind":"presence","presence_state":"travel","is_all_day":true,
  "start_date":"2026-11-20","end_date":"2026-11-20"}'::jsonb, 'p@x', 1) $$,
  '22023', 'WW-CAL-001 invalid event', 'a presence entry is refused');
select throws_ok($$ select api.event_import(null, '[]'::jsonb, 'a@x', 1) $$,
  '22023', 'WW-CAL-001 invalid event', 'an event that is not an object is refused');
insert into ids select 'neg', (api.event_import(null, pg_temp.ev('Negativ'), 'neg@x', -3) ->> 'id')::uuid;
insert into ids select 'nul', (api.event_import(null, pg_temp.ev('Ohne'), 'nul@x') ->> 'id')::uuid;
reset role;
select is((select source_sequence from app.event where id = pg_temp.pid('neg')), 0, 'a negative sequence is stored as 0');
select is((select source_sequence from app.event where id = pg_temp.pid('nul')), 0, 'a missing sequence is stored as 0');

-- ---- another household ---------------------------------------------------------------------------------------------
select pg_temp.act_as_dev('b');
select is(api.event_import_lookup(null, 'abc-123@school.example'), null::jsonb, 'another household does not find the row of A');
select is(api.event_import_lookup(null, (select v from snap where k = 'own_uid')), null::jsonb,
  'nor the event A made itself');
select lives_ok($$ insert into ids select 'imp_b', (api.event_import(null, pg_temp.ev('Elternabend'),
  'abc-123@school.example', 4) ->> 'id')::uuid $$, 'another household imports the same file');
select throws_ok($$ select api.event_import(null, pg_temp.ev('Fremd', pg_temp.pid('imp')), 'abc-123@school.example', 9) $$,
  'P0002', 'event not found', 'another household cannot update the row of A by its id');
select is(api.event_import_lookup(null, 'abc-123@school.example') ->> 'id', pg_temp.pid('imp_b')::text,
  'its lookup finds its own row only');
reset role;
select is((select title from app.event where id = pg_temp.pid('imp')), 'Elternabend (neu)', 'A''s row was not touched');
select is((select count(*)::int from app.event where source_uid = 'abc-123@school.example'), 2,
  'the same file may sit in two households');

-- ---- who may call ----------------------------------------------------------------------------------------------------
select pg_temp.act_as_dev('ipad');
select throws_ok($$ select api.event_import((select id from ids where name = 'emma'), pg_temp.ev('Kind'), 'kid@x', 1) $$,
  '42501', 'guardian required', 'a child cannot import an event');
select throws_ok($$ select api.event_import_lookup((select id from ids where name = 'emma'), 'abc-123@school.example') $$,
  '42501', 'guardian required', 'a child cannot look an event up');
reset role;
select pg_temp.act_as_dev('kiosk');
select throws_ok($$ select api.event_import((select id from ids where name = 'papa'), pg_temp.ev('Kiosk'), 'k@x', 1) $$,
  '42501', 'not allowed on a kiosk', 'a kiosk cannot import an event');
select throws_ok($$ select api.event_import_lookup((select id from ids where name = 'papa'), 'abc-123@school.example') $$,
  '42501', 'not allowed on a kiosk', 'a kiosk cannot look an event up');
reset role;
select pg_temp.act_as_dev('old');
select throws_ok($$ select api.event_import(null, pg_temp.ev('Alt'), 'old@x', 1) $$,
  '42501', 'device not usable', 'a revoked phone cannot import an event');
select throws_ok($$ select api.event_import_lookup(null, 'abc-123@school.example') $$,
  '42501', 'device not usable', 'a revoked phone cannot look an event up');
reset role;
set local role anon;
select throws_ok($$ select api.event_import(null, '{}'::jsonb, 'a@x', 1) $$,
  '42501', 'permission denied for function event_import', 'anonymous callers cannot import an event');
select throws_ok($$ select api.event_import_lookup(null, 'a@x') $$,
  '42501', 'permission denied for function event_import_lookup', 'anonymous callers cannot look an event up');
reset role;
select is((select count(*)::int from app.event where source_uid in ('kid@x', 'k@x', 'old@x', 'a@x')), 0,
  'none of the refused calls wrote a row');

-- ---- a deleted event ------------------------------------------------------------------------------------------------
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.event_delete(null, pg_temp.pid('imp')) $$, 'a guardian deletes the imported event');
select is(api.event_import_lookup(null, 'abc-123@school.example'), null::jsonb, 'a deleted event is no longer found');
select throws_ok($$ select api.event_import(null, pg_temp.ev('Zurueck', pg_temp.pid('imp')), 'abc-123@school.example', 7) $$,
  'P0002', 'event not found', 'a deleted event cannot be updated by its id');
reset role;

-- ---- discovery -------------------------------------------------------------------------------------------------------
select ok(api.server_info() -> 'features' ? 'event-import', 'the server announces the event import');

select * from finish();
rollback;
