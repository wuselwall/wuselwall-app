-- M2 MCP, family:read (specs/12 "Part 2", FR-6.1, FR-6.4): read-only keys for an assistant that
-- speaks MCP (Claude, or any other client), on the shortcut keys' table.
--
-- Authorisation is the interim Q15 allows: a per-person bearer key ("wwa_…") instead of OAuth 2.1.
-- Supabase Auth's OAuth server works self-hosted, but needs a login and consent screen on every
-- family's server and a hook change for OAuth sessions; that belongs with the write scopes and
-- grant management (specs/12, phase 3). An assistant key is family:read and nothing more: its
-- actor (device class 'assistant', origin 'mcp') is refused by every write, by
-- app.require_guardian, and by the shortcut functions; only api.mcp_context accepts it.
--
-- Only adults hold assistant keys: family:read is the whole household's week, children's
-- timetables and who is away included. The shortcut functions are unchanged in behaviour;
-- api.shortcut_context's body moves into app.key_context, which the MCP read shares, and
-- api.shortcut_token_create's into app.key_issue. Additive for api_version: a column, a view
-- column at the end, new functions.

-- ------------------------------------------------------------------ the kind of a key

alter table app.shortcut_token add column kind text not null default 'shortcut'
  check (kind in ('shortcut', 'assistant'));
grant select (kind) on app.shortcut_token to authenticated;

-- kind is appended; every other column and the grants stay.
create or replace view api.shortcut_tokens with (security_invoker = true) as
  select id, profile_id, label, created_by_profile_id, created_at, last_used_at, use_count, revoked_at,
         kind
    from app.shortcut_token;

-- ------------------------------------------------------------------ internals

-- The actor a key of [p_kind] acts as, or the one error for every key that does not work:
-- unknown, revoked, of another kind, of a deleted household or of a profile no longer active.
-- Counts the use, and for a write the day's writes. An assistant key never writes.
create function app.key_actor(p_token text, p_kind text, p_write boolean) returns app.actor_t
language plpgsql security definer set search_path = '' as $$
declare
  t       app.shortcut_token;
  p       app.profile;
  v_today date;
begin
  select k.* into t from app.shortcut_token k
    join app.household h on h.id = k.household_id and h.deleted_at is null
   where k.token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex')
     and k.revoked_at is null and k.kind = p_kind
   for update of k;
  if found then
    select * into p from app.profile where id = t.profile_id and household_id = t.household_id and active;
  end if;
  if t.id is null or p.id is null then
    raise exception 'WW-SHC-001 shortcut token invalid' using errcode = '42501', hint = 'shortcut_token_invalid';
  end if;

  if p_write then
    if t.kind <> 'shortcut' then
      raise exception 'read only' using errcode = '42501', hint = 'key_read_only';
    end if;
    v_today := app.tasks_today(t.household_id);
    if t.writes_on = v_today and t.writes_count >= app.shortcut_daily_writes() then
      raise exception 'WW-SHC-002 daily limit reached' using errcode = '54000', hint = 'shortcut_rate_limited';
    end if;
    update app.shortcut_token
       set writes_count = case when writes_on = v_today then writes_count + 1 else 1 end,
           writes_on = v_today
     where id = t.id;
  end if;
  update app.shortcut_token set last_used_at = now(), use_count = use_count + 1 where id = t.id;

  return case t.kind
    when 'assistant' then row(t.household_id, p.id, p.role, null::uuid, 'assistant', 'mcp',
                              null::timestamptz, null::uuid)::app.actor_t
    else row(t.household_id, p.id, p.role, null::uuid, 'shortcut', 'shortcut',
             null::timestamptz, null::uuid)::app.actor_t
  end;
end $$;

-- Same signature and behaviour as before: shortcut keys only.
create or replace function app.shortcut_actor(p_token text, p_write boolean default false) returns app.actor_t
language sql security definer set search_path = '' as $$
  select app.key_actor(p_token, 'shortcut', p_write)
$$;

-- Issues a key of [p_kind] for [p_profile] (the actor's own profile when null) and returns it once.
-- A guardian issues one for any active member; anyone issues their own on a personal device.
-- Never on a kiosk. An assistant key is for an adult only.
create function app.key_issue(a app.actor_t, p_profile uuid, p_label text, p_kind text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_profile uuid := coalesce(p_profile, a.profile_id);
  v_label   text := btrim(coalesce(p_label, ''));
  v_id      uuid := gen_random_uuid();
  v_kind    app.profile;
  v_token   text;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if v_profile <> a.profile_id or a.device_class <> 'personal' then
    perform app.require_guardian(a);
  end if;

  select * into v_kind from app.profile p
   where p.id = v_profile and p.household_id = a.household_id and p.active;
  if not found then
    raise exception 'unknown profile' using errcode = 'P0002', hint = 'profile_not_found';
  end if;
  if p_kind = 'assistant' and v_kind.kind <> 'adult' then
    raise exception 'WW-SHC-005 assistant keys are for adults' using errcode = '22023', hint = 'assistant_adult_only';
  end if;
  if length(v_label) not between 1 and 60 then
    raise exception 'WW-SHC-003 shortcut label invalid' using errcode = '22023', hint = 'shortcut_label_invalid';
  end if;
  if (select count(*) from app.shortcut_token k
       where k.profile_id = v_profile and k.kind = p_kind and k.revoked_at is null) >= 10 then
    raise exception 'WW-SHC-004 too many shortcut tokens' using errcode = '22023', hint = 'shortcut_token_limit';
  end if;

  -- "wws_" (shortcut) or "wwa_" (assistant) and 32 random bytes, base64url without padding.
  v_token := case p_kind when 'assistant' then 'wwa_' else 'wws_' end
             || replace(replace(translate(encode(extensions.gen_random_bytes(32), 'base64'), '+/', '-_'),
                                '=', ''), E'\n', '');

  insert into app.shortcut_token (id, household_id, profile_id, label, token_hash, created_by_profile_id, kind)
  values (v_id, a.household_id, v_profile, v_label, encode(extensions.digest(v_token, 'sha256'), 'hex'),
          a.profile_id, p_kind);
  perform app.audit(a, 'shortcut_token', v_id, 'create',
                    jsonb_build_object('label', v_label, 'profile_id', v_profile, 'kind', p_kind));
  return jsonb_build_object('id', v_id, 'token', v_token);
end $$;

-- What a key's answers are computed from: the body of api.shortcut_context (20261016110000), plus
-- the parts only an assistant asks for. 'tasks_all': every task instance of the window, anyone's;
-- 'shopping': the open items and the categories; 'points': every active member's balance, the last
-- 30 days of the ledger and the streaks; 'recipes': the recipes and their ingredients. Rows have
-- the api views' shape and are narrowed to the actor's household by joining their tables.
create function app.key_context(a app.actor_t, p_parts text[], p_from date, p_days int)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  h         app.household;
  v_today   date;
  v_from    date;
  v_to      date;
  v_region  text;
  v_out     jsonb;
  v_terms   uuid[];
  v_tts     uuid[];
  v_events  uuid[];
  v_members uuid[];
  v_instants_from timestamptz;
  v_instants_to   timestamptz;
begin
  select * into h from app.household where id = a.household_id;
  v_today := (now() at time zone h.timezone)::date;
  v_from := coalesce(p_from, v_today);
  if p_days is null or p_days not between 1 and 62 or v_from not between v_today - 7 and v_today + 400 then
    raise exception 'window invalid' using errcode = '22023', hint = 'window_invalid';
  end if;
  v_to := v_from + p_days - 1;
  -- Instants are widened by a day on each side, as calendar_data.ts does; expansion clips.
  v_instants_from := (v_from - 1)::timestamp at time zone 'UTC';
  v_instants_to := (v_to + 2)::timestamp at time zone 'UTC';
  v_region := nullif(app.setting_value(a.household_id, 'household.region') #>> '{}', '');
  select coalesce(array_agg(p.id), '{}'::uuid[]) into v_members
    from app.profile p where p.household_id = a.household_id;

  v_out := jsonb_build_object(
    'holder', (select jsonb_build_object('profile_id', p.id, 'display_name', p.display_name,
                                         'role', p.role, 'kind', p.kind)
                 from app.profile p where p.id = a.profile_id),
    'household', jsonb_build_object('name', h.name, 'timezone', h.timezone, 'locale', h.locale,
                                    'today', v_today, 'region', v_region),
    'window', jsonb_build_object('from', v_from, 'to', v_to),
    'members', (select coalesce(jsonb_agg(jsonb_build_object(
                  'id', p.id, 'display_name', p.display_name, 'role', p.role, 'kind', p.kind,
                  'default_presence_state', p.default_presence_state,
                  'default_presence_label', p.default_presence_label)
                  order by p.sort_order, p.created_at, p.id), '[]'::jsonb)
                  from app.profile p where p.household_id = a.household_id and p.active),
    'points', app.tasks_balance(a.profile_id),
    'lists', (select coalesce(jsonb_agg(to_jsonb(v) order by v.sort_order, v.id), '[]'::jsonb)
                from api.shopping_lists v
               where v.id in (select l.id from app.shopping_list l where l.household_id = a.household_id)),
    'equipment_hint', coalesce((app.setting_value(a.household_id, 'school.equipment_hint') #>> '{}')::boolean, true));

  if 'calendar' = any(p_parts) then
    select coalesce(array_agg(e.id), '{}'::uuid[]) into v_events
      from app.event e
     where e.household_id = a.household_id and e.deleted_at is null
       and (e.rrule is not null or e.rdates is not null
            or (e.start_date <= v_to and e.end_date >= v_from)
            or (e.starts_at < v_instants_to and e.ends_at > v_instants_from));
    v_out := v_out || jsonb_build_object(
      'events', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                   from api.events v where v.id = any(v_events)),
      'overrides', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                      from api.event_overrides v where v.event_id = any(v_events)),
      'external', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                     from api.external_occurrences v
                    where v.id in (select o.id from app.external_occurrence o
                                    where o.household_id = a.household_id)
                      and ((v.starts_at < v_instants_to and v.ends_at > v_instants_from)
                           or (v.start_date <= v_to and v.end_date >= v_from))),
      'busy_until', (select coalesce(jsonb_agg(to_jsonb(v) order by v.profile_id, v.on_date), '[]'::jsonb)
                       from api.busy_until v
                      where v.profile_id = any(v_members) and v.on_date between v_from and v_to));
  end if;

  if 'school' = any(p_parts) then
    select coalesce(array_agg(te.id), '{}'::uuid[]) into v_terms
      from app.school_term te
     where te.household_id = a.household_id and te.starts_on <= v_to and te.ends_on >= v_from;
    select coalesce(array_agg(tt.id), '{}'::uuid[]) into v_tts
      from app.timetable tt
     where tt.household_id = a.household_id and tt.term_id = any(v_terms)
       and tt.valid_from <= v_to and (tt.valid_to is null or tt.valid_to >= v_from);
    v_out := v_out || jsonb_build_object('school', jsonb_build_object(
      'schools', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                    from api.schools v
                   where v.id in (select s.id from app.school s where s.household_id = a.household_id)),
      'periods', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                    from api.school_periods v
                   where v.id in (select s.id from app.school_period s where s.household_id = a.household_id)),
      'terms', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                  from api.school_terms v where v.id = any(v_terms)),
      'subjects', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                     from api.subjects v
                    where v.id in (select s.id from app.subject s where s.household_id = a.household_id)),
      'timetables', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                       from api.timetables v where v.id = any(v_tts)),
      'lessons', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                    from api.timetable_lessons v where v.timetable_id = any(v_tts)),
      'exceptions', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                       from api.timetable_exceptions v
                      where v.timetable_id = any(v_tts) and v.on_date between v_from and v_to),
      'holidays', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                     from api.school_holidays v
                    where v.id in (select s.id from app.school_holiday s where s.household_id = a.household_id)
                      and v.starts_on <= v_to and v.ends_on >= v_from),
      -- The public holiday cache is not household data; only the countries in use are read.
      'public_feed', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]'::jsonb)
                        from api.holiday_feed v
                       where v.kind = 'public' and v.starts_on <= v_to and v.ends_on >= v_from
                         and v.country in (
                           select split_part(r.code, '-', 1)
                             from (select s.region_code as code from app.school s
                                    where s.household_id = a.household_id
                                   union select v_region) r
                            where r.code is not null))));
  end if;

  if 'meals' = any(p_parts) then
    v_out := v_out || jsonb_build_object(
      'meals', (select coalesce(jsonb_agg(to_jsonb(v) order by v.on_date, v.slot), '[]'::jsonb)
                  from api.meal_plan_entries v
                 where v.id in (select m.id from app.meal_plan_entry m where m.household_id = a.household_id)
                   and v.on_date between v_from and v_to));
  end if;

  if 'tasks' = any(p_parts) then
    v_out := v_out || jsonb_build_object(
      'tasks', (select coalesce(jsonb_agg(to_jsonb(v) order by v.due_on, v.title, v.id), '[]'::jsonb)
                  from api.task_instances v
                 where v.id in (select i.id from app.task_instance i where i.household_id = a.household_id)
                   and v.status = 'open' and v.opens_on <= v_to and v.closes_on >= v_from
                   and (v.assigned_profile_id = a.profile_id or v.assigned_profile_id is null)));
  end if;

  if 'tasks_all' = any(p_parts) then
    v_out := v_out || jsonb_build_object(
      'tasks_all', (select coalesce(jsonb_agg(to_jsonb(v) order by v.due_on, v.title, v.id), '[]'::jsonb)
                      from api.task_instances v
                     where v.id in (select i.id from app.task_instance i where i.household_id = a.household_id)
                       and v.opens_on <= v_to and v.closes_on >= v_from));
  end if;

  if 'shopping' = any(p_parts) then
    v_out := v_out || jsonb_build_object(
      'shopping_items', (select coalesce(jsonb_agg(to_jsonb(v) order by v.list_id, v.created_at, v.id), '[]'::jsonb)
                           from api.shopping_items v
                          where v.id in (select i.id from app.shopping_item i where i.household_id = a.household_id)
                            and not v.checked),
      'shopping_categories', (select coalesce(jsonb_agg(to_jsonb(v) order by v.list_id, v.sort_order, v.id), '[]'::jsonb)
                                from api.shopping_categories v
                               where v.id in (select c.id from app.shopping_category c
                                               where c.household_id = a.household_id)));
  end if;

  if 'points' = any(p_parts) then
    v_out := v_out || jsonb_build_object(
      'balances', (select coalesce(jsonb_agg(to_jsonb(v) order by v.profile_id), '[]'::jsonb)
                     from api.point_balances v where v.profile_id = any(v_members)),
      'ledger', (select coalesce(jsonb_agg(to_jsonb(v) order by v.occurred_at desc, v.id), '[]'::jsonb)
                   from api.point_transactions v
                  where v.profile_id = any(v_members) and v.occurred_at >= now() - interval '30 days'),
      'streaks', (select coalesce(jsonb_agg(to_jsonb(v) || jsonb_build_object('title', d.title)
                                            order by v.profile_id, v.id), '[]'::jsonb)
                    from api.streaks v
                    left join app.task_definition d on d.id = v.definition_id
                   where v.profile_id = any(v_members)));
  end if;

  if 'recipes' = any(p_parts) then
    v_out := v_out || jsonb_build_object(
      'recipes', (select coalesce(jsonb_agg(to_jsonb(v) order by v.title, v.id), '[]'::jsonb)
                    from api.recipes v
                   where v.id in (select r.id from app.recipe r where r.household_id = a.household_id)),
      'ingredients', (select coalesce(jsonb_agg(to_jsonb(v) order by v.recipe_id, v.position), '[]'::jsonb)
                        from api.recipe_ingredients v
                       where v.recipe_id in (select r.id from app.recipe r where r.household_id = a.household_id)));
  end if;

  return v_out;
end $$;

revoke all on function app.key_actor(text, text, boolean), app.key_issue(app.actor_t, uuid, text, text),
  app.key_context(app.actor_t, text[], date, int) from public, anon, authenticated;

-- ------------------------------------------------------------------ api: the shortcut functions, unchanged

create or replace function api.shortcut_token_create(p_actor uuid, p_profile uuid, p_label text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  return app.key_issue(a, p_profile, p_label, 'shortcut');
end $$;

create or replace function api.shortcut_context(p_token text, p_parts text[], p_from date default null,
                                                p_days int default 1)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.shortcut_actor(p_token);
begin
  -- A shortcut reads what its answers need; the assistant's wider parts are not for it.
  return app.key_context(a, array(select x from unnest(p_parts) x
                                   where x in ('calendar', 'school', 'meals', 'tasks')),
                         p_from, p_days);
end $$;

-- ------------------------------------------------------------------ api: assistant keys and MCP

-- Issues an assistant key (family:read) for an adult. The same rules as a shortcut key otherwise.
create function api.assistant_key_create(p_actor uuid, p_profile uuid, p_label text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  return app.key_issue(a, p_profile, p_label, 'assistant');
end $$;

-- What the `mcp` Edge Function reads for an assistant key: app.key_context with any of its parts.
create function api.mcp_context(p_token text, p_parts text[], p_from date default null, p_days int default 1)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.key_actor(p_token, 'assistant', false);
begin
  return app.key_context(a, p_parts, p_from, p_days);
end $$;

-- api.shortcut_token_revoke revokes a key of either kind (it looks a key up by id).

revoke all on function api.assistant_key_create(uuid, uuid, text), api.mcp_context(text, text[], date, int)
  from public, anon;
grant execute on function api.assistant_key_create(uuid, uuid, text) to authenticated;
revoke all on function api.mcp_context(text, text[], date, int) from authenticated;
grant execute on function api.mcp_context(text, text[], date, int) to service_role;
