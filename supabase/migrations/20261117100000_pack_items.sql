-- One-off things to bring (specs/15 "One-off things to bring", FR-7.15, issue #289).
--
-- The packing list knew only the equipment of a timetable's subjects (Sport → Sportsachen,
-- FR-7.12). A school letter asks for more: "Turnbeutel", "Zettel unterschrieben", "5 Fr. für den
-- Ausflug". Such a thing belongs to one child and one day, not to a subject, and it may be for a
-- child without a timetable (kindergarten) or a day without school. It joins that day's packing
-- list wherever the list shows: the child's Today, the Stundenplan section, the board's pack strip,
-- the evening packing reminder and Siri's answer.
--
--   * app.pack_item: one thing (title, 1 to 80 characters) for one child on one date. Readable by
--     every device of the household (RLS, grant select), written only by the functions below.
--   * View api.pack_items. The school-week and board-week functions read it for their window.
--   * api.pack_item_save(actor, id, profile_id, on_date, title) creates (id null) or changes one
--     and answers {id}; the same title again for the same child and date answers the existing id.
--     api.pack_item_delete(actor, id). Both audit and broadcast the topic 'school'.
--   * Who: an adult for any child of the household, a child only for itself. Every device class,
--     the wall included (its acting member), as for the meals' "isst mit".
--   * The school.equipment_hint setting switches off the subjects' notes, not these: a thing a
--     person wrote down for a day is always shown.
--   * api.shortcut_context adds 'pack' (the window's things) to its 'school' part, so Siri's "what
--     does Mia have tomorrow" names them. The assistant context (MCP, on hold) is left as it is.
--   * The export carries the table.
--
-- Errors (hint in brackets):
--   WW-PACK-001 pack item invalid (pack_item_invalid)   no title, too long, no date, a date more
--                                                       than 400 days away, not an active child of
--                                                       the household, more than 20 on a day
--   42501 pack_item_not_yours                           a child for another child
--   P0002 pack_item_not_found                           also for another household's id
--
-- api_version: unchanged. Additive: a table, a view, two functions and one more key in two
-- function answers. An older app neither reads nor writes any of it. api.server_info announces
-- 'pack-items'; an app on an older server hides the entry points.

-- ================================================================== table

create table app.pack_item (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  -- The child's things go with the child.
  profile_id            uuid not null references app.profile on delete cascade,
  on_date               date not null,
  title                 text not null check (length(btrim(title)) between 1 and 80),
  created_by_profile_id uuid references app.profile on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index pack_item_household_date_idx on app.pack_item (household_id, on_date);
create index pack_item_profile_idx on app.pack_item (profile_id);

alter table app.pack_item enable row level security;
alter table app.pack_item force row level security;

create policy pack_item_read on app.pack_item for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.pack_item to postgres using (true) with check (true);

revoke all on app.pack_item from public, anon, authenticated;
grant select on app.pack_item to authenticated;

create view api.pack_items with (security_invoker = true) as
  select i.id, i.profile_id, i.on_date, i.title, i.created_by_profile_id, i.created_at,
         i.updated_at
    from app.pack_item i;

grant select on api.pack_items to authenticated;
revoke all on api.pack_items from anon;

-- ================================================================== writes

create function app.pack_fail() returns void
language plpgsql immutable set search_path = '' as $$
begin
  raise exception 'WW-PACK-001 pack item invalid' using errcode = '22023', hint = 'pack_item_invalid';
end $$;

-- Whether the acting person may write a thing for p_profile: an adult for any child, a child only
-- for itself. p_profile must be an active child of the household.
create function app.pack_check_target(a app.actor_t, p_profile uuid) returns void
language plpgsql stable set search_path = '' as $$
begin
  if p_profile is null or not exists (
       select 1 from app.profile p
        where p.id = p_profile and p.household_id = a.household_id and p.active
          and p.kind = 'child') then
    perform app.pack_fail();
  end if;
  if (select p.kind from app.profile p where p.id = a.profile_id) is distinct from 'adult'
     and p_profile <> a.profile_id then
    raise exception 'not your thing to bring' using errcode = '42501', hint = 'pack_item_not_yours';
  end if;
end $$;

revoke all on function app.pack_fail(), app.pack_check_target(app.actor_t, uuid)
  from public, anon, authenticated;

-- Creates (p_id null) or changes one thing. Answers {id}. The same title (trimmed, ignoring case)
-- for the same child and date answers the thing that is there, so a retried save adds nothing.
create function api.pack_item_save(p_actor uuid, p_id uuid, p_profile_id uuid, p_on_date date,
                                   p_title text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  v_title text := btrim(coalesce(p_title, ''));
  v_old   app.pack_item;
  v_same  uuid;
  v_id    uuid;
begin
  if length(v_title) not between 1 and 80 or p_on_date is null
     or abs(p_on_date - current_date) > 400 then
    perform app.pack_fail();
  end if;
  perform app.pack_check_target(a, p_profile_id);

  if p_id is not null then
    select * into v_old from app.pack_item
     where id = p_id and household_id = a.household_id for update;
    if not found then
      raise exception 'pack item not found' using errcode = 'P0002', hint = 'pack_item_not_found';
    end if;
    -- A child moves only its own things, and only to itself.
    perform app.pack_check_target(a, v_old.profile_id);
  end if;

  perform pg_advisory_xact_lock(hashtextextended('pack:' || p_profile_id::text || ':' || p_on_date::text, 0));
  select i.id into v_same from app.pack_item i
   where i.profile_id = p_profile_id and i.on_date = p_on_date
     and lower(i.title) = lower(v_title) and i.id is distinct from p_id
   limit 1;
  if v_same is not null then
    if p_id is not null then
      -- Changed into a thing the day already has: one is enough.
      delete from app.pack_item where id = p_id;
      perform app.audit(a, 'pack_item', p_id, 'delete',
                        jsonb_build_object('profile_id', v_old.profile_id, 'on_date', v_old.on_date,
                                           'title', v_old.title, 'merged_into', v_same));
      perform app.broadcast(a.household_id, 'school');
    end if;
    return jsonb_build_object('id', v_same);
  end if;

  if (p_id is null or v_old.profile_id <> p_profile_id or v_old.on_date <> p_on_date)
     and (select count(*) from app.pack_item i
           where i.profile_id = p_profile_id and i.on_date = p_on_date) >= 20 then
    perform app.pack_fail();
  end if;

  if p_id is null then
    insert into app.pack_item (household_id, profile_id, on_date, title, created_by_profile_id)
    values (a.household_id, p_profile_id, p_on_date, v_title, a.profile_id)
    returning id into v_id;
    perform app.audit(a, 'pack_item', v_id, 'create',
                      jsonb_build_object('profile_id', p_profile_id, 'on_date', p_on_date,
                                         'title', v_title));
  else
    v_id := p_id;
    update app.pack_item set profile_id = p_profile_id, on_date = p_on_date, title = v_title,
           updated_at = now()
     where id = p_id;
    perform app.audit(a, 'pack_item', v_id, 'update',
                      jsonb_build_object('profile_id', p_profile_id, 'on_date', p_on_date,
                                         'title', v_title));
  end if;
  perform app.broadcast(a.household_id, 'school');
  return jsonb_build_object('id', v_id);
end $$;

create function api.pack_item_delete(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  v app.pack_item;
begin
  select * into v from app.pack_item where id = p_id and household_id = a.household_id for update;
  if not found then
    raise exception 'pack item not found' using errcode = 'P0002', hint = 'pack_item_not_found';
  end if;
  -- Not pack_check_target: a thing for a child who has since left can still be removed.
  if (select p.kind from app.profile p where p.id = a.profile_id) is distinct from 'adult'
     and v.profile_id <> a.profile_id then
    raise exception 'not your thing to bring' using errcode = '42501', hint = 'pack_item_not_yours';
  end if;
  delete from app.pack_item where id = p_id;
  perform app.audit(a, 'pack_item', p_id, 'delete',
                    jsonb_build_object('profile_id', v.profile_id, 'on_date', v.on_date,
                                       'title', v.title));
  perform app.broadcast(a.household_id, 'school');
end $$;

revoke all on function api.pack_item_save(uuid, uuid, uuid, date, text),
  api.pack_item_delete(uuid, uuid) from public, anon;
grant execute on function api.pack_item_save(uuid, uuid, uuid, date, text),
  api.pack_item_delete(uuid, uuid) to authenticated;

-- ================================================================== Shortcuts

-- The body of 20261016120000_assistant_keys.sql, plus 'pack' beside 'school': the things dated in
-- the window, by date, then in the order they were noted.
create or replace function api.shortcut_context(p_token text, p_parts text[], p_from date default null,
                                                p_days int default 1)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a     app.actor_t := app.shortcut_actor(p_token);
  v_out jsonb;
begin
  -- A shortcut reads what its answers need; the assistant's wider parts are not for it.
  v_out := app.key_context(a, array(select x from unnest(p_parts) x
                                     where x in ('calendar', 'school', 'meals', 'tasks')),
                           p_from, p_days);
  if 'school' = any(p_parts) then
    v_out := v_out || jsonb_build_object('pack', (
      select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'member_id', i.profile_id,
                                                   'date', i.on_date, 'title', i.title)
                                order by i.on_date, i.created_at, i.id), '[]'::jsonb)
        from app.pack_item i
       where i.household_id = a.household_id
         and i.on_date between (v_out #>> '{window,from}')::date and (v_out #>> '{window,to}')::date));
  end if;
  return v_out;
end $$;

-- ================================================================== export

-- Beside the timetable's tables.
insert into app.export_table (name, position, omit, keep) values
  ('pack_item', 195, '{}', null);

-- ================================================================== announce

-- As in 20261115110000_trips.sql, plus 'pack-items'.
create or replace function api.server_info()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'api_version', 1,
    'min_app_version', '1.0.0',
    'household_creation', case when app.household_creation_mode() = 'code' then 'token' else 'open' end,
    'claimed', app.server_claimed(),
    'features', jsonb_build_array(
      'calendar', 'ics', 'calendar-import', 'school', 'tasks', 'meals', 'shopping', 'holidays',
      'lighter-day', 'event-templates', 'password-reset', 'claim', 'local-matching', 'event-import',
      'shopping-start', 'event-reminder', 'services', 'trips', 'pack-items'
    )
  );
$$;
