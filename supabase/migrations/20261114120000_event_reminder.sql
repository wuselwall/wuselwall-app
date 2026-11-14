-- A reminder of its own for one event (specs/05 "A reminder for one event", FR-1.22).
--
-- Until now a phone knew one lead time for every appointment (the member setting
-- notify.event_reminder, 5 to 120 minutes). An event can now say its own: "the day before the
-- dentist". The reminder belongs to the event, so everyone the event concerns gets it, each on
-- their own phone. It stays a local notification the app plans itself (specs/14 Q47): the server
-- stores the lead time and sends nothing.
--
--   * app.event.reminder_minutes: minutes before the start, null for none. One per event.
--   * api.events shows it (at its end); the `occurrences` function passes it on.
--   * api.event_save takes 'reminder_minutes' (a whole number from 0 to 40320, four weeks, or
--     null to clear). An all-day event has no clock time to count from: its reminder is a whole
--     number of days, which the app shows at 09:00. A presence entry carries none.
--
-- api_version: unchanged. Additive: one column, one more key of api.event_save. The previous app
-- release does not send the key, and a key that is not sent keeps the stored value, so an older
-- app that edits an event does not lose its reminder. Where that edit leaves a value the event can
-- no longer carry (it became all-day, or a presence entry), the value is cleared.
-- api.server_info announces 'event-reminder'; an app on an older server hides the choice.
--
-- Errors (hint in brackets):
--   WW-CAL-001 invalid event (event_invalid)   a reminder that is no whole number, out of range,
--                                              not whole days on an all-day event, or on presence

alter table app.event
  add column reminder_minutes int
    check (reminder_minutes is null or reminder_minutes between 0 and 40320);

create or replace view api.events with (security_invoker = true) as
  select e.id, e.calendar_id, e.title, e.description, e.location, e.kind, e.presence_state,
         e.status, e.importance, e.is_all_day, e.starts_at, e.ends_at, e.start_date, e.end_date,
         e.timezone, e.rrule, e.rdates, e.exdates, e.uid, e.sequence, e.created_by_profile_id,
         e.created_at, e.updated_at,
         coalesce((select array_agg(a.profile_id order by p.sort_order, p.id)
                     from app.event_attendee a
                     join app.profile p on p.id = a.profile_id
                    where a.event_id = e.id), '{}') as attendee_ids,
         e.icon_key, e.countdown, e.tradition,
         (select jsonb_build_object('slot', m.slot, 'recipe_id', m.recipe_id, 'free_text', m.free_text,
                                    'title', coalesce(r.title, m.free_text))
            from app.tradition_meal m left join app.recipe r on r.id = m.recipe_id
           where m.event_id = e.id) as tradition_meal,
         e.reminder_minutes
    from app.event e
   where e.deleted_at is null;

-- The body of 20261025100000_lighter_day_dates_fixes.sql with 'reminder_minutes': a whole number
-- of minutes before the start, or null to clear. A key that is not sent keeps its stored value.
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
  v_minutes   numeric;
  v_reminder  int;
begin
  if jsonb_typeof(p_event) is distinct from 'object' then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;
  if (p_event ? 'countdown' and jsonb_typeof(p_event -> 'countdown') <> 'boolean')
     or (p_event ? 'tradition' and jsonb_typeof(p_event -> 'tradition') <> 'boolean')
     or (p_event ? 'icon_key' and jsonb_typeof(p_event -> 'icon_key') not in ('string', 'null'))
     or (p_event ? 'reminder_minutes'
         and jsonb_typeof(p_event -> 'reminder_minutes') not in ('number', 'null')) then
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
  -- The reminder: whole minutes, at most four weeks. An all-day event counts in whole days, and
  -- a presence entry reminds nobody.
  if jsonb_typeof(p_event -> 'reminder_minutes') = 'number' then
    v_minutes := (p_event ->> 'reminder_minutes')::numeric;
    if v_minutes <> trunc(v_minutes) or v_minutes < 0 or v_minutes > 40320
       or v_presence
       or (p_event ->> 'is_all_day' = 'true' and (v_minutes < 1440 or v_minutes % 1440 <> 0)) then
      raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
    end if;
    v_reminder := v_minutes::int;
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
    tradition = coalesce(v_tradition, tradition),
    -- is_all_day is what the core just wrote. A stored reminder an older app left on an event
    -- it turned into an all-day one is cleared unless it is whole days.
    reminder_minutes = case
      when v_presence then null
      when p_event ? 'reminder_minutes' then v_reminder
      when is_all_day and (reminder_minutes < 1440 or reminder_minutes % 1440 <> 0) then null
      else reminder_minutes end
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

  if p_event ?| array['icon_key', 'countdown', 'tradition', 'tradition_meal', 'reminder_minutes'] then
    perform app.audit(a, 'event', v_id, 'flags',
      (select jsonb_build_object('icon_key', e.icon_key, 'countdown', e.countdown,
                                 'tradition', e.tradition, 'reminder_minutes', e.reminder_minutes)
         from app.event e where e.id = v_id));
  end if;
  return v_result;
end $$;

revoke all on function api.event_save(uuid, jsonb) from public, anon;
grant execute on function api.event_save(uuid, jsonb) to authenticated;

-- As in 20261114100000_shopping_start_notice.sql, plus 'event-reminder'.
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
      'shopping-start', 'event-reminder'
    )
  );
$$;
