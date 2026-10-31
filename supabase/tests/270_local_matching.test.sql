begin;
select plan(72);

-- Local matching (specs/29, migration 20261031151000): the layered matcher over the dictionary,
-- the pictures and categories that come from it, and the household's corrections.
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

-- Household A: a guardian on a phone, and Paul, a member on his phone.
create temp table a as select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'A', '#111111', '123456') r;
grant all on a to public;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (a.r ->> 'household_id')::uuid, p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
  from a join app.profile p on p.id = (a.r ->> 'profile_id')::uuid;
create temp table ctx as
  select (r ->> 'household_id')::uuid hh, p.auth_user_id usr, d.id dev, p.id prof
  from a join app.profile p on p.id = (a.r ->> 'profile_id')::uuid join app.device d on d.profile_id = p.id;
grant all on ctx to public;

create temp table paul as
  select ctx.hh, app.create_auth_user('paul@example.org', 'longpassword1') usr from ctx;
insert into app.profile (household_id, display_name, role, auth_user_id) select hh, 'Paul', 'member', usr from paul;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select paul.hh, paul.usr, 'Paul-Phone', 'personal', 'adult', (select id from app.profile where auth_user_id = paul.usr) from paul;
alter table paul add column dev uuid;
update paul set dev = (select id from app.device where label = 'Paul-Phone');
grant all on paul to public;

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

-- ------------------------------------------------------------------ the edit distance (owner)

select is(app.damerau_levenshtein('tomtaen', 'tomaten', 2), 1, 'swapping two neighbours costs one');
select is(app.damerau_levenshtein('kitten', 'sitting', 3), 3, 'insert, delete and replace cost one each');
select is(app.damerau_levenshtein('abc', 'xyz', 1), 2, 'over the maximum it answers max + 1');
select is(app.damerau_levenshtein('', 'abc', 5), 3, 'against nothing it is the length');
select is(app.damerau_levenshtein('milch', 'milch', 0), 0, 'equal strings are 0 apart');

-- ------------------------------------------------------------------ the layers (owner)

select is(app.match_normalize('Jus d''orange  -  WC-Papier'), 'jus d orange wc papier',
  'normalising folds and turns every run of other characters into one space');

create function pg_temp.m(p_domain text, p_text text) returns text language sql as $$
  select key || ' ' || layer || ' ' || matched from app.match_dictionary(p_domain, p_text)
$$;

select is(pg_temp.m('shopping', 'Crème fraîche'), 'milk phrase creme fraiche', 'phrase: the whole text is a dictionary word');
select is(pg_temp.m('shopping', 'orange juice'), 'juice phrase orange juice', 'orange juice is juice');
select is(pg_temp.m('shopping', 'cold orange juice'), 'juice word orange juice', 'word: the longest run of words that is one');
select is(app.match_key('shopping', 'jus d''orange'), 'juice', 'jus d''orange is juice, not orange');
select is(pg_temp.m('shopping', 'jus d orange frais'), 'juice word jus d orange', 'word: French, the head first');
select is(pg_temp.m('shopping', 'zumo de naranja natural'), 'juice word zumo de naranja', 'word: Spanish');
select is(app.match_key('shopping', 'zumo de naranja'), 'juice', 'zumo de naranja is juice, not orange');
select is(app.match_key('shopping', 'milch tomaten'), 'tomato', 'without a connector the last word is the head');
select is(app.match_key('shopping', 'milch mit tomaten'), 'milk', 'with a connector the first word is the head');
select is(pg_temp.m('shopping', '2 liter milch'), 'milk word milch', 'a number names nothing');
select is(app.match_key('shopping', '123'), null, 'a text of only digits matches nothing');
select is(app.match_key('shopping', 'Tomates'), 'tomato', 'Tomates are tomatoes');
select is(pg_temp.m('shopping', 'tomatens'), 'tomato stem tomaten', 'stem: an ending removed');
select is(pg_temp.m('shopping', 'Bio-Vollmilch'), 'milk word vollmilch', 'a hyphen separates words');
select is(pg_temp.m('shopping', 'alpenvollmilch'), 'milk compound vollmilch', 'compound: the word ends with a dictionary word');
select is(pg_temp.m('shopping', 'Vollmilch'), 'milk phrase vollmilch', 'Vollmilch is milk');
select is(pg_temp.m('shopping', 'tomatten'), 'tomato fuzzy tomaten', 'fuzzy: one typo');
select is(app.match_key('shopping', 'Brokoli'), 'broccoli', 'Brokoli is broccoli');
select is(pg_temp.m('shopping', 'frisch'), null, 'a stopword is never fuzzed (frisch is not fisch)');
select is((select count(*)::int from app.match_dictionary('shopping', 'Gänseblümchen')), 0, 'an unknown name matches nothing');
select is(app.match_key('shopping', ''), null, 'nor does an empty one');
select is(app.match_key('shopping', null), null, 'nor a null');
select is(app.match_key('nowhere', 'milch'), null, 'nor a domain without words');
select is(app.match_key('meals', 'Pizza'), 'pizza', 'the meals domain has its own words');

-- ------------------------------------------------------------------ category-only (@) words

select is(app.catalog_icon_for('silikon'), null::text, 'a category-only word has no picture');
select is((app.catalog_category_keys_for('silikon'))[1], 'tools', 'but it has a category');
select is(app.catalog_category_keys_for('tiefkuehlpizza'), array['frozen']::text[], 'the frozen prefix first, without repeating it');
select is((app.catalog_category_keys_for('tk-spinat'))[1], 'frozen', 'TK- is frozen too');
select is(app.catalog_category_keys_for('schokolade'), array['snacks', 'pantry']::text[], 'the categories come most likely first');

-- ------------------------------------------------------------------ dish pictures follow the title (owner)

insert into app.recipe (household_id, title) select hh, 'Pizza' from ctx;
select is((select icon_key from app.recipe where title = 'Pizza'), 'pizza', 'a new recipe has its picture');
update app.recipe set title = 'Gemüsesuppe' where title = 'Pizza';
select is((select icon_key from app.recipe where title = 'Gemüsesuppe'), 'soup', 'renaming the recipe changes the picture');
update app.recipe set title = 'Bauklötze' where title = 'Gemüsesuppe';
select is((select icon_key from app.recipe where title = 'Bauklötze'), null::text, 'and drops it when the name is no dish');
insert into app.meal_plan_entry (household_id, on_date, slot, free_text) select hh, current_date, 'dinner', 'Pfannkuchen' from ctx;
select is((select icon_key from app.meal_plan_entry where free_text = 'Pfannkuchen'), 'pancakes', 'a planned meal has its picture');
update app.meal_plan_entry set free_text = 'Hot Dog' where free_text = 'Pfannkuchen';
select is((select icon_key from app.meal_plan_entry where free_text = 'Hot Dog'), 'hotdog', 'and follows its text');

-- ------------------------------------------------------------------ categories by list (guardian)

select pg_temp.act_as((select usr from ctx), jsonb_build_object(
  'household_id', (select hh from ctx), 'device_id', (select dev from ctx), 'device_class', 'personal'));

create temp table lists as
  select api.shopping_list_create(null, 'Werkstatt', 'hardware') hw,
         api.shopping_list_create(null, 'Zweiter', 'supermarket') l2,
         api.shopping_list_create(null, 'Dritter', 'supermarket') l3,
         api.shopping_list_create(null, 'Vierter', 'supermarket') l4;
alter table lists add column l1 uuid;
update lists set l1 = (select id from api.shopping_lists where is_default);
grant all on lists to public;

create function pg_temp.cat_of(p_name text, p_list uuid) returns text language sql as $$
  select c.key from api.shopping_items i
    left join api.shopping_categories c on c.id = i.category_id
   where i.name = p_name and i.list_id = p_list
$$;

select api.shopping_add_item(null, 'Hammer', null, (select hw from lists));
select api.shopping_add_item(null, 'Hammer', null, (select l1 from lists));
select is(pg_temp.cat_of('Hammer', (select hw from lists)), 'tools', 'on a hardware list a Hammer lands in tools');
select is((select category_id from api.shopping_items where name = 'Hammer' and list_id = (select l1 from lists)), null,
  'on a supermarket list it gets no category');

-- ------------------------------------------------------------------ the household's corrections

select api.shopping_add_item(null, 'Bananen', null, (select l1 from lists));
select is(pg_temp.cat_of('Bananen', (select l1 from lists)), 'produce', 'Bananen start in produce');
select is((select count(*)::int from api.match_corrections), 0, 'nothing is learned from the dictionary');
select api.shopping_set_category(null, (select id from api.shopping_items where name = 'Bananen'),
  (select id from api.shopping_categories where key = 'bakery' and list_id = (select l1 from lists)));
select is((select text || '|' || folded_text || '|' || key || '|' || domain from api.match_corrections),
  'Bananen|bananen|bakery|shopping_category', 'choosing a category teaches it (name, folded name, key)');
select is((select set_by from api.match_corrections), (select prof from ctx), 'by whom');
select api.shopping_add_item(null, 'bananen', null, (select l2 from lists));
select is(pg_temp.cat_of('bananen', (select l2 from lists)), 'bakery',
  'on another supermarket list the correction beats the dictionary');
select api.shopping_add_item(null, 'Bananen', null, (select hw from lists));
select is((select category_id from api.shopping_items where name = 'Bananen' and list_id = (select hw from lists)), null,
  'a list without that category gets none');

-- the same name chosen again is one row
select api.shopping_set_category(null, (select id from api.shopping_items where name = 'Bananen' and list_id = (select l1 from lists)),
  (select id from api.shopping_categories where key = 'snacks' and list_id = (select l1 from lists)));
select is((select array_agg(key) from api.match_corrections), array['snacks'], 'a second choice for a name replaces the first');

-- no category forgets the name
select api.shopping_set_category(null, (select id from api.shopping_items where name = 'Bananen' and list_id = (select l1 from lists)), null);
select is((select count(*)::int from api.match_corrections), 0, 'clearing the category forgets the name');
select api.shopping_add_item(null, 'Bananen', null, (select l3 from lists));
select is(pg_temp.cat_of('Bananen', (select l3 from lists)), 'produce', 'and the dictionary answers again');

-- the catalogue entry's category
select api.shopping_add_item(null, 'Mehl', null, (select l1 from lists));
select api.shopping_toggle_item(null, (select id from api.shopping_items where name = 'Mehl'));
select api.shopping_finish(null);
select api.catalog_item_update(null, (select id from api.shopping_catalog where name = 'Mehl'), null,
  (select id from api.shopping_categories where key = 'household' and list_id = (select l1 from lists)));
select is((select text || '|' || key from api.match_corrections), 'Mehl|household',
  'a category chosen for a catalogue entry is learned too');
select api.shopping_add_item(null, 'Mehl', null, (select l2 from lists));
select is(pg_temp.cat_of('Mehl', (select l2 from lists)), 'household', 'and used on the next list');

-- a custom category named like a seeded one
create temp table cat as
  select api.shopping_category_save(null, (select l1 from lists), null, 'Süsses') sweet,
         api.shopping_category_save(null, (select l1 from lists), null, 'Zebra') zebra;
grant all on cat to public;
select api.shopping_add_item(null, 'Gummibärchen', null, (select l1 from lists));
select api.shopping_set_category(null, (select id from api.shopping_items where name = 'Gummibärchen'), (select sweet from cat));
select is((select key from api.match_corrections where text = 'Gummibärchen'), 'snacks',
  'a custom category named like a seeded one teaches the seeded key');
select api.shopping_add_item(null, 'Xyzzy', null, (select l1 from lists));
select api.shopping_set_category(null, (select id from api.shopping_items where name = 'Xyzzy'), (select zebra from cat));
select is((select count(*)::int from api.match_corrections where text = 'Xyzzy'), 0, 'a custom category of an unknown name teaches nothing');
create temp table cat2 as select api.shopping_category_save(null, (select l2 from lists), null, 'Zebra') zebra;
grant all on cat2 to public;
select api.shopping_set_category(null, (select id from api.shopping_items where name = 'Mehl' and list_id = (select l2 from lists)), (select zebra from cat2));
select is((select count(*)::int from api.match_corrections where text = 'Mehl'), 0,
  'and replaces an older lesson for that name');

-- ------------------------------------------------------------------ forgetting

select api.shopping_set_category(null, (select id from api.shopping_items where name = 'Bananen' and list_id = (select l1 from lists)), null);
select api.shopping_set_category(null, (select id from api.shopping_items where name = 'Bananen' and list_id = (select l1 from lists)),
  (select id from api.shopping_categories where key = 'bakery' and list_id = (select l1 from lists)));
create temp table lesson as select id from api.match_corrections where text = 'Bananen';
grant all on lesson to public;
select is((select count(*)::int from lesson), 1, 'Bananen are learned again');

select pg_temp.act_as((select usr from paul), jsonb_build_object(
  'household_id', (select hh from paul), 'device_id', (select dev from paul), 'device_class', 'personal'));
select is((select count(*)::int from api.match_corrections where text = 'Bananen'), 1, 'any member sees the lessons');
select is(pg_temp.error_hint(format($q$select api.match_correction_forget(null, %L)$q$, (select id from lesson))),
  'guardian_required', 'a member who is no guardian cannot forget');

select pg_temp.act_as((select usr from b), jsonb_build_object(
  'household_id', (select hh from b), 'device_id', (select dev from b), 'device_class', 'personal'));
select is((select count(*)::int from api.match_corrections), 0, 'another household sees no lessons (RLS)');
select is(pg_temp.error_hint(format($q$select api.match_correction_forget(null, %L)$q$, (select id from lesson))),
  'correction_not_found', 'and cannot forget them');

select pg_temp.act_as((select usr from ctx), jsonb_build_object(
  'household_id', (select hh from ctx), 'device_id', (select dev from ctx), 'device_class', 'personal'));
select api.match_correction_forget(null, (select id from lesson));
select is((select count(*)::int from api.match_corrections where text = 'Bananen'), 0, 'a guardian forgets a lesson');
select api.shopping_add_item(null, 'Bananen', null, (select l4 from lists));
select is(pg_temp.cat_of('Bananen', (select l4 from lists)), 'produce', 'and the dictionary answers on the next add');
select is(pg_temp.error_hint(format($q$select api.match_correction_forget(null, %L)$q$, (select id from lesson))),
  'correction_not_found', 'forgetting a lesson twice says so');
reset role;
select is((select count(*)::int from app.audit_log where entity_type = 'match_correction' and action = 'forget'), 1,
  'forgetting is audited');

-- ------------------------------------------------------------------ the perimeter

select is((select count(*)::int from app.export_table where name = 'match_correction'), 1, 'the export carries the lessons');
select is((select bool_and(has_function_privilege('authenticated', f, 'execute'))
             from unnest(array[
               'app.match_normalize(text)', 'app.damerau_levenshtein(text, text, int)',
               'app.match_dictionary(text, text)', 'app.match_key(text, text)',
               'app.shopping_correction_save(app.actor_t, text, text, uuid)',
               'app.recipe_icon()', 'app.meal_plan_entry_icon()']) f), false,
  'authenticated cannot call the matcher or the writers');
select is(has_function_privilege('authenticated', 'api.match_correction_forget(uuid, uuid)', 'execute'), true, 'a signed-in person can forget');
select is(has_function_privilege('anon', 'api.match_correction_forget(uuid, uuid)', 'execute'), false, 'anon cannot');
select is((select array_agg(c.relname::text order by c.relname) from pg_class c
            where c.oid in ('app.match_word'::regclass, 'app.match_correction'::regclass)
              and c.relrowsecurity and c.relforcerowsecurity),
  array['match_correction', 'match_word'], 'the dictionary and the lessons have row security enabled and forced');
select is(has_table_privilege('authenticated', 'app.match_word', 'select'), false, 'the dictionary is nobody''s to read');
select is(has_table_privilege('authenticated', 'app.match_correction', 'insert,update,delete'), false,
  'the lessons are written through the api only');

select * from finish();
rollback;
