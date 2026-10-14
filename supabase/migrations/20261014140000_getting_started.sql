-- Getting-started card (specs/20 "The getting-started card", "Empty states", FR-5.17).
--
-- The card is derived from data, never ticked by hand: api.getting_started computes each item
-- from the household's devices, profiles, feed tokens and school. A guardian dismisses an item
-- (household-wide, or for this guardian only for set_pin); a dismissal is the only state stored
-- here. Kiosks and members get nothing: the card is for the adult Today tab.

-- ------------------------------------------------------------------ table

create table app.getting_started_dismissal (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references app.household on delete cascade,
  -- Null for household-wide items; the guardian's profile for set_pin.
  profile_id    uuid references app.profile on delete cascade,
  item          text not null check (item in ('invite_partner', 'connect_tablet', 'wall_display',
                                              'set_pin', 'subscribe_feed', 'school')),
  dismissed_at  timestamptz not null default now()
);
create unique index getting_started_dismissal_once on app.getting_started_dismissal
  (household_id, coalesce(profile_id, '00000000-0000-0000-0000-000000000000'::uuid), item);

-- ------------------------------------------------------------------ RLS

alter table app.getting_started_dismissal enable row level security;
alter table app.getting_started_dismissal force row level security;

create policy getting_started_dismissal_read on app.getting_started_dismissal for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.getting_started_dismissal to postgres using (true) with check (true);

revoke all on app.getting_started_dismissal from public, anon, authenticated;
grant select on app.getting_started_dismissal to authenticated;

-- ------------------------------------------------------------------ internals

-- Whether the item is dismissed for this household, or for this profile (set_pin).
create function app.getting_started_dismissed(p_household uuid, p_profile uuid, p_item text)
returns boolean language sql stable set search_path = '' as $$
  select exists (
    select 1 from app.getting_started_dismissal d
     where d.household_id = p_household
       and d.item = p_item
       and (d.profile_id is null or d.profile_id = p_profile))
$$;

revoke all on function app.getting_started_dismissed(uuid, uuid, text) from public, anon, authenticated;

-- ------------------------------------------------------------------ api: reads

-- The open and done items the caller should see, in card order. Items are omitted when their
-- "shown when" is false or when they are dismissed. Only a guardian on a personal or shared
-- device gets anything; members and kiosks get [].
create function api.getting_started(p_actor uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_out     jsonb := '[]'::jsonb;
  v_guards  int;
  v_child   boolean;
  v_tablet  boolean;
  v_kiosk   boolean;
  v_pin     boolean;
  v_feed    boolean;
  v_school  boolean;
begin
  if a.profile_role <> 'guardian' or a.device_class = 'kiosk' then
    return v_out;
  end if;

  select count(*) into v_guards from app.profile
   where household_id = a.household_id and role = 'guardian' and auth_user_id is not null and active;
  select exists (select 1 from app.profile
                  where household_id = a.household_id and role = 'member' and active) into v_child;
  select exists (select 1 from app.device
                  where household_id = a.household_id and class = 'shared' and revoked_at is null) into v_tablet;
  select exists (select 1 from app.device
                  where household_id = a.household_id and class = 'kiosk' and revoked_at is null) into v_kiosk;
  select exists (select 1 from app.calendar_feed_token
                  where household_id = a.household_id and revoked_at is null) into v_feed;
  select exists (select 1 from app.school where household_id = a.household_id)
     and exists (select 1 from app.timetable where household_id = a.household_id) into v_school;
  select coalesce((select pin_hash is not null from app.profile where id = a.profile_id), false) into v_pin;

  if v_guards < 2 and not app.getting_started_dismissed(a.household_id, a.profile_id, 'invite_partner') then
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'item', 'invite_partner', 'done', false, 'scope', 'household'));
  end if;

  if v_child and not app.getting_started_dismissed(a.household_id, a.profile_id, 'connect_tablet') then
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'item', 'connect_tablet', 'done', v_tablet, 'scope', 'household'));
  end if;

  if not app.getting_started_dismissed(a.household_id, a.profile_id, 'wall_display') then
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'item', 'wall_display', 'done', v_kiosk, 'scope', 'household'));
  end if;

  if (v_tablet or v_kiosk) and not app.getting_started_dismissed(a.household_id, a.profile_id, 'set_pin') then
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'item', 'set_pin', 'done', v_pin, 'scope', 'profile'));
  end if;

  if not app.getting_started_dismissed(a.household_id, a.profile_id, 'subscribe_feed') then
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'item', 'subscribe_feed', 'done', v_feed, 'scope', 'household'));
  end if;

  if v_child and not app.getting_started_dismissed(a.household_id, a.profile_id, 'school') then
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'item', 'school', 'done', v_school, 'scope', 'household'));
  end if;

  return v_out;
end $$;

-- ------------------------------------------------------------------ api: guardian functions

-- Dismisses one item. Household items are dismissed for everyone; set_pin only for the caller.
create function api.getting_started_dismiss(p_actor uuid, p_item text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  v_scope_profile boolean;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);

  if p_item not in ('invite_partner', 'connect_tablet', 'wall_display', 'set_pin', 'subscribe_feed', 'school') then
    raise exception 'WW-ONB-001 unknown getting-started item' using errcode = '22023',
      hint = 'getting_started_item_unknown';
  end if;

  v_scope_profile := p_item = 'set_pin';
  insert into app.getting_started_dismissal (household_id, profile_id, item)
  values (a.household_id, case when v_scope_profile then a.profile_id end, p_item)
  on conflict (household_id, coalesce(profile_id, '00000000-0000-0000-0000-000000000000'::uuid), item)
  do nothing;

  perform app.audit(a, 'getting_started', null, 'dismiss',
                    jsonb_build_object('item', p_item, 'scope', case when v_scope_profile then 'profile' else 'household' end));
end $$;

-- Brings the card back: removes the household's dismissals and this guardian's own.
create function api.getting_started_restore(p_actor uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);

  delete from app.getting_started_dismissal
   where household_id = a.household_id
     and (profile_id is null or profile_id = a.profile_id);
  perform app.audit(a, 'getting_started', null, 'restore');
end $$;

-- ------------------------------------------------------------------ grants

revoke all on function api.getting_started(uuid), api.getting_started_dismiss(uuid, text),
  api.getting_started_restore(uuid) from public, anon;
grant execute on function api.getting_started(uuid), api.getting_started_dismiss(uuid, text),
  api.getting_started_restore(uuid) to authenticated;
