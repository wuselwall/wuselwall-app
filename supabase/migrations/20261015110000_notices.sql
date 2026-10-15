-- In-app notices on the adult Today tab (specs/20 J2 and J4): "Sabine ist beigetreten" for every
-- guardian, "Neu angemeldet: Daniels iPhone" for the account's other personal devices.
--
-- Design: derived, not stored. Both events already leave a durable, household-scoped record in
-- the same transaction that causes them: invitation acceptance writes an app.audit_log row
-- (entity 'invitation', action 'accept', actor = the profile that joined), and a sign-in on a
-- new phone inserts an app.device row (class 'personal', profile_id = the account's profile).
-- A second notice store would duplicate those facts and could drift from them. The audit log is
-- never exposed and has no policy for members, so the read goes through api.notices, a
-- security definer function in the style of api.getting_started: it takes the household, profile
-- and device from app.actor() and shows only what that actor may see. The one thing stored here
-- is the dismissal ("Gesehen"), per profile, keyed by the derived notice key
-- ('join:<audit id>', 'signin:<device id>'). Notices age out after 14 days on their own; old
-- dismissals are pruned on the next dismissal.
--
-- api_version: additive only (one table, one internal function, two api functions); no bump.
-- An app talking to a server without them gets "function not found" and shows no notices.

-- ------------------------------------------------------------------ table

create table app.notice_dismissal (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references app.household on delete cascade,
  profile_id    uuid not null references app.profile on delete cascade,
  notice_key    text not null check (notice_key ~ '^(join|signin):[0-9a-f-]{1,40}$'),
  dismissed_at  timestamptz not null default now(),
  unique (profile_id, notice_key)
);
create index on app.notice_dismissal (household_id);

alter table app.notice_dismissal enable row level security;
alter table app.notice_dismissal force row level security;

create policy notice_dismissal_read on app.notice_dismissal for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.notice_dismissal to postgres using (true) with check (true);

revoke all on app.notice_dismissal from public, anon, authenticated;
grant select on app.notice_dismissal to authenticated;

-- ------------------------------------------------------------------ internals

-- The notices the actor may see, newest first. Kiosks get none. Join notices go to guardians
-- (on a personal device, or a shared one with a verified PIN) and never to the joiner; sign-in
-- notices go to the same profile on its other personal devices, only for devices registered
-- after the viewing device was (so a new phone does not announce the old ones).
create function app.notices_for(a app.actor_t)
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
   where a.profile_role = 'guardian'
     and (a.device_class = 'personal' or coalesce(a.guardian_verified_until, '-infinity') > now())
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

revoke all on function app.notices_for(app.actor_t) from public, anon, authenticated;

-- ------------------------------------------------------------------ api

create function api.notices(p_actor uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'key', n.notice_key, 'kind', n.kind, 'at', n.at,
             'name', n.name, 'device_id', n.device_id, 'profile_id', n.profile_id)
           order by n.at desc)
      from app.notices_for(a) n), '[]'::jsonb);
end $$;

-- "Gesehen": hides one notice for the acting profile only. Only a notice the actor can see
-- (or has already been dismissed: a repeat is harmless) can be dismissed, which bounds the table.
create function api.notice_dismiss(p_actor uuid, p_key text) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  if not exists (select 1 from app.notices_for(a) n where n.notice_key = p_key)
     and not exists (select 1 from app.notice_dismissal d
                      where d.profile_id = a.profile_id and d.notice_key = p_key) then
    raise exception 'WW-ONB-002 unknown notice' using errcode = '22023', hint = 'notice_unknown';
  end if;

  delete from app.notice_dismissal
   where profile_id = a.profile_id and dismissed_at < now() - interval '30 days';
  insert into app.notice_dismissal (household_id, profile_id, notice_key)
  values (a.household_id, a.profile_id, p_key)
  on conflict (profile_id, notice_key) do nothing;

  perform app.audit(a, 'notice', null, 'dismiss', jsonb_build_object('key', p_key));
end $$;

revoke all on function api.notices(uuid), api.notice_dismiss(uuid, text) from public, anon;
grant execute on function api.notices(uuid), api.notice_dismiss(uuid, text) to authenticated;
