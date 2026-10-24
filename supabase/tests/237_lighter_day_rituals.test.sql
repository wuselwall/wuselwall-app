begin;
select plan(50);

-- The rituals after their review (migration 20261025110000): planning a wish onto a taken
-- slot, several open wishes, who may wish, the perimeter of the rituals' tables and the
-- Wochenrückblick's order and reach.

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

-- ---- household B, made by hand -----------------------------------------------------------------
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into users select 'b', app.create_auth_user('b@example.org', 'longpassword1');
insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_b'), 'B', 'guardian', usr from users where name = 'b';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.id('hh_b'), u.usr, 'B-Phone', 'personal', 'adult', p.id
    from users u join app.profile p on p.auth_user_id = u.usr where u.name = 'b';
insert into devs
  select 'b', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id
   where u.name = 'b';

-- ================================================================ who may wish (meals.wishes)
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, null, %L) $q$, pg_temp.id('emma'), repeat('x', 61))),
  'wish_invalid', 'a wish of more than 60 characters is refused');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, null, %L) $q$, pg_temp.id('emma'), repeat('x', 60))),
  null, 'sixty characters are fine');
select api.meal_wish_withdraw(pg_temp.id('emma'), (select id from api.meal_wishes where profile_id = pg_temp.id('emma')));

reset role;
insert into app.household_setting (household_id, key, value) values (pg_temp.id('hh_a'), 'meals.wishes', '"off"');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, null, 'Pizza') $q$, pg_temp.id('emma'))),
  'wishes_off', 'with wishes off not even a child wishes');

reset role;
update app.household_setting set value = '"everyone"' where household_id = pg_temp.id('hh_a') and key = 'meals.wishes';
insert into app.household_setting (household_id, key, value) values (pg_temp.id('hh_a'), 'meals.wishes_per_week', '2');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, null, 'Steak') $q$, pg_temp.id('paul'))),
  null, 'with wishes for everyone a grown-up wishes too');

-- ================================================================ several open wishes (wishes_per_week 2)
select api.meal_wish_set(pg_temp.id('emma'), null, 'Pizza');
-- One transaction has one now(): Pizza is made a minute older, so "the newest" is Suppe.
reset role;
update app.meal_wish set created_at = created_at - interval '1 minute' where free_text = 'Pizza';
select pg_temp.act_as_dev('ipad');
select api.meal_wish_set(pg_temp.id('emma'), null, 'Suppe');
select is((select string_agg(title, ',' order by created_at) from api.meal_wishes
            where profile_id = pg_temp.id('emma') and status = 'open'), 'Pizza,Suppe', 'two open wishes within a limit of two');
select api.meal_wish_set(pg_temp.id('emma'), null, 'Eis');
select is((select string_agg(title, ',' order by created_at) from api.meal_wishes
            where profile_id = pg_temp.id('emma') and status = 'open'), 'Pizza,Eis',
  'at the limit a call without the wish changes the newest, as the previous app expects');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, null, 'Nudeln', p_wish => %L) $q$,
  pg_temp.id('emma'), (select id from api.meal_wishes where title = 'Pizza'))), null, 'a named wish changes');
select is((select string_agg(title, ',' order by created_at) from api.meal_wishes
            where profile_id = pg_temp.id('emma') and status = 'open'), 'Nudeln,Eis',
  'the one named, not the newest, and no wish is added');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, null, 'Kohl', p_wish => %L) $q$,
  pg_temp.id('paul'), (select id from api.meal_wishes where title = 'Eis'))), 'wish_not_found',
  'nobody changes another member''s wish');
select is((select count(*)::int from app.meal_wish where profile_id = pg_temp.id('emma') and status = 'open'), 2,
  'the invariant holds: never more open wishes than the limit');

-- ================================================================ a guardian removes a wish
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_withdraw(null, %L) $q$,
  (select id from api.meal_wishes where title = 'Eis'))), null, 'a guardian removes someone else''s wish');
select is((select status from app.meal_wish where free_text = 'Eis'), 'withdrawn', 'it is withdrawn, never declined');
select is((select actor_profile_id from app.audit_log where entity_type = 'meal_wish' and action = 'withdraw'
            order by id desc limit 1), pg_temp.id('papa'), 'and the audit row names the guardian');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_withdraw(null, %L) $q$,
  (select id from api.meal_wishes where title = 'Steak'))), null, 'a grown-up''s wish too');

-- ================================================================ planning onto a taken slot
select api.meal_set(null, jsonb_build_object('on_date', '2026-11-02', 'slot', 'dinner', 'free_text', 'Linsen',
  'servings', '4', 'cook_profile_id', pg_temp.id('paul'), 'at_time', '18:45', 'guests', '1'));
select is(pg_temp.error_hint(format($q$ select api.meal_wish_plan(null, %L, '2026-11-02', 'dinner') $q$,
  (select id from api.meal_wishes where title = 'Nudeln'))), 'slot_taken',
  'a wish does not silently replace a planned meal');
select is((select title from api.meal_plan_entries where on_date = '2026-11-02' and slot = 'dinner'), 'Linsen',
  'the meal stays as it was');
select is((select status from app.meal_wish where free_text = 'Nudeln'), 'open', 'and the wish stays open');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_plan(null, %L, '2026-11-02', 'dinner', p_replace => true) $q$,
  (select id from api.meal_wishes where title = 'Nudeln'))), null, 'replacing is a choice the planner makes');
select is((select title || ' ' || servings || ' ' || (cook_profile_id = pg_temp.id('paul'))::text || ' '
                  || to_char(at_time, 'HH24:MI') || ' ' || guests || ' ' || (wished_by_profile_id = pg_temp.id('emma'))::text
             from api.meal_plan_entries where on_date = '2026-11-02' and slot = 'dinner'),
  'Nudeln 4 true 18:45 1 true', 'the wish takes the dish; servings, cook, time and guests stay');
select is((select (diff ->> 'replaced') from app.audit_log where entity_type = 'meal_wish' and action = 'plan'
            order by id desc limit 1), 'true', 'the audit row says a meal was replaced');

-- The same dish wished again and planned onto the same meal: one meal carries one wish.
select pg_temp.act_as_dev('ipad');
select api.meal_wish_set(pg_temp.id('emma'), null, 'Nudeln');
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_plan(null, %L, '2026-11-02', 'dinner', true) $q$,
  (select id from api.meal_wishes where title = 'Nudeln' and status = 'open'))), null, 'the same dish can be planned again');
select is((select count(*)::int from app.meal_wish w join app.meal_plan_entry e on e.id = w.meal_plan_entry_id
            where e.on_date = '2026-11-02' and e.slot = 'dinner'), 1, 'and the meal carries exactly one wish');
select is((select count(*)::int from app.meal_wish where free_text = 'Nudeln' and status = 'open' and meal_plan_entry_id is null), 1,
  'the wish it carried before is given back, open again');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_plan(null, %L, '2026-11-03', 'lunch') $q$,
  (select id from api.meal_wishes where title = 'Nudeln' and status = 'open'))), null,
  'the previous app''s call plans onto a free slot as before');
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_plan(%L, %L, '2026-11-04', 'dinner', true) $q$,
  pg_temp.id('papa'), (select id from app.meal_wish where free_text = 'Suppe' limit 1))), 'kiosk_forbidden',
  'the wall plans no wishes');

-- ================================================================ the perimeter of the rituals' tables
select pg_temp.act_as_dev('ipad');
select api.table_question_add(pg_temp.id('emma'), 'Welches Tier wärst du gern?');
select pg_temp.act_as_dev('old');
select is((select count(*)::int from app.meal_wish), 0, 'a revoked device reads no wishes');
select is((select count(*)::int from app.table_question), 0, 'nor table questions');
select is((select count(*)::int from api.meal_wishes), 0, 'nor through the view');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, null, 'Eis') $q$, pg_temp.id('emma'))),
  'device_revoked', 'and writes none');
select pg_temp.act_as_dev('b');
select is((select count(*)::int from app.meal_wish), 0, 'another household reads none of our wishes');
select is((select count(*)::int from app.table_question), 0, 'nor our table questions');
reset role;
set local role anon;
select is(pg_temp.error_state('select count(*) from app.meal_wish'), '42501', 'anonymous callers read no wishes');
select is(pg_temp.error_state('select count(*) from app.table_question'), '42501', 'nor table questions');
reset role;
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_state(format($q$ insert into app.meal_wish (household_id, profile_id, free_text)
  values (%L, %L, 'Eis') $q$, pg_temp.id('hh_a'), pg_temp.id('emma'))), '42501', 'no wish is written past the api');
select is(pg_temp.error_state($q$ update app.meal_wish set status = 'planned' $q$), '42501', 'nor changed');
select is(pg_temp.error_state($q$ delete from app.meal_wish $q$), '42501', 'nor deleted');
select is(pg_temp.error_state(format($q$ insert into app.table_question (household_id, text)
  values (%L, 'Na?') $q$, pg_temp.id('hh_a'))), '42501', 'no question is written past the api');
select is(pg_temp.error_state($q$ update app.table_question set text = 'Na?' $q$), '42501', 'nor changed');
select is(pg_temp.error_state($q$ delete from app.table_question $q$), '42501', 'nor deleted');

-- ================================================================ Wochenrückblick: the order of highlights
-- Week W (Monday 12 October): Emma's chain reaches 7 days, Paul's goes from 8 to 10 and he
-- redeems a reward. Week W2 (Monday 5 October): Emma's wish is eaten and she did every chore of
-- a day; Papa's name is on a meal that no wish of his ever was.
reset role;
insert into app.task_definition (household_id, title, kind, points, assignment, assignee_profile_ids)
values (pg_temp.id('hh_a'), 'Zähne putzen', 'duty', 1, 'fixed', array[pg_temp.id('emma')]),
       (pg_temp.id('hh_a'), 'Blumen gießen', 'duty', 1, 'fixed', array[pg_temp.id('paul')]);
insert into ids select 'teeth', id from app.task_definition where title = 'Zähne putzen';
insert into ids select 'plants', id from app.task_definition where title = 'Blumen gießen';
insert into app.task_instance (household_id, definition_id, title, points, kind, due_on, opens_on, closes_on,
                               assigned_profile_id, status)
select pg_temp.id('hh_a'), pg_temp.id(def), 'x', 1, 'duty', d, d, d, pg_temp.id(who), 'done'
  from (values ('teeth', 'emma', date '2026-10-12'), ('teeth', 'emma', date '2026-10-13'),
               ('plants', 'paul', date '2026-10-12'), ('plants', 'paul', date '2026-10-13'),
               ('teeth', 'emma', date '2026-10-06')) v(def, who, d);
insert into app.streak (household_id, profile_id, definition_id, current_length, longest_length, last_completed_on)
values (pg_temp.id('hh_a'), pg_temp.id('emma'), pg_temp.id('teeth'), 8, 8, '2026-10-13'),
       (pg_temp.id('hh_a'), pg_temp.id('paul'), pg_temp.id('plants'), 10, 10, '2026-10-13');
insert into app.reward (household_id, title, cost_points) values (pg_temp.id('hh_a'), 'Kino', 10);
insert into app.reward_redemption (household_id, reward_id, profile_id, cost_points, status, decided_at)
  select pg_temp.id('hh_a'), r.id, pg_temp.id('paul'), 10, 'approved', '2026-10-14 12:00+00'
    from app.reward r where r.title = 'Kino';
insert into app.meal_plan_entry (household_id, on_date, slot, free_text, wished_by_profile_id)
values (pg_temp.id('hh_a'), '2026-10-07', 'dinner', 'Pfannkuchen', pg_temp.id('emma')),
       (pg_temp.id('hh_a'), '2026-10-08', 'dinner', 'Suppe', pg_temp.id('papa'));
insert into app.meal_wish (household_id, profile_id, free_text, status, meal_plan_entry_id)
  select pg_temp.id('hh_a'), pg_temp.id('emma'), 'Pfannkuchen', 'planned', e.id
    from app.meal_plan_entry e where e.on_date = '2026-10-07' and e.household_id = pg_temp.id('hh_a');
-- Next week, which has not happened yet: Emma's wish is planned for its Monday.
create temp table nw as
  select ((now() at time zone 'Europe/Berlin')::date
          - (extract(isodow from (now() at time zone 'Europe/Berlin')::date)::int - 1) + 7) as monday;
grant all on nw to public;
insert into app.meal_plan_entry (household_id, on_date, slot, free_text, wished_by_profile_id)
  select pg_temp.id('hh_a'), monday, 'lunch', 'Waffeln', pg_temp.id('emma') from nw;
insert into app.meal_wish (household_id, profile_id, free_text, status, meal_plan_entry_id)
  select pg_temp.id('hh_a'), pg_temp.id('emma'), 'Waffeln', 'planned', e.id
    from app.meal_plan_entry e join nw on e.on_date = nw.monday and e.slot = 'lunch'
   where e.household_id = pg_temp.id('hh_a');

select pg_temp.act_as_dev('papa');
create temp table wr as
  select 'w' as week, api.week_review('2026-10-12') r
  union all select 'w2', api.week_review('2026-10-07')
  union all select 'next', api.week_review((select monday from nw));
grant all on wr to public;
create function pg_temp.kind(p_week text, p_who text) returns text language sql as $$
  select m -> 'highlight' ->> 'kind' from wr, jsonb_array_elements(r -> 'members') m
   where wr.week = p_week and m ->> 'profile_id' = pg_temp.id(p_who)::text
$$;
select is(pg_temp.kind('w', 'emma'), 'streak', 'a chain that reached seven days this week is a highlight');
select is(pg_temp.kind('w', 'paul'), 'reward', 'one that only grew past seven is not; the reward comes next');
select is(pg_temp.kind('w2', 'emma'), 'wish', 'a wish eaten comes before a day with every chore done');
select is(pg_temp.kind('w2', 'papa'), 'here', 'a name on a meal that no wish put there is not a wish');
select isnt(pg_temp.kind('next', 'emma'), 'wish', 'a wish not eaten yet is not a highlight yet');
select is((select r ->> 'week_start' from wr where week = 'w2'), '2026-10-05', 'any day of a week reviews that week');
select is((select count(*)::int from wr, jsonb_array_elements(r -> 'members') m, jsonb_each(m -> 'highlight') kv
            where jsonb_typeof(kv.value) = 'number' or kv.key not in ('kind', 'title', 'icon_key')), 0,
  'no member''s line carries a number, in any week (P10)');

-- ================================================================ Wochenrückblick: who may read it
select pg_temp.act_as_dev('kiosk');
select is((select jsonb_array_length(api.week_review('2026-10-12') -> 'members')), 3,
  'the wall reads the look-back for its tile');
select pg_temp.act_as_dev('old');
select is(pg_temp.error_hint($q$ select api.week_review('2026-10-12') $q$), 'not_allowed',
  'a revoked device reads no look-back');
select pg_temp.act_as_dev('b');
select is((select count(*)::int from jsonb_array_elements(api.week_review('2026-10-12') -> 'members') m
            where (m ->> 'profile_id')::uuid in (pg_temp.id('papa'), pg_temp.id('emma'), pg_temp.id('paul'))), 0,
  'another household''s look-back holds none of our members');
reset role;
set local role anon;
select is(pg_temp.error_state($q$ select api.week_review('2026-10-12') $q$), '42501',
  'anonymous callers read no look-back');
reset role;

select * from finish();
rollback;
