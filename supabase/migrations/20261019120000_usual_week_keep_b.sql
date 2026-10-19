-- The usual week keeps week B when alternating weeks are switched off (issue #81, after
-- 20261019110000_usual_week.sql). Without an anchor only week 0 is ever read
-- (_shared/usual_week.ts, app.usual_week_summarise), so week 1 rows are harmless then, and
-- switching alternating on again brings them back.
--
-- Replaces api.member_usual_week_set verbatim except that week 1 rows no longer need an
-- anchor; its signature and grants stay. Additive for api_version: nothing that was
-- accepted is refused.

create or replace function api.member_usual_week_set(p_actor uuid, p_profile_id uuid, p_anchor date, p_slots jsonb)
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
    if v_week not in (0, 1)
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
