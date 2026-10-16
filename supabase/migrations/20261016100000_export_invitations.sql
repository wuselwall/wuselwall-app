-- The household export carries the invitations (specs/20 J6, FR-5.16), without their token and
-- code hashes and without the accepting Auth user.
--
-- The 'invitation' key was first added to 20261014160000_household_export.sql after servers had
-- applied it, so they never got it; that file is back to its applied text and the change lives
-- here. Replaces api.household_export verbatim except for the 'invitation' key; its grants stay.
-- Additive for api_version: the export gains a key.

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
                     from app.invitation r where r.household_id = a.household_id)
  );

  perform app.audit(a, 'household', a.household_id, 'export');

  return jsonb_build_object(
    'format', 'wuselwall-export',
    'version', 1,
    'exported_at', now(),
    'household', coalesce(v_household, '{}'::jsonb),
    'tables', v_tables);
end $$;
