-- M1.4 Meals (specs/07 "Meal Plan", specs/04 "Meals", specs/21 "Meals (M1.4)", FR-3.1-3.7).
--
-- Free text is a first-class meal; a recipe is an optional enrichment that makes shopping
-- quantity-accurate. A plan entry can also exist with neither (a slot that only carries
-- eating overrides), which is why the check on recipe/free text is an exclusive-or only for
-- the API: meal_set always gives one of them, the eating correction may leave both empty.
--
-- Every write is one api function that starts with app.actor, refuses kiosks (except
-- meal_eating_set, the correction dots of the wall), writes an audit row and broadcasts
-- 'meals'. Generated shopping items broadcast 'shopping' as well.

-- ------------------------------------------------------------------ tables

create table app.recipe (
  id               uuid primary key default gen_random_uuid(),
  household_id     uuid not null references app.household on delete cascade,
  title            text not null check (length(btrim(title)) between 1 and 120),
  description      text check (description is null or length(description) <= 4000),
  servings_default int not null default 4 check (servings_default between 1 and 50),
  steps            text check (steps is null or length(steps) <= 20000),
  source_url       text check (source_url is null or length(source_url) <= 2000),
  tags             text[] not null default '{}' check (cardinality(tags) <= 20),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index on app.recipe (household_id);

create table app.recipe_ingredient (
  id              uuid primary key default gen_random_uuid(),
  household_id    uuid not null references app.household on delete cascade,
  recipe_id       uuid not null references app.recipe on delete cascade,
  position        int not null,
  -- Links to the shopping catalogue; without it generation falls back to the name.
  catalog_item_id uuid references app.catalog_item on delete set null,
  raw_name        text not null check (length(btrim(raw_name)) between 1 and 80),
  quantity        numeric check (quantity is null or quantity > 0),
  unit            text check (unit is null or length(unit) <= 20),
  note            text,
  unique (recipe_id, position)
);

create table app.meal_plan_entry (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  on_date               date not null,
  slot                  text not null check (slot in ('breakfast', 'lunch', 'dinner', 'snack')),
  recipe_id             uuid references app.recipe on delete set null,
  free_text             text check (free_text is null or length(btrim(free_text)) between 1 and 120),
  check (recipe_id is null or free_text is null),
  servings              int check (servings is null or servings between 1 and 50),
  cook_profile_id       uuid references app.profile on delete set null,
  at_time               time,
  guests                int not null default 0 check (guests between 0 and 20),
  -- {"<profile_id>": true|false}; members without a key follow the default rule (specs/07).
  eating_overrides      jsonb not null default '{}' check (jsonb_typeof(eating_overrides) = 'object'),
  -- Guards against generating the same meal twice (specs/07, step 4 of the seam).
  shopping_generated_at timestamptz,
  unique (household_id, on_date, slot)
);

-- FR-3.7: which meals put an item on the list.
alter table app.shopping_item add column source_meal_entry_ids uuid[];

-- ------------------------------------------------------------------ RLS

alter table app.recipe            enable row level security;
alter table app.recipe_ingredient enable row level security;
alter table app.meal_plan_entry   enable row level security;
alter table app.recipe            force row level security;
alter table app.recipe_ingredient force row level security;
alter table app.meal_plan_entry   force row level security;

create policy recipe_read on app.recipe for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy recipe_ingredient_read on app.recipe_ingredient for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy meal_plan_entry_read on app.meal_plan_entry for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.recipe            to postgres using (true) with check (true);
create policy owner_all on app.recipe_ingredient to postgres using (true) with check (true);
create policy owner_all on app.meal_plan_entry   to postgres using (true) with check (true);

-- No write grants: every change goes through the api functions below.
grant select on app.recipe, app.recipe_ingredient, app.meal_plan_entry to authenticated;

-- ------------------------------------------------------------------ internals: parsing

-- Each parser returns null for an absent value and raises WW-MEAL-001 for a bad one, so the
-- api functions never fail with a bare cast error.

create function app.meal_date(p_text text) returns date
language plpgsql stable set search_path = '' as $$
begin
  if coalesce(p_text, '') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;
  return p_text::date;
exception when others then
  raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
end $$;

create function app.meal_time(p_text text) returns time
language plpgsql stable set search_path = '' as $$
begin
  if nullif(btrim(coalesce(p_text, '')), '') is null then
    return null;
  end if;
  if btrim(p_text) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;
  return btrim(p_text)::time;
end $$;

create function app.meal_uuid(p_text text) returns uuid
language plpgsql immutable set search_path = '' as $$
begin
  if nullif(btrim(coalesce(p_text, '')), '') is null then
    return null;
  end if;
  if btrim(p_text) !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;
  return btrim(p_text)::uuid;
end $$;

create function app.meal_int(p_text text, p_min int, p_max int) returns int
language plpgsql immutable set search_path = '' as $$
begin
  if nullif(btrim(coalesce(p_text, '')), '') is null then
    return null;
  end if;
  if btrim(p_text) !~ '^[0-9]{1,4}$' or btrim(p_text)::int not between p_min and p_max then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;
  return btrim(p_text)::int;
end $$;

-- A decimal comma is accepted: recipes are written by a German household.
create function app.meal_quantity(p_text text) returns numeric
language plpgsql immutable set search_path = '' as $$
declare v_text text := replace(btrim(coalesce(p_text, '')), ',', '.');
begin
  if v_text = '' then
    return null;
  end if;
  if v_text !~ '^[0-9]{1,6}([.][0-9]{1,3})?$' or v_text::numeric <= 0 then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;
  return v_text::numeric;
end $$;

-- Are the overrides an object of booleans keyed by profiles of the household?
create function app.meal_overrides_valid(p_household uuid, p_value jsonb) returns boolean
language plpgsql stable set search_path = '' as $$
begin
  if jsonb_typeof(p_value) is distinct from 'object' then
    return false;
  end if;
  return not exists (
    select 1 from jsonb_each(p_value) e
     where jsonb_typeof(e.value) is distinct from 'boolean'
        or case when e.key ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
             then not exists (select 1 from app.profile p
                               where p.id = e.key::uuid and p.household_id = p_household)
             else true
           end);
end $$;

-- Only adults (guardians, or profiles of kind adult) write recipes (specs/07, FR-3.5).
create function app.meal_is_adult(a app.actor_t) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from app.profile p
                  where p.id = a.profile_id and (p.role = 'guardian' or p.kind = 'adult'))
$$;

-- ------------------------------------------------------------------ internals: shopping seam

-- The ingredients the range would put on the list, one line per (ingredient, unit), not yet
-- generated. Scaled by servings / servings_default, rounded up: one decimal for g, ml, kg and
-- l, whole numbers otherwise (nobody buys 1.33 onions). Read by the preview and by generate,
-- so the two never disagree. Output names are prefixed item_ so they cannot shadow columns.
create function app.meal_shopping_rows(p_household uuid, p_from date, p_to date)
returns table (item_key text, item_name text, item_qty numeric, item_unit text,
               item_catalog_id uuid, item_entry_ids uuid[], item_on_list boolean)
language sql stable security definer set search_path = '' as $$
  with lines as (
    select e.id as entry_id, e.on_date, i.position,
           coalesce(i.catalog_item_id::text, 'n:' || lower(i.raw_name)) as k,
           i.catalog_item_id, i.unit,
           coalesce(c.name, i.raw_name) as display_name,
           i.quantity * (coalesce(e.servings, r.servings_default)::numeric / r.servings_default) as qty
      from app.meal_plan_entry e
      join app.recipe r on r.id = e.recipe_id
      join app.recipe_ingredient i on i.recipe_id = r.id
      left join app.catalog_item c on c.id = i.catalog_item_id
     where e.household_id = p_household
       and e.on_date between p_from and p_to
       and e.shopping_generated_at is null
  ),
  grouped as (
    select l.k, l.unit,
           max(l.catalog_item_id::text)::uuid as catalog_id,
           (array_agg(l.display_name order by l.on_date, l.position))[1] as shown,
           sum(l.qty) as qty,
           array_agg(distinct l.entry_id) as entry_ids
      from lines l
     group by l.k, l.unit
  ),
  rounded as (
    select g.k, g.unit, g.catalog_id, g.shown, g.entry_ids,
           case
             when g.qty is null then null
             when g.unit in ('g', 'ml', 'kg', 'l') then trim_scale(ceil(g.qty * 10) / 10)
             else ceil(g.qty)
           end as qty
      from grouped g
  )
  select r.k || '|' || coalesce(r.unit, '') as item_key,
         r.shown as item_name,
         r.qty as item_qty,
         r.unit as item_unit,
         r.catalog_id as item_catalog_id,
         r.entry_ids as item_entry_ids,
         exists (select 1 from app.shopping_item si
                   join app.shopping_list sl on sl.id = si.list_id
                  where sl.household_id = p_household and sl.is_default
                    and si.trip_id is null and not si.checked
                    and si.folded_name = app.fold(r.shown)) as item_on_list
    from rounded r
   order by r.shown, r.unit
$$;

-- ------------------------------------------------------------------ api: reads

create view api.recipes with (security_invoker = true) as
  select r.id, r.title, r.description, r.servings_default, r.steps, r.source_url, r.tags,
         r.created_at, r.updated_at
    from app.recipe r;

create view api.recipe_ingredients with (security_invoker = true) as
  select i.id, i.recipe_id, i.position, i.catalog_item_id, i.raw_name, i.quantity, i.unit, i.note
    from app.recipe_ingredient i;

-- title: the recipe's, else the free text.
create view api.meal_plan_entries with (security_invoker = true) as
  select e.id, e.on_date, e.slot, e.recipe_id, e.free_text,
         coalesce(r.title, e.free_text) as title,
         e.servings, e.cook_profile_id, e.at_time, e.guests, e.eating_overrides,
         e.shopping_generated_at
    from app.meal_plan_entry e
    left join app.recipe r on r.id = e.recipe_id;

grant select on api.recipes, api.recipe_ingredients, api.meal_plan_entries to authenticated;
revoke all on api.recipes, api.recipe_ingredients, api.meal_plan_entries from anon;

-- The open list view gains the meals that put an item on it. Every column and grant stays.
create or replace view api.shopping_items with (security_invoker = true) as
  select i.id, i.name, i.quantity, i.checked, i.added_by, i.checked_by, i.checked_at, i.created_at,
         i.list_id, i.category_id, i.count, i.catalog_item_id, i.source_meal_entry_ids
    from app.shopping_item i
   where i.trip_id is null;

-- ------------------------------------------------------------------ api: recipes

-- Replaces the recipe as sent. An absent ingredients key keeps the set; an array replaces it.
create function api.recipe_save(p_actor uuid, p_recipe jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a          app.actor_t := app.actor(p_actor);
  v_id       uuid;
  v_update   boolean := false;
  v_title    text;
  v_desc     text;
  v_servings int;
  v_steps    text;
  v_source   text;
  v_tags     text[];
  v_has_ing  boolean;
  v_ing      jsonb;
  v_pos      int := 0;
  v_name     text;
  v_qty      numeric;
  v_unit     text;
  v_cat      uuid;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if not app.meal_is_adult(a) then
    raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
  end if;
  if jsonb_typeof(p_recipe) is distinct from 'object' then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;
  if jsonb_typeof(p_recipe -> 'ingredients') not in ('array', 'null') then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;

  v_title := btrim(coalesce(p_recipe ->> 'title', ''));
  if length(v_title) not between 1 and 120 then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;
  v_desc    := nullif(btrim(coalesce(p_recipe ->> 'description', '')), '');
  v_steps   := nullif(btrim(coalesce(p_recipe ->> 'steps', '')), '');
  v_source  := nullif(btrim(coalesce(p_recipe ->> 'source_url', '')), '');
  if length(coalesce(v_steps, '')) > 20000 or length(coalesce(v_desc, '')) > 4000
     or length(coalesce(v_source, '')) > 2000 then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;
  v_servings := coalesce(app.meal_int(p_recipe ->> 'servings_default', 1, 50), 4);

  if jsonb_typeof(p_recipe -> 'tags') = 'array' then
    v_tags := array(select btrim(t.v) from jsonb_array_elements_text(p_recipe -> 'tags') as t(v)
                     where btrim(t.v) <> '');
  else
    v_tags := '{}';
  end if;
  if cardinality(v_tags) > 20 or exists (select 1 from unnest(v_tags) t where length(t) > 40) then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;

  v_has_ing := jsonb_typeof(p_recipe -> 'ingredients') = 'array';
  if v_has_ing and jsonb_array_length(p_recipe -> 'ingredients') > 100 then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;

  if nullif(p_recipe ->> 'id', '') is not null then
    v_id := app.meal_uuid(p_recipe ->> 'id');
    perform 1 from app.recipe where id = v_id and household_id = a.household_id for update;
    if not found then
      raise exception 'recipe not found' using errcode = 'P0002', hint = 'recipe_not_found';
    end if;
    update app.recipe set title = v_title, description = v_desc, servings_default = v_servings,
           steps = v_steps, source_url = v_source, tags = v_tags, updated_at = now()
     where id = v_id;
    v_update := true;
  else
    insert into app.recipe (household_id, title, description, servings_default, steps, source_url, tags)
    values (a.household_id, v_title, v_desc, v_servings, v_steps, v_source, v_tags)
    returning id into v_id;
  end if;

  if v_has_ing then
    delete from app.recipe_ingredient where recipe_id = v_id;
    for v_ing in select value from jsonb_array_elements(p_recipe -> 'ingredients') loop
      if jsonb_typeof(v_ing) is distinct from 'object' then
        raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
      end if;
      v_name := btrim(coalesce(v_ing ->> 'raw_name', ''));
      if length(v_name) not between 1 and 80 then
        raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
      end if;
      v_qty  := app.meal_quantity(v_ing ->> 'quantity');
      v_unit := nullif(btrim(coalesce(v_ing ->> 'unit', '')), '');
      if length(coalesce(v_unit, '')) > 20 then
        raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
      end if;
      v_cat := app.meal_uuid(v_ing ->> 'catalog_item_id');
      if v_cat is not null and not exists (
           select 1 from app.catalog_item c where c.id = v_cat and c.household_id = a.household_id) then
        raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
      end if;
      v_pos := v_pos + 1;
      insert into app.recipe_ingredient (household_id, recipe_id, position, catalog_item_id,
                                         raw_name, quantity, unit, note)
      values (a.household_id, v_id, v_pos, v_cat, v_name, v_qty, v_unit,
              nullif(btrim(coalesce(v_ing ->> 'note', '')), ''));
    end loop;
  end if;

  perform app.audit(a, 'recipe', v_id, case when v_update then 'update' else 'create' end,
                    jsonb_build_object('title', v_title));
  perform app.broadcast(a.household_id, 'meals');
  return jsonb_build_object('id', v_id);
end $$;

create function api.recipe_delete(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if not app.meal_is_adult(a) then
    raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
  end if;
  delete from app.recipe where id = p_id and household_id = a.household_id;
  if not found then
    raise exception 'recipe not found' using errcode = 'P0002', hint = 'recipe_not_found';
  end if;
  perform app.audit(a, 'recipe', p_id, 'delete');
  perform app.broadcast(a.household_id, 'meals');
end $$;

-- ------------------------------------------------------------------ api: meals

-- Upsert by (date, slot). A recipe or free text, exactly one. eating_overrides are kept
-- unless the object names them.
create function api.meal_set(p_actor uuid, p_entry jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a           app.actor_t := app.actor(p_actor);
  v_date      date;
  v_slot      text;
  v_recipe    uuid;
  v_free      text;
  v_servings  int;
  v_cook      uuid;
  v_time      time;
  v_guests    int;
  v_overrides jsonb;
  v_id        uuid;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if jsonb_typeof(p_entry) is distinct from 'object' then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;

  v_date := app.meal_date(p_entry ->> 'on_date');
  v_slot := p_entry ->> 'slot';
  if v_slot is null or v_slot not in ('breakfast', 'lunch', 'dinner', 'snack') then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;

  v_recipe := app.meal_uuid(p_entry ->> 'recipe_id');
  if v_recipe is not null and not exists (
       select 1 from app.recipe r where r.id = v_recipe and r.household_id = a.household_id) then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;
  v_free := nullif(btrim(coalesce(p_entry ->> 'free_text', '')), '');
  if (v_recipe is null) = (v_free is null) or length(coalesce(v_free, '')) > 120 then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;

  v_servings := app.meal_int(p_entry ->> 'servings', 1, 50);
  v_cook     := app.meal_uuid(p_entry ->> 'cook_profile_id');
  if v_cook is not null and not exists (
       select 1 from app.profile p
        where p.id = v_cook and p.household_id = a.household_id and p.active) then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;
  v_time   := app.meal_time(p_entry ->> 'at_time');
  v_guests := coalesce(app.meal_int(p_entry ->> 'guests', 0, 20), 0);

  if p_entry ? 'eating_overrides' then
    v_overrides := case when jsonb_typeof(p_entry -> 'eating_overrides') = 'null'
                        then '{}'::jsonb else p_entry -> 'eating_overrides' end;
    if not app.meal_overrides_valid(a.household_id, v_overrides) then
      raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
    end if;
  end if;

  insert into app.meal_plan_entry (household_id, on_date, slot, recipe_id, free_text, servings,
                                   cook_profile_id, at_time, guests, eating_overrides)
  values (a.household_id, v_date, v_slot, v_recipe, v_free, v_servings, v_cook, v_time, v_guests,
          coalesce(v_overrides, '{}'::jsonb))
  on conflict (household_id, on_date, slot) do update set
    recipe_id       = excluded.recipe_id,
    free_text       = excluded.free_text,
    servings        = excluded.servings,
    cook_profile_id = excluded.cook_profile_id,
    at_time         = excluded.at_time,
    guests          = excluded.guests,
    eating_overrides = case when v_overrides is null
                            then app.meal_plan_entry.eating_overrides
                            else excluded.eating_overrides end
  returning id into v_id;

  perform app.audit(a, 'meal_plan_entry', v_id, 'set',
                    jsonb_build_object('on_date', v_date, 'slot', v_slot));
  perform app.broadcast(a.household_id, 'meals');
  return jsonb_build_object('id', v_id);
end $$;

create function api.meal_clear(p_actor uuid, p_on_date date, p_slot text) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_id uuid;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if p_on_date is null or p_slot is null or p_slot not in ('breakfast', 'lunch', 'dinner', 'snack') then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;
  delete from app.meal_plan_entry
   where household_id = a.household_id and on_date = p_on_date and slot = p_slot
  returning id into v_id;
  if found then
    perform app.audit(a, 'meal_plan_entry', v_id, 'clear',
                      jsonb_build_object('on_date', p_on_date, 'slot', p_slot));
    perform app.broadcast(a.household_id, 'meals');
  end if;
end $$;

-- Drag a meal to another slot. An occupied target swaps. The target row is removed, the
-- source moves, then the target's content (same id) takes the source's old slot.
create function api.meal_move(p_actor uuid, p_from_date date, p_from_slot text,
                              p_to_date date, p_to_slot text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.actor(p_actor);
  v_src    app.meal_plan_entry;
  v_dst    app.meal_plan_entry;
  v_has_dst boolean;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if p_from_date is null or p_to_date is null
     or p_from_slot not in ('breakfast', 'lunch', 'dinner', 'snack')
     or p_to_slot not in ('breakfast', 'lunch', 'dinner', 'snack') then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;

  select * into v_src from app.meal_plan_entry
   where household_id = a.household_id and on_date = p_from_date and slot = p_from_slot
   for update;
  if not found then
    raise exception 'meal not found' using errcode = 'P0002', hint = 'meal_not_found';
  end if;
  if p_from_date = p_to_date and p_from_slot = p_to_slot then
    return;
  end if;

  select * into v_dst from app.meal_plan_entry
   where household_id = a.household_id and on_date = p_to_date and slot = p_to_slot
   for update;
  v_has_dst := found;
  if v_has_dst then
    delete from app.meal_plan_entry where id = v_dst.id;
  end if;

  update app.meal_plan_entry set on_date = p_to_date, slot = p_to_slot where id = v_src.id;
  if v_has_dst then
    insert into app.meal_plan_entry (id, household_id, on_date, slot, recipe_id, free_text, servings,
                                     cook_profile_id, at_time, guests, eating_overrides,
                                     shopping_generated_at)
    values (v_dst.id, v_dst.household_id, p_from_date, p_from_slot, v_dst.recipe_id, v_dst.free_text,
            v_dst.servings, v_dst.cook_profile_id, v_dst.at_time, v_dst.guests, v_dst.eating_overrides,
            v_dst.shopping_generated_at);
  end if;

  perform app.audit(a, 'meal_plan_entry', v_src.id, 'move',
                    jsonb_build_object('from', jsonb_build_array(p_from_date, p_from_slot),
                                       'to', jsonb_build_array(p_to_date, p_to_slot),
                                       'swapped', v_has_dst));
  perform app.broadcast(a.household_id, 'meals');
end $$;

-- The correction dots of the kiosk: allowed on every device class. null removes the override;
-- a meal row is created when a person is first corrected for a slot that has none.
create function api.meal_eating_set(p_actor uuid, p_on_date date, p_slot text,
                                    p_profile_id uuid, p_eating boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a     app.actor_t := app.actor(p_actor);
  v_id  uuid;
  v_key text := p_profile_id::text;
begin
  if p_on_date is null or p_slot is null or p_slot not in ('breakfast', 'lunch', 'dinner', 'snack')
     or p_profile_id is null then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;
  if not exists (select 1 from app.profile p where p.id = p_profile_id and p.household_id = a.household_id) then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;

  if p_eating is null then
    update app.meal_plan_entry set eating_overrides = eating_overrides - v_key
     where household_id = a.household_id and on_date = p_on_date and slot = p_slot
    returning id into v_id;
    if not found then
      return;
    end if;
  else
    insert into app.meal_plan_entry (household_id, on_date, slot, eating_overrides)
    values (a.household_id, p_on_date, p_slot, jsonb_build_object(v_key, p_eating))
    on conflict (household_id, on_date, slot) do update
      set eating_overrides = app.meal_plan_entry.eating_overrides || jsonb_build_object(v_key, p_eating)
    returning id into v_id;
  end if;

  perform app.audit(a, 'meal_plan_entry', v_id, 'eating',
                    jsonb_build_object('on_date', p_on_date, 'slot', p_slot,
                                       'profile_id', p_profile_id, 'eating', p_eating));
  perform app.broadcast(a.household_id, 'meals');
end $$;

-- ------------------------------------------------------------------ api: shopping seam

-- The mandatory preview (specs/07, the seam). Lines not yet generated, scaled and rounded.
create function api.meal_shopping_preview(p_actor uuid, p_from date, p_to date) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a     app.actor_t := app.actor(p_actor);
  v_out jsonb;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 92 then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'key', r.item_key, 'name', r.item_name, 'quantity', r.item_qty, 'unit', r.item_unit,
           'catalog_item_id', r.item_catalog_id, 'meal_entry_ids', to_jsonb(r.item_entry_ids),
           'already_on_list', r.item_on_list)
         order by r.item_name, r.item_unit), '[]'::jsonb)
    into v_out
    from app.meal_shopping_rows(a.household_id, p_from, p_to) r;
  return v_out;
end $$;

-- Adds the chosen lines of the preview to the default list. Each item carries its quantity as
-- text ("1250 g"); a line that merges into an open item adds its meals to that item. Every
-- meal that contributed to a chosen line is stamped, so a second run adds nothing.
create function api.meal_shopping_generate(p_actor uuid, p_from date, p_to date, p_keys text[])
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.actor(p_actor);
  v_list   uuid;
  r        record;
  v_text   text;
  v_item   uuid;
  v_used   uuid[] := '{}';
  v_added  int := 0;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 92 then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;

  -- Serialises two runs over the same meals: the second waits, then finds them stamped.
  perform 1 from app.meal_plan_entry
   where household_id = a.household_id and on_date between p_from and p_to
   for update;

  v_list := app.shopping_target_list(a.household_id, null);
  for r in select * from app.meal_shopping_rows(a.household_id, p_from, p_to)
            where item_key = any(coalesce(p_keys, '{}'::text[])) loop
    v_text := nullif(left(concat_ws(' ',
                case when r.item_qty is not null then trim_scale(r.item_qty)::text end,
                r.item_unit), 40), '');
    v_item := app.shopping_do_add(a, v_list, r.item_name, v_text);
    update app.shopping_item set source_meal_entry_ids = array(
             select distinct x from unnest(coalesce(source_meal_entry_ids, '{}'::uuid[]) || r.item_entry_ids) as x)
     where id = v_item;
    v_used := v_used || r.item_entry_ids;
    v_added := v_added + 1;
  end loop;

  if v_added > 0 then
    update app.meal_plan_entry set shopping_generated_at = now()
     where id = any(v_used) and household_id = a.household_id and shopping_generated_at is null;
    perform app.audit(a, 'shopping_list', v_list, 'meal_generate',
                      jsonb_build_object('added', v_added, 'from', p_from, 'to', p_to));
    perform app.broadcast(a.household_id, 'shopping');
    perform app.broadcast(a.household_id, 'meals');
  end if;
  return jsonb_build_object('added', v_added);
end $$;

-- ------------------------------------------------------------------ grants

revoke all on function api.recipe_save(uuid, jsonb), api.recipe_delete(uuid, uuid),
  api.meal_set(uuid, jsonb), api.meal_clear(uuid, date, text),
  api.meal_move(uuid, date, text, date, text), api.meal_eating_set(uuid, date, text, uuid, boolean),
  api.meal_shopping_preview(uuid, date, date), api.meal_shopping_generate(uuid, date, date, text[])
  from public, anon;
grant execute on function api.recipe_save(uuid, jsonb), api.recipe_delete(uuid, uuid),
  api.meal_set(uuid, jsonb), api.meal_clear(uuid, date, text),
  api.meal_move(uuid, date, text, date, text), api.meal_eating_set(uuid, date, text, uuid, boolean),
  api.meal_shopping_preview(uuid, date, date), api.meal_shopping_generate(uuid, date, date, text[])
  to authenticated;

-- Internal: PUBLIC may execute new app functions unless revoked here.
revoke execute on function app.meal_date(text), app.meal_time(text), app.meal_uuid(text),
  app.meal_int(text, int, int), app.meal_quantity(text), app.meal_overrides_valid(uuid, jsonb),
  app.meal_is_adult(app.actor_t), app.meal_shopping_rows(uuid, date, date)
  from public, anon, authenticated;
