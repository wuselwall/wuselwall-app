-- M1.3b ICS school days (specs/05 "The ICS feed", specs/15 "What goes into the ICS feed").
--
-- api.ics_feed gains a "school" key for tokens whose filter asks for school days ('day' or
-- 'lessons'): the eight row sets that the Edge Function's projection (school.ts) needs, in the
-- columns the api views expose. The key is absent when the filter is 'off', so an existing
-- subscriber's feed is unchanged. Everything else is the function of 20261013150000 verbatim.
--
-- The rows are limited to the token's household, to the timetables of its children (or of the
-- profiles the filter names, when it names some), and to the terms that overlap the projection
-- window [today - 30, today + 120]. Holidays, exceptions and lessons follow those timetables.

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

  return jsonb_build_object(
    'household', jsonb_build_object('name', h.name, 'timezone', h.timezone, 'locale', h.locale),
    'filter', t.filter,
    'revision', v_revision,
    'events', v_events,
    'overrides', v_overrides,
    'attendees', v_attendees)
    || case when v_school is null then '{}'::jsonb
            else jsonb_build_object('school', v_school, 'members', v_members) end;
end $$;

-- Same grants as 20261013150000: the service role only.
revoke all on function api.ics_feed(text) from public, anon, authenticated;
grant usage on schema api to service_role;
grant execute on function api.ics_feed(text) to service_role;
