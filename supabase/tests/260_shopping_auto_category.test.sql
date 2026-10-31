begin;
select plan(17);

-- Snacks in the supermarket walk, and categories picked by a dictionary (issue #195).
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

create temp table a as select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'A', '#111111', '123456') r;
grant all on a to public;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (a.r ->> 'household_id')::uuid, p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
  from a join app.profile p on p.id = (a.r ->> 'profile_id')::uuid;

create temp table ctx as
  select (r ->> 'household_id')::uuid hh, p.auth_user_id usr, d.id dev
  from a join app.profile p on p.id = (a.r ->> 'profile_id')::uuid join app.device d on d.profile_id = p.id;
grant all on ctx to public;

-- The dictionary, as the migration owner (before the role switch).
select is((app.catalog_category_keys_for(app.fold('Bananen')))[1], 'produce', 'Bananen belong to produce');
select is((app.catalog_category_keys_for(app.fold('Chips')))[1], 'snacks', 'Chips are snacks first');
select is((app.catalog_category_keys_for(app.fold('Tiefkühlpizza')))[1], 'frozen', 'a Tiefkühl prefix puts frozen first, whatever the icon says');
select is((app.catalog_category_keys_for(app.fold('Zahnpasta')))[1], 'care', 'Zahnpasta is care, not pantry');
select is((app.catalog_category_keys_for(app.fold('Haferflocken')))[1], 'pantry', 'the word list wins over the icon (a bowl is not dairy)');
select is((app.catalog_category_keys_for(app.fold('Müsliriegel')))[1], 'snacks', 'a compound without an icon: Müsliriegel');
select is(app.catalog_category_keys_for('xyzzy'), array[]::text[], 'an unknown name has no keys');

select pg_temp.act_as((select usr from ctx), jsonb_build_object(
  'household_id', (select hh from ctx), 'device_id', (select dev from ctx), 'device_class', 'personal'));

-- A new supermarket list has snacks right after the pantry, numbered 0, 10, 20 …
select api.shopping_add_item(null, 'Bananen');
select is((select array_agg(key order by sort_order) from api.shopping_categories
            where list_id = (select id from api.shopping_lists where is_default)),
  array['produce', 'bakery', 'dairy', 'meat_fish', 'pantry', 'snacks', 'frozen', 'drinks', 'household', 'other'],
  'snacks follows the pantry in a new supermarket list');
select is((select array_agg(sort_order order by sort_order) from api.shopping_categories
            where list_id = (select id from api.shopping_lists where is_default)),
  array[0, 10, 20, 30, 40, 50, 60, 70, 80, 90], 'the walk is numbered in tens');

-- An item without a category gets the dictionary's.
select is((select c.key from api.shopping_items i join api.shopping_categories c on c.id = i.category_id
            where i.name = 'Bananen'), 'produce', 'a new item lands in its category');

create temp table lists as select api.shopping_list_create(null, 'Drogerie', 'drugstore') drug;
grant all on lists to public;
select api.shopping_add_item(null, 'Zahnpasta', null, (select drug from lists));
select api.shopping_add_item(null, 'Zahnpasta');
select is((select c.key from api.shopping_items i join api.shopping_categories c on c.id = i.category_id
            where i.name = 'Zahnpasta' and i.list_id = (select drug from lists)), 'care',
  'on a drugstore list Zahnpasta is care');
select is((select c.key from api.shopping_items i join api.shopping_categories c on c.id = i.category_id
            where i.name = 'Zahnpasta' and i.list_id <> (select drug from lists)), 'household',
  'a supermarket has no care aisle: the next candidate, household');

-- Buying teaches the catalogue; a missing category on the item is inferred there.
select api.shopping_add_item(null, 'Mehl');
select api.shopping_set_category(null, (select id from api.shopping_items where name = 'Mehl'), null);
select api.shopping_toggle_item(null, (select id from api.shopping_items where name = 'Mehl'));
select api.shopping_toggle_item(null, (select id from api.shopping_items where name = 'Bananen'));
select api.shopping_finish(null);
select is((select c.key from api.shopping_catalog k join api.shopping_categories c on c.id = k.category_id
            where k.name = 'Mehl'), 'pantry', 'a new catalogue entry gets the inferred category');

-- What the family chose for a catalogue entry wins over the dictionary.
select api.catalog_item_update(null, (select id from api.shopping_catalog where name = 'Bananen'), null,
  (select c.id from api.shopping_categories c where c.key = 'bakery'
      and c.list_id = (select list_id from api.shopping_catalog where name = 'Bananen')));
select api.shopping_add_item(null, 'Bananen');
select is((select c.key from api.shopping_items i join api.shopping_categories c on c.id = i.category_id
            where i.name = 'Bananen'), 'bakery', 'the family''s category on the catalogue entry is kept');

-- The offline outbox's add gets the same rule.
select api.shopping_apply(null, jsonb_build_array(jsonb_build_object(
  'op_id', gen_random_uuid(), 'kind', 'add', 'item_id', gen_random_uuid(), 'name', 'Chips')));
select is((select c.key from api.shopping_items i join api.shopping_categories c on c.id = i.category_id
            where i.name = 'Chips'), 'snacks', 'an add through shopping_apply is categorised too');

-- The helpers are internal.
select is(has_function_privilege('authenticated', 'app.catalog_category_keys_for(text)', 'execute'), false,
  'authenticated cannot call the dictionary');
select is(has_function_privilege('authenticated', 'app.shopping_category_for(uuid, text)', 'execute'), false,
  'authenticated cannot call the picker');

select * from finish();
rollback;
