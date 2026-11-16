begin;
select plan(247);

-- Family trips (specs/30), migrations/20261115110000_trips.sql: the tables and views, every write
-- function with its rules, the calendar entry that belongs to a trip, the combinations, the
-- checks and the home place. Start from an empty system, whatever the database already holds
-- (all rolled back).
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

-- Runs p_sql (one select that answers a jsonb) as device p_dev.
create function pg_temp.call(p_dev text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as_dev(p_dev);
  execute p_sql into r;
  reset role;
  return r;
end $$;

-- The same for a statement without an answer.
create function pg_temp.run(p_dev text, p_sql text) returns void language plpgsql as $$
begin
  perform pg_temp.act_as_dev(p_dev);
  execute p_sql;
  reset role;
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

-- The same as the current role.
create function pg_temp.error_hint(p_sql text) returns text language plpgsql as $$
declare v_hint text;
begin
  execute p_sql;
  return 'no error';
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint;
  return v_hint;
end $$;

-- The SQLSTATE of the error p_sql raises (as the current role), or 'ok'.
create function pg_temp.state(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end $$;

-- Saves a trip / entry / combo / check / checks as p_dev; the new id is kept under p_name.
create function pg_temp.reg(p_name text, p_result jsonb) returns jsonb language plpgsql as $$
begin
  if p_name is not null and p_result ? 'id' then
    insert into ids values (p_name, (p_result ->> 'id')::uuid)
      on conflict (name) do update set id = excluded.id;
  end if;
  return p_result;
end $$;
create function pg_temp.trip(p_name text, p_json text, p_dev text default 'papa') returns jsonb language sql as $$
  select pg_temp.reg(p_name, pg_temp.call(p_dev, 'select api.trip_save(null, ' || quote_literal(p_json) || '::jsonb)'))
$$;
create function pg_temp.entry(p_name text, p_json text, p_dev text default 'papa') returns jsonb language sql as $$
  select pg_temp.reg(p_name, pg_temp.call(p_dev, 'select api.trip_entry_save(null, ' || quote_literal(p_json) || '::jsonb)'))
$$;
create function pg_temp.combo(p_name text, p_json text, p_dev text default 'papa') returns jsonb language sql as $$
  select pg_temp.reg(p_name, pg_temp.call(p_dev, 'select api.trip_combo_save(null, ' || quote_literal(p_json) || '::jsonb)'))
$$;
create function pg_temp.chk(p_name text, p_json text, p_dev text default 'papa') returns jsonb language sql as $$
  select pg_temp.reg(p_name, pg_temp.call(p_dev, 'select api.trip_check_save(null, ' || quote_literal(p_json) || '::jsonb)'))
$$;
-- The hint of saving p_json through the function p_fn, as p_dev.
create function pg_temp.bad(p_fn text, p_json text, p_dev text default 'papa') returns text language sql as $$
  select pg_temp.hint(p_dev, 'select api.' || p_fn || '(null, ' || quote_literal(p_json) || '::jsonb)')
$$;
-- A snapshot of what the trip functions write: row counts and the audit log.
create function pg_temp.snap() returns text language sql as $$
  select (select count(*) from app.trip)::text || '/' || (select count(*) from app.trip_member) || '/'
      || (select count(*) from app.trip_entry) || '/' || (select count(*) from app.trip_combo) || '/'
      || (select count(*) from app.trip_combo_entry) || '/' || (select count(*) from app.trip_check) || '/'
      || (select count(*) from app.trip_home) || '/' || (select count(*) from app.event) || '/'
      || (select count(*) from app.audit_log) || '/' || (select coalesce(sum(sequence), 0) from app.event)
$$;
create function pg_temp.eid(p_trip text) returns uuid language sql as $$
  select e.id from app.event e where e.trip_id = pg_temp.id(p_trip) and e.deleted_at is null
$$;

-- ---- household A: Papa and Mama (guardians), Opa (an adult member), two children; B: Bea ---------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;
insert into users select 'papa', auth_user_id from app.profile where id = pg_temp.id('papa');
insert into users select n, app.create_auth_user(n || '@example.org', 'longpassword1')
  from unnest(array['bea', 'mama', 'opa', 'kind', 'papa_old', 'ipad', 'kiosk']) n;

insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
with ins as (insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_b'), 'Bea', 'guardian', usr from users where name = 'bea' returning id)
insert into ids select 'bea', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_a'), 'Mama', 'guardian', usr from users where name = 'mama' returning id)
insert into ids select 'mama', id from ins;
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
  select pg_temp.id('hh_a'), 'Ex', 'member', 'adult', false returning id)
insert into ids select 'ex', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, kind)
  select pg_temp.id('hh_b'), 'BKind', 'member', 'child' returning id)
insert into ids select 'bkind', id from ins;

select pg_temp.add_dev('papa', 'papa', 'hh_a', 'papa', 'personal', 'adult');
select pg_temp.add_dev('bea', 'bea', 'hh_b', 'bea', 'personal', 'adult');
select pg_temp.add_dev('mama', 'mama', 'hh_a', 'mama', 'personal', 'adult');
select pg_temp.add_dev('opa', 'opa', 'hh_a', 'opa', 'personal', 'adult');
select pg_temp.add_dev('kind', 'kind', 'hh_a', 'kind', 'personal', 'kid');
select pg_temp.add_dev('ipad', 'ipad', 'hh_a', null, 'shared', 'adult');
select pg_temp.add_dev('kiosk', 'kiosk', 'hh_a', null, 'kiosk', 'kiosk');
select pg_temp.add_dev('papa_old', 'papa_old', 'hh_a', 'papa', 'personal', 'adult', true);

-- ---- 1. The announcement and the shape --------------------------------------------------------------
select ok(api.server_info() -> 'features' ?& array['trips', 'services'], 'the server announces trips and services');
select has_column('app', 'event', 'trip_id', 'a calendar entry can belong to a trip');
select is((select column_name::text from information_schema.columns
            where table_schema = 'api' and table_name = 'events' order by ordinal_position desc limit 1),
  'trip_id', 'api.events shows it as its last column: the ones before it keep their place');
select is((select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns
            where table_schema = 'api' and table_name = 'trips'),
  'id,title,icon_key,stage,destination_name,destination_key,country,lat,lon,starts_on,ends_on,note,currency,created_by_profile_id,created_at,updated_at,member_ids,event_id',
  'api.trips');
select is((select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns
            where table_schema = 'api' and table_name = 'trip_entries'),
  'id,trip_id,kind,mode,title,state,url,price_cents,price_checked_on,details,note,from_place,to_place,booking_ref,cancel_until,address,phone,lat,lon,starts_on,starts_time,ends_on,ends_time,position,source_uid,created_by_profile_id,created_at,updated_at',
  'api.trip_entries');
select is((select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns
            where table_schema = 'api' and table_name = 'trip_combos'),
  'id,trip_id,name,position,created_by_profile_id,created_at,updated_at,entry_ids', 'api.trip_combos');
select is((select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns
            where table_schema = 'api' and table_name = 'trip_checks'),
  'id,trip_id,kind,title,profile_id,due_days_before,done_at,done_by_profile_id,position,created_at', 'api.trip_checks');
select is((select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns
            where table_schema = 'api' and table_name = 'trip_home'),
  'name,lat,lon,updated_at', 'api.trip_home');

-- ---- 2. Making a trip -----------------------------------------------------------------------------------
select is(pg_temp.trip('sard', '{"title": "Sardinien", "icon_key": "beach", "destination_name": "Sardinien", "country": "IT", "lat": 40.1, "lon": 9.0, "destination_key": "sardinia"}') ->> 'event_id',
  null, 'an idea is saved without a calendar entry');
select is((select stage || ':' || currency || ':' || note || ':' || created_by_profile_id::text from app.trip where id = pg_temp.id('sard')),
  'idea:EUR::' || pg_temp.id('papa')::text, 'it is an idea, the currency is euro without a region, the note empty, the creator the actor');
select is((select count(*)::int from app.event where trip_id is not null), 0, 'and the calendar has nothing of it');

select lives_ok($$ select pg_temp.trip('sard', format('{"id": "%s", "note": "warm"}', pg_temp.id('sard'))) $$,
  'saving again with the same id updates');
select is((select title || ':' || note || ':' || destination_name from app.trip where id = pg_temp.id('sard')), 'Sardinien:warm:Sardinien',
  'a key that is left out keeps its value');
select lives_ok($$ select pg_temp.trip('sard', format('{"id": "%s", "note": "warm"}', pg_temp.id('sard'))) $$, 'and the same call again');
select is((select count(*)::int from app.trip), 1, 'is idempotent');
select lives_ok($$ select pg_temp.trip('sard', format('{"id": "%s", "destination_name": null, "icon_key": "", "lat": null, "lon": null}', pg_temp.id('sard'))) $$,
  'null and empty clear an optional value');
select is((select coalesce(destination_name, 'none') || ':' || coalesce(icon_key, 'none') || ':' || coalesce(lat::text, 'none') from app.trip where id = pg_temp.id('sard')),
  'none:none:none', 'name, picture and place');
select pg_temp.trip('sard', format('{"id": "%s", "destination_name": "Sardinien", "icon_key": "beach"}', pg_temp.id('sard')));

-- The currency: the last trip's, else the region's.
update app.trip set created_at = now() - interval '3 days' where id = pg_temp.id('sard');
select is(pg_temp.trip('nord', '{"title": "Nordsee", "currency": "sek"}') is not null, true, 'a trip with a currency of its own');
select is((select currency from app.trip where id = pg_temp.id('nord')), 'SEK', 'is kept, in capitals');
update app.trip set created_at = now() - interval '2 days' where id = pg_temp.id('nord');
select pg_temp.trip('ostsee', '{"title": "Ostsee"}');
select is((select currency from app.trip where id = pg_temp.id('ostsee')), 'SEK', 'a trip without one takes the currency of the household''s last trip');
insert into app.household_setting (household_id, key, value) values (pg_temp.id('hh_b'), 'household.region', '"CH-ZH"');
select pg_temp.trip('b1', '{"title": "Tessin"}', 'bea');
select is((select currency from app.trip where id = pg_temp.id('b1')), 'CHF', 'the first trip of a household in Switzerland is in francs');
select pg_temp.run('bea', format('select api.trip_delete(null, %L)', pg_temp.id('b1')));
update app.household_setting set value = '"LI"' where household_id = pg_temp.id('hh_b') and key = 'household.region';
select pg_temp.trip('b2', '{"title": "Wallis"}', 'bea');
select is((select currency from app.trip where id = pg_temp.id('b2')), 'CHF', 'a household in Liechtenstein as well');
select pg_temp.run('bea', format('select api.trip_delete(null, %L)', pg_temp.id('b2')));
update app.household_setting set value = '"DE-BY"' where household_id = pg_temp.id('hh_b') and key = 'household.region';
select pg_temp.trip('b3', '{"title": "Bodensee"}', 'bea');
select is((select currency from app.trip where id = pg_temp.id('b3')), 'EUR', 'and one in Bavaria in euro');

create function pg_temp.members(p_trip text) returns uuid[] language sql as $$
  select coalesce(array_agg(profile_id order by profile_id), '{}') from app.trip_member where trip_id = pg_temp.id(p_trip)
$$;
create function pg_temp.ids_of(variadic p_names text[]) returns uuid[] language sql as $$
  select coalesce(array_agg(id order by id), '{}') from ids where name = any (p_names)
$$;
-- The calendar entry of a trip as one string.
create function pg_temp.ev(p_trip text) returns text language sql as $$
  select e.title || '|' || coalesce(e.location, '-') || '|' || coalesce(e.icon_key, '-') || '|' || e.kind || '|'
      || e.is_all_day || '|' || e.start_date || '|' || e.end_date || '|' || e.status || '|' || e.importance || '|'
      || e.countdown
    from app.event e where e.trip_id = pg_temp.id(p_trip) and e.deleted_at is null
$$;
create function pg_temp.seq(p_trip text) returns int language sql as $$
  select e.sequence from app.event e where e.trip_id = pg_temp.id(p_trip) and e.deleted_at is null
$$;
create function pg_temp.attendees(p_trip text) returns uuid[] language sql as $$
  select coalesce(array_agg(a.profile_id order by a.profile_id), '{}')
    from app.event_attendee a join app.event e on e.id = a.event_id
   where e.trip_id = pg_temp.id(p_trip) and e.deleted_at is null
$$;

-- What a trip may not be.
insert into snaps values ('bad_trips', pg_temp.snap());
select is((select coalesce(string_agg(t.d, '; '), '') from (values
  ('not an object', '[]'),
  ('no title', '{}'),
  ('blank title', '{"title": "   "}'),
  ('title that is no text', '{"title": 5}'),
  ('title of 121 characters', format('{"title": "%s"}', repeat('t', 121))),
  ('unknown stage', '{"title": "X", "stage": "dream"}'),
  ('null stage', '{"title": "X", "stage": null}'),
  ('planned without dates', '{"title": "X", "stage": "planned"}'),
  ('fixed without dates', '{"title": "X", "stage": "fixed"}'),
  ('one date only', '{"title": "X", "starts_on": "2027-07-10"}'),
  ('end before start', '{"title": "X", "starts_on": "2027-07-10", "ends_on": "2027-07-09"}'),
  ('367 days', '{"title": "X", "starts_on": "2027-01-01", "ends_on": "2028-01-02"}'),
  ('a day that does not exist', '{"title": "X", "starts_on": "2027-02-30", "ends_on": "2027-03-02"}'),
  ('a date in words', '{"title": "X", "starts_on": "July", "ends_on": "August"}'),
  ('icon with blanks', '{"title": "X", "icon_key": "Bad Icon"}'),
  ('destination key in capitals', '{"title": "X", "destination_key": "Bad Key"}'),
  ('country in small letters', '{"title": "X", "country": "ch"}'),
  ('country of three letters', '{"title": "X", "country": "CHE"}'),
  ('currency of four letters', '{"title": "X", "currency": "CHFF"}'),
  ('currency with a digit', '{"title": "X", "currency": "C1F"}'),
  ('latitude without longitude', '{"title": "X", "lat": 10}'),
  ('latitude 91', '{"title": "X", "lat": 91, "lon": 0}'),
  ('longitude 181', '{"title": "X", "lat": 0, "lon": 181}'),
  ('latitude as text', '{"title": "X", "lat": "10", "lon": 10}'),
  ('note of 4001 characters', format('{"title": "X", "note": "%s"}', repeat('n', 4001))),
  ('members that are no array', '{"title": "X", "member_ids": "all"}'),
  ('a member that is no uuid', '{"title": "X", "member_ids": ["papa"]}'),
  ('a member who left', format('{"title": "X", "member_ids": ["%s"]}', pg_temp.id('ex'))),
  ('a member of another household', format('{"title": "X", "member_ids": ["%s"]}', pg_temp.id('bea'))),
  ('an id that is no uuid', '{"id": "abc", "title": "X"}')
) t(d, j) where pg_temp.bad('trip_save', t.j) is distinct from 'trip_invalid'), '', 'each of these is refused as an invalid trip');
select is(pg_temp.snap(), (select v from snaps where name = 'bad_trips'), 'and none of them wrote a row, a member, an entry of the calendar or an audit row');
select lives_ok($$ select pg_temp.trip('year', '{"title": "Sabbatical", "starts_on": "2027-01-01", "ends_on": "2028-01-01", "stage": "planned"}') $$,
  'but 366 days are taken');
select pg_temp.run('papa', format('select api.trip_delete(null, %L)', pg_temp.id('year')));
select is(pg_temp.bad('trip_save', format('{"id": "%s", "title": "Mine now"}', pg_temp.id('b3'))), 'trip_not_found',
  'another household''s trip cannot be saved');
select is(pg_temp.bad('trip_save', format('{"id": "%s", "title": "Mine now"}', pg_temp.id('sard')), 'bea'), 'trip_not_found',
  'nor from the other side');
select is((select title from app.trip where id = pg_temp.id('sard')), 'Sardinien', 'and the trip is as it was');

-- Members.
select pg_temp.trip('sard', format('{"id": "%s", "member_ids": ["%s", "%s", "%s"]}', pg_temp.id('sard'), pg_temp.id('papa'), pg_temp.id('mama'), pg_temp.id('papa')));
select is(pg_temp.members('sard'), pg_temp.ids_of('papa', 'mama'), 'the members are saved, each once');
select pg_temp.trip('sard', format('{"id": "%s", "member_ids": ["%s"]}', pg_temp.id('sard'), pg_temp.id('mama')));
select is(pg_temp.members('sard'), pg_temp.ids_of('mama'), 'a new list replaces the old');
select pg_temp.trip('sard', format('{"id": "%s", "title": "Sardinien"}', pg_temp.id('sard')));
select is(pg_temp.members('sard'), pg_temp.ids_of('mama'), 'a save without the key keeps them');
select pg_temp.act_as_dev('kind');
select is((select member_ids from api.trips where id = pg_temp.id('sard')), pg_temp.ids_of('mama'), 'every device of the household reads them in api.trips');
reset role;
select pg_temp.trip('sard', format('{"id": "%s", "member_ids": null}', pg_temp.id('sard')));
select is(pg_temp.members('sard'), '{}'::uuid[], 'null means the whole family');

-- ---- 3. The calendar entry belongs to the trip ---------------------------------------------------------
select is((select count(*)::int from app.event where trip_id is not null), 0, 'ideas have no calendar entry');
select isnt(pg_temp.trip('ibiza', format('{"title": "Ibiza", "icon_key": "beach", "destination_name": "Ibiza", "stage": "planned", "starts_on": "2027-07-10", "ends_on": "2027-07-24", "member_ids": ["%s", "%s", "%s"]}',
  pg_temp.id('papa'), pg_temp.id('mama'), pg_temp.id('kind'))) ->> 'event_id', null, 'a planned trip answers with its calendar entry');
select is(pg_temp.ev('ibiza'), 'Ibiza|Ibiza|beach|appointment|true|2027-07-10|2027-07-24|tentative|normal|false',
  'an all-day appointment: the trip''s name, place and picture, dates, tentative, without a countdown');
select is(pg_temp.attendees('ibiza'), pg_temp.ids_of('papa', 'mama', 'kind'), 'its attendees are the trip''s members');
select is((select e.uid = e.id::text || '@wuselwall.app' and e.sequence = 0 and e.created_by_profile_id = pg_temp.id('papa')
                  and e.timezone = (select h.timezone from app.household h where h.id = e.household_id)
                  and e.calendar_id = (select c.id from app.calendar c where c.household_id = e.household_id order by c.created_at, c.id limit 1)
                  and e.rrule is null and e.reminder_minutes is null and e.description is null
             from app.event e where e.id = pg_temp.eid('ibiza')), true,
  'with the uid, sequence, zone and calendar of any new all-day event');
select pg_temp.act_as_dev('papa');
select is((select event_id from api.trips where id = pg_temp.id('ibiza')), pg_temp.eid('ibiza'), 'api.trips names the entry');
select is((select trip_id from api.events where id = pg_temp.eid('ibiza')), pg_temp.id('ibiza'), 'and api.events names the trip');
select is((select attendee_ids from api.events where id = pg_temp.eid('ibiza')), (select array_agg(profile_id order by p.sort_order, p.id)
  from app.event_attendee a join app.profile p on p.id = a.profile_id where a.event_id = pg_temp.eid('ibiza')),
  'the calendar shows its attendees like any event''s');
reset role;

select pg_temp.trip('ibiza', format('{"id": "%s", "stage": "fixed"}', pg_temp.id('ibiza')));
select is(pg_temp.ev('ibiza'), 'Ibiza|Ibiza|beach|appointment|true|2027-07-10|2027-07-24|confirmed|key|true',
  'fixed: confirmed, a key appointment, counting down');
select is((select count(*)::int from app.event where trip_id = pg_temp.id('ibiza')), 1, 'in the same entry');
select is(pg_temp.seq('ibiza'), 1, 'whose sequence moved on');
select pg_temp.trip('ibiza', format('{"id": "%s", "stage": "fixed"}', pg_temp.id('ibiza')));
select is(pg_temp.seq('ibiza'), 1, 'a save that changes nothing leaves the sequence');
select pg_temp.trip('ibiza', format('{"id": "%s", "starts_on": "2027-07-11", "title": "Ibiza 27"}', pg_temp.id('ibiza')));
select is(pg_temp.ev('ibiza'), 'Ibiza 27|Ibiza|beach|appointment|true|2027-07-11|2027-07-24|confirmed|key|true', 'new dates and a new title reach the entry');
select is(pg_temp.seq('ibiza'), 2, 'with one step of the sequence');
select pg_temp.trip('ibiza', format('{"id": "%s", "member_ids": ["%s"]}', pg_temp.id('ibiza'), pg_temp.id('opa')));
select is(pg_temp.attendees('ibiza'), pg_temp.ids_of('opa'), 'members replace the attendees');
select is(pg_temp.seq('ibiza'), 3, 'and count as a change');
select pg_temp.trip('ibiza', format('{"id": "%s", "stage": "planned"}', pg_temp.id('ibiza')));
select is(pg_temp.ev('ibiza'), 'Ibiza 27|Ibiza|beach|appointment|true|2027-07-11|2027-07-24|tentative|normal|false', 'back to planned: tentative again, no countdown');
select pg_temp.trip('ibiza', format('{"id": "%s", "member_ids": []}', pg_temp.id('ibiza')));
select is((select importance from app.event where id = pg_temp.eid('ibiza')), 'key', 'a trip of the whole family is a key appointment, as the household''s rule says');
select pg_temp.trip('ibiza', format('{"id": "%s", "member_ids": ["%s", "%s", "%s", "%s", "%s"]}', pg_temp.id('ibiza'),
  pg_temp.id('papa'), pg_temp.id('mama'), pg_temp.id('opa'), pg_temp.id('kind'), pg_temp.id('kind2')));
select is((select importance from app.event where id = pg_temp.eid('ibiza')), 'key', 'so is one with every active member');
select pg_temp.trip('ibiza', format('{"id": "%s", "member_ids": ["%s", "%s"]}', pg_temp.id('ibiza'), pg_temp.id('papa'), pg_temp.id('mama')));
select is((select importance from app.event where id = pg_temp.eid('ibiza')), 'normal', 'but not one of two');
update app.household_setting set value = '"all"' where false;
insert into app.household_setting (household_id, key, value) values (pg_temp.id('hh_a'), 'calendar.key_default', '"none"');
select pg_temp.trip('ibiza', format('{"id": "%s", "member_ids": []}', pg_temp.id('ibiza')));
select is((select importance from app.event where id = pg_temp.eid('ibiza')), 'normal', 'the household''s own rule decides: none');
update app.household_setting set value = '"all"' where household_id = pg_temp.id('hh_a') and key = 'calendar.key_default';
select pg_temp.trip('ibiza', format('{"id": "%s", "member_ids": ["%s"]}', pg_temp.id('ibiza'), pg_temp.id('papa')));
select is((select importance from app.event where id = pg_temp.eid('ibiza')), 'key', 'and all');
delete from app.household_setting where household_id = pg_temp.id('hh_a') and key = 'calendar.key_default';

-- An idea has no entry; a trip that falls through takes it away.
select pg_temp.trip('ibiza', format('{"id": "%s", "stage": "fixed", "member_ids": ["%s", "%s"]}', pg_temp.id('ibiza'), pg_temp.id('papa'), pg_temp.id('mama')));
insert into ids values ('ibiza_event', pg_temp.eid('ibiza'));
select pg_temp.trip('ibiza', format('{"id": "%s", "stage": "idea"}', pg_temp.id('ibiza')));
select is((select count(*)::int from app.event where trip_id = pg_temp.id('ibiza')), 0, 'an idea has no entry: it is detached');
select is((select deleted_at is not null and trip_id is null and sequence > 0 from app.event where id = pg_temp.id('ibiza_event')), true,
  'and soft-deleted, as an event is when it is deleted');
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from api.events where id = pg_temp.id('ibiza_event')), 0, 'the calendar no longer shows it');
select is((select event_id from api.trips where id = pg_temp.id('ibiza')), null, 'and the trip names none');
reset role;
select is((select stage || ':' || starts_on from app.trip where id = pg_temp.id('ibiza')), 'idea:2027-07-11', 'the trip keeps its dates');
select pg_temp.trip('ibiza', format('{"id": "%s", "stage": "planned"}', pg_temp.id('ibiza')));
select isnt(pg_temp.eid('ibiza'), pg_temp.id('ibiza_event'), 'planned again, it gets an entry of its own');
select pg_temp.trip('ibiza', format('{"id": "%s", "stage": "fixed"}', pg_temp.id('ibiza')));

-- Nobody changes the entry from the calendar.
create function pg_temp.event_json(p_id uuid, p_title text) returns text language sql as $$
  select jsonb_build_object('id', p_id, 'title', p_title, 'kind', 'appointment', 'is_all_day', true,
                            'start_date', '2027-07-11', 'end_date', '2027-07-24')::text
$$;
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($$ select api.event_save(null, %L::jsonb) $$, pg_temp.event_json(pg_temp.eid('ibiza'), 'Umbenannt'))),
  'trip_event', 'api.event_save refuses a trip''s entry');
select is(pg_temp.error_hint(format($$ select api.event_delete(null, %L) $$, pg_temp.eid('ibiza'))), 'trip_event', 'api.event_delete too');
select is(pg_temp.error_hint(format($$ select api.event_override_save(null, %L, '2027-07-12T00:00:00Z', true, '{}') $$, pg_temp.eid('ibiza'))),
  'event_invalid', 'a day of it cannot be changed through the api either: the entry is no series');
reset role;
select throws_ok(format($$ insert into app.event_override (household_id, event_id, recurrence_id, is_cancelled)
  values (%L, %L, '2027-07-12T00:00:00Z', true) $$, pg_temp.id('hh_a'), pg_temp.eid('ibiza')), '42501', 'WW-TRIP-004 the calendar entry of a trip is changed in the trip',
  'an override of it is refused whoever makes it');
select throws_ok(format($$ update app.event set title = 'x' where id = %L $$, pg_temp.eid('ibiza')), '42501', 'WW-TRIP-004 the calendar entry of a trip is changed in the trip',
  'and so is any update of what a person sees');
select throws_ok(format($$ update app.event set deleted_at = now() where id = %L $$, pg_temp.eid('ibiza')), '42501', null, 'including the soft delete');
select lives_ok(format($$ update app.event set created_by_profile_id = null, sequence = sequence, updated_at = now() where id = %L $$, pg_temp.eid('ibiza')),
  'while the creator going away is not a change');
select is(pg_temp.ev('ibiza'), 'Ibiza 27|Ibiza|beach|appointment|true|2027-07-11|2027-07-24|confirmed|key|true', 'the entry is as it was after all of that');
select is(current_setting('app.trip_sync', true), 'off', 'and the guard is closed again');

-- The calendar is as before for every other event.
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.event_save(null, '{"id": "5d3d9c28-4f9b-4c32-9f6e-0a5b8c7d1e01", "title": "Zahnarzt", "kind": "appointment", "is_all_day": true, "start_date": "2027-03-01", "end_date": "2027-03-01"}'::jsonb) $$,
  'an ordinary event is saved');
select lives_ok($$ select api.event_save(null, '{"id": "5d3d9c28-4f9b-4c32-9f6e-0a5b8c7d1e01", "title": "Zahnarzt 2", "kind": "appointment", "is_all_day": true, "start_date": "2027-03-01", "end_date": "2027-03-01"}'::jsonb) $$,
  'changed');
select lives_ok($$ select api.event_delete(null, '5d3d9c28-4f9b-4c32-9f6e-0a5b8c7d1e01') $$, 'and deleted');
reset role;

-- ---- 4. Entries ----------------------------------------------------------------------------------------
create function pg_temp.today_a() returns date language sql as $$ select app.tasks_today(pg_temp.id('hh_a')) $$;
-- The hint of saving an entry of the trip 'ibiza' with these fields.
create function pg_temp.be(p_fields text, p_dev text default 'papa') returns text language sql as $$
  select pg_temp.bad('trip_entry_save', '{"trip_id": "' || pg_temp.id('ibiza') || '", ' || p_fields || '}', p_dev)
$$;

select is(pg_temp.entry('f1', format('{"trip_id": "%s", "kind": "transport", "mode": "flight", "title": "ZRH-IBZ", "price_cents": 84000, "from_place": "ZRH", "to_place": "IBZ", "starts_on": "2027-07-11", "starts_time": "10:40", "ends_on": "2027-07-11", "ends_time": "12:55:30", "url": "https://air.example/x?a=1", "details": "direct"}', pg_temp.id('ibiza'))) ? 'id',
  true, 'an entry is saved');
select is((select kind || ':' || mode || ':' || state || ':' || position || ':' || starts_time || ':' || ends_time || ':' || price_cents
             from app.trip_entry where id = pg_temp.id('f1')),
  'transport:flight:option:0:10:40:00:12:55:30:84000', 'a new entry is an option, first of its kind, its times as written');
select is((select price_checked_on from app.trip_entry where id = pg_temp.id('f1')), pg_temp.today_a(), 'its price is dated today');
select pg_temp.entry('f2', format('{"trip_id": "%s", "kind": "transport", "title": "Fähre"}', pg_temp.id('ibiza')));
select is((select mode || ':' || position || ':' || coalesce(price_checked_on::text, 'none') from app.trip_entry where id = pg_temp.id('f2')),
  'other:1:none', 'a transport without a mode is "other", the next place, no price and so no date');
select pg_temp.entry('h1', format('{"trip_id": "%s", "kind": "stay", "title": "Finca", "address": "Calle 1", "phone": "+34 600", "starts_on": "2027-07-11", "ends_on": "2027-07-24", "price_cents": 250000, "cancel_until": "2027-06-01", "lat": 38.9, "lon": 1.4}', pg_temp.id('ibiza')));
select is((select coalesce(mode, 'none') || ':' || position from app.trip_entry where id = pg_temp.id('h1')), 'none:0', 'a stay has no mode and its own count of places');
select pg_temp.entry('r1', format('{"trip_id": "%s", "kind": "rental", "title": "Fiat 500", "starts_on": "2027-07-11", "ends_on": "2027-07-24", "note": "Kindersitz"}', pg_temp.id('ibiza')));
select pg_temp.entry('a1', format('{"trip_id": "%s", "kind": "activity", "title": "Bootstour"}', pg_temp.id('ibiza')));
select pg_temp.entry('n1', format('{"trip_id": "%s", "kind": "note", "title": "Pässe prüfen"}', pg_temp.id('ibiza')));

insert into snaps values ('bad_entries', pg_temp.snap());
select is((select coalesce(string_agg(t.d, '; '), '') from (values
  ('no trip', '"kind": "note", "title": "x", "trip_id": null'),
  ('unknown kind', '"kind": "hotel", "title": "x"'),
  ('no kind', '"title": "x"'),
  ('no title', '"kind": "note"'),
  ('blank title', '"kind": "note", "title": "  "'),
  ('title of 201', format('"kind": "note", "title": "%s"', repeat('t', 201))),
  ('a mode on a stay', '"kind": "stay", "title": "x", "mode": "flight"'),
  ('an unknown mode', '"kind": "transport", "title": "x", "mode": "rocket"'),
  ('a mode that is no text', '"kind": "transport", "title": "x", "mode": 5'),
  ('an unknown state', '"kind": "note", "title": "x", "state": "maybe"'),
  ('a ftp link', '"kind": "note", "title": "x", "url": "ftp://x.example/f"'),
  ('a script link', '"kind": "note", "title": "x", "url": "javascript:alert(1)"'),
  ('a link with a blank', '"kind": "note", "title": "x", "url": "https://x.example/a b"'),
  ('a link of 2001', format('"kind": "note", "title": "x", "url": "https://x.example/%s"', repeat('a', 1985))),
  ('a negative price', '"kind": "note", "title": "x", "price_cents": -1'),
  ('a price over 10^10', '"kind": "note", "title": "x", "price_cents": 10000000001'),
  ('a fractional price', '"kind": "note", "title": "x", "price_cents": 10.5'),
  ('a price as text', '"kind": "note", "title": "x", "price_cents": "10"'),
  ('details of 201', format('"kind": "note", "title": "x", "details": "%s"', repeat('d', 201))),
  ('a note of 4001', format('"kind": "note", "title": "x", "note": "%s"', repeat('d', 4001))),
  ('a place of 81', format('"kind": "note", "title": "x", "from_place": "%s"', repeat('d', 81))),
  ('a reference of 81', format('"kind": "note", "title": "x", "booking_ref": "%s"', repeat('d', 81))),
  ('an address of 301', format('"kind": "note", "title": "x", "address": "%s"', repeat('d', 301))),
  ('a phone of 41', format('"kind": "note", "title": "x", "phone": "%s"', repeat('d', 41))),
  ('a cancel day that is no date', '"kind": "note", "title": "x", "cancel_until": "tomorrow"'),
  ('a time without its date', '"kind": "note", "title": "x", "starts_time": "10:00"'),
  ('an end time without its date', '"kind": "note", "title": "x", "starts_on": "2027-07-11", "ends_time": "10:00"'),
  ('an end before the start', '"kind": "note", "title": "x", "starts_on": "2027-07-11", "ends_on": "2027-07-10"'),
  ('an end time before the start time on one day', '"kind": "note", "title": "x", "starts_on": "2027-07-11", "starts_time": "10:00", "ends_on": "2027-07-11", "ends_time": "09:59"'),
  ('a time of 25:00', '"kind": "note", "title": "x", "starts_on": "2027-07-11", "starts_time": "25:00"'),
  ('a time in words', '"kind": "note", "title": "x", "starts_on": "2027-07-11", "starts_time": "noon"'),
  ('a latitude without longitude', '"kind": "note", "title": "x", "lat": 10'),
  ('a latitude of 91', '"kind": "note", "title": "x", "lat": 91, "lon": 0'),
  ('a position of -1', '"kind": "note", "title": "x", "position": -1'),
  ('a source uid of 301', format('"kind": "note", "title": "x", "source_uid": "%s"', repeat('u', 301)))
) t(d, f) where pg_temp.be(t.f) is distinct from 'trip_entry_invalid'), '', 'each of these is refused as an invalid entry');
select is(pg_temp.snap(), (select v from snaps where name = 'bad_entries'), 'and none of them wrote anything');
select is(pg_temp.bad('trip_entry_save', '[]'), 'trip_entry_invalid', 'an entry that is no object');
select is(pg_temp.bad('trip_entry_save', '{"kind": "note", "title": "x"}'), 'trip_entry_invalid', 'a new entry needs its trip');
select is(pg_temp.bad('trip_entry_save', format('{"trip_id": "%s", "kind": "note", "title": "x"}', pg_temp.id('b3'))), 'trip_not_found', 'another household''s trip is not found');
select is(pg_temp.bad('trip_entry_save', format('{"trip_id": "%s", "kind": "note", "title": "x"}', gen_random_uuid())), 'trip_not_found', 'nor one that does not exist');
select is(pg_temp.bad('trip_entry_save', format('{"id": "%s", "trip_id": "%s"}', pg_temp.id('f1'), pg_temp.id('sard'))), 'trip_entry_invalid', 'an entry does not move to another trip');
select lives_ok(format($$ select pg_temp.entry(null, '{"trip_id": "%s", "kind": "note", "title": "same day", "starts_on": "2027-07-11", "starts_time": "10:00", "ends_on": "2027-07-11", "ends_time": "10:00"}') $$, pg_temp.id('ibiza')),
  'an end at the start is allowed');
select lives_ok(format($$ select pg_temp.entry(null, '{"trip_id": "%s", "kind": "note", "title": "overnight", "starts_on": "2027-07-11", "starts_time": "22:00", "ends_on": "2027-07-12", "ends_time": "06:00"}') $$, pg_temp.id('ibiza')),
  'an earlier time on a later day is fine');
select lives_ok(format($$ select pg_temp.entry(null, '{"trip_id": "%s", "kind": "note", "title": "dates only", "starts_on": "2027-07-11", "ends_on": "2027-07-12"}') $$, pg_temp.id('ibiza')),
  'so is a date without time');

-- Update: omitted keys stay, null clears.
select pg_temp.entry('f1', format('{"id": "%s", "title": "ZRH-IBZ direkt"}', pg_temp.id('f1')));
select is((select title || ':' || price_cents || ':' || url || ':' || starts_time from app.trip_entry where id = pg_temp.id('f1')),
  'ZRH-IBZ direkt:84000:https://air.example/x?a=1:10:40:00', 'a key that is left out keeps its value');
select pg_temp.entry('f1', format('{"id": "%s", "details": null, "url": "", "ends_time": null}', pg_temp.id('f1')));
select is((select coalesce(details, 'none') || ':' || coalesce(url, 'none') || ':' || coalesce(ends_time::text, 'none') from app.trip_entry where id = pg_temp.id('f1')),
  'none:none:none', 'null and empty clear');
select is(pg_temp.bad('trip_entry_save', format('{"id": "%s", "ends_on": "2027-07-10"}', pg_temp.id('f1'))), 'trip_entry_invalid',
  'an update is checked against what is stored');

-- The date of a price.
update app.trip_entry set price_checked_on = '2027-01-01' where id = pg_temp.id('f1');
select pg_temp.entry('f1', format('{"id": "%s", "note": "Handgepäck"}', pg_temp.id('f1')));
select is((select price_checked_on from app.trip_entry where id = pg_temp.id('f1')), '2027-01-01'::date, 'a price that is not touched keeps its date');
select pg_temp.entry('f1', format('{"id": "%s", "price_cents": 84000}', pg_temp.id('f1')));
select is((select price_checked_on from app.trip_entry where id = pg_temp.id('f1')), '2027-01-01'::date, 'and one that is saved again unchanged');
select pg_temp.entry('f1', format('{"id": "%s", "price_cents": 79000}', pg_temp.id('f1')));
select is((select price_checked_on from app.trip_entry where id = pg_temp.id('f1')), pg_temp.today_a(), 'a changed price is dated today');
select pg_temp.entry('f1', format('{"id": "%s", "price_cents": null}', pg_temp.id('f1')));
select is((select coalesce(price_checked_on::text, 'none') from app.trip_entry where id = pg_temp.id('f1')), 'none', 'a removed price has no date');
select pg_temp.entry('f1', format('{"id": "%s", "price_cents": 79000, "price_checked_on": "2020-01-01"}', pg_temp.id('f1')));
select is((select price_checked_on from app.trip_entry where id = pg_temp.id('f1')), pg_temp.today_a(), 'a price that comes back is dated today, whatever the client says');

-- Not found, copy, delete.
select is(pg_temp.bad('trip_entry_save', format('{"id": "%s", "title": "x"}', pg_temp.id('f1')), 'bea'), 'trip_entry_not_found', 'another household''s entry cannot be saved');
select pg_temp.entry('f1', format('{"id": "%s", "state": "booked", "booking_ref": "ABC123", "source_uid": "uid-f1"}', pg_temp.id('f1')));
select is(pg_temp.reg('f1c', pg_temp.call('papa', format('select api.trip_entry_copy(null, %L)', pg_temp.id('f1')))) ? 'id', true, 'an entry is copied');
select is((select state || ':' || coalesce(booking_ref, 'none') || ':' || coalesce(source_uid, 'none') || ':' || position || ':' || title || ':' || price_cents
             from app.trip_entry where id = pg_temp.id('f1c')),
  'option:none:none:1:ZRH-IBZ direkt:79000', 'as an option, without reference and source, right after the original');
select is((select position from app.trip_entry where id = pg_temp.id('f2')), 2, 'the later ones of its kind move down');
select is(pg_temp.hint('bea', format('select api.trip_entry_copy(null, %L)', pg_temp.id('f1'))), 'trip_entry_not_found', 'another household''s entry cannot be copied');
select is(pg_temp.hint('papa', format('select api.trip_entry_delete(null, %L)', gen_random_uuid())), 'trip_entry_not_found', 'an entry that does not exist cannot be deleted');
select pg_temp.run('papa', format('select api.trip_entry_delete(null, %L)', pg_temp.id('f1c')));
select is((select count(*)::int from app.trip_entry where id = pg_temp.id('f1c')), 0, 'a deleted entry is gone');

-- Import from a booking's calendar file.
select is(pg_temp.call('papa', format($q$ select api.trip_entries_import(null, %L, '[{"source_uid": "ev1", "kind": "transport", "mode": "train", "title": "IC 1", "starts_on": "2027-07-11", "starts_time": "06:00"}, {"source_uid": " ev2 ", "kind": "stay", "title": "Hotel Playa", "address": "Calle 2"}]'::jsonb) $q$, pg_temp.id('ibiza'))),
  '{"added": 2, "updated": 0}'::jsonb, 'two entries are imported');
select is((select string_agg(state || ':' || source_uid, ',' order by source_uid) from app.trip_entry where source_uid in ('ev1', 'ev2')), 'booked:ev1,booked:ev2',
  'as booked, with the file''s ids');
select is(pg_temp.call('papa', format($q$ select api.trip_entries_import(null, %L, '[{"source_uid": "ev1", "title": "IC 1 (neu)"}, {"source_uid": "ev3", "kind": "activity", "title": "Konzert", "state": "option"}]'::jsonb) $q$, pg_temp.id('ibiza'))),
  '{"added": 1, "updated": 1}'::jsonb, 'the same file again updates and adds');
select is((select title || ':' || state || ':' || starts_time from app.trip_entry where trip_id = pg_temp.id('ibiza') and source_uid = 'ev1'), 'IC 1 (neu):booked:06:00:00',
  'an update keeps what the file does not say');
select is((select count(*)::int from app.trip_entry where trip_id = pg_temp.id('ibiza') and source_uid like 'ev%'), 3, 'and does not double it');
select is((select state from app.trip_entry where trip_id = pg_temp.id('ibiza') and source_uid = 'ev3'), 'option', 'a state the file names is taken');
select pg_temp.trip('imp', '{"title": "Import"}');
select is(pg_temp.call('papa', format($q$ select api.trip_entries_import(null, %L, (select jsonb_agg(jsonb_build_object('source_uid', 'u' || g, 'kind', 'note', 'title', 'n' || g)) from generate_series(1, 50) g)) $q$, pg_temp.id('imp'))),
  '{"added": 50, "updated": 0}'::jsonb, 'fifty entries at once');
select is(pg_temp.hint('papa', format($q$ select api.trip_entries_import(null, %L, (select jsonb_agg(jsonb_build_object('source_uid', 'v' || g, 'kind', 'note', 'title', 'n' || g)) from generate_series(1, 51) g)) $q$, pg_temp.id('imp'))),
  'trip_entry_invalid', 'fifty-one are too many');
select is((select count(*)::int from app.trip_entry where trip_id = pg_temp.id('imp')), 50, 'and none of them is written');
select pg_temp.run('papa', format('select api.trip_entry_delete(null, id) from app.trip_entry where trip_id = %L', pg_temp.id('imp')));
select is((select coalesce(string_agg(t.d, '; '), '') from (values
  ('no source uid', '[{"kind": "note", "title": "x"}]'),
  ('a blank source uid', '[{"source_uid": "  ", "kind": "note", "title": "x"}]'),
  ('a source uid of 301', format('[{"source_uid": "%s", "kind": "note", "title": "x"}]', repeat('u', 301))),
  ('a source uid that is no text', '[{"source_uid": 5, "kind": "note", "title": "x"}]'),
  ('a new entry without a kind', '[{"source_uid": "z1", "title": "x"}]'),
  ('an element that is no object', '[{"source_uid": "z1", "kind": "note", "title": "x"}, "text"]'),
  ('a good element and a bad one', '[{"source_uid": "z1", "kind": "note", "title": "x"}, {"source_uid": "z2", "kind": "note", "title": "x", "url": "ftp://x"}]'),
  ('not an array', '{"source_uid": "z1"}')
) t(d, j) where pg_temp.hint('papa', format('select api.trip_entries_import(null, %L, %L::jsonb)', pg_temp.id('imp'), t.j)) is distinct from 'trip_entry_invalid'),
  '', 'each of these imports is refused');
select is((select count(*)::int from app.trip_entry where trip_id = pg_temp.id('imp')), 0, 'and writes nothing, not even the good element');
select is(pg_temp.hint('bea', format($q$ select api.trip_entries_import(null, %L, '[]'::jsonb) $q$, pg_temp.id('imp'))), 'trip_not_found', 'another household''s trip takes no import');
select is(pg_temp.hint('papa', format($q$ select api.trip_entries_import(null, %L, '[]'::jsonb) $q$, pg_temp.id('b3'))), 'trip_not_found', 'and one of its own cannot reach it');
select pg_temp.trip('imp2', '{"title": "Import 2"}');
select is(pg_temp.call('papa', format($q$ select api.trip_entries_import(null, %L, '[{"source_uid": "ev1", "kind": "note", "title": "other trip"}]'::jsonb) $q$, pg_temp.id('imp2'))),
  '{"added": 1, "updated": 0}'::jsonb, 'a source uid is the trip''s own: another trip adds it');

-- ---- 5. Combinations ------------------------------------------------------------------------------------
select pg_temp.trip('plan', '{"title": "Plan"}');
create function pg_temp.pe(p_name text, p_fields text) returns void language sql as $$
  select pg_temp.entry(p_name, '{"trip_id": "' || pg_temp.id('plan') || '", ' || p_fields || '}') -> 'id' is not null
$$;
select pg_temp.pe('pA', '"kind": "transport", "mode": "flight", "title": "Hin", "starts_on": "2027-07-10", "ends_on": "2027-07-10"');
select pg_temp.pe('pH1', '"kind": "stay", "title": "Hotel 1", "starts_on": "2027-07-10", "ends_on": "2027-07-17"');
select pg_temp.pe('pR', '"kind": "rental", "title": "Auto", "starts_on": "2027-07-10", "ends_on": "2027-07-17"');
select pg_temp.pe('pAct', '"kind": "activity", "title": "Boot"');
select pg_temp.pe('pB', '"kind": "transport", "mode": "train", "title": "Zug", "state": "chosen", "starts_on": "2027-07-12", "ends_on": "2027-07-12"');
select pg_temp.pe('pH0', '"kind": "stay", "title": "Hotel 0", "state": "chosen", "starts_on": "2027-07-12", "ends_on": "2027-07-19"');
select pg_temp.pe('pCar', '"kind": "rental", "title": "Gebucht", "state": "booked"');
select pg_temp.pe('pN', '"kind": "note", "title": "Notiz", "state": "chosen"');
select pg_temp.pe('pAct2', '"kind": "activity", "title": "Museum", "state": "chosen"');
select pg_temp.pe('pL1', '"kind": "stay", "title": "Lang 1", "starts_on": "2027-01-01", "ends_on": "2027-01-02"');
select pg_temp.pe('pL2', '"kind": "stay", "title": "Lang 2", "starts_on": "2028-02-01"');

select pg_temp.entry('be1', format('{"trip_id": "%s", "kind": "note", "title": "B"}', pg_temp.id('b3')), 'bea');
select is(pg_temp.combo('cA', format('{"trip_id": "%s", "name": "Günstig", "entry_ids": ["%s", "%s", "%s", "%s", "%s"]}', pg_temp.id('plan'),
  pg_temp.id('pA'), pg_temp.id('pH1'), pg_temp.id('pR'), pg_temp.id('pAct'), pg_temp.id('pA'))) ? 'id', true, 'a combination is saved');
select pg_temp.act_as_dev('kind');
select is((select entry_ids from api.trip_combos where id = pg_temp.id('cA')), pg_temp.ids_of('pA', 'pH1', 'pR', 'pAct'), 'every device reads its entries, each once');
reset role;
select pg_temp.combo('cA', format('{"id": "%s", "entry_ids": ["%s", "%s", "%s", "%s"]}', pg_temp.id('cA'), pg_temp.id('pA'), pg_temp.id('pH1'), pg_temp.id('pR'), pg_temp.id('pAct')));
select pg_temp.combo('cB', format('{"trip_id": "%s", "name": "Zug und Hotel", "entry_ids": ["%s", "%s"]}', pg_temp.id('plan'), pg_temp.id('pB'), pg_temp.id('pH0')));
select is((select position from app.trip_combo where id = pg_temp.id('cA')) + 1, (select position from app.trip_combo where id = pg_temp.id('cB')), 'the next combination takes the next place');
select pg_temp.combo('cA', format('{"id": "%s", "name": "Günstig 2"}', pg_temp.id('cA')));
select is((select name || ':' || (select count(*) from app.trip_combo_entry where combo_id = pg_temp.id('cA')) from app.trip_combo where id = pg_temp.id('cA')), 'Günstig 2:4',
  'a save without entry_ids keeps the set');
select pg_temp.combo('cA', format('{"id": "%s", "entry_ids": ["%s"]}', pg_temp.id('cA'), pg_temp.id('pA')));
select is((select count(*)::int from app.trip_combo_entry where combo_id = pg_temp.id('cA')), 1, 'a new set replaces the old');
select pg_temp.combo('cA', format('{"id": "%s", "entry_ids": ["%s", "%s", "%s", "%s"]}', pg_temp.id('cA'), pg_temp.id('pA'), pg_temp.id('pH1'), pg_temp.id('pR'), pg_temp.id('pAct')));
select is((select coalesce(string_agg(t.d, '; '), '') from (values
  ('an entry of another trip', format('{"trip_id": "%s", "name": "x", "entry_ids": ["%s"]}', pg_temp.id('plan'), pg_temp.id('f1'))),
  ('an entry that is not there', format('{"trip_id": "%s", "name": "x", "entry_ids": ["%s"]}', pg_temp.id('plan'), gen_random_uuid())),
  ('another household''s entry', format('{"trip_id": "%s", "name": "x", "entry_ids": ["%s"]}', pg_temp.id('plan'), pg_temp.id('be1'))),
  ('no name', format('{"trip_id": "%s"}', pg_temp.id('plan'))),
  ('a blank name', format('{"trip_id": "%s", "name": "  "}', pg_temp.id('plan'))),
  ('a name of 61', format('{"trip_id": "%s", "name": "%s"}', pg_temp.id('plan'), repeat('n', 61))),
  ('entry_ids that are no array', format('{"trip_id": "%s", "name": "x", "entry_ids": "all"}', pg_temp.id('plan'))),
  ('an entry id that is no uuid', format('{"trip_id": "%s", "name": "x", "entry_ids": ["a"]}', pg_temp.id('plan'))),
  ('no trip', '{"name": "x"}'),
  ('not an object', '[]')
) t(d, j) where pg_temp.bad('trip_combo_save', t.j) is distinct from 'trip_combo_invalid'), '', 'each of these is refused as an invalid combination');
select is(pg_temp.bad('trip_combo_save', format('{"trip_id": "%s", "name": "x"}', pg_temp.id('b3'))), 'trip_not_found', 'a combination of another household''s trip is not found');
select is(pg_temp.bad('trip_combo_save', format('{"id": "%s", "name": "x"}', pg_temp.id('cA')), 'bea'), 'trip_combo_not_found', 'another household''s combination cannot be saved');
select is(pg_temp.bad('trip_combo_save', format('{"id": "%s", "trip_id": "%s", "name": "x"}', pg_temp.id('cA'), pg_temp.id('ibiza'))), 'trip_combo_invalid', 'and does not move to another trip');
-- Forty entries, not forty-one.
select pg_temp.trip('big', '{"title": "Viele"}');
insert into app.trip_entry (household_id, trip_id, kind, title, position)
  select pg_temp.id('hh_a'), pg_temp.id('big'), 'note', 'n' || g, g from generate_series(1, 41) g;
select is(pg_temp.bad('trip_combo_save', format('{"trip_id": "%s", "name": "x", "entry_ids": %s}', pg_temp.id('big'),
  (select jsonb_agg(id) from (select id from app.trip_entry where trip_id = pg_temp.id('big') limit 41) q))), 'trip_combo_invalid', 'forty-one entries are too many');
select lives_ok(format($$ select pg_temp.combo(null, '{"trip_id": "%s", "name": "x", "entry_ids": %s}') $$, pg_temp.id('big'),
  (select jsonb_agg(id) from (select id from app.trip_entry where trip_id = pg_temp.id('big') limit 40) q)), 'forty are taken');

-- Taking one.
create function pg_temp.states(p_names text) returns text language sql as $$
  select string_agg(e.title || '=' || e.state, ',' order by e.title)
    from app.trip_entry e where e.id = any (select id from ids where name = any (string_to_array(p_names, ',')))
$$;
select is(pg_temp.call('papa', format('select api.trip_combo_choose(null, %L)', pg_temp.id('cA'))), '{"chosen": 4, "released": 2, "dates_set": false}'::jsonb,
  'taking a combination chooses its options and releases the chosen transport and stay that are not in it');
select is(pg_temp.states('pA,pH1,pR,pAct,pB,pH0,pCar,pN,pAct2'),
  'Auto=chosen,Boot=chosen,Gebucht=booked,Hin=chosen,Hotel 0=option,Hotel 1=chosen,Museum=chosen,Notiz=chosen,Zug=option',
  'a booked entry, a note and an activity of the trip are never released');
select is((select stage || ':' || coalesce(starts_on::text, 'none') from app.trip where id = pg_temp.id('plan')), 'idea:none', 'without p_set_dates the trip''s dates stay');
select is((select count(*)::int from app.event where trip_id = pg_temp.id('plan')), 0, 'and an idea has no calendar entry');
select is(pg_temp.call('papa', format('select api.trip_combo_choose(null, %L)', pg_temp.id('cA'))), '{"chosen": 0, "released": 0, "dates_set": false}'::jsonb, 'taking it again changes nothing');
select is(pg_temp.call('papa', format('select api.trip_combo_choose(null, %L, true)', pg_temp.id('cA'))), '{"chosen": 0, "released": 0, "dates_set": true}'::jsonb, 'asked for its dates, it sets them');
select is((select stage || ':' || starts_on || ':' || ends_on from app.trip where id = pg_temp.id('plan')), 'planned:2027-07-10:2027-07-17',
  'from the first start to the last end, and an idea with dates is planned');
select is(pg_temp.ev('plan'), 'Plan|-|-|appointment|true|2027-07-10|2027-07-17|tentative|key|false', 'its calendar entry appears');
select is(pg_temp.call('papa', format('select api.trip_combo_choose(null, %L, true)', pg_temp.id('cB'))), '{"chosen": 2, "released": 3, "dates_set": true}'::jsonb,
  'the other combination takes over');
select is(pg_temp.states('pA,pH1,pR,pAct,pB,pH0,pCar'), 'Auto=option,Boot=chosen,Gebucht=booked,Hin=option,Hotel 0=chosen,Hotel 1=option,Zug=chosen', 'the states follow');
select is((select stage || ':' || starts_on || ':' || ends_on from app.trip where id = pg_temp.id('plan')), 'planned:2027-07-12:2027-07-19', 'a planned trip keeps its stage and takes the new dates');
select is(pg_temp.ev('plan'), 'Plan|-|-|appointment|true|2027-07-12|2027-07-19|tentative|key|false', 'and its calendar entry follows');
select pg_temp.trip('plan', format('{"id": "%s", "stage": "fixed"}', pg_temp.id('plan')));
select is(pg_temp.call('papa', format('select api.trip_combo_choose(null, %L, true)', pg_temp.id('cA'))),
  '{"chosen": 3, "released": 2, "dates_set": true}'::jsonb, 'a fixed trip takes a combination and its dates too');
select is((select stage || ':' || starts_on || ':' || ends_on from app.trip where id = pg_temp.id('plan')), 'fixed:2027-07-10:2027-07-17', 'and stays fixed');
select is(pg_temp.ev('plan'), 'Plan|-|-|appointment|true|2027-07-10|2027-07-17|confirmed|key|true', 'its entry follows, still confirmed');

-- Taking one that cannot be taken writes nothing.
select pg_temp.combo('cL', format('{"trip_id": "%s", "name": "Zu lang", "entry_ids": ["%s", "%s"]}', pg_temp.id('plan'), pg_temp.id('pL1'), pg_temp.id('pL2')));
insert into snaps values ('before_long', pg_temp.snap());
select is(pg_temp.hint('papa', format('select api.trip_combo_choose(null, %L, true)', pg_temp.id('cL'))), 'trip_invalid', 'dates of more than 366 days are refused');
select is(pg_temp.snap(), (select v from snaps where name = 'before_long'), 'and nothing changed, not even the chosen states');
select is(pg_temp.states('pL1,pL2'), 'Lang 1=option,Lang 2=option', 'the combination''s options are still options');
select is(pg_temp.call('papa', format('select api.trip_combo_choose(null, %L)', pg_temp.id('cL'))), '{"chosen": 2, "released": 3, "dates_set": false}'::jsonb,
  'without the dates it is taken');
select pg_temp.combo('cN', format('{"trip_id": "%s", "name": "Ohne Termine", "entry_ids": ["%s"]}', pg_temp.id('plan'), pg_temp.id('pAct2')));
select is(pg_temp.call('papa', format('select api.trip_combo_choose(null, %L, true)', pg_temp.id('cN')))::text, '{"chosen": 0, "released": 2, "dates_set": false}',
  'a combination without a start has no dates to set');
select is((select starts_on::text || ':' || ends_on::text from app.trip where id = pg_temp.id('plan')), '2027-07-10:2027-07-17', 'the trip''s dates stay');
select is(pg_temp.hint('bea', format('select api.trip_combo_choose(null, %L)', pg_temp.id('cA'))), 'trip_combo_not_found', 'another household''s combination cannot be taken');
select pg_temp.entry('pAct', format('{"id": "%s", "state": "option"}', pg_temp.id('pAct')));
select pg_temp.run('papa', format('select api.trip_entry_delete(null, %L)', pg_temp.id('pAct')));
select is((select count(*)::int from app.trip_combo_entry where combo_id = pg_temp.id('cA')), 3, 'an entry that is deleted leaves its combinations');
select pg_temp.act_as_dev('papa');
select is((select cardinality(entry_ids) from api.trip_combos where id = pg_temp.id('cA')), 3, 'as the view shows');
reset role;
select pg_temp.run('papa', format('select api.trip_combo_delete(null, %L)', pg_temp.id('cN')));
select is((select count(*)::int from app.trip_combo where id = pg_temp.id('cN')), 0, 'a combination is deleted');
select is((select count(*)::int from app.trip_entry where id = pg_temp.id('pAct2')), 1, 'with none of its entries');
select is(pg_temp.hint('papa', format('select api.trip_combo_delete(null, %L)', pg_temp.id('cN'))), 'trip_combo_not_found', 'once');

-- ---- 6. Checks --------------------------------------------------------------------------------------------
select is(pg_temp.chk('k1', format('{"trip_id": "%s", "kind": "pack", "title": "Reisepässe"}', pg_temp.id('ibiza'))) ? 'id', true, 'a check is saved');
select pg_temp.chk('k2', format('{"trip_id": "%s", "kind": "pack", "title": "Plüschtier", "profile_id": "%s"}', pg_temp.id('ibiza'), pg_temp.id('kind')));
select pg_temp.chk('k3', format('{"trip_id": "%s", "kind": "todo", "title": "Nachbarn fragen", "due_days_before": 14}', pg_temp.id('ibiza')));
select is((select string_agg(title || ':' || position || ':' || coalesce(profile_id::text, 'family') || ':' || coalesce(due_days_before::text, '-') || ':' || (done_at is null)::text, ',' order by title)
             from app.trip_check where trip_id = pg_temp.id('ibiza')),
  'Nachbarn fragen:0:family:14:true,Plüschtier:1:' || pg_temp.id('kind')::text || ':-:true,Reisepässe:0:family:-:true',
  'each is last of its kind, unticked, for the family or one person');
select is((select coalesce(string_agg(t.d, '; '), '') from (values
  ('no kind', format('{"trip_id": "%s", "title": "x"}', pg_temp.id('ibiza'))),
  ('an unknown kind', format('{"trip_id": "%s", "kind": "buy", "title": "x"}', pg_temp.id('ibiza'))),
  ('no title', format('{"trip_id": "%s", "kind": "pack"}', pg_temp.id('ibiza'))),
  ('a title of 121', format('{"trip_id": "%s", "kind": "pack", "title": "%s"}', pg_temp.id('ibiza'), repeat('t', 121))),
  ('a due day on packing', format('{"trip_id": "%s", "kind": "pack", "title": "x", "due_days_before": 3}', pg_temp.id('ibiza'))),
  ('a due day of 366', format('{"trip_id": "%s", "kind": "todo", "title": "x", "due_days_before": 366}', pg_temp.id('ibiza'))),
  ('a negative due day', format('{"trip_id": "%s", "kind": "todo", "title": "x", "due_days_before": -1}', pg_temp.id('ibiza'))),
  ('a fractional due day', format('{"trip_id": "%s", "kind": "todo", "title": "x", "due_days_before": 1.5}', pg_temp.id('ibiza'))),
  ('a person who left', format('{"trip_id": "%s", "kind": "pack", "title": "x", "profile_id": "%s"}', pg_temp.id('ibiza'), pg_temp.id('ex'))),
  ('a person of another household', format('{"trip_id": "%s", "kind": "pack", "title": "x", "profile_id": "%s"}', pg_temp.id('ibiza'), pg_temp.id('bea'))),
  ('a person that is no uuid', format('{"trip_id": "%s", "kind": "pack", "title": "x", "profile_id": "mama"}', pg_temp.id('ibiza'))),
  ('no trip', '{"kind": "pack", "title": "x"}'),
  ('not an object', '[]')
) t(d, j) where pg_temp.bad('trip_check_save', t.j) is distinct from 'trip_check_invalid'), '', 'each of these is refused as an invalid check');
select is(pg_temp.bad('trip_check_save', format('{"trip_id": "%s", "kind": "pack", "title": "x"}', pg_temp.id('b3'))), 'trip_not_found', 'a check on another household''s trip is not found');
select is(pg_temp.bad('trip_check_save', format('{"id": "%s", "title": "x"}', pg_temp.id('k1')), 'bea'), 'trip_check_not_found', 'another household''s check cannot be saved');
select pg_temp.chk('k3', format('{"id": "%s", "due_days_before": null}', pg_temp.id('k3')));
select is((select title || ':' || coalesce(due_days_before::text, 'none') from app.trip_check where id = pg_temp.id('k3')), 'Nachbarn fragen:none', 'a due day is cleared with null, the title kept');
select pg_temp.chk('k3', format('{"id": "%s", "due_days_before": 14}', pg_temp.id('k3')));
select is(pg_temp.bad('trip_check_save', format('{"id": "%s", "kind": "pack"}', pg_temp.id('k3'))), 'trip_check_invalid', 'a to-do with a due day does not become packing');

-- Adding the starter list.
select is(pg_temp.call('papa', format($q$ select api.trip_checks_add(null, %L, '[{"kind": "pack", "title": "Ladegeräte"}, {"kind": "pack", "title": "Apotheke"}, {"kind": "pack", "title": "Badesachen", "profile_id": "%s"}, {"kind": "todo", "title": "Pässe prüfen", "due_days_before": 60}, {"kind": "pack", "title": " reisepässe "}]'::jsonb) $q$,
  pg_temp.id('ibiza'), pg_temp.id('mama'))), '{"added": 4}'::jsonb, 'four of five are added: a title the trip has is skipped, ignoring blanks and case');
select is(pg_temp.call('papa', format($q$ select api.trip_checks_add(null, %L, '[{"kind": "pack", "title": "Ladegeräte"}, {"kind": "todo", "title": "Ladegeräte"}, {"kind": "pack", "title": "Badesachen"}, {"kind": "pack", "title": "BADESACHEN", "profile_id": "%s"}, {"kind": "pack", "title": "Sonnencreme"}, {"kind": "pack", "title": "SONNENCREME "}]'::jsonb) $q$,
  pg_temp.id('ibiza'), pg_temp.id('mama'))), '{"added": 3}'::jsonb,
  'the same title for another kind or another person counts as new; twice in one list, once');
select is((select count(*)::int from app.trip_check where trip_id = pg_temp.id('ibiza') and lower(btrim(title)) = 'sonnencreme'), 1, 'and the duplicate in the list is not added');
select is(pg_temp.call('papa', format($q$ select api.trip_checks_add(null, %L, '[]'::jsonb) $q$, pg_temp.id('ibiza'))), '{"added": 0}'::jsonb, 'an empty list adds nothing');
select is((select coalesce(string_agg(t.d, '; '), '') from (values
  ('a hundred and one', (select jsonb_agg(jsonb_build_object('kind', 'pack', 'title', 'x' || g))::text from generate_series(1, 101) g)),
  ('an element that is no object', '["x"]'),
  ('a bad kind', '[{"kind": "pack", "title": "ok1"}, {"kind": "buy", "title": "x"}]'),
  ('a due day on packing', '[{"kind": "pack", "title": "ok2", "due_days_before": 1}]'),
  ('a person who left', format('[{"kind": "pack", "title": "ok3", "profile_id": "%s"}]', pg_temp.id('ex'))),
  ('no title', '[{"kind": "pack"}]'),
  ('not an array', '{"kind": "pack", "title": "x"}')
) t(d, j) where pg_temp.hint('papa', format('select api.trip_checks_add(null, %L, %L::jsonb)', pg_temp.id('ibiza'), t.j)) is distinct from 'trip_check_invalid'),
  '', 'each of these lists is refused');
select is((select count(*)::int from app.trip_check where title in ('ok1', 'ok2', 'ok3')), 0, 'and writes nothing, even the good ones before the bad one');
select lives_ok($q$ select pg_temp.run('papa', format('select api.trip_checks_add(null, %L, (select jsonb_agg(jsonb_build_object(''kind'', ''pack'', ''title'', ''h'' || g)) from generate_series(1, 100) g))', pg_temp.id('imp2'))) $q$,
  'a hundred are taken');
select is(pg_temp.hint('papa', format($q$ select api.trip_checks_add(null, %L, '[]'::jsonb) $q$, pg_temp.id('b3'))), 'trip_not_found', 'another household''s trip takes no checks');

-- Copying a list.
select pg_temp.trip('tessin', '{"title": "Tessin"}');
select pg_temp.run('papa', format('select api.trip_check_tick(null, %L, true)', pg_temp.id('k1')));
select is(pg_temp.call('papa', format('select api.trip_checks_copy(null, %L, %L)', pg_temp.id('ibiza'), pg_temp.id('tessin'))),
  (select jsonb_build_object('added', count(*)) from app.trip_check where trip_id = pg_temp.id('ibiza')), 'the checks of another trip are copied');
select is((select count(*)::int from app.trip_check where trip_id = pg_temp.id('tessin') and done_at is null and done_by_profile_id is null),
  (select count(*)::int from app.trip_check where trip_id = pg_temp.id('ibiza')), 'unticked');
select is((select string_agg(kind || ':' || title || ':' || coalesce(profile_id::text, '-') || ':' || coalesce(due_days_before::text, '-') || ':' || position, ',' order by kind, title, profile_id)
             from app.trip_check where trip_id = pg_temp.id('tessin')),
  (select string_agg(kind || ':' || title || ':' || coalesce(profile_id::text, '-') || ':' || coalesce(due_days_before::text, '-') || ':' || position, ',' order by kind, title, profile_id)
             from app.trip_check where trip_id = pg_temp.id('ibiza')), 'with kind, title, person, due day and place');
select is(pg_temp.call('papa', format('select api.trip_checks_copy(null, %L, %L)', pg_temp.id('ibiza'), pg_temp.id('tessin'))), '{"added": 0}'::jsonb, 'a second copy skips what is there');
select is(pg_temp.call('papa', format('select api.trip_checks_copy(null, %L, %L)', pg_temp.id('ibiza'), pg_temp.id('ibiza'))), '{"added": 0}'::jsonb, 'a trip copied onto itself gains nothing');
select is(pg_temp.hint('papa', format('select api.trip_checks_copy(null, %L, %L)', pg_temp.id('b3'), pg_temp.id('tessin'))), 'trip_not_found', 'from another household''s trip is refused');
select is(pg_temp.hint('papa', format('select api.trip_checks_copy(null, %L, %L)', pg_temp.id('ibiza'), pg_temp.id('b3'))), 'trip_not_found', 'and onto it');
select is(pg_temp.hint('papa', format('select api.trip_checks_copy(null, %L, %L)', gen_random_uuid(), pg_temp.id('tessin'))), 'trip_not_found', 'and from one that does not exist');

-- Ticking.
select is((select done_at is not null and done_by_profile_id = pg_temp.id('papa') from app.trip_check where id = pg_temp.id('k1')), true, 'a tick is dated and signed');
select pg_temp.run('opa', format('select api.trip_check_tick(null, %L, true)', pg_temp.id('k1')));
select is((select done_by_profile_id from app.trip_check where id = pg_temp.id('k1')), pg_temp.id('papa'), 'a second tick keeps the first');
select pg_temp.run('opa', format('select api.trip_check_tick(null, %L, true)', pg_temp.id('k2')));
select is((select done_by_profile_id from app.trip_check where id = pg_temp.id('k2')), pg_temp.id('opa'), 'an adult who is no guardian ticks');
select pg_temp.run('mama', format('select api.trip_check_tick(null, %L, false)', pg_temp.id('k1')));
select is((select done_at is null and done_by_profile_id is null from app.trip_check where id = pg_temp.id('k1')), true, 'anyone unticks');
select is(pg_temp.hint('papa', format('select api.trip_check_tick(null, %L, null)', pg_temp.id('k1'))), 'trip_check_invalid', 'a tick that is neither on nor off');
select is(pg_temp.hint('bea', format('select api.trip_check_tick(null, %L, true)', pg_temp.id('k1'))), 'trip_check_not_found', 'another household''s check is not ticked');
select pg_temp.act_as_dev('kind');
select is((select count(*)::int from api.trip_checks where trip_id = pg_temp.id('ibiza')), (select count(*)::int from app.trip_check where trip_id = pg_temp.id('ibiza')),
  'a child sees the list, and may not change it');
reset role;
select pg_temp.run('papa', format('select api.trip_check_delete(null, %L)', pg_temp.id('k3')));
select is((select count(*)::int from app.trip_check where id = pg_temp.id('k3')), 0, 'a check is deleted');
select is(pg_temp.hint('papa', format('select api.trip_check_delete(null, %L)', pg_temp.id('k3'))), 'trip_check_not_found', 'once');

-- ---- 7. The home place ------------------------------------------------------------------------------------
select pg_temp.run('papa', $q$ select api.trip_home_set(null, '{"name": "Zürich", "lat": 47.3769, "lon": 8.5417}'::jsonb) $q$);
select is((select name || ':' || lat || ':' || lon from app.trip_home where household_id = pg_temp.id('hh_a')), 'Zürich:47.38:8.54', 'a guardian sets the home place, rounded to two decimals');
select pg_temp.act_as_dev('kind');
select is((select name || ':' || lat || ':' || lon from api.trip_home), 'Zürich:47.38:8.54', 'every device of the household reads it');
reset role;
select pg_temp.run('papa', $q$ select api.trip_home_set(null, '{"name": "Basel", "lat": -89.996, "lon": -180}'::jsonb) $q$);
select is((select name || ':' || lat || ':' || lon from app.trip_home where household_id = pg_temp.id('hh_a')), 'Basel:-90.00:-180.00', 'a second call replaces it');
select is((select count(*)::int from app.trip_home), 1, 'there is one per household');
select is((select coalesce(string_agg(t.d, '; '), '') from (values
  ('latitude 91', '{"name": "x", "lat": 91, "lon": 0}'),
  ('longitude 181', '{"name": "x", "lat": 0, "lon": 181}'),
  ('no longitude', '{"name": "x", "lat": 0}'),
  ('no latitude', '{"name": "x", "lon": 0}'),
  ('coordinates as text', '{"name": "x", "lat": "1", "lon": "2"}'),
  ('a name of 121', format('{"name": "%s", "lat": 0, "lon": 0}', repeat('n', 121))),
  ('a name that is no text', '{"name": 5, "lat": 0, "lon": 0}'),
  ('not an object', '"home"'),
  ('an array', '[]')
) t(d, j) where pg_temp.bad('trip_home_set', t.j) is distinct from 'trip_home_invalid'), '', 'each of these is refused as an invalid home place');
select is((select name from app.trip_home where household_id = pg_temp.id('hh_a')), 'Basel', 'and the place is as it was');
select is(pg_temp.hint('opa', $q$ select api.trip_home_set(null, '{"name": "x", "lat": 0, "lon": 0}'::jsonb) $q$), 'guardian_required', 'an adult who is no guardian cannot set it');
select is(pg_temp.hint('opa', $q$ select api.trip_home_set(null, null) $q$), 'guardian_required', 'nor forget it');
select is(pg_temp.hint('kind', $q$ select api.trip_home_set(null, null) $q$), 'adults_only', 'a child cannot');
select is(pg_temp.hint('ipad', format($q$ select api.trip_home_set(%L, null) $q$, pg_temp.id('mama'))), 'guardian_required', 'a guardian at a shared device needs the step-up first');
select pg_temp.run('bea', $q$ select api.trip_home_set(null, '{"name": "Bern", "lat": 46.95, "lon": 7.45}'::jsonb) $q$);
select is((select name from app.trip_home where household_id = pg_temp.id('hh_a')), 'Basel', 'another household''s guardian sets its own place only');
select is((select count(*)::int from app.trip_home where household_id = pg_temp.id('hh_b')), 1, 'which is its own');
select pg_temp.run('papa', $q$ select api.trip_home_set(null, null) $q$);
select is((select count(*)::int from app.trip_home where household_id = pg_temp.id('hh_a')), 0, 'null forgets the place');
select pg_temp.run('papa', $q$ select api.trip_home_set(null, 'null'::jsonb) $q$);
select pg_temp.run('papa', $q$ select api.trip_home_set(null, '{"lat": 1, "lon": 2}'::jsonb) $q$);
select is((select name from app.trip_home where household_id = pg_temp.id('hh_a')), '', 'a place may have no name');

-- ---- 8. Every function: who may, and who is kept out ------------------------------------------------
create temp table calls (name text primary key, sql text, xhint text);
grant all on calls to public;
-- %1$L the acting profile, %2$L a trip, %3$L an entry, %4$L a combination, %5$L a check (all of household A).
insert into calls values
  ('trip_save', 'select api.trip_save(%1$L, jsonb_build_object(''id'', %2$L::text, ''title'', ''x''))', 'trip_not_found'),
  ('trip_delete', 'select api.trip_delete(%1$L, %2$L)', 'trip_not_found'),
  ('trip_entry_save', 'select api.trip_entry_save(%1$L, jsonb_build_object(''id'', %3$L::text, ''title'', ''x''))', 'trip_entry_not_found'),
  ('trip_entry_delete', 'select api.trip_entry_delete(%1$L, %3$L)', 'trip_entry_not_found'),
  ('trip_entry_copy', 'select api.trip_entry_copy(%1$L, %3$L)', 'trip_entry_not_found'),
  ('trip_entries_import', 'select api.trip_entries_import(%1$L, %2$L, ''[]''::jsonb)', 'trip_not_found'),
  ('trip_combo_save', 'select api.trip_combo_save(%1$L, jsonb_build_object(''id'', %4$L::text, ''name'', ''x''))', 'trip_combo_not_found'),
  ('trip_combo_delete', 'select api.trip_combo_delete(%1$L, %4$L)', 'trip_combo_not_found'),
  ('trip_combo_choose', 'select api.trip_combo_choose(%1$L, %4$L, false)', 'trip_combo_not_found'),
  ('trip_check_save', 'select api.trip_check_save(%1$L, jsonb_build_object(''id'', %5$L::text, ''title'', ''x''))', 'trip_check_not_found'),
  ('trip_checks_add', 'select api.trip_checks_add(%1$L, %2$L, ''[]''::jsonb)', 'trip_not_found'),
  ('trip_checks_copy', 'select api.trip_checks_copy(%1$L, %2$L, %2$L)', 'trip_not_found'),
  ('trip_check_tick', 'select api.trip_check_tick(%1$L, %5$L, true)', 'trip_check_not_found'),
  ('trip_check_delete', 'select api.trip_check_delete(%1$L, %5$L)', 'trip_check_not_found'),
  ('trip_home_set', 'select api.trip_home_set(%1$L, null)', null);
create function pg_temp.m_sql(p_sql text, p_actor uuid) returns text language sql as $$
  select format(p_sql, p_actor, pg_temp.id('ibiza'), pg_temp.id('f1'), pg_temp.id('cA'), pg_temp.id('k1'))
$$;
create function pg_temp.m_hint(p_sql text, p_actor uuid) returns text language sql as $$
  select pg_temp.error_hint(pg_temp.m_sql(p_sql, p_actor))
$$;
create function pg_temp.m_state(p_sql text, p_actor uuid) returns text language sql as $$
  select pg_temp.state(pg_temp.m_sql(p_sql, p_actor))
$$;
reset role;
insert into snaps values ('matrix', pg_temp.snap());

select pg_temp.act_as_dev('kiosk');
select is((select coalesce(string_agg(name, ','), '') from calls where pg_temp.m_hint(sql, pg_temp.id('papa')) is distinct from 'kiosk_forbidden'), '',
  'the wall may call none of the trip functions, whoever it says is acting');
select pg_temp.act_as_dev('kind');
select is((select coalesce(string_agg(name, ','), '') from calls where pg_temp.m_hint(sql, null) is distinct from 'adults_only'), '',
  'a child on a phone of their own may call none');
select pg_temp.act_as_dev('ipad');
select is((select coalesce(string_agg(name, ','), '') from calls where pg_temp.m_hint(sql, pg_temp.id('kind')) is distinct from 'adults_only'), '',
  'nor a child at a shared device');
select is((select coalesce(string_agg(name, ','), '') from calls where pg_temp.m_hint(sql, null) is distinct from 'actor_required'), '',
  'a shared device must say who acts');
select pg_temp.act_as_dev('papa_old');
select is((select coalesce(string_agg(name, ','), '') from calls where pg_temp.m_hint(sql, null) is distinct from 'device_revoked'), '',
  'a revoked device may call none');
select pg_temp.act_as_dev('bea');
select is((select coalesce(string_agg(name, ','), '') from calls where xhint is not null and pg_temp.m_hint(sql, null) is distinct from xhint), '',
  'another household finds no trip, entry, combination or check of this one');
reset role;
select is(pg_temp.snap(), (select v from snaps where name = 'matrix'), 'and none of those refusals wrote anything');
set local role anon;
select is((select coalesce(string_agg(name, ','), '') from calls where pg_temp.m_state(sql, null) is distinct from '42501'), '',
  'an anonymous caller may call none');
reset role;
select is((select coalesce(string_agg(f, ','), '') from (select p.oid::regprocedure::text f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'api' and p.proname like 'trip%'
              and (has_function_privilege('anon', p.oid, 'execute') or not has_function_privilege('authenticated', p.oid, 'execute'))) q), '',
  'every trip function is for authenticated users only');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'api' and p.proname like 'trip%'), 15,
  'and there are fifteen of them, each in the list above');
-- An adult who is no guardian is no less an adult.
select lives_ok($$ select pg_temp.trip('opa_trip', '{"title": "Opas Idee"}', 'opa') $$, 'an adult who is no guardian saves a trip');
select lives_ok(format($$ select pg_temp.entry(null, '{"trip_id": "%s", "kind": "note", "title": "Karte"}', 'opa') $$, pg_temp.id('opa_trip')), 'an entry');
select is(pg_temp.call('opa', format($q$ select api.trip_checks_add(null, %L, '[{"kind": "pack", "title": "Hut"}]'::jsonb) $q$, pg_temp.id('opa_trip'))), '{"added": 1}'::jsonb, 'and a check');
select lives_ok(format($$ select pg_temp.run('opa', 'select api.trip_delete(null, ''%s'')') $$, pg_temp.id('opa_trip')), 'and deletes it again');

-- ---- 9. The views ------------------------------------------------------------------------------------------
select pg_temp.act_as_dev('kiosk');
select is((select count(*)::int from api.trips) > 0 and (select count(*)::int from api.trip_entries) > 0 and (select count(*)::int from api.trip_checks) > 0
          and (select count(*)::int from api.trip_combos) > 0, true, 'the wall reads the trips of the household');
select pg_temp.act_as_dev('kind');
select is((select count(*)::int from api.trips), (select count(*)::int from app.trip where household_id = pg_temp.id('hh_a')), 'a child reads them too');
select throws_ok($$ insert into app.trip (household_id, title, stage, currency) values (gen_random_uuid(), 'x', 'idea', 'EUR') $$, '42501', null, 'but writes none directly');
select throws_ok($$ update app.trip_entry set title = 'x' $$, '42501', null, 'not even an entry');
select throws_ok($$ delete from app.trip_check $$, '42501', null, 'or a check');
select pg_temp.act_as_dev('bea');
select is((select count(*)::int from api.trips where id = pg_temp.id('ibiza')) + (select count(*)::int from api.trip_entries where id = pg_temp.id('f1'))
          + (select count(*)::int from api.trip_combos where id = pg_temp.id('cA')) + (select count(*)::int from api.trip_checks where id = pg_temp.id('k1')),
  0, 'another household sees none of this household''s rows');
select is((select count(*)::int from app.trip) + (select count(*)::int from app.trip_entry) + (select count(*)::int from app.trip_member)
          + (select count(*)::int from app.trip_combo_entry) - (select count(*)::int from app.trip where household_id = pg_temp.id('hh_b'))
          - (select count(*)::int from app.trip_entry where household_id = pg_temp.id('hh_b')) - (select count(*)::int from app.trip_member where household_id = pg_temp.id('hh_b'))
          - (select count(*)::int from app.trip_combo_entry where household_id = pg_temp.id('hh_b')), 0, 'nor in the tables');
select is((select name from api.trip_home), 'Bern', 'it reads its own home place');
select pg_temp.act_as_dev('papa_old');
select is((select count(*)::int from api.trips) + (select count(*)::int from api.trip_entries) + (select count(*)::int from api.trip_combos)
          + (select count(*)::int from api.trip_checks) + (select count(*)::int from api.trip_home), 0, 'a revoked device reads nothing');
reset role;
set local role anon;
select is((select coalesce(string_agg(v, ','), '') from unnest(array['trips', 'trip_entries', 'trip_combos', 'trip_checks', 'trip_home']) v
            where pg_temp.state('select count(*) from api.' || v) is distinct from '42501'), '', 'an anonymous caller reads none of the views');
select is((select coalesce(string_agg(t, ','), '') from unnest(array['trip', 'trip_member', 'trip_entry', 'trip_combo', 'trip_combo_entry', 'trip_check', 'trip_home']) t
            where pg_temp.state('select count(*) from app.' || t) is distinct from '42501'), '', 'nor the tables');
reset role;

-- ---- 10. The audit log -----------------------------------------------------------------------------------
select is((select coalesce(string_agg(w.e || ':' || w.a, ','), '') from (values
  ('trip', 'create'), ('trip', 'update'), ('trip', 'delete'), ('trip_entry', 'create'), ('trip_entry', 'update'), ('trip_entry', 'copy'),
  ('trip_entry', 'delete'), ('trip_combo', 'create'), ('trip_combo', 'update'), ('trip_combo', 'choose'), ('trip_combo', 'delete'),
  ('trip_check', 'create'), ('trip_check', 'update'), ('trip_check', 'add'), ('trip_check', 'copy'), ('trip_check', 'tick'),
  ('trip_check', 'untick'), ('trip_check', 'delete'), ('trip_home', 'set'), ('trip_home', 'delete')) w(e, a)
  where not exists (select 1 from app.audit_log l where l.entity_type = w.e and l.action = w.a and l.household_id = pg_temp.id('hh_a'))), '',
  'every kind of write left an audit row');
select is((select diff ->> 'title' || ':' || (diff ->> 'stage') from app.audit_log where entity_type = 'trip' and entity_id = pg_temp.id('ibiza') and action = 'create'),
  'Ibiza:planned', 'the audit row of a trip names it and its stage');
select is((select actor_profile_id from app.audit_log where entity_type = 'trip_check' and action = 'tick' and entity_id = pg_temp.id('k2')), pg_temp.id('opa'), 'and who did it');
select is((select jsonb_array_length(jsonb_agg(1)) from app.audit_log where entity_type = 'trip_combo' and action = 'choose' and diff ->> 'dates_set' = 'true'), 3,
  'a combination taken says whether it set the dates');

-- ---- 11. Taking a trip away --------------------------------------------------------------------------------
insert into ids values ('plan_event', pg_temp.eid('plan'));
select is((select count(*)::int from app.trip_entry where trip_id = pg_temp.id('plan')), 10, 'the plan has its entries before it goes');
select pg_temp.run('papa', format('select api.trip_delete(null, %L)', pg_temp.id('plan')));
select is((select count(*)::int from app.trip where id = pg_temp.id('plan')), 0, 'a deleted trip is gone');
select is((select count(*)::int from app.trip_entry where trip_id = pg_temp.id('plan')) + (select count(*)::int from app.trip_combo where trip_id = pg_temp.id('plan'))
          + (select count(*)::int from app.trip_check where trip_id = pg_temp.id('plan')) + (select count(*)::int from app.trip_member where trip_id = pg_temp.id('plan')), 0,
  'with its entries, combinations, checks and members');
select is((select count(*)::int from app.trip_combo_entry ce where not exists (select 1 from app.trip_combo c where c.id = ce.combo_id)), 0, 'and the combinations'' entries');
select is((select deleted_at is not null and trip_id is null and sequence > 0 from app.event where id = pg_temp.id('plan_event')), true,
  'its calendar entry is soft-deleted, like an event, and detached');
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from api.events where id = pg_temp.id('plan_event')), 0, 'the calendar shows it no more');
reset role;
select is(pg_temp.hint('papa', format('select api.trip_delete(null, %L)', pg_temp.id('plan'))), 'trip_not_found', 'a trip is deleted once');
select is(pg_temp.hint('papa', format('select api.trip_delete(null, %L)', pg_temp.id('b3'))), 'trip_not_found', 'and another household''s never');
select is(current_setting('app.trip_sync', true), 'off', 'the guard is closed after a delete');

-- A household takes everything with it.
select pg_temp.trip('b3', format('{"id": "%s", "stage": "fixed", "starts_on": "2027-08-01", "ends_on": "2027-08-10"}', pg_temp.id('b3')), 'bea');
select pg_temp.chk('bk', format('{"trip_id": "%s", "kind": "pack", "title": "Hut"}', pg_temp.id('b3')), 'bea');
select pg_temp.combo('bc', format('{"trip_id": "%s", "name": "Eins", "entry_ids": ["%s"]}', pg_temp.id('b3'), pg_temp.id('be1')), 'bea');
select is((select count(*)::int from app.event where trip_id = pg_temp.id('b3')), 1, 'household B has a fixed trip with a calendar entry, an entry, a combination, a check and a home place');
select lives_ok(format($$ delete from app.household where id = %L $$, pg_temp.id('hh_b')), 'deleting the household works, the calendar entry of its trip included');
select is((select count(*)::int from app.trip where household_id = pg_temp.id('hh_b')) + (select count(*)::int from app.trip_member where household_id = pg_temp.id('hh_b'))
        + (select count(*)::int from app.trip_entry where household_id = pg_temp.id('hh_b')) + (select count(*)::int from app.trip_combo where household_id = pg_temp.id('hh_b'))
        + (select count(*)::int from app.trip_combo_entry where household_id = pg_temp.id('hh_b')) + (select count(*)::int from app.trip_check where household_id = pg_temp.id('hh_b'))
        + (select count(*)::int from app.trip_home where household_id = pg_temp.id('hh_b')) + (select count(*)::int from app.event where household_id = pg_temp.id('hh_b')), 0,
  'and no row of it remains');
select is((select count(*)::int from app.trip where household_id = pg_temp.id('hh_a')) > 0, true, 'household A is untouched');
-- A profile that is deleted leaves the calendar entry it created alone.
update app.event set created_by_profile_id = pg_temp.id('kind2') where id = pg_temp.eid('ibiza');
select lives_ok(format($$ delete from app.profile where id = %L $$, pg_temp.id('kind2')), 'a profile who created a trip''s entry can be deleted: the guard does not mind the creator going');
select is((select created_by_profile_id from app.event where trip_id = pg_temp.id('ibiza') and deleted_at is null), null, 'the creator link is cleared');
select is(pg_temp.ev('ibiza'), 'Ibiza 27|Ibiza|beach|appointment|true|2027-07-11|2027-07-24|confirmed|key|true', 'and nothing else of the entry changed');

select * from finish();
rollback;
