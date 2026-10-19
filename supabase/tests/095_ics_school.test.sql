begin;
select plan(23);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

-- Named things of the test: households, profiles, schools and rows (ids), tokens and feeds.
create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table tok (name text primary key, token text);
grant all on tok to public;
create temp table snap (k text primary key, v jsonb);
grant all on snap to public;

-- Switches to Papa's personal phone, as PostgREST would with its JWT.
create function pg_temp.act_as_papa() returns void language plpgsql as $$
declare d app.device;
begin
  select * into d from app.device where label = 'A-Phone';
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.auth_user_id, 'role', 'authenticated',
    'household_id', d.household_id, 'device_id', d.id, 'device_class', 'personal')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- ---- household A: Papa (guardian), Emma (child), Paul (member) ------------------------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;
insert into app.profile (household_id, display_name, role, kind)
  select (select id from ids where name = 'hh_a'), 'Emma', 'member', 'child';
insert into app.profile (household_id, display_name, role, kind)
  select (select id from ids where name = 'hh_a'), 'Paul', 'member', 'adult';
insert into ids select lower(p.display_name), p.id from app.profile p
 where p.household_id = (select id from ids where name = 'hh_a') and p.role = 'member';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (select id from ids where name = 'hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = (select id from ids where name = 'papa');

with s as (insert into app.school (household_id, name, timezone)
           values ((select id from ids where name = 'hh_a'), 'Grundschule A', 'Europe/Berlin') returning id)
  insert into ids select 'school_a', id from s;
insert into app.school_period (household_id, school_id, index, starts_at, ends_at, kind)
  select (select id from ids where name = 'hh_a'), (select id from ids where name = 'school_a'), i, s, e, 'lesson'
    from (values (1, '08:00'::time, '08:45'::time), (2, '08:50', '09:35')) v(i, s, e);
with s as (insert into app.subject (household_id, name, short_name, tint)
           values ((select id from ids where name = 'hh_a'), 'Mathe', 'Ma', 'blue') returning id)
  insert into ids select 'subj_a', id from s;

-- Current term, an old term (outside the window), and the timetables of Emma and Paul.
with s as (insert into app.school_term (household_id, school_id, name, starts_on, ends_on)
           values ((select id from ids where name = 'hh_a'), (select id from ids where name = 'school_a'),
                   'Herbst', current_date - 60, current_date + 200) returning id)
  insert into ids select 'term_a', id from s;
with s as (insert into app.school_term (household_id, school_id, name, starts_on, ends_on)
           values ((select id from ids where name = 'hh_a'), (select id from ids where name = 'school_a'),
                   'Frueher', '2025-01-01', '2025-06-30') returning id)
  insert into ids select 'term_old', id from s;
with s as (insert into app.timetable (household_id, profile_id, school_id, term_id, valid_from)
           values ((select id from ids where name = 'hh_a'), (select id from ids where name = 'emma'),
                   (select id from ids where name = 'school_a'), (select id from ids where name = 'term_a'),
                   current_date - 60) returning id)
  insert into ids select 'tt_emma', id from s;
with s as (insert into app.timetable (household_id, profile_id, school_id, term_id, valid_from)
           values ((select id from ids where name = 'hh_a'), (select id from ids where name = 'emma'),
                   (select id from ids where name = 'school_a'), (select id from ids where name = 'term_old'),
                   '2025-01-01') returning id)
  insert into ids select 'tt_old', id from s;
with s as (insert into app.timetable (household_id, profile_id, school_id, term_id, valid_from)
           values ((select id from ids where name = 'hh_a'), (select id from ids where name = 'paul'),
                   (select id from ids where name = 'school_a'), (select id from ids where name = 'term_a'),
                   current_date - 60) returning id)
  insert into ids select 'tt_paul', id from s;

insert into app.timetable_lesson (household_id, timetable_id, weekday, period_index, subject_id, room)
  select (select id from ids where name = 'hh_a'), (select id from ids where name = 'tt_emma'), w, p,
         (select id from ids where name = 'subj_a'), 'R1'
    from (values (1, 1), (1, 2), (2, 1)) v(w, p);
insert into app.timetable_lesson (household_id, timetable_id, weekday, period_index, title)
  select (select id from ids where name = 'hh_a'), (select id from ids where name = 'tt_paul'), 1, 1, 'Paul-Stunde';
insert into app.timetable_lesson (household_id, timetable_id, weekday, period_index, subject_id)
  select (select id from ids where name = 'hh_a'), (select id from ids where name = 'tt_old'), 1, 1,
         (select id from ids where name = 'subj_a');

-- One cancellation inside the window, one long before it.
insert into app.timetable_exception (household_id, timetable_id, on_date, period_index, kind)
  select (select id from ids where name = 'hh_a'), (select id from ids where name = 'tt_emma'),
         current_date + 3, 1, 'cancelled'
  union all
  select (select id from ids where name = 'hh_a'), (select id from ids where name = 'tt_emma'),
         current_date - 45, 1, 'cancelled';

insert into app.school_holiday (household_id, school_id, name, starts_on, ends_on, kind)
  values ((select id from ids where name = 'hh_a'), (select id from ids where name = 'school_a'),
          'Herbstferien', current_date + 1, current_date + 5, 'holiday');

-- ---- household B, made by hand, with a school, a term, a timetable and a holiday of its own --
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into app.profile (household_id, display_name, role, kind)
  select (select id from ids where name = 'hh_b'), 'Mia', 'member', 'child';
insert into ids select 'mia', id from app.profile where display_name = 'Mia';
with s as (insert into app.school (household_id, name, timezone)
           values ((select id from ids where name = 'hh_b'), 'Fremde Schule', 'Europe/Berlin') returning id)
  insert into ids select 'school_b', id from s;
with s as (insert into app.school_term (household_id, school_id, name, starts_on, ends_on)
           values ((select id from ids where name = 'hh_b'), (select id from ids where name = 'school_b'),
                   'Fremd', current_date - 60, current_date + 200) returning id)
  insert into ids select 'term_b', id from s;
with s as (insert into app.timetable (household_id, profile_id, school_id, term_id, valid_from)
           values ((select id from ids where name = 'hh_b'), (select id from ids where name = 'mia'),
                   (select id from ids where name = 'school_b'), (select id from ids where name = 'term_b'),
                   current_date - 60) returning id)
  insert into ids select 'tt_b', id from s;
insert into app.timetable_lesson (household_id, timetable_id, weekday, period_index, title)
  select (select id from ids where name = 'hh_b'), (select id from ids where name = 'tt_b'), 1, 1, 'Fremd';
insert into app.school_holiday (household_id, school_id, name, starts_on, ends_on, kind)
  values ((select id from ids where name = 'hh_b'), (select id from ids where name = 'school_b'),
          'Fremde Ferien', current_date + 1, current_date + 5, 'holiday');

-- ---- tokens, as Papa --------------------------------------------------------------------------
select pg_temp.act_as_papa();
insert into tok select 'off', r ->> 'token' from (select api.feed_token_create(null, 'Oma', '{}'::jsonb) r) s;
insert into tok select 'day', r ->> 'token' from (select api.feed_token_create(null, 'Schule',
  '{"school":"day"}'::jsonb) r) s;
insert into tok select 'lessons', r ->> 'token' from (select api.feed_token_create(null, 'Stunden',
  '{"school":"lessons"}'::jsonb) r) s;
insert into tok select 'paul', r ->> 'token' from (select api.feed_token_create(null, 'Paul',
  jsonb_build_object('profile_ids', jsonb_build_array((select id from ids where name = 'paul')),
                     'school', 'day')) r) s;
reset role;

insert into snap select k, api.ics_feed((select token from tok where name = k))
  from (values ('off'), ('day'), ('lessons'), ('paul')) v(k);

-- ---- what the feed holds --------------------------------------------------------------------
select ok(not ((select v from snap where k = 'off') ? 'school'), 'the default filter has no school key');
select ok(not ((select v from snap where k = 'off') ? 'members'), 'the default filter has no members key');
select ok((select v from snap where k = 'off') ? 'events', 'the feed keeps its events key without school');
select ok((select v from snap where k = 'day') ? 'school', 'school "day" adds the school key');
select is(jsonb_array_length((select v from snap where k = 'day') -> 'school' -> 'timetables'), 1,
  'only Emma has a timetable in the window (Paul is not a child, the old term is outside it)');
select is((select v from snap where k = 'day') -> 'school' -> 'timetables' -> 0 ->> 'id',
  (select id::text from ids where name = 'tt_emma'), 'the timetable is Emma''s current one');
select is(jsonb_array_length((select v from snap where k = 'day') -> 'school' -> 'schools'), 1,
  'the schools are the household''s own');
select is((select v from snap where k = 'day') -> 'school' -> 'schools' -> 0 ->> 'name', 'Grundschule A',
  'the school row carries its api columns');
select is(jsonb_array_length((select v from snap where k = 'day') -> 'school' -> 'periods'), 2,
  'the household''s bell times come along');
select is(jsonb_array_length((select v from snap where k = 'day') -> 'school' -> 'terms'), 1,
  'only the term that overlaps the window');
select is(jsonb_array_length((select v from snap where k = 'day') -> 'school' -> 'subjects'), 1,
  'the household''s subjects come along');
select is(jsonb_array_length((select v from snap where k = 'day') -> 'school' -> 'lessons'), 3,
  'the lessons of the timetable, and none of the old one');
select is(jsonb_array_length((select v from snap where k = 'day') -> 'school' -> 'exceptions'), 1,
  'only the exception inside the window');
select is(jsonb_array_length((select v from snap where k = 'day') -> 'school' -> 'holidays'), 1,
  'only the household''s holiday, not the other household''s');
select is((select v from snap where k = 'day') -> 'members',
  jsonb_build_object((select id::text from ids where name = 'emma'), 'Emma'),
  'members name the child with a timetable');
select ok(not exists (select 1 from snap s, jsonb_array_elements(s.v -> 'school' -> 'timetables') t
                       where s.k = 'day' and t ->> 'id' = (select id::text from ids where name = 'tt_b')),
  'a foreign household''s timetable never appears');
select ok(not exists (select 1 from snap s, jsonb_array_elements(s.v -> 'school' -> 'schools') x
                       where s.k = 'day' and x ->> 'id' = (select id::text from ids where name = 'school_b')),
  'a foreign household''s school never appears');
select ok(not exists (select 1 from snap s, jsonb_array_elements(s.v -> 'school' -> 'holidays') x
                       where s.k = 'day' and x ->> 'name' = 'Fremde Ferien'),
  'a foreign household''s holiday never appears');
select ok(exists (select 1 from snap s, jsonb_array_elements(s.v -> 'school' -> 'periods') p
                    where s.k = 'day' and p ->> 'starts_at' = '08:00:00' and p ->> 'index' = '1'),
  'times arrive as the api gives them');
select ok((select v from snap where k = 'lessons') ? 'school', 'school "lessons" adds the school key');
select is(jsonb_array_length((select v from snap where k = 'lessons') -> 'school' -> 'timetables'), 1,
  'lessons mode selects the same rows');
select is((select v from snap where k = 'paul') -> 'members',
  jsonb_build_object((select id::text from ids where name = 'paul'), 'Paul'),
  'a profile filter names its member and no other');
select is((select v from snap where k = 'paul') -> 'school' -> 'timetables' -> 0 ->> 'profile_id',
  (select id::text from ids where name = 'paul'), 'a profile filter limits the timetables to that profile');

select * from finish();
rollback;
