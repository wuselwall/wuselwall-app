-- The usual week (issue #81, specs/15 "The baseline"): a member's usual place per weekday
-- instead of one place for every day, so a part-time week is zero input and only real
-- deviations are loud. Three levels, all optional beyond the first:
--
--   1. one usual place per weekday (or none: a free weekend draws nothing);
--   2. up to three time slots on a day ("Büro 8–12, Homeoffice 13–17");
--   3. alternating weeks A and B, anchored on the Monday of a week A
--      (profile.usual_week_anchor). Calendar-week parity is not used: a year with a
--      week 53 would make two odd weeks follow each other.
--
-- Like the single baseline, the usual week is display only: it is never an event, never
-- reaches the ICS feed and does not decide who eats (specs/04 "The baseline is on the
-- profile"). The board-week function resolves it per day (supabase/functions/_shared/
-- usual_week.ts) and leaves it out on public holidays.
--
-- Additive for api_version: a table, a column, a view and a function. The previous app
-- release keeps reading members[].baseline from api.board_week and writing it with
-- api.member_baseline_set; profile.default_presence_* stays as that summary, kept up to
-- date by both write functions (member_baseline_set fills Monday to Friday).
--
-- Errors (raised with the message 'WW-CAL-0nn ...' and the hint in the second column):
--   WW-CAL-008  usual week invalid  (hint usual_week_invalid)  shape, state, label, times,
--               overlapping slots, more than three slots, week B without an anchor

-- ------------------------------------------------------------------ the anchor

alter table app.profile
  add column usual_week_anchor date check (extract(isodow from usual_week_anchor) = 1);

grant select (usual_week_anchor) on app.profile to authenticated;

-- ------------------------------------------------------------------ the slots

-- One row per usual place of a weekday. A row without times is the whole day and is then
-- the day's only row; timed rows (at most three) do not overlap. Week 0 is week A, or every
-- week when the profile has no anchor; week 1 is week B.
create table app.usual_presence (
  household_id uuid not null references app.household on delete cascade,
  profile_id   uuid not null references app.profile on delete cascade,
  week         smallint not null default 0 check (week in (0, 1)),
  weekday      smallint not null check (weekday between 1 and 7),   -- ISO: 1 = Monday
  position     smallint not null check (position between 1 and 3),
  state        text not null check (state in
                 ('working', 'home_office', 'travel', 'away', 'off', 'childcare')),
  label        text check (label is null or length(btrim(label)) between 1 and 40),
  starts       time,
  ends         time,
  check ((starts is null) = (ends is null)),
  check (starts < ends),
  primary key (profile_id, week, weekday, position)
);
create index on app.usual_presence (household_id);

alter table app.usual_presence enable row level security;
alter table app.usual_presence force row level security;

create policy usual_presence_read on app.usual_presence for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.usual_presence to postgres using (true) with check (true);

-- No write grants: every change goes through api.member_usual_week_set.
grant select on app.usual_presence to authenticated;

-- Existing baselines become Monday to Friday: the weekend of a new usual week is free.
insert into app.usual_presence (household_id, profile_id, week, weekday, position, state, label)
select p.household_id, p.id, 0, d, 1, p.default_presence_state, p.default_presence_label
  from app.profile p cross join generate_series(1, 5) d
 where p.default_presence_state is not null;

-- ------------------------------------------------------------------ api: the view

-- One row per profile the caller may see: the anchor and the slots, ordered. Security
-- invoker, so the RLS of app.profile and app.usual_presence decides what a caller sees.
create view api.usual_weeks with (security_invoker = true) as
  select p.id as profile_id,
         p.usual_week_anchor as anchor,
         coalesce((select jsonb_agg(jsonb_build_object(
                            'week', u.week, 'weekday', u.weekday, 'position', u.position,
                            'state', u.state, 'label', u.label,
                            'starts', to_char(u.starts, 'HH24:MI'),
                            'ends', to_char(u.ends, 'HH24:MI'))
                          order by u.week, u.weekday, u.position)
                     from app.usual_presence u where u.profile_id = p.id), '[]'::jsonb) as slots
    from app.profile p;

grant select on api.usual_weeks to authenticated;
revoke all on api.usual_weeks from anon;

-- ------------------------------------------------------------------ internal: the summary

-- profile.default_presence_* for the previous app release: the week's most common place
-- (week A, any slot), ties going to the earliest weekday. Null when the week is empty.
create function app.usual_week_summarise(p_profile uuid) returns void
language sql security definer set search_path = '' as $$
  update app.profile p
     set (default_presence_state, default_presence_label) =
         (select u.state, u.label
            from app.usual_presence u
           where u.profile_id = p_profile and u.week = 0
           group by u.state, u.label
           order by count(*) desc, min(u.weekday * 10 + u.position)
           limit 1)
   where p.id = p_profile;
$$;

-- p_slots as rows, once api.member_usual_week_set has checked every element.
create function app.usual_week_rows(p_slots jsonb)
returns table (ord bigint, week int, weekday int, state text, label text, starts time, ends time)
language sql immutable set search_path = '' as $$
  select t.ord, coalesce((t.s ->> 'week')::int, 0), (t.s ->> 'weekday')::int, t.s ->> 'state',
         nullif(btrim(coalesce(t.s ->> 'label', '')), ''), (t.s ->> 'starts')::time,
         (t.s ->> 'ends')::time
    from jsonb_array_elements(p_slots) with ordinality as t(s, ord);
$$;

revoke all on function app.usual_week_summarise(uuid), app.usual_week_rows(jsonb)
  from public, anon, authenticated;

-- ------------------------------------------------------------------ api: writing a week

-- Replaces a member's whole usual week. p_slots is a JSON array of
--   {"week": 0|1, "weekday": 1–7, "state": "...", "label": "..."|null,
--    "starts": "HH:MM"|null, "ends": "HH:MM"|null}
-- in any order; an empty array clears the week. p_anchor is null (the same every week) or
-- the Monday of a week A, and week 1 rows need it. A guardian may set anyone's, a member
-- only their own; never from a kiosk.
create function api.member_usual_week_set(p_actor uuid, p_profile_id uuid, p_anchor date, p_slots jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  v_slot  jsonb;
  v_week  int;
  v_day   int;
  v_state text;
  v_label text;
  v_from  time;
  v_to    time;
  v_rows  int;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if not (app.calendar_is_guardian(a) or a.profile_id = p_profile_id) then
    raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
  end if;
  if not exists (select 1 from app.profile p where p.id = p_profile_id and p.household_id = a.household_id) then
    raise exception 'profile not found' using errcode = 'P0002', hint = 'profile_not_found';
  end if;
  if (p_anchor is not null and extract(isodow from p_anchor) <> 1)
     or p_slots is null or jsonb_typeof(p_slots) <> 'array' or jsonb_array_length(p_slots) > 42 then
    raise exception 'WW-CAL-008 usual week invalid' using errcode = '22023', hint = 'usual_week_invalid';
  end if;

  for v_slot in select * from jsonb_array_elements(p_slots) loop
    begin
      if jsonb_typeof(v_slot) <> 'object' then
        raise exception 'shape';
      end if;
      v_week := coalesce((v_slot ->> 'week')::int, 0);
      v_day := (v_slot ->> 'weekday')::int;
      v_state := v_slot ->> 'state';
      v_label := nullif(btrim(coalesce(v_slot ->> 'label', '')), '');
      v_from := (v_slot ->> 'starts')::time;
      v_to := (v_slot ->> 'ends')::time;
    exception when others then
      raise exception 'WW-CAL-008 usual week invalid' using errcode = '22023', hint = 'usual_week_invalid';
    end;
    if v_week not in (0, 1) or (v_week = 1 and p_anchor is null)
       or v_day is null or v_day not between 1 and 7
       or v_state is null
       or v_state not in ('working', 'home_office', 'travel', 'away', 'off', 'childcare')
       or length(coalesce(v_label, '')) > 40
       or (v_from is null) <> (v_to is null) or v_from >= v_to then
      raise exception 'WW-CAL-008 usual week invalid' using errcode = '22023', hint = 'usual_week_invalid';
    end if;
  end loop;

  -- Every slot is well-formed now. A day holds one whole-day place or up to three timed
  -- slots that do not overlap.
  if exists (select 1 from app.usual_week_rows(p_slots) n
              group by n.week, n.weekday
             having count(*) > 3 or (count(*) > 1 and bool_or(n.starts is null)))
     or exists (select 1 from app.usual_week_rows(p_slots) x
                  join app.usual_week_rows(p_slots) y
                    on x.week = y.week and x.weekday = y.weekday and x.ord < y.ord
                 where x.starts < y.ends and y.starts < x.ends) then
    raise exception 'WW-CAL-008 usual week invalid' using errcode = '22023', hint = 'usual_week_invalid';
  end if;

  delete from app.usual_presence where profile_id = p_profile_id;
  insert into app.usual_presence (household_id, profile_id, week, weekday, position, state, label, starts, ends)
  select a.household_id, p_profile_id, n.week, n.weekday,
         row_number() over (partition by n.week, n.weekday order by n.starts nulls first),
         n.state, n.label, n.starts, n.ends
    from app.usual_week_rows(p_slots) n;
  get diagnostics v_rows = row_count;

  update app.profile set usual_week_anchor = p_anchor where id = p_profile_id;
  perform app.usual_week_summarise(p_profile_id);

  perform app.audit(a, 'profile', p_profile_id, 'usual_week_set',
                    jsonb_build_object('anchor', p_anchor, 'slots', v_rows));
  perform app.broadcast(a.household_id, 'calendar');
end $$;

-- ------------------------------------------------------------------ api: the single baseline

-- The previous app release's write: one place for every day. It now replaces the usual
-- week with that place on Monday to Friday (the migration's rule), or clears it. Same
-- signature, grants and errors as in 20261013140000_calendar.sql.
create or replace function api.member_baseline_set(p_actor uuid, p_profile_id uuid, p_state text, p_label text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  v_label text := case when p_state is null then null else nullif(btrim(coalesce(p_label, '')), '') end;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if not (app.calendar_is_guardian(a) or a.profile_id = p_profile_id) then
    raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
  end if;
  if p_state is not null and p_state not in ('working', 'home_office', 'travel', 'away', 'off', 'childcare') then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;
  if length(coalesce(v_label, '')) > 40 then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;

  update app.profile
     set default_presence_state = p_state, default_presence_label = v_label, usual_week_anchor = null
   where id = p_profile_id and household_id = a.household_id;
  if not found then
    raise exception 'profile not found' using errcode = 'P0002', hint = 'profile_not_found';
  end if;
  delete from app.usual_presence where profile_id = p_profile_id;
  if p_state is not null then
    insert into app.usual_presence (household_id, profile_id, week, weekday, position, state, label)
    select a.household_id, p_profile_id, 0, d, 1, p_state, v_label from generate_series(1, 5) d;
  end if;
  perform app.audit(a, 'profile', p_profile_id, 'baseline_set',
                    jsonb_build_object('state', p_state, 'label', v_label));
  perform app.broadcast(a.household_id, 'calendar');
end $$;

revoke all on function api.member_usual_week_set(uuid, uuid, date, jsonb) from public, anon;
grant execute on function api.member_usual_week_set(uuid, uuid, date, jsonb) to authenticated;

-- ------------------------------------------------------------------ api: the assistant

-- api.mcp_context gains the part 'usual': the active members' usual weeks, for "who is
-- where" (get_presence). Otherwise as in 20261016120000_assistant_keys.sql; its grants stay.
create or replace function api.mcp_context(p_token text, p_parts text[], p_from date default null, p_days int default 1)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.key_actor(p_token, 'assistant', false);
begin
  if 'usual' = any(p_parts) then
    return app.key_context(a, p_parts, p_from, p_days) || jsonb_build_object(
      'usual_weeks', (select coalesce(jsonb_agg(to_jsonb(v) order by v.profile_id), '[]'::jsonb)
                        from api.usual_weeks v
                       where v.profile_id in (select p.id from app.profile p
                                               where p.household_id = a.household_id and p.active)));
  end if;
  return app.key_context(a, p_parts, p_from, p_days);
end $$;

-- ------------------------------------------------------------------ the export

-- The export carries the usual week (FR-5.16). Replaces api.household_export of
-- 20261016110000_shortcuts.sql verbatim except for the 'usual_presence' key; its grants stay.
create or replace function api.household_export(p_actor uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  -- Columns that never leave the database, whichever table they sit in.
  v_secret constant text[] := array['pin_hash', 'pin_failures', 'pin_locked_until', 'auth_user_id',
                                    'auth_session_id', 'token_hash', 'code_hash'];
  v_household jsonb;
  v_tables    jsonb;
begin
  perform app.require_guardian(a);
  if a.device_class <> 'personal' then
    raise exception 'personal device required' using errcode = '42501', hint = 'personal_device_required';
  end if;

  select to_jsonb(h) into v_household from app.household h where h.id = a.household_id;

  v_tables := jsonb_build_object(
    'profile', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                  from app.profile r where r.household_id = a.household_id),
    -- Devices: label, class and dates only; the Auth user and guardian-verification state stay out.
    'device', (select coalesce(jsonb_agg(jsonb_build_object(
                  'id', r.id, 'label', r.label, 'class', r.class, 'register', r.register,
                  'profile_id', r.profile_id, 'created_at', r.created_at,
                  'last_seen_at', r.last_seen_at, 'revoked_at', r.revoked_at)
                  order by r.created_at, r.id), '[]')
                 from app.device r where r.household_id = a.household_id),
    'household_setting', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.key, r.id), '[]')
                            from app.household_setting r where r.household_id = a.household_id),
    'audit_log', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                    from app.audit_log r where r.household_id = a.household_id),
    'calendar', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                   from app.calendar r where r.household_id = a.household_id),
    'event', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                from app.event r where r.household_id = a.household_id),
    'event_attendee', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret), '[]')
                         from app.event_attendee r where r.household_id = a.household_id),
    'event_override', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                         from app.event_override r where r.household_id = a.household_id),
    'usual_presence', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret
                                                 order by r.profile_id, r.week, r.weekday, r.position), '[]')
                         from app.usual_presence r where r.household_id = a.household_id),
    'calendar_feed_token', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                              from app.calendar_feed_token r where r.household_id = a.household_id),
    'school', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                 from app.school r where r.household_id = a.household_id),
    'school_period', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                        from app.school_period r where r.household_id = a.household_id),
    'school_term', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                      from app.school_term r where r.household_id = a.household_id),
    'school_holiday', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                         from app.school_holiday r where r.household_id = a.household_id),
    -- Subscribed calendars, without the fetch bookkeeping; their occurrences are a cache of the URL.
    'external_calendar', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret - 'etag' order by r.id), '[]')
                            from app.external_calendar r where r.household_id = a.household_id),
    'subject', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                  from app.subject r where r.household_id = a.household_id),
    'timetable', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                    from app.timetable r where r.household_id = a.household_id),
    'timetable_lesson', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                           from app.timetable_lesson r where r.household_id = a.household_id),
    'timetable_exception', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                              from app.timetable_exception r where r.household_id = a.household_id),
    'shopping_list', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                        from app.shopping_list r where r.household_id = a.household_id),
    'shopping_item', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                        from app.shopping_item r where r.household_id = a.household_id),
    'shopping_trip', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.finished_at, r.id), '[]')
                        from app.shopping_trip r where r.household_id = a.household_id),
    'shopping_category', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.sort_order, r.id), '[]')
                            from app.shopping_category r where r.household_id = a.household_id),
    'catalog_item', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                       from app.catalog_item r where r.household_id = a.household_id),
    'recipe', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                 from app.recipe r where r.household_id = a.household_id),
    'recipe_ingredient', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.recipe_id, r.position), '[]')
                            from app.recipe_ingredient r where r.household_id = a.household_id),
    'meal_plan_entry', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.on_date, r.slot), '[]')
                          from app.meal_plan_entry r where r.household_id = a.household_id),
    'task_definition', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                          from app.task_definition r where r.household_id = a.household_id),
    'task_instance', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.due_on, r.id), '[]')
                        from app.task_instance r where r.household_id = a.household_id),
    'point_transaction', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.occurred_at, r.id), '[]')
                            from app.point_transaction r where r.household_id = a.household_id),
    'reward', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.created_at, r.id), '[]')
                 from app.reward r where r.household_id = a.household_id),
    'reward_redemption', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.requested_at, r.id), '[]')
                            from app.reward_redemption r where r.household_id = a.household_id),
    'streak', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.id), '[]')
                 from app.streak r where r.household_id = a.household_id),
    'badge_definition', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.key, r.id), '[]')
                           from app.badge_definition r where r.household_id = a.household_id),
    'badge_award', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.awarded_at, r.id), '[]')
                      from app.badge_award r where r.household_id = a.household_id),
    'tasks_day_closed', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret order by r.day), '[]')
                           from app.tasks_day_closed r where r.household_id = a.household_id),
    -- Invitations: token and code hashes are secrets (v_secret); the accepting Auth user is one too.
    'invitation', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret - 'accepted_by_user'
                                             order by r.created_at, r.id), '[]')
                     from app.invitation r where r.household_id = a.household_id),
    -- Shortcut tokens: label, holder and dates; the hash is a secret (v_secret), and the daily
    -- write counter is bookkeeping.
    'shortcut_token', (select coalesce(jsonb_agg(to_jsonb(r) - v_secret - 'writes_on' - 'writes_count'
                                                 order by r.created_at, r.id), '[]')
                         from app.shortcut_token r where r.household_id = a.household_id)
  );

  perform app.audit(a, 'household', a.household_id, 'export');

  return jsonb_build_object(
    'format', 'wuselwall-export',
    'version', 1,
    'exported_at', now(),
    'household', coalesce(v_household, '{}'::jsonb),
    'tables', v_tables);
end $$;
