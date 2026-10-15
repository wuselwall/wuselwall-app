-- M1.0 Households (specs/20 J1, specs/16 step 9.2): a signed-in account without a household
-- can start its own family. Additive: setup_household and enrol_device stay for one release.

-- ------------------------------------------------------------ instance settings

-- Operator switches for the whole instance. Read only by definer functions.
create table app.instance_setting (
  key   text primary key,
  value jsonb not null
);
alter table app.instance_setting enable row level security;
alter table app.instance_setting force row level security;
create policy owner_all on app.instance_setting to postgres using (true) with check (true);
revoke all on app.instance_setting from public, anon, authenticated;

-- 'code': creating a household needs a founder code. 'open': any signed-in account may.
insert into app.instance_setting (key, value) values ('household_creation', '"code"')
  on conflict (key) do nothing;

create function app.household_creation_mode() returns text
language sql stable set search_path = '' as $$
  select coalesce((select i.value #>> '{}' from app.instance_setting i
                    where i.key = 'household_creation'), 'code')
$$;

-- ------------------------------------------------------------ columns

alter table app.household
  add column created_by_profile_id uuid references app.profile on delete set null,
  add column deleted_at            timestamptz;

-- The founder codes are the old setup tokens, now possibly many; a code records who used it.
alter table app.setup_token
  add column consumed_by uuid references app.profile on delete set null;

-- Founder-code guesses. Their own log, not app.enrol_attempt: a stranger guessing founder
-- codes must not use up the global device-enrolment budget of api.enrol_device.
create table app.founder_attempt (
  id           bigint generated always as identity primary key,
  attempted_at timestamptz not null default now(),
  client_key   text not null,
  success      boolean not null
);
create index on app.founder_attempt (client_key, attempted_at desc);
alter table app.founder_attempt enable row level security;
alter table app.founder_attempt force row level security;
create policy owner_all on app.founder_attempt to postgres using (true) with check (true);
revoke all on app.founder_attempt from public, anon, authenticated;

-- ------------------------------------------------------------ member colours

-- The member palette of app/lib/app/theme/palette.dart, in its order (upper case, as stored).
create function app.next_member_color(p_household uuid) returns text
language sql stable set search_path = '' as $$
  with palette(c, ord) as (values
    ('#7B3FE4', 1), ('#08737F', 2), ('#9A5300', 3), ('#C2255C', 4),
    ('#7A4A2A', 5), ('#1A4FA8', 6), ('#736200', 7), ('#A0309E', 8))
  select coalesce(
    (select p.c from palette p
      where not exists (select 1 from app.profile x
                         where x.household_id = p_household and x.active and upper(x.color) = p.c)
      order by p.ord limit 1),
    -- every colour is taken: wrap around
    (select p.c from palette p
      where p.ord = (select count(*) from app.profile x
                      where x.household_id = p_household and x.active) % 8 + 1))
$$;

-- ------------------------------------------------------------ seeds: one body, two callers

-- The starter content of specs/21, for an actor. api.tasks_seed_starter checks the caller;
-- household_create calls this for a household that has just been created.
create function app.tasks_seed_starter_for(a app.actor_t) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_today   date := app.tasks_today(a.household_id);
  v_kids    uuid[];
  v_approve boolean := (app.setting_value(a.household_id, 'tasks.reward_approval_default') #>> '{}') = 'required';
  v_defs    int := 0;
  v_rewards int := 0;
  v_badges  int := 0;
begin
  select coalesce(array_agg(p.id order by p.sort_order, p.id), '{}'::uuid[]) into v_kids
    from app.profile p where p.household_id = a.household_id and p.active and p.kind = 'child';

  if cardinality(v_kids) >= 1 and not exists (select 1 from app.task_definition
       where household_id = a.household_id and title = 'Tisch decken') then
    insert into app.task_definition (household_id, title, kind, points, rrule, starts_on, assignment,
                                     assignee_profile_ids)
    values (a.household_id, 'Tisch decken', 'duty', 1, 'FREQ=DAILY', v_today, 'rotating', v_kids);
    v_defs := v_defs + 1;
  end if;
  if cardinality(v_kids) >= 1 and not exists (select 1 from app.task_definition
       where household_id = a.household_id and title = 'Spülmaschine ausräumen') then
    insert into app.task_definition (household_id, title, kind, points, rrule, starts_on, assignment,
                                     assignee_profile_ids)
    values (a.household_id, 'Spülmaschine ausräumen', 'duty', 1, 'FREQ=DAILY', v_today, 'rotating', v_kids);
    v_defs := v_defs + 1;
  end if;
  if cardinality(v_kids) >= 1 and not exists (select 1 from app.task_definition
       where household_id = a.household_id and title = 'Zimmer aufräumen') then
    insert into app.task_definition (household_id, title, kind, points, rrule, starts_on, assignment,
                                     assignee_profile_ids, requires_verification)
    values (a.household_id, 'Zimmer aufräumen', 'duty', 2, 'FREQ=WEEKLY;BYDAY=SA', v_today, 'each',
            v_kids, true);
    v_defs := v_defs + 1;
  end if;
  if not exists (select 1 from app.task_definition
       where household_id = a.household_id and title = 'Müll rausbringen') then
    insert into app.task_definition (household_id, title, kind, points, rrule, starts_on, assignment,
                                     assignee_profile_ids)
    values (a.household_id, 'Müll rausbringen', 'bonus', 5, 'FREQ=WEEKLY', v_today, 'open', v_kids);
    v_defs := v_defs + 1;
  end if;
  if not exists (select 1 from app.task_definition
       where household_id = a.household_id and title = 'Beim Kochen helfen') then
    insert into app.task_definition (household_id, title, kind, points, rrule, starts_on, assignment,
                                     assignee_profile_ids)
    values (a.household_id, 'Beim Kochen helfen', 'bonus', 8, 'FREQ=WEEKLY', v_today, 'open', v_kids);
    v_defs := v_defs + 1;
  end if;

  -- Rewards at 5, 15 and 50 points: the 1 : 3 : 10 ratio of specs/06.
  if not exists (select 1 from app.reward where household_id = a.household_id and title = 'Samstagsfilm aussuchen') then
    insert into app.reward (household_id, title, cost_points, requires_approval)
    values (a.household_id, 'Samstagsfilm aussuchen', 5, v_approve);
    v_rewards := v_rewards + 1;
  end if;
  if not exists (select 1 from app.reward where household_id = a.household_id and title = '15 Minuten länger aufbleiben') then
    insert into app.reward (household_id, title, cost_points, requires_approval)
    values (a.household_id, '15 Minuten länger aufbleiben', 15, v_approve);
    v_rewards := v_rewards + 1;
  end if;
  if not exists (select 1 from app.reward where household_id = a.household_id and title = 'Ausflug nach Wahl') then
    insert into app.reward (household_id, title, cost_points, requires_approval)
    values (a.household_id, 'Ausflug nach Wahl', 50, v_approve);
    v_rewards := v_rewards + 1;
  end if;

  insert into app.badge_definition (household_id, key, title, description, rule)
  values
    (a.household_id, 'erste_aufgabe', 'Erste Aufgabe', 'Die erste Aufgabe erledigt', '{"type":"first_task"}'),
    (a.household_id, 'sieben_tage', 'Sieben Tage am Stück', 'Sieben Fälligkeiten hintereinander erledigt', '{"type":"streak_reached","length":7}'),
    (a.household_id, 'fuenfundzwanzig', 'Fünfundzwanzig Aufgaben', 'Fünfundzwanzig Aufgaben erledigt', '{"type":"total_tasks","count":25}'),
    (a.household_id, 'hundert_punkte', 'Hundert Punkte', 'Hundert Punkte verdient', '{"type":"points_earned","amount":100}')
  on conflict (household_id, key) do nothing;
  get diagnostics v_badges = row_count;

  perform app.audit(a, 'household', a.household_id, 'tasks_seed_starter',
                    jsonb_build_object('definitions', v_defs, 'rewards', v_rewards, 'badges', v_badges));
  perform app.broadcast(a.household_id, 'tasks');
  return jsonb_build_object('definitions', v_defs, 'rewards', v_rewards, 'badges', v_badges);
end $$;

-- Same behaviour as before: a guardian on a phone or a tablet's guardian window only.
create or replace function api.tasks_seed_starter(p_actor uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  return app.tasks_seed_starter_for(a);
end $$;

-- ------------------------------------------------------------ api: my_account

create function api.my_account() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'user_id',            u.id,
    'email',              u.email,
    -- A device user (a shared or kiosk tablet) has no profile but is not free to start one.
    'has_household',      p.id is not null or exists (select 1 from app.device d where d.auth_user_id = u.id),
    'household_id',       p.household_id,
    'profile_id',         p.id,
    'household_creation', app.household_creation_mode(),
    'full_name', nullif(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')), ''),
    'given_name', coalesce(
      nullif(btrim(coalesce(u.raw_user_meta_data ->> 'given_name', '')), ''),
      nullif(split_part(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')), ' ', 1), '')))
    from auth.users u
    left join lateral (
      select pr.id, pr.household_id from app.profile pr
       where pr.auth_user_id = u.id and pr.active
       order by pr.created_at limit 1) p on true
   where u.id = auth.uid()
$$;

-- ------------------------------------------------------------ api: household_create

-- Creates the household, the caller's guardian profile, the default shopping list, the
-- examples when asked, and registers this session as the caller's personal device.
-- Refusals a person can correct (no or wrong founder code, rate limit) are results, not
-- raises, so the attempt log survives.
create function api.household_create(
  p_name text, p_display_name text, p_color text, p_timezone text, p_locale text,
  p_founder_code text, p_seed_examples boolean, p_device_label text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user    uuid := auth.uid();
  v_session uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  v_headers text := current_setting('request.headers', true);
  v_key     text := coalesce(nullif(split_part(coalesce(v_headers::json ->> 'x-forwarded-for', ''), ',', 1), ''), 'unknown');
  v_mode    text := app.household_creation_mode();
  v_token   app.setup_token;
  v_hh      uuid;
  v_prof    uuid;
  v_dev     uuid;
  v_actor   app.actor_t;
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '42501', hint = 'auth_required';
  end if;
  if v_session is null or not exists (select 1 from auth.sessions where id = v_session and user_id = v_user) then
    raise exception 'no session' using errcode = '42501', hint = 'session_invalid';
  end if;
  -- Also refused for any device user (shared or kiosk tablets sign in as their own user), revoked or not.
  if exists (select 1 from app.profile where auth_user_id = v_user and active)
     or exists (select 1 from app.device where auth_user_id = v_user) then
    raise exception 'already in a household' using errcode = '42501', hint = 'already_in_household';
  end if;

  if length(btrim(coalesce(p_name, ''))) not between 1 and 60 then
    raise exception 'household name invalid' using errcode = '22023', hint = 'household_name_invalid';
  end if;
  if length(btrim(coalesce(p_display_name, ''))) not between 1 and 40 then
    raise exception 'name invalid' using errcode = '22023', hint = 'name_invalid';
  end if;
  if coalesce(p_color, '') !~ '^#[0-9A-Fa-f]{6}$' then
    raise exception 'colour invalid' using errcode = '22023', hint = 'color_invalid';
  end if;
  if not exists (select 1 from pg_timezone_names where name = p_timezone) then
    raise exception 'timezone invalid' using errcode = '22023', hint = 'timezone_invalid';
  end if;
  if coalesce(p_locale, '') !~ '^[a-z]{2}(-[A-Z]{2})?$' then
    raise exception 'locale invalid' using errcode = '22023', hint = 'locale_invalid';
  end if;
  if length(btrim(coalesce(p_device_label, ''))) not between 1 and 60 then
    raise exception 'label required' using errcode = '22023', hint = 'label_invalid';
  end if;

  -- The founder code. Only a guess counts against the client: a missing code is not one.
  if v_mode = 'code' then
    if coalesce(btrim(p_founder_code), '') = '' then
      return jsonb_build_object('ok', false, 'reason', 'founder_code_required');
    end if;
    -- 5 failures per client and 50 overall per 10 minutes. The overall limit keeps a
    -- guessing stranger from ever reaching a code: it also refuses the honest founder.
    if (select count(*) from app.founder_attempt
         where client_key = v_key and not success and attempted_at > now() - interval '10 minutes') >= 5
       or (select count(*) from app.founder_attempt
            where not success and attempted_at > now() - interval '10 minutes') >= 50 then
      return jsonb_build_object('ok', false, 'reason', 'rate_limited');
    end if;
    select * into v_token from app.setup_token
     where token_hash = encode(extensions.digest(lower(btrim(p_founder_code)), 'sha256'), 'hex')
       and consumed_at is null
     for update;
    if not found then
      insert into app.founder_attempt (client_key, success) values (v_key, false);
      return jsonb_build_object('ok', false, 'reason', 'founder_code_invalid');
    end if;
  end if;

  insert into app.household (name, timezone, locale)
  values (btrim(p_name), p_timezone, p_locale) returning id into v_hh;
  insert into app.profile (household_id, display_name, color, role, kind, auth_user_id)
  values (v_hh, btrim(p_display_name), upper(p_color), 'guardian', 'adult', v_user)
  returning id into v_prof;
  update app.household set created_by_profile_id = v_prof where id = v_hh;
  insert into app.device (household_id, auth_user_id, auth_session_id, label, class, register, profile_id)
  values (v_hh, v_user, v_session, btrim(p_device_label), 'personal', 'adult', v_prof)
  returning id into v_dev;

  if v_mode = 'code' then
    update app.setup_token set consumed_at = now(), consumed_by = v_prof where token_hash = v_token.token_hash;
    insert into app.founder_attempt (client_key, success) values (v_key, true);
  end if;

  perform app.shopping_ensure_lists(v_hh);
  v_actor := row(v_hh, v_prof, 'guardian', v_dev, 'personal', 'ui', null::timestamptz, null::uuid)::app.actor_t;
  if coalesce(p_seed_examples, false) then
    perform app.tasks_seed_starter_for(v_actor);
  end if;
  perform app.audit(v_actor, 'household', v_hh, 'create',
                    jsonb_build_object('examples', coalesce(p_seed_examples, false), 'founder_code', v_mode = 'code'));
  perform app.audit(v_actor, 'device', v_dev, 'register_personal');
  return jsonb_build_object('ok', true, 'household_id', v_hh, 'profile_id', v_prof, 'device_id', v_dev);
end $$;

-- ------------------------------------------------------------ api: household_add_members

-- The rows of H2 ("Wer gehört noch zu euch?"). Children are members; adults are guardians
-- without an account yet (invitations come later).
create function api.household_add_members(p_actor uuid, p_members jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  r      jsonb;
  v_name text;
  v_kind text;
  v_id   uuid;
  v_out  jsonb := '[]'::jsonb;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_members) <> 'array' or jsonb_array_length(p_members) not between 1 and 12 then
    raise exception 'between 1 and 12 members' using errcode = '22023', hint = 'members_invalid';
  end if;
  for r in select value from jsonb_array_elements(p_members) loop
    if length(btrim(coalesce(r ->> 'display_name', ''))) not between 1 and 40 then
      raise exception 'name invalid' using errcode = '22023', hint = 'name_invalid';
    end if;
    if coalesce(r ->> 'kind', '') not in ('child', 'adult') then
      raise exception 'kind invalid' using errcode = '22023', hint = 'kind_invalid';
    end if;
  end loop;

  for r in select value from jsonb_array_elements(p_members) loop
    v_name := btrim(r ->> 'display_name');
    v_kind := r ->> 'kind';
    insert into app.profile (household_id, display_name, color, role, kind)
    values (a.household_id, v_name, app.next_member_color(a.household_id),
            case when v_kind = 'adult' then 'guardian' else 'member' end, v_kind)
    returning id into v_id;
    perform app.audit(a, 'profile', v_id, 'create', jsonb_build_object('display_name', v_name, 'kind', v_kind));
    v_out := v_out || jsonb_build_array(jsonb_build_object('id', v_id, 'display_name', v_name, 'kind', v_kind));
  end loop;
  return v_out;
end $$;

-- ------------------------------------------------------------ grants

revoke execute on function app.household_creation_mode(), app.next_member_color(uuid),
  app.tasks_seed_starter_for(app.actor_t) from public, anon, authenticated;
revoke execute on function api.my_account(), api.household_create(text, text, text, text, text, text, boolean, text),
  api.household_add_members(uuid, jsonb) from public, anon;
grant execute on function api.my_account() to authenticated;
grant execute on function api.household_create(text, text, text, text, text, text, boolean, text) to authenticated;
grant execute on function api.household_add_members(uuid, jsonb) to authenticated;
