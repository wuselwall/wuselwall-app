-- FR-3.8 and FR-3.7 read side (specs/07 "Meal Plan" and "Shopping List").
--
-- api.meal_history: the household's cooked meals of the last 365 days, one row per meal.
-- A meal is grouped by its recipe when the entry links one, otherwise by its free text
-- (case and surrounding spaces ignored). Only entries dated today or earlier count as
-- cooked; eating-only slots (neither recipe nor text) are not meals.
--
-- api.shopping_item_meals: the meals behind a shopping item, from source_meal_entry_ids.
-- Entries that are gone (cleared or deleted) are skipped.
--
-- Both are read-only views over the existing tables, so RLS and the device check apply.

create view api.meal_history with (security_invoker = true) as
  with meals as (
    select e.on_date, e.id as entry_id, e.recipe_id,
           coalesce(r.title, e.free_text) as title
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
  )
  select max(k.recipe_id::text)::uuid as recipe_id,
         (array_agg(k.title order by k.on_date desc, k.entry_id desc))[1] as title,
         count(*)::int as times,
         max(k.on_date) as last_on,
         min(k.on_date) as first_on
    from keyed k
   group by k.group_key;

create view api.shopping_item_meals with (security_invoker = true) as
  select i.id as item_id, e.id as meal_entry_id, e.on_date, e.slot,
         coalesce(r.title, e.free_text) as title
    from app.shopping_item i
    cross join lateral unnest(i.source_meal_entry_ids) as src(entry_id)
    join app.meal_plan_entry e on e.id = src.entry_id
    left join app.recipe r on r.id = e.recipe_id;

grant select on api.meal_history, api.shopping_item_meals to authenticated;
revoke all on api.meal_history, api.shopping_item_meals from anon;
