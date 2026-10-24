-- A lighter day, the dates: fixes after the review of birthdays, Vorfreude and traditions
-- (specs/27, ADR-020).
--
--   * api.member_update refuses a kiosk, as app.event_save_core does. The wall could otherwise
--     name any active profile as its actor and set that profile's birthday (or name, colour,
--     picture). The body is the one of 20261024110000 with the guard added; the signature,
--     defaults and grants are unchanged, so the call without p_birthday works as before.
--   * api.event_save refuses a presence entry that carries a countdown, a tradition, an icon or a
--     tradition meal (event_invalid). Vorfreude counts down to the way home by itself, and a
--     presence entry is not a ritual. An older app that turns an appointment into a presence entry
--     (it sends none of the keys) leaves no flag behind: they are cleared.
--   * api.member_deactivate clears the birthday. "Nicht mehr dabei" keeps the person's name in the
--     family's history, not their birth date; a reactivated member's birthday is entered again.
--   * api.ics_feed gains "birthdays": the active members' birthdays, which the ics function
--     renders as one yearly all-day VEVENT each (specs/27 "Birthdays", specs/16 step 11). The
--     renderer applies the token's member filter (ics.ts, tested there).
--
-- Additive for api_version: no signature changes, the feed gains a key, an older ics function
-- ignores it. The previous app release works unchanged: it never sends flags for presence
-- entries (EventDraft.toEvent clears them) and its member page is not on the wall.

-- ================================================================== member_update: no kiosk

create or replace function api.member_update(
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
  -- The wall names no one: it may not edit a member, its own "actor" included.
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
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

-- ================================================================== event_save: no flags on presence

-- api.event_save with the flags of specs/27: 'icon_key' (a content icon, '' to clear),
-- 'countdown' and 'tradition' (booleans), and 'tradition_meal' ({slot, recipe_id | free_text},
-- or null to clear). A key an older app does not send keeps its stored value. A tradition is
-- always a key appointment, so it always reaches the board. A presence entry carries none of
-- them: set ones are refused, stored ones are cleared.
create or replace function api.event_save(p_actor uuid, p_event jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a           app.actor_t;
  v_event     jsonb := p_event;
  v_result    jsonb;
  v_id        uuid;
  v_icon      text;
  v_tradition boolean;
  v_presence  boolean;
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
  -- A presence entry (away, travelling, …) is no ritual: no countdown, tradition, icon or meal.
  -- The app sends the keys with their empty values ('', false), which are fine.
  v_presence := p_event ->> 'kind' = 'presence';
  if v_presence and (
       coalesce((p_event ->> 'countdown')::boolean, false)
       or coalesce((p_event ->> 'tradition')::boolean, false)
       or v_icon is not null
       or (p_event ? 'tradition_meal' and jsonb_typeof(p_event -> 'tradition_meal') <> 'null')) then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;
  v_tradition := case when v_presence then false else (p_event ->> 'tradition')::boolean end;
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
    icon_key  = case when v_presence then null
                     when p_event ? 'icon_key' then v_icon else icon_key end,
    countdown = case when v_presence then false
                     when p_event ? 'countdown' then (p_event ->> 'countdown')::boolean else countdown end,
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

-- ================================================================== member_deactivate: the birthday goes

-- The body of 20261023100000 with the birthday cleared. The audit row says that it was cleared,
-- never the date.
create or replace function api.member_deactivate(p_actor uuid, p_profile uuid) returns void
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
  update app.profile set active = false, birthday = null where id = p_profile;
  update app.invitation set revoked_at = now()
   where profile_id = p_profile and accepted_at is null and revoked_at is null;
  update app.device set guardian_verified_until = null, guardian_verified_profile = null
   where household_id = a.household_id and guardian_verified_profile = p_profile;
  perform app.audit(a, 'profile', p_profile, 'deactivate',
    case when v.birthday is not null then jsonb_build_object('birthday', 'cleared') end);
end $$;

-- ================================================================== ics_feed: birthdays

-- The body of 20261015101000 with "birthdays" added: each active member with a birthday, in
-- board order. The renderer keeps those of the token's members (all when it names none).
create or replace function api.ics_feed(p_token text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  t           app.calendar_feed_token;
  h           app.household;
  v_today     date;
  v_events    jsonb;
  v_overrides jsonb;
  v_attendees jsonb;
  v_revision  bigint;
  v_from      date;
  v_to        date;
  v_profiles  uuid[];
  v_terms     uuid[];
  v_timetables uuid[];
  v_school    jsonb := null;
  v_members   jsonb := null;
  v_external  jsonb := null;
  v_birthdays jsonb;
begin
  update app.calendar_feed_token
     set last_fetched_at = now(), fetch_count = fetch_count + 1
   where token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
     and revoked_at is null
  returning * into t;
  if not found then
    return null;
  end if;

  select * into h from app.household where id = t.household_id;
  v_today := (now() at time zone h.timezone)::date;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', e.id, 'calendar_id', e.calendar_id, 'title', e.title, 'description', e.description,
           'location', e.location, 'kind', e.kind, 'presence_state', e.presence_state, 'status', e.status,
           'importance', e.importance, 'is_all_day', e.is_all_day, 'starts_at', e.starts_at,
           'ends_at', e.ends_at, 'start_date', e.start_date, 'end_date', e.end_date, 'timezone', e.timezone,
           'rrule', e.rrule, 'rdates', e.rdates, 'exdates', e.exdates, 'uid', e.uid, 'sequence', e.sequence,
           'created_by_profile_id', e.created_by_profile_id, 'created_at', e.created_at,
           'updated_at', e.updated_at,
           'attendee_ids', coalesce((select jsonb_agg(a.profile_id order by p.sort_order, p.id)
                                       from app.event_attendee a
                                       join app.profile p on p.id = a.profile_id
                                      where a.event_id = e.id), '[]'::jsonb),
           'deleted', e.deleted_at is not null
         ) order by e.uid), '[]'::jsonb)
    into v_events
    from app.feed_matching_events(t, v_today) e;

  select coalesce(jsonb_agg(jsonb_build_object(
           'event_id', o.event_id, 'recurrence_id', o.recurrence_id, 'is_cancelled', o.is_cancelled,
           'title', o.title, 'starts_at', o.starts_at, 'ends_at', o.ends_at, 'start_date', o.start_date,
           'end_date', o.end_date, 'location', o.location, 'status', o.status
         ) order by o.event_id, o.recurrence_id), '[]'::jsonb)
    into v_overrides
    from app.event_override o
   where o.event_id in (select m.id from app.feed_matching_events(t, v_today) m);

  select coalesce(jsonb_object_agg(p.id::text, p.display_name), '{}'::jsonb)
    into v_attendees
    from app.profile p
   where p.id in (select a.profile_id from app.event_attendee a
                   where a.event_id in (select m.id from app.feed_matching_events(t, v_today) m));

  select extract(epoch from greatest(
           (select max(e.updated_at) from app.event e where e.household_id = t.household_id),
           t.created_at))::bigint
    into v_revision;

  -- The school days (specs/15). Only for the two modes that emit them.
  if t.filter ->> 'school' in ('day', 'lessons') then
    v_from := v_today - 30;
    v_to := v_today + 120;

    -- Empty profile list = every child of the household; otherwise the named profiles.
    select coalesce(array_agg(p.id order by p.id), '{}'::uuid[]) into v_profiles
      from app.profile p
     where p.household_id = t.household_id
       and ((jsonb_array_length(t.filter -> 'profile_ids') = 0 and p.kind = 'child' and p.active)
            or p.id in (select j.v::uuid from jsonb_array_elements_text(t.filter -> 'profile_ids') as j(v)));

    select coalesce(array_agg(te.id order by te.id), '{}'::uuid[]) into v_terms
      from app.school_term te
     where te.household_id = t.household_id
       and te.starts_on <= v_to and te.ends_on >= v_from;

    select coalesce(array_agg(tt.id order by tt.id), '{}'::uuid[]) into v_timetables
      from app.timetable tt
     where tt.household_id = t.household_id
       and tt.profile_id = any(v_profiles)
       and tt.term_id = any(v_terms)
       and tt.valid_from <= v_to
       and (tt.valid_to is null or tt.valid_to >= v_from);

    v_school := jsonb_build_object(
      'schools', (select coalesce(jsonb_agg(jsonb_build_object(
                    'id', s.id, 'name', s.name, 'state_code', s.state_code, 'timezone', s.timezone,
                    'created_at', s.created_at) order by s.id), '[]'::jsonb)
                    from app.school s where s.household_id = t.household_id),
      'periods', (select coalesce(jsonb_agg(jsonb_build_object(
                    'id', sp.id, 'school_id', sp.school_id, 'index', sp.index, 'label', sp.label,
                    'starts_at', sp.starts_at, 'ends_at', sp.ends_at, 'kind', sp.kind) order by sp.id), '[]'::jsonb)
                    from app.school_period sp where sp.household_id = t.household_id),
      'terms', (select coalesce(jsonb_agg(jsonb_build_object(
                    'id', te.id, 'school_id', te.school_id, 'name', te.name, 'starts_on', te.starts_on,
                    'ends_on', te.ends_on, 'ab_anchor_week', te.ab_anchor_week, 'is_current', te.is_current)
                    order by te.id), '[]'::jsonb)
                  from app.school_term te where te.id = any(v_terms)),
      'subjects', (select coalesce(jsonb_agg(jsonb_build_object(
                    'id', sj.id, 'name', sj.name, 'short_name', sj.short_name, 'tint', sj.tint,
                    'icon_key', sj.icon_key, 'equipment_note', sj.equipment_note,
                    'notable_default', sj.notable_default) order by sj.id), '[]'::jsonb)
                    from app.subject sj where sj.household_id = t.household_id),
      'timetables', (select coalesce(jsonb_agg(jsonb_build_object(
                    'id', tt.id, 'profile_id', tt.profile_id, 'school_id', tt.school_id, 'term_id', tt.term_id,
                    'class_label', tt.class_label, 'week_cycle', tt.week_cycle, 'valid_from', tt.valid_from,
                    'valid_to', tt.valid_to, 'source', tt.source, 'source_ref', tt.source_ref,
                    'updated_at', tt.updated_at) order by tt.id), '[]'::jsonb)
                     from app.timetable tt where tt.id = any(v_timetables)),
      'lessons', (select coalesce(jsonb_agg(jsonb_build_object(
                    'id', l.id, 'timetable_id', l.timetable_id, 'weekday', l.weekday,
                    'period_index', l.period_index, 'starts_at', l.starts_at, 'ends_at', l.ends_at,
                    'subject_id', l.subject_id, 'kind', l.kind, 'title', l.title, 'teacher', l.teacher,
                    'room', l.room, 'week_parity', l.week_parity, 'is_notable', l.is_notable,
                    'note', l.note) order by l.id), '[]'::jsonb)
                    from app.timetable_lesson l where l.timetable_id = any(v_timetables)),
      'exceptions', (select coalesce(jsonb_agg(jsonb_build_object(
                    'id', x.id, 'timetable_id', x.timetable_id, 'on_date', x.on_date,
                    'period_index', x.period_index, 'kind', x.kind, 'subject_id', x.subject_id,
                    'teacher', x.teacher, 'room', x.room, 'starts_at', x.starts_at, 'ends_at', x.ends_at,
                    'note', x.note, 'created_by_profile_id', x.created_by_profile_id) order by x.id), '[]'::jsonb)
                     from app.timetable_exception x
                    where x.timetable_id = any(v_timetables)
                      and x.on_date between v_from and v_to),
      'holidays', (select coalesce(jsonb_agg(jsonb_build_object(
                    'id', hd.id, 'school_id', hd.school_id, 'name', hd.name, 'starts_on', hd.starts_on,
                    'ends_on', hd.ends_on, 'kind', hd.kind, 'source', hd.source, 'source_url', hd.source_url)
                    order by hd.id), '[]'::jsonb)
                    from app.school_holiday hd
                   where hd.household_id = t.household_id
                     and hd.starts_on <= v_to and hd.ends_on >= v_from));

    v_members := (select coalesce(jsonb_object_agg(p.id::text, p.display_name), '{}'::jsonb)
                    from app.profile p where p.id = any(v_profiles));
  end if;

  -- The subscribed calendars (FR-1.9): the household's active imported occurrences, with the
  -- members of their calendar. The profile filter is applied by the renderer (ics.ts), where it is
  -- tested. Only the hash of each UID leaves the database: the feed names its events by it.
  if t.filter ->> 'subscribed' = 'true' then
    select coalesce(jsonb_agg(jsonb_build_object(
             'calendar_id', o.calendar_id, 'uid_hash', encode(extensions.digest(o.uid, 'sha256'), 'hex'),
             'member_ids', to_jsonb(c.member_ids),
             'starts_at', o.starts_at, 'ends_at', o.ends_at, 'all_day', o.all_day,
             'start_date', o.start_date, 'end_date', o.end_date, 'title', o.title, 'location', o.location
           ) order by o.calendar_id, o.uid, o.starts_at nulls first, o.start_date nulls first, o.id), '[]'::jsonb)
      into v_external
      from app.external_occurrence o
      join app.external_calendar c on c.id = o.calendar_id
     where o.household_id = t.household_id
       and c.active;
  end if;

  -- The birthdays (specs/27): projected like a holiday, one yearly event per member. The token's
  -- filter (members, kinds, calendars) is applied by the renderer (ics.ts), where it is tested.
  select coalesce(jsonb_agg(jsonb_build_object(
           'profile_id', p.id, 'name', p.display_name, 'birthday', p.birthday)
           order by p.sort_order, p.id), '[]'::jsonb)
    into v_birthdays
    from app.profile p
   where p.household_id = t.household_id and p.active and p.birthday is not null;

  return jsonb_build_object(
    'household', jsonb_build_object('name', h.name, 'timezone', h.timezone, 'locale', h.locale),
    'filter', t.filter,
    'revision', v_revision,
    'events', v_events,
    'overrides', v_overrides,
    'attendees', v_attendees,
    'birthdays', v_birthdays)
    || case when v_school is null then '{}'::jsonb
            else jsonb_build_object('school', v_school, 'members', v_members) end
    || case when v_external is null then '{}'::jsonb
            else jsonb_build_object('external', v_external) end;
end $$;
revoke all on function api.ics_feed(text) from public, anon, authenticated;
grant execute on function api.ics_feed(text) to service_role;
