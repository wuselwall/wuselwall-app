-- M0.2 Shopping list, online only (docs/07, docs/16 step 6).
-- Offline outbox, catalogue and tile picker are M1.1.

create table app.shopping_list (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references app.household on delete cascade,
  status       text not null default 'active' check (status in ('active', 'done')),
  created_at   timestamptz not null default now(),
  finished_at  timestamptz
);
-- At most one active list per household.
create unique index shopping_list_one_active on app.shopping_list (household_id) where status = 'active';

create table app.shopping_item (
  id           uuid primary key default gen_random_uuid(),
  list_id      uuid not null references app.shopping_list on delete cascade,
  household_id uuid not null references app.household on delete cascade,
  name         text not null check (length(btrim(name)) between 1 and 120),
  quantity     text check (quantity is null or length(quantity) <= 40),
  checked      boolean not null default false,
  added_by     uuid references app.profile on delete set null,
  checked_by   uuid references app.profile on delete set null,
  checked_at   timestamptz,
  created_at   timestamptz not null default now()
);
create index on app.shopping_item (list_id);

alter table app.shopping_list enable row level security;
alter table app.shopping_item enable row level security;
alter table app.shopping_list force row level security;
alter table app.shopping_item force row level security;

create policy shopping_list_read on app.shopping_list for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy shopping_item_read on app.shopping_item for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.shopping_list to postgres using (true) with check (true);
create policy owner_all on app.shopping_item to postgres using (true) with check (true);

grant select on app.shopping_list, app.shopping_item to authenticated;

-- "Something in <topic> changed — refetch." The payload carries no data on purpose.
create function app.broadcast(p_household uuid, p_topic text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform realtime.send(jsonb_build_object('topic', p_topic), 'invalidate',
                        'household:' || p_household, true);
end $$;

-- Only devices of the household may listen to its private channel, and never when revoked.
create policy household_channel_read on realtime.messages for select to authenticated
  using (
    extension = 'broadcast'
    and realtime.topic() = 'household:' || app.jwt_household()::text
    and app.device_ok()
  );

create view api.shopping_items with (security_invoker = true) as
  select i.id, i.name, i.quantity, i.checked, i.added_by, i.checked_by, i.checked_at, i.created_at
    from app.shopping_item i
    join app.shopping_list l on l.id = i.list_id
   where l.status = 'active';
grant select on api.shopping_items to authenticated;

create function app.shopping_active_list(p_household uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  select id into v_id from app.shopping_list where household_id = p_household and status = 'active';
  if v_id is null then
    insert into app.shopping_list (household_id) values (p_household) returning id into v_id;
  end if;
  return v_id;
end $$;

create function api.shopping_add_item(p_actor uuid, p_name text, p_quantity text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_id uuid;
begin
  if length(btrim(coalesce(p_name, ''))) = 0 then
    raise exception 'name required' using errcode = '22023', hint = 'name_required';
  end if;
  insert into app.shopping_item (list_id, household_id, name, quantity, added_by)
  values (app.shopping_active_list(a.household_id), a.household_id, btrim(p_name),
          nullif(btrim(coalesce(p_quantity, '')), ''), a.profile_id)
  returning id into v_id;
  perform app.audit(a, 'shopping_item', v_id, 'create', jsonb_build_object('name', btrim(p_name)));
  perform app.broadcast(a.household_id, 'shopping');
  return v_id;
end $$;

create function api.shopping_toggle_item(p_actor uuid, p_item uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_checked boolean;
begin
  update app.shopping_item i set
    checked    = not i.checked,
    checked_by = case when not i.checked then a.profile_id end,
    checked_at = case when not i.checked then now() end
   from app.shopping_list l
   where i.id = p_item and l.id = i.list_id and l.status = 'active'
     and i.household_id = a.household_id
  returning i.checked into v_checked;
  if not found then
    raise exception 'item not found' using errcode = 'P0002', hint = 'item_not_found';
  end if;
  perform app.audit(a, 'shopping_item', p_item, case when v_checked then 'check' else 'uncheck' end);
  perform app.broadcast(a.household_id, 'shopping');
  return v_checked;
end $$;

-- Finish the trip: the list is closed and whatever was not ticked carries over to a fresh list.
create function api.shopping_finish(p_actor uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v_old  uuid;
  v_new  uuid;
  v_done int;
  v_left int;
begin
  select id into v_old from app.shopping_list where household_id = a.household_id and status = 'active';
  if v_old is null then
    return jsonb_build_object('bought', 0, 'carried_over', 0);
  end if;
  update app.shopping_list set status = 'done', finished_at = now() where id = v_old;
  insert into app.shopping_list (household_id) values (a.household_id) returning id into v_new;
  update app.shopping_item set list_id = v_new where list_id = v_old and not checked;
  get diagnostics v_left = row_count;
  select count(*) into v_done from app.shopping_item where list_id = v_old;
  perform app.audit(a, 'shopping_list', v_old, 'finish',
                    jsonb_build_object('bought', v_done, 'carried_over', v_left));
  perform app.broadcast(a.household_id, 'shopping');
  return jsonb_build_object('bought', v_done, 'carried_over', v_left);
end $$;

revoke execute on all functions in schema api from public, anon;
grant execute on function api.health() to anon, authenticated;
grant execute on function api.setup_household(text, text, text, text, text, text, text) to anon;
grant execute on function api.enrol_device(text) to anon;
grant execute on function api.shopping_add_item(uuid, text, text) to authenticated;
grant execute on function api.shopping_toggle_item(uuid, uuid) to authenticated;
grant execute on function api.shopping_finish(uuid) to authenticated;
revoke execute on all functions in schema app from public, anon, authenticated;
grant execute on function app.jwt_household(), app.jwt_device(), app.device_ok() to authenticated;
