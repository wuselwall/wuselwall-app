begin;
select plan(57);


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
insert into ids select 'dev_' || name, dev from devs;

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
-- A wishable recipe in A and one in B.
insert into app.recipe (household_id, title) values (pg_temp.id('hh_a'), 'Pfannkuchen'), (pg_temp.id('hh_b'), 'Fremdes Rezept');
insert into ids select 'pancakes', id from app.recipe where title = 'Pfannkuchen';
insert into ids select 'foreign_recipe', id from app.recipe where title = 'Fremdes Rezept';

-- ================================================================ birthdays (specs/27)
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, p_birthday => '2017-03-09') $q$,
  pg_temp.id('emma'), pg_temp.id('emma'))), null, 'a member sets their own birthday');
select is((select birthday from api.members where id = pg_temp.id('emma')), date '2017-03-09', 'the birthday is visible');
select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, p_birthday => '2017-03-09') $q$,
  pg_temp.id('emma'), pg_temp.id('paul'))), 'guardian_required', 'nobody else''s birthday without a guardian');
select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, p_birthday => '2017-02-30') $q$,
  pg_temp.id('emma'), pg_temp.id('emma'))), 'birthday_invalid', 'an impossible date is refused');
select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, p_birthday => '2999-01-01') $q$,
  pg_temp.id('emma'), pg_temp.id('emma'))), 'birthday_invalid', 'a birthday in the future is refused');
select ok((select diff ->> 'birthday' = 'set' and not (diff::text like '%2017%') from app.audit_log
            where entity_id = pg_temp.id('emma') and action = 'update' order by id desc limit 1),
  'the audit row says the birthday was set, not the date');
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($q$ select api.member_update(null, %L, p_birthday => '') $q$, pg_temp.id('paul'))),
  null, 'a guardian clears a birthday with the empty string');
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.members where id = pg_temp.id('emma')), 0, 'another household sees no birthday of ours');

-- ================================================================ events: flags and traditions
select pg_temp.act_as_dev('papa');
create temp table ev as select api.event_save(null, jsonb_build_object(
  'title', 'Spieleabend', 'kind', 'appointment', 'is_all_day', false,
  'starts_at', '2026-10-30T18:00:00Z', 'ends_at', '2026-10-30T20:00:00Z', 'rrule', 'FREQ=WEEKLY',
  'importance', 'normal', 'tradition', true, 'icon_key', 'game_die', 'countdown', true,
  'tradition_meal', jsonb_build_object('slot', 'dinner', 'free_text', 'Pizza'))) r;
grant all on ev to public;
insert into ids select 'game_night', (r ->> 'id')::uuid from ev;
select is((select importance || ' ' || icon_key || ' ' || countdown || ' ' || tradition from api.events where id = pg_temp.id('game_night')),
  'key game_die true true', 'a tradition is a key appointment with its icon and flags');
select is((select tradition_meal ->> 'title' from api.events where id = pg_temp.id('game_night')), 'Pizza', 'the tradition carries its meal');
select is(pg_temp.error_hint(format($q$ select api.event_save(null, jsonb_build_object('id', %L, 'title', 'Spieleabend',
  'kind', 'appointment', 'is_all_day', false, 'starts_at', '2026-10-30T18:00:00Z', 'ends_at', '2026-10-30T20:00:00Z',
  'rrule', 'FREQ=WEEKLY')) $q$, pg_temp.id('game_night'))), null, 'an older app saves without the new keys');
select is((select icon_key || ' ' || countdown || ' ' || tradition from api.events where id = pg_temp.id('game_night')),
  'game_die true true', 'and the flags it did not send are kept');
select is(pg_temp.error_hint(format($q$ select api.event_save(null, jsonb_build_object('id', %L, 'title', 'Spieleabend',
  'kind', 'appointment', 'is_all_day', false, 'starts_at', '2026-10-30T18:00:00Z', 'ends_at', '2026-10-30T20:00:00Z',
  'icon_key', 'Game Die!')) $q$, pg_temp.id('game_night'))), 'event_invalid', 'an icon is a plain key');
select is(pg_temp.error_hint(format($q$ select api.event_save(null, jsonb_build_object('id', %L, 'title', 'Spieleabend',
  'kind', 'appointment', 'is_all_day', false, 'starts_at', '2026-10-30T18:00:00Z', 'ends_at', '2026-10-30T20:00:00Z',
  'tradition_meal', jsonb_build_object('slot', 'dinner', 'recipe_id', %L))) $q$,
  pg_temp.id('game_night'), pg_temp.id('foreign_recipe'))), 'event_invalid', 'a tradition meal cannot name another household''s recipe');
select is(pg_temp.error_hint(format($q$ select api.event_save(null, jsonb_build_object('id', %L, 'title', 'Spieleabend',
  'kind', 'appointment', 'is_all_day', false, 'starts_at', '2026-10-30T18:00:00Z', 'ends_at', '2026-10-30T20:00:00Z',
  'tradition', false)) $q$, pg_temp.id('game_night'))), null, 'a tradition can be ended');
select is((select (tradition_meal is null)::text || ' ' || tradition from api.events where id = pg_temp.id('game_night')),
  'true false', 'and its meal goes with it');
select ok(exists (select 1 from app.audit_log where entity_id = pg_temp.id('game_night') and action = 'flags'),
  'the flags are audited');
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.error_hint(format($q$ select api.event_save(%L, '{"title":"x","kind":"appointment","is_all_day":true,"start_date":"2026-11-01","end_date":"2026-11-01","tradition":true}') $q$, pg_temp.id('emma'))),
  'kiosk_forbidden', 'the wall saves no events, traditions included');
select pg_temp.act_as_dev('b');
select is((select count(*)::int from app.tradition_meal), 0, 'another household reads no tradition meals of ours');

-- ================================================================ Wunschessen
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, %L) $q$, pg_temp.id('emma'), pg_temp.id('pancakes'))),
  null, 'a child wishes a recipe');
select is((select title || ' ' || status from api.meal_wishes where profile_id = pg_temp.id('emma')), 'Pfannkuchen open',
  'the wish waits, open');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, null, 'Pizza', 'pizza') $q$, pg_temp.id('emma'))),
  null, 'a second wish within the limit of one replaces the first');
select is((select string_agg(title, ',') from api.meal_wishes where profile_id = pg_temp.id('emma')), 'Pizza',
  'one open wish per child: the newest');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, null, 'Steak') $q$, pg_temp.id('paul'))),
  'wishes_off', 'by default only children wish');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, %L) $q$, pg_temp.id('emma'), pg_temp.id('foreign_recipe'))),
  'wish_invalid', 'a wish cannot name another household''s recipe');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, %L, 'Both') $q$, pg_temp.id('emma'), pg_temp.id('pancakes'))),
  'wish_invalid', 'a recipe or words, not both');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_withdraw(%L, (select id from api.meal_wishes where profile_id = %L)) $q$,
  pg_temp.id('paul'), pg_temp.id('emma'))), 'guardian_required', 'only the wisher or a guardian withdraws a wish');

select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_plan(null, (select id from api.meal_wishes where profile_id = %L), '2026-10-29', 'dinner') $q$,
  pg_temp.id('emma'))), null, 'a guardian puts the wish on the plan');
select is((select title || ' ' || (wished_by_profile_id = pg_temp.id('emma'))::text from api.meal_plan_entries where on_date = '2026-10-29' and slot = 'dinner'),
  'Pizza true', 'the meal is the wish and carries the wisher');
select is((select status from app.meal_wish where profile_id = pg_temp.id('emma')), 'planned', 'the wish is planned');
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, null, 'Eis') $q$, pg_temp.id('emma'))),
  'kiosk_forbidden', 'the wall takes no wishes');
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.meal_wishes), 0, 'another household sees no wishes of ours');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_withdraw(null, (select id from app.meal_wish limit 1)) $q$)),
  'wish_not_found', 'nor withdraws them');

-- ================================================================ Tischfrage
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($q$ select api.table_question_add(%L, 'Welches Tier wärst du gern?') $q$, pg_temp.id('emma'))),
  null, 'a child adds a question of their own');
select is((select created_by_profile_id = pg_temp.id('emma') from api.table_questions where text is not null), true,
  'it shows who asked');
select is(pg_temp.error_hint(format($q$ select api.table_question_add(%L, '   ') $q$, pg_temp.id('emma'))),
  'question_invalid', 'a blank question is refused');
select is(pg_temp.error_hint(format($q$ select api.table_question_hide(%L, 'de:q-0001') $q$, pg_temp.id('emma'))),
  'guardian_required', 'hiding a bundled question is a guardian''s');
select is(pg_temp.error_hint(format($q$ select api.table_question_remove(%L, (select id from api.table_questions where text is not null)) $q$,
  pg_temp.id('paul'))), 'guardian_required', 'only the author or a guardian removes a question');
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint($q$ select api.table_question_hide(null, 'de:q-0001') $q$), null, 'a guardian hides a bundled question');
select is(pg_temp.error_hint($q$ select api.table_question_hide(null, 'de:q-0001') $q$), null, 'hiding twice is harmless');
select is((select count(*)::int from api.table_questions where hidden_key = 'de:q-0001'), 1, 'and keeps one row');
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.table_questions), 0, 'another household sees none of our questions');

-- ================================================================ Wochenrückblick
select pg_temp.act_as_dev('papa');
create temp table wr as select api.week_review('2026-10-26') r;
grant all on wr to public;
select is((select jsonb_array_length(r -> 'members') from wr), 3, 'every active member has exactly one line');
select is((select count(*)::int from wr, jsonb_array_elements(r -> 'members') m, jsonb_each(m -> 'highlight') kv
            where jsonb_typeof(kv.value) = 'number'), 0,
  'no member''s line carries a number another line could be compared with');
select is((select m -> 'highlight' ->> 'kind' from wr, jsonb_array_elements(r -> 'members') m
            where m ->> 'profile_id' = pg_temp.id('emma')::text), 'wish', 'Emma''s wish was on the table');
select is((select jsonb_typeof(r -> 'chores_done') from wr), 'number', 'the family''s chores are one number, the family''s');
select is((select count(*)::int from wr, jsonb_array_elements(r -> 'meals') x where (x ->> 'wished_by_profile_id') is not null), 1,
  'the wished meal is marked');

-- ---- the star follows the dish (review findings 1 and 2) ----
select pg_temp.act_as_dev('ipad');
select api.meal_wish_set(pg_temp.id('emma'), pg_temp.id('pancakes'));
select is((select free_text from app.meal_wish where profile_id = pg_temp.id('emma') and status = 'open'),
  'Pfannkuchen', 'a recipe wish keeps the recipe''s title as words');
select pg_temp.act_as_dev('papa');
select api.meal_wish_plan(null, (select id from api.meal_wishes where profile_id = pg_temp.id('emma') and status = 'open'),
  '2026-10-30', 'dinner');
select api.meal_move(null, '2026-10-29', 'dinner', '2026-10-30', 'dinner');
select is((select string_agg(on_date || ':' || coalesce(wished_by_profile_id = pg_temp.id('emma'), false)::text, ',' order by on_date)
             from app.meal_plan_entry where on_date in ('2026-10-29', '2026-10-30') and slot = 'dinner'),
  '2026-10-29:true,2026-10-30:true', 'a swap keeps both meals'' stars');
select is((select count(*)::int from app.meal_wish where profile_id = pg_temp.id('emma') and status = 'planned'), 2,
  'and both wishes stay planned');
select api.meal_set(null, jsonb_build_object('on_date', '2026-10-30', 'slot', 'dinner', 'free_text', 'Suppe'));
select is((select wished_by_profile_id from app.meal_plan_entry where on_date = '2026-10-30' and slot = 'dinner'), null,
  'another dish on that meal takes the star off');
select is((select count(*)::int from app.meal_wish where profile_id = pg_temp.id('emma') and status = 'open'), 1,
  'and gives the wish back to the child, open again');
select api.meal_clear(null, '2026-10-29', 'dinner');
select is((select count(*)::int from app.meal_wish where profile_id = pg_temp.id('emma') and status = 'open'), 2,
  'clearing a wished meal gives its wish back too');
select is(pg_temp.error_hint(format($q$ select api.recipe_delete(null, %L) $q$, pg_temp.id('pancakes'))), null,
  'a recipe someone wished for can still be deleted');
select ok(exists (select 1 from api.meal_wishes where profile_id = pg_temp.id('emma') and recipe_id is null
                   and title = 'Pfannkuchen'), 'and the wish keeps its words');
select ok(exists (select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
                   where c.relname = 'profile' and t.tgname = 'profile_broadcast'
                     and pg_get_triggerdef(t.oid) like '%birthday%'),
  'a birthday change wakes the other screens');
-- An older app saves a tradition without the flag and with its own importance.
select api.event_save(null, jsonb_build_object('title', 'Pizza', 'kind', 'appointment', 'is_all_day', true,
  'start_date', '2026-11-06', 'end_date', '2026-11-06', 'tradition', true));
select api.event_save(null, jsonb_build_object('id', (select id from api.events where title = 'Pizza'), 'title', 'Pizza',
  'kind', 'appointment', 'is_all_day', true, 'start_date', '2026-11-06', 'end_date', '2026-11-06', 'importance', 'normal'));
select is((select importance from api.events where title = 'Pizza'), 'key', 'a tradition stays on the board when an older app saves it');


select * from finish();
rollback;
