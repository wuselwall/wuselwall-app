begin;
select plan(112);

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

-- Switches to the device's Auth user, as PostgREST would with its JWT.
create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- ---- household A: Papa (guardian, personal phone), Emma (child), iPad, kiosk, revoked phone -----
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into app.profile (household_id, display_name, role, kind)
  select (r ->> 'household_id')::uuid, 'Emma', 'member', 'child' from sa;
insert into ids select lower(p.display_name), p.id from app.profile p
 where p.household_id = (select id from ids where name = 'hh_a');

insert into users values
  ('ipad', app.create_auth_user('ipad@devices.invalid', 'x1234567890')),
  ('kiosk', app.create_auth_user('kiosk@devices.invalid', 'x1234567890')),
  ('old', app.create_auth_user('old@example.org', 'longpassword1')),
  ('b', app.create_auth_user('b@example.org', 'longpassword1'));

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

-- ---- household B: a guardian with a phone and a school of its own ---------------------------------
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into app.profile (household_id, display_name, role, auth_user_id)
  select (select id from ids where name = 'hh_b'), 'B', 'guardian', usr from users where name = 'b';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (select id from ids where name = 'hh_b'), u.usr, 'B-Phone', 'personal', 'adult', p.id
    from users u join app.profile p on p.auth_user_id = u.usr where u.name = 'b';
insert into devs
  select 'b', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id
   where u.name = 'b';
with s as (insert into app.school (household_id, name, timezone)
           values ((select id from ids where name = 'hh_b'), 'Fremde Schule', 'Europe/Berlin') returning id)
  insert into ids select 'school_b', id from s;

-- ---- the public reference data, as the sync would write it (the owner here) ---------------------
insert into app.region (code, country, parent_code, level, category, short_name, names) values
  ('CH-ZH', 'CH', null, 1, 'Kanton', 'ZH', '{"de":"Zürich","fr":"Zurich"}'),
  ('CH-ZH-ZH', 'CH', 'CH-ZH', 2, 'Bezirk', 'Zürich', '{"de":"Bezirk Zürich"}'),
  ('CH-ZH-ZH-ZH', 'CH', 'CH-ZH-ZH', 3, 'Gemeinde', 'Zürich', '{"de":"Zürich"}'),
  ('CH-AG', 'CH', null, 1, 'Kanton', 'AG', '{"de":"Aargau","fr":"Argovie"}'),
  ('DE-BY', 'DE', null, 1, 'Bundesland', 'BY', '{"de":"Bayern"}');

insert into app.holiday_feed (id, country, kind, starts_on, ends_on, names, nationwide, subdivisions) values
  ('feed-ch-nat', 'CH', 'public', '2026-08-01', '2026-08-01', '{"de":"Bundesfeier","fr":"Fête nationale"}', true, '{}'),
  ('feed-zh-ferien', 'CH', 'school', '2026-10-19', '2026-10-23', '{"de":"Herbstferien"}', false, '{"CH-ZH"}'),
  ('feed-ag-ferien', 'CH', 'school', '2026-10-19', '2026-10-23', '{"de":"Herbstferien AG"}', false, '{"CH-AG"}'),
  ('feed-ag-pub', 'CH', 'public', '2026-09-01', '2026-09-01', '{"de":"Kantonaler Feiertag AG"}', false, '{"CH-AG"}'),
  ('feed-de-pub', 'DE', 'public', '2026-10-03', '2026-10-03', '{"de":"Tag der Deutschen Einheit"}', true, '{}');

-- ---- region_covers: the rules of the subdivision codes -------------------------------------------
select ok(app.region_covers('DE-BY', 'DE', true, '{}'), 'a nationwide holiday covers every region of its country');
select ok(not app.region_covers('AT-9', 'CH', true, '{}'), 'a nationwide holiday does not cover another country');
select ok(app.region_covers('CH-ZH-ZH-ZH', 'CH', false, '{"CH-ZH"}'), 'a canton covers the municipalities in it');
select ok(not app.region_covers('CH-ZH', 'CH', false, '{"CH-ZH-ZH-ZH"}'), 'a municipality does not cover its canton');
select ok(app.region_covers('CH-AG', 'CH', false, '{"CH-AG"}'), 'a region covers itself');
select ok(not app.region_covers('CH-AGX', 'CH', false, '{"CH-AG"}'), 'the boundary is a dash: CH-AG does not cover CH-AGX');
select ok(not app.region_covers('CH-ZH', 'CH', false, '{}'), 'no subdivisions and not nationwide covers nothing');

-- ---- the reference data: read by members, written by nobody but the sync -------------------------
select throws_ok($$ insert into app.region (code, country, level, category, short_name, names)
  values ('CH', 'CH', 1, 'Land', 'CH', '{}') $$, '23514', null, 'a region code needs at least one level below the country');
select throws_ok($$ insert into app.region (code, country, level, category, short_name, names)
  values ('CH-ZH', 'CH', 2, 'Kanton', 'ZH', '{}') $$, '23514', null, 'a region level matches its code');
select throws_ok($$ insert into app.holiday_feed (id, country, kind, starts_on, ends_on, names, nationwide)
  values ('feed-bad', 'CH', 'school', '2026-10-02', '2026-10-01', '{}', true) $$, '23514', null,
  'a holiday ends on or after its start');

-- ---- anonymous callers ---------------------------------------------------------------------------
reset role;
set local role anon;
select throws_ok('select count(*) from api.regions', '42501', 'permission denied for view regions',
  'anonymous callers cannot read the regions');
select throws_ok('select count(*) from app.region', '42501', null,
  'anonymous callers cannot read the region table');
select throws_ok('select count(*) from api.holiday_feed_status', '42501', 'permission denied for view holiday_feed_status',
  'anonymous callers cannot read the feed status');
select throws_ok($$ select api.holiday_import_preview(null, null, 'CH-ZH', '2026-10-01', '2026-10-31') $$, '42501',
  'permission denied for function holiday_import_preview', 'anonymous callers cannot preview an import');
select throws_ok($$ select app.region_covers('CH-ZH', 'CH', true, '{}') $$, '42501', null,
  'anonymous callers cannot call the internal helper');
reset role;

-- ---- Papa, guardian on a personal phone -----------------------------------------------------------
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from api.regions where country = 'CH'), 4, 'a member reads the Swiss regions');
select is((select names ->> 'fr' from api.regions where code = 'CH-ZH'), 'Zurich', 'the names come as a language map');
select throws_ok($$ insert into app.region (code, country, level, category, short_name, names)
  values ('CH-BE', 'CH', 1, 'Kanton', 'BE', '{}') $$, '42501', 'permission denied for table region',
  'a member cannot write a region');
select throws_ok($$ insert into app.holiday_feed (id, country, kind, starts_on, ends_on, names, nationwide)
  values ('feed-mine', 'CH', 'school', '2026-10-02', '2026-10-03', '{}', true) $$, '42501',
  'permission denied for table holiday_feed', 'a member cannot write a holiday feed row');

-- A school in a canton; the region is sent, the state is derived from it.
insert into ids select 'sch_ch', (api.school_save(null, '{"name":"Schule Zürich","region_code":"CH-ZH-ZH-ZH"}'::jsonb) ->> 'id')::uuid;
select is((select region_code from api.schools where id = (select id from ids where name = 'sch_ch')), 'CH-ZH-ZH-ZH',
  'a school keeps the region it was given');
select is((select state_code from api.schools where id = (select id from ids where name = 'sch_ch')), 'CH-ZH',
  'the state is the first two segments of the region');
select is((select count(*)::int from api.subjects), 10, 'a Swiss school brings the ten Lehrplan 21 starter subjects');
select ok(exists (select 1 from api.subjects where name = 'Französisch' and short_name = 'F'),
  'the Swiss starter list has French');
select ok(not exists (select 1 from api.subjects where name = 'Sachunterricht'),
  'the Swiss starter list does not carry the German list');
select ok((select notable_default and equipment_note = 'Sportsachen' from api.subjects where short_name = 'BS'),
  'Bewegung und Sport is notable and needs its kit');

-- A state_code only save (the previous app release) sets the region as well.
select lives_ok($$ select api.school_save(null, jsonb_build_object('id', (select id from ids where name = 'sch_ch'),
  'name', 'Schule Zürich', 'state_code', 'DE-BE')) $$, 'a state code only save is still accepted');
select is((select region_code from api.schools where id = (select id from ids where name = 'sch_ch')), 'DE-BE',
  'a state code only save sets the region to the state');
select lives_ok($$ select api.school_save(null, jsonb_build_object('id', (select id from ids where name = 'sch_ch'),
  'name', 'Schule Zürich', 'region_code', 'AT-9')) $$, 'an Austrian region is accepted');
select is((select state_code from api.schools where id = (select id from ids where name = 'sch_ch')), 'AT-9',
  'an Austrian state is the region itself');
-- OpenHolidays writes some codes with umlauts (AT-NÖ, CH-BE-SL-RÜ).
select lives_ok($$ select api.school_save(null, jsonb_build_object('id', (select id from ids where name = 'sch_ch'),
  'name', 'Schule Zürich', 'region_code', 'CH-BE-SL-RÜ')) $$, 'a region code with an umlaut is accepted');
select is((select state_code from api.schools where id = (select id from ids where name = 'sch_ch')), 'CH-BE',
  'the state of a municipality with an umlaut is its canton');
select lives_ok($$ select api.school_save(null, jsonb_build_object('id', (select id from ids where name = 'sch_ch'),
  'name', 'Schule Zürich', 'region_code', 'AT-NÖ')) $$, 'an Austrian state with an umlaut is accepted');
select is((select state_code from api.schools where id = (select id from ids where name = 'sch_ch')), 'AT-NÖ',
  'an Austrian state with an umlaut is the state code too');
select throws_ok($$ select api.school_save(null, '{"name":"X","region_code":"CH-BE-SL-rü"}'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'umlauts in region codes are upper case too');
select lives_ok($$ select api.school_save(null, jsonb_build_object('id', (select id from ids where name = 'sch_ch'),
  'name', 'Schule Zürich', 'region_code', null)) $$, 'a null region clears the region');
select ok((select region_code is null and state_code is null from api.schools where id = (select id from ids where name = 'sch_ch')),
  'a cleared region clears the state too');
select throws_ok($$ select api.school_save(null, '{"name":"X","region_code":"Zurich"}'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'a region is a subdivision code, not a name');
select throws_ok($$ select api.school_save(null, '{"name":"X","region_code":"CH"}'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'a country alone is not a region');
select throws_ok($$ select api.school_save(null, '{"name":"X","region_code":"CH-zh"}'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'region codes are upper case');
select throws_ok($$ select api.school_save(null, '{"name":"X","region_code":"CH-ZH-ZH-ZH-ZH-ZH"}'::jsonb) $$,
  '22023', 'WW-SCH-001 school invalid', 'a region has at most four levels below the country');

-- Restore the Swiss school for the import tests below.
select lives_ok($$ select api.school_save(null, jsonb_build_object('id', (select id from ids where name = 'sch_ch'),
  'name', 'Schule Zürich', 'region_code', 'CH-ZH-ZH-ZH')) $$, 'the school is back in Zürich');

-- The starter lists of Austria and Germany, each written into an empty subject list (the owner
-- empties it here, rolled back with the rest).
reset role;
delete from app.subject where household_id = (select id from ids where name = 'hh_a');
select pg_temp.act_as_dev('papa');
insert into ids select 'sch_at', (api.school_save(null, '{"name":"Schule Wien","region_code":"AT-9"}'::jsonb) ->> 'id')::uuid;
select is((select count(*)::int from api.subjects), 10, 'an Austrian school brings the ten Austrian starter subjects');
select ok(exists (select 1 from api.subjects where name = 'Kunst und Gestaltung' and short_name = 'KuG'),
  'the Austrian starter list has Kunst und Gestaltung');
reset role;
delete from app.subject where household_id = (select id from ids where name = 'hh_a');
select pg_temp.act_as_dev('papa');
insert into ids select 'sch_de', (api.school_save(null, '{"name":"Grundschule","region_code":"DE-BE"}'::jsonb) ->> 'id')::uuid;
select ok(exists (select 1 from api.subjects where name = 'Sachunterricht')
          and exists (select 1 from api.subjects where name = 'Religion/Ethik'),
  'a German school keeps the German starter list');
select is((select count(*)::int from api.subjects), 11, 'the German starter list has eleven subjects');

-- ---- holidays: the preview -----------------------------------------------------------------------
-- A manual holiday of the household for the school, overlapping the Herbstferien of Zürich
-- (inserted as the owner).
reset role;
insert into app.school_holiday (household_id, school_id, name, starts_on, ends_on, kind, source)
  values ((select id from ids where name = 'hh_a'), (select id from ids where name = 'sch_ch'),
          'Eigene Ferien', '2026-10-21', '2026-10-22', 'holiday', 'manual');
select pg_temp.act_as_dev('papa');

select is(jsonb_array_length(api.holiday_import_preview(null, (select id from ids where name = 'sch_ch'),
  'CH-ZH-ZH-ZH', '2026-07-01', '2026-12-31')), 2,
  'the preview lists the holidays that cover the municipality: the nationwide one and the canton''s');
select is((api.holiday_import_preview(null, (select id from ids where name = 'sch_ch'),
  'CH-ZH-ZH-ZH', '2026-07-01', '2026-12-31') -> 0 ->> 'feed_id'), 'feed-ch-nat',
  'the preview is ordered by start date');
select is((api.holiday_import_preview(null, (select id from ids where name = 'sch_ch'),
  'CH-ZH-ZH-ZH', '2026-07-01', '2026-12-31') -> 0 ->> 'kind'), 'public_holiday',
  'a public holiday comes as public_holiday');
select is((api.holiday_import_preview(null, (select id from ids where name = 'sch_ch'),
  'CH-ZH-ZH-ZH', '2026-07-01', '2026-12-31') -> 1 ->> 'kind'), 'holiday',
  'a school holiday comes as holiday');
select is((select (e ->> 'overlaps_existing')::boolean::text from jsonb_array_elements(api.holiday_import_preview(null,
  (select id from ids where name = 'sch_ch'), 'CH-ZH-ZH-ZH', '2026-07-01', '2026-12-31')) e
  where e ->> 'feed_id' = 'feed-zh-ferien'), 'true', 'a manual holiday that overlaps is flagged');
select is((select (e ->> 'overlaps_existing')::boolean::text from jsonb_array_elements(api.holiday_import_preview(null,
  (select id from ids where name = 'sch_ch'), 'CH-ZH-ZH-ZH', '2026-07-01', '2026-12-31')) e
  where e ->> 'feed_id' = 'feed-ch-nat'), 'false', 'a holiday with no overlap is not flagged');
select is((select (e ->> 'already_imported')::boolean::text from jsonb_array_elements(api.holiday_import_preview(null,
  (select id from ids where name = 'sch_ch'), 'CH-ZH-ZH-ZH', '2026-07-01', '2026-12-31')) e
  where e ->> 'feed_id' = 'feed-zh-ferien'), 'false', 'nothing is imported yet');
select is(jsonb_array_length(api.holiday_import_preview(null, null, 'CH-ZH-ZH-ZH', '2026-07-01', '2026-12-31')), 1,
  'without a school only the public holidays come back');
select is(jsonb_array_length(api.holiday_import_preview(null, (select id from ids where name = 'sch_ch'),
  'CH-AG', '2026-07-01', '2026-12-31')), 3,
  'the Aargau preview has its nationwide, public and school holidays');
select is(jsonb_array_length(api.holiday_import_preview(null, (select id from ids where name = 'sch_ch'),
  'CH-ZH-ZH-ZH', '2026-11-01', '2026-11-30')), 0, 'a window with no holidays is empty');
select throws_ok($$ select api.holiday_import_preview(null, (select id from ids where name = 'sch_ch'),
  'CH-ZH-ZH-ZH', '2024-01-01', '2026-12-31') $$, '22023', 'WW-SCH-001 school invalid',
  'a preview window over 800 days is refused');
select throws_ok($$ select api.holiday_import_preview(null, (select id from ids where name = 'sch_ch'),
  'Zurich', '2026-07-01', '2026-12-31') $$, '22023', 'WW-SCH-001 school invalid', 'a preview needs a region code');
select is(jsonb_array_length(api.holiday_import_preview(null, null, 'CH-BE-SL-RÜ', '2026-07-01', '2026-12-31')), 1,
  'a preview for a region code with an umlaut works (the nationwide holiday)');
select throws_ok($$ select api.holiday_import_preview(null, (select id from ids where name = 'school_b'),
  'CH-ZH-ZH-ZH', '2026-07-01', '2026-12-31') $$, 'P0002', 'school not found',
  'a preview for a school of another household is refused');

-- ---- holidays: the import ------------------------------------------------------------------------
-- A child on the shared iPad cannot import; a revoked phone cannot; a school of another household
-- cannot be named.
reset role;
select pg_temp.act_as_dev('ipad');
select throws_ok($$ select api.holiday_import((select id from ids where name = 'emma'),
  (select id from ids where name = 'sch_ch'), array['feed-ch-nat'], 'de') $$,
  '42501', 'guardian required', 'a child cannot import holidays');
reset role;
select pg_temp.act_as_dev('old');
select throws_ok($$ select api.holiday_import(null, (select id from ids where name = 'sch_ch'), array['feed-ch-nat'], 'de') $$,
  '42501', 'device not usable', 'a revoked phone cannot import holidays');
reset role;
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.holiday_import(null, (select id from ids where name = 'school_b'),
  array['feed-zh-ferien'], 'de') $$, 'P0002', 'school not found', 'another household''s school cannot receive an import');
select throws_ok($$ select api.holiday_import(null, null, array['feed-zh-ferien'], 'de') $$,
  '22023', 'WW-SCH-001 school invalid', 'a school holiday needs a school');

-- Papa imports the public holiday and the Zürich school holidays; the unknown id is ignored.
select is(api.holiday_import(null, (select id from ids where name = 'sch_ch'),
  array['feed-ch-nat', 'feed-zh-ferien', 'feed-unknown'], 'de'), 2, 'the import inserts the two known holidays');
select is(api.holiday_import(null, (select id from ids where name = 'sch_ch'),
  array['feed-ch-nat', 'feed-zh-ferien'], 'de'), 0, 'importing the same holidays again inserts nothing');
select is(api.holiday_import(null, (select id from ids where name = 'sch_ch'), '{}'::text[], 'de'), 0,
  'an empty import inserts nothing');
select is((select count(*)::int from jsonb_array_elements(api.holiday_import_preview(null,
  (select id from ids where name = 'sch_ch'), 'CH-ZH-ZH-ZH', '2026-07-01', '2026-12-31')) e
  where (e ->> 'already_imported')::boolean), 2, 'the preview flags both imported holidays');
select is((select school_id from api.school_holidays where feed_id = 'feed-ch-nat'), null::uuid,
  'a public holiday is stored without a school');
select is((select kind from api.school_holidays where feed_id = 'feed-ch-nat'), 'public_holiday',
  'an imported public holiday has the public_holiday kind');
select is((select school_id from api.school_holidays where feed_id = 'feed-zh-ferien'),
  (select id from ids where name = 'sch_ch'), 'a school holiday is stored for its school');
select is((select source || ' ' || source_url from api.school_holidays where feed_id = 'feed-zh-ferien'),
  'imported https://openholidaysapi.org', 'an imported holiday names its source');
select is((select name from api.school_holidays where feed_id = 'feed-zh-ferien'), 'Herbstferien',
  'an imported holiday takes its name in the household language');
reset role;
select ok(exists (select 1 from app.audit_log where entity_type = 'school_holiday' and action = 'create'
                  and diff ->> 'feed_id' = 'feed-zh-ferien'),
  'an import is audited per holiday');
select pg_temp.act_as_dev('papa');
-- The same school holidays are imported for the Aargau school only when that school exists; the
-- feed row of another canton does not reach Zürich.
select is((select count(*)::int from api.school_holidays where feed_id = 'feed-ag-ferien'), 0,
  'a holiday of another canton is not imported');

-- A manual holiday cannot be given a feed id, and the public kind is accepted by hand too.
select lives_ok($$ select api.school_holiday_save(null, jsonb_build_object('name', 'Brückentag',
  'starts_on', '2026-12-24', 'ends_on', '2026-12-24', 'kind', 'public_holiday')) $$,
  'a public holiday can be entered by hand');
select is((select feed_id from api.school_holidays where name = 'Brückentag'), null::text,
  'a manual holiday has no feed id');

-- Another household sees none of the imported holidays.
reset role;
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.school_holidays where feed_id is not null), 0,
  'another household sees none of the imported holidays');

-- ---- household region -----------------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.set_setting(null, 'household.region', '"CH-ZH-ZH-ZH"'::jsonb) $$,
  'a guardian sets the household region to a municipality');
select is((select value #>> '{}' from api.settings where key = 'household.region' and profile_id is null and device_id is null),
  'CH-ZH-ZH-ZH', 'the household region is read back');
select throws_ok($$ select api.set_setting(null, 'household.region', '"Zurich"'::jsonb) $$,
  '22023', 'WW-SET-001 setting value out of range', 'a household region is a code, not a name');
select throws_ok($$ select api.set_setting(null, 'household.region', '"CH"'::jsonb) $$,
  '22023', 'WW-SET-001 setting value out of range', 'a household region needs a level below the country');
select lives_ok($$ select api.set_setting(null, 'household.region', '"AT-OÖ"'::jsonb) $$,
  'a household region with an umlaut is accepted');
select lives_ok($$ select api.set_setting(null, 'household.region', 'null'::jsonb) $$,
  'the household region can be cleared');

-- ---- a revoked device reads no reference data either ---------------------------------------------
reset role;
select pg_temp.act_as_dev('old');
select is((select count(*)::int from api.regions), 0, 'a revoked device reads no regions');
select is((select count(*)::int from api.holiday_feed_status), 0, 'a revoked device reads no feed status');

-- ---- the cache is written by the sync, through service-role-only functions -----------------------
reset role;
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.holiday_cache_put_regions('[]'::jsonb) $$, '42501', null,
  'a member cannot write the region cache');
select throws_ok($$ select api.holiday_cache_claim('CH', now(), now()) $$, '42501', null,
  'a member cannot claim a cache refresh');
reset role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
select is(api.holiday_cache_put_regions('[{"code":"AT-9","country":"AT","parent_code":null,"level":1,
  "category":"Bundesland","short_name":"W","names":{"de":"Wien"},"fetched_at":"2026-10-14T00:00:00Z"}]'::jsonb),
  1, 'the service role upserts regions');
select is(api.holiday_cache_put_regions('[{"code":"AT-KÄ","country":"AT","parent_code":null,"level":1,
  "category":"Bundesland","short_name":"KÄ","names":{"de":"Kärnten"},"fetched_at":"2026-10-14T00:00:00Z"},
  {"code":"CH-BE-SL-RÜ","country":"CH","parent_code":"CH-BE-SL","level":3,"category":"Gemeinde",
  "short_name":"BE-SL-RÜ","names":{"de":"Rüti bei Büren"},"fetched_at":"2026-10-14T00:00:00Z"}]'::jsonb),
  2, 'the cache takes the region codes with umlauts that OpenHolidays sends');
select is(api.holiday_cache_put_holidays('[{"id":"feed-at","country":"AT","kind":"public","starts_on":"2026-10-26",
  "ends_on":"2026-10-26","names":{"de":"Nationalfeiertag"},"nationwide":false,"subdivisions":["AT-9"],
  "fetched_at":"2026-10-14T00:00:00Z"}]'::jsonb),
  1, 'the service role upserts holidays, subdivisions from a JSON array');
select ok(api.holiday_cache_claim('AT', now(), now() - interval '10 minutes'), 'a first refresh is claimed');
select ok(not api.holiday_cache_claim('AT', now(), now() - interval '10 minutes'),
  'a second refresh within ten minutes is refused');
select is(api.holiday_cache_prune('CH', 'school', '2026-01-01', '2027-12-31', array['feed-zh-ferien']), 1,
  'pruning removes the school holidays the API no longer returns');
select is((api.holiday_cache_state('CH') ->> 'holidays')::int, 3, 'the other Swiss holidays stay');
select lives_ok($$ select api.holiday_cache_finish('AT', now(), '2025-01-01', '2027-12-31') $$,
  'a refresh is recorded');
select is((api.holiday_cache_state('AT') ->> 'regions')::int, 2, 'the cache state counts the regions (Wien and Kärnten)');
select ok('AT' = any (api.holiday_cache_countries()), 'a fetched country is refreshed again');
select lives_ok($$ select api.holiday_cache_fail('AT', 'timeout') $$, 'a failed refresh is recorded');
reset role;
select pg_temp.act_as_dev('papa');
select is((select last_error from api.holiday_feed_status where country = 'AT'), 'timeout',
  'members see that the last refresh failed');
reset role;
select ok((select app.region_covers('AT-9', h.country, h.nationwide, h.subdivisions)
             from app.holiday_feed h where h.id = 'feed-at'), 'the stored subdivisions are a text array');

-- ---- starter subjects per region and language (app.starter_subjects, direct) ----------------------
create temp table hh (name text primary key, id uuid);
insert into app.household (name) values ('FR'), ('ES-VC'), ('CH-GE'), ('CH-FR-fr'), ('CH-TI'), ('AT'), ('BE-fr');
insert into hh select name, id from app.household where name in ('FR', 'ES-VC', 'CH-GE', 'CH-FR-fr', 'CH-TI', 'AT', 'BE-fr');
select is(app.starter_subjects((select id from hh where name = 'FR'), 'FR-IDF', 'fr'), 11,
  'a French school brings the eleven French starter subjects');
select ok(exists (select 1 from app.subject where household_id = (select id from hh where name = 'FR')
  and name = 'Questionner le monde' and short_name = 'QLM'), 'the French list has Questionner le monde');
select is(app.starter_subjects((select id from hh where name = 'ES-VC'), 'ES-VC', 'es'), 12,
  'a Valencian school brings the Spanish list plus Valencià');
select ok(exists (select 1 from app.subject where household_id = (select id from hh where name = 'ES-VC')
  and short_name = 'VAL'), 'the Valencian list has Valencià');
select is(app.starter_subjects((select id from hh where name = 'CH-GE'), 'CH-GE-GE-GE', 'de'), 12,
  'a Geneva school brings the French-speaking Swiss list, whatever the app language');
select ok(exists (select 1 from app.subject where household_id = (select id from hh where name = 'CH-GE')
  and name = 'Activités créatrices manuelles'), 'the Romandie list has ACM');
select is(app.starter_subjects((select id from hh where name = 'CH-FR-fr'), 'CH-FR', 'fr'), 12,
  'a bilingual canton follows the app language');
select is(app.starter_subjects((select id from hh where name = 'CH-TI'), 'CH-TI', 'de'), 9,
  'Ticino brings the Italian list');
select is(app.starter_subjects((select id from hh where name = 'AT'), 'AT-9', null), 10,
  'an Austrian school brings the ten Austrian starter subjects');
select ok(exists (select 1 from app.subject where household_id = (select id from hh where name = 'AT')
  and name = 'Kunst und Gestaltung' and short_name = 'KuG'), 'the Austrian list carries the 2023/24 names');
select is(app.starter_subjects((select id from hh where name = 'BE-fr'), 'BE-WAL', 'fr'), 11,
  'a country without a list follows the app language');
select is(app.starter_subjects((select id from hh where name = 'BE-fr'), 'BE-WAL', 'fr'), 0,
  'a household with subjects gets no starter list');

select * from finish();
rollback;
