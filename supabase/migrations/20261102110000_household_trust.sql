-- Trust inside the household (security review 2026-11-01, F4, F11, F13, F16, F17, F18, F20).
--
-- Who may act as a guardian, and what a device of the family may do on its own, is
-- tightened in seven places:
--
--  F16 A personal device counts as its person only when the device's Auth user is the
--      profile's own account. A child's phone (pairing kind child_phone) is a personal device
--      with a device user, so it never passes as a guardian, whatever role the profile is
--      given later; promoting such a person to guardian revokes those phones. app.actor
--      refuses an inactive profile on a personal device, and "Nicht mehr dabei" revokes the
--      person's phones.
--  F17 Ticking or unticking someone else's task and the join notices ask app.guardian_ok,
--      the predicate behind app.require_guardian, instead of the bare role: on a shared
--      device a guardian's avatar alone no longer counts, the PIN window must be open for
--      that guardian. The Shortcuts path keeps its semantics (a key ticks only its own tasks).
--  F13 The PIN window on a shared or kiosk device is five minutes (fifteen stay for a
--      personal device, where the PIN is never asked), and api.guardian_step_down ends it
--      early: the app calls it when the acting profile changes, when the wall reverts to
--      nobody and when the person leaves the settings.
--  F4  The due days of task instances come from the server's own expander only:
--      api.tasks_materialise is the job's function (service role), the tasks-materialise
--      Edge Function reads the schedule as the caller and writes with the service role. A
--      day the nightly close has closed accepts no tick any more.
--  F11 A profile's calendar feed tokens are revoked when the profile is deactivated or its
--      account is unlinked, like its shortcut keys; api.feed_tokens shows who created a token.
--  F18 Closing, deleting and purging a family ends the sessions and the Auth users of every
--      device account, a child's phone included, not only of shared and kiosk devices.
--  F20 api.setup_household (the enrolment-era founding, still reachable in the released
--      apps and used by the integration test) counts its failures in the founder buckets
--      and refuses when they are exhausted.
--
-- Signatures: api.tasks_materialise keeps its signature but is no longer granted to
-- authenticated (no released app calls it directly; both call the Edge Function);
-- api.feed_tokens gains a column; api.guardian_step_down is new. api_version unchanged.

-- ------------------------------------------------------------ F16/F17: who is a guardian

-- Whether the actor may do a guardian action right now. On a personal device the proof is
-- the account sign-in, so the device's Auth user must be the profile's own account: a phone
-- that signed in as a device user (child_phone) is bound to a person, not signed in as one.
-- A synthetic actor without a device (the founder's first audit rows) is trusted as before.
-- On a shared or kiosk device the proof is the PIN window, and it is the acting profile's own.
create function app.guardian_ok(a app.actor_t) returns boolean
language sql stable security definer set search_path = '' as $$
  select a.profile_role = 'guardian'
     and case
           when a.device_class = 'personal' then
             a.device_id is null
             or exists (select 1 from app.device d
                          join app.profile p on p.id = a.profile_id
                         where d.id = a.device_id
                           and p.auth_user_id is not null
                           and p.auth_user_id = d.auth_user_id)
           else
             coalesce(a.guardian_verified_until, '-infinity') > now()
             and a.verified_profile = a.profile_id
         end
$$;
revoke execute on function app.guardian_ok(app.actor_t) from public, anon, authenticated;

-- Same contract as 20261011170000_security_hardening.sql; the predicate moved to guardian_ok.
create or replace function app.require_guardian(a app.actor_t) returns void
language plpgsql stable set search_path = '' as $$
begin
  if app.guardian_ok(a) then
    return;
  end if;
  raise exception 'guardian required' using errcode = '42501', hint = 'guardian_required';
end $$;

-- Whether the Auth user is one of the device accounts the server creates for a shared or
-- kiosk device or a child's phone: the address is the one app.enrol_device and
-- api.pairing_approve give them. Adult accounts never match.
create function app.is_device_account(p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from auth.users u
                  where u.id = p_user and u.email like 'device-%@devices.wuselwall.invalid')
$$;
revoke execute on function app.is_device_account(uuid) from public, anon, authenticated;

-- Same body as 20261015104000_leave.sql, with one word: a personal device acts for its
-- profile only while that profile is active (a shared device checked this already).
create or replace function app.actor(p_profile uuid default null) returns app.actor_t
language plpgsql stable security definer set search_path = '' as $$
declare
  v_dev  app.device;
  v_prof app.profile;
begin
  if exists (select 1 from app.household h
              where h.id = app.jwt_household() and h.deleted_at is not null) then
    raise exception 'household deleted' using errcode = '42501', hint = 'household_deleted';
  end if;

  select * into v_dev from app.device
   where id = app.jwt_device() and household_id = app.jwt_household();
  if not found or v_dev.revoked_at is not null then
    raise exception 'device not usable' using errcode = '42501', hint = 'device_revoked';
  end if;

  if v_dev.class = 'personal' then
    select * into v_prof from app.profile where id = v_dev.profile_id and active;
  else
    if p_profile is null then
      raise exception 'acting profile required' using errcode = '22023', hint = 'actor_required';
    end if;
    select * into v_prof from app.profile
     where id = p_profile and household_id = v_dev.household_id and active;
  end if;
  if not found then
    raise exception 'unknown acting profile' using errcode = '42501', hint = 'actor_invalid';
  end if;

  return row(v_dev.household_id, v_prof.id, v_prof.role, v_dev.id, v_dev.class,
             'ui', v_dev.guardian_verified_until, v_dev.guardian_verified_profile)::app.actor_t;
end $$;

-- Revokes the phones that act for a profile with a device user (child_phone): the person's
-- own account, if any, keeps its devices. Their sessions end with them. Returns how many.
create function app.revoke_device_user_phones(p_profile uuid) returns int
language plpgsql security definer set search_path = '' as $$
declare
  v_users uuid[];
  v_n     int;
begin
  select coalesce(array_agg(d.auth_user_id), '{}') into v_users
    from app.device d
   where d.profile_id = p_profile and d.class = 'personal' and d.revoked_at is null
     and app.is_device_account(d.auth_user_id);
  update app.device set revoked_at = now()
   where profile_id = p_profile and class = 'personal' and revoked_at is null
     and auth_user_id = any(v_users);
  get diagnostics v_n = row_count;
  delete from auth.sessions where user_id = any(v_users);
  return v_n;
end $$;
revoke execute on function app.revoke_device_user_phones(uuid) from public, anon, authenticated;

-- Same body as 20261025100000_lighter_day_dates_fixes.sql, plus: the person's phones with a
-- device user are revoked, so a retired child's phone stops with the profile.
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
  perform app.revoke_device_user_phones(p_profile);
  perform app.audit(a, 'profile', p_profile, 'deactivate',
    case when v.birthday is not null then jsonb_build_object('birthday', 'cleared') end);
end $$;

-- Same body as 20261023100000_editable_household.sql, plus: a person promoted to guardian
-- loses the phones that act for them with a device user. Such a phone could never prove a
-- guardian (guardian_ok), so it would only show guardian pages that fail; the person signs
-- in with an account instead.
create or replace function api.member_set_role(p_actor uuid, p_profile uuid, p_role text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  v app.profile := app.member_of(a, p_profile);
begin
  perform app.require_guardian(a);
  if coalesce(p_role, '') not in ('guardian', 'member') then
    raise exception 'role invalid' using errcode = '22023', hint = 'role_invalid';
  end if;
  if v.role = p_role then
    return;
  end if;
  if p_role = 'guardian' and v.kind <> 'adult' then
    raise exception 'a child cannot be a guardian' using errcode = '22023', hint = 'role_child';
  end if;
  if p_role = 'member' and v.auth_user_id is not null
     and not exists (select 1 from app.profile p
                      where p.household_id = a.household_id and p.active and p.id <> p_profile
                        and p.role = 'guardian' and p.auth_user_id is not null) then
    raise exception 'last guardian with an account' using errcode = '42501', hint = 'last_guardian';
  end if;
  update app.profile set role = p_role where id = p_profile;
  if p_role = 'member' then
    update app.device set guardian_verified_until = null, guardian_verified_profile = null
     where household_id = a.household_id and guardian_verified_profile = p_profile;
  else
    perform app.revoke_device_user_phones(p_profile);
  end if;
  perform app.audit(a, 'profile', p_profile, 'set_role', jsonb_build_object('role', p_role));
end $$;

-- ------------------------------------------------------------ F13: the PIN window

-- The profile row is read under a lock and the failure counter written from that read
-- (security review 2026-11-01, F15; the last definition of this function); the
-- window is five minutes on a shared or kiosk device, where a child may pick up the tablet
-- the moment the parent walks away. A personal device keeps fifteen (the PIN is not asked
-- there; the value only matters for the device row).
create or replace function api.guardian_verify_pin(p_profile uuid, p_pin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_dev  app.device;
  v_prof app.profile;
  v_fail int;
begin
  select * into v_dev from app.device
   where id = app.jwt_device() and household_id = app.jwt_household() and revoked_at is null;
  if not found then
    raise exception 'device not usable' using errcode = '42501', hint = 'device_revoked';
  end if;
  select * into v_prof from app.profile
   where id = p_profile and household_id = v_dev.household_id and role = 'guardian' and active
   for update;
  if not found or v_prof.pin_hash is null then
    return jsonb_build_object('ok', false, 'reason', 'pin_invalid');
  end if;
  if v_prof.pin_locked_until is not null and v_prof.pin_locked_until > now() then
    return jsonb_build_object('ok', false, 'reason',
      case when v_prof.pin_locked_until = 'infinity' then 'pin_locked' else 'pin_backoff' end,
      'retry_at', case when v_prof.pin_locked_until = 'infinity' then null else v_prof.pin_locked_until end);
  end if;

  if extensions.crypt(p_pin, v_prof.pin_hash) = v_prof.pin_hash then
    update app.profile set pin_failures = 0, pin_locked_until = null where id = v_prof.id;
    update app.device set guardian_verified_until = now() + case when v_dev.class = 'personal'
                                                                 then interval '15 minutes'
                                                                 else interval '5 minutes' end,
                          guardian_verified_profile = v_prof.id
     where id = v_dev.id returning guardian_verified_until into v_dev.guardian_verified_until;
    insert into app.audit_log (household_id, actor_profile_id, device_id, entity_type, entity_id, action)
    values (v_dev.household_id, v_prof.id, v_dev.id, 'profile', v_prof.id, 'pin_verified');
    return jsonb_build_object('ok', true, 'verified_until', v_dev.guardian_verified_until);
  end if;

  -- The counter comes from the locked read: no parallel call saw the same value.
  v_fail := v_prof.pin_failures + 1;
  update app.profile set
    pin_failures = v_fail,
    pin_locked_until = case
      when v_fail >= 10 then 'infinity'::timestamptz               -- hard lock
      when v_fail >= 3  then now() + make_interval(secs => 5 * power(2, v_fail - 3))
    end
   where id = v_prof.id;
  insert into app.audit_log (household_id, actor_profile_id, device_id, entity_type, entity_id, action, diff)
  values (v_dev.household_id, v_prof.id, v_dev.id, 'profile', v_prof.id, 'pin_failed',
          jsonb_build_object('failures', v_fail));
  return jsonb_build_object('ok', false, 'reason', 'pin_invalid', 'attempts_left', greatest(10 - v_fail, 0));
end $$;

-- Ends the PIN window of the calling device, whoever opened it. No acting profile: the wall
-- calls it when it reverts to nobody. Nothing to audit: it only shortens a window the
-- verification already recorded. A revoked device is refused like everywhere else.
create function api.guardian_step_down() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not app.device_ok() then
    raise exception 'device not usable' using errcode = '42501', hint = 'device_revoked';
  end if;
  update app.device set guardian_verified_until = null, guardian_verified_profile = null
   where id = app.jwt_device() and household_id = app.jwt_household()
     and (guardian_verified_until is not null or guardian_verified_profile is not null);
end $$;
revoke execute on function api.guardian_step_down() from public, anon;
grant execute on function api.guardian_step_down() to authenticated;

-- ------------------------------------------------------------ F4/F17: tasks

-- Same body as 20261016110000_shortcuts.sql, with two changes. Someone else's task is a
-- guardian action (guardian_ok, not the role: on a shared device the PIN window must be the
-- actor's). And a day the nightly close has closed accepts no tick: an instance that is still
-- open after its day was closed can only have been created afterwards.
create or replace function app.tasks_do_complete(a app.actor_t, p_instance_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  i        app.task_instance;
  v_tz     text;
  v_today  date;
  v_pool   uuid[];
  v_count  int;
  v_credit int := 0;
begin
  select * into i from app.task_instance
   where id = p_instance_id and household_id = a.household_id for update;
  if not found then
    raise exception 'task not found' using errcode = 'P0002', hint = 'task_not_found';
  end if;
  -- Someone else's task stays someone else's, even when it is already ticked: the
  -- idempotent answer below is for a retry by the same person, not a probe by another.
  if i.assigned_profile_id is not null and i.assigned_profile_id <> a.profile_id
     and not app.guardian_ok(a) then
    raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
  end if;
  if i.status in ('done', 'verified') then
    return jsonb_build_object('status', i.status, 'points_credited', app.tasks_credited(i.id));
  end if;

  select h.timezone into v_tz from app.household h where h.id = a.household_id;
  v_today := (now() at time zone v_tz)::date;
  if i.status <> 'open' or i.opens_on > v_today then
    raise exception 'WW-TSK-005 task not open' using errcode = '22023', hint = 'task_not_open';
  end if;
  if i.closes_on < v_today and exists (select 1 from app.tasks_day_closed c
                                        where c.household_id = a.household_id and c.day >= i.closes_on) then
    raise exception 'WW-TSK-005 task not open' using errcode = '22023', hint = 'task_window_closed';
  end if;

  -- The assignee ticks their task; a guardian may tick an assigned task for anyone. An unassigned
  -- (open) task is claimed by the member who ticks it, from its pool when the definition has one.
  if i.assigned_profile_id is not null then
    if i.assigned_profile_id <> a.profile_id and not app.guardian_ok(a) then
      raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
    end if;
  else
    if a.profile_role <> 'member' then
      raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
    end if;
    if i.definition_id is not null then
      select d.assignee_profile_ids into v_pool from app.task_definition d where d.id = i.definition_id;
      if cardinality(v_pool) > 0 and not (a.profile_id = any(v_pool)) then
        raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
      end if;
    end if;
    i.assigned_profile_id := a.profile_id;
  end if;

  v_count := i.completion_count + 1;
  -- A task that needs verification holds its points until a guardian approves it.
  if not i.requires_verification and i.points > 0 then
    insert into app.point_transaction (household_id, profile_id, amount, reason, source_type, source_id,
                                       created_by_profile_id)
    values (a.household_id, i.assigned_profile_id, i.points, 'task', 'task',
            i.id::text || ':' || v_count::text, a.profile_id);
    v_credit := i.points;
  end if;

  update app.task_instance set status = 'done', completion_count = v_count,
         completed_by_profile_id = a.profile_id, completed_at = now(),
         assigned_profile_id = i.assigned_profile_id, updated_at = now()
   where id = i.id;
  if i.definition_id is not null then
    perform app.tasks_streak_complete(a.household_id, i.assigned_profile_id, i.definition_id, i.due_on);
  end if;

  perform app.audit(a, 'task_instance', i.id, 'complete',
                    jsonb_build_object('points', v_credit, 'profile_id', i.assigned_profile_id));
  perform app.broadcast(a.household_id, 'tasks');
  return jsonb_build_object('status', 'done', 'points_credited', v_credit);
end $$;

-- Same body as 20261013170000_tasks.sql; taking back someone else's tick is a guardian action.
create or replace function api.task_undo(p_actor uuid, p_instance_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  i       app.task_instance;
  v_tz    text;
  v_today date;
begin
  select * into i from app.task_instance
   where id = p_instance_id and household_id = a.household_id for update;
  if not found then
    raise exception 'task not found' using errcode = 'P0002', hint = 'task_not_found';
  end if;
  if i.status <> 'done' then
    raise exception 'WW-TSK-005 task not open' using errcode = '22023', hint = 'task_not_open';
  end if;

  select h.timezone into v_tz from app.household h where h.id = a.household_id;
  v_today := (now() at time zone v_tz)::date;
  if (i.completed_at at time zone v_tz)::date <> v_today then
    raise exception 'WW-TSK-005 task not open' using errcode = '22023', hint = 'undo_window_closed';
  end if;
  if a.profile_id is distinct from i.completed_by_profile_id and not app.guardian_ok(a) then
    raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
  end if;

  if not i.requires_verification and i.points > 0 then
    insert into app.point_transaction (household_id, profile_id, amount, reason, source_type, source_id,
                                       created_by_profile_id)
    values (a.household_id, i.assigned_profile_id, -i.points, 'task', 'task_undo',
            i.id::text || ':' || i.completion_count::text, a.profile_id);
  end if;

  update app.task_instance set status = 'open', completed_by_profile_id = null, completed_at = null,
         updated_at = now()
   where id = i.id;
  if i.definition_id is not null then
    perform app.tasks_streak_revert(i.assigned_profile_id, i.definition_id, i.due_on, i.id);
  end if;

  perform app.audit(a, 'task_instance', i.id, 'undo');
  perform app.broadcast(a.household_id, 'tasks');
end $$;

-- Same body as 20261013170000_tasks.sql, for the job only. The due days a device may ask
-- for are not checked here against the rules: the tasks-materialise Edge Function reads the
-- schedule as the caller and expands the rules with the shared code, then writes with the
-- service role, as tasks-nightly does. A device calling this directly is refused. Defence in
-- depth: should the grant ever return, the body refuses too.
create or replace function api.tasks_materialise(p_household uuid, p_due jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_today   date;
  v_created int;
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  if p_household is null or jsonb_typeof(p_due) is distinct from 'array' then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  v_today := app.tasks_today(p_household);
  if v_today is null then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  v_created := app.tasks_materialise_rows(p_household, (
    select coalesce(jsonb_agg(x), '[]'::jsonb) from jsonb_array_elements(p_due) x
     where (x ->> 'due_on')::date <= v_today + 14));
  if v_created > 0 then
    perform app.broadcast(p_household, 'tasks');
  end if;
  return jsonb_build_object('created', v_created);
end $$;
revoke execute on function api.tasks_materialise(uuid, jsonb) from public, anon, authenticated;
grant execute on function api.tasks_materialise(uuid, jsonb) to service_role;

-- ------------------------------------------------------------ F17: the join notices

-- Same body as 20261015110000_notices.sql; the join notices (who accepted an invitation) are
-- for a guardian who can prove it: on a shared device within their own PIN window. A
-- guardian's avatar alone shows none.
create or replace function app.notices_for(a app.actor_t)
returns table (notice_key text, kind text, at timestamptz, name text, device_id uuid, profile_id uuid)
language plpgsql stable security definer set search_path = '' as $$
declare v_since timestamptz;
begin
  if a.device_class = 'kiosk' then
    return;
  end if;

  return query
  select 'join:' || l.id::text, 'join'::text, l.occurred_at, p.display_name, null::uuid, p.id
    from app.audit_log l
    join app.profile p on p.id = l.actor_profile_id and p.household_id = a.household_id
   where app.guardian_ok(a)
     and l.household_id = a.household_id
     and l.entity_type = 'invitation' and l.action = 'accept'
     and l.occurred_at > now() - interval '14 days'
     and l.actor_profile_id <> a.profile_id
     and not exists (select 1 from app.notice_dismissal d
                      where d.profile_id = a.profile_id and d.notice_key = 'join:' || l.id::text);

  if a.device_class = 'personal' then
    select created_at into v_since from app.device where id = a.device_id;
    return query
    select 'signin:' || d.id::text, 'signin'::text, d.created_at, d.label, d.id, null::uuid
      from app.device d
     where d.household_id = a.household_id
       and d.profile_id = a.profile_id
       and d.class = 'personal'
       and d.revoked_at is null
       and d.id <> a.device_id
       and d.created_at > v_since
       and d.created_at > now() - interval '14 days'
       and not exists (select 1 from app.notice_dismissal x
                        where x.profile_id = a.profile_id and x.notice_key = 'signin:' || d.id::text);
  end if;
end $$;

-- ------------------------------------------------------------ F11: feed tokens follow their maker

-- A feed token stops with the person who made it, like a shortcut key: when the profile is
-- deactivated, or the adult leaves the family or deletes the account (auth_user_id cleared).
-- The remaining guardians see the token revoked in the list, with its maker.
create function app.feed_tokens_follow_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (old.active and not new.active)
     or (old.auth_user_id is not null and new.auth_user_id is null) then
    update app.calendar_feed_token set revoked_at = now()
     where created_by_profile_id = new.id and revoked_at is null;
  end if;
  return new;
end $$;
revoke execute on function app.feed_tokens_follow_profile() from public, anon, authenticated;

create trigger feed_tokens_follow_profile after update of active, auth_user_id on app.profile
  for each row execute function app.feed_tokens_follow_profile();

-- The columns of 20261013150000_feed_tokens.sql plus the maker (additive).
create or replace view api.feed_tokens with (security_invoker = true) as
  select id, label, filter, created_at, last_fetched_at, fetch_count, revoked_at, created_by_profile_id
    from app.calendar_feed_token;
grant select on api.feed_tokens to authenticated;
revoke all on api.feed_tokens from anon;

-- ------------------------------------------------------------ F18: every device account goes

-- Same body as 20261015106000_account_admin.sql; the sessions of every device account end,
-- a child's phone included (its row is personal and has no session id).
create or replace function app.household_close(p_household uuid) returns timestamptz
language plpgsql security definer set search_path = '' as $$
declare
  v_at timestamptz;
begin
  update app.household set deleted_at = now() where id = p_household returning deleted_at into v_at;

  -- Everyone is signed out: the sessions of phones, and of every device account.
  delete from auth.sessions s
   where s.id in (select d.auth_session_id from app.device d
                   where d.household_id = p_household and d.auth_session_id is not null)
      or s.user_id in (select d.auth_user_id from app.device d
                        where d.household_id = p_household and app.is_device_account(d.auth_user_id));
  update app.device set revoked_at = coalesce(revoked_at, now()) where household_id = p_household;

  update app.enrolment_code set consumed_at = now()
   where household_id = p_household and consumed_at is null;
  update app.calendar_feed_token set revoked_at = now()
   where household_id = p_household and revoked_at is null;
  update app.pairing_request set status = 'claimed', claimed_at = coalesce(claimed_at, now())
   where household_id = p_household and status <> 'claimed';
  return v_at;
end $$;

-- Same body as 20261019140000_household_delete_now.sql; every device account is removed.
create or replace function api.household_delete(p_actor uuid, p_confirm_name text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  v_hh    app.household;
  v_users uuid[];
begin
  if a.device_class <> 'personal' then
    raise exception 'personal device required' using errcode = '42501', hint = 'personal_device_required';
  end if;
  perform app.require_guardian(a);

  select * into v_hh from app.household where id = a.household_id for update;
  if lower(btrim(coalesce(p_confirm_name, ''))) is distinct from lower(btrim(v_hh.name)) then
    raise exception 'family name does not match' using errcode = '22023', hint = 'confirm_name_mismatch';
  end if;

  select coalesce(array_agg(distinct d.auth_user_id), '{}') into v_users from app.device d
   where d.household_id = a.household_id and app.is_device_account(d.auth_user_id);

  -- Everyone is signed out: the sessions of phones, and of every device account.
  delete from auth.sessions s
   where s.id in (select d.auth_session_id from app.device d
                   where d.household_id = a.household_id and d.auth_session_id is not null)
      or s.user_id = any(v_users);

  -- Every row of the family cascades away, its audit rows too: nothing of it is kept.
  delete from app.household where id = a.household_id;

  -- Device accounts only: is_device_account has checked the address.
  delete from auth.users u where u.id = any(v_users);

  return jsonb_build_object('ok', true, 'purge_after', now());
end $$;

-- Same body as 20261015104000_leave.sql; every device account is removed.
create or replace function api.household_purge_due() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_hh       uuid[];
  v_users    uuid[];
  v_families int := 0;
  v_accounts int := 0;
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;

  select coalesce(array_agg(h.id), '{}') into v_hh from app.household h
   where h.deleted_at is not null and h.deleted_at + app.household_retention() <= now();
  if cardinality(v_hh) = 0 then
    return jsonb_build_object('households', 0, 'device_accounts', 0);
  end if;

  select coalesce(array_agg(distinct d.auth_user_id), '{}') into v_users from app.device d
   where d.household_id = any(v_hh) and app.is_device_account(d.auth_user_id);

  delete from app.household where id = any(v_hh);
  get diagnostics v_families = row_count;

  -- Device accounts only: is_device_account has checked the address.
  delete from auth.users u where u.id = any(v_users);
  get diagnostics v_accounts = row_count;

  return jsonb_build_object('households', v_families, 'device_accounts', v_accounts);
end $$;

-- ------------------------------------------------------------ F20: the old founding, rate-limited

-- Same body as 20261011170000_security_hardening.sql, with the founder buckets of
-- api.setup_claim: a client that exhausted them is refused, and a wrong key is counted. A
-- wrong key is answered, not raised, so the count survives (a raise would roll it back);
-- the other refusals raise as before. Only the enrolment-era wizard and the integration test
-- call this; the claim (api.setup_claim, api.household_create) is the way in.
create or replace function api.setup_household(
  p_token text, p_household_name text, p_email text, p_password text,
  p_display_name text, p_color text, p_pin text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_hash   text := encode(extensions.digest(p_token, 'sha256'), 'hex');
  v_client text := app.request_client_key();
  v_hh     uuid;
  v_user   uuid;
  v_prof   uuid;
begin
  lock table app.household in exclusive mode;
  if exists (select 1 from app.household) then
    raise exception 'already set up' using errcode = '42501', hint = 'setup_closed';
  end if;
  if app.founder_attempts_exceeded(v_client) then
    raise exception 'too many attempts' using errcode = '42501', hint = 'rate_limited';
  end if;
  if not exists (select 1 from app.setup_token where token_hash = v_hash and consumed_at is null) then
    insert into app.founder_attempt (client_key, success) values (v_client, false);
    return jsonb_build_object('ok', false, 'reason', 'setup_token_invalid');
  end if;
  if length(coalesce(p_password, '')) < 10 then
    raise exception 'password too short' using errcode = '22023', hint = 'password_too_short';
  end if;
  if p_pin !~ '^[0-9]{6}$' then
    raise exception 'PIN must be 6 digits' using errcode = '22023', hint = 'pin_format';
  end if;

  insert into app.household (name) values (p_household_name) returning id into v_hh;
  v_user := app.create_auth_user(p_email, p_password);
  insert into app.profile (household_id, display_name, color, role, auth_user_id, pin_hash)
  values (v_hh, p_display_name, coalesce(p_color, '#2E7D6B'), 'guardian', v_user,
          extensions.crypt(p_pin, extensions.gen_salt('bf', 12)))
  returning id into v_prof;
  update app.setup_token set consumed_at = now() where token_hash = v_hash;
  insert into app.founder_attempt (client_key, success) values (v_client, true);
  insert into app.audit_log (household_id, actor_profile_id, entity_type, entity_id, action)
  values (v_hh, v_prof, 'household', v_hh, 'setup');
  return jsonb_build_object('ok', true, 'household_id', v_hh, 'profile_id', v_prof);
end $$;
