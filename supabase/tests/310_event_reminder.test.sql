begin;
select plan(38);

-- A reminder of its own for one event, migrations/20261114120000_event_reminder.sql: the column,
-- api.events, and what api.event_save takes, keeps, clears and refuses. Start from an empty
-- system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;

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
-- A timed appointment, with whatever p_more adds or replaces.
create function pg_temp.timed(p_title text, p_more jsonb default '{}', p_id uuid default null)
returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('id', p_id)) || jsonb_build_object(
    'title', p_title, 'kind', 'appointment', 'is_all_day', false,
    'starts_at', '2026-11-20T14:00:00+01:00', 'ends_at', '2026-11-20T15:00:00+01:00') || p_more
$$;
-- The same as an all-day event.
create function pg_temp.allday(p_title text, p_more jsonb default '{}', p_id uuid default null)
returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('id', p_id)) || jsonb_build_object(
    'title', p_title, 'kind', 'appointment', 'is_all_day', true,
    'start_date', '2026-11-20', 'end_date', '2026-11-20') || p_more
$$;
create function pg_temp.reminder(p_name text) returns int language sql as $$
  select reminder_minutes from app.event where id = pg_temp.pid(p_name)
$$;

-- ---- household A: Papa (guardian, personal phone); household B, made by hand -----------------------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select lower(p.display_name), p.id from app.profile p where p.household_id = pg_temp.pid('hh_a');
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.pid('hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = pg_temp.pid('papa');
insert into devs
  select 'papa', d.auth_user_id, d.id, d.household_id, 'personal' from app.device d where d.label = 'A-Phone';

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

-- ---- the column ------------------------------------------------------------------------------------------
select has_column('app', 'event', 'reminder_minutes', 'app.event carries the reminder');
select has_column('api', 'events', 'reminder_minutes', 'api.events shows it');
select is((select column_name::text from information_schema.columns
            where table_schema = 'api' and table_name = 'events' order by ordinal_position desc limit 1),
  'reminder_minutes', 'as the view''s last column: the ones before it keep their place');

-- ---- saving, keeping and clearing ------------------------------------------------------------------------
select pg_temp.act_as_dev('papa');
select lives_ok($$ insert into ids select 'plain', (api.event_save(null, pg_temp.timed('Turnen')) ->> 'id')::uuid $$,
  'an event without the key is saved as before');
select lives_ok($$ insert into ids select 'dentist', (api.event_save(null,
  pg_temp.timed('Zahnarzt', '{"reminder_minutes": 1440}')) ->> 'id')::uuid $$, 'an event is saved with a reminder');
select is((select reminder_minutes from api.events where id = pg_temp.pid('plain')), null::int,
  'an event has no reminder unless one is set');
select is((select reminder_minutes from api.events where id = pg_temp.pid('dentist')), 1440,
  'the household reads the reminder with the event');
reset role;
select ok(exists (select 1 from app.audit_log where entity_type = 'event' and entity_id = pg_temp.pid('dentist')
                    and action = 'flags' and (diff ->> 'reminder_minutes')::int = 1440),
  'the reminder is written to the audit log');

select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.event_save(null, pg_temp.timed('Zahnarzt Dr. Blum', '{}', pg_temp.pid('dentist'))) $$,
  'an app that does not know the reminder saves the event');
reset role;
select is(pg_temp.reminder('dentist'), 1440, 'and the reminder stays');
select is((select title from app.event where id = pg_temp.pid('dentist')), 'Zahnarzt Dr. Blum', 'with the change it made');

select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.event_save(null,
  pg_temp.timed('Zahnarzt', '{"reminder_minutes": 30}', pg_temp.pid('dentist'))) $$, 'the reminder is changed');
reset role;
select is(pg_temp.reminder('dentist'), 30, 'to the new lead time');
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.event_save(null,
  pg_temp.timed('Zahnarzt', '{"reminder_minutes": null}', pg_temp.pid('dentist'))) $$, 'null is taken');
reset role;
select is(pg_temp.reminder('dentist'), null::int, 'and clears the reminder');
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.event_save(null,
  pg_temp.timed('Zahnarzt', '{"reminder_minutes": 0}', pg_temp.pid('dentist'))) $$, 'zero is "when it starts"');
select lives_ok($$ select api.event_save(null,
  pg_temp.timed('Zahnarzt', '{"reminder_minutes": 40320}', pg_temp.pid('dentist'))) $$, 'four weeks is the longest');
reset role;
select is(pg_temp.reminder('dentist'), 40320, 'and is stored');

-- ---- what is refused -------------------------------------------------------------------------------------
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.event_save(null, pg_temp.timed('X', '{"reminder_minutes": -5}')) $$,
  '22023', 'WW-CAL-001 invalid event', 'a negative reminder is refused');
select throws_ok($$ select api.event_save(null, pg_temp.timed('X', '{"reminder_minutes": 40321}')) $$,
  '22023', 'WW-CAL-001 invalid event', 'more than four weeks is refused');
select throws_ok($$ select api.event_save(null, pg_temp.timed('X', '{"reminder_minutes": 12.5}')) $$,
  '22023', 'WW-CAL-001 invalid event', 'a fraction of a minute is refused');
select throws_ok($$ select api.event_save(null, pg_temp.timed('X', '{"reminder_minutes": "30"}')) $$,
  '22023', 'WW-CAL-001 invalid event', 'a text is refused');
select throws_ok($$ select api.event_save(null, pg_temp.timed('X', '{"reminder_minutes": true}')) $$,
  '22023', 'WW-CAL-001 invalid event', 'a flag is refused');
select throws_ok($$ select api.event_save(null,
  pg_temp.timed('Zahnarzt', '{"reminder_minutes": 99999}', pg_temp.pid('dentist'))) $$,
  '22023', 'WW-CAL-001 invalid event', 'a refused reminder on an existing event');
reset role;
select is(pg_temp.reminder('dentist'), 40320, 'leaves the stored one as it was');
select is((select count(*)::int from app.event where title = 'X'), 0, 'none of the refused calls wrote a row');

-- ---- an all-day event counts in whole days ---------------------------------------------------------------
select pg_temp.act_as_dev('papa');
select lives_ok($$ insert into ids select 'party', (api.event_save(null,
  pg_temp.allday('Geburtstagsfest', '{"reminder_minutes": 2880}')) ->> 'id')::uuid $$,
  'an all-day event takes a reminder of whole days');
select throws_ok($$ select api.event_save(null, pg_temp.allday('X', '{"reminder_minutes": 30}')) $$,
  '22023', 'WW-CAL-001 invalid event', 'but not one of minutes');
select throws_ok($$ select api.event_save(null, pg_temp.allday('X', '{"reminder_minutes": 2000}')) $$,
  '22023', 'WW-CAL-001 invalid event', 'and not a day and a bit');
-- An older app turns events into the other kind of timing without sending the key.
select lives_ok($$ select api.event_save(null, pg_temp.timed('Geburtstagsfest', '{}', pg_temp.pid('party'))) $$,
  'an all-day event with a reminder becomes a timed one');
reset role;
select is(pg_temp.reminder('party'), 2880, 'and keeps its two days');
update app.event set reminder_minutes = 30 where id = pg_temp.pid('party');
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.event_save(null, pg_temp.allday('Geburtstagsfest', '{}', pg_temp.pid('party'))) $$,
  'a timed event with a reminder of minutes becomes an all-day one');
reset role;
select is(pg_temp.reminder('party'), null::int, 'and loses a reminder it can no longer carry');

-- ---- a presence entry reminds nobody ---------------------------------------------------------------------
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.event_save(null, pg_temp.timed('Dienstreise',
  '{"kind": "presence", "presence_state": "travel", "reminder_minutes": 60}')) $$,
  '22023', 'WW-CAL-001 invalid event', 'a presence entry with a reminder is refused');
select lives_ok($$ select api.event_save(null, pg_temp.timed('Dienstreise',
  '{"kind": "presence", "presence_state": "travel"}', pg_temp.pid('dentist'))) $$,
  'an event with a reminder becomes a presence entry');
reset role;
select is(pg_temp.reminder('dentist'), null::int, 'and its reminder is cleared');

-- ---- the perimeter and discovery -------------------------------------------------------------------------
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.events), 0, 'another household reads none of it');
reset role;
select ok(api.server_info() -> 'features' ?& array['event-reminder', 'shopping-start', 'event-import'],
  'the server announces the event reminder beside the features before it');

select * from finish();
rollback;
