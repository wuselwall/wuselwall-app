begin;
select plan(38);

-- Custom categories match by name, the auto flag, pinned tiles, merged quantities (issue #195, round 2).
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

-- Household B: one guardian's phone.
insert into app.household (name) values ('B');
create temp table b as
  select h.id hh, app.create_auth_user('b@example.org', 'longpassword1') usr from app.household h where h.name = 'B';
insert into app.profile (household_id, display_name, role, auth_user_id) select hh, 'B', 'guardian', usr from b;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select b.hh, b.usr, 'B-Phone', 'personal', 'adult', (select id from app.profile where auth_user_id = b.usr) from b;
alter table b add column dev uuid;
update b set dev = (select id from app.device where label = 'B-Phone');
grant all on b to public;

-- ------------------------------------------------------------------ names as keys (owner)

select is(app.shopping_key_for_name('suesses'), 'snacks', '"Süsses" stands for snacks');
select is(app.shopping_key_for_name('sweets'), 'snacks', '"Sweets" stands for snacks');
select is(app.shopping_key_for_name('zebra'), null, 'an unknown name stands for nothing');
-- Every label of the app in all four languages folds to its key.
select is((
  select count(*)::int from (values
    ('produce', array['Obst & Gemüse', 'Fruit & vegetables', 'Fruits et légumes', 'Frutas y verduras']),
    ('bakery', array['Brot & Backwaren', 'Bread & bakery', 'Pain et boulangerie', 'Pan y bollería']),
    ('dairy', array['Milch & Käse', 'Dairy & cheese', 'Produits laitiers et fromages', 'Lácteos y quesos']),
    ('meat_fish', array['Fleisch & Fisch', 'Meat & fish', 'Viande et poisson', 'Carne y pescado']),
    ('pantry', array['Vorrat', 'Pantry', 'Épicerie', 'Despensa']),
    ('snacks', array['Snacks', 'Snacks', 'Snacks', 'Snacks']),
    ('frozen', array['Tiefkühl', 'Frozen', 'Surgelés', 'Congelados']),
    ('drinks', array['Getränke', 'Drinks', 'Boissons', 'Bebidas']),
    ('household', array['Haushalt', 'Household', 'Maison', 'Hogar']),
    ('other', array['Sonstiges', 'Other', 'Autres', 'Otros']),
    ('care', array['Körperpflege', 'Body care', 'Hygiène et soins', 'Cuidado personal']),
    ('baby', array['Baby & Kind', 'Baby & kids', 'Bébés et enfants', 'Bebés y niños']),
    ('cleaning', array['Reinigung', 'Cleaning', 'Entretien', 'Limpieza']),
    ('health', array['Gesundheit', 'Health', 'Santé', 'Salud']),
    ('tools', array['Werkzeug', 'Tools', 'Outils', 'Herramientas']),
    ('screws', array['Schrauben & Befestigung', 'Screws & fixings', 'Vis et fixations', 'Tornillos y fijaciones']),
    ('electrical', array['Elektro', 'Electrical', 'Électricité', 'Electricidad']),
    ('garden', array['Garten', 'Garden', 'Jardin', 'Jardín'])
  ) as t(key, labels), unnest(t.labels) as l(label)
  where app.shopping_key_for_name(app.fold(l.label)) is distinct from t.key), 0,
  'every shoppingCat label of the four languages maps to its key');

select pg_temp.act_as((select usr from ctx), jsonb_build_object(
  'household_id', (select hh from ctx), 'device_id', (select dev from ctx), 'device_class', 'personal'));

select api.shopping_add_item(null, 'Bananen');
create temp table l as select id from api.shopping_lists where is_default;
grant all on l to public;
create temp table cat as
  select api.shopping_category_save(null, (select id from l), null, 'Bio') bio,
         api.shopping_category_save(null, (select id from l), null, 'Süsses') sweet,
         api.shopping_category_save(null, (select id from l), null, 'Zebra') zebra;
grant all on cat to public;

create function pg_temp.cat_of(p_name text) returns text language sql as $$
  select coalesce(c.name, c.key) from api.shopping_items i
    left join api.shopping_categories c on c.id = i.category_id where i.name = p_name
$$;

-- ------------------------------------------------------------------ a custom category named in the item

select api.shopping_add_item(null, 'Bio Äpfel');
select is(pg_temp.cat_of('Bio Äpfel'), 'Bio', 'a custom category named in the item wins over produce');
select api.shopping_add_item(null, 'Bio-Milch');
select is(pg_temp.cat_of('Bio-Milch'), 'Bio', 'a hyphen is a word boundary');
select api.shopping_add_item(null, 'Biokost Tomaten');
select is(pg_temp.cat_of('Biokost Tomaten'), 'produce', 'only a whole word counts');
select api.shopping_add_item(null, 'Mehl');
select is(pg_temp.cat_of('Mehl'), 'pantry', 'a custom category is never picked otherwise');
select api.shopping_add_item(null, 'Xyzzy');
select is((select category_id from api.shopping_items where name = 'Xyzzy'), null, 'an unknown name stays uncategorised');

-- ------------------------------------------------------------------ a custom name that stands for a key

select api.shopping_add_item(null, 'Schokolade');
select is(pg_temp.cat_of('Schokolade'), 'snacks', 'the seeded snacks (earlier in the walk) win over a custom "Süsses"');
select api.shopping_categories_reorder(null, (select id from l), array[(select sweet from cat)]);
select api.shopping_add_item(null, 'Popcorn');
select is(pg_temp.cat_of('Popcorn'), 'Süsses', 'the custom "Süsses" earlier in the walk wins over the seeded snacks');
select api.shopping_category_delete(null, (select id from api.shopping_categories where key = 'snacks' and list_id = (select id from l)));
select api.shopping_add_item(null, 'Chips');
select is(pg_temp.cat_of('Chips'), 'Süsses', 'without a seeded snacks the custom "Süsses" receives snacks');

-- ------------------------------------------------------------------ the auto flag

select is((select category_auto from api.shopping_items where name = 'Bio Äpfel'), true, 'an inferred category is auto');
select is((select category_auto from api.shopping_items where name = 'Xyzzy'), false, 'no category, not auto');
select api.shopping_set_category(null, (select id from api.shopping_items where name = 'Bio Äpfel'),
  (select id from api.shopping_categories where key = 'produce' and list_id = (select id from l)));
select is((select category_auto from api.shopping_items where name = 'Bio Äpfel'), false, 'set_category clears the flag');
select is(pg_temp.cat_of('Bio Äpfel'), 'produce', 'and sets the category');

-- the batch: an add is inferred, a category op is a person
create temp table ids as select gen_random_uuid() nachos, gen_random_uuid() o1, gen_random_uuid() o2, gen_random_uuid() o3;
grant all on ids to public;
create temp table r1 as select api.shopping_apply(null, jsonb_build_array(
  jsonb_build_object('op_id', o1, 'kind', 'add', 'item_id', nachos, 'name', 'Nachos'))) r from ids;
grant all on r1 to public;
select is((select e ->> 'category_auto' from r1, jsonb_array_elements(r1.r -> 'items') e where e ->> 'name' = 'Nachos'),
  'true', 'shopping_apply returns category_auto for an inferred add');
create temp table r2 as select api.shopping_apply(null, jsonb_build_array(
  jsonb_build_object('op_id', o2, 'kind', 'category', 'item_id', nachos,
                     'category_id', (select id from api.shopping_categories where key = 'pantry' and list_id = (select id from l))))) r from ids;
grant all on r2 to public;
select is((select e ->> 'category_auto' from r2, jsonb_array_elements(r2.r -> 'items') e where e ->> 'name' = 'Nachos'),
  'false', 'the category operation clears it');

-- buying carries the flag to the catalogue entry
select api.shopping_toggle_item(null, (select id from api.shopping_items where name = 'Bio Äpfel'));
select api.shopping_toggle_item(null, (select id from api.shopping_items where name = 'Popcorn'));
select api.shopping_finish(null);
select is((select category_auto from api.shopping_catalog where name = 'Popcorn'), true, 'a new entry from an inferred item is auto');
select is((select category_auto from api.shopping_catalog where name = 'Bio Äpfel'), false, 'a new entry from a chosen category is not');
select api.shopping_add_item(null, 'Bio Äpfel');
select is((select category_auto from api.shopping_items where name = 'Bio Äpfel'), false, 'an item from a person-set entry is not auto');
select is(pg_temp.cat_of('Bio Äpfel'), 'produce', 'and takes the entry''s category');
select api.shopping_add_item(null, 'Popcorn');
select is((select category_auto from api.shopping_items where name = 'Popcorn'), true, 'an item from an auto entry is auto');
select api.catalog_item_update(null, (select id from api.shopping_catalog where name = 'Popcorn'), null,
  (select id from api.shopping_categories where key = 'pantry' and list_id = (select id from l)));
select is((select category_auto from api.shopping_catalog where name = 'Popcorn'), false, 'choosing the entry''s category clears its flag');

-- ------------------------------------------------------------------ the views

select is((select column_name::text from information_schema.columns
            where table_schema = 'api' and table_name = 'shopping_items' order by ordinal_position desc limit 1),
  'category_auto', 'category_auto is the last column of api.shopping_items');
select is((select array_agg(column_name::text order by ordinal_position) from information_schema.columns
            where table_schema = 'api' and table_name = 'shopping_catalog' and ordinal_position > 8),
  array['category_auto', 'pinned'], 'api.shopping_catalog ends with category_auto and pinned');

-- ------------------------------------------------------------------ pinned tiles

select is((select pinned from api.shopping_catalog where name = 'Popcorn'), false, 'tiles are not pinned by default');
select api.shopping_catalog_pin(null, (select id from api.shopping_catalog where name = 'Popcorn'), true);
select is((select pinned from api.shopping_catalog where name = 'Popcorn'), true, 'pin pins');
select api.shopping_catalog_pin(null, (select id from api.shopping_catalog where name = 'Popcorn'), false);
select is((select pinned from api.shopping_catalog where name = 'Popcorn'), false, 'pin(false) releases');
reset role;
select is((select array_agg(action order by id) from app.audit_log
            where entity_type = 'catalog_item' and action in ('pin', 'unpin')),
  array['pin', 'unpin'], 'pinning is audited');
create temp table tile as select id from api.shopping_catalog limit 0;
select pg_temp.act_as((select usr from b), jsonb_build_object(
  'household_id', (select hh from b), 'device_id', (select dev from b), 'device_class', 'personal'));
select throws_ok(format($q$select api.shopping_catalog_pin(null, %L, true)$q$,
    (select id from app.catalog_item where name = 'Popcorn' and household_id = (select hh from ctx))),
  'P0002', 'item not found', 'another household cannot pin the entry');
select is((select count(*)::int from api.shopping_catalog), 0, 'another household sees no tiles (RLS)');
select is(has_function_privilege('anon', 'api.shopping_catalog_pin(uuid, uuid, boolean)', 'execute'), false,
  'anon cannot pin');
reset role;
select is((select pinned from app.catalog_item where name = 'Popcorn' and household_id = (select hh from ctx)), false,
  'and nothing changed');

-- ------------------------------------------------------------------ quantities merge

select pg_temp.act_as((select usr from ctx), jsonb_build_object(
  'household_id', (select hh from ctx), 'device_id', (select dev from ctx), 'device_class', 'personal'));
select api.shopping_add_item(null, 'Reis');
select api.shopping_add_item(null, 'Reis', '500 g');
select is((select quantity from api.shopping_items where name = 'Reis'), '500 g', 'merging into an item without quantity sets it');
select api.shopping_add_item(null, 'Reis', '200 g');
select is((select quantity from api.shopping_items where name = 'Reis'), '500 g + 200 g', 'a different quantity is appended');
select api.shopping_add_item(null, 'Reis', '200 g');
select api.shopping_add_item(null, 'Reis');
select is((select quantity from api.shopping_items where name = 'Reis'), '500 g + 200 g', 'the same text twice, or none, changes nothing');
select is((select count from api.shopping_items where name = 'Reis'), 5, 'and every add still counts');

select * from finish();
rollback;
