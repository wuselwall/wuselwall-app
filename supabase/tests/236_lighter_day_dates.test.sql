-- Birthdays, Vorfreude and traditions after the review (20261025100000_lighter_day_dates_fixes):
-- the wall edits no member, a presence entry carries no ritual flag, members set flags only on
-- events they may edit, "Nicht mehr dabei" clears the birthday, the ICS feed carries birthdays,
-- and the tradition meals stay behind the perimeter.
begin;
select plan(25);


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

-- ---- household A: Papa (guardian, personal phone), Emma (child), Paul (adult member) ----------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#7B3FE4', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into app.profile (household_id, display_name, role, kind)
  select (r ->> 'household_id')::uuid, 'Emma', 'member', 'child' from sa;
insert into app.profile (household_id, display_name, role)
  select (r ->> 'household_id')::uuid, 'Paul', 'member' from sa;
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

-- ================================================================ member_update: never from the wall
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, p_birthday => '2017-03-09') $q$,
  pg_temp.id('emma'), pg_temp.id('emma'))), 'kiosk_forbidden', 'the wall sets no birthday, not even "its own"');
select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, 'Fremd') $q$,
  pg_temp.id('papa'), pg_temp.id('papa'))), 'kiosk_forbidden', 'nor renames anyone');
select pg_temp.act_as_dev('papa');
select is((select display_name || ' ' || coalesce(birthday::text, '-') from api.members where id = pg_temp.id('emma')),
  'Emma -', 'and nothing changed');

-- The previous app release calls with six arguments, no birthday.
select is(pg_temp.error_hint(format($q$ select api.member_update(null, %L, 'Emma', '#FF8800', null, null) $q$,
  pg_temp.id('emma'))), null, 'the call shape without p_birthday still works');
select is((select color from api.members where id = pg_temp.id('emma')), '#FF8800', 'and saves');
select api.member_update(null, pg_temp.id('paul'), p_birthday => '1990-05-01');
select is(pg_temp.error_hint(format($q$ select api.member_update(null, %L, 'Paul') $q$, pg_temp.id('paul'))),
  null, 'a rename without the birthday ...');
select is((select birthday from api.members where id = pg_temp.id('paul')), date '1990-05-01', '... keeps the birthday');

-- ================================================================ event flags: who may set them
-- Papa's own appointment, which Emma does not attend.
create temp table ev as select api.event_save(null, jsonb_build_object(
  'title', 'Elternabend', 'kind', 'appointment', 'is_all_day', true,
  'start_date', '2026-11-12', 'end_date', '2026-11-12',
  'attendee_ids', jsonb_build_array(pg_temp.id('papa')))) r;
grant all on ev to public;
insert into ids select 'parents_evening', (r ->> 'id')::uuid from ev;

select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($q$ select api.event_save(%L, jsonb_build_object('id', %L, 'title', 'Elternabend',
  'kind', 'appointment', 'is_all_day', true, 'start_date', '2026-11-12', 'end_date', '2026-11-12',
  'attendee_ids', jsonb_build_array(%L), 'countdown', true)) $q$,
  pg_temp.id('emma'), pg_temp.id('parents_evening'), pg_temp.id('papa'))),
  'guardian_required', 'a member cannot mark an event they do not attend for Vorfreude');
select is(pg_temp.error_hint(format($q$ select api.event_save(%L, jsonb_build_object('id', %L, 'title', 'Elternabend',
  'kind', 'appointment', 'is_all_day', true, 'start_date', '2026-11-12', 'end_date', '2026-11-12',
  'attendee_ids', jsonb_build_array(%L, %L), 'tradition', true)) $q$,
  pg_temp.id('emma'), pg_temp.id('parents_evening'), pg_temp.id('papa'), pg_temp.id('emma'))),
  'guardian_required', 'nor make it a tradition by adding themselves');
select is((select countdown::text || ' ' || tradition from api.events where id = pg_temp.id('parents_evening')),
  'false false', 'the flags stay as they were');

-- Emma's own event is hers to mark, until the household says members do not edit events.
select is(pg_temp.error_hint(format($q$ select api.event_save(%L, jsonb_build_object('title', 'Zoo',
  'kind', 'appointment', 'is_all_day', true, 'start_date', '2026-11-14', 'end_date', '2026-11-14',
  'attendee_ids', jsonb_build_array(%L), 'countdown', true, 'icon_key', 'lion')) $q$,
  pg_temp.id('emma'), pg_temp.id('emma'))), null, 'a member marks their own event');
reset role;
insert into app.household_setting (household_id, key, value)
  values (pg_temp.id('hh_a'), 'calendar.members_edit_own_events', 'false');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($q$ select api.event_save(%L, jsonb_build_object('title', 'Kino',
  'kind', 'appointment', 'is_all_day', true, 'start_date', '2026-11-15', 'end_date', '2026-11-15',
  'attendee_ids', jsonb_build_array(%L), 'countdown', true)) $q$,
  pg_temp.id('emma'), pg_temp.id('emma'))), 'guardian_required',
  'with calendar.members_edit_own_events off, a member marks nothing');
select is((select count(*)::int from api.events where title = 'Kino'), 0, 'and no event was saved');

-- ================================================================ presence entries carry no ritual
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($q$ select api.event_save(null, jsonb_build_object('title', 'Dienstreise',
  'kind', 'presence', 'presence_state', 'travel', 'is_all_day', true, 'start_date', '2026-11-02',
  'end_date', '2026-11-05', 'attendee_ids', jsonb_build_array(%L), 'countdown', true)) $q$, pg_temp.id('papa'))),
  'event_invalid', 'a presence entry is not counted down to by hand');
select is(pg_temp.error_hint(format($q$ select api.event_save(null, jsonb_build_object('title', 'Dienstreise',
  'kind', 'presence', 'presence_state', 'travel', 'is_all_day', true, 'start_date', '2026-11-02',
  'end_date', '2026-11-05', 'attendee_ids', jsonb_build_array(%L), 'tradition', true)) $q$, pg_temp.id('papa'))),
  'event_invalid', 'nor a tradition');
select is(pg_temp.error_hint(format($q$ select api.event_save(null, jsonb_build_object('title', 'Dienstreise',
  'kind', 'presence', 'presence_state', 'travel', 'is_all_day', true, 'start_date', '2026-11-02',
  'end_date', '2026-11-05', 'attendee_ids', jsonb_build_array(%L), 'icon_key', 'airplane')) $q$, pg_temp.id('papa'))),
  'event_invalid', 'nor has an icon');
select is(pg_temp.error_hint(format($q$ select api.event_save(null, jsonb_build_object('title', 'Dienstreise',
  'kind', 'presence', 'presence_state', 'travel', 'is_all_day', true, 'start_date', '2026-11-02',
  'end_date', '2026-11-05', 'attendee_ids', jsonb_build_array(%L), 'icon_key', '', 'countdown', false,
  'tradition', false)) $q$, pg_temp.id('papa'))),
  null, 'the empty values the app always sends are fine');
-- An older app turns a marked appointment into a presence entry, sending none of the keys.
select api.event_save(null, jsonb_build_object('id', pg_temp.id('parents_evening'), 'title', 'Elternabend',
  'kind', 'appointment', 'is_all_day', true, 'start_date', '2026-11-12', 'end_date', '2026-11-12',
  'attendee_ids', jsonb_build_array(pg_temp.id('papa')), 'countdown', true, 'icon_key', 'school'));
select api.event_save(null, jsonb_build_object('id', pg_temp.id('parents_evening'), 'title', 'Elternabend',
  'kind', 'presence', 'presence_state', 'away', 'is_all_day', true, 'start_date', '2026-11-12', 'end_date', '2026-11-12',
  'attendee_ids', jsonb_build_array(pg_temp.id('papa'))));
select is((select coalesce(icon_key, '-') || ' ' || countdown || ' ' || tradition from api.events
            where id = pg_temp.id('parents_evening')), '- false false', 'and leaves no flag behind');

-- ================================================================ "Nicht mehr dabei" forgets the birthday
select api.member_update(null, pg_temp.id('emma'), p_birthday => '2017-03-09');
select is(pg_temp.error_hint(format($q$ select api.member_deactivate(null, %L) $q$, pg_temp.id('emma'))), null,
  'a guardian marks Emma as no longer here');
select is((select birthday from api.members where id = pg_temp.id('emma')), null, 'her birthday is cleared');
select ok((select diff ->> 'birthday' = 'cleared' and not (diff::text like '%2017%') from app.audit_log
            where entity_id = pg_temp.id('emma') and action = 'deactivate' order by id desc limit 1),
  'the audit row says it was cleared, not the date');

-- ================================================================ the ICS feed carries birthdays
create temp table tok (name text primary key, token text);
grant all on tok to public;
insert into tok select 'all', r ->> 'token' from (select api.feed_token_create(null, 'Oma', '{}'::jsonb) r) s;
reset role;
select is((select jsonb_agg(b ->> 'name' || ' ' || (b ->> 'birthday'))
             from jsonb_array_elements(api.ics_feed((select token from tok where name = 'all')) -> 'birthdays') b),
  '["Paul 1990-05-01"]'::jsonb, 'the feed carries the active members'' birthdays (not Emma''s, who left)');

-- ================================================================ tradition meals: the perimeter
select pg_temp.act_as_dev('papa');
select api.event_save(null, jsonb_build_object('title', 'Pizza-Freitag', 'kind', 'appointment', 'is_all_day', true,
  'start_date', '2026-11-06', 'end_date', '2026-11-06', 'rrule', 'FREQ=WEEKLY', 'tradition', true,
  'tradition_meal', jsonb_build_object('slot', 'dinner', 'free_text', 'Pizza')));
select is((select count(*)::int from app.tradition_meal), 1, 'the family reads its tradition meal');
select pg_temp.act_as_dev('old');
select is((select count(*)::int from app.tradition_meal), 0, 'a revoked device reads no tradition meal');
reset role;
set local role anon;
select throws_ok('select count(*) from app.tradition_meal', '42501', null,
  'an unauthenticated caller reads no tradition meal');
reset role;

select * from finish();
rollback;
