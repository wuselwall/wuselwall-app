-- A lighter day, the remaining pieces of Wunschessen (specs/27):
--
--   * Dish pictures. app.meal_icon_for() picks a picture of the app's `meals` set from a dish's
--     name, in German, English, French and Spanish, the way app.catalog_icon_for() does for the
--     shopping tiles. Recipes and meal plan entries keep it in a generated column, which
--     api.recipes and api.meal_history show as icon_key, so the wish picker shows the family's
--     recipes and its favourites with a picture; a wish made without an icon gets one from its
--     words when it is written.
--   * "von letzter Woche". api.meal_wishes gains wished_on (the household day the wish was made
--     or last changed) and earlier_week (an open wish made before this household week began).
--   * Ageing. An open wish not planned within four weeks (28 days) of being made drops out of
--     api.meal_wishes and no longer counts toward meals.wishes_per_week. Its row stays as it is:
--     nothing records that it was not cooked, and no job runs for it. Wishing again simply makes
--     a new wish.
--
-- Additive for api_version: two tables and two views gain a last column, api.meal_wishes two, and
-- api.meal_wish_set keeps its signature. The previous app ignores the new columns; it shows a
-- wish older than four weeks no more, which is the point.

-- ================================================================== dish pictures

-- The key of the `meals` picture set (app/assets/emoji/meals/) for a dish's name, or null.
-- Every word of the folded name is looked at, the first that matches wins: a whole word first,
-- then the longest known word it ends with, at least four letters (German compounds:
-- Gemüsesuppe, Kartoffelsalat). The whole name is looked at before its words, for dishes of
-- several words (hot dog, pot-au-feu). Only the owner calls it: in the generated columns below
-- and the wish trigger, so the views' readers need no right to it. A later migration that
-- teaches it new words recomputes the columns with `update ... set title = title`.
create function app.meal_icon_for(p_title text) returns text
language sql immutable parallel safe set search_path = '' as $$
  with w(word, key) as (values
    -- pizza
    ('pizza', 'pizza'), ('pizzen', 'pizza'), ('pizzas', 'pizza'), ('flammkuchen', 'pizza'),
    ('tarte flambee', 'pizza'), ('calzone', 'pizza'),
    -- pasta
    ('pasta', 'pasta'), ('nudeln', 'pasta'), ('spaghetti', 'pasta'), ('spagetti', 'pasta'),
    ('lasagne', 'pasta'), ('lasagna', 'pasta'), ('lasana', 'pasta'), ('makkaroni', 'pasta'),
    ('macaroni', 'pasta'), ('macarrones', 'pasta'), ('penne', 'pasta'), ('tagliatelle', 'pasta'),
    ('fusilli', 'pasta'), ('tortellini', 'pasta'), ('ravioli', 'pasta'), ('raviolis', 'pasta'),
    ('spaetzle', 'pasta'), ('kaesespaetzle', 'pasta'), ('gnocchi', 'pasta'), ('pates', 'pasta'),
    ('espaguetis', 'pasta'), ('fideos', 'pasta'), ('carbonara', 'pasta'), ('bolognese', 'pasta'),
    -- pancakes
    ('pfannkuchen', 'pancakes'), ('eierkuchen', 'pancakes'), ('palatschinken', 'pancakes'),
    ('kaiserschmarrn', 'pancakes'), ('crepes', 'pancakes'), ('crepe', 'pancakes'),
    ('pancakes', 'pancakes'), ('pancake', 'pancakes'), ('galettes', 'pancakes'),
    ('tortitas', 'pancakes'), ('reibekuchen', 'pancakes'), ('kartoffelpuffer', 'pancakes'),
    -- waffle
    ('waffeln', 'waffle'), ('waffel', 'waffle'), ('waffles', 'waffle'), ('waffle', 'waffle'),
    ('gaufres', 'waffle'), ('gaufre', 'waffle'), ('gofres', 'waffle'),
    -- burger
    ('burger', 'burger'), ('burgers', 'burger'), ('hamburger', 'burger'), ('cheeseburger', 'burger'),
    ('hamburguesa', 'burger'), ('hamburguesas', 'burger'),
    -- fries
    ('pommes', 'fries'), ('fritten', 'fries'), ('frites', 'fries'), ('fries', 'fries'),
    ('chips', 'fries'), ('fritas', 'fries'),
    -- hot dog
    ('hotdog', 'hotdog'), ('hot dog', 'hotdog'), ('hot-dog', 'hotdog'), ('wurst', 'hotdog'),
    ('wuerstchen', 'hotdog'), ('wienerli', 'hotdog'), ('bratwurst', 'hotdog'), ('currywurst', 'hotdog'),
    ('sausages', 'hotdog'), ('saucisses', 'hotdog'), ('salchichas', 'hotdog'), ('perritos', 'hotdog'),
    ('perrito', 'hotdog'),
    -- sandwich
    ('sandwich', 'sandwich'), ('sandwiches', 'sandwich'), ('toast', 'sandwich'), ('croque', 'sandwich'),
    ('bocadillo', 'sandwich'), ('bocadillos', 'sandwich'), ('panini', 'sandwich'),
    -- taco, burrito, kebab
    ('taco', 'taco'), ('tacos', 'taco'), ('nachos', 'taco'), ('quesadilla', 'taco'),
    ('quesadillas', 'taco'), ('fajitas', 'taco'),
    ('burrito', 'burrito'), ('burritos', 'burrito'), ('wrap', 'burrito'), ('wraps', 'burrito'),
    ('kebab', 'kebab'), ('doener', 'kebab'), ('doner', 'kebab'), ('doenerteller', 'kebab'),
    ('gyros', 'kebab'), ('shawarma', 'kebab'), ('durum', 'kebab'),
    -- curry, rice, noodles
    ('curry', 'curry'), ('currys', 'curry'), ('dal', 'curry'), ('couscous', 'curry'),
    ('reis', 'rice'), ('rice', 'rice'), ('riz', 'rice'), ('arroz', 'rice'), ('risotto', 'rice'),
    ('nasi', 'rice'), ('bibimbap', 'rice'),
    ('ramen', 'noodles'), ('nudelsuppe', 'noodles'), ('noodles', 'noodles'), ('udon', 'noodles'),
    ('pho', 'noodles'), ('mie', 'noodles'), ('asianudeln', 'noodles'),
    -- soup and stew
    ('suppe', 'soup'), ('eintopf', 'soup'), ('gulasch', 'soup'), ('chili', 'soup'),
    ('linsen', 'soup'), ('soup', 'soup'), ('stew', 'soup'), ('soupe', 'soup'), ('potage', 'soup'),
    ('veloute', 'soup'), ('pot-au-feu', 'soup'), ('ragout', 'soup'), ('sopa', 'soup'),
    ('caldo', 'soup'), ('cocido', 'soup'), ('guiso', 'soup'), ('lentejas', 'soup'),
    ('gazpacho', 'soup'), ('crema', 'soup'),
    -- paella
    ('paella', 'paella'), ('jambalaya', 'paella'),
    -- salad
    ('salat', 'salad'), ('salad', 'salad'), ('salade', 'salad'), ('ensalada', 'salad'),
    ('bowl', 'salad'),
    -- sushi, dumplings
    ('sushi', 'sushi'), ('maki', 'sushi'),
    ('dumplings', 'dumpling'), ('dumpling', 'dumpling'), ('maultaschen', 'dumpling'),
    ('knoedel', 'dumpling'), ('kloesse', 'dumpling'), ('gyoza', 'dumpling'), ('pierogi', 'dumpling'),
    ('empanadas', 'dumpling'), ('empanada', 'dumpling'), ('samosas', 'dumpling'),
    -- chicken, fish, meat
    ('haehnchen', 'chicken'), ('huhn', 'chicken'), ('haehnchenbrust', 'chicken'), ('poulet', 'chicken'),
    ('chicken', 'chicken'), ('nuggets', 'chicken'), ('chicken nuggets', 'chicken'), ('pollo', 'chicken'),
    ('ente', 'chicken'), ('pute', 'chicken'), ('truthahn', 'chicken'),
    ('fisch', 'fish'), ('fish', 'fish'), ('lachs', 'fish'), ('salmon', 'fish'), ('forelle', 'fish'),
    ('fischstaebchen', 'fish'), ('fish fingers', 'fish'), ('poisson', 'fish'), ('saumon', 'fish'),
    ('pescado', 'fish'), ('merluza', 'fish'), ('thunfisch', 'fish'), ('tuna', 'fish'),
    ('steak', 'meat'), ('fleisch', 'meat'), ('meat', 'meat'), ('schnitzel', 'meat'),
    ('frikadellen', 'meat'), ('buletten', 'meat'), ('hackbraten', 'meat'), ('braten', 'meat'),
    ('cordon bleu', 'meat'), ('meatballs', 'meat'), ('viande', 'meat'), ('boulettes', 'meat'),
    ('carne', 'meat'), ('albondigas', 'meat'), ('filete', 'meat'), ('rouladen', 'meat'),
    ('koettbullar', 'meat'), ('bbq', 'meat'), ('grillen', 'meat'),
    -- egg
    ('ei', 'egg'), ('eier', 'egg'), ('spiegelei', 'egg'), ('ruehrei', 'egg'), ('omelett', 'egg'),
    ('omelette', 'egg'), ('egg', 'egg'), ('eggs', 'egg'), ('oeufs', 'egg'), ('huevos', 'egg'),
    ('tortilla', 'egg'), ('shakshuka', 'egg'),
    -- falafel, fondue, raclette
    ('falafel', 'falafel'), ('fondue', 'fondue'), ('raclette', 'cheese'),
    -- pie, cake, ice cream
    ('quiche', 'pie'), ('pie', 'pie'), ('tarte', 'pie'), ('auflauf', 'pie'), ('gratin', 'potato'),
    ('kuchen', 'cake'), ('torte', 'cake'), ('cake', 'cake'), ('muffins', 'cake'), ('gateau', 'cake'),
    ('tarta', 'cake'), ('pastel', 'cake'), ('bizcocho', 'cake'),
    ('eis', 'ice_cream'), ('glace', 'ice_cream'), ('helado', 'ice_cream'), ('ice cream', 'ice_cream'),
    -- bread
    ('brot', 'bread'), ('broetchen', 'bread'), ('brotzeit', 'bread'), ('abendbrot', 'bread'),
    ('bread', 'bread'), ('pain', 'bread'), ('pan', 'bread'), ('tostadas', 'bread'),
    ('brezel', 'pretzel'), ('brezeln', 'pretzel'), ('pretzel', 'pretzel'),
    ('croissant', 'croissant'), ('croissants', 'croissant'), ('gipfeli', 'croissant'),
    -- potato
    ('kartoffeln', 'potato'), ('kartoffel', 'potato'), ('bratkartoffeln', 'potato'),
    ('kartoffelbrei', 'potato'), ('pueree', 'potato'), ('roesti', 'potato'), ('rosti', 'potato'),
    ('potatoes', 'potato'), ('potato', 'potato'), ('mash', 'potato'), ('puree', 'potato'),
    ('pommes de terre', 'potato'), ('parmentier', 'potato'), ('patatas', 'potato'), ('pure', 'potato'),
    ('ofenkartoffel', 'potato'), ('wedges', 'potato'),
    -- cheese, porridge, vegetables
    ('kaese', 'cheese'), ('cheese', 'cheese'), ('fromage', 'cheese'), ('queso', 'cheese'),
    ('porridge', 'porridge'), ('muesli', 'porridge'), ('haferbrei', 'porridge'), ('milchreis', 'porridge'),
    ('griessbrei', 'porridge'), ('oatmeal', 'porridge'), ('gachas', 'porridge'), ('arroz con leche', 'porridge'),
    ('gemuese', 'vegetables'), ('vegetables', 'vegetables'), ('veggies', 'vegetables'),
    ('legumes', 'vegetables'), ('ratatouille', 'vegetables'), ('verduras', 'vegetables'),
    ('menestra', 'vegetables'), ('brokkoli', 'vegetables'), ('broccoli', 'vegetables'),
    ('spinat', 'vegetables')
  ),
  t(word, pos) as (
    select btrim(app.fold(coalesce(p_title, ''))), 0::bigint
    union all
    select s.word, s.pos
      from regexp_split_to_table(app.fold(coalesce(p_title, '')), '[^a-z0-9-]+') with ordinality s(word, pos)
     where s.word <> ''
  )
  select w.key from w, t
   where w.word = t.word
      or (length(w.word) >= 4 and t.pos > 0 and t.word like '%' || w.word)
   order by t.pos, (w.word = t.word) desc, length(w.word) desc
   limit 1
$$;
revoke all on function app.meal_icon_for(text) from public, anon, authenticated;

alter table app.recipe
  add column icon_key text generated always as (app.meal_icon_for(title)) stored;
alter table app.meal_plan_entry
  add column icon_key text generated always as (app.meal_icon_for(free_text)) stored;

-- The family's recipes, now with a picture (a last column, additive).
create or replace view api.recipes with (security_invoker = true) as
  select r.id, r.title, r.description, r.servings_default, r.steps, r.source_url, r.tags,
         r.created_at, r.updated_at, r.icon_key
    from app.recipe r;

-- The household's cooked meals, now with a picture (a last column, additive). Otherwise as
-- 20261014130000_meal_history.sql.
create or replace view api.meal_history with (security_invoker = true) as
  with meals as (
    select e.on_date, e.id as entry_id, e.recipe_id,
           coalesce(r.title, e.free_text) as title,
           case when r.id is not null then r.icon_key else e.icon_key end as icon_key
      from app.meal_plan_entry e
      left join app.recipe r on r.id = e.recipe_id
     where e.on_date between current_date - 365 and current_date
       and coalesce(r.title, e.free_text) is not null
  ),
  keyed as (
    select m.*,
           case when m.recipe_id is not null then 'r:' || m.recipe_id::text
                else 't:' || lower(btrim(m.title)) end as group_key
      from meals m
  ),
  grouped as (
    select max(k.recipe_id::text)::uuid as recipe_id,
           (array_agg(k.title order by k.on_date desc, k.entry_id desc))[1] as title,
           (array_agg(k.icon_key order by k.on_date desc, k.entry_id desc))[1] as icon_key,
           count(*)::int as times,
           max(k.on_date) as last_on,
           min(k.on_date) as first_on
      from keyed k
     group by k.group_key
  )
  select g.recipe_id, g.title, g.times, g.last_on, g.first_on, g.icon_key
    from grouped g;

-- A wish without an icon of its own gets one from its words (a recipe wish keeps the recipe's
-- title as words), as a catalogue item does from its name. One chosen in the picker stays.
create function app.meal_wish_icon() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.icon_key := coalesce(new.icon_key, app.meal_icon_for(new.free_text));
  return new;
end $$;
revoke all on function app.meal_wish_icon() from public, anon, authenticated;

create trigger meal_wish_icon before insert or update of free_text, recipe_id, icon_key
  on app.meal_wish for each row execute function app.meal_wish_icon();

-- The wishes made before this migration.
update app.meal_wish set icon_key = app.meal_icon_for(free_text) where icon_key is null;

-- ================================================================== ageing and "von letzter Woche"

-- Whether an open wish made or last changed at p_wished is still current in its household: made
-- within the last 28 days of the household's calendar. Older ones leave the tray and the limit.
-- Called by api.meal_wish_set, which runs as the owner; api.meal_wishes says the same inline.
create function app.meal_wish_current(p_household uuid, p_wished timestamptz) returns boolean
language sql stable set search_path = '' as $$
  select (p_wished at time zone coalesce(h.timezone, 'UTC'))::date
           >= (now() at time zone coalesce(h.timezone, 'UTC'))::date - 28
    from app.household h where h.id = p_household
$$;
revoke all on function app.meal_wish_current(uuid, timestamptz) from public, anon, authenticated;

-- Open wishes made within the last four weeks, and planned ones until a week after their meal.
-- New last columns: wished_on, the household day the wish was made or last changed, and
-- earlier_week, an open wish made before this household week (Monday) began: the tray marks it
-- "von letzter Woche". A wish not planned simply stays open; nothing here is ever "declined".
create or replace view api.meal_wishes with (security_invoker = true) as
  select w.id, w.profile_id, w.recipe_id, w.free_text, w.icon_key, w.status,
         coalesce(r.title, w.free_text) as title,
         w.meal_plan_entry_id, e.on_date as planned_on, e.slot as planned_slot,
         w.created_at,
         d.wished_on,
         (w.status = 'open' and d.wished_on < d.today - (extract(isodow from d.today)::int - 1))
           as earlier_week
    from app.meal_wish w
    left join app.recipe r on r.id = w.recipe_id
    left join app.meal_plan_entry e on e.id = w.meal_plan_entry_id
    left join lateral (
      select (now() at time zone coalesce(h.timezone, 'UTC'))::date as today,
             (w.updated_at at time zone coalesce(h.timezone, 'UTC'))::date as wished_on
        from app.household h where h.id = w.household_id) d on true
   where (w.status = 'open' and d.wished_on >= d.today - 28)
      or (w.status = 'planned' and e.on_date >= d.today - 7);

-- As 20261025110000, but only current wishes count toward meals.wishes_per_week, and the one
-- changed at the limit is the newest current one: an aged wish is out of sight and out of the
-- count. Same signature and behaviour otherwise.
create or replace function api.meal_wish_set(p_actor uuid, p_recipe_id uuid default null,
  p_free_text text default null, p_icon_key text default null, p_wish uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.actor(p_actor);
  v_who    text := app.household_setting_value(a.household_id, 'meals.wishes') #>> '{}';
  v_limit  int  := (app.household_setting_value(a.household_id, 'meals.wishes_per_week') #>> '{}')::int;
  v_free   text := nullif(btrim(coalesce(p_free_text, '')), '');
  v_icon   text := nullif(p_icon_key, '');
  v_kind   text;
  v_id     uuid;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if a.profile_id is null then
    raise exception 'WW-MEAL-010 wish invalid' using errcode = '22023', hint = 'wish_invalid';
  end if;
  -- One member's wishes are written one at a time, so the limit holds under double taps.
  select p.kind into v_kind from app.profile p where p.id = a.profile_id for update;
  if v_who = 'off' or (v_who = 'children' and v_kind is distinct from 'child') then
    raise exception 'WW-MEAL-012 wishes are off' using errcode = '42501', hint = 'wishes_off';
  end if;
  if (p_recipe_id is null) = (v_free is null)
     or length(coalesce(v_free, '')) > 60
     or (v_icon is not null and v_icon !~ '^[a-z0-9_]{1,40}$')
     or (p_recipe_id is not null and not exists (
           select 1 from app.recipe r where r.id = p_recipe_id and r.household_id = a.household_id)) then
    raise exception 'WW-MEAL-010 wish invalid' using errcode = '22023', hint = 'wish_invalid';
  end if;
  -- The recipe's title is kept as words too, so deleting the recipe leaves the wish.
  if p_recipe_id is not null then
    select left(r.title, 60) into v_free from app.recipe r where r.id = p_recipe_id;
  end if;

  if p_wish is not null then
    -- Only one's own open wish changes; a planned one has gone to the kitchen.
    select w.id into v_id from app.meal_wish w
     where w.id = p_wish and w.household_id = a.household_id
       and w.profile_id = a.profile_id and w.status = 'open';
    if v_id is null then
      raise exception 'wish not found' using errcode = 'P0002', hint = 'wish_not_found';
    end if;
  elsif (select count(*) from app.meal_wish w
          where w.profile_id = a.profile_id and w.status = 'open'
            and app.meal_wish_current(a.household_id, w.updated_at)) >= v_limit then
    select w.id into v_id from app.meal_wish w
     where w.profile_id = a.profile_id and w.status = 'open'
       and app.meal_wish_current(a.household_id, w.updated_at)
     order by w.created_at desc limit 1;
  end if;

  if v_id is not null then
    update app.meal_wish set recipe_id = p_recipe_id, free_text = v_free, icon_key = v_icon,
                             updated_at = now()
     where id = v_id;
    perform app.audit(a, 'meal_wish', v_id, 'update');
  else
    insert into app.meal_wish (household_id, profile_id, recipe_id, free_text, icon_key)
    values (a.household_id, a.profile_id, p_recipe_id, v_free, v_icon)
    returning id into v_id;
    perform app.audit(a, 'meal_wish', v_id, 'create');
  end if;
  perform app.broadcast(a.household_id, 'meals');
  return jsonb_build_object('id', v_id);
end $$;

revoke all on function api.meal_wish_set(uuid, uuid, text, text, uuid) from public, anon;
grant execute on function api.meal_wish_set(uuid, uuid, text, text, uuid) to authenticated;
