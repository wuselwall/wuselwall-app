-- A lighter day, after its review: fixes to Wunschessen and the Wochenrückblick (specs/27).
--
--   * api.meal_wish_plan no longer overwrites a planned meal by surprise. A slot that already
--     has a meal is refused with `slot_taken` unless the caller passes p_replace => true; a
--     replacement keeps the meal's servings, cook, time and guests, and gives a wish that was
--     on that meal back to its wisher (open again), also when the dish stays the same.
--   * api.meal_wish_set takes the wish to change (p_wish), so a member with several open wishes
--     (meals.wishes_per_week > 1) changes the one they mean instead of adding another. Without
--     it the call behaves as before: a new wish, or the newest replaced once at the limit.
--   * api.week_review picks each member's highlight in the order of specs/27: a badge, a streak
--     reaching a multiple of 7 this week, a reward, a wish meal eaten, a day with every chore
--     done; then the quieter facts as before. Same signature, same document.
--
-- Additive for api_version: both functions gain a last parameter with a default, so the
-- previous app's calls (named arguments, without it) reach the same function and behave as
-- they did, except that planning onto a taken slot now asks first instead of overwriting.
--
-- Errors (hint in brackets):
--   WW-MEAL-013 slot taken      (slot_taken)    the day and meal already have a dish

-- ================================================================== Wunschessen: planning

drop function api.meal_wish_plan(uuid, uuid, date, text);

-- Puts a wish on the plan: the meal of that day and slot becomes the wish (api.meal_set, so the
-- usual rules apply) and carries the wisher, and the wish is planned. A slot that already has a
-- meal is refused unless p_replace; replacing keeps what the meal had besides its dish.
create function api.meal_wish_plan(p_actor uuid, p_wish uuid, p_on_date date, p_slot text,
                                   p_replace boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  w       app.meal_wish;
  v_cur   app.meal_plan_entry;
  v_exists boolean;
  v_taken boolean;
  v_given uuid[] := '{}';
  v_entry uuid;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  select * into w from app.meal_wish where id = p_wish and household_id = a.household_id for update;
  if not found or w.status <> 'open' then
    raise exception 'wish not found' using errcode = 'P0002', hint = 'wish_not_found';
  end if;
  if p_on_date is null or p_slot is null or p_slot not in ('breakfast', 'lunch', 'dinner', 'snack') then
    raise exception 'WW-MEAL-001 meal invalid' using errcode = '22023', hint = 'meal_invalid';
  end if;

  select * into v_cur from app.meal_plan_entry
   where household_id = a.household_id and on_date = p_on_date and slot = p_slot
   for update;
  v_exists := found;
  -- A slot that only holds who eats along has no dish to lose.
  v_taken := v_exists and (v_cur.recipe_id is not null or v_cur.free_text is not null);
  if v_taken and not coalesce(p_replace, false) then
    raise exception 'WW-MEAL-013 slot taken' using errcode = '23505', hint = 'slot_taken';
  end if;
  if v_exists then
    -- The wish that was on this meal goes back to its wisher, whatever the new dish is: the
    -- trigger only notices a change of dish, and one meal carries one wish.
    with given as (
      update app.meal_wish set status = 'open', meal_plan_entry_id = null, updated_at = now()
       where meal_plan_entry_id = v_cur.id and status = 'planned'
      returning id)
    select coalesce(array_agg(id), '{}') into v_given from given;
    update app.meal_plan_entry set wished_by_profile_id = null where id = v_cur.id;
  end if;

  v_entry := (api.meal_set(p_actor, jsonb_strip_nulls(jsonb_build_object(
    'on_date', p_on_date, 'slot', p_slot,
    'recipe_id', w.recipe_id,
    'free_text', case when w.recipe_id is null then w.free_text end,
    -- What the meal had besides its dish stays: who cooks, when, for how many.
    'servings', v_cur.servings,
    'cook_profile_id', (select p.id from app.profile p where p.id = v_cur.cook_profile_id and p.active),
    'at_time', to_char(v_cur.at_time, 'HH24:MI'),
    'guests', v_cur.guests))) ->> 'id')::uuid;
  update app.meal_plan_entry set wished_by_profile_id = w.profile_id where id = v_entry;
  update app.meal_wish set status = 'planned', meal_plan_entry_id = v_entry, updated_at = now()
   where id = p_wish;
  perform app.audit(a, 'meal_wish', p_wish, 'plan',
                    jsonb_build_object('on_date', p_on_date, 'slot', p_slot, 'replaced', v_taken,
                                       'given_back', to_jsonb(v_given)));
  perform app.broadcast(a.household_id, 'meals');
  return jsonb_build_object('id', v_entry);
end $$;

revoke all on function api.meal_wish_plan(uuid, uuid, date, text, boolean) from public, anon;
grant execute on function api.meal_wish_plan(uuid, uuid, date, text, boolean) to authenticated;

-- ================================================================== Wunschessen: changing a wish

drop function api.meal_wish_set(uuid, uuid, text, text);

-- Creates or changes the actor's own open wish: a recipe of the household, or a few words with
-- an optional icon. Who may wish is meals.wishes; how many open at once, meals.wishes_per_week.
-- p_wish names the open wish to change; without it a new wish is made, or, once the actor has
-- as many open as allowed, their newest changes (the previous app's behaviour).
create function api.meal_wish_set(p_actor uuid, p_recipe_id uuid default null,
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
          where w.profile_id = a.profile_id and w.status = 'open') >= v_limit then
    select w.id into v_id from app.meal_wish w
     where w.profile_id = a.profile_id and w.status = 'open'
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

-- ================================================================== Wochenrückblick

-- The look back at one week (Monday p_week_start, default this household week), as one JSON
-- document the wall and the phones read alike (specs/27 "Wochenrückblick"):
--   chores_done   the family's chores done that week: one number, the family's
--   members       one highlight for every active member, in board order; a highlight is a kind
--                 and a title, never a number another member's line could be compared with
--   meals         the week's lunches and dinners, wishes marked, recipes cooked the first time
-- Traditions and next week's countdowns come from the occurrences, which the app already reads.
-- Never in it: a balance, a chore not done, a missed streak.
create or replace function api.week_review(p_week_start date default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_household uuid := app.jwt_household();
  v_tz        text;
  v_today     date;
  v_from      date;
  v_to        date;
begin
  if v_household is null or not app.device_ok() then
    raise exception 'not allowed' using errcode = '42501', hint = 'not_allowed';
  end if;
  select h.timezone into v_tz from app.household h where h.id = v_household;
  v_today := (now() at time zone coalesce(v_tz, 'UTC'))::date;
  v_from := coalesce(p_week_start, v_today - (extract(isodow from v_today)::int - 1));
  v_from := v_from - (extract(isodow from v_from)::int - 1);
  v_to := v_from + 6;

  return jsonb_build_object(
    'week_start', v_from,
    'chores_done', (select count(*) from app.task_instance t
                     where t.household_id = v_household and t.status in ('done', 'verified')
                       and t.due_on between v_from and v_to),
    'members', coalesce((
      select jsonb_agg(m.line order by m.sort_order, m.id)
        from (
          select p.id, p.sort_order,
                 jsonb_build_object('profile_id', p.id, 'highlight', coalesce(
                   -- 1. a badge earned
                   (select jsonb_build_object('kind', 'badge', 'title', d.title, 'icon_key', d.icon_key)
                      from app.badge_award b join app.badge_definition d on d.id = b.badge_definition_id
                     where b.profile_id = p.id
                       and (b.awarded_at at time zone coalesce(v_tz, 'UTC'))::date between v_from and v_to
                     order by b.awarded_at desc limit 1),
                   -- 2. a streak that reached a multiple of 7 this week: the chain grew by one for
                   --    each due day done this week, so it passed a multiple of 7 when its length
                   --    now is less than that many past one.
                   (select jsonb_build_object('kind', 'streak', 'title', td.title, 'icon_key', td.icon_key)
                      from app.streak s join app.task_definition td on td.id = s.definition_id
                     where s.profile_id = p.id and s.current_length >= 7
                       and s.last_completed_on between v_from and v_to
                       and s.current_length % 7 < (
                         select count(*) from app.task_instance t
                          where t.household_id = v_household and t.assigned_profile_id = p.id
                            and t.definition_id = s.definition_id
                            and t.status in ('done', 'verified')
                            and t.due_on between v_from and s.last_completed_on)
                     order by s.current_length desc limit 1),
                   -- 3. a reward redeemed
                   (select jsonb_build_object('kind', 'reward', 'title', r.title, 'icon_key', r.icon_key)
                      from app.reward_redemption x join app.reward r on r.id = x.reward_id
                     where x.profile_id = p.id and x.status in ('approved', 'fulfilled')
                       and (coalesce(x.decided_at, x.requested_at) at time zone coalesce(v_tz, 'UTC'))::date
                           between v_from and v_to
                     order by x.decided_at desc nulls last limit 1),
                   -- 4. their wish was on the table: a wish that was planned, on a day that has come
                   (select jsonb_build_object('kind', 'wish', 'title', coalesce(rc.title, e.free_text))
                      from app.meal_plan_entry e left join app.recipe rc on rc.id = e.recipe_id
                     where e.household_id = v_household and e.wished_by_profile_id = p.id
                       and e.on_date between v_from and least(v_to, v_today)
                       and exists (select 1 from app.meal_wish w
                                    where w.meal_plan_entry_id = e.id and w.profile_id = p.id
                                      and w.status = 'planned')
                     order by e.on_date limit 1),
                   -- 5. every chore of a day done
                   (select jsonb_build_object('kind', 'all_done')
                      where exists (
                        select 1 from app.task_instance t
                         where t.household_id = v_household and t.assigned_profile_id = p.id
                           and t.due_on between v_from and v_to
                         group by t.due_on
                        having bool_and(t.status in ('done', 'verified')))),
                   -- 6. they cooked
                   (select jsonb_build_object('kind', 'cooked', 'title', coalesce(rc.title, e.free_text))
                      from app.meal_plan_entry e left join app.recipe rc on rc.id = e.recipe_id
                     where e.household_id = v_household and e.cook_profile_id = p.id
                       and e.on_date between v_from and v_to
                     order by e.on_date desc limit 1),
                   -- 7. they helped
                   (select jsonb_build_object('kind', 'helped')
                      where exists (select 1 from app.task_instance t
                                     where t.household_id = v_household
                                       and t.completed_by_profile_id = p.id
                                       and t.due_on between v_from and v_to)),
                   -- 8. always true, never a judgement
                   jsonb_build_object('kind', 'here'))) as line
            from app.profile p
           where p.household_id = v_household and p.active) m), '[]'::jsonb),
    'meals', coalesce((
      select jsonb_agg(jsonb_build_object(
               'on_date', e.on_date, 'slot', e.slot, 'title', coalesce(r.title, e.free_text),
               'wished_by_profile_id', e.wished_by_profile_id,
               'first_time', e.recipe_id is not null and not exists (
                 select 1 from app.meal_plan_entry o
                  where o.recipe_id = e.recipe_id and o.on_date < v_from))
             order by e.on_date, e.slot)
        from app.meal_plan_entry e left join app.recipe r on r.id = e.recipe_id
       where e.household_id = v_household and e.on_date between v_from and v_to
         and e.slot in ('lunch', 'dinner')), '[]'::jsonb));
end $$;

revoke all on function api.week_review(date) from public, anon;
grant execute on function api.week_review(date) to authenticated;
