-- M1.1 Shopping, complete (specs/07, specs/13): several lists, categories as store layout,
-- a catalogue learned on purchase, counts ("tap again for 2x"), trips as history.
--
-- Until now `shopping_list` was a *trip* (status active/done). It becomes the stable
-- list (Supermarkt, Drogerie, ...) and trips get their own table. The api views keep
-- every column the previous app release reads.

-- ------------------------------------------------------------------ folding

-- Case, umlauts and accents fold together so "klopapier" finds Toilettenpapier.
-- The app folds the typed query the same way (core/text/fold.dart).
create function app.fold(p_text text) returns text
language sql immutable parallel safe set search_path = '' as $$
  select lower(translate(
    replace(replace(replace(replace(replace(replace(replace(p_text,
      'ä', 'ae'), 'ö', 'oe'), 'ü', 'ue'), 'Ä', 'ae'), 'Ö', 'oe'), 'Ü', 'ue'), 'ß', 'ss'),
    'áàâéèêíìîóòôúùûñçÁÀÂÉÈÊÍÌÎÓÒÔÚÙÛÑÇ', 'aaaeeeiiiooouuuncaaaeeeiiiooouuunc'))
$$;

-- ------------------------------------------------------------------ lists and trips

alter table app.shopping_list
  add column name       text not null default 'Supermarkt' check (length(btrim(name)) between 1 and 40),
  add column is_default boolean not null default false,
  add column sort_order int not null default 0;

create table app.shopping_trip (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references app.household on delete cascade,
  list_id      uuid not null references app.shopping_list on delete cascade,
  finished_at  timestamptz not null default now(),
  finished_by  uuid references app.profile on delete set null
);
create index on app.shopping_trip (list_id, finished_at desc);

create table app.shopping_category (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references app.household on delete cascade,
  list_id      uuid not null references app.shopping_list on delete cascade,
  -- Seeded categories carry a key the app localises; a custom one carries its own name.
  key          text,
  name         text check (name is null or length(btrim(name)) between 1 and 40),
  sort_order   int not null default 0,
  check (key is not null or name is not null)
);
create index on app.shopping_category (list_id, sort_order);

create table app.catalog_item (
  id                uuid primary key default gen_random_uuid(),
  household_id      uuid not null references app.household on delete cascade,
  list_id           uuid not null references app.shopping_list on delete cascade,
  name              text not null,
  folded_name       text not null,
  category_id       uuid references app.shopping_category on delete set null,
  icon_key          text,
  purchase_count    int not null default 0,
  last_purchased_at timestamptz,
  unique (list_id, folded_name)
);

alter table app.shopping_item
  add column trip_id         uuid references app.shopping_trip on delete cascade,
  add column category_id     uuid references app.shopping_category on delete set null,
  add column catalog_item_id uuid references app.catalog_item on delete set null,
  add column count           int not null default 1 check (count between 1 and 99),
  add column folded_name     text;
create index on app.shopping_item (trip_id);

-- ---- migrate: the active list per household is the list; done lists become trips.
update app.shopping_item set folded_name = app.fold(name);
alter table app.shopping_item alter column folded_name set not null;

insert into app.shopping_list (household_id, status)
  select h.id, 'active' from app.household h
   where not exists (select 1 from app.shopping_list l where l.household_id = h.id and l.status = 'active');
update app.shopping_list set name = 'Supermarkt', is_default = true where status = 'active';

with trips as (
  insert into app.shopping_trip (household_id, list_id, finished_at)
  select d.household_id, a.id, d.finished_at
    from app.shopping_list d
    join app.shopping_list a on a.household_id = d.household_id and a.status = 'active'
   where d.status = 'done'
  returning id, list_id, finished_at, household_id
)
update app.shopping_item i set trip_id = t.id, list_id = t.list_id
  from app.shopping_list d
  join trips t on t.household_id = d.household_id and t.finished_at = d.finished_at
 where i.list_id = d.id and d.status = 'done';
delete from app.shopping_list where status = 'done';

-- The view stops depending on the list's status before the column goes.
create or replace view api.shopping_items with (security_invoker = true) as
  select i.id, i.name, i.quantity, i.checked, i.added_by, i.checked_by, i.checked_at, i.created_at,
         i.list_id, i.category_id, i.count, i.catalog_item_id
    from app.shopping_item i
   where i.trip_id is null;

drop index app.shopping_list_one_active;
alter table app.shopping_list drop column status, drop column finished_at;
-- (an expression index needs an immutable function; app.fold is)
create unique index shopping_list_name on app.shopping_list (household_id, (app.fold(name)));
create unique index shopping_list_one_default on app.shopping_list (household_id) where is_default;

-- ------------------------------------------------------------------ RLS

alter table app.shopping_trip enable row level security;
alter table app.shopping_category enable row level security;
alter table app.catalog_item enable row level security;
alter table app.shopping_trip force row level security;
alter table app.shopping_category force row level security;
alter table app.catalog_item force row level security;

create policy shopping_trip_read on app.shopping_trip for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy shopping_category_read on app.shopping_category for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy catalog_item_read on app.catalog_item for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.shopping_trip to postgres using (true) with check (true);
create policy owner_all on app.shopping_category to postgres using (true) with check (true);
create policy owner_all on app.catalog_item to postgres using (true) with check (true);
grant select on app.shopping_trip, app.shopping_category, app.catalog_item to authenticated;

-- ------------------------------------------------------------------ list creation

-- Default categories, in walking order. Keys are localised by the app.
create function app.shopping_seed_categories(p_list uuid, p_household uuid, p_kind text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_keys text[];
begin
  v_keys := case p_kind
    when 'supermarket' then array['produce', 'bakery', 'dairy', 'meat_fish', 'pantry', 'frozen', 'drinks', 'household', 'other']
    when 'drugstore'   then array['care', 'baby', 'cleaning', 'health', 'other']
    when 'hardware'    then array['tools', 'screws', 'electrical', 'garden', 'other']
    else array['other']
  end;
  insert into app.shopping_category (household_id, list_id, key, sort_order)
    select p_household, p_list, k, (ord - 1) * 10 from unnest(v_keys) with ordinality as t(k, ord);
end $$;

create function app.shopping_ensure_lists(p_household uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if exists (select 1 from app.shopping_list where household_id = p_household) then
    return;
  end if;
  insert into app.shopping_list (household_id, name, is_default, sort_order)
    values (p_household, 'Supermarkt', true, 0) returning id into v_id;
  perform app.shopping_seed_categories(v_id, p_household, 'supermarket');
end $$;

-- The list a write targets: the one named, else the household default.
create function app.shopping_target_list(p_household uuid, p_list uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  perform app.shopping_ensure_lists(p_household);
  if p_list is null then
    select id into v_id from app.shopping_list where household_id = p_household and is_default;
  else
    select id into v_id from app.shopping_list where household_id = p_household and id = p_list;
  end if;
  if v_id is null then
    raise exception 'list not found' using errcode = 'P0002', hint = 'list_not_found';
  end if;
  return v_id;
end $$;

revoke execute on function app.fold(text), app.shopping_seed_categories(uuid, uuid, text),
  app.shopping_ensure_lists(uuid), app.shopping_target_list(uuid, uuid) from public, anon, authenticated;

-- Lists that existed before this migration get their categories now.
do $$
declare r record;
begin
  for r in select id, household_id from app.shopping_list loop
    perform app.shopping_seed_categories(r.id, r.household_id, 'supermarket');
  end loop;
end $$;

-- ------------------------------------------------------------------ views

create view api.shopping_lists with (security_invoker = true) as
  select l.id, l.name, l.is_default, l.sort_order,
         (select count(*) from app.shopping_item i where i.list_id = l.id and i.trip_id is null and not i.checked)::int as open_count
    from app.shopping_list l;

create view api.shopping_categories with (security_invoker = true) as
  select id, list_id, key, name, sort_order from app.shopping_category;

create view api.shopping_catalog with (security_invoker = true) as
  select id, list_id, name, folded_name, category_id, icon_key, purchase_count, last_purchased_at
    from app.catalog_item;

create view api.shopping_trips with (security_invoker = true) as
  select t.id, t.list_id, t.finished_at, t.finished_by,
         (select count(*) from app.shopping_item i where i.trip_id = t.id)::int as item_count
    from app.shopping_trip t;

create view api.shopping_trip_items with (security_invoker = true) as
  select i.id, i.trip_id, i.list_id, i.name, i.quantity, i.count, i.category_id, i.added_by
    from app.shopping_item i
   where i.trip_id is not null;

grant select on api.shopping_lists, api.shopping_categories, api.shopping_catalog,
                api.shopping_trips, api.shopping_trip_items to authenticated;

-- ------------------------------------------------------------------ writes

drop function api.shopping_add_item(uuid, text, text);
-- Adding a name already open (unticked) on the list raises its count instead of
-- duplicating it: "two people add the same item" lands as 2x.
create function api.shopping_add_item(p_actor uuid, p_name text, p_quantity text default null, p_list uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v_list uuid := app.shopping_target_list(a.household_id, p_list);
  v_name text := btrim(coalesce(p_name, ''));
  v_fold text := app.fold(btrim(coalesce(p_name, '')));
  v_id   uuid;
  v_cat  app.catalog_item;
begin
  if length(v_name) = 0 then
    raise exception 'name required' using errcode = '22023', hint = 'name_required';
  end if;

  select i.id into v_id from app.shopping_item i
   where i.list_id = v_list and i.trip_id is null and not i.checked and i.folded_name = v_fold
   limit 1 for update;
  if found then
    update app.shopping_item set count = least(count + 1, 99) where id = v_id;
    perform app.audit(a, 'shopping_item', v_id, 'increment');
  else
    select * into v_cat from app.catalog_item where list_id = v_list and folded_name = v_fold;
    insert into app.shopping_item (list_id, household_id, name, folded_name, quantity, added_by, category_id, catalog_item_id)
    values (v_list, a.household_id, coalesce(v_cat.name, v_name), v_fold,
            nullif(btrim(coalesce(p_quantity, '')), ''), a.profile_id, v_cat.category_id, v_cat.id)
    returning id into v_id;
    perform app.audit(a, 'shopping_item', v_id, 'create', jsonb_build_object('name', v_name));
  end if;
  perform app.broadcast(a.household_id, 'shopping');
  return v_id;
end $$;

-- +1 / -1 from the tile; reaching zero removes the item.
create function api.shopping_adjust_count(p_actor uuid, p_item uuid, p_delta int) returns int
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_count int;
begin
  select count + p_delta into v_count from app.shopping_item
   where id = p_item and household_id = a.household_id and trip_id is null for update;
  if not found then
    raise exception 'item not found' using errcode = 'P0002', hint = 'item_not_found';
  end if;
  if v_count <= 0 then
    delete from app.shopping_item where id = p_item;
    perform app.audit(a, 'shopping_item', p_item, 'delete');
    v_count := 0;
  else
    update app.shopping_item set count = least(v_count, 99) where id = p_item;
    perform app.audit(a, 'shopping_item', p_item, 'count', jsonb_build_object('count', v_count));
  end if;
  perform app.broadcast(a.household_id, 'shopping');
  return v_count;
end $$;

-- The free-text specification from a long press ("Bio", "500 g"), kept verbatim.
create function api.shopping_set_item_spec(p_actor uuid, p_item uuid, p_text text) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if length(coalesce(p_text, '')) > 40 then
    raise exception 'specification too long' using errcode = '22023', hint = 'spec_too_long';
  end if;
  update app.shopping_item set quantity = nullif(btrim(coalesce(p_text, '')), '')
   where id = p_item and household_id = a.household_id and trip_id is null;
  if not found then
    raise exception 'item not found' using errcode = 'P0002', hint = 'item_not_found';
  end if;
  perform app.audit(a, 'shopping_item', p_item, 'spec');
  perform app.broadcast(a.household_id, 'shopping');
end $$;

-- Correcting a category teaches the catalogue too.
create function api.shopping_set_category(p_actor uuid, p_item uuid, p_category uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_item app.shopping_item;
begin
  select * into v_item from app.shopping_item
   where id = p_item and household_id = a.household_id and trip_id is null;
  if not found then
    raise exception 'item not found' using errcode = 'P0002', hint = 'item_not_found';
  end if;
  if p_category is not null and not exists (
       select 1 from app.shopping_category where id = p_category and list_id = v_item.list_id) then
    raise exception 'category not found' using errcode = 'P0002', hint = 'category_not_found';
  end if;
  update app.shopping_item set category_id = p_category where id = p_item;
  update app.catalog_item set category_id = p_category where id = v_item.catalog_item_id;
  perform app.audit(a, 'shopping_item', p_item, 'categorise');
  perform app.broadcast(a.household_id, 'shopping');
end $$;

create function api.shopping_list_create(p_actor uuid, p_name text, p_kind text default 'other') returns uuid
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_id uuid; v_name text := btrim(coalesce(p_name, ''));
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if length(v_name) not between 1 and 40 then
    raise exception 'name required' using errcode = '22023', hint = 'name_required';
  end if;
  perform app.shopping_ensure_lists(a.household_id);
  if exists (select 1 from app.shopping_list where household_id = a.household_id and app.fold(name) = app.fold(v_name)) then
    raise exception 'list exists' using errcode = '23505', hint = 'list_exists';
  end if;
  insert into app.shopping_list (household_id, name, sort_order)
    values (a.household_id, v_name,
            (select coalesce(max(sort_order), 0) + 10 from app.shopping_list where household_id = a.household_id))
    returning id into v_id;
  perform app.shopping_seed_categories(v_id, a.household_id, p_kind);
  perform app.audit(a, 'shopping_list', v_id, 'create', jsonb_build_object('name', v_name));
  perform app.broadcast(a.household_id, 'shopping');
  return v_id;
end $$;

create function api.shopping_list_set_default(p_actor uuid, p_list uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.shopping_target_list(a.household_id, p_list);
  update app.shopping_list set is_default = false where household_id = a.household_id and is_default;
  update app.shopping_list set is_default = true where id = p_list;
  perform app.audit(a, 'shopping_list', p_list, 'set_default');
  perform app.broadcast(a.household_id, 'shopping');
end $$;

drop function api.shopping_finish(uuid);
-- Ends the trip: ticked items become the trip and teach the catalogue (created here, on
-- purchase, not on capture); unticked ones stay on the list.
create function api.shopping_finish(p_actor uuid, p_list uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
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

  insert into app.shopping_trip (household_id, list_id, finished_by)
    values (a.household_id, v_list, a.profile_id) returning id into v_trip;

  for r in select * from app.shopping_item where list_id = v_list and trip_id is null and checked loop
    insert into app.catalog_item (household_id, list_id, name, folded_name, category_id, purchase_count, last_purchased_at)
      values (a.household_id, v_list, r.name, r.folded_name, r.category_id, 1, now())
    on conflict (list_id, folded_name) do update
      set purchase_count = app.catalog_item.purchase_count + 1,
          last_purchased_at = now(),
          category_id = coalesce(excluded.category_id, app.catalog_item.category_id)
    returning id into v_cat;
    update app.shopping_item set trip_id = v_trip, catalog_item_id = v_cat where id = r.id;
  end loop;

  perform app.audit(a, 'shopping_list', v_list, 'finish',
                    jsonb_build_object('bought', v_done, 'carried_over', v_left, 'trip', v_trip));
  perform app.broadcast(a.household_id, 'shopping');
  return jsonb_build_object('bought', v_done, 'carried_over', v_left, 'trip_id', v_trip);
end $$;

-- toggle only touches open items now that trips are a column rather than a list status.
create or replace function api.shopping_toggle_item(p_actor uuid, p_item uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_checked boolean;
begin
  update app.shopping_item i set
    checked    = not i.checked,
    checked_by = case when not i.checked then a.profile_id end,
    checked_at = case when not i.checked then now() end
   where i.id = p_item and i.trip_id is null and i.household_id = a.household_id
  returning i.checked into v_checked;
  if not found then
    raise exception 'item not found' using errcode = 'P0002', hint = 'item_not_found';
  end if;
  perform app.audit(a, 'shopping_item', p_item, case when v_checked then 'check' else 'uncheck' end);
  perform app.broadcast(a.household_id, 'shopping');
  return v_checked;
end $$;

drop function app.shopping_active_list(uuid);

-- New api functions are executable by authenticated only (default privileges of the api
-- schema); anon never.
revoke execute on function api.shopping_add_item(uuid, text, text, uuid),
  api.shopping_adjust_count(uuid, uuid, int), api.shopping_set_item_spec(uuid, uuid, text),
  api.shopping_set_category(uuid, uuid, uuid), api.shopping_list_create(uuid, text, text),
  api.shopping_list_set_default(uuid, uuid), api.shopping_finish(uuid, uuid) from public, anon;
