-- Catalogue pictures (specs/07): the server picks an icon_key from the item's name, German and
-- English. The app shows its bundled picture for the key, and the category icon for a key it
-- does not know or for a null. No api change: api.shopping_catalog already returns icon_key, so
-- this needs no api_version bump, and the previous app release simply ignores it.

-- Matching, in order: the whole name, then its last word (after a space, hyphen or slash:
-- "Bio-Milch", "olive oil"), then the longest known word the last word ends with, at least 3
-- letters (German compounds: Vollkornbrot, Orangensaft). Exact matches come first, so
-- "Zahnpasta" is toothpaste, not pasta. Every word is folded (app.fold): lower case, umlauts as
-- ae/oe/ue, ß as ss.
create function app.catalog_icon_for(p_folded text) returns text
language sql immutable parallel safe set search_path = '' as $$
  with w(word, key) as (values
    -- milk
    ('milch', 'milk'), ('milk', 'milk'), ('sahne', 'milk'), ('rahm', 'milk'), ('cream', 'milk'), ('kefir', 'milk'),
    -- cheese
    ('kaese', 'cheese'), ('cheese', 'cheese'), ('parmesan', 'cheese'), ('mozzarella', 'cheese'),
    ('gouda', 'cheese'), ('emmentaler', 'cheese'), ('feta', 'cheese'), ('cheddar', 'cheese'),
    -- butter
    ('butter', 'butter'), ('margarine', 'butter'),
    -- egg
    ('ei', 'egg'), ('eier', 'egg'), ('egg', 'egg'), ('eggs', 'egg'),
    -- bowl
    ('joghurt', 'bowl'), ('jogurt', 'bowl'), ('yoghurt', 'bowl'), ('yogurt', 'bowl'), ('quark', 'bowl'),
    ('skyr', 'bowl'), ('muesli', 'bowl'), ('cornflakes', 'bowl'), ('haferflocken', 'bowl'),
    ('cereal', 'bowl'), ('porridge', 'bowl'), ('oats', 'bowl'),
    -- bread
    ('brot', 'bread'), ('bread', 'bread'), ('toast', 'bread'), ('broetchen', 'bread'), ('semmeln', 'bread'),
    ('weggli', 'bread'), ('rolls', 'bread'), ('buns', 'bread'),
    -- baguette
    ('baguette', 'baguette'),
    -- pretzel
    ('brezel', 'pretzel'), ('brezeln', 'pretzel'), ('pretzel', 'pretzel'), ('pretzels', 'pretzel'),
    -- croissant
    ('croissant', 'croissant'), ('croissants', 'croissant'), ('gipfeli', 'croissant'),
    -- apple
    ('apfel', 'apple'), ('aepfel', 'apple'), ('apple', 'apple'), ('apples', 'apple'),
    -- pear
    ('birne', 'pear'), ('birnen', 'pear'), ('pear', 'pear'), ('pears', 'pear'),
    -- banana
    ('banane', 'banana'), ('bananen', 'banana'), ('banana', 'banana'), ('bananas', 'banana'),
    -- orange
    ('orange', 'orange'), ('orangen', 'orange'), ('mandarine', 'orange'), ('mandarinen', 'orange'),
    ('clementine', 'orange'), ('clementinen', 'orange'), ('oranges', 'orange'), ('mandarins', 'orange'),
    ('satsumas', 'orange'),
    -- lemon
    ('zitrone', 'lemon'), ('zitronen', 'lemon'), ('limette', 'lemon'), ('limetten', 'lemon'),
    ('lemon', 'lemon'), ('lemons', 'lemon'), ('lime', 'lemon'), ('limes', 'lemon'),
    -- grapes
    ('trauben', 'grapes'), ('grapes', 'grapes'),
    -- strawberry
    ('erdbeere', 'strawberry'), ('erdbeeren', 'strawberry'), ('beeren', 'strawberry'),
    ('strawberry', 'strawberry'), ('strawberries', 'strawberry'), ('berries', 'strawberry'),
    -- tomato
    ('tomate', 'tomato'), ('tomaten', 'tomato'), ('tomato', 'tomato'), ('tomatoes', 'tomato'),
    -- cucumber
    ('gurke', 'cucumber'), ('gurken', 'cucumber'), ('cucumber', 'cucumber'), ('cucumbers', 'cucumber'),
    -- carrot
    ('karotte', 'carrot'), ('karotten', 'carrot'), ('moehre', 'carrot'), ('moehren', 'carrot'),
    ('ruebli', 'carrot'), ('carrot', 'carrot'), ('carrots', 'carrot'),
    -- potato
    ('kartoffel', 'potato'), ('kartoffeln', 'potato'), ('erdaepfel', 'potato'), ('potato', 'potato'),
    ('potatoes', 'potato'),
    -- onion
    ('zwiebel', 'onion'), ('zwiebeln', 'onion'), ('onion', 'onion'), ('onions', 'onion'),
    -- garlic
    ('knoblauch', 'garlic'), ('garlic', 'garlic'),
    -- bell pepper
    ('paprika', 'bell_pepper'), ('peppers', 'bell_pepper'),
    -- chili
    ('chili', 'chili'), ('chilis', 'chili'), ('chilli', 'chili'), ('chillies', 'chili'),
    -- broccoli
    ('brokkoli', 'broccoli'), ('broccoli', 'broccoli'),
    -- lettuce
    ('salat', 'lettuce'), ('spinat', 'lettuce'), ('rucola', 'lettuce'), ('lettuce', 'lettuce'),
    ('salad', 'lettuce'), ('spinach', 'lettuce'),
    -- mushroom
    ('pilze', 'mushroom'), ('champignons', 'mushroom'), ('mushroom', 'mushroom'), ('mushrooms', 'mushroom'),
    -- avocado
    ('avocado', 'avocado'), ('avocados', 'avocado'),
    -- corn
    ('mais', 'corn'), ('corn', 'corn'), ('sweetcorn', 'corn'),
    -- peas
    ('erbsen', 'peas'), ('peas', 'peas'),
    -- beans
    ('bohnen', 'beans'), ('beans', 'beans'),
    -- pasta
    ('nudeln', 'pasta'), ('pasta', 'pasta'), ('spaghetti', 'pasta'), ('penne', 'pasta'), ('fusilli', 'pasta'),
    ('spaetzle', 'pasta'), ('noodles', 'pasta'), ('lasagne', 'pasta'),
    -- rice
    ('reis', 'rice'), ('rice', 'rice'),
    -- salt
    ('salz', 'salt'), ('pfeffer', 'salt'), ('gewuerze', 'salt'), ('salt', 'salt'),
    -- honey
    ('honig', 'honey'), ('marmelade', 'honey'), ('konfituere', 'honey'), ('honey', 'honey'), ('jam', 'honey'),
    -- oil
    ('oel', 'oil'), ('oliven', 'oil'), ('oil', 'oil'), ('olives', 'oil'),
    -- nuts
    ('nuesse', 'nuts'), ('mandeln', 'nuts'), ('erdnussbutter', 'nuts'), ('nuts', 'nuts'),
    ('peanuts', 'nuts'), ('almonds', 'nuts'), ('peanut butter', 'nuts'),
    -- chocolate
    ('schokolade', 'chocolate'), ('schoggi', 'chocolate'), ('chocolate', 'chocolate'),
    -- candy
    ('gummibaerchen', 'candy'), ('suessigkeiten', 'candy'), ('bonbons', 'candy'), ('gummy bears', 'candy'),
    ('sweets', 'candy'), ('candy', 'candy'),
    -- cookie
    ('kekse', 'cookie'), ('guetzli', 'cookie'), ('cookies', 'cookie'), ('biscuits', 'cookie'),
    -- cake
    ('kuchen', 'cake'), ('torte', 'cake'), ('cake', 'cake'),
    -- ice cream
    ('eis', 'ice_cream'), ('glace', 'ice_cream'), ('ice cream', 'ice_cream'),
    -- pizza
    ('pizza', 'pizza'),
    -- fries
    ('pommes', 'fries'), ('chips', 'fries'), ('fries', 'fries'), ('crisps', 'fries'),
    -- chicken
    ('haehnchen', 'chicken'), ('haehnchenbrust', 'chicken'), ('huhn', 'chicken'), ('poulet', 'chicken'),
    ('chicken', 'chicken'), ('chicken breast', 'chicken'),
    -- meat
    ('fleisch', 'meat'), ('hack', 'meat'), ('hackfleisch', 'meat'), ('gehacktes', 'meat'), ('steak', 'meat'),
    ('schnitzel', 'meat'), ('braten', 'meat'), ('mince', 'meat'), ('beef', 'meat'), ('meat', 'meat'),
    ('pork', 'meat'), ('lamb', 'meat'),
    -- sausage
    ('wurst', 'sausage'), ('wuerstchen', 'sausage'), ('salami', 'sausage'), ('sausage', 'sausage'),
    ('sausages', 'sausage'),
    -- bacon
    ('speck', 'bacon'), ('schinken', 'bacon'), ('bacon', 'bacon'), ('ham', 'bacon'),
    -- fish
    ('fisch', 'fish'), ('lachs', 'fish'), ('fischstaebchen', 'fish'), ('fish', 'fish'), ('salmon', 'fish'),
    ('tuna', 'fish'), ('fish fingers', 'fish'),
    -- coffee
    ('kaffee', 'coffee'), ('espresso', 'coffee'), ('coffee', 'coffee'),
    -- tea
    ('tee', 'tea'), ('tea', 'tea'),
    -- juice
    ('saft', 'juice'), ('juice', 'juice'),
    -- water
    ('wasser', 'water'), ('sprudel', 'water'), ('water', 'water'),
    -- soda
    ('limo', 'soda'), ('limonade', 'soda'), ('cola', 'soda'), ('soda', 'soda'), ('lemonade', 'soda'),
    ('coke', 'soda'),
    -- beer
    ('bier', 'beer'), ('beer', 'beer'),
    -- wine
    ('wein', 'wine'), ('wine', 'wine'),
    -- tin
    ('konserven', 'tin'), ('ketchup', 'tin'), ('tomatenmark', 'tin'), ('passata', 'tin'),
    ('dosentomaten', 'tin'), ('canned tomatoes', 'tin'),
    -- toilet paper
    ('toilettenpapier', 'toilet_paper'), ('klopapier', 'toilet_paper'), ('wc-papier', 'toilet_paper'),
    ('kuechenrolle', 'toilet_paper'), ('kuechenpapier', 'toilet_paper'), ('taschentuecher', 'toilet_paper'),
    ('toilet paper', 'toilet_paper'), ('toilet roll', 'toilet_paper'), ('toilet rolls', 'toilet_paper'),
    ('kitchen roll', 'toilet_paper'), ('tissues', 'toilet_paper'),
    -- soap
    ('seife', 'soap'), ('soap', 'soap'),
    -- toothbrush
    ('zahnbuerste', 'toothbrush'), ('zahnpasta', 'toothbrush'), ('zahncreme', 'toothbrush'),
    ('toothbrush', 'toothbrush'), ('toothpaste', 'toothbrush'),
    -- lotion
    ('shampoo', 'lotion'), ('duschgel', 'lotion'), ('sonnencreme', 'lotion'), ('handcreme', 'lotion'),
    ('bodylotion', 'lotion'), ('lotion', 'lotion'), ('shower gel', 'lotion'), ('conditioner', 'lotion'),
    ('sun cream', 'lotion'),
    -- sponge
    ('schwamm', 'sponge'), ('schwaemme', 'sponge'), ('spuelmittel', 'sponge'), ('putzmittel', 'sponge'),
    ('spuelmaschinentabs', 'sponge'), ('spuelmaschinentabletten', 'sponge'), ('geschirrspueltabs', 'sponge'),
    ('sponge', 'sponge'), ('sponges', 'sponge'), ('washing-up liquid', 'sponge'), ('dish soap', 'sponge'),
    ('dishwasher tablets', 'sponge'),
    -- baby bottle
    ('babynahrung', 'baby_bottle'), ('babybrei', 'baby_bottle'), ('baby food', 'baby_bottle'),
    -- trash
    ('muellbeutel', 'trash'), ('muellsaecke', 'trash'), ('bin bags', 'trash'), ('trash bags', 'trash'),
    -- battery
    ('batterie', 'battery'), ('batterien', 'battery'), ('battery', 'battery'), ('batteries', 'battery'),
    -- light bulb
    ('gluehbirne', 'light_bulb'), ('gluehbirnen', 'light_bulb'), ('light bulb', 'light_bulb'),
    ('light bulbs', 'light_bulb'),
    -- plaster
    ('pflaster', 'plaster'), ('plasters', 'plaster'),
    -- pill
    ('medikamente', 'pill'), ('vitamine', 'pill'), ('ibuprofen', 'pill'), ('paracetamol', 'pill'),
    ('aspirin', 'pill'), ('pills', 'pill'), ('vitamins', 'pill'), ('painkillers', 'pill'), ('medicine', 'pill')
  ),
  n(whole, last) as (
    select btrim(p_folded), regexp_replace(btrim(p_folded), '^.*[[:space:]/-]', '')
  )
  select w.key from w, n
   where w.word = n.whole
      or w.word = n.last
      or (length(w.word) >= 3 and n.last like '%' || w.word)
   order by (w.word = n.whole) desc, (w.word = n.last) desc, length(w.word) desc
   limit 1
$$;

-- A new catalogue item gets its picture from its name; one the family has given a key keeps it.
-- Definer, like the other triggers: it has no caller privileges of its own to rely on.
create function app.catalog_item_icon() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.icon_key := coalesce(new.icon_key, app.catalog_icon_for(new.folded_name));
  return new;
end $$;

create trigger catalog_item_icon before insert on app.catalog_item
  for each row execute function app.catalog_item_icon();

revoke execute on function app.catalog_icon_for(text), app.catalog_item_icon() from public, anon, authenticated;

-- Items the household bought before this migration.
update app.catalog_item set icon_key = app.catalog_icon_for(folded_name) where icon_key is null;
