begin;
select plan(27);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create function pg_temp.act_as(p_sub uuid, p_claims jsonb) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_sub, 'role', 'authenticated') || p_claims)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- One member of a board by display name.
create function pg_temp.member(p_board jsonb, p_name text) returns jsonb
language sql stable as $$
  select m.v from jsonb_array_elements(p_board -> 'members') m(v) where m.v ->> 'display_name' = p_name
$$;

-- Household A: a guardian on a personal phone, plus a child without an account.
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (sa.r ->> 'household_id')::uuid, p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from sa join app.profile p on p.id = (sa.r ->> 'profile_id')::uuid;
create temp table ctxa as
  select (sa.r ->> 'household_id')::uuid hh, p.auth_user_id usr, d.id dev, p.id prof
    from sa join app.profile p on p.id = (sa.r ->> 'profile_id')::uuid
    join app.device d on d.profile_id = p.id;
grant all on ctxa to public;

-- Household B, made by hand as in 020 (setup closes after the first household).
insert into app.household (name) values ('B');
create temp table ctxb as
  select h.id hh, app.create_auth_user('b@example.org', 'longpassword1') usr
    from app.household h where h.name = 'B';
grant all on ctxb to public;
insert into app.profile (household_id, display_name, role, auth_user_id)
  select hh, 'B', 'guardian', usr from ctxb;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select b.hh, b.usr, 'B-Phone', 'personal', 'adult', (select id from app.profile where auth_user_id = b.usr)
    from ctxb b;

-- Papa has a baseline; a child is added with a direct insert (sort order from the trigger).
update app.profile set default_presence_state = 'home_office', default_presence_label = 'Homeoffice'
 where id = (select prof from ctxa);
insert into app.profile (household_id, display_name, role, kind)
  select hh, 'Emma', 'member', 'child' from ctxa;

-- The guardian's phone adds Paul through the add-member function.
select pg_temp.act_as((select usr from ctxa), jsonb_build_object(
  'household_id', (select hh from ctxa), 'device_id', (select dev from ctxa), 'device_class', 'personal'));
create temp table added as select api.members_add(null, 'Paul', '#ff8800') id;
grant all on added to public;
select is((select sort_order from api.members where id = (select id from added)), 30,
  'a new member goes to the end: the last sort order plus ten');

-- Paul is moved in front of Emma: the board follows sort_order, not creation order.
reset role;
update app.profile set sort_order = 15 where id = (select id from added);
select pg_temp.act_as((select usr from ctxa), jsonb_build_object(
  'household_id', (select hh from ctxa), 'device_id', (select dev from ctxa), 'device_class', 'personal'));

-- Shopping: three open items and one ticked on the default list; one open item on another list.
create temp table items as
  select api.shopping_add_item(null, 'Milch') m, api.shopping_add_item(null, 'Brot') br,
         api.shopping_add_item(null, 'Butter') bu;
grant all on items to public;
select api.shopping_toggle_item(null, (select bu from items));
create temp table drogerie as select api.shopping_list_create(null, 'Drogerie', 'drugstore') id;
grant all on drogerie to public;
select api.shopping_add_item(null, 'Zahnpasta', null, (select id from drogerie));

create temp table bd (k text primary key, board jsonb);
grant all on bd to public;
insert into bd values ('now', api.board_week());
insert into bd values ('sep2', api.board_week('2026-09-02'));

-- ---- shape: seven days, a Monday first, consecutive, every zone present ----------------
select is(jsonb_array_length((select board -> 'days' from bd where k = 'now')), 7,
  'the board has seven days');
select is(extract(isodow from ((select board ->> 'week_start' from bd where k = 'now'))::date)::int, 1,
  'the week starts on a Monday');
select ok((select bool_and((e.v ->> 'date')::date = (x.board ->> 'week_start')::date + e.n::int - 1)
             from bd x cross join lateral jsonb_array_elements(x.board -> 'days') with ordinality e(v, n)
            where x.k = 'now'),
  'the days run on from week_start without gaps');
select ok((select bool_and(e.v -> 'events' = '[]'::jsonb and e.v -> 'busy_until' = '[]'::jsonb
                       and e.v -> 'school' = '[]'::jsonb and e.v -> 'meal' = 'null'::jsonb)
             from bd x cross join lateral jsonb_array_elements(x.board -> 'days') e(v)
            where x.k = 'now'),
  'every day has the same empty zones until the calendar and meals exist');
select ok((select board -> 'presence' = '[]'::jsonb and board -> 'timetables' = '[]'::jsonb
                  and board -> 'open_tasks' = '[]'::jsonb
             from bd where k = 'now'),
  'presence, timetables and open tasks are empty arrays');

-- ---- explicit week start ------------------------------------------------------------------
select is((select board ->> 'week_start' from bd where k = 'sep2'), '2026-08-31',
  'a date in the week gives that week''s Monday');
select is((select board -> 'days' -> 2 ->> 'date' from bd where k = 'sep2'), '2026-09-02',
  'the days follow the given week');
select is(api.board_week('2026-08-31') ->> 'week_start', '2026-08-31',
  'a Monday is its own week start');

-- ---- members ------------------------------------------------------------------------------
select is((select array_agg(m.v ->> 'display_name' order by m.n)
             from bd x cross join lateral jsonb_array_elements(x.board -> 'members') with ordinality m(v, n)
            where x.k = 'now'),
  array['Papa', 'Paul', 'Emma'], 'members come back in sort order');
select is(pg_temp.member((select board from bd where k = 'now'), 'Emma') ->> 'kind', 'child',
  'a child is marked as a child');
select is(pg_temp.member((select board from bd where k = 'now'), 'Papa') ->> 'kind', 'adult',
  'a guardian is an adult');
select is(pg_temp.member((select board from bd where k = 'now'), 'Papa') -> 'baseline',
  '{"state": "home_office", "label": "Homeoffice"}'::jsonb, 'a set baseline is returned with its label');
select is(pg_temp.member((select board from bd where k = 'now'), 'Emma') -> 'baseline', 'null'::jsonb,
  'no baseline is a JSON null');
select is(pg_temp.member((select board from bd where k = 'now'), 'Papa') ->> 'color', '#111111',
  'members carry their colour');

-- ---- shopping -----------------------------------------------------------------------------
select is((select (board ->> 'shopping_count')::int from bd where k = 'now'), 2,
  'the count is the open items of the default list: other lists and ticked items are left out');

-- ---- settings -----------------------------------------------------------------------------
select is((select board -> 'settings' -> 'day_parts' from bd where k = 'now'), '["12:00", "17:00"]'::jsonb,
  'day parts default to noon and five');
select is((select board -> 'settings' ->> 'member_label' from bd where k = 'now'), 'name',
  'member labels default to the name');

reset role;
insert into app.household_setting (household_id, key, value, updated_by_profile_id)
  select hh, 'board.day_parts', '["11:30", "16:00"]', prof from ctxa;
select pg_temp.act_as((select usr from ctxa), jsonb_build_object(
  'household_id', (select hh from ctxa), 'device_id', (select dev from ctxa), 'device_class', 'personal'));
insert into bd values ('parts', api.board_week());
select is((select board -> 'settings' -> 'day_parts' from bd where k = 'parts'), '["11:30", "16:00"]'::jsonb,
  'a household override replaces the default');

-- ---- rollover -----------------------------------------------------------------------------
-- The default rollover (the setting's default, Saturday noon): the week containing today,
-- or the next one once the rollover has passed. Computed here from the household's timezone.
select is((select board ->> 'week_start' from bd where k = 'now'),
  (select to_char((d.m + case when d.lt >= (d.m + ((sd.default_value ->> 'weekday')::int - 1))
                                          + (sd.default_value ->> 'time')::time then 7 else 0 end)::timestamp,
                  'YYYY-MM-DD')
     from app.setting_definition sd
     cross join (select date_trunc('week', (now() at time zone h.timezone)::timestamp)::date m,
                        now() at time zone h.timezone lt
                   from app.household h where h.id = (select hh from ctxa)) d
    where sd.key = 'board.rollover'),
  'the default rollover is the setting''s default, in the household''s timezone');

reset role;
insert into app.household_setting (household_id, key, value, updated_by_profile_id)
  select hh, 'board.rollover', '{"weekday": 1, "time": "00:00"}', prof from ctxa;
select pg_temp.act_as((select usr from ctxa), jsonb_build_object(
  'household_id', (select hh from ctxa), 'device_id', (select dev from ctxa), 'device_class', 'personal'));
insert into bd values ('rollover', api.board_week());
select is((select board ->> 'week_start' from bd where k = 'rollover'),
  (select to_char(date_trunc('week', (now() at time zone h.timezone)::timestamp) + interval '7 days', 'YYYY-MM-DD')
     from app.household h where h.id = (select hh from ctxa)),
  'a rollover at Monday midnight always shows next week');
select is(api.board_week('2026-09-02') ->> 'week_start', '2026-08-31',
  'an explicit week start ignores the rollover');

-- ---- another household ----------------------------------------------------------------------
reset role;
-- auth_user_id is not granted to authenticated: look B's profile up as the owner first.
create temp table bprof as select id from app.profile where auth_user_id = (select usr from ctxb);
grant all on bprof to public;
select pg_temp.act_as((select usr from ctxb), jsonb_build_object(
  'household_id', (select hh from ctxb), 'device_id', (select id from app.device where auth_user_id = (select usr from ctxb)),
  'device_class', 'personal'));
select is(jsonb_array_length(api.board_week() -> 'members'), 1,
  'another household sees only its own members');
select is((api.board_week() -> 'members' -> 0 ->> 'id')::uuid, (select id from bprof),
  'the member it sees is its own');
select is((api.board_week() ->> 'shopping_count')::int, 0,
  'another household''s shopping is not counted');

-- ---- a revoked device ------------------------------------------------------------------------
reset role;
update app.device set revoked_at = now() where auth_user_id = (select usr from ctxb);
select pg_temp.act_as((select usr from ctxb), jsonb_build_object(
  'household_id', (select hh from ctxb), 'device_id', (select id from app.device where auth_user_id = (select usr from ctxb)),
  'device_class', 'personal'));
select throws_ok('select api.board_week()', '42501', 'WW-BOARD-001 no household',
  'a revoked device gets no board');

-- ---- anon -----------------------------------------------------------------------------------
reset role;
set local role anon;
select throws_ok('select api.board_week()', '42501', 'permission denied for function board_week',
  'anon cannot read the board');
reset role;

select * from finish();
rollback;
