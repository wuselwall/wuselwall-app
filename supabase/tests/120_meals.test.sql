begin;
select plan(51);

-- Meals (M1.4, specs/07 "Meal Plan" and the seam to shopping). Start from an empty system,
-- whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

-- Named things of the test: households and profiles (ids), devices and users (devs, users).
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

-- ---- household A: Papa (guardian, phone), Lotta (child), Hanna (adult member) ------------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;
insert into app.profile (household_id, display_name, role, kind)
  values ((select id from ids where name = 'hh_a'), 'Lotta', 'member', 'child');
insert into app.profile (household_id, display_name, role)
  values ((select id from ids where name = 'hh_a'), 'Hanna', 'member');
insert into ids select lower(p.display_name), p.id from app.profile p
 where p.household_id = (select id from ids where name = 'hh_a') and p.display_name in ('Lotta', 'Hanna');

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

-- ---- household B, made by hand (setup closes after the first household) ---------------------------
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

-- ---- recipes (Papa) -------------------------------------------------------------------------------
select pg_temp.act_as_dev('papa');

insert into ids select 'lasagne', (api.recipe_save(null, jsonb_build_object(
  'title', 'Lasagne', 'servings_default', 4, 'steps', 'Schichten, backen.',
  'ingredients', jsonb_build_array(
    jsonb_build_object('raw_name', 'Hackfleisch', 'quantity', '500', 'unit', 'g'),
    jsonb_build_object('raw_name', 'Milch', 'quantity', '0.5', 'unit', 'l'),
    jsonb_build_object('raw_name', 'Salz'),
    jsonb_build_object('raw_name', 'Zucker', 'quantity', '1', 'unit', 'Prise')))) ->> 'id')::uuid;

select is((select count(*)::int from api.recipe_ingredients where recipe_id = (select id from ids where name = 'lasagne')),
  4, 'a recipe is saved with its ingredients');

select lives_ok($$ select api.recipe_save(null, jsonb_build_object(
  'id', (select id from ids where name = 'lasagne'), 'title', 'Lasagne', 'servings_default', 4,
  'ingredients', jsonb_build_array(
    jsonb_build_object('raw_name', 'Hackfleisch', 'quantity', '500', 'unit', 'g'),
    jsonb_build_object('raw_name', 'Milch', 'quantity', '0,5', 'unit', 'l'),
    jsonb_build_object('raw_name', 'Salz')))) $$, 'a second save with the id replaces the ingredients');
select is((select count(*)::int from api.recipe_ingredients where recipe_id = (select id from ids where name = 'lasagne')),
  3, 'the second save leaves the three ingredients it sent');
select is((select count(*)::int from api.recipe_ingredients where raw_name = 'Zucker'), 0,
  'an ingredient left out of the second save is gone');

insert into ids select 'bolognese', (api.recipe_save(null, jsonb_build_object(
  'title', 'Bolognese', 'servings_default', 4,
  'ingredients', jsonb_build_array(
    jsonb_build_object('raw_name', 'Hackfleisch', 'quantity', '500', 'unit', 'g'),
    jsonb_build_object('raw_name', 'Zwiebeln', 'quantity', '1.33')))) ->> 'id')::uuid;

-- Children may not write recipes; a kiosk may not write anything of this kind.
select pg_temp.act_as_dev('ipad');
select throws_ok($$ select api.recipe_save((select id from ids where name = 'lotta'), '{"title":"Kekse"}'::jsonb) $$,
  '42501', 'guardian required', 'a child may not save a recipe');
select pg_temp.act_as_dev('kiosk');
select throws_ok($$ select api.recipe_save((select id from ids where name = 'hanna'), '{"title":"Nein"}'::jsonb) $$,
  '42501', 'not allowed on a kiosk', 'a kiosk may not save a recipe');

-- ---- meals (Papa) ---------------------------------------------------------------------------------
select pg_temp.act_as_dev('papa');

insert into ids select 'pizza', (api.meal_set(null,
  '{"on_date":"2026-10-13","slot":"dinner","free_text":"Pizza"}'::jsonb) ->> 'id')::uuid;
select is((select title from api.meal_plan_entries where id = (select id from ids where name = 'pizza')),
  'Pizza', 'a meal can be free text');
select is(api.meal_set(null, '{"on_date":"2026-10-13","slot":"dinner","free_text":"Pasta"}'::jsonb) ->> 'id',
  (select id::text from ids where name = 'pizza'), 'a set on the same date and slot updates the entry');
select is((select title from api.meal_plan_entries where on_date = '2026-10-13' and slot = 'dinner'),
  'Pasta', 'the update changes the title');
select throws_ok($$ select api.meal_set(null, jsonb_build_object('on_date', '2026-10-13', 'slot', 'lunch',
  'free_text', 'Brot', 'recipe_id', (select id from ids where name = 'lasagne'))) $$,
  '22023', 'WW-MEAL-001 meal invalid', 'a meal is a recipe or free text, not both');

insert into ids select 'lasagne_meal', (api.meal_set(null, jsonb_build_object(
  'on_date', '2026-10-14', 'slot', 'dinner', 'recipe_id', (select id from ids where name = 'lasagne'),
  'servings', 6, 'cook_profile_id', (select id from ids where name = 'papa'),
  'at_time', '18:30', 'guests', 2)) ->> 'id')::uuid;
insert into ids select 'bolo_meal', (api.meal_set(null, jsonb_build_object(
  'on_date', '2026-10-15', 'slot', 'dinner', 'recipe_id', (select id from ids where name = 'bolognese'),
  'servings', 4)) ->> 'id')::uuid;
insert into ids select 'brot', (api.meal_set(null,
  '{"on_date":"2026-10-16","slot":"lunch","free_text":"Brot"}'::jsonb) ->> 'id')::uuid;

select is((select title from api.meal_plan_entries where id = (select id from ids where name = 'lasagne_meal')),
  'Lasagne', 'a meal can be a recipe, which names it');
select is((select count(*)::int from api.meal_plan_entries where on_date between '2026-10-13' and '2026-10-16'),
  4, 'the week holds the four meals');

-- ---- moving and clearing --------------------------------------------------------------------------
select lives_ok($$ select api.meal_move(null, '2026-10-16', 'lunch', '2026-10-17', 'lunch') $$,
  'a meal moves to an empty slot');
select is((select title from api.meal_plan_entries where on_date = '2026-10-17' and slot = 'lunch'),
  'Brot', 'the moved meal is in its new slot');
select is((select count(*)::int from api.meal_plan_entries where on_date = '2026-10-16' and slot = 'lunch'),
  0, 'the old slot is empty after the move');

select lives_ok($$ select api.meal_move(null, '2026-10-17', 'lunch', '2026-10-13', 'dinner') $$,
  'a meal dropped on an occupied slot swaps with it');
select is((select title from api.meal_plan_entries where on_date = '2026-10-13' and slot = 'dinner'),
  'Brot', 'the dropped meal takes the occupied slot');
select is((select title from api.meal_plan_entries where on_date = '2026-10-17' and slot = 'lunch'),
  'Pasta', 'the displaced meal takes the old slot');

select lives_ok($$ select api.meal_clear(null, '2026-10-17', 'lunch') $$, 'a meal can be cleared');
select is((select count(*)::int from api.meal_plan_entries where on_date = '2026-10-17' and slot = 'lunch'),
  0, 'a cleared slot is empty');

-- ---- eating corrections on the kiosk --------------------------------------------------------------
select pg_temp.act_as_dev('kiosk');
select lives_ok($$ select api.meal_eating_set((select id from ids where name = 'hanna'), '2026-10-14', 'dinner',
  (select id from ids where name = 'lotta'), false) $$,
  'a kiosk corrects who is eating, with an acting profile');
select is((select eating_overrides ->> (select id::text from ids where name = 'lotta')
             from api.meal_plan_entries where on_date = '2026-10-14' and slot = 'dinner'),
  'false', 'the correction is stored as an override');
select lives_ok($$ select api.meal_eating_set((select id from ids where name = 'hanna'), '2026-10-14', 'dinner',
  (select id from ids where name = 'lotta'), null) $$, 'a null correction removes the override');
select is((select count(*)::int from jsonb_object_keys((select eating_overrides from api.meal_plan_entries
             where on_date = '2026-10-14' and slot = 'dinner'))),
  0, 'no override is left after the removal');

-- ---- the shopping seam (Papa) ---------------------------------------------------------------------
select pg_temp.act_as_dev('papa');
insert into ids select 'milch_item', api.shopping_add_item(null, 'Milch');

create temp table prev as select api.meal_shopping_preview(null, '2026-10-14', '2026-10-15') r;
grant all on prev to public;

select is((select jsonb_array_length(r) from prev), 4,
  'the preview has one line per ingredient and unit, shared ones once');
select is((select (x ->> 'quantity')::numeric from prev, jsonb_array_elements(r) x where x ->> 'name' = 'Hackfleisch'),
  1250::numeric, 'shared ingredients add up across meals, scaled by servings (750 + 500)');
select is((select (x ->> 'quantity')::numeric from prev, jsonb_array_elements(r) x where x ->> 'name' = 'Milch'),
  0.8::numeric, 'liquids round up to a tenth (0.75 l becomes 0.8)');
select is((select (x ->> 'quantity')::numeric from prev, jsonb_array_elements(r) x where x ->> 'name' = 'Zwiebeln'),
  2::numeric, 'a piece count rounds up to a whole number (1.33 becomes 2)');
select is((select (x ->> 'already_on_list')::boolean from prev, jsonb_array_elements(r) x where x ->> 'name' = 'Milch'),
  true, 'a line already on the default list is flagged');
select is((select jsonb_array_length(x -> 'meal_entry_ids') from prev, jsonb_array_elements(r) x where x ->> 'name' = 'Hackfleisch'),
  2, 'a line names the meals it comes from');

-- Generate only the chosen lines: Hackfleisch and Zwiebeln, not Milch or Salz.
create temp table chosen as
  select array_agg(x ->> 'key') ks from prev, jsonb_array_elements(r) x where x ->> 'name' in ('Hackfleisch', 'Zwiebeln');
grant all on chosen to public;
create temp table gen1 as
  select api.meal_shopping_generate(null, '2026-10-14', '2026-10-15', (select ks from chosen)) r;
grant all on gen1 to public;

select is((select (r ->> 'added')::int from gen1), 2, 'only the chosen lines are added');
select is((select quantity from api.shopping_items where name = 'Hackfleisch'), '1250 g',
  'a generated item carries its quantity as text');
select is((select quantity from api.shopping_items where name = 'Zwiebeln'), '2',
  'a generated piece count is written without a unit');
select is((select count from api.shopping_items where name = 'Milch'), 1,
  'a line that was not chosen is not added');
select is((select cardinality(source_meal_entry_ids) from api.shopping_items where name = 'Hackfleisch'), 2,
  'a generated item names the meals behind it');
select is((select (api.meal_shopping_generate(null, '2026-10-14', '2026-10-15', (select ks from chosen)) ->> 'added')::int),
  0, 'a second run adds nothing');
select is((select count(*)::int from api.meal_plan_entries
            where on_date between '2026-10-14' and '2026-10-15' and shopping_generated_at is not null),
  2, 'the meals used are stamped');
select is((select jsonb_array_length(api.meal_shopping_preview(null, '2026-10-14', '2026-10-15'))),
  0, 'a stamped range previews nothing');

-- api.shopping_items keeps every column it had and appends the meal source.
reset role;
select is((select array_agg(column_name::text order by ordinal_position) from information_schema.columns
            where table_schema = 'api' and table_name = 'shopping_items'),
  array['id', 'name', 'quantity', 'checked', 'added_by', 'checked_by', 'checked_at', 'created_at',
        'list_id', 'category_id', 'count', 'catalog_item_id', 'source_meal_entry_ids'],
  'api.shopping_items keeps its columns and appends the meal source');

select ok(exists (select 1 from app.audit_log where entity_type = 'recipe' and action = 'create'
                  and household_id = (select id from ids where name = 'hh_a')),
  'recipe writes are audited');
select ok(exists (select 1 from app.audit_log where entity_type = 'meal_plan_entry' and action = 'eating'
                  and household_id = (select id from ids where name = 'hh_a')),
  'meal corrections are audited');
select ok(exists (select 1 from app.audit_log where entity_type = 'shopping_list' and action = 'meal_generate'
                  and household_id = (select id from ids where name = 'hh_a')),
  'generated shopping is audited');

-- ---- another household ----------------------------------------------------------------------------
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.recipes) + (select count(*)::int from api.recipe_ingredients)
          + (select count(*)::int from api.meal_plan_entries), 0,
  'another household sees no recipes, ingredients or meals');
select is((select jsonb_array_length(api.meal_shopping_preview(null, '2026-10-14', '2026-10-15'))), 0,
  'another household previews none of them');
select throws_ok($$ select api.meal_set(null, jsonb_build_object('on_date', '2026-10-20', 'slot', 'dinner',
  'recipe_id', (select id from ids where name = 'lasagne'))) $$,
  '22023', 'WW-MEAL-001 meal invalid', 'another household cannot cook a foreign recipe');
select throws_ok($$ select api.meal_set(null, jsonb_build_object('on_date', '2026-10-20', 'slot', 'dinner',
  'free_text', 'Suppe', 'cook_profile_id', (select id from ids where name = 'papa'))) $$,
  '22023', 'WW-MEAL-001 meal invalid', 'another household cannot name a foreign cook');
select throws_ok($$ select api.recipe_delete(null, (select id from ids where name = 'lasagne')) $$,
  'P0002', 'recipe not found', 'another household cannot delete a foreign recipe');

-- ---- a revoked phone ------------------------------------------------------------------------------
select pg_temp.act_as_dev('old');
select is((select count(*)::int from api.meal_plan_entries), 0, 'a revoked phone reads no meals');
select throws_ok($$ select api.meal_set(null, '{"on_date":"2026-10-20","slot":"dinner","free_text":"Alt"}'::jsonb) $$,
  '42501', 'device not usable', 'a revoked phone cannot set a meal');

-- ---- anonymous callers ----------------------------------------------------------------------------
reset role;
set local role anon;
select throws_ok('select count(*) from api.recipes', '42501', 'permission denied for view recipes',
  'anonymous callers read no recipes');
select throws_ok($$ select api.meal_set(null, '{}'::jsonb) $$, '42501', 'permission denied for function meal_set',
  'anonymous callers cannot set meals');
reset role;

select * from finish();
rollback;
