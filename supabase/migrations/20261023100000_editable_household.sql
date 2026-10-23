-- Step 10, slices 1–3 (specs/16): what a family entered during J1 can be corrected.
-- Members: name, colour, avatar, kind, order, role, and "no longer with us". The family:
-- its name, time zone and locale. Devices: their label. Shopping: lists renamed and
-- removed, categories added, renamed, reordered and removed, catalogue tiles renamed and
-- forgotten.
--
-- Additive for api_version: a column, functions, one view column appended. The previous
-- app release never calls any of this; its reads keep their columns in their order.
-- Every write starts with app.actor(), audits, and the ones a screen mirrors broadcast.

-- ------------------------------------------------------------------ profile.avatar_key

-- A picture from the bundled set (specs/17 content icons); null shows the initial.
alter table app.profile
  add column avatar_key text check (avatar_key is null or avatar_key ~ '^[a-z_]{1,32}$');
grant select (avatar_key) on app.profile to authenticated;

-- The avatar is on the board and in the avatar rows, so a change wakes the screens too.
drop trigger profile_broadcast on app.profile;
create trigger profile_broadcast
  after insert or update of display_name, color, role, active, sort_order, kind,
                            default_presence_state, default_presence_label, avatar_key
  or delete on app.profile
  for each row execute function app.profile_broadcast();

-- api.members: one column appended.
create or replace view api.members with (security_invoker = true) as
  select id, household_id, display_name, color, role, active,
         sort_order, kind, default_presence_state, default_presence_label,
         app.profile_has_account(id) as has_account,
         avatar_key
    from app.profile;

-- ------------------------------------------------------------------ members

-- The profile a member function acts on: any profile of the actor's household.
create function app.member_of(a app.actor_t, p_profile uuid) returns app.profile
language plpgsql stable security definer set search_path = '' as $$
declare v app.profile;
begin
  select * into v from app.profile where id = p_profile and household_id = a.household_id;
  if not found then
    raise exception 'member not found' using errcode = 'P0002', hint = 'member_not_found';
  end if;
  return v;
end $$;

-- Name, colour, avatar and kind. A member changes their own name, colour and avatar; a
-- guardian changes anyone's, and only a guardian changes the kind. A null keeps the
-- value; the empty avatar key removes the picture.
create function api.member_update(
  p_actor uuid, p_profile uuid, p_display_name text default null, p_color text default null,
  p_kind text default null, p_avatar_key text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v      app.profile := app.member_of(a, p_profile);
  v_name text := nullif(btrim(coalesce(p_display_name, '')), '');
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
  if v_diff = '{}'::jsonb then
    return;
  end if;
  update app.profile set
    display_name = coalesce(v_name, display_name),
    color        = coalesce(upper(p_color), color),
    kind         = coalesce(p_kind, kind),
    avatar_key   = case when p_avatar_key is null then avatar_key else nullif(p_avatar_key, '') end
  where id = p_profile;
  perform app.audit(a, 'profile', p_profile, 'update', v_diff);
end $$;

-- The board's member order: the ids given, in that order, then anyone not named in their
-- old order. Re-spaced in steps of ten.
create function api.members_reorder(p_actor uuid, p_profile_ids uuid[]) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v_n    int;
begin
  perform app.require_guardian(a);
  if p_profile_ids is null or cardinality(p_profile_ids) = 0
     or (select count(distinct x) from unnest(p_profile_ids) x) <> cardinality(p_profile_ids)
     or exists (select 1 from unnest(p_profile_ids) x
                 where not exists (select 1 from app.profile p
                                    where p.id = x and p.household_id = a.household_id)) then
    raise exception 'members invalid' using errcode = '22023', hint = 'members_invalid';
  end if;
  v_n := cardinality(p_profile_ids);
  update app.profile p set sort_order = s.ord * 10
    from unnest(p_profile_ids) with ordinality as s(id, ord)
   where p.id = s.id;
  update app.profile p set sort_order = (v_n + s.rn) * 10
    from (select id, row_number() over (order by sort_order, id) rn
            from app.profile
           where household_id = a.household_id and not (id = any (p_profile_ids))) s
   where p.id = s.id;
  perform app.audit(a, 'profile', null, 'reorder', jsonb_build_object('order', to_jsonb(p_profile_ids)));
end $$;

-- Guardian or member. A guardian is an adult; the last guardian with an account stays
-- one; a demoted guardian's PIN window on shared devices ends at once.
create function api.member_set_role(p_actor uuid, p_profile uuid, p_role text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  v app.profile := app.member_of(a, p_profile);
begin
  perform app.require_guardian(a);
  if coalesce(p_role, '') not in ('guardian', 'member') then
    raise exception 'role invalid' using errcode = '22023', hint = 'role_invalid';
  end if;
  if v.role = p_role then
    return;
  end if;
  if p_role = 'guardian' and v.kind <> 'adult' then
    raise exception 'a child cannot be a guardian' using errcode = '22023', hint = 'role_child';
  end if;
  if p_role = 'member' and v.auth_user_id is not null
     and not exists (select 1 from app.profile p
                      where p.household_id = a.household_id and p.active and p.id <> p_profile
                        and p.role = 'guardian' and p.auth_user_id is not null) then
    raise exception 'last guardian with an account' using errcode = '42501', hint = 'last_guardian';
  end if;
  update app.profile set role = p_role where id = p_profile;
  if p_role = 'member' then
    update app.device set guardian_verified_until = null, guardian_verified_profile = null
     where household_id = a.household_id and guardian_verified_profile = p_profile;
  end if;
  perform app.audit(a, 'profile', p_profile, 'set_role', jsonb_build_object('role', p_role));
end $$;

-- "Nicht mehr dabei": off the board, the avatar rows, rotations and new assignments;
-- history and points stay. An adult with an account leaves first (J6); a guardian cannot
-- retire themself. Open invitations for the person are withdrawn.
create function api.member_deactivate(p_actor uuid, p_profile uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  v app.profile := app.member_of(a, p_profile);
begin
  perform app.require_guardian(a);
  if p_profile = a.profile_id then
    raise exception 'cannot deactivate yourself' using errcode = '22023', hint = 'member_self';
  end if;
  if v.auth_user_id is not null then
    raise exception 'the person has an account' using errcode = '22023', hint = 'member_has_account';
  end if;
  if not v.active then
    return;
  end if;
  update app.profile set active = false where id = p_profile;
  update app.invitation set revoked_at = now()
   where profile_id = p_profile and accepted_at is null and revoked_at is null;
  update app.device set guardian_verified_until = null, guardian_verified_profile = null
   where household_id = a.household_id and guardian_verified_profile = p_profile;
  perform app.audit(a, 'profile', p_profile, 'deactivate');
end $$;

create function api.member_reactivate(p_actor uuid, p_profile uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  v app.profile := app.member_of(a, p_profile);
begin
  perform app.require_guardian(a);
  if v.active then
    return;
  end if;
  update app.profile set active = true where id = p_profile;
  perform app.audit(a, 'profile', p_profile, 'reactivate');
end $$;

-- ------------------------------------------------------------------ household

-- Name, time zone and locale (H1: "changed in Settings later"). A null keeps the value.
create function api.household_update(
  p_actor uuid, p_name text default null, p_timezone text default null, p_locale text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
  v_diff jsonb := '{}'::jsonb;
begin
  perform app.require_guardian(a);
  if p_name is not null then
    if v_name is null or length(v_name) > 60 then
      raise exception 'household name invalid' using errcode = '22023', hint = 'household_name_invalid';
    end if;
    v_diff := v_diff || jsonb_build_object('name', v_name);
  end if;
  if p_timezone is not null then
    if not exists (select 1 from pg_timezone_names where name = p_timezone) then
      raise exception 'timezone invalid' using errcode = '22023', hint = 'timezone_invalid';
    end if;
    v_diff := v_diff || jsonb_build_object('timezone', p_timezone);
  end if;
  if p_locale is not null then
    if p_locale !~ '^[a-z]{2}(-[A-Z]{2})?$' then
      raise exception 'locale invalid' using errcode = '22023', hint = 'locale_invalid';
    end if;
    v_diff := v_diff || jsonb_build_object('locale', p_locale);
  end if;
  if v_diff = '{}'::jsonb then
    return;
  end if;
  update app.household set
    name     = coalesce(v_name, name),
    timezone = coalesce(p_timezone, timezone),
    locale   = coalesce(p_locale, locale)
  where id = a.household_id;
  perform app.audit(a, 'household', a.household_id, 'update', v_diff);
  -- The board's week and its holiday names follow the zone and the locale.
  perform app.broadcast(a.household_id, 'board');
end $$;

-- ------------------------------------------------------------------ devices

-- A guardian names any device of the family; a device may rename itself.
create function api.device_rename(p_actor uuid, p_device uuid, p_label text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  v_label text := nullif(btrim(coalesce(p_label, '')), '');
begin
  if p_device <> a.device_id then
    perform app.require_guardian(a);
  end if;
  if v_label is null or length(v_label) > 60 then
    raise exception 'label invalid' using errcode = '22023', hint = 'label_invalid';
  end if;
  if not exists (select 1 from app.device
                  where id = p_device and household_id = a.household_id and revoked_at is null) then
    raise exception 'device not found' using errcode = 'P0002', hint = 'device_not_found';
  end if;
  update app.device set label = v_label where id = p_device;
  perform app.audit(a, 'device', p_device, 'rename', jsonb_build_object('label', v_label));
end $$;

-- ------------------------------------------------------------------ shopping structure

-- Structure edits are online only (ADR-006); the mirror refetches on the broadcast.
-- Renaming, adding and ordering are open to everyone but the wall, like creating a list;
-- removing a list, a category or a tile is a guardian action.

create function api.shopping_list_update(p_actor uuid, p_list uuid, p_name text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v_list uuid;
  v_name text := btrim(coalesce(p_name, ''));
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  v_list := app.shopping_target_list(a.household_id, p_list);
  if length(v_name) not between 1 and 40 then
    raise exception 'name required' using errcode = '22023', hint = 'name_required';
  end if;
  if exists (select 1 from app.shopping_list
              where household_id = a.household_id and id <> v_list and app.fold(name) = app.fold(v_name)) then
    raise exception 'list exists' using errcode = '23505', hint = 'list_exists';
  end if;
  update app.shopping_list set name = v_name where id = v_list;
  perform app.audit(a, 'shopping_list', v_list, 'rename', jsonb_build_object('name', v_name));
  perform app.broadcast(a.household_id, 'shopping');
end $$;

-- Never the default list. Its open items move to the default list, uncategorised; its
-- trips and tiles go with it.
create function api.shopping_list_delete(p_actor uuid, p_list uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_list    uuid;
  v_default uuid;
  v_name    text;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  v_list := app.shopping_target_list(a.household_id, p_list);
  select name into v_name from app.shopping_list where id = v_list;
  select id into v_default from app.shopping_list where household_id = a.household_id and is_default;
  if v_list = v_default then
    raise exception 'the default list stays' using errcode = 'P0001', hint = 'list_default';
  end if;
  update app.shopping_item
     set list_id = v_default, category_id = null, catalog_item_id = null
   where list_id = v_list and trip_id is null;
  delete from app.shopping_list where id = v_list;
  perform app.audit(a, 'shopping_list', v_list, 'delete', jsonb_build_object('name', v_name));
  perform app.broadcast(a.household_id, 'shopping');
end $$;

-- A new category (p_category null) at the end of the walk, or a new name for one. A seeded
-- category keeps its key; the name shown is the one given here.
create function api.shopping_category_save(p_actor uuid, p_list uuid, p_category uuid, p_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v_list uuid;
  v_name text := btrim(coalesce(p_name, ''));
  v_id   uuid := p_category;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  v_list := app.shopping_target_list(a.household_id, p_list);
  if length(v_name) not between 1 and 40 then
    raise exception 'name required' using errcode = '22023', hint = 'name_required';
  end if;
  if v_id is null then
    insert into app.shopping_category (household_id, list_id, name, sort_order)
      values (a.household_id, v_list, v_name,
              (select coalesce(max(sort_order), -10) + 10 from app.shopping_category where list_id = v_list))
      returning id into v_id;
    perform app.audit(a, 'shopping_category', v_id, 'create', jsonb_build_object('name', v_name));
  else
    update app.shopping_category set name = v_name where id = v_id and list_id = v_list;
    if not found then
      raise exception 'category not found' using errcode = 'P0002', hint = 'category_not_found';
    end if;
    perform app.audit(a, 'shopping_category', v_id, 'rename', jsonb_build_object('name', v_name));
  end if;
  perform app.broadcast(a.household_id, 'shopping');
  return v_id;
end $$;

-- Its items and tiles become uncategorised (the foreign keys set null).
create function api.shopping_category_delete(p_actor uuid, p_category uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  delete from app.shopping_category where id = p_category and household_id = a.household_id;
  if not found then
    raise exception 'category not found' using errcode = 'P0002', hint = 'category_not_found';
  end if;
  perform app.audit(a, 'shopping_category', p_category, 'delete');
  perform app.broadcast(a.household_id, 'shopping');
end $$;

-- The walking order: the ids given, in that order, then the rest in their old order.
create function api.shopping_categories_reorder(p_actor uuid, p_list uuid, p_category_ids uuid[])
returns void language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v_list uuid;
  v_n    int;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  v_list := app.shopping_target_list(a.household_id, p_list);
  if p_category_ids is null or cardinality(p_category_ids) = 0
     or (select count(distinct x) from unnest(p_category_ids) x) <> cardinality(p_category_ids)
     or exists (select 1 from unnest(p_category_ids) x
                 where not exists (select 1 from app.shopping_category c where c.id = x and c.list_id = v_list)) then
    raise exception 'categories invalid' using errcode = '22023', hint = 'categories_invalid';
  end if;
  v_n := cardinality(p_category_ids);
  update app.shopping_category c set sort_order = (s.ord - 1) * 10
    from unnest(p_category_ids) with ordinality as s(id, ord)
   where c.id = s.id;
  update app.shopping_category c set sort_order = (v_n + s.rn - 1) * 10
    from (select id, row_number() over (order by sort_order, id) rn
            from app.shopping_category
           where list_id = v_list and not (id = any (p_category_ids))) s
   where c.id = s.id;
  perform app.audit(a, 'shopping_list', v_list, 'categories_reorder');
  perform app.broadcast(a.household_id, 'shopping');
end $$;

-- A tile's name and category; the history keeps what was bought under the old name.
-- A null keeps the value.
create function api.catalog_item_update(p_actor uuid, p_item uuid, p_name text default null, p_category uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v      app.catalog_item;
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  select * into v from app.catalog_item where id = p_item and household_id = a.household_id;
  if not found then
    raise exception 'tile not found' using errcode = 'P0002', hint = 'catalog_not_found';
  end if;
  if p_name is not null then
    if v_name is null or length(v_name) > 120 then
      raise exception 'name required' using errcode = '22023', hint = 'name_required';
    end if;
    if exists (select 1 from app.catalog_item
                where list_id = v.list_id and id <> p_item and folded_name = app.fold(v_name)) then
      raise exception 'tile exists' using errcode = '23505', hint = 'catalog_exists';
    end if;
  end if;
  if p_category is not null and not exists (select 1 from app.shopping_category
                                              where id = p_category and list_id = v.list_id) then
    raise exception 'category not found' using errcode = 'P0002', hint = 'category_not_found';
  end if;
  update app.catalog_item set
    name        = coalesce(v_name, name),
    folded_name = coalesce(app.fold(v_name), folded_name),
    category_id = coalesce(p_category, category_id)
  where id = p_item;
  perform app.audit(a, 'catalog_item', p_item, 'update',
                    jsonb_strip_nulls(jsonb_build_object('name', v_name, 'category_id', p_category)));
  perform app.broadcast(a.household_id, 'shopping');
end $$;

-- "Nicht mehr vorschlagen": the tile goes; the history keeps its text. The next purchase
-- of the name teaches it again.
create function api.catalog_item_delete(p_actor uuid, p_item uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor); v_name text;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  delete from app.catalog_item where id = p_item and household_id = a.household_id returning name into v_name;
  if not found then
    raise exception 'tile not found' using errcode = 'P0002', hint = 'catalog_not_found';
  end if;
  perform app.audit(a, 'catalog_item', p_item, 'delete', jsonb_build_object('name', v_name));
  perform app.broadcast(a.household_id, 'shopping');
end $$;

-- ------------------------------------------------------------------ grants

revoke execute on function app.member_of(app.actor_t, uuid) from public, anon, authenticated;
revoke execute on function
  api.member_update(uuid, uuid, text, text, text, text), api.members_reorder(uuid, uuid[]),
  api.member_set_role(uuid, uuid, text), api.member_deactivate(uuid, uuid), api.member_reactivate(uuid, uuid),
  api.household_update(uuid, text, text, text), api.device_rename(uuid, uuid, text),
  api.shopping_list_update(uuid, uuid, text), api.shopping_list_delete(uuid, uuid),
  api.shopping_category_save(uuid, uuid, uuid, text), api.shopping_category_delete(uuid, uuid),
  api.shopping_categories_reorder(uuid, uuid, uuid[]),
  api.catalog_item_update(uuid, uuid, text, uuid), api.catalog_item_delete(uuid, uuid)
  from public, anon;
grant execute on function
  api.member_update(uuid, uuid, text, text, text, text), api.members_reorder(uuid, uuid[]),
  api.member_set_role(uuid, uuid, text), api.member_deactivate(uuid, uuid), api.member_reactivate(uuid, uuid),
  api.household_update(uuid, text, text, text), api.device_rename(uuid, uuid, text),
  api.shopping_list_update(uuid, uuid, text), api.shopping_list_delete(uuid, uuid),
  api.shopping_category_save(uuid, uuid, uuid, text), api.shopping_category_delete(uuid, uuid),
  api.shopping_categories_reorder(uuid, uuid, uuid[]),
  api.catalog_item_update(uuid, uuid, text, uuid), api.catalog_item_delete(uuid, uuid)
  to authenticated;
