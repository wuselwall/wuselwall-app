-- A lighter day: the family rituals (ADR-020, specs/27).
--
--   * Birthdays: profile.birthday, written by api.member_update (Q50, specs/27 "Birthdays").
--   * Events gain an icon, a countdown flag ("Darauf freuen wir uns") and a tradition flag;
--     a tradition may carry a meal (app.tradition_meal). api.event_save keeps its signature:
--     the original moves to app.event_save_core and the new one wraps it, writing the flags in
--     the same transaction. A tradition always reaches the board (importance 'key').
--   * Wunschessen: app.meal_wish and meal_plan_entry.wished_by_profile_id.
--   * Tischfrage: app.table_question holds the family's own questions and the bundled ones it
--     hides. Nothing about answers is ever stored.
--   * Wochenrückblick: api.week_review, a read function over existing data.
--
-- Rules every ritual follows (specs/27): it creates no task, no points, no streak and no
-- "missed" state; nothing ranks or counts one member against another.
--
-- Additive for api_version: columns with defaults, new tables, views gain columns at their end,
-- new functions; api.member_update gains a last parameter with a default; api.event_save keeps
-- its signature and ignores keys an older app does not send. The previous app release works
-- unchanged.
--
-- Errors (hint in brackets):
--   birthday invalid            (birthday_invalid)
--   WW-CAL-001 invalid event    (event_invalid)      a bad icon, flag or tradition meal
--   WW-MEAL-010 wish invalid    (wish_invalid)
--   WW-MEAL-011 too many wishes (wish_limit)         more open wishes than meals.wishes_per_week
--   WW-MEAL-012 wishes are off  (wishes_off)         meals.wishes says this member may not wish
--   wish not found              (wish_not_found)
--   WW-RIT-001 question invalid (question_invalid)
--   question not found          (question_not_found)

-- ================================================================== birthdays

alter table app.profile add column birthday date
  check (birthday is null or birthday between date '1900-01-01' and date '2100-12-31');
grant select (birthday) on app.profile to authenticated;

-- The birthday is on the wall and dresses Wusel up, so a change wakes the screens too.
drop trigger profile_broadcast on app.profile;
create trigger profile_broadcast
  after insert or update of display_name, color, role, active, sort_order, kind,
                            default_presence_state, default_presence_label, avatar_key, birthday
  or delete on app.profile
  for each row execute function app.profile_broadcast();

create or replace view api.members with (security_invoker = true) as
  select id, household_id, display_name, color, role, active,
         sort_order, kind, default_presence_state, default_presence_label,
         app.profile_has_account(id) as has_account,
         avatar_key, birthday
    from app.profile;

-- The same function with a birthday at the end: 'YYYY-MM-DD', '' to clear, null to keep. A
-- member may set their own; anyone else's is a guardian's.
drop function api.member_update(uuid, uuid, text, text, text, text);
create function api.member_update(
  p_actor uuid, p_profile uuid, p_display_name text default null, p_color text default null,
  p_kind text default null, p_avatar_key text default null, p_birthday text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v      app.profile := app.member_of(a, p_profile);
  v_name text := nullif(btrim(coalesce(p_display_name, '')), '');
  v_birthday date;
  v_diff jsonb := '{}'::jsonb;
begin
  if a.profile_id <> p_profile or p_kind is not null then
    perform app.require_guardian(a);
  end if;
  if p_display_name is not null then
    if v_name is null or length(v_name) > 40 then
      raise exception 'name invalid' using errcode = '22023', hint = 'name_invalid';
    end if;
    v_diff := v_diff || jsonb_build_object('display_name', v_name);
  end if;
  if p_color is not null then
    if p_color !~ '^#[0-9A-Fa-f]{6}$' then
      raise exception 'colour invalid' using errcode = '22023', hint = 'color_invalid';
    end if;
    v_diff := v_diff || jsonb_build_object('color', upper(p_color));
  end if;
  if p_kind is not null then
    if p_kind not in ('child', 'adult') then
      raise exception 'kind invalid' using errcode = '22023', hint = 'kind_invalid';
    end if;
    -- Guardians are adults (ADR-014), and so is anyone with an account.
    if p_kind = 'child' and (v.role = 'guardian' or v.auth_user_id is not null) then
      raise exception 'an adult with an account or a guardian role stays an adult'
        using errcode = '22023', hint = 'kind_adult_required';
    end if;
    v_diff := v_diff || jsonb_build_object('kind', p_kind);
  end if;
  if p_avatar_key is not null then
    if p_avatar_key <> '' and p_avatar_key !~ '^[a-z_]{1,32}$' then
      raise exception 'avatar invalid' using errcode = '22023', hint = 'avatar_invalid';
    end if;
    v_diff := v_diff || jsonb_build_object('avatar_key', nullif(p_avatar_key, ''));
  end if;
  if p_birthday is not null and p_birthday <> '' then
    if p_birthday !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
      raise exception 'birthday invalid' using errcode = '22023', hint = 'birthday_invalid';
    end if;
    begin
      v_birthday := p_birthday::date;
    exception when others then
      raise exception 'birthday invalid' using errcode = '22023', hint = 'birthday_invalid';
    end;
    if v_birthday < date '1900-01-01' or v_birthday > current_date then
      raise exception 'birthday invalid' using errcode = '22023', hint = 'birthday_invalid';
    end if;
  end if;
  if p_birthday is not null then
    -- The audit row says that it changed, not the date: a child's birth date is personal data.
    v_diff := v_diff || jsonb_build_object('birthday', case when p_birthday = '' then 'cleared' else 'set' end);
  end if;
  if v_diff = '{}'::jsonb then
    return;
  end if;
  update app.profile set
    display_name = coalesce(v_name, display_name),
    color        = coalesce(upper(p_color), color),
    kind         = coalesce(p_kind, kind),
    avatar_key   = case when p_avatar_key is null then avatar_key else nullif(p_avatar_key, '') end,
    birthday     = case when p_birthday is null then birthday
                        when p_birthday = '' then null
                        else v_birthday end
  where id = p_profile;
  perform app.audit(a, 'profile', p_profile, 'update', v_diff);
end $$;

revoke execute on function api.member_update(uuid, uuid, text, text, text, text, text) from public, anon;
grant execute on function api.member_update(uuid, uuid, text, text, text, text, text) to authenticated;

-- ================================================================== event flags and traditions

alter table app.event
  add column icon_key  text check (icon_key is null or icon_key ~ '^[a-z0-9_]{1,40}$'),
  add column countdown boolean not null default false,
  add column tradition boolean not null default false;

-- A tradition's meal (Pizza-Freitag): offered by the planner on the tradition's days when that
-- slot is empty. Never put on the plan by itself. A recipe's title is kept in free_text as well,
-- so deleting the recipe leaves the words (the check would otherwise refuse the delete).
create table app.tradition_meal (
  event_id     uuid primary key references app.event on delete cascade,
  household_id uuid not null references app.household on delete cascade,
  slot         text not null check (slot in ('breakfast', 'lunch', 'dinner', 'snack')),
  recipe_id    uuid references app.recipe on delete set null,
  free_text    text check (free_text is null or length(btrim(free_text)) between 1 and 120),
  check (recipe_id is not null or free_text is not null)
);
create index on app.tradition_meal (household_id);
alter table app.tradition_meal enable row level security;
alter table app.tradition_meal force row level security;
create policy tradition_meal_read on app.tradition_meal for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.tradition_meal to postgres using (true) with check (true);
revoke all on app.tradition_meal from public, anon, authenticated;
grant select on app.tradition_meal to authenticated;

create or replace view api.events with (security_invoker = true) as
  select e.id, e.calendar_id, e.title, e.description, e.location, e.kind, e.presence_state,
         e.status, e.importance, e.is_all_day, e.starts_at, e.ends_at, e.start_date, e.end_date,
         e.timezone, e.rrule, e.rdates, e.exdates, e.uid, e.sequence, e.created_by_profile_id,
         e.created_at, e.updated_at,
         coalesce((select array_agg(a.profile_id order by p.sort_order, p.id)
                     from app.event_attendee a
                     join app.profile p on p.id = a.profile_id
                    where a.event_id = e.id), '{}') as attendee_ids,
         e.icon_key, e.countdown, e.tradition,
         (select jsonb_build_object('slot', m.slot, 'recipe_id', m.recipe_id, 'free_text', m.free_text,
                                    'title', coalesce(r.title, m.free_text))
            from app.tradition_meal m left join app.recipe r on r.id = m.recipe_id
           where m.event_id = e.id) as tradition_meal
    from app.event e
   where e.deleted_at is null;

-- The original stays as it was, under the app schema; only the wrapper below is callable.
alter function api.event_save(uuid, jsonb) rename to event_save_core;
alter function api.event_save_core(uuid, jsonb) set schema app;
revoke all on function app.event_save_core(uuid, jsonb) from public, anon, authenticated;

-- api.event_save with the flags of specs/27: 'icon_key' (a content icon, '' to clear),
-- 'countdown' and 'tradition' (booleans), and 'tradition_meal' ({slot, recipe_id | free_text},
-- or null to clear). A key an older app does not send keeps its stored value. A tradition is
-- always a key appointment, so it always reaches the board.
create function api.event_save(p_actor uuid, p_event jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a           app.actor_t;
  v_event     jsonb := p_event;
  v_result    jsonb;
  v_id        uuid;
  v_icon      text;
  v_tradition boolean;
  v_meal      jsonb;
  v_slot      text;
  v_recipe    uuid;
  v_free      text;
begin
  if jsonb_typeof(p_event) is distinct from 'object' then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;
  if (p_event ? 'countdown' and jsonb_typeof(p_event -> 'countdown') <> 'boolean')
     or (p_event ? 'tradition' and jsonb_typeof(p_event -> 'tradition') <> 'boolean')
     or (p_event ? 'icon_key' and jsonb_typeof(p_event -> 'icon_key') not in ('string', 'null')) then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;
  v_icon := nullif(p_event ->> 'icon_key', '');
  if v_icon is not null and v_icon !~ '^[a-z0-9_]{1,40}$' then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;
  v_tradition := (p_event ->> 'tradition')::boolean;
  -- A tradition stays on the board even when an older app, which does not send the flag,
  -- saves it with its own importance.
  if coalesce(v_tradition, (select e.tradition from app.event e
                             where (p_event ->> 'id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                               and e.id = (p_event ->> 'id')::uuid), false) then
    v_event := v_event || jsonb_build_object('importance', 'key');
  end if;

  v_result := app.event_save_core(p_actor, v_event);
  v_id := (v_result ->> 'id')::uuid;
  a := app.actor(p_actor);

  update app.event set
    icon_key  = case when p_event ? 'icon_key' then v_icon else icon_key end,
    countdown = case when p_event ? 'countdown' then (p_event ->> 'countdown')::boolean else countdown end,
    tradition = coalesce(v_tradition, tradition)
   where id = v_id;

  if p_event ? 'tradition_meal' or v_tradition is false then
    v_meal := case when v_tradition is false then null else p_event -> 'tradition_meal' end;
    if v_meal is null or jsonb_typeof(v_meal) = 'null' then
      delete from app.tradition_meal where event_id = v_id;
    else
      v_slot   := v_meal ->> 'slot';
      v_recipe := app.meal_uuid(v_meal ->> 'recipe_id');
      v_free   := nullif(btrim(coalesce(v_meal ->> 'free_text', '')), '');
      if jsonb_typeof(v_meal) <> 'object'
         or v_slot is null or v_slot not in ('breakfast', 'lunch', 'dinner', 'snack')
         or (v_recipe is null) = (v_free is null)
         or length(coalesce(v_free, '')) > 120
         or (v_recipe is not null and not exists (
               select 1 from app.recipe r where r.id = v_recipe and r.household_id = a.household_id))
         or not (select e.tradition from app.event e where e.id = v_id) then
        raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
      end if;
      insert into app.tradition_meal (event_id, household_id, slot, recipe_id, free_text)
      values (v_id, a.household_id, v_slot, v_recipe,
              coalesce(v_free, (select left(r.title, 120) from app.recipe r where r.id = v_recipe)))
      on conflict (event_id) do update set
        slot = excluded.slot, recipe_id = excluded.recipe_id, free_text = excluded.free_text;
    end if;
  end if;

  if p_event ?| array['icon_key', 'countdown', 'tradition', 'tradition_meal'] then
    perform app.audit(a, 'event', v_id, 'flags',
      (select jsonb_build_object('icon_key', e.icon_key, 'countdown', e.countdown,
                                 'tradition', e.tradition)
         from app.event e where e.id = v_id));
  end if;
  return v_result;
end $$;

revoke all on function api.event_save(uuid, jsonb) from public, anon;
grant execute on function api.event_save(uuid, jsonb) to authenticated;

-- ================================================================== Wunschessen

alter table app.meal_plan_entry add column wished_by_profile_id uuid
  references app.profile on delete set null;

create table app.meal_wish (
  id                 uuid primary key default gen_random_uuid(),
  household_id       uuid not null references app.household on delete cascade,
  profile_id         uuid not null references app.profile on delete cascade,
  recipe_id          uuid references app.recipe on delete set null,
  free_text          text check (free_text is null or length(btrim(free_text)) between 1 and 60),
  icon_key           text check (icon_key is null or icon_key ~ '^[a-z0-9_]{1,40}$'),
  status             text not null default 'open' check (status in ('open', 'planned', 'withdrawn')),
  meal_plan_entry_id uuid references app.meal_plan_entry on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  check (recipe_id is not null or free_text is not null)
);
create index on app.meal_wish (household_id, status);
create index meal_wish_household_id_id_idx on app.meal_wish (household_id, id);
alter table app.meal_wish enable row level security;
alter table app.meal_wish force row level security;
create policy meal_wish_read on app.meal_wish for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.meal_wish to postgres using (true) with check (true);
revoke all on app.meal_wish from public, anon, authenticated;
grant select on app.meal_wish to authenticated;

-- Open and planned wishes; a planned one until its meal has passed. A wish that is not planned
-- simply stays open: nothing here is ever "declined".
create view api.meal_wishes with (security_invoker = true) as
  select w.id, w.profile_id, w.recipe_id, w.free_text, w.icon_key, w.status,
         coalesce(r.title, w.free_text) as title,
         w.meal_plan_entry_id, e.on_date as planned_on, e.slot as planned_slot,
         w.created_at
    from app.meal_wish w
    left join app.recipe r on r.id = w.recipe_id
    left join app.meal_plan_entry e on e.id = w.meal_plan_entry_id
   where w.status = 'open'
      or (w.status = 'planned' and e.on_date >= (now() at time zone
            (select h.timezone from app.household h where h.id = w.household_id))::date - 7);
grant select on api.meal_wishes to authenticated;

create or replace view api.meal_plan_entries with (security_invoker = true) as
  select e.id, e.on_date, e.slot, e.recipe_id, e.free_text,
         coalesce(r.title, e.free_text) as title,
         e.servings, e.cook_profile_id, e.at_time, e.guests, e.eating_overrides,
         e.shopping_generated_at, e.wished_by_profile_id
    from app.meal_plan_entry e
    left join app.recipe r on r.id = e.recipe_id;

-- The effective value of a household setting (no member or device override).
create function app.household_setting_value(p_household uuid, p_key text) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select s.value from app.household_setting s
      where s.household_id = p_household and s.key = p_key
        and s.profile_id is null and s.device_id is null limit 1),
    (select d.default_value from app.setting_definition d where d.key = p_key))
$$;
revoke all on function app.household_setting_value(uuid, text) from public, anon, authenticated;

-- Creates or replaces the actor's own open wish: a recipe of the household, or a few words
-- with an optional icon. Who may wish is meals.wishes; how many open at once, meals.wishes_per_week.
create function api.meal_wish_set(p_actor uuid, p_recipe_id uuid default null,
  p_free_text text default null, p_icon_key text default null) returns jsonb
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

  -- Replacing: the newest open wish of the actor changes; otherwise a new one, within the limit.
  select w.id into v_id from app.meal_wish w
   where w.profile_id = a.profile_id and w.status = 'open'
   order by w.created_at desc limit 1;
  if v_id is not null and (select count(*) from app.meal_wish w
                            where w.profile_id = a.profile_id and w.status = 'open') >= v_limit then
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

-- The wisher takes a wish back, or a guardian removes it. The child's card then simply
-- invites a new one.
create function api.meal_wish_withdraw(p_actor uuid, p_wish uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  w app.meal_wish;
begin
  select * into w from app.meal_wish where id = p_wish and household_id = a.household_id;
  if not found or w.status <> 'open' then
    raise exception 'wish not found' using errcode = 'P0002', hint = 'wish_not_found';
  end if;
  if w.profile_id is distinct from a.profile_id then
    perform app.require_guardian(a);
  end if;
  update app.meal_wish set status = 'withdrawn', updated_at = now() where id = p_wish;
  perform app.audit(a, 'meal_wish', p_wish, 'withdraw');
  perform app.broadcast(a.household_id, 'meals');
end $$;

-- Puts a wish on the plan: the meal of that day and slot becomes the wish (api.meal_set, so the
-- usual rules apply) and carries the wisher, and the wish is planned.
create function api.meal_wish_plan(p_actor uuid, p_wish uuid, p_on_date date, p_slot text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  w       app.meal_wish;
  v_entry uuid;
begin
  select * into w from app.meal_wish where id = p_wish and household_id = a.household_id for update;
  if not found or w.status <> 'open' then
    raise exception 'wish not found' using errcode = 'P0002', hint = 'wish_not_found';
  end if;
  v_entry := (api.meal_set(p_actor, jsonb_strip_nulls(jsonb_build_object(
    'on_date', p_on_date, 'slot', p_slot,
    'recipe_id', w.recipe_id,
    'free_text', case when w.recipe_id is null then w.free_text end))) ->> 'id')::uuid;
  update app.meal_plan_entry set wished_by_profile_id = w.profile_id where id = v_entry;
  update app.meal_wish set status = 'planned', meal_plan_entry_id = v_entry, updated_at = now()
   where id = p_wish;
  perform app.audit(a, 'meal_wish', p_wish, 'plan',
                    jsonb_build_object('on_date', p_on_date, 'slot', p_slot));
  perform app.broadcast(a.household_id, 'meals');
  return jsonb_build_object('id', v_entry);
end $$;

-- The star goes with the dish (specs/27): changing what is cooked takes the wish off that meal
-- and gives it back to the child; so does removing the meal. Nothing is ever declined.
create function app.meal_wish_follow() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE'
     or new.recipe_id is distinct from old.recipe_id
     or new.free_text is distinct from old.free_text then
    update app.meal_wish set status = 'open', meal_plan_entry_id = null, updated_at = now()
     where meal_plan_entry_id = old.id and status = 'planned';
    if tg_op = 'DELETE' then
      return old;
    end if;
    new.wished_by_profile_id := null;
  end if;
  return new;
end $$;
revoke all on function app.meal_wish_follow() from public, anon, authenticated;

create trigger meal_wish_follow before update of recipe_id, free_text or delete
  on app.meal_plan_entry for each row execute function app.meal_wish_follow();

-- api.meal_move keeps a swapped meal's wish: the swap deletes and re-inserts the other meal,
-- which would otherwise give its wish back. Same function, the wish carried across.
create or replace function api.meal_move(p_actor uuid, p_from_date date, p_from_slot text,
                              p_to_date date, p_to_slot text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.actor(p_actor);
  v_src    app.meal_plan_entry;
  v_dst    app.meal_plan_entry;
  v_has_dst boolean;
  v_wishes uuid[];
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
    v_wishes := array(select w.id from app.meal_wish w where w.meal_plan_entry_id = v_dst.id);
    delete from app.meal_plan_entry where id = v_dst.id;
  end if;

  update app.meal_plan_entry set on_date = p_to_date, slot = p_to_slot where id = v_src.id;
  if v_has_dst then
    insert into app.meal_plan_entry (id, household_id, on_date, slot, recipe_id, free_text, servings,
                                     cook_profile_id, at_time, guests, eating_overrides,
                                     shopping_generated_at, wished_by_profile_id)
    values (v_dst.id, v_dst.household_id, p_from_date, p_from_slot, v_dst.recipe_id, v_dst.free_text,
            v_dst.servings, v_dst.cook_profile_id, v_dst.at_time, v_dst.guests, v_dst.eating_overrides,
            v_dst.shopping_generated_at, v_dst.wished_by_profile_id);
    update app.meal_wish set status = 'planned', meal_plan_entry_id = v_dst.id
     where id = any (v_wishes);
  end if;

  perform app.audit(a, 'meal_plan_entry', v_src.id, 'move',
                    jsonb_build_object('from', jsonb_build_array(p_from_date, p_from_slot),
                                       'to', jsonb_build_array(p_to_date, p_to_slot),
                                       'swapped', v_has_dst));
  perform app.broadcast(a.household_id, 'meals');
end $$;

revoke all on function api.meal_wish_set(uuid, uuid, text, text), api.meal_wish_withdraw(uuid, uuid),
  api.meal_wish_plan(uuid, uuid, date, text) from public, anon;
grant execute on function api.meal_wish_set(uuid, uuid, text, text), api.meal_wish_withdraw(uuid, uuid),
  api.meal_wish_plan(uuid, uuid, date, text) to authenticated;

-- ================================================================== Tischfrage

-- The family's own questions (text) and the bundled questions it hides (hidden_key, e.g.
-- 'de:q-0042'). The bundled deck lives in the app; nothing about answers is stored anywhere.
create table app.table_question (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  text                  text check (text is null or length(btrim(text)) between 1 and 200),
  hidden_key            text check (hidden_key is null or hidden_key ~ '^[a-z]{2}:[a-z0-9_-]{1,40}$'),
  created_by_profile_id uuid references app.profile on delete set null,
  created_at            timestamptz not null default now(),
  check ((text is null) <> (hidden_key is null))
);
create unique index table_question_hidden_once on app.table_question (household_id, hidden_key)
  where hidden_key is not null;
create index table_question_household_id_id_idx on app.table_question (household_id, id);
alter table app.table_question enable row level security;
alter table app.table_question force row level security;
create policy table_question_read on app.table_question for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.table_question to postgres using (true) with check (true);
revoke all on app.table_question from public, anon, authenticated;
grant select on app.table_question to authenticated;

create view api.table_questions with (security_invoker = true) as
  select id, text, hidden_key, created_by_profile_id, created_at from app.table_question;
grant select on api.table_questions to authenticated;

-- Any member adds a question of their own ("Frage von Jack").
create function api.table_question_add(p_actor uuid, p_text text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v_text text := btrim(coalesce(p_text, ''));
  v_id   uuid;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if length(v_text) not between 1 and 200
     or (select count(*) from app.table_question q
          where q.household_id = a.household_id and q.text is not null) >= 500 then
    raise exception 'WW-RIT-001 question invalid' using errcode = '22023', hint = 'question_invalid';
  end if;
  insert into app.table_question (household_id, text, created_by_profile_id)
  values (a.household_id, v_text, a.profile_id)
  returning id into v_id;
  perform app.audit(a, 'table_question', v_id, 'create');
  perform app.broadcast(a.household_id, 'meals');
  return jsonb_build_object('id', v_id);
end $$;

-- A guardian hides a bundled question for the household; showing it again removes the row.
create function api.table_question_hide(p_actor uuid, p_key text, p_hidden boolean default true)
returns void language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  perform app.require_guardian(a);
  if p_key is null or p_key !~ '^[a-z]{2}:[a-z0-9_-]{1,40}$' then
    raise exception 'WW-RIT-001 question invalid' using errcode = '22023', hint = 'question_invalid';
  end if;
  if p_hidden then
    insert into app.table_question (household_id, hidden_key, created_by_profile_id)
    values (a.household_id, p_key, a.profile_id)
    on conflict (household_id, hidden_key) where hidden_key is not null do nothing;
  else
    delete from app.table_question where household_id = a.household_id and hidden_key = p_key;
  end if;
  perform app.audit(a, 'table_question', null, case when p_hidden then 'hide' else 'show' end,
                    jsonb_build_object('key', p_key));
  perform app.broadcast(a.household_id, 'meals');
end $$;

-- The author or a guardian removes a question of the family's own.
create function api.table_question_remove(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  q app.table_question;
begin
  select * into q from app.table_question
   where id = p_id and household_id = a.household_id and text is not null;
  if not found then
    raise exception 'question not found' using errcode = 'P0002', hint = 'question_not_found';
  end if;
  if q.created_by_profile_id is distinct from a.profile_id then
    perform app.require_guardian(a);
  end if;
  delete from app.table_question where id = p_id;
  perform app.audit(a, 'table_question', p_id, 'delete');
  perform app.broadcast(a.household_id, 'meals');
end $$;

revoke all on function api.table_question_add(uuid, text), api.table_question_hide(uuid, text, boolean),
  api.table_question_remove(uuid, uuid) from public, anon;
grant execute on function api.table_question_add(uuid, text), api.table_question_hide(uuid, text, boolean),
  api.table_question_remove(uuid, uuid) to authenticated;

-- ================================================================== Wochenrückblick

-- The look back at one week (Monday p_week_start, default this household week), as one JSON
-- document the wall and the phones read alike (specs/27 "Wochenrückblick"):
--   chores_done   the family's chores done that week: one number, the family's
--   members       one highlight for every active member, in board order; a highlight is a kind
--                 and a title, never a number another member's line could be compared with
--   meals         the week's lunches and dinners, wishes marked, recipes cooked the first time
-- Traditions and next week's countdowns come from the occurrences, which the app already reads.
-- Never in it: a balance, a chore not done, a missed streak.
create function api.week_review(p_week_start date default null) returns jsonb
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
                   -- 2. a streak that ran through the week, a week long at least
                   (select jsonb_build_object('kind', 'streak', 'title', td.title, 'icon_key', td.icon_key)
                      from app.streak s join app.task_definition td on td.id = s.definition_id
                     where s.profile_id = p.id and s.current_length >= 7
                       and s.last_completed_on between v_from and v_to
                     order by s.current_length desc limit 1),
                   -- 3. every chore of a day done
                   (select jsonb_build_object('kind', 'all_done')
                      where exists (
                        select 1 from app.task_instance t
                         where t.household_id = v_household and t.assigned_profile_id = p.id
                           and t.due_on between v_from and v_to
                         group by t.due_on
                        having bool_and(t.status in ('done', 'verified')))),
                   -- 4. a reward redeemed
                   (select jsonb_build_object('kind', 'reward', 'title', r.title, 'icon_key', r.icon_key)
                      from app.reward_redemption x join app.reward r on r.id = x.reward_id
                     where x.profile_id = p.id and x.status in ('approved', 'fulfilled')
                       and (coalesce(x.decided_at, x.requested_at) at time zone coalesce(v_tz, 'UTC'))::date
                           between v_from and v_to
                     order by x.decided_at desc nulls last limit 1),
                   -- 5. their wish was on the table
                   (select jsonb_build_object('kind', 'wish', 'title', coalesce(rc.title, e.free_text))
                      from app.meal_plan_entry e left join app.recipe rc on rc.id = e.recipe_id
                     where e.household_id = v_household and e.wished_by_profile_id = p.id
                       and e.on_date between v_from and v_to
                     order by e.on_date limit 1),
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

-- ================================================================== export

insert into app.export_table (name, position, omit, keep) values
  ('tradition_meal', 275, '{}', null),
  ('meal_wish',      276, '{}', null),
  ('table_question', 277, '{}', null);
