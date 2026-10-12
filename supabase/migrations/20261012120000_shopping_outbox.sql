-- M1.1 Shopping offline (specs/07#offline, ADR-006): the app's outbox drains into one
-- function, api.shopping_apply, which replays a batch of operations in order.
--
-- Idempotency: every operation carries a client-generated op_id, recorded once in
-- app.shopping_op; a replayed batch is a no-op for the ops already applied. New items
-- carry a client-generated id, so later offline operations can refer to them before the
-- server has seen them. When an offline add merges into an item that is already open
-- under that name ("two people add the same item"), the client's id becomes an alias.
--
-- The single-item api functions stay for the previous app release; they and the batch
-- now share the app.shopping_do_* internals below.

-- ------------------------------------------------------------------ tables

create table app.shopping_op (
  household_id uuid not null references app.household on delete cascade,
  op_id        uuid not null,
  kind         text not null,
  status       text not null check (status in ('applied', 'skipped', 'rejected')),
  code         text,
  applied_at   timestamptz not null default now(),
  primary key (household_id, op_id)
);
create index on app.shopping_op (household_id, applied_at);

create table app.shopping_item_alias (
  household_id uuid not null references app.household on delete cascade,
  alias_id     uuid not null,
  item_id      uuid not null references app.shopping_item on delete cascade,
  primary key (household_id, alias_id)
);

-- Internal bookkeeping: no client role reads or writes these, not even through RLS.
alter table app.shopping_op enable row level security;
alter table app.shopping_item_alias enable row level security;
alter table app.shopping_op force row level security;
alter table app.shopping_item_alias force row level security;
create policy owner_all on app.shopping_op to postgres using (true) with check (true);
create policy owner_all on app.shopping_item_alias to postgres using (true) with check (true);

-- ------------------------------------------------------------------ internals

-- An open item of the household by its id, or by the client id it was merged under.
-- Null when it is gone (removed, or bought on a trip): the tombstone wins.
create function app.shopping_resolve_item(p_household uuid, p_id uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select i.id from app.shopping_item i
      where i.id = p_id and i.household_id = p_household and i.trip_id is null),
    (select i.id from app.shopping_item_alias x
       join app.shopping_item i on i.id = x.item_id and i.trip_id is null
      where x.household_id = p_household and x.alias_id = p_id))
$$;

-- Adding a name already open (unticked) on the list raises its count instead of
-- duplicating it. [p_id] is the client's id for the new item, if it chose one.
create function app.shopping_do_add(a app.actor_t, p_list uuid, p_name text, p_quantity text,
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
            v_cat.category_id, v_cat.id)
    returning id into v_id;
    perform app.audit(a, 'shopping_item', v_id, 'create', jsonb_build_object('name', v_name));
  end if;
  return v_id;
end $$;

-- Sets the ticked state (absolute, so a replay changes nothing). False when the item is gone.
create function app.shopping_do_check(a app.actor_t, p_item uuid, p_checked boolean)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  update app.shopping_item i set
    checked    = p_checked,
    checked_by = case when p_checked then a.profile_id end,
    checked_at = case when p_checked then now() end
   where i.id = p_item and i.trip_id is null and i.household_id = a.household_id
     and i.checked is distinct from p_checked;
  if not found then
    return exists (select 1 from app.shopping_item
                    where id = p_item and trip_id is null and household_id = a.household_id);
  end if;
  perform app.audit(a, 'shopping_item', p_item, case when p_checked then 'check' else 'uncheck' end);
  return true;
end $$;

-- +n / -n; reaching zero removes the item. Null when the item is gone.
create function app.shopping_do_count(a app.actor_t, p_item uuid, p_delta int)
returns int language plpgsql security definer set search_path = '' as $$
declare v_count int;
begin
  if p_delta is null or p_delta not between -99 and 99 then
    raise exception 'invalid count' using errcode = '22023', hint = 'count_invalid';
  end if;
  select count + p_delta into v_count from app.shopping_item
   where id = p_item and household_id = a.household_id and trip_id is null for update;
  if not found then
    return null;
  end if;
  if v_count <= 0 then
    delete from app.shopping_item where id = p_item;
    perform app.audit(a, 'shopping_item', p_item, 'delete');
    return 0;
  end if;
  update app.shopping_item set count = least(v_count, 99) where id = p_item;
  perform app.audit(a, 'shopping_item', p_item, 'count', jsonb_build_object('count', v_count));
  return least(v_count, 99);
end $$;

-- The free-text specification from a long press ("Bio", "500 g"), kept verbatim.
create function app.shopping_do_spec(a app.actor_t, p_item uuid, p_text text)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if length(coalesce(p_text, '')) > 40 then
    raise exception 'specification too long' using errcode = '22023', hint = 'spec_too_long';
  end if;
  update app.shopping_item set quantity = nullif(btrim(coalesce(p_text, '')), '')
   where id = p_item and household_id = a.household_id and trip_id is null;
  if not found then
    return false;
  end if;
  perform app.audit(a, 'shopping_item', p_item, 'spec');
  return true;
end $$;

-- Correcting a category teaches the catalogue too.
create function app.shopping_do_category(a app.actor_t, p_item uuid, p_category uuid)
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
  update app.shopping_item set category_id = p_category where id = p_item;
  update app.catalog_item set category_id = p_category where id = v_item.catalog_item_id;
  perform app.audit(a, 'shopping_item', p_item, 'categorise');
  return true;
end $$;

-- Ends the trip: ticked items become the trip and teach the catalogue (created here, on
-- purchase, not on capture); unticked ones stay on the list. [p_trip] is the client's id.
create function app.shopping_do_finish(a app.actor_t, p_list uuid, p_trip uuid default null)
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
  return jsonb_build_object('bought', v_done, 'carried_over', v_left, 'trip_id', v_trip);
end $$;

-- One operation of a batch. 'applied', or 'skipped' when it no longer has anything to act
-- on (the item was removed or bought meanwhile, the trip exists). Domain errors raise.
create function app.shopping_apply_op(a app.actor_t, p_op jsonb) returns text
language plpgsql security definer set search_path = '' as $$
declare v_item uuid;
begin
  case p_op ->> 'kind'
  when 'add' then
    if app.shopping_resolve_item(a.household_id, (p_op ->> 'item_id')::uuid) is not null then
      return 'skipped';
    end if;
    perform app.shopping_do_add(a, (p_op ->> 'list_id')::uuid, p_op ->> 'name',
                                p_op ->> 'quantity', (p_op ->> 'item_id')::uuid);
  when 'check' then
    v_item := app.shopping_resolve_item(a.household_id, (p_op ->> 'item_id')::uuid);
    if v_item is null or not app.shopping_do_check(a, v_item, (p_op ->> 'checked')::boolean) then
      return 'skipped';
    end if;
  when 'count' then
    v_item := app.shopping_resolve_item(a.household_id, (p_op ->> 'item_id')::uuid);
    if v_item is null or app.shopping_do_count(a, v_item, (p_op ->> 'delta')::int) is null then
      return 'skipped';
    end if;
  when 'spec' then
    v_item := app.shopping_resolve_item(a.household_id, (p_op ->> 'item_id')::uuid);
    if v_item is null or not app.shopping_do_spec(a, v_item, p_op ->> 'text') then
      return 'skipped';
    end if;
  when 'category' then
    v_item := app.shopping_resolve_item(a.household_id, (p_op ->> 'item_id')::uuid);
    if v_item is null or not app.shopping_do_category(a, v_item, (p_op ->> 'category_id')::uuid) then
      return 'skipped';
    end if;
  when 'finish' then
    if exists (select 1 from app.shopping_trip
                where id = (p_op ->> 'trip_id')::uuid and household_id = a.household_id) then
      return 'skipped';
    end if;
    perform app.shopping_do_finish(a, (p_op ->> 'list_id')::uuid, (p_op ->> 'trip_id')::uuid);
  else
    raise exception 'unknown operation' using errcode = '22023', hint = 'op_unknown';
  end case;
  return 'applied';
end $$;

revoke execute on function app.shopping_resolve_item(uuid, uuid),
  app.shopping_do_add(app.actor_t, uuid, text, text, uuid),
  app.shopping_do_check(app.actor_t, uuid, boolean),
  app.shopping_do_count(app.actor_t, uuid, int),
  app.shopping_do_spec(app.actor_t, uuid, text),
  app.shopping_do_category(app.actor_t, uuid, uuid),
  app.shopping_do_finish(app.actor_t, uuid, uuid),
  app.shopping_apply_op(app.actor_t, jsonb) from public, anon, authenticated;

-- ------------------------------------------------------------------ the batch

-- Applies [p_ops] in order and returns, per op, 'applied', 'duplicate' (seen before),
-- 'skipped' or 'rejected' with its code, plus the household's open items afterwards —
-- the authoritative state the client's mirror is replaced with.
--
-- [p_actor] establishes the device; each op may name its own acting profile ("actor"),
-- because a shared tablet queues the changes of several people while offline. One op
-- failing (a stale category, a profile removed meanwhile) rejects that op only, so a bad
-- op can never block the outbox behind it.
create function api.shopping_apply(p_actor uuid, p_ops jsonb) returns jsonb
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
                'count', i.count, 'catalog_item_id', i.catalog_item_id)
                order by i.checked, i.created_at), '[]')
                from app.shopping_item i
               where i.household_id = a.household_id and i.trip_id is null));
end $$;

revoke execute on function api.shopping_apply(uuid, jsonb) from public, anon;
grant execute on function api.shopping_apply(uuid, jsonb) to authenticated;

-- ------------------------------------------------------------------ single-item functions

-- Unchanged signatures and behaviour for the previous app release; now thin wrappers.
create or replace function api.shopping_add_item(p_actor uuid, p_name text, p_quantity text default null, p_list uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_id uuid;
begin
  v_id := app.shopping_do_add(a, p_list, p_name, p_quantity);
  perform app.broadcast(a.household_id, 'shopping');
  return v_id;
end $$;

create or replace function api.shopping_toggle_item(p_actor uuid, p_item uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_checked boolean;
begin
  select not checked into v_checked from app.shopping_item
   where id = p_item and trip_id is null and household_id = a.household_id;
  if not found then
    raise exception 'item not found' using errcode = 'P0002', hint = 'item_not_found';
  end if;
  perform app.shopping_do_check(a, p_item, v_checked);
  perform app.broadcast(a.household_id, 'shopping');
  return v_checked;
end $$;

create or replace function api.shopping_adjust_count(p_actor uuid, p_item uuid, p_delta int) returns int
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_count int;
begin
  v_count := app.shopping_do_count(a, p_item, p_delta);
  if v_count is null then
    raise exception 'item not found' using errcode = 'P0002', hint = 'item_not_found';
  end if;
  perform app.broadcast(a.household_id, 'shopping');
  return v_count;
end $$;

create or replace function api.shopping_set_item_spec(p_actor uuid, p_item uuid, p_text text) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if not app.shopping_do_spec(a, p_item, p_text) then
    raise exception 'item not found' using errcode = 'P0002', hint = 'item_not_found';
  end if;
  perform app.broadcast(a.household_id, 'shopping');
end $$;

create or replace function api.shopping_set_category(p_actor uuid, p_item uuid, p_category uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if not app.shopping_do_category(a, p_item, p_category) then
    raise exception 'item not found' using errcode = 'P0002', hint = 'item_not_found';
  end if;
  perform app.broadcast(a.household_id, 'shopping');
end $$;

create or replace function api.shopping_finish(p_actor uuid, p_list uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_result jsonb;
begin
  v_result := app.shopping_do_finish(a, p_list);
  if (v_result ->> 'bought')::int > 0 then
    perform app.broadcast(a.household_id, 'shopping');
  end if;
  return v_result;
end $$;
