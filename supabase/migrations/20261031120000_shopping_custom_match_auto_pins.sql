-- Shopping: custom categories match by name, the "auto" flag, pinned tiles (issue #195, round 2).
--
-- 1. app.shopping_category_for(list, folded name) learns the family's own categories. In this
--    precedence it picks
--      a. a custom category (no key) whose folded name is at least 3 letters and appears in the
--         item's folded name as a whole word (start/end, space, hyphen, slash): "Bio" takes
--         "Bio Äpfel" and "Bio-Milch"; the longest name wins, then the walk order;
--      b. the first candidate key of the dictionary (app.catalog_category_keys_for) the list
--         has, where a custom category counts as that key when its folded name equals the key
--         itself or the key's label in German, English, French or Spanish (or a close synonym),
--         see app.shopping_key_for_name: a family category "Süsses" receives what the
--         dictionary calls snacks. A seeded category and a custom one with the same key are both
--         candidates; the lower sort_order (the one earlier in the walk) wins.
--    A custom category is never picked otherwise. The signature is unchanged.
-- 2. category_auto on app.shopping_item and app.catalog_item says that the category was inferred
--    (dictionary or name match), not chosen by a person. Inferring sets it, a person setting the
--    category (api.shopping_set_category, the 'category' operation of api.shopping_apply,
--    api.catalog_item_update) clears it. An item added from a catalogue entry takes the entry's
--    flag; finishing a trip carries the item's flag to the entry, and an inferred category never
--    replaces one a person set on the entry. Exposed as the LAST column of api.shopping_items
--    and api.shopping_catalog, and as "category_auto" in the items of api.shopping_apply.
--    The one-time backfill cannot know which categories round 1 inferred, so it marks open items
--    and catalogue entries whose category is what the dictionary picks for them and for which
--    no audit row records a person's category change.
-- 3. app.catalog_item.pinned (default false) pins a tile; api.shopping_catalog_pin sets or clears
--    it for any member. Exposed as the last column of api.shopping_catalog.
-- 4. Adding a name that is already open on the list used to drop the quantity text. It now keeps
--    it: set when the open item has none, appended ("500 g + 200 g", at most 40 characters) when
--    it differs, unchanged when the open item's text already contains it.
--
-- api_version: unchanged. Everything is additive (new columns at the end of the views, a new
-- function); the previous app release ignores the new keys.

-- ------------------------------------------------------------------ custom names as keys

-- The seeded key a family's category name stands for, else null. [p_folded] is app.fold(name).
-- The key itself, the labels of the app (app_de/en/fr/es.arb, shoppingCat_*) and a few synonyms.
create function app.shopping_key_for_name(p_folded text) returns text
language sql immutable parallel safe set search_path = '' as $$
  select a.key from (values
    ('produce', 'produce'), ('produce', 'obst & gemuese'), ('produce', 'fruit & vegetables'),
    ('produce', 'fruits et legumes'), ('produce', 'frutas y verduras'), ('produce', 'obst und gemuese'),
    ('produce', 'gemuese'), ('produce', 'obst'), ('produce', 'fruechte'), ('produce', 'fruit'),
    ('produce', 'fruits'), ('produce', 'vegetables'), ('produce', 'veggies'), ('produce', 'legumes'),
    ('produce', 'frutas'), ('produce', 'verduras'),
    ('bakery', 'bakery'), ('bakery', 'brot & backwaren'), ('bakery', 'bread & bakery'),
    ('bakery', 'pain et boulangerie'), ('bakery', 'pan y bolleria'), ('bakery', 'brot und backwaren'),
    ('bakery', 'brot'), ('bakery', 'backwaren'), ('bakery', 'baeckerei'), ('bakery', 'bread'),
    ('bakery', 'boulangerie'), ('bakery', 'pain'), ('bakery', 'panaderia'), ('bakery', 'pan'),
    ('dairy', 'dairy'), ('dairy', 'milch & kaese'), ('dairy', 'dairy & cheese'),
    ('dairy', 'produits laitiers et fromages'), ('dairy', 'lacteos y quesos'),
    ('dairy', 'milch und kaese'), ('dairy', 'milchprodukte'), ('dairy', 'milch'), ('dairy', 'kaese'),
    ('dairy', 'molkerei'), ('dairy', 'produits laitiers'), ('dairy', 'lacteos'),
    ('meat_fish', 'meat_fish'), ('meat_fish', 'fleisch & fisch'), ('meat_fish', 'meat & fish'),
    ('meat_fish', 'viande et poisson'), ('meat_fish', 'carne y pescado'),
    ('meat_fish', 'fleisch und fisch'), ('meat_fish', 'fleisch'), ('meat_fish', 'fisch'),
    ('meat_fish', 'metzgerei'), ('meat_fish', 'meat'), ('meat_fish', 'fish'), ('meat_fish', 'viande'),
    ('meat_fish', 'poisson'), ('meat_fish', 'carne'), ('meat_fish', 'pescado'),
    ('pantry', 'pantry'), ('pantry', 'vorrat'), ('pantry', 'epicerie'), ('pantry', 'despensa'),
    ('pantry', 'vorraete'), ('pantry', 'trockenwaren'), ('pantry', 'konserven'), ('pantry', 'grocery'),
    ('pantry', 'groceries'),
    ('snacks', 'snacks'), ('snacks', 'snack'), ('snacks', 'suessigkeiten'), ('snacks', 'suesses'),
    ('snacks', 'sweets'), ('snacks', 'friandises'), ('snacks', 'dulces'), ('snacks', 'aperitivos'),
    ('snacks', 'knabbereien'), ('snacks', 'naschen'), ('snacks', 'naschzeug'), ('snacks', 'candy'),
    ('snacks', 'confiserie'), ('snacks', 'chuches'),
    ('frozen', 'frozen'), ('frozen', 'tiefkuehl'), ('frozen', 'surgeles'), ('frozen', 'congelados'),
    ('frozen', 'tiefkuehlprodukte'), ('frozen', 'tiefkuehlware'), ('frozen', 'tk'),
    ('frozen', 'gefrorenes'), ('frozen', 'congeles'),
    ('drinks', 'drinks'), ('drinks', 'getraenke'), ('drinks', 'boissons'), ('drinks', 'bebidas'),
    ('drinks', 'getraenk'), ('drinks', 'drink'), ('drinks', 'beverages'), ('drinks', 'boisson'),
    ('drinks', 'bebida'),
    ('household', 'household'), ('household', 'haushalt'), ('household', 'maison'),
    ('household', 'hogar'), ('household', 'haushaltswaren'), ('household', 'haushaltsartikel'),
    ('other', 'other'), ('other', 'sonstiges'), ('other', 'autres'), ('other', 'otros'),
    ('other', 'diverses'), ('other', 'anderes'), ('other', 'misc'), ('other', 'miscellaneous'),
    ('other', 'divers'), ('other', 'varios'),
    ('care', 'care'), ('care', 'koerperpflege'), ('care', 'body care'), ('care', 'hygiene et soins'),
    ('care', 'cuidado personal'), ('care', 'pflege'), ('care', 'kosmetik'), ('care', 'hygiene'),
    ('care', 'soins'),
    ('baby', 'baby'), ('baby', 'baby & kind'), ('baby', 'baby & kids'), ('baby', 'bebes et enfants'),
    ('baby', 'bebes y ninos'), ('baby', 'baby und kind'), ('baby', 'kind'), ('baby', 'kinder'),
    ('baby', 'kids'), ('baby', 'bebes'), ('baby', 'enfants'), ('baby', 'ninos'),
    ('cleaning', 'cleaning'), ('cleaning', 'reinigung'), ('cleaning', 'entretien'),
    ('cleaning', 'limpieza'), ('cleaning', 'reinigungsmittel'), ('cleaning', 'putzmittel'),
    ('health', 'health'), ('health', 'gesundheit'), ('health', 'sante'), ('health', 'salud'),
    ('health', 'medikamente'), ('health', 'apotheke'), ('health', 'medicine'), ('health', 'pharmacy'),
    ('tools', 'tools'), ('tools', 'werkzeug'), ('tools', 'outils'), ('tools', 'herramientas'),
    ('tools', 'werkzeuge'),
    ('screws', 'screws'), ('screws', 'schrauben & befestigung'), ('screws', 'screws & fixings'),
    ('screws', 'vis et fixations'), ('screws', 'tornillos y fijaciones'),
    ('screws', 'schrauben und befestigung'), ('screws', 'schrauben'), ('screws', 'befestigung'),
    ('screws', 'fixings'), ('screws', 'vis'), ('screws', 'fixations'), ('screws', 'tornillos'),
    ('screws', 'fijaciones'),
    ('electrical', 'electrical'), ('electrical', 'elektro'), ('electrical', 'electricite'),
    ('electrical', 'electricidad'), ('electrical', 'elektrik'),
    ('garden', 'garden'), ('garden', 'garten'), ('garden', 'jardin'), ('garden', 'gartenbedarf'),
    ('garden', 'gardening')
  ) as a(key, name)
  where a.name = btrim(p_folded)
  limit 1
$$;

-- The list's own category for a folded name; null when nothing fits. See the header.
create or replace function app.shopping_category_for(p_list uuid, p_folded text) returns uuid
language sql stable security definer set search_path = '' as $$
  select coalesce(
    -- a. a custom category named in the item
    (select c.id
       from app.shopping_category c
      where c.list_id = p_list and c.key is null and c.name is not null
        and length(app.fold(btrim(c.name))) >= 3
        and position(' ' || regexp_replace(app.fold(btrim(c.name)), '[-/]', ' ', 'g') || ' '
                     in ' ' || regexp_replace(btrim(p_folded), '[-/]', ' ', 'g') || ' ') > 0
      order by length(app.fold(btrim(c.name))) desc, c.sort_order, c.id
      limit 1),
    -- b. the first candidate key the list has, as a seeded or an equally named custom category
    (select c.id
       from unnest(app.catalog_category_keys_for(p_folded)) with ordinality as k(key, pos)
       join app.shopping_category c
         on c.list_id = p_list
        and (c.key = k.key
             or (c.key is null and app.shopping_key_for_name(app.fold(c.name)) = k.key))
      order by k.pos, c.sort_order, c.id
      limit 1))
$$;

revoke execute on function app.shopping_key_for_name(text), app.shopping_category_for(uuid, text)
  from public, anon, authenticated;

-- ------------------------------------------------------------------ columns

alter table app.shopping_item add column category_auto boolean not null default false;
alter table app.catalog_item  add column category_auto boolean not null default false;
alter table app.catalog_item  add column pinned        boolean not null default false;

-- ------------------------------------------------------------------ using it

-- As in 20261031100000_shopping_snacks_and_categories.sql; a new item takes the catalogue
-- entry's category and flag, else the inferred category (auto). Adding a name that is already
-- open keeps the quantity text.
create or replace function app.shopping_do_add(a app.actor_t, p_list uuid, p_name text, p_quantity text,
                                               p_id uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_list uuid := app.shopping_target_list(a.household_id, p_list);
  v_name text := btrim(coalesce(p_name, ''));
  v_fold text := app.fold(btrim(coalesce(p_name, '')));
  v_q    text := nullif(btrim(coalesce(p_quantity, '')), '');
  v_id   uuid;
  v_cat  app.catalog_item;
  v_cid  uuid;
  v_auto boolean;
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
    update app.shopping_item set
      count = least(count + 1, 99),
      quantity = case
        when v_q is null then quantity
        when quantity is null then left(v_q, 40)
        when position(app.fold(v_q) in app.fold(quantity)) > 0 then quantity
        else left(quantity || ' + ' || v_q, 40)
      end
     where id = v_id;
    if p_id is not null and p_id <> v_id then
      insert into app.shopping_item_alias (household_id, alias_id, item_id)
        values (a.household_id, p_id, v_id) on conflict do nothing;
    end if;
    perform app.audit(a, 'shopping_item', v_id, 'increment');
  else
    select * into v_cat from app.catalog_item where list_id = v_list and folded_name = v_fold;
    if v_cat.category_id is not null then
      v_cid := v_cat.category_id;
      v_auto := v_cat.category_auto;
    else
      v_cid := app.shopping_category_for(v_list, v_fold);
      v_auto := v_cid is not null;
    end if;
    insert into app.shopping_item (id, list_id, household_id, name, folded_name, quantity,
                                   added_by, category_id, category_auto, catalog_item_id)
    values (coalesce(p_id, gen_random_uuid()), v_list, a.household_id, coalesce(v_cat.name, v_name),
            v_fold, v_q, a.profile_id, v_cid, v_auto, v_cat.id)
    returning id into v_id;
    perform app.audit(a, 'shopping_item', v_id, 'create', jsonb_build_object('name', v_name));
  end if;
  return v_id;
end $$;

-- As in 20261012120000_shopping_outbox.sql; a person's choice clears the flag, on the item and
-- on the catalogue entry it teaches.
create or replace function app.shopping_do_category(a app.actor_t, p_item uuid, p_category uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_item app.shopping_item;
begin
  select * into v_item from app.shopping_item
   where id = p_item and household_id = a.household_id and trip_id is null;
  if not found then
    return false;
  end if;
  if p_category is not null and not exists (
       select 1 from app.shopping_category where id = p_category and list_id = v_item.list_id) then
    raise exception 'category not found' using errcode = 'P0002', hint = 'category_not_found';
  end if;
  update app.shopping_item set category_id = p_category, category_auto = false where id = p_item;
  update app.catalog_item set category_id = p_category, category_auto = false
   where id = v_item.catalog_item_id;
  perform app.audit(a, 'shopping_item', p_item, 'categorise');
  return true;
end $$;

-- As in 20261031100000_shopping_snacks_and_categories.sql; the flag travels with the category
-- into a new entry, and an inferred category does not replace one a person set on the entry.
create or replace function app.shopping_do_finish(a app.actor_t, p_list uuid, p_trip uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_list uuid := app.shopping_target_list(a.household_id, p_list);
  v_trip uuid;
  v_done int;
  v_left int;
  r      record;
  v_e    app.catalog_item;
  v_c    uuid;
  v_a    boolean;
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
    select * into v_e from app.catalog_item where list_id = v_list and folded_name = r.folded_name;
    if found and v_e.category_id is not null
       and (r.category_id is null or (r.category_auto and not v_e.category_auto)) then
      -- the entry already has a category and the item brings nothing better
      v_c := v_e.category_id;
      v_a := v_e.category_auto;
    elsif r.category_id is not null then
      v_c := r.category_id;
      v_a := r.category_auto;
    else
      v_c := app.shopping_category_for(v_list, r.folded_name);
      v_a := v_c is not null;
    end if;
    insert into app.catalog_item (household_id, list_id, name, folded_name, category_id, category_auto,
                                  purchase_count, last_purchased_at)
      values (a.household_id, v_list, r.name, r.folded_name, v_c, v_a, 1, now())
    on conflict (list_id, folded_name) do update
      set purchase_count = app.catalog_item.purchase_count + 1,
          last_purchased_at = now(),
          category_id = excluded.category_id,
          category_auto = excluded.category_auto
    returning id into v_cat;
    update app.shopping_item set trip_id = v_trip, catalog_item_id = v_cat where id = r.id;
  end loop;

  perform app.audit(a, 'shopping_list', v_list, 'finish',
                    jsonb_build_object('bought', v_done, 'carried_over', v_left, 'trip', v_trip));
  return jsonb_build_object('bought', v_done, 'carried_over', v_left, 'trip_id', v_trip);
end $$;

-- As in 20261023100000_editable_household.sql; choosing a category clears the flag.
create or replace function api.catalog_item_update(p_actor uuid, p_item uuid, p_name text default null, p_category uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v      app.catalog_item;
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  select * into v from app.catalog_item where id = p_item and household_id = a.household_id;
  if not found then
    raise exception 'tile not found' using errcode = 'P0002', hint = 'catalog_not_found';
  end if;
  if p_name is not null then
    if v_name is null or length(v_name) > 120 then
      raise exception 'name required' using errcode = '22023', hint = 'name_required';
    end if;
    if exists (select 1 from app.catalog_item
                where list_id = v.list_id and id <> p_item and folded_name = app.fold(v_name)) then
      raise exception 'tile exists' using errcode = '23505', hint = 'catalog_exists';
    end if;
  end if;
  if p_category is not null and not exists (select 1 from app.shopping_category
                                              where id = p_category and list_id = v.list_id) then
    raise exception 'category not found' using errcode = 'P0002', hint = 'category_not_found';
  end if;
  update app.catalog_item set
    name          = coalesce(v_name, name),
    folded_name   = coalesce(app.fold(v_name), folded_name),
    category_id   = coalesce(p_category, category_id),
    category_auto = case when p_category is not null then false else category_auto end
  where id = p_item;
  perform app.audit(a, 'catalog_item', p_item, 'update',
                    jsonb_strip_nulls(jsonb_build_object('name', v_name, 'category_id', p_category)));
  perform app.broadcast(a.household_id, 'shopping');
end $$;

-- ------------------------------------------------------------------ pinned tiles

-- Pins a tile to the top of the suggestions, or releases it. Any member may.
create function api.shopping_catalog_pin(p_actor uuid, p_item uuid, p_pinned boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  update app.catalog_item set pinned = coalesce(p_pinned, false)
   where id = p_item and household_id = a.household_id;
  if not found then
    raise exception 'item not found' using errcode = 'P0002', hint = 'item_not_found';
  end if;
  perform app.audit(a, 'catalog_item', p_item, case when coalesce(p_pinned, false) then 'pin' else 'unpin' end);
  perform app.broadcast(a.household_id, 'shopping');
end $$;

revoke execute on function api.shopping_catalog_pin(uuid, uuid, boolean) from public, anon;
grant execute on function api.shopping_catalog_pin(uuid, uuid, boolean) to authenticated;

-- ------------------------------------------------------------------ views and the batch

-- Every column and grant stays; the flag comes last.
create or replace view api.shopping_items with (security_invoker = true) as
  select i.id, i.name, i.quantity, i.checked, i.added_by, i.checked_by, i.checked_at, i.created_at,
         i.list_id, i.category_id, i.count, i.catalog_item_id, i.source_meal_entry_ids,
         i.category_auto
    from app.shopping_item i
   where i.trip_id is null;

create or replace view api.shopping_catalog with (security_invoker = true) as
  select id, list_id, name, folded_name, category_id, icon_key, purchase_count, last_purchased_at,
         category_auto, pinned
    from app.catalog_item;

-- As in 20261012120000_shopping_outbox.sql; the open items carry category_auto.
create or replace function api.shopping_apply(p_actor uuid, p_ops jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.actor(p_actor);
  b        app.actor_t;
  v_op     jsonb;
  v_op_id  uuid;
  v_kind   text;
  v_status text;
  v_code   text;
  v_hint   text;
  v_out    jsonb := '[]';
begin
  if jsonb_typeof(p_ops) is distinct from 'array' or jsonb_array_length(p_ops) > 200 then
    raise exception 'invalid operations' using errcode = '22023', hint = 'ops_invalid';
  end if;

  -- Replays older than this are not expected; the log stays small.
  delete from app.shopping_op
   where household_id = a.household_id and applied_at < now() - interval '30 days';

  for v_op in select value from jsonb_array_elements(p_ops) loop
    begin
      v_op_id := (v_op ->> 'op_id')::uuid;
    exception when others then
      raise exception 'invalid operations' using errcode = '22023', hint = 'ops_invalid';
    end;
    if v_op_id is null then
      raise exception 'invalid operations' using errcode = '22023', hint = 'ops_invalid';
    end if;
    v_kind := coalesce(v_op ->> 'kind', '');

    if exists (select 1 from app.shopping_op where household_id = a.household_id and op_id = v_op_id) then
      v_out := v_out || jsonb_build_object('op_id', v_op_id, 'status', 'duplicate');
      continue;
    end if;

    v_code := null;
    begin
      b := case when v_op ? 'actor' then app.actor((v_op ->> 'actor')::uuid) else a end;
      v_status := app.shopping_apply_op(b, v_op);
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint;
      v_status := 'rejected';
      v_code := coalesce(nullif(v_hint, ''), sqlstate);
    end;

    insert into app.shopping_op (household_id, op_id, kind, status, code)
      values (a.household_id, v_op_id, left(v_kind, 20), v_status, v_code);
    v_out := v_out || jsonb_strip_nulls(
      jsonb_build_object('op_id', v_op_id, 'status', v_status, 'code', v_code));
  end loop;

  perform app.broadcast(a.household_id, 'shopping');
  return jsonb_build_object(
    'results', v_out,
    'items', (select coalesce(jsonb_agg(jsonb_build_object(
                'id', i.id, 'name', i.name, 'quantity', i.quantity, 'checked', i.checked,
                'added_by', i.added_by, 'checked_by', i.checked_by, 'checked_at', i.checked_at,
                'created_at', i.created_at, 'list_id', i.list_id, 'category_id', i.category_id,
                'count', i.count, 'catalog_item_id', i.catalog_item_id,
                'category_auto', i.category_auto)
                order by i.checked, i.created_at), '[]')
                from app.shopping_item i
               where i.household_id = a.household_id and i.trip_id is null));
end $$;

revoke execute on function api.shopping_apply(uuid, jsonb) from public, anon;
grant execute on function api.shopping_apply(uuid, jsonb) to authenticated;

-- ------------------------------------------------------------------ once for what exists

-- Round 1 filled categories from the dictionary without recording it. Mark what still equals the
-- dictionary's pick and has no audit row of a person's category change; a person who chose the
-- very same category is marked too, which only means the app may offer a better one.
update app.shopping_item i set category_auto = true
 where i.trip_id is null and i.category_id is not null
   and i.category_id = app.shopping_category_for(i.list_id, i.folded_name)
   and not exists (select 1 from app.audit_log l
                    where l.entity_type = 'shopping_item' and l.entity_id = i.id and l.action = 'categorise');

update app.catalog_item c set category_auto = true
 where c.category_id is not null
   and c.category_id = app.shopping_category_for(c.list_id, c.folded_name)
   and not exists (select 1 from app.audit_log l
                    where l.entity_type = 'catalog_item' and l.entity_id = c.id and l.action = 'update'
                      and l.diff ? 'category_id')
   and not exists (select 1 from app.audit_log l
                     join app.shopping_item s on s.id = l.entity_id
                    where l.entity_type = 'shopping_item' and l.action = 'categorise'
                      and s.catalog_item_id = c.id);
