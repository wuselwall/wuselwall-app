begin;
select plan(98);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

-- Named things of the test: profiles, households, schools and rows (ids), devices (devs).
create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;
create temp table lj (j jsonb);
grant all on lj to public;

-- Switches to the device's Auth user, as PostgREST would with its JWT.
create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- ---- household A: Papa (guardian, personal phone), Lotta (child), Hanna (member) -------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into app.profile (household_id, display_name, role, kind)
  select (r ->> 'household_id')::uuid, 'Lotta', 'member', 'child' from sa;
insert into app.profile (household_id, display_name, role)
  select (r ->> 'household_id')::uuid, 'Hanna', 'member' from sa;
insert into ids select lower(p.display_name), p.id from app.profile p
 where p.household_id = (select id from ids where name = 'hh_a');

insert into users values
  ('ipad', app.create_auth_user('ipad@devices.invalid', 'x1234567890')),
  ('kiosk', app.create_auth_user('kiosk@devices.invalid', 'x1234567890')),
  ('old', app.create_auth_user('old@example.org', 'longpassword1'));

insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (select id from ids where name = 'hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = (select id from ids where name = 'papa');
insert into app.device (household_id, auth_user_id, label, class, register)
  select (select id from ids where name = 'hh_a'), usr, 'iPad', 'shared', 'kid' from users where name = 'ipad';
insert into app.device (household_id, auth_user_id, label, class, register)
  select (select id from ids where name = 'hh_a'), usr, 'Kiosk', 'kiosk', 'kiosk' from users where name = 'kiosk';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  select (select id from ids where name = 'hh_a'), usr, 'Old-Phone', 'personal', 'adult',
         (select id from ids where name = 'papa'), now()
    from users where name = 'old';

insert into devs
  select 'papa', d.auth_user_id, d.id, d.household_id, 'personal' from app.device d where d.label = 'A-Phone'
  union all
  select 'ipad', u.usr, d.id, d.household_id, 'shared' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'ipad'
  union all
  select 'kiosk', u.usr, d.id, d.household_id, 'kiosk' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'kiosk'
  union all
  select 'old', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'old';

-- ---- household B, made by hand, with its own school and subject ---------------------------------
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into users select 'b', app.create_auth_user('b@example.org', 'longpassword1');
insert into app.profile (household_id, display_name, role, auth_user_id)
  select (select id from ids where name = 'hh_b'), 'B', 'guardian', usr from users where name = 'b';
insert into ids select 'prof_b', p.id from app.profile p where p.display_name = 'B';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (select id from ids where name = 'hh_b'), u.usr, 'B-Phone', 'personal', 'adult', p.id
    from users u join app.profile p on p.auth_user_id = u.usr where u.name = 'b';
insert into devs
  select 'b', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id
   where u.name = 'b';
with s as (insert into app.school (household_id, name, timezone)
           values ((select id from ids where name = 'hh_b'), 'Fremde Schule', 'Europe/Berlin') returning id)
  insert into ids select 'school_b', id from s;
with s as (insert into app.subject (household_id, name, short_name, tint)
           values ((select id from ids where name = 'hh_b'), 'Physik', 'Ph', 'blue') returning id)
  insert into ids select 'subj_b', id from s;

-- ---- Papa, guardian on a personal phone: schools and bell times ---------------------------------
reset role;
select pg_temp.act_as_dev('papa');

select is((select count(*)::int from api.schools), 0, 'a new household has no school yet');
insert into ids select 'sch1', (api.school_save(null, '{"name":"Grundschule am Park","state_code":"DE-BE"}'::jsonb) ->> 'id')::uuid;
select is((select timezone from api.schools where id = (select id from ids where name = 'sch1')), 'Europe/Berlin',
  'a school takes the household time zone by default');
select is((select count(*)::int from api.school_periods where school_id = (select id from ids where name = 'sch1')
             and kind = 'lesson'), 6, 'the bell-time template has six lessons');
select is((select count(*)::int from api.school_periods where school_id = (select id from ids where name = 'sch1')
             and kind = 'break'), 5, 'the bell-time template has five breaks');
select is((select starts_at from api.school_periods where school_id = (select id from ids where name = 'sch1')
             and kind = 'lesson' and index = 1), '08:00'::time, 'the first lesson starts at 08:00');
select is((select ends_at from api.school_periods where school_id = (select id from ids where name = 'sch1')
             and kind = 'lesson' and index = 1), '08:45'::time, 'the first lesson ends at 08:45');
select is((select ends_at - starts_at from api.school_periods where school_id = (select id from ids where name = 'sch1')
             and kind = 'break' and index = 2), interval '20 minutes', 'the break after the second lesson is 20 minutes');
select is((select count(*)::int from api.subjects), 9, 'the first school brings the nine starter subjects');
select ok((select notable_default and equipment_note = 'Sportsachen' from api.subjects where short_name = 'Sp'),
  'Sport is notable by default and needs its kit');

select lives_ok($$ select api.school_save(null, jsonb_build_object('id', (select id from ids where name = 'sch1'),
  'name', 'Grundschule Park', 'state_code', 'DE-BE')) $$, 'a guardian renames the school');
select is((select name from api.schools where id = (select id from ids where name = 'sch1')), 'Grundschule Park',
  'the rename is saved');

insert into ids select 'sch2', (api.school_save(null, '{"name":"Gymnasium Nord","state_code":"DE-NI"}'::jsonb) ->> 'id')::uuid;
select is((select count(*)::int from api.subjects), 9, 'a second school does not duplicate the starter subjects');
select is((select count(*)::int from api.school_periods where school_id = (select id from ids where name = 'sch2')),
  11, 'a second school gets its own bell-time template');

select throws_ok($$ select api.school_save(null, '{"name":"   "}'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'a school needs a name');
select throws_ok($$ select api.school_save(null, '{"name":"X","state_code":"berlin"}'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'a state code must be ISO 3166-2');
select throws_ok($$ select api.school_save(null, '{"name":"X","timezone":"Mars/Olympus"}'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'an unknown time zone is refused');

-- Bell times are replaced as a whole.
select lives_ok($$ select api.school_periods_set(null, (select id from ids where name = 'sch2'),
  '[{"index":1,"kind":"lesson","starts_at":"08:00","ends_at":"08:45"},
    {"index":1,"kind":"break","starts_at":"08:45","ends_at":"08:50"},
    {"index":2,"kind":"lesson","starts_at":"08:50","ends_at":"09:35"}]'::jsonb) $$,
  'a guardian replaces the bell times of a school');
select is((select count(*)::int from api.school_periods where school_id = (select id from ids where name = 'sch2')),
  3, 'the replaced bell times are the only ones');
select throws_ok($$ select api.school_periods_set(null, (select id from ids where name = 'sch2'),
  '[{"index":1,"kind":"lesson","starts_at":"09:00","ends_at":"08:00"}]'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'a period must end after it starts');
select throws_ok($$ select api.school_periods_set(null, (select id from ids where name = 'sch2'),
  '[{"index":1,"kind":"recess","starts_at":"08:00","ends_at":"08:45"}]'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'a period is a lesson or a break');
select throws_ok($$ select api.school_periods_set(null, (select id from ids where name = 'sch2'),
  '[{"index":1,"kind":"lesson","starts_at":"08:00","ends_at":"08:45"},
    {"index":1,"kind":"lesson","starts_at":"08:50","ends_at":"09:35"}]'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'two lessons cannot share a number');

-- ---- terms: at most one current term per school -----------------------------------------------
insert into ids select 't1', (api.school_term_save(null, jsonb_build_object(
  'school_id', (select id from ids where name = 'sch1'), 'name', '1. Halbjahr',
  'starts_on', '2026-08-20', 'ends_on', '2027-02-05', 'is_current', true)) ->> 'id')::uuid;
select is((select is_current from api.school_terms where id = (select id from ids where name = 't1')), true,
  'a term can be marked as the current one');
insert into ids select 't2', (api.school_term_save(null, jsonb_build_object(
  'school_id', (select id from ids where name = 'sch1'), 'name', '2. Halbjahr',
  'starts_on', '2027-02-06', 'ends_on', '2027-07-30', 'ab_anchor_week', 6, 'is_current', true)) ->> 'id')::uuid;
select is((select count(*)::int from api.school_terms where school_id = (select id from ids where name = 'sch1')
             and is_current), 1, 'only one term per school is current');
select is((select id from api.school_terms where school_id = (select id from ids where name = 'sch1') and is_current),
  (select id from ids where name = 't2'), 'the term saved last as current wins');
select is((select ab_anchor_week from api.school_terms where id = (select id from ids where name = 't2')), 6,
  'the A/B anchor week is stored');
select throws_ok($$ select api.school_term_save(null, jsonb_build_object(
  'school_id', (select id from ids where name = 'sch1'), 'name', 'Verkehrt',
  'starts_on', '2027-01-01', 'ends_on', '2026-12-01')) $$,
  '22023', 'WW-SCH-001 school invalid', 'a term must end on or after its start');
insert into ids select 't_s2', (api.school_term_save(null, jsonb_build_object(
  'school_id', (select id from ids where name = 'sch2'), 'name', 'Halbjahr',
  'starts_on', '2026-08-20', 'ends_on', '2027-02-05')) ->> 'id')::uuid;

-- ---- subjects -----------------------------------------------------------------------------------
insert into ids select 'werken', (api.subject_save(null, '{"name":"Werken","short_name":"Wk","tint":"stone","icon_key":"hammer"}'::jsonb) ->> 'id')::uuid;
select is((select count(*)::int from api.subjects), 10, 'a guardian adds a subject');
select lives_ok($$ select api.subject_save(null, jsonb_build_object('id', (select id from ids where name = 'werken'),
  'name', 'Werken', 'short_name', 'Wk', 'tint', 'lemon')) $$, 'a guardian changes the colour of a subject');
select is((select tint from api.subjects where id = (select id from ids where name = 'werken')), 'lemon',
  'the colour change is saved');
select throws_ok($$ select api.subject_save(null, '{"name":"Lila","short_name":"Li","tint":"purple"}'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'a subject colour must be one of the palette');
select throws_ok($$ select api.subject_save(null, '{"name":"Deutsch","short_name":"Dt","tint":"rose"}'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'a subject name is unique in the household');
select lives_ok($$ select api.subject_delete(null, (select id from ids where name = 'werken')) $$,
  'a subject no lesson uses can be deleted');
select is((select count(*)::int from api.subjects), 9, 'the deleted subject is gone');

-- ---- timetables and grids -----------------------------------------------------------------------
insert into ids select 'subj_d', id from app.subject
 where household_id = (select id from ids where name = 'hh_a') and short_name = 'D';
insert into ids select 'subj_ma', id from app.subject
 where household_id = (select id from ids where name = 'hh_a') and short_name = 'Ma';
insert into ids select 'subj_sp', id from app.subject
 where household_id = (select id from ids where name = 'hh_a') and short_name = 'Sp';
insert into ids select 'subj_sw', id from app.subject
 where household_id = (select id from ids where name = 'hh_a') and short_name = 'Sw';

insert into ids select 'tt_lotta', (api.timetable_save(null, jsonb_build_object(
  'profile_id', (select id from ids where name = 'lotta'), 'school_id', (select id from ids where name = 'sch1'),
  'term_id', (select id from ids where name = 't1'), 'class_label', '2b', 'week_cycle', 'ab')) ->> 'id')::uuid;
select is((select week_cycle from api.timetables where id = (select id from ids where name = 'tt_lotta')), 'ab',
  'a timetable keeps its A/B cycle');
select is((select valid_from from api.timetables where id = (select id from ids where name = 'tt_lotta')),
  '2026-08-20'::date, 'a timetable is valid from the start of its term unless told otherwise');
select throws_ok($$ select api.timetable_save(null, jsonb_build_object(
  'profile_id', (select id from ids where name = 'lotta'), 'school_id', (select id from ids where name = 'sch1'),
  'term_id', (select id from ids where name = 't1'))) $$,
  '22023', 'WW-SCH-001 school invalid', 'a member has one timetable per term');
select throws_ok($$ select api.timetable_save(null, jsonb_build_object(
  'profile_id', (select id from ids where name = 'hanna'), 'school_id', (select id from ids where name = 'sch1'),
  'term_id', (select id from ids where name = 't_s2'))) $$,
  '22023', 'WW-SCH-001 school invalid', 'a term of another school is refused');
select throws_ok($$ select api.timetable_save(null, jsonb_build_object(
  'profile_id', (select id from ids where name = 'prof_b'), 'school_id', (select id from ids where name = 'sch1'),
  'term_id', (select id from ids where name = 't1'))) $$,
  '22023', 'WW-SCH-001 school invalid', 'a profile of another household is refused');

insert into lj select jsonb_build_array(
  jsonb_build_object('weekday', 1, 'period_index', 1, 'subject_id', (select id from ids where name = 'subj_d'),
                     'teacher', 'Frau Kern', 'room', '1a'),
  jsonb_build_object('weekday', 1, 'period_index', 2, 'subject_id', (select id from ids where name = 'subj_ma')),
  jsonb_build_object('weekday', 2, 'period_index', 4, 'subject_id', (select id from ids where name = 'subj_sp')),
  jsonb_build_object('weekday', 3, 'period_index', 2, 'subject_id', (select id from ids where name = 'subj_sw'),
                     'week_parity', 'a'),
  jsonb_build_object('weekday', 1, 'kind', 'care', 'title', 'Hort', 'starts_at', '13:00', 'ends_at', '15:30'));

select lives_ok($$ select api.timetable_lessons_set(null, (select id from ids where name = 'tt_lotta'),
  (select j from lj)) $$, 'a guardian saves the whole grid at once');
select is((select count(*)::int from api.timetable_lessons where timetable_id = (select id from ids where name = 'tt_lotta')),
  5, 'the grid holds the five cells that were saved');
select is((select is_notable from api.timetable_lessons where timetable_id = (select id from ids where name = 'tt_lotta')
             and weekday = 2 and period_index = 4), true, 'Sport is notable when the entry does not say');
select is((select is_notable from api.timetable_lessons where timetable_id = (select id from ids where name = 'tt_lotta')
             and weekday = 1 and period_index = 1), false, 'a subject that is not notable stays off the wall');
select is((select week_parity from api.timetable_lessons where timetable_id = (select id from ids where name = 'tt_lotta')
             and weekday = 3), 'a', 'a lesson can sit on the A week only');
select ok((select kind = 'care' and period_index is null and starts_at = '13:00'::time and subject_id is null
             from api.timetable_lessons where timetable_id = (select id from ids where name = 'tt_lotta') and kind = 'care'),
  'a care row has its own times and no period');

-- Saving the grid moves the timetable's updated_at forward (it drives the ICS SEQUENCE).
reset role;
update app.timetable set updated_at = '2000-01-01' where id = (select id from ids where name = 'tt_lotta');
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.timetable_lessons_set(null, (select id from ids where name = 'tt_lotta'),
  (select j from lj)) $$, 'the same grid can be saved again');
select ok((select updated_at > '2000-01-01'::timestamptz from api.timetables where id = (select id from ids where name = 'tt_lotta')),
  'saving the grid moves the timetable updated_at forward');

select throws_ok($$ select api.timetable_lessons_set(null, (select id from ids where name = 'tt_lotta'),
  jsonb_build_array(jsonb_build_object('weekday', 4, 'period_index', 1,
    'subject_id', (select id from ids where name = 'subj_b')))) $$,
  '22023', 'WW-SCH-001 school invalid', 'a subject of another household is refused in a lesson');
select throws_ok($$ select api.timetable_lessons_set(null, (select id from ids where name = 'tt_lotta'),
  '[{"weekday":4,"period_index":1}]'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'a lesson needs a subject or a title');
select throws_ok($$ select api.timetable_lessons_set(null, (select id from ids where name = 'tt_lotta'),
  '[{"weekday":8,"period_index":1,"title":"Test"}]'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'a weekday is 1 to 7');

-- Copy to the sibling: metadata and grid, not exceptions.
insert into ids select 'tt_hanna', (api.timetable_copy(null, (select id from ids where name = 'tt_lotta'),
  (select id from ids where name = 'hanna'), (select id from ids where name = 't1')) ->> 'id')::uuid;
select is((select count(*)::int from api.timetable_lessons where timetable_id = (select id from ids where name = 'tt_hanna')),
  5, 'a copy to the sibling takes all five cells');
select is((select profile_id from api.timetables where id = (select id from ids where name = 'tt_hanna')),
  (select id from ids where name = 'hanna'), 'the copy belongs to the sibling');
select throws_ok($$ select api.timetable_copy(null, (select id from ids where name = 'tt_lotta'),
  (select id from ids where name = 'hanna'), (select id from ids where name = 't1')) $$,
  '22023', 'WW-SCH-001 school invalid', 'a child cannot have two timetables in one term');

-- ---- exceptions ---------------------------------------------------------------------------------
insert into ids select 'ex_cancel', (api.timetable_exception_save(null, jsonb_build_object(
  'timetable_id', (select id from ids where name = 'tt_lotta'), 'on_date', '2026-10-19',
  'period_index', 2, 'kind', 'cancelled')) ->> 'id')::uuid;
select is((select kind from api.timetable_exceptions where id = (select id from ids where name = 'ex_cancel')), 'cancelled',
  'a lesson can be cancelled on one date');
insert into ids select 'ex_sub', (api.timetable_exception_save(null, jsonb_build_object(
  'timetable_id', (select id from ids where name = 'tt_lotta'), 'on_date', '2026-10-20',
  'period_index', 4, 'kind', 'substituted', 'teacher', 'Herr Lang')) ->> 'id')::uuid;
select is((select teacher from api.timetable_exceptions where id = (select id from ids where name = 'ex_sub')), 'Herr Lang',
  'a substitution names the teacher');
insert into ids select 'ex_extra', (api.timetable_exception_save(null, jsonb_build_object(
  'timetable_id', (select id from ids where name = 'tt_lotta'), 'on_date', '2026-10-17',
  'starts_at', '10:00', 'ends_at', '11:00', 'kind', 'extra',
  'subject_id', (select id from ids where name = 'subj_ma'))) ->> 'id')::uuid;
select is((select count(*)::int from api.timetable_exceptions where timetable_id = (select id from ids where name = 'tt_lotta')
             and on_date = '2026-10-17' and kind = 'extra'), 1, 'an extra lesson can land on a Saturday');
select throws_ok($$ select api.timetable_exception_save(null, jsonb_build_object(
  'timetable_id', (select id from ids where name = 'tt_lotta'), 'on_date', '2026-10-21', 'kind', 'cancelled')) $$,
  '22023', 'WW-SCH-001 school invalid', 'a cancelled lesson names its period');
select throws_ok($$ select api.timetable_exception_save(null, jsonb_build_object(
  'timetable_id', (select id from ids where name = 'tt_lotta'), 'on_date', '2026-10-21',
  'kind', 'extra', 'period_index', 2)) $$,
  '22023', 'WW-SCH-001 school invalid', 'an extra lesson needs a subject and a time or period');

reset role;
update app.timetable set updated_at = '2000-01-01' where id = (select id from ids where name = 'tt_lotta');
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.timetable_exception_save(null, jsonb_build_object(
  'id', (select id from ids where name = 'ex_sub'), 'timetable_id', (select id from ids where name = 'tt_lotta'),
  'on_date', '2026-10-20', 'period_index', 4, 'kind', 'substituted', 'teacher', 'Frau Lang')) $$,
  'a guardian corrects a substitution');
select is((select teacher from api.timetable_exceptions where id = (select id from ids where name = 'ex_sub')), 'Frau Lang',
  'the corrected teacher is saved');
select ok((select updated_at > '2000-01-01'::timestamptz from api.timetables where id = (select id from ids where name = 'tt_lotta')),
  'an exception moves the timetable updated_at forward');
select lives_ok($$ select api.timetable_exception_delete(null, (select id from ids where name = 'ex_cancel')) $$,
  'a guardian removes an exception');
select is((select count(*)::int from api.timetable_exceptions where id = (select id from ids where name = 'ex_cancel')),
  0, 'the removed exception is gone');

-- ---- holidays -----------------------------------------------------------------------------------
insert into ids select 'hol_herbst', (api.school_holiday_save(null, jsonb_build_object(
  'name', 'Herbstferien', 'starts_on', '2026-10-05', 'ends_on', '2026-10-16', 'kind', 'holiday')) ->> 'id')::uuid;
select is((select school_id from api.school_holidays where id = (select id from ids where name = 'hol_herbst')),
  null::uuid, 'a holiday without a school applies to every school');
insert into ids select 'hol_close', (api.school_holiday_save(null, jsonb_build_object(
  'school_id', (select id from ids where name = 'sch1'), 'name', 'Beweglicher Ferientag',
  'starts_on', '2026-11-06', 'ends_on', '2026-11-06', 'kind', 'closure_day')) ->> 'id')::uuid;
select is((select kind from api.school_holidays where id = (select id from ids where name = 'hol_close')), 'closure_day',
  'a closure day belongs to its school');
select throws_ok($$ select api.school_holiday_save(null, '{"name":"Verkehrt","starts_on":"2026-12-02",
  "ends_on":"2026-12-01","kind":"holiday"}'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'a holiday ends on or after its start');
select throws_ok($$ select api.school_holiday_save(null, jsonb_build_object('school_id', (select id from ids where name = 'school_b'),
  'name', 'Fremd', 'starts_on', '2026-12-01', 'ends_on', '2026-12-01', 'kind', 'holiday')) $$,
  '22023', 'WW-SCH-001 school invalid', 'a holiday cannot name a school of another household');
select lives_ok($$ select api.school_holiday_delete(null, (select id from ids where name = 'hol_close')) $$,
  'a guardian removes a closure day');
select is((select count(*)::int from api.school_holidays where id = (select id from ids where name = 'hol_close')),
  0, 'the removed closure day is gone');

-- ---- a child on the shared iPad: reads and reports, does not maintain ---------------------------
reset role;
select pg_temp.act_as_dev('ipad');
select throws_ok($$ select api.school_save((select id from ids where name = 'lotta'), '{"name":"Nein"}'::jsonb) $$,
  '42501', 'guardian required', 'a child cannot change the school');
select throws_ok($$ select api.timetable_lessons_set((select id from ids where name = 'lotta'),
  (select id from ids where name = 'tt_lotta'), '[]'::jsonb) $$,
  '42501', 'guardian required', 'a child cannot replace the grid');
select throws_ok($$ select api.school_holiday_save((select id from ids where name = 'lotta'),
  '{"name":"Ferien","starts_on":"2026-12-01","ends_on":"2026-12-02","kind":"holiday"}'::jsonb) $$,
  '42501', 'guardian required', 'a child cannot add a holiday');
select throws_ok($$ select api.timetable_exception_save((select id from ids where name = 'lotta'), jsonb_build_object(
  'timetable_id', (select id from ids where name = 'tt_lotta'), 'on_date', '2026-10-22', 'period_index', 3,
  'kind', 'cancelled')) $$,
  '42501', 'guardian required', 'with the setting off a child cannot report a change');

-- The household opens exception reporting to members (inserted as the owner).
reset role;
insert into app.household_setting (household_id, key, value)
  values ((select id from ids where name = 'hh_a'), 'school.members_report_changes', 'true'::jsonb);
select pg_temp.act_as_dev('ipad');
insert into ids select 'ex_kid', (api.timetable_exception_save((select id from ids where name = 'lotta'), jsonb_build_object(
  'timetable_id', (select id from ids where name = 'tt_lotta'), 'on_date', '2026-10-22', 'period_index', 3,
  'kind', 'cancelled')) ->> 'id')::uuid;
select is((select count(*)::int from api.timetable_exceptions where id = (select id from ids where name = 'ex_kid')), 1,
  'a child reports a change once the household allows it');
select lives_ok($$ select api.timetable_exception_delete((select id from ids where name = 'lotta'),
  (select id from ids where name = 'ex_kid')) $$, 'a child removes the change she reported');
select throws_ok($$ select api.school_save((select id from ids where name = 'lotta'), '{"name":"Nein"}'::jsonb) $$,
  '42501', 'guardian required', 'the setting opens exceptions only, not the school');

-- ---- a kiosk never writes -----------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('kiosk');
select throws_ok($$ select api.school_save((select id from ids where name = 'papa'), '{"name":"Kiosk"}'::jsonb) $$,
  '42501', 'not allowed on a kiosk', 'a kiosk device cannot save a school');
select throws_ok($$ select api.timetable_exception_save((select id from ids where name = 'papa'), jsonb_build_object(
  'timetable_id', (select id from ids where name = 'tt_lotta'), 'on_date', '2026-10-23', 'period_index', 1,
  'kind', 'cancelled')) $$,
  '42501', 'not allowed on a kiosk', 'a kiosk device cannot report an exception, even with the setting on');

-- ---- household B sees and touches nothing of A ----------------------------------------------------
reset role;
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.schools where id in (select id from ids where name in ('sch1', 'sch2'))),
  0, 'another household sees none of the schools');
select is((select count(*)::int from api.school_periods where school_id in (select id from ids where name in ('sch1', 'sch2'))),
  0, 'another household sees none of the bell times');
select is((select count(*)::int from api.school_terms where id in (select id from ids where name in ('t1', 't2', 't_s2'))),
  0, 'another household sees none of the terms');
select is((select count(*)::int from api.subjects where name in ('Deutsch', 'Mathematik')),
  0, 'another household sees none of the subjects');
select is((select count(*)::int from api.timetables where id in (select id from ids where name in ('tt_lotta', 'tt_hanna'))),
  0, 'another household sees none of the timetables');
select is((select count(*)::int from api.timetable_lessons where timetable_id in (select id from ids where name in ('tt_lotta', 'tt_hanna'))),
  0, 'another household sees none of the lessons');
select is((select count(*)::int from api.timetable_exceptions where timetable_id = (select id from ids where name = 'tt_lotta')),
  0, 'another household sees none of the exceptions');
select is((select count(*)::int from api.school_holidays where id = (select id from ids where name = 'hol_herbst')),
  0, 'another household sees none of the holidays');
select throws_ok($$ select api.school_save(null, jsonb_build_object('id', (select id from ids where name = 'sch1'),
  'name', 'Fremd')) $$, 'P0002', 'school not found', 'another household cannot rename a school by its id');
select throws_ok($$ select api.timetable_lessons_set(null, (select id from ids where name = 'tt_lotta'), '[]'::jsonb) $$,
  'P0002', 'timetable not found', 'another household cannot replace a grid');
select throws_ok($$ select api.subject_delete(null, (select id from ids where name = 'subj_d')) $$,
  'P0002', 'subject not found', 'another household cannot delete a subject');
select throws_ok($$ select api.timetable_save(null, jsonb_build_object('profile_id', (select id from ids where name = 'lotta'),
  'school_id', (select id from ids where name = 'school_b'), 'term_id', (select id from ids where name = 't1'))) $$,
  '22023', 'WW-SCH-001 school invalid', 'another household cannot put a child on its own term');
select throws_ok($$ select api.timetable_exception_save(null, jsonb_build_object(
  'timetable_id', (select id from ids where name = 'tt_lotta'), 'on_date', '2026-10-24', 'period_index', 1,
  'kind', 'cancelled')) $$,
  '22023', 'WW-SCH-001 school invalid', 'another household cannot add an exception to a timetable of another');
select throws_ok($$ select api.school_holiday_save(null, jsonb_build_object('school_id', (select id from ids where name = 'sch1'),
  'name', 'Fremd', 'starts_on', '2026-12-01', 'ends_on', '2026-12-01', 'kind', 'holiday')) $$,
  '22023', 'WW-SCH-001 school invalid', 'another household cannot add a holiday to a school of another');
select throws_ok($$ select api.school_term_save(null, jsonb_build_object('school_id', (select id from ids where name = 'sch1'),
  'name', 'Fremd', 'starts_on', '2026-08-20', 'ends_on', '2027-02-05')) $$,
  '22023', 'WW-SCH-001 school invalid', 'another household cannot add a term to a school of another');

-- ---- a revoked phone ------------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('old');
select is((select count(*)::int from api.schools), 0, 'a revoked phone reads no school');
select throws_ok($$ select api.school_save(null, '{"name":"Alt"}'::jsonb) $$,
  '42501', 'device not usable', 'a revoked phone cannot save a school');

-- ---- anonymous callers ----------------------------------------------------------------------------
reset role;
set local role anon;
select throws_ok('select count(*) from api.schools', '42501', 'permission denied for view schools',
  'anonymous callers cannot read schools');
select throws_ok($$ select api.school_save(null, '{}'::jsonb) $$, '42501', 'permission denied for function school_save',
  'anonymous callers cannot save a school');
reset role;

-- ---- back to the guardian: a subject in use cannot go ---------------------------------------------
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.subject_delete(null, (select id from ids where name = 'subj_sp')) $$,
  '23503', 'WW-SCH-002 subject in use', 'a subject that a lesson uses cannot be deleted');
reset role;

-- ---- the owner's view: audit ----------------------------------------------------------------------
select ok(exists (select 1 from app.audit_log where entity_type = 'school' and action = 'create'
                  and household_id = (select id from ids where name = 'hh_a')),
  'school writes are audited');

select * from finish();
rollback;
