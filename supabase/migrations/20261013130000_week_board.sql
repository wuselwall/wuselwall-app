-- The week board's read model (specs/09 "The week board", specs/04 profile columns).
-- One call, api.board_week, returns everything the kitchen screen draws for one week.
-- Presence, timetables, meals and open tasks come later (M1.3, M1.2); their keys are
-- already present and empty so the client never has to special-case their absence.

-- ------------------------------------------------------------------ profile columns

alter table app.profile
  add column sort_order             int not null default 0,
  add column kind                   text not null default 'adult' check (kind in ('adult', 'child')),
  add column default_presence_state text check (default_presence_state in
                                      ('working', 'home_office', 'travel', 'away', 'off', 'childcare')),
  add column default_presence_label text check (default_presence_label is null
                                      or length(btrim(default_presence_label)) between 1 and 40);

-- Existing households keep the order they were created in, in steps of ten so a member can
-- be moved between two others without renumbering everyone.
update app.profile p set sort_order = s.rn * 10
  from (select id, row_number() over (partition by household_id order by created_at, id) rn
          from app.profile) s
 where p.id = s.id;

-- A member without an account is most likely a child: the household's adults who do not
-- have an account yet are still guardians or members with a device, and are corrected by
-- hand. Guardians are always adults (ADR-014).
update app.profile set kind = 'child' where role = 'member' and auth_user_id is null;

-- The API reads the new columns as the caller, so they need column grants like the others.
grant select (sort_order, kind, default_presence_state, default_presence_label) on app.profile to authenticated;

-- A profile inserted without a sort order goes to the end of its household.
create function app.profile_default_sort() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_next int;
begin
  if new.sort_order = 0 then
    select coalesce(max(p.sort_order), 0) + 10 into v_next
      from app.profile p where p.household_id = new.household_id;
    new.sort_order := v_next;
  end if;
  return new;
end $$;

create trigger profile_default_sort before insert on app.profile
  for each row execute function app.profile_default_sort();

-- The kiosk refetches its members on the 'members' invalidation. Only the columns the board
-- shows fire it, so a PIN attempt (which updates pin_failures) does not wake every screen.
-- Definer, like app.broadcast: a trigger has no caller privileges of its own to rely on.
create function app.profile_broadcast() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_household uuid;
begin
  if tg_op = 'DELETE' then
    v_household := old.household_id;
  else
    v_household := new.household_id;
  end if;
  perform app.broadcast(v_household, 'members');
  return null;
end $$;

create trigger profile_broadcast
  after insert or update of display_name, color, role, active, sort_order, kind,
                            default_presence_state, default_presence_label
  or delete on app.profile
  for each row execute function app.profile_broadcast();

revoke all on function app.profile_default_sort(), app.profile_broadcast()
  from public, anon, authenticated;

-- ------------------------------------------------------------------ api: members view

-- Same columns in the same order; the new ones are appended. The view stays security
-- invoker, so RLS and the column grants above still decide what a caller sees.
create or replace view api.members with (security_invoker = true) as
  select id, household_id, display_name, color, role, active,
         sort_order, kind, default_presence_state, default_presence_label
    from app.profile;

-- ------------------------------------------------------------------ api: the board

-- Security invoker on purpose: every table is read under the caller's RLS, so a caller only
-- ever sees their own household, and a revoked device sees no household at all.
create function api.board_week(p_week_start date default null) returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
declare
  h              app.household;
  v_now          timestamp;
  v_today        date;
  v_monday       date;
  v_rollover     jsonb;
  v_rollover_at  timestamp;
  v_day_parts    jsonb;
  v_member_label jsonb;
  v_members      jsonb;
  v_days         jsonb;
  v_shopping     int;
begin
  if not app.device_ok() then
    raise exception 'WW-BOARD-001 no household' using errcode = '42501', hint = 'device_revoked';
  end if;
  select * into h from app.household where id = app.jwt_household();
  if not found then
    raise exception 'WW-BOARD-001 no household' using errcode = '42501', hint = 'device_revoked';
  end if;

  -- Effective settings: the household's override, else the curated default (specs/21).
  v_rollover := coalesce(
    (select s.value from app.household_setting s
      where s.household_id = h.id and s.key = 'board.rollover' and s.profile_id is null and s.device_id is null
      limit 1),
    (select d.default_value from app.setting_definition d where d.key = 'board.rollover'));
  v_day_parts := coalesce(
    (select s.value from app.household_setting s
      where s.household_id = h.id and s.key = 'board.day_parts' and s.profile_id is null and s.device_id is null
      limit 1),
    (select d.default_value from app.setting_definition d where d.key = 'board.day_parts'));
  v_member_label := coalesce(
    (select s.value from app.household_setting s
      where s.household_id = h.id and s.key = 'board.member_label' and s.profile_id is null and s.device_id is null
      limit 1),
    (select d.default_value from app.setting_definition d where d.key = 'board.member_label'));

  -- Local wall-clock time of the household. The week is the one containing today, unless the
  -- rollover point of the week has passed (Saturday noon by default: Sunday's planning
  -- session looks at the week it plans). An explicit week start is taken as given.
  v_now   := now() at time zone h.timezone;
  v_today := v_now::date;
  if p_week_start is not null then
    v_monday := date_trunc('week', p_week_start::timestamp)::date;
  else
    v_monday := date_trunc('week', v_today::timestamp)::date;
    v_rollover_at := (v_monday + ((v_rollover ->> 'weekday')::int - 1)) + (v_rollover ->> 'time')::time;
    if v_now >= v_rollover_at then
      v_monday := v_monday + 7;
    end if;
  end if;

  -- Members in the household's order. The baseline is the default presence, if one is set.
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', p.id,
           'display_name', p.display_name,
           'color', p.color,
           'kind', p.kind,
           'baseline', case when p.default_presence_state is not null
                            then jsonb_build_object('state', p.default_presence_state,
                                                    'label', p.default_presence_label)
                       end)
         -- created_at is not in authenticated's column grant; ties are broken by id.
         order by p.sort_order, p.id), '[]'::jsonb)
    into v_members
    from app.profile p
   where p.household_id = h.id and p.active;

  -- Seven days, always: every column has the same zones (specs/09). The zones that do not
  -- exist yet (calendar, timetables, meals) are present and empty.
  select coalesce(jsonb_agg(jsonb_build_object(
           'date', to_char((v_monday + g)::timestamp, 'YYYY-MM-DD'),
           'events', '[]'::jsonb,
           'busy_until', '[]'::jsonb,
           'school', '[]'::jsonb,
           'meal', null::jsonb)
         order by g), '[]'::jsonb)
    into v_days
    from generate_series(0, 6) g;

  -- Open items on the household's default list. Open means not ticked and not bought:
  -- a finished trip moves its items out of the list (trip_id), see the shopping migrations.
  select count(*)::int into v_shopping
    from app.shopping_item i
    join app.shopping_list l on l.id = i.list_id
   where l.household_id = h.id and l.is_default and i.trip_id is null and not i.checked;

  return jsonb_build_object(
    'week_start', to_char(v_monday::timestamp, 'YYYY-MM-DD'),
    'today', to_char(v_today::timestamp, 'YYYY-MM-DD'),
    'generated_at', now(),
    'timezone', h.timezone,
    'settings', jsonb_build_object('day_parts', v_day_parts, 'member_label', v_member_label),
    'members', v_members,
    'presence', '[]'::jsonb,
    'timetables', '[]'::jsonb,
    'days', v_days,
    'open_tasks', '[]'::jsonb,
    'shopping_count', v_shopping);
end $$;

revoke all on function api.board_week(date) from public, anon;
grant execute on function api.board_week(date) to authenticated;
