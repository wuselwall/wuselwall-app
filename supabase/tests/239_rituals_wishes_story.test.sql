begin;
select plan(50);

-- Wunschessen's remaining pieces (migration 20261025130000): dish pictures from a name, the
-- recipes' and favourites' pictures, a wish's icon, "von letzter Woche", wishes ageing out of
-- the tray and the limit after four weeks, grown-ups wishing when the family says everyone, and
-- the perimeter of what changed.

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

-- ================================================================ dish pictures from a name
select is(app.meal_icon_for('Pfannkuchen'), 'pancakes', 'a dish by its whole name');
select is(app.meal_icon_for('Spaghetti Bolognese'), 'pasta', 'the first word that is a dish');
select is(app.meal_icon_for('Gemüsesuppe'), 'soup', 'a German compound by the dish it ends with');
select is(app.meal_icon_for('Kartoffelsalat'), 'salad', 'the dish a compound ends with, not the one it starts with');
select is(app.meal_icon_for('Apfelpfannkuchen'), 'pancakes', 'the longest known word it ends with');
select is(app.meal_icon_for('Milchreis'), 'porridge', 'a whole word before a word it ends with');
select is(app.meal_icon_for('Chili sin Carne'), 'soup', 'the first matching word wins');
select is(app.meal_icon_for('Hot Dog'), 'hotdog', 'a dish of two words by the whole name');
select is(app.meal_icon_for('Crêpes au sucre'), 'pancakes', 'French, accents folded');
select is(app.meal_icon_for('Paella valenciana'), 'paella', 'Spanish');
select is(app.meal_icon_for('Fish and chips'), 'fish', 'English');
select is(app.meal_icon_for('Eis'), 'ice_cream', 'a short word as a whole word');
select is(app.meal_icon_for('Bastelei'), null, 'but a short word is no ending: Bastelei is no egg');
select is(app.meal_icon_for('Bauklötze'), null, 'no picture for what is no dish');
select is(app.meal_icon_for(null), null, 'nor for no name');

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

-- ================================================================ the recipes' and favourites' pictures
insert into app.recipe (household_id, title) values (pg_temp.id('hh_a'), 'Pizza Margherita');
insert into ids select 'pizza', id from app.recipe where title = 'Pizza Margherita';
insert into app.meal_plan_entry (household_id, on_date, slot, free_text)
values (pg_temp.id('hh_a'), current_date - 3, 'dinner', 'Fischstäbchen mit Kartoffelbrei');

select pg_temp.act_as_dev('papa');
select is((select icon_key from api.recipes where id = pg_temp.id('pizza')), 'pizza', 'a recipe has a picture');
select is((select icon_key from api.meal_history where title like 'Fischst%'), 'fish',
  'and so has a meal the family cooked');

-- ================================================================ a wish's icon
select pg_temp.act_as_dev('ipad');
select api.meal_wish_set(pg_temp.id('emma'), null, 'Pfannkuchen');
select is((select icon_key from api.meal_wishes where profile_id = pg_temp.id('emma')), 'pancakes',
  'a wish without an icon gets one from its words');
select api.meal_wish_set(pg_temp.id('emma'), null, 'Omas Spezial', 'cake');
select is((select icon_key || ' ' || title from api.meal_wishes where profile_id = pg_temp.id('emma')),
  'cake Omas Spezial', 'an icon chosen in the picker is kept');
select api.meal_wish_set(pg_temp.id('emma'), pg_temp.id('pizza'));
select is((select icon_key || ' ' || title from api.meal_wishes where profile_id = pg_temp.id('emma')),
  'pizza Pizza Margherita', 'a recipe wish shows the recipe''s picture');
select is((select earlier_week from api.meal_wishes where profile_id = pg_temp.id('emma')), false,
  'a wish made this week is not from last week');
select is((select wished_on from api.meal_wishes where profile_id = pg_temp.id('emma')),
  (now() at time zone 'Europe/Berlin')::date, 'it was made today, in the household''s time zone');

-- ================================================================ "von letzter Woche"
reset role;
-- Wishes age by the household's calendar, not by elapsed hours: "29 days ago" is a time on the
-- household day 29 days before today. now() - interval '29 days' is not that: across a daylight
-- saving change it can land on the day 28 days back (run at 23:01 in Berlin within four weeks
-- after the autumn change, 29 times 24 hours earlier is 00:01 a day later). So fixtures name the day.
create function pg_temp.days_ago(p_days int, p_time time default '12:00') returns timestamptz
language sql as $$
  select (((now() at time zone 'Europe/Berlin')::date - p_days) + p_time) at time zone 'Europe/Berlin'
$$;
update app.meal_wish set created_at = pg_temp.days_ago(8), updated_at = pg_temp.days_ago(8)
 where profile_id = pg_temp.id('emma');
select pg_temp.act_as_dev('ipad');
select is((select earlier_week from api.meal_wishes where profile_id = pg_temp.id('emma')), true,
  'a wish not planned in its week stays, marked as from an earlier week');
select is((select status from api.meal_wishes where profile_id = pg_temp.id('emma')), 'open', 'still open');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, null, 'Waffeln', p_wish => %L) $q$,
  pg_temp.id('emma'), (select id from api.meal_wishes where profile_id = pg_temp.id('emma')))), null,
  'the child changes it');
select is((select earlier_week::text || ' ' || title from api.meal_wishes where profile_id = pg_temp.id('emma')),
  'false Waffeln', 'and a changed wish is this week''s again');

-- ================================================================ ageing: four weeks
reset role;
update app.meal_wish set created_at = pg_temp.days_ago(27), updated_at = pg_temp.days_ago(27)
 where profile_id = pg_temp.id('emma');
select pg_temp.act_as_dev('ipad');
select is((select count(*)::int from api.meal_wishes where profile_id = pg_temp.id('emma')), 1,
  'a wish of 27 days ago is still in the tray');
-- The edges are calendar days: early on the day 28 days back is still current, late on the day
-- before is not, however many hours either is from now.
reset role;
update app.meal_wish set created_at = pg_temp.days_ago(28, '00:00:30'), updated_at = pg_temp.days_ago(28, '00:00:30')
 where profile_id = pg_temp.id('emma');
select pg_temp.act_as_dev('ipad');
select is((select count(*)::int from api.meal_wishes where profile_id = pg_temp.id('emma')), 1,
  'a wish from early on the day four weeks ago is still in the tray');
reset role;
update app.meal_wish set created_at = pg_temp.days_ago(29, '23:59:30'), updated_at = pg_temp.days_ago(29, '23:59:30')
 where profile_id = pg_temp.id('emma');
select pg_temp.act_as_dev('ipad');
select is((select count(*)::int from api.meal_wishes where profile_id = pg_temp.id('emma')), 0,
  'one from late on the day before has dropped out');
reset role;
update app.meal_wish set created_at = pg_temp.days_ago(29), updated_at = pg_temp.days_ago(29)
 where profile_id = pg_temp.id('emma');
select pg_temp.act_as_dev('ipad');
select is((select count(*)::int from api.meal_wishes where profile_id = pg_temp.id('emma')), 0,
  'one of 29 days ago has dropped out');
select is((select status from app.meal_wish where profile_id = pg_temp.id('emma')), 'open',
  'its row stays as it was: nothing records that it was not cooked');
-- The default limit is one open wish: the aged one does not count, so a new wish is made.
select api.meal_wish_set(pg_temp.id('emma'), null, 'Lasagne');
select is((select string_agg(title, ',') from api.meal_wishes where profile_id = pg_temp.id('emma')), 'Lasagne',
  'a new wish after an aged one is a new wish');
select is((select count(*)::int from app.meal_wish where profile_id = pg_temp.id('emma') and free_text = 'Waffeln'), 1,
  'and the aged one was not changed into it');
select api.meal_wish_set(pg_temp.id('emma'), null, 'Gulasch');
select is((select string_agg(title, ',') from api.meal_wishes where profile_id = pg_temp.id('emma')), 'Gulasch',
  'at the limit the newest current wish changes, as before');
select is((select count(*)::int from app.meal_wish where profile_id = pg_temp.id('emma') and status = 'open'), 2,
  'one current and one aged row, never two current at a limit of one');

-- A planned wish stays visible until a week after its meal, as before.
select pg_temp.act_as_dev('papa');
select api.meal_wish_plan(null, (select id from api.meal_wishes where title = 'Gulasch'),
  (now() at time zone 'Europe/Berlin')::date + 1, 'dinner');
select is((select status from api.meal_wishes where title = 'Gulasch'), 'planned', 'a planned wish shows as planned');
select is((select earlier_week from api.meal_wishes where title = 'Gulasch'), false,
  'and is never marked as from an earlier week');

-- ================================================================ grown-ups wishing (meals.wishes)
select is(pg_temp.error_hint($q$ select api.meal_wish_set(null, null, 'Steak') $q$), 'wishes_off',
  'by default a grown-up does not wish');
reset role;
insert into app.household_setting (household_id, key, value) values (pg_temp.id('hh_a'), 'meals.wishes', '"everyone"');
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint($q$ select api.meal_wish_set(null, null, 'Steak') $q$), null,
  'with everyone a grown-up wishes from their own phone');
select is((select icon_key from api.meal_wishes where profile_id = pg_temp.id('papa')), 'meat',
  'with the same pictures');
select is((select actor_profile_id from app.audit_log where entity_type = 'meal_wish' and action = 'create'
            order by id desc limit 1), pg_temp.id('papa'), 'and the audit row names them');
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.error_hint(format($q$ select api.meal_wish_set(%L, null, 'Eis') $q$, pg_temp.id('paul'))),
  'kiosk_forbidden', 'the wall wishes for nobody');
reset role;
update app.household_setting set value = '"off"' where household_id = pg_temp.id('hh_a') and key = 'meals.wishes';
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint($q$ select api.meal_wish_set(null, null, 'Steak') $q$), 'wishes_off',
  'with wishes off a grown-up does not wish either');

-- ================================================================ the perimeter of what changed
select pg_temp.act_as_dev('old');
select is((select count(*)::int from api.meal_wishes), 0, 'a revoked device reads no wishes');
select is((select count(*)::int from api.recipes), 0, 'nor recipes with their pictures');
select is((select count(*)::int from api.meal_history), 0, 'nor the meals cooked');
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.meal_wishes), 0, 'another household reads none of our wishes');
select is((select count(*)::int from api.recipes), 0, 'nor our recipes');
reset role;
set local role anon;
select is(pg_temp.error_state('select count(*) from api.meal_wishes'), '42501', 'anonymous callers read no wishes');
select is(pg_temp.error_state('select count(*) from api.recipes'), '42501', 'nor recipes');
reset role;

select * from finish();
rollback;
