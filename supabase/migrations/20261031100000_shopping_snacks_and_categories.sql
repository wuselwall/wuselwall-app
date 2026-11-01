-- Shopping: a Snacks category and categories picked by a dictionary (issue #195).
--
-- 1. The supermarket walk gains "snacks" between the pantry and the freezer. New supermarket
--    lists are seeded with it; every existing list that was seeded as a supermarket (it has a
--    "produce" category) and has no "snacks" yet gets one right after its pantry (before
--    "other" when it has no pantry, else last), and the list's categories are renumbered
--    0, 10, 20 … in their old order.
-- 2. An item or catalogue entry added without a category gets one from a dictionary, no AI:
--    app.catalog_category_keys_for(folded name) names the seeded category keys the name
--    belongs to, in order of preference, and app.shopping_category_for(list, folded name)
--    picks the first of them the list has. It uses the same matching as the icon words
--    (app.catalog_icon_for): the whole name, then its last word, then the longest known word
--    the last word ends with. Words with a picture map through the icon; a second, more
--    specific list covers what has none (flour, nappies, detergent …) and wins over the icon
--    ("Tiefkühlpizza" is frozen, "Müsliriegel" snacks, "Haferflocken" pantry, not dairy).
--    A category the family chose for a catalogue entry always wins; custom categories (no
--    key) are never picked automatically.
-- 3. Open items and catalogue entries without a category get theirs once, now.
--
-- The logic lives in app.shopping_do_add and app.shopping_do_finish, which api.shopping_add_item,
-- api.shopping_finish and the add and finish operations of api.shopping_apply all call, so
-- recreating those two covers every entry point. Same signatures, grants kept.
--
-- api_version: unchanged. Everything is additive; the previous app release shows an unknown
-- category key by its key at worst and ignores nothing else.

-- ------------------------------------------------------------------ the snacks category

create or replace function app.shopping_seed_categories(p_list uuid, p_household uuid, p_kind text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_keys text[];
begin
  v_keys := case p_kind
    when 'supermarket' then array['produce', 'bakery', 'dairy', 'meat_fish', 'pantry', 'snacks', 'frozen', 'drinks', 'household', 'other']
    when 'drugstore'   then array['care', 'baby', 'cleaning', 'health', 'other']
    when 'hardware'    then array['tools', 'screws', 'electrical', 'garden', 'other']
    else array['other']
  end;
  insert into app.shopping_category (household_id, list_id, key, sort_order)
    select p_household, p_list, k, (ord - 1) * 10 from unnest(v_keys) with ordinality as t(k, ord);
end $$;

-- Lists seeded as a supermarket before this migration.
do $$
declare
  r record;
  v_at int;
begin
  for r in
    select distinct c.list_id, c.household_id from app.shopping_category c
     where c.key = 'produce'
       and not exists (select 1 from app.shopping_category s where s.list_id = c.list_id and s.key = 'snacks')
  loop
    -- Double the order so there is room for one more between any two, then renumber.
    update app.shopping_category set sort_order = sort_order * 2 where list_id = r.list_id;
    select coalesce(
             (select sort_order + 1 from app.shopping_category where list_id = r.list_id and key = 'pantry' limit 1),
             (select sort_order - 1 from app.shopping_category where list_id = r.list_id and key = 'other' limit 1),
             (select max(sort_order) + 2 from app.shopping_category where list_id = r.list_id))
      into v_at;
    insert into app.shopping_category (household_id, list_id, key, sort_order)
      values (r.household_id, r.list_id, 'snacks', v_at);
    update app.shopping_category c set sort_order = (s.rn - 1) * 10
      from (select id, row_number() over (order by sort_order, id) rn
              from app.shopping_category where list_id = r.list_id) s
     where c.id = s.id;
  end loop;
end $$;

-- ------------------------------------------------------------------ the dictionary

-- The seeded category keys a folded name belongs to, most likely first; empty when unknown.
-- Order: a frozen prefix ("Tiefkühl…"), then the specific word list, then the icon's keys.
create function app.catalog_category_keys_for(p_folded text) returns text[]
language sql immutable parallel safe set search_path = '' as $$
  with w(word, keys) as (values
    -- snacks and baking aids that have no picture
    ('mehl', array['pantry']), ('flour', array['pantry']), ('farine', array['pantry']), ('harina', array['pantry']),
    ('zucker', array['pantry']), ('sugar', array['pantry']), ('sucre', array['pantry']), ('azucar', array['pantry']),
    ('backpulver', array['pantry']), ('baking powder', array['pantry']),
    ('hefe', array['pantry']), ('yeast', array['pantry']), ('levure', array['pantry']), ('levadura', array['pantry']),
    ('essig', array['pantry']), ('vinegar', array['pantry']), ('vinaigre', array['pantry']), ('vinagre', array['pantry']),
    ('senf', array['pantry']), ('mustard', array['pantry']), ('moutarde', array['pantry']), ('mostaza', array['pantry']),
    ('mayo', array['pantry']), ('mayonnaise', array['pantry']),
    ('muesli', array['pantry']), ('cornflakes', array['pantry']), ('haferflocken', array['pantry']),
    ('cereal', array['pantry']), ('porridge', array['pantry']), ('oats', array['pantry']),
    ('muesliriegel', array['snacks', 'pantry']), ('riegel', array['snacks', 'pantry']),
    ('bar', array['snacks', 'pantry']), ('bars', array['snacks', 'pantry']),
    ('cracker', array['snacks', 'pantry']), ('crackers', array['snacks', 'pantry']),
    ('salzstangen', array['snacks', 'pantry']), ('pretzel sticks', array['snacks', 'pantry']),
    ('popcorn', array['snacks', 'pantry']), ('nachos', array['snacks', 'pantry']),
    ('studentenfutter', array['snacks', 'pantry']), ('trail mix', array['snacks', 'pantry']),
    ('pommes', array['frozen', 'snacks']),
    -- baby
    ('windeln', array['baby']), ('diapers', array['baby']), ('nappies', array['baby']), ('couches', array['baby']),
    ('panales', array['baby']), ('feuchttuecher', array['baby', 'care']), ('wipes', array['baby', 'care']),
    ('schnuller', array['baby']), ('dummy', array['baby']), ('pacifier', array['baby']),
    -- cleaning
    ('waschmittel', array['cleaning', 'household']), ('detergent', array['cleaning', 'household']),
    ('lessive', array['cleaning', 'household']), ('detergente', array['cleaning', 'household']),
    ('weichspueler', array['cleaning', 'household']), ('fabric softener', array['cleaning', 'household']),
    ('allzweckreiniger', array['cleaning', 'household']), ('wc-reiniger', array['cleaning', 'household']),
    ('badreiniger', array['cleaning', 'household']), ('glasreiniger', array['cleaning', 'household']),
    ('reiniger', array['cleaning', 'household']), ('cleaner', array['cleaning', 'household']),
    ('muelltueten', array['cleaning', 'household']),
    -- care
    ('deo', array['care']), ('deodorant', array['care']), ('rasierer', array['care']), ('razor', array['care']),
    ('rasierklingen', array['care']), ('razors', array['care']), ('tampons', array['care']),
    ('binden', array['care']), ('pads', array['care']), ('watte', array['care']), ('cotton wool', array['care']),
    ('wattestaebchen', array['care']), ('cotton buds', array['care']), ('zahnseide', array['care']),
    ('floss', array['care']),
    -- health
    ('hustensaft', array['health']), ('cough syrup', array['health']), ('nasenspray', array['health']),
    ('nasal spray', array['health']), ('fieberthermometer', array['health']), ('thermometer', array['health']),
    -- screws
    ('schrauben', array['screws']), ('screws', array['screws']), ('naegel', array['screws']),
    ('nails', array['screws']), ('duebel', array['screws']), ('wall plugs', array['screws']),
    -- tools
    ('hammer', array['tools']), ('saege', array['tools']), ('saw', array['tools']), ('bohrer', array['tools']),
    ('drill', array['tools']), ('zange', array['tools']), ('pliers', array['tools']),
    ('schraubenzieher', array['tools']), ('screwdriver', array['tools']),
    -- electrical
    ('kabel', array['electrical']), ('cable', array['electrical']), ('steckdose', array['electrical']),
    ('socket', array['electrical']), ('sicherung', array['electrical']), ('fuse', array['electrical']),
    -- garden
    ('erde', array['garden']), ('soil', array['garden']), ('duenger', array['garden']),
    ('fertiliser', array['garden']), ('fertilizer', array['garden']), ('samen', array['garden']),
    ('seeds', array['garden']), ('blumen', array['garden']), ('flowers', array['garden']),
    ('pflanzen', array['garden']), ('plants', array['garden']),
    -- household
    ('alufolie', array['household']), ('foil', array['household']), ('frischhaltefolie', array['household']),
    ('cling film', array['household']), ('backpapier', array['household']), ('baking paper', array['household']),
    ('kerzen', array['household']), ('candles', array['household']), ('servietten', array['household']),
    ('napkins', array['household']), ('gefrierbeutel', array['household', 'frozen'])
  ),
  i(icon, keys) as (values
    ('milk', array['dairy']), ('cheese', array['dairy']), ('butter', array['dairy']), ('egg', array['dairy']),
    ('bowl', array['dairy']),
    ('bread', array['bakery']), ('baguette', array['bakery']), ('pretzel', array['bakery']),
    ('croissant', array['bakery']),
    ('apple', array['produce']), ('pear', array['produce']), ('banana', array['produce']),
    ('orange', array['produce']), ('lemon', array['produce']), ('grapes', array['produce']),
    ('strawberry', array['produce']), ('tomato', array['produce']), ('cucumber', array['produce']),
    ('carrot', array['produce']), ('potato', array['produce']), ('onion', array['produce']),
    ('garlic', array['produce']), ('bell_pepper', array['produce']), ('chili', array['produce']),
    ('broccoli', array['produce']), ('lettuce', array['produce']), ('mushroom', array['produce']),
    ('avocado', array['produce']), ('corn', array['produce']), ('peas', array['produce']),
    ('beans', array['produce']),
    ('pasta', array['pantry']), ('rice', array['pantry']), ('salt', array['pantry']),
    ('honey', array['pantry']), ('oil', array['pantry']), ('nuts', array['pantry']), ('tin', array['pantry']),
    ('chocolate', array['snacks', 'pantry']), ('candy', array['snacks', 'pantry']),
    ('cookie', array['snacks', 'pantry']), ('cake', array['snacks', 'pantry']),
    ('fries', array['snacks', 'frozen']),
    ('ice_cream', array['frozen']), ('pizza', array['frozen']),
    ('chicken', array['meat_fish']), ('meat', array['meat_fish']), ('sausage', array['meat_fish']),
    ('bacon', array['meat_fish']), ('fish', array['meat_fish']),
    ('coffee', array['drinks']), ('tea', array['drinks']), ('juice', array['drinks']),
    ('water', array['drinks']), ('soda', array['drinks']), ('beer', array['drinks']), ('wine', array['drinks']),
    ('toilet_paper', array['household', 'care', 'cleaning']), ('sponge', array['household', 'cleaning']),
    ('trash', array['household', 'cleaning']), ('battery', array['household', 'cleaning']),
    ('light_bulb', array['household', 'cleaning']),
    ('soap', array['care', 'household']), ('toothbrush', array['care', 'household']),
    ('lotion', array['care', 'household']),
    ('baby_bottle', array['baby', 'household']),
    ('plaster', array['health', 'household']), ('pill', array['health', 'household'])
  ),
  n(whole, last) as (
    select btrim(p_folded), regexp_replace(btrim(p_folded), '^.*[[:space:]/-]', '')
  ),
  -- the same rule as the icon words: whole name, last word, longest word the last word ends with
  specific as (
    select w.keys from w, n
     where w.word = n.whole
        or w.word = n.last
        or (length(w.word) >= 3 and n.last like '%' || w.word)
     order by (w.word = n.whole) desc, (w.word = n.last) desc, length(w.word) desc
     limit 1
  ),
  parts(ord, keys) as (
    select 1, array['frozen'] from n
     where n.whole like 'tiefkuehl%' or n.whole like 'tiefgekuehlt%' or n.whole like 'tk-%'
        or n.whole like 'frozen %'
    union all select 2, keys from specific
    union all select 3, i.keys from i where i.icon = app.catalog_icon_for(p_folded)
  ),
  flat as (
    select k, min(p.ord * 100 + t.pos) as rank
      from parts p, unnest(p.keys) with ordinality as t(k, pos)
     group by k
  )
  select coalesce(array_agg(k order by rank), array[]::text[]) from flat
$$;

-- The list's own category for a folded name: the first candidate key the list has, else null.
create function app.shopping_category_for(p_list uuid, p_folded text) returns uuid
language sql stable security definer set search_path = '' as $$
  select c.id
    from unnest(app.catalog_category_keys_for(p_folded)) with ordinality as k(key, pos)
    join app.shopping_category c on c.list_id = p_list and c.key = k.key
   order by k.pos
   limit 1
$$;

revoke execute on function app.catalog_category_keys_for(text), app.shopping_category_for(uuid, text)
  from public, anon, authenticated;

-- ------------------------------------------------------------------ using it

-- As in 20261012120000_shopping_outbox.sql; only the category of a new item changes: the
-- catalogue entry's category if the family set one, else the dictionary's.
create or replace function app.shopping_do_add(a app.actor_t, p_list uuid, p_name text, p_quantity text,
                                               p_id uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_list uuid := app.shopping_target_list(a.household_id, p_list);
  v_name text := btrim(coalesce(p_name, ''));
  v_fold text := app.fold(btrim(coalesce(p_name, '')));
  v_id   uuid;
  v_cat  app.catalog_item;
begin
  if length(v_name) = 0 then
    raise exception 'name required' using errcode = '22023', hint = 'name_required';
  end if;
  if length(v_name) > 120 then
    raise exception 'name too long' using errcode = '22023', hint = 'name_too_long';
  end if;

  select i.id into v_id from app.shopping_item i
   where i.list_id = v_list and i.trip_id is null and not i.checked and i.folded_name = v_fold
   limit 1 for update;
  if found then
    update app.shopping_item set count = least(count + 1, 99) where id = v_id;
    if p_id is not null and p_id <> v_id then
      insert into app.shopping_item_alias (household_id, alias_id, item_id)
        values (a.household_id, p_id, v_id) on conflict do nothing;
    end if;
    perform app.audit(a, 'shopping_item', v_id, 'increment');
  else
    select * into v_cat from app.catalog_item where list_id = v_list and folded_name = v_fold;
    insert into app.shopping_item (id, list_id, household_id, name, folded_name, quantity,
                                   added_by, category_id, catalog_item_id)
    values (coalesce(p_id, gen_random_uuid()), v_list, a.household_id, coalesce(v_cat.name, v_name),
            v_fold, nullif(btrim(coalesce(p_quantity, '')), ''), a.profile_id,
            coalesce(v_cat.category_id, app.shopping_category_for(v_list, v_fold)), v_cat.id)
    returning id into v_id;
    perform app.audit(a, 'shopping_item', v_id, 'create', jsonb_build_object('name', v_name));
  end if;
  return v_id;
end $$;

-- As in 20261012120000_shopping_outbox.sql; only a new catalogue entry's category changes:
-- the item's own, else the dictionary's. An existing entry keeps what the family set.
create or replace function app.shopping_do_finish(a app.actor_t, p_list uuid, p_trip uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_list uuid := app.shopping_target_list(a.household_id, p_list);
  v_trip uuid;
  v_done int;
  v_left int;
  r      record;
  v_cat  uuid;
begin
  select count(*) into v_done from app.shopping_item where list_id = v_list and trip_id is null and checked;
  select count(*) into v_left from app.shopping_item where list_id = v_list and trip_id is null and not checked;
  if v_done = 0 then
    return jsonb_build_object('bought', 0, 'carried_over', v_left);
  end if;

  insert into app.shopping_trip (id, household_id, list_id, finished_by)
    values (coalesce(p_trip, gen_random_uuid()), a.household_id, v_list, a.profile_id)
    returning id into v_trip;

  for r in select * from app.shopping_item where list_id = v_list and trip_id is null and checked loop
    insert into app.catalog_item (household_id, list_id, name, folded_name, category_id, purchase_count, last_purchased_at)
      values (a.household_id, v_list, r.name, r.folded_name,
              coalesce(r.category_id, app.shopping_category_for(v_list, r.folded_name)), 1, now())
    on conflict (list_id, folded_name) do update
      set purchase_count = app.catalog_item.purchase_count + 1,
          last_purchased_at = now(),
          -- The item's own category first, then what the entry had, then the dictionary.
          category_id = coalesce(r.category_id, app.catalog_item.category_id, excluded.category_id)
    returning id into v_cat;
    update app.shopping_item set trip_id = v_trip, catalog_item_id = v_cat where id = r.id;
  end loop;

  perform app.audit(a, 'shopping_list', v_list, 'finish',
                    jsonb_build_object('bought', v_done, 'carried_over', v_left, 'trip', v_trip));
  return jsonb_build_object('bought', v_done, 'carried_over', v_left, 'trip_id', v_trip);
end $$;

-- ------------------------------------------------------------------ once for what exists

update app.shopping_item i set category_id = app.shopping_category_for(i.list_id, i.folded_name)
 where i.trip_id is null and i.category_id is null
   and app.shopping_category_for(i.list_id, i.folded_name) is not null;

update app.catalog_item c set category_id = app.shopping_category_for(c.list_id, c.folded_name)
 where c.category_id is null
   and app.shopping_category_for(c.list_id, c.folded_name) is not null;
