begin;
select plan(23);

-- Meal history and the meals behind shopping items (FR-3.8, FR-3.7). Relative dates, so the
-- suite passes on any day. Starts from an empty system, all rolled back.
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;

create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- A day relative to the database clock: day(-3) is three days ago.
create function pg_temp.day(p_offset int) returns text language sql stable as $$
  select to_char(current_date + p_offset, 'YYYY-MM-DD')
$$;

-- ---- household A (Papa), household B and a revoked phone of A, made by hand ----------------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;

insert into users values
  ('phone_b', app.create_auth_user('b@example.org', 'longpassword1')),
  ('old', app.create_auth_user('old@example.org', 'longpassword1'));
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (select id from ids where name = 'hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = (select id from ids where name = 'papa');
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into app.profile (household_id, display_name, role, auth_user_id)
  select (select id from ids where name = 'hh_b'), 'B', 'guardian', usr from users where name = 'phone_b';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (select id from ids where name = 'hh_b'), u.usr, 'B-Phone', 'personal', 'adult', p.id
    from users u join app.profile p on p.auth_user_id = u.usr where u.name = 'phone_b';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  select (select id from ids where name = 'hh_a'), usr, 'Old-Phone', 'personal', 'adult',
         (select id from ids where name = 'papa'), now()
    from users where name = 'old';

insert into devs
  select 'papa', d.auth_user_id, d.id, d.household_id, 'personal' from app.device d where d.label = 'A-Phone'
  union all
  select 'b', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'phone_b'
  union all
  select 'old', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'old';

-- ---- meals (Papa) ---------------------------------------------------------------------------------
select pg_temp.act_as_dev('papa');

insert into ids select 'lasagne', (api.recipe_save(null, '{"title":"Lasagne","servings_default":4}'::jsonb) ->> 'id')::uuid;
insert into ids select 'gulasch', (api.recipe_save(null, jsonb_build_object('title', 'Gulasch', 'servings_default', 4,
  'ingredients', jsonb_build_array(jsonb_build_object('raw_name', 'Rindfleisch', 'quantity', '500', 'unit', 'g'))))
  ->> 'id')::uuid;

-- Recipe-linked Lasagne on days -10 and -40; free-text "Lasagne" (no recipe) on day -50.
insert into ids select 'l10', (api.meal_set(null, jsonb_build_object('on_date', pg_temp.day(-10), 'slot', 'dinner',
  'recipe_id', (select id from ids where name = 'lasagne')))->> 'id')::uuid;
insert into ids select 'l40', (api.meal_set(null, jsonb_build_object('on_date', pg_temp.day(-40), 'slot', 'dinner',
  'recipe_id', (select id from ids where name = 'lasagne')))->> 'id')::uuid;
insert into ids select 'l50', (api.meal_set(null, jsonb_build_object('on_date', pg_temp.day(-50), 'slot', 'lunch',
  'free_text', 'Lasagne'))->> 'id')::uuid;
-- Free text: "  PIZZA  " on day -30 and "Pizza" on day -3: one meal, the latest spelling names it.
insert into ids select 'p30', (api.meal_set(null, jsonb_build_object('on_date', pg_temp.day(-30), 'slot', 'lunch',
  'free_text', '  PIZZA  '))->> 'id')::uuid;
insert into ids select 'p3', (api.meal_set(null, jsonb_build_object('on_date', pg_temp.day(-3), 'slot', 'dinner',
  'free_text', 'Pizza'))->> 'id')::uuid;
-- Planned for the future (day +5 and the Gulasch of day +6): not cooked yet.
insert into ids select 'zukunft', (api.meal_set(null, jsonb_build_object('on_date', pg_temp.day(5), 'slot', 'dinner',
  'free_text', 'Zukunftsessen'))->> 'id')::uuid;
insert into ids select 'gulasch_meal', (api.meal_set(null, jsonb_build_object('on_date', pg_temp.day(6), 'slot', 'dinner',
  'recipe_id', (select id from ids where name = 'gulasch')))->> 'id')::uuid;
-- Older than 365 days: out of the window.
insert into ids select 'alt', (api.meal_set(null, jsonb_build_object('on_date', pg_temp.day(-400), 'slot', 'dinner',
  'free_text', 'Altes Rezept'))->> 'id')::uuid;
-- An eating correction on a slot without a meal: a row with neither recipe nor text.
select lives_ok($$ select api.meal_eating_set(null, current_date - 1, 'dinner',
  (select id from ids where name = 'papa'), false) $$, 'an eating correction can create a slot without a meal');

-- ---- meal history --------------------------------------------------------------------------------
select is((select count(*)::int from api.meal_history), 3,
  'history holds the cooked meals: Lasagne (recipe), Lasagne (text), Pizza');
select is((select times from api.meal_history where recipe_id = (select id from ids where name = 'lasagne')),
  2, 'the recipe-linked Lasagne is counted twice');
select is((select last_on from api.meal_history where recipe_id = (select id from ids where name = 'lasagne')),
  current_date - 10, 'the recipe-linked Lasagne was last cooked ten days ago');
select is((select first_on from api.meal_history where recipe_id = (select id from ids where name = 'lasagne')),
  current_date - 40, 'the recipe-linked Lasagne was first cooked forty days ago');
select is((select title from api.meal_history where recipe_id = (select id from ids where name = 'lasagne')),
  'Lasagne', 'a recipe meal is named by its recipe');
select is((select count(*)::int from api.meal_history where lower(btrim(title)) = 'lasagne'), 2,
  'free-text Lasagne is a separate meal from the recipe');
select is((select times from api.meal_history where recipe_id is null and lower(btrim(title)) = 'pizza'), 2,
  'free text is grouped ignoring case and surrounding spaces');
select is((select title from api.meal_history where recipe_id is null and lower(btrim(title)) = 'pizza'), 'Pizza',
  'the most recent spelling names the free-text meal');
select is((select last_on from api.meal_history where recipe_id is null and lower(btrim(title)) = 'pizza'),
  current_date - 3, 'the free-text meal was last cooked three days ago');
select is((select count(*)::int from api.meal_history where title in ('Zukunftsessen', 'Gulasch', 'Altes Rezept')), 0,
  'a future plan and a meal older than a year are not history');

-- ---- meals behind a shopping item ----------------------------------------------------------------
select is(api.meal_shopping_generate(null, pg_temp.day(6)::date, pg_temp.day(6)::date, (
  select array_agg(x ->> 'key') from jsonb_array_elements(api.meal_shopping_preview(null, pg_temp.day(6)::date, pg_temp.day(6)::date)) x
   where x ->> 'name' = 'Rindfleisch')) ->> 'added', '1',
  'a generated Gulasch line is added to the list');
insert into ids select 'rind', id from api.shopping_items where name = 'Rindfleisch';

select is((select count(*)::int from api.shopping_item_meals where item_id = (select id from ids where name = 'rind')),
  1, 'the generated item maps to its meal');
select is((select title from api.shopping_item_meals where item_id = (select id from ids where name = 'rind')),
  'Gulasch', 'the item names its meal');
select is((select slot from api.shopping_item_meals where item_id = (select id from ids where name = 'rind')),
  'dinner', 'the item shows the slot of its meal');
select is((select on_date from api.shopping_item_meals where item_id = (select id from ids where name = 'rind')),
  current_date + 6, 'the item shows the day of its meal');

-- A meal that is gone leaves a stale id behind on the item; the view skips it.
reset role;
update app.shopping_item set source_meal_entry_ids = source_meal_entry_ids || gen_random_uuid()
 where id = (select id from ids where name = 'rind');
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from api.shopping_item_meals where item_id = (select id from ids where name = 'rind')),
  1, 'the view skips a stale meal id');

-- ---- another household -----------------------------------------------------------------------------
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.meal_history), 0, 'another household sees no meal history');
select is((select count(*)::int from api.shopping_item_meals), 0, 'another household sees no shopping meals');

-- ---- a revoked phone ---------------------------------------------------------------------------------
select pg_temp.act_as_dev('old');
select is((select count(*)::int from api.meal_history), 0, 'a revoked phone reads no meal history');
select is((select count(*)::int from api.shopping_item_meals), 0, 'a revoked phone reads no shopping meals');

-- ---- anonymous callers -------------------------------------------------------------------------------
reset role;
set local role anon;
select throws_ok('select count(*) from api.meal_history', '42501', 'permission denied for view meal_history',
  'anonymous callers read no meal history');
select throws_ok('select count(*) from api.shopping_item_meals', '42501', 'permission denied for view shopping_item_meals',
  'anonymous callers read no shopping meals');
reset role;

select * from finish();
rollback;
