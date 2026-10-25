begin;
select plan(114);

-- Event templates and suggestions (specs/28, migration 20261025150000): the signature, saved
-- templates with their rules and perimeter, hidden suggestions, and what api.event_suggestions
-- counts, leaves out and puts first.

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

create function pg_temp.id(p_name text) returns uuid language sql as $$
  select id from ids where name = p_name
$$;

create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- The hint a statement fails with, or null when it succeeds.
create function pg_temp.error_hint(p_sql text) returns text language plpgsql as $$
declare v_hint text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint;
  return v_hint;
end $$;

-- The SQLSTATE a statement fails with, or null when it succeeds.
create function pg_temp.error_state(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlstate;
end $$;

-- The hint of api.event_template_save(p_actor, p_template).
create function pg_temp.save_hint(p_actor text, p_template jsonb) returns text language sql as $$
  select pg_temp.error_hint(format('select api.event_template_save(%L, %L::jsonb)', pg_temp.id(p_actor), p_template))
$$;

-- ---- household A: Papa (guardian, personal phone), Emma (child), Paul (adult member) ----------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#7B3FE4', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into app.profile (household_id, display_name, role, kind)
  select (r ->> 'household_id')::uuid, 'Emma', 'member', 'child' from sa;
insert into app.profile (household_id, display_name, role)
  select (r ->> 'household_id')::uuid, 'Paul', 'member' from sa;
insert into app.profile (household_id, display_name, role, active)
  select (r ->> 'household_id')::uuid, 'Opa', 'member', false from sa;
insert into ids select lower(p.display_name), p.id from app.profile p where p.household_id = pg_temp.id('hh_a');

insert into users values
  ('ipad', app.create_auth_user('ipad@devices.invalid', 'x1234567890')),
  ('kiosk', app.create_auth_user('kiosk@devices.invalid', 'x1234567890')),
  ('old', app.create_auth_user('old@example.org', 'longpassword1'));

insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.id('hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = pg_temp.id('papa');
insert into app.device (household_id, auth_user_id, label, class, register)
  select pg_temp.id('hh_a'), usr, 'iPad', 'shared', 'kid' from users where name = 'ipad';
insert into app.device (household_id, auth_user_id, label, class, register)
  select pg_temp.id('hh_a'), usr, 'Kiosk', 'kiosk', 'kiosk' from users where name = 'kiosk';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  select pg_temp.id('hh_a'), usr, 'Old-Phone', 'personal', 'adult', pg_temp.id('papa'), now()
    from users where name = 'old';

insert into devs
  select 'papa', d.auth_user_id, d.id, d.household_id, 'personal' from app.device d where d.label = 'A-Phone'
  union all
  select 'ipad', u.usr, d.id, d.household_id, 'shared' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'ipad'
  union all
  select 'kiosk', u.usr, d.id, d.household_id, 'kiosk' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'kiosk'
  union all
  select 'old', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'old';

-- ---- household B, made by hand -----------------------------------------------------------------
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into users select 'b', app.create_auth_user('b@example.org', 'longpassword1');
insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_b'), 'B', 'guardian', usr from users where name = 'b';
insert into ids select 'bob', p.id from app.profile p where p.household_id = pg_temp.id('hh_b');
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.id('hh_b'), u.usr, 'B-Phone', 'personal', 'adult', p.id
    from users u join app.profile p on p.auth_user_id = u.usr where u.name = 'b';
insert into devs
  select 'b', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id
   where u.name = 'b';

-- One event, written as the owner. p_day is days from the household's today; timed events start
-- at p_time in the household's zone and last p_minutes, all-day ones last p_days.
create function pg_temp.ev(p_title text, p_day int, p_time time default '18:30', p_minutes int default 180,
                           p_people text[] default '{}', p_icon text default null, p_location text default null,
                           p_all_day boolean default false, p_days int default 1,
                           p_kind text default 'appointment', p_presence text default null,
                           p_rrule text default null, p_rdates date[] default null,
                           p_tradition boolean default false, p_deleted boolean default false,
                           p_hh text default 'hh_a') returns uuid language plpgsql as $$
declare
  v_id  uuid := gen_random_uuid();
  v_tz  text;
  v_day date;
begin
  select timezone into v_tz from app.household where id = pg_temp.id(p_hh);
  v_day := (now() at time zone v_tz)::date + p_day;
  insert into app.event (id, household_id, calendar_id, title, kind, presence_state, is_all_day,
                         starts_at, ends_at, start_date, end_date, timezone, uid, icon_key, location,
                         rrule, rdates, tradition, deleted_at)
  values (v_id, pg_temp.id(p_hh),
          (select c.id from app.calendar c where c.household_id = pg_temp.id(p_hh) order by c.created_at, c.id limit 1),
          p_title, p_kind, p_presence, p_all_day,
          case when not p_all_day then (v_day + p_time) at time zone v_tz end,
          case when not p_all_day then (v_day + p_time) at time zone v_tz + make_interval(mins => p_minutes) end,
          case when p_all_day then v_day end, case when p_all_day then v_day + p_days - 1 end,
          v_tz, v_id::text || '@test.invalid', p_icon, p_location, p_rrule, p_rdates, p_tradition,
          case when p_deleted then now() end);
  insert into app.event_attendee (event_id, profile_id, household_id)
    select v_id, pg_temp.id(x), pg_temp.id(p_hh) from unnest(p_people) x;
  return v_id;
end $$;

-- The signatures of a suggestion list, in its order.
create function pg_temp.sigs(p jsonb) returns text language sql as $$
  select string_agg(e ->> 'signature', ',' order by o) from jsonb_array_elements(p) with ordinality x(e, o)
$$;

create temp table today as
  select (now() at time zone h.timezone)::date as d from app.household h where h.id = pg_temp.id('hh_a');
grant all on today to public;

-- ================================================================ the tables
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'app.event_template'::regclass),
  'event_template has RLS enabled and forced');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'app.event_suggestion_hidden'::regclass),
  'event_suggestion_hidden has RLS enabled and forced');
select ok(exists (select 1 from app.export_table where name = 'event_template')
          and exists (select 1 from app.export_table where name = 'event_suggestion_hidden'),
  'both tables are in the export');
select ok(api.server_info() -> 'features' ? 'event-templates', 'the server announces event templates');
select ok(api.server_info() -> 'features' ? 'lighter-day', 'and still a lighter day');

-- ================================================================ the signature
select is(app.event_signature('  Grosi  kommt! '), 'grosi kommt', 'lower case, one space, no punctuation at the ends');
select is(app.event_signature(E'Fussball\t\n Training'), 'fussball training', 'any run of white space is one space');
select is(app.event_signature('"Kino"...?'), 'kino', 'punctuation at both ends goes');
select is(app.event_signature('Dr. Müller'), 'dr. müller', 'punctuation inside stays');
select is(app.event_signature(' ?! '), null, 'nothing left is null');
select is(app.event_signature(null), null, 'null stays null');
select ok(length(app.event_signature(repeat('ab ', 100))) <= 120, 'a signature has at most 120 characters');
select is(app.event_signature(app.event_signature(repeat('ab ', 100))), app.event_signature(repeat('ab ', 100)),
  'a signature is its own signature');

-- ================================================================ saving a template
select pg_temp.act_as_dev('ipad');
create temp table t1 as select api.event_template_save(pg_temp.id('emma'), jsonb_build_object(
  'title', '  Gäste zum Essen ', 'icon_key', 'house', 'kind', 'appointment', 'is_all_day', false,
  'start_minute', 1110, 'duration_minutes', 180, 'days', 3,
  'attendee_ids', jsonb_build_array(pg_temp.id('paul'), pg_temp.id('emma'), pg_temp.id('emma')),
  'location', 'Bei uns', 'description', 'Raclette', 'importance', 'key', 'countdown', true)) r;
insert into ids select 'tpl_emma', (r ->> 'id')::uuid from t1;
select is((select title || '|' || icon_key || '|' || kind || '|' || is_all_day || '|' || start_minute || '|'
                  || duration_minutes || '|' || coalesce(days::text, '-') || '|' || location || '|' || description
                  || '|' || importance || '|' || countdown
             from api.event_templates where id = pg_temp.id('tpl_emma')),
  'Gäste zum Essen|house|appointment|false|1110|180|-|Bei uns|Raclette|key|true',
  'a member saves a template; a timed one keeps no days');
select is((select attendee_ids from api.event_templates where id = pg_temp.id('tpl_emma')),
  (select array_agg(x order by x) from unnest(array[pg_temp.id('paul'), pg_temp.id('emma')]) x),
  'its people once each');
select is((select created_by_profile_id from api.event_templates where id = pg_temp.id('tpl_emma')), pg_temp.id('emma'),
  'the acting profile is its author');
select is((select count(*)::int from app.audit_log where entity_type = 'event_template' and action = 'create'
            and entity_id = pg_temp.id('tpl_emma') and actor_profile_id = pg_temp.id('emma')), 1, 'the save is audited');

create temp table t2 as select api.event_template_save(pg_temp.id('paul'),
  '{"title":"Ferien","icon_key":"plane","is_all_day":true,"days":7,"start_minute":600,"duration_minutes":60}') r;
insert into ids select 'tpl_paul', (r ->> 'id')::uuid from t2;
select is((select kind || '|' || is_all_day || '|' || days || '|' || coalesce(start_minute::text, '-') || '|'
                  || coalesce(duration_minutes::text, '-') || '|' || coalesce(importance, '-') || '|' || countdown
                  || '|' || cardinality(attendee_ids)
             from api.event_templates where id = pg_temp.id('tpl_paul')),
  'appointment|true|7|-|-|-|false|0', 'the defaults; an all-day one keeps no start time or length');
select is(pg_temp.save_hint('emma', jsonb_build_object('title', 'Opa kommt', 'attendee_ids', jsonb_build_array(pg_temp.id('opa')))),
  null, 'a member no longer active may stay on a template');
select is(pg_temp.save_hint('emma', '{"title":"Homeoffice","kind":"presence","presence_state":"home_office","start_minute":480,"duration_minutes":540}'),
  null, 'a presence template');
-- One transaction has one now(): the templates are made older in the order they were saved.
reset role;
update app.event_template set created_at = created_at - case title when 'Gäste zum Essen' then interval '3 minutes'
  when 'Ferien' then interval '2 minutes' when 'Opa kommt' then interval '1 minute' else interval '0' end;
select pg_temp.act_as_dev('ipad');
select is((select string_agg(title, ',') from api.event_templates),
  'Gäste zum Essen,Ferien,Opa kommt,Homeoffice', 'the view lists them oldest first');

-- ================================================================ what a template may not be
select is(pg_temp.save_hint('emma', '"Gäste"'), 'template_invalid', 'not an object');
select is(pg_temp.save_hint('emma', '{"title":"   "}'), 'template_invalid', 'an empty title');
select is(pg_temp.save_hint('emma', jsonb_build_object('title', repeat('x', 121))), 'template_invalid', 'a title of 121 characters');
select is(pg_temp.save_hint('emma', '{"title":42}'), 'template_invalid', 'a title that is no string');
select is(pg_temp.save_hint('emma', '{"title":"x","kind":"meeting"}'), 'template_invalid', 'a bad kind');
select is(pg_temp.save_hint('emma', '{"title":"x","kind":"presence"}'), 'template_invalid', 'presence without a state');
select is(pg_temp.save_hint('emma', '{"title":"x","presence_state":"away"}'), 'template_invalid', 'a state on an appointment');
select is(pg_temp.save_hint('emma', '{"title":"x","kind":"presence","presence_state":"asleep"}'), 'template_invalid', 'a bad state');
select is(pg_temp.save_hint('emma', '{"title":"x","kind":"presence","presence_state":"away","countdown":true}'),
  'template_invalid', 'a presence template counts down to nothing');
select is(pg_temp.save_hint('emma', '{"title":"x","kind":"presence","presence_state":"away","icon_key":"plane"}'),
  'template_invalid', 'and carries no picture');
select is(pg_temp.save_hint('emma', '{"title":"x","icon_key":"Kuchen!"}'), 'template_invalid', 'a bad picture');
select is(pg_temp.save_hint('emma', '{"title":"x","start_minute":1440}'), 'template_invalid', 'a start after 23:59');
select is(pg_temp.save_hint('emma', '{"title":"x","start_minute":-1}'), 'template_invalid', 'a start before midnight');
select is(pg_temp.save_hint('emma', '{"title":"x","duration_minutes":4}'), 'template_invalid', 'shorter than five minutes');
select is(pg_temp.save_hint('emma', '{"title":"x","duration_minutes":10081}'), 'template_invalid', 'longer than a week');
select is(pg_temp.save_hint('emma', '{"title":"x","duration_minutes":30.5}'), 'template_invalid', 'a fraction of a minute');
select is(pg_temp.save_hint('emma', '{"title":"x","duration_minutes":"60"}'), 'template_invalid', 'a number as a string');
select is(pg_temp.save_hint('emma', '{"title":"x","is_all_day":true,"days":367}'), 'template_invalid', 'more than 366 days');
select is(pg_temp.save_hint('emma', '{"title":"x","is_all_day":"yes"}'), 'template_invalid', 'all day that is no boolean');
select is(pg_temp.save_hint('emma', '{"title":"x","countdown":1}'), 'template_invalid', 'a countdown that is no boolean');
select is(pg_temp.save_hint('emma', '{"title":"x","importance":"high"}'), 'template_invalid', 'a bad importance');
select is(pg_temp.save_hint('emma', jsonb_build_object('title', 'x', 'location', repeat('x', 201))), 'template_invalid', 'a long place');
select is(pg_temp.save_hint('emma', jsonb_build_object('title', 'x', 'description', repeat('x', 4001))), 'template_invalid', 'long notes');
select is(pg_temp.save_hint('emma', jsonb_build_object('title', 'x', 'attendee_ids', jsonb_build_array(pg_temp.id('bob')))),
  'template_invalid', 'someone of another household');
select is(pg_temp.save_hint('emma', jsonb_build_object('title', 'x', 'attendee_ids', jsonb_build_array(gen_random_uuid()))),
  'template_invalid', 'someone of no household');
select is(pg_temp.save_hint('emma', '{"title":"x","attendee_ids":["Emma"]}'), 'template_invalid', 'a name instead of an id');
select is(pg_temp.save_hint('emma', '{"title":"x","attendee_ids":"all"}'), 'template_invalid', 'people that are no list');
select is(pg_temp.save_hint('emma', '{"title":"x","id":"nope"}'), 'template_invalid', 'an id that is no uuid');
select is((select count(*)::int from app.event_template), 4, 'none of them was saved');

-- ================================================================ who changes and deletes a template
select is(pg_temp.save_hint('emma', jsonb_build_object('id', pg_temp.id('tpl_emma'), 'title', 'Gäste', 'icon_key', 'house')),
  null, 'its author changes it');
select is((select title || '|' || coalesce(location, '-') || '|' || countdown || '|' || (updated_at >= created_at)
             from app.event_template where id = pg_temp.id('tpl_emma')),
  'Gäste|-|false|true', 'a change replaces every value');
select is((select count(*)::int from app.event_template), 4, 'and adds none');
select is((select count(*)::int from app.audit_log where entity_type = 'event_template' and action = 'update'
            and entity_id = pg_temp.id('tpl_emma')), 1, 'the change is audited');
select is(pg_temp.save_hint('paul', jsonb_build_object('id', pg_temp.id('tpl_emma'), 'title', 'Meins')),
  'guardian_required', 'another member does not change it');
select is(pg_temp.error_hint(format('select api.event_template_delete(%L, %L)', pg_temp.id('paul'), pg_temp.id('tpl_emma'))),
  'guardian_required', 'nor delete it');
select is(pg_temp.save_hint('papa', jsonb_build_object('id', pg_temp.id('tpl_emma'), 'title', 'Gäste')),
  'guardian_required', 'a guardian on a shared device without the PIN does not either');
select is(pg_temp.save_hint('emma', jsonb_build_object('id', gen_random_uuid(), 'title', 'x')),
  'template_not_found', 'an unknown template is not found');
select is(pg_temp.error_hint(format('select api.event_template_delete(%L, %L)', pg_temp.id('emma'), gen_random_uuid())),
  'template_not_found', 'nor deleted');

select pg_temp.act_as_dev('kiosk');
select is(pg_temp.save_hint('papa', '{"title":"Wand"}'), 'kiosk_forbidden', 'the wall saves no template');
select is(pg_temp.error_hint(format('select api.event_template_delete(%L, %L)', pg_temp.id('papa'), pg_temp.id('tpl_paul'))),
  'kiosk_forbidden', 'nor deletes one');
select is(pg_temp.error_hint(format($q$ select api.event_suggestion_hide(%L, 'grosi kommt') $q$, pg_temp.id('papa'))),
  'kiosk_forbidden', 'nor hides a suggestion');

select pg_temp.act_as_dev('b');
select is(pg_temp.save_hint('bob', jsonb_build_object('id', pg_temp.id('tpl_emma'), 'title', 'Unseres')),
  'template_not_found', 'another household''s template is not found');
select is(pg_temp.error_hint(format('select api.event_template_delete(null, %L)', pg_temp.id('tpl_emma'))),
  'template_not_found', 'nor deleted from there');

select pg_temp.act_as_dev('papa');
select is(pg_temp.save_hint('papa', jsonb_build_object('id', pg_temp.id('tpl_emma'), 'title', 'Gäste zum Essen',
  'start_minute', 1110, 'duration_minutes', 180)), null, 'a guardian changes another''s template');
select is((select created_by_profile_id from app.event_template where id = pg_temp.id('tpl_emma')), pg_temp.id('emma'),
  'which stays its author''s');
select is(pg_temp.error_hint(format('select api.event_template_delete(null, %L)', pg_temp.id('tpl_paul'))), null,
  'a guardian deletes another''s template');
select is((select count(*)::int from app.event_template where id = pg_temp.id('tpl_paul')), 0, 'it is gone');
select is((select count(*)::int from app.audit_log where entity_type = 'event_template' and action = 'delete'
            and entity_id = pg_temp.id('tpl_paul') and actor_profile_id = pg_temp.id('papa')), 1, 'the delete is audited');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format('select api.event_template_delete(%L, %L)', pg_temp.id('emma'),
  (select id from app.event_template where title = 'Homeoffice'))), null, 'its author deletes a template');

-- ================================================================ at most 50
reset role;
insert into app.event_template (household_id, title, created_by_profile_id)
  select pg_temp.id('hh_a'), 'Vorlage ' || g, pg_temp.id('paul')
    from generate_series(1, 50 - (select count(*)::int from app.event_template where household_id = pg_temp.id('hh_a'))) g;
select pg_temp.act_as_dev('ipad');
select is(pg_temp.save_hint('paul', '{"title":"Eine zu viel"}'), 'template_limit', 'a household keeps at most 50');
select is(pg_temp.save_hint('paul', jsonb_build_object('id', (select id from app.event_template where title = 'Vorlage 1'),
  'title', 'Vorlage eins')), null, 'at 50 a template still changes');
select pg_temp.act_as_dev('b');
select is(pg_temp.save_hint('bob', '{"title":"Unsere erste"}'), null, 'another household''s count is its own');
reset role;
delete from app.event_template where title like 'Vorlage %' or title = 'Unsere erste';

-- ================================================================ the perimeter
select pg_temp.act_as_dev('old');
select is((select count(*)::int from app.event_template), 0, 'a revoked device reads no templates');
select is((select count(*)::int from api.event_templates), 0, 'nor through the view');
select is(pg_temp.save_hint('papa', '{"title":"x"}'), 'device_revoked', 'and saves none');
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.event_templates), 0, 'another household reads none of our templates');
reset role;
set local role anon;
select is(pg_temp.error_state('select count(*) from app.event_template'), '42501', 'anonymous callers read no templates');
select is(pg_temp.error_state('select count(*) from app.event_suggestion_hidden'), '42501', 'nor hidden suggestions');
select is(pg_temp.error_state('select count(*) from api.event_templates'), '42501', 'nor the view');
select is(pg_temp.error_state($q$ select api.event_template_save(null, '{"title":"x"}') $q$), '42501', 'and save none');
select is(pg_temp.error_state('select api.event_suggestions()'), '42501', 'and get no suggestions');
reset role;
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_state(format($q$ insert into app.event_template (household_id, title) values (%L, 'x') $q$,
  pg_temp.id('hh_a'))), '42501', 'no template is written past the api');
select is(pg_temp.error_state($q$ update app.event_template set title = 'x' $q$), '42501', 'nor changed');
select is(pg_temp.error_state(format($q$ insert into app.event_suggestion_hidden (household_id, signature) values (%L, 'x') $q$,
  pg_temp.id('hh_a'))), '42501', 'no suggestion is hidden past the api');

-- ================================================================ suggestions
-- Grosi: three recent evenings at home (two of them on today's weekday).
-- Ausflug: three recent days out, all day. Fussball: five Saturdays-or-so long ago (weight ½ each),
-- on the weekday before today's, at the Sportplatz three times of five. Homeoffice: presence, old.
reset role;
delete from app.event_template;
select pg_temp.ev('Grosi kommt!', -1, '19:00', 120, array['emma', 'papa'], null, 'Bei uns');
select pg_temp.act_as_dev('papa');
select is(api.event_suggestions(), '[]'::jsonb, 'nothing yet');
reset role;
select pg_temp.ev('grosi  kommt', -7, '18:30', 180, array['papa', 'emma'], 'house');
select pg_temp.act_as_dev('papa');
select is(jsonb_array_length(api.event_suggestions()), 0, 'twice is not regular');
reset role;
select pg_temp.ev('Grosi kommt', -14, '18:30', 180, array['papa', 'emma'], 'house');
select pg_temp.act_as_dev('papa');
create temp table s1 as select api.event_suggestions() r;
grant all on s1 to public;
select is(jsonb_array_length((select r from s1)), 1, 'three times is a suggestion');
select is((select array_agg(k order by k) from s1, jsonb_object_keys(r -> 0) k),
  array['attendee_ids', 'count', 'days', 'duration_minutes', 'icon_key', 'is_all_day', 'kind', 'last_on',
        'location', 'presence_state', 'signature', 'start_minute', 'title'],
  'a suggestion has exactly the keys of the contract');
select is((select r -> 0 ->> 'signature' || '|' || (r -> 0 ->> 'title') || '|' || (r -> 0 ->> 'icon_key') || '|'
                  || (r -> 0 ->> 'kind') || '|' || (r -> 0 ->> 'is_all_day') || '|' || (r -> 0 ->> 'start_minute') || '|'
                  || (r -> 0 ->> 'duration_minutes') || '|' || coalesce(r -> 0 ->> 'days', '-') || '|'
                  || coalesce(r -> 0 ->> 'presence_state', '-') || '|' || coalesce(r -> 0 ->> 'location', '-') || '|'
                  || (r -> 0 ->> 'count')
             from s1),
  'grosi kommt|Grosi kommt!|house|appointment|false|1110|180|-|-|-|3',
  'the latest title; the usual picture, start and length; a place on one of three is not kept');
select is((select r -> 0 -> 'attendee_ids' from s1),
  (select to_jsonb(array_agg(x order by x)) from unnest(array[pg_temp.id('papa'), pg_temp.id('emma')]) x),
  'the usual people, as a set');
select is((select (r -> 0 ->> 'last_on')::date from s1), (select d - 1 from today), 'and the day of the latest');

reset role;
select pg_temp.ev('Ausflug', -30, p_all_day => true, p_days => 3, p_people => array['papa', 'emma', 'paul'], p_icon => 'hiking');
select pg_temp.ev('Ausflug', -20, p_all_day => true, p_people => array['papa', 'emma', 'paul'], p_icon => 'hiking');
select pg_temp.ev('Ausflug', -10, p_all_day => true, p_people => array['papa', 'emma', 'paul'], p_icon => 'hiking');
select pg_temp.ev('Fussball', -204, '10:00', 90, array['emma'], 'football', 'Sportplatz');
select pg_temp.ev('Fussball', -197, '10:00', 90, array['emma'], 'football', 'Sportplatz');
select pg_temp.ev('Fussball', -190, '10:00', 90, array['emma'], 'football', 'Sportplatz');
select pg_temp.ev('Fussball', -183, '10:00', 90, array['emma'], 'football');
select pg_temp.ev('Fussball', -106, '11:00', 90, array['emma'], 'football');
select pg_temp.ev('Homeoffice', -300, '08:00', 540, array['papa'], 'laptop', p_kind => 'presence', p_presence => 'home_office');
select pg_temp.ev('Homeoffice', -290, '08:00', 540, array['papa'], p_kind => 'presence', p_presence => 'home_office');
select pg_temp.ev('Homeoffice', -280, '08:00', 540, array['papa'], p_kind => 'presence', p_presence => 'home_office');
select pg_temp.ev('Schwimmen', d, '16:00', 60, array['emma'], 'swimming') from unnest(array[-350, -340, -330]) d;
-- Never counted: a series, dates of a series, a tradition, deleted events, events too long ago or too
-- far ahead, another household's events.
select pg_temp.ev('Turnen', d, p_rrule => 'FREQ=WEEKLY') from unnest(array[-3, -5, -9]) d;
select pg_temp.ev('Elternabend', d, p_rdates => array[current_date]) from unnest(array[-3, -5, -9]) d;
select pg_temp.ev('Pizza', d, p_tradition => true) from unnest(array[-3, -5, -9]) d;
select pg_temp.ev('Zahnarzt', d, p_deleted => true) from unnest(array[-3, -5, -9]) d;
select pg_temp.ev('Kino', d) from unnest(array[-400, -390, -366]) d;
select pg_temp.ev('Zirkus', d) from unnest(array[61, 70, 80]) d;
select pg_temp.ev('Grill', d, p_hh => 'hh_b') from unnest(array[-3, -5, -9]) d;

select pg_temp.act_as_dev('papa');
create temp table s2 as select api.event_suggestions() r;
grant all on s2 to public;
select is((select pg_temp.sigs(r) from s2), 'grosi kommt,ausflug,fussball,homeoffice',
  'by weight, then the most recent; four is the default limit');
select is((select e ->> 'is_all_day' || '|' || coalesce(e ->> 'start_minute', '-') || '|' || coalesce(e ->> 'duration_minutes', '-')
                  || '|' || (e ->> 'days') || '|' || (e ->> 'icon_key')
             from s2, jsonb_array_elements(r) e where e ->> 'signature' = 'ausflug'),
  'true|-|-|1|hiking', 'an all-day suggestion: the usual number of days, no start time or length');
select is((select e ->> 'start_minute' || '|' || (e ->> 'location') || '|' || (e ->> 'count')
             from s2, jsonb_array_elements(r) e where e ->> 'signature' = 'fussball'),
  '600|Sportplatz|5', 'a place on three of five is kept');
select is(pg_temp.sigs(api.event_suggestions(p_limit => 12)), 'grosi kommt,ausflug,fussball,homeoffice,schwimmen',
  'all five groups; of two equal weights the more recent first');
select is((select e ->> 'kind' || '|' || (e ->> 'presence_state') || '|' || coalesce(e ->> 'icon_key', '-')
             from jsonb_array_elements(api.event_suggestions(p_limit => 12)) e where e ->> 'signature' = 'homeoffice'),
  'presence|home_office|-', 'with its state and without a picture');
select is(pg_temp.sigs(api.event_suggestions((select d - 1 + 7 from today))), 'fussball,grosi kommt,ausflug,schwimmen',
  'on its usual weekday a group weighs one and a half times');
select is(pg_temp.sigs(api.event_suggestions((select d + 7 from today))), 'grosi kommt,ausflug,fussball,homeoffice',
  'on another weekday it does not');
select is(jsonb_array_length(api.event_suggestions(p_limit => 1)), 1, 'p_limit is respected');
select is(jsonb_array_length(api.event_suggestions(p_limit => 0)), 1, 'and kept at one at least');
select is(jsonb_array_length(api.event_suggestions(p_limit => 100)), 5, 'a large p_limit gives all of them (twelve at most)');

-- Hidden, shown again, and covered by a saved template.
select is(pg_temp.error_hint($q$ select api.event_suggestion_hide(null, 'Grosi kommt') $q$), 'template_invalid',
  'only a signature is hidden');
select is(pg_temp.error_hint($q$ select api.event_suggestion_hide(null, '') $q$), 'template_invalid', 'not an empty one');
select is(pg_temp.error_hint(format('select api.event_suggestion_hide(null, %L)', repeat('a', 121))), 'template_invalid',
  'nor a long one');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($q$ select api.event_suggestion_hide(%L, 'grosi kommt') $q$, pg_temp.id('emma'))), null,
  'any member hides a suggestion');
select api.event_suggestion_hide(pg_temp.id('emma'), 'grosi kommt');
select is(pg_temp.sigs(api.event_suggestions()), 'ausflug,fussball,homeoffice,schwimmen', 'a hidden suggestion is not offered');
select is((select count(*)::int from app.audit_log where entity_type = 'event_suggestion' and action = 'hide'
            and diff ->> 'signature' = 'grosi kommt'), 2, 'hiding is audited');
select pg_temp.act_as_dev('b');
select is(pg_temp.sigs(api.event_suggestions()), 'grill',
  'another household sees only its own suggestions, and hides nothing of ours');
select is((select count(*)::int from app.event_suggestion_hidden), 0, 'nor reads our hidden ones');
select pg_temp.act_as_dev('papa');
select api.event_suggestion_hide(null, 'grosi kommt', false);
select is((select e ->> 'signature' from jsonb_array_elements(api.event_suggestions()) e limit 1), 'grosi kommt',
  'shown again, it is offered again');
select api.event_template_save(null, '{"title":"Grosi kommt?","kind":"presence","presence_state":"away"}');
select is((select e ->> 'signature' from jsonb_array_elements(api.event_suggestions()) e limit 1), 'grosi kommt',
  'a template of the other kind does not cover it');
select api.event_template_save(null, '{"title":" GROSI kommt!!"}');
select is(pg_temp.sigs(api.event_suggestions()), 'ausflug,fussball,homeoffice,schwimmen',
  'a saved template of the same kind and signature covers it');

select pg_temp.act_as_dev('old');
select is(api.event_suggestions(), '[]'::jsonb, 'a revoked device gets no suggestions');

select * from finish();
rollback;
