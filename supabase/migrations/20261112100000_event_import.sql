-- An event received as a calendar file (specs/05 "Sharing one event", the receiving side).
--
-- Another family sends one event as an .ics file; a guardian opens it in the app, looks at a
-- preview and adds it. The event becomes an ordinary row of this household: its own id, its own
-- uid, its own attendees. What is kept of its origin is the file's UID and SEQUENCE, so the same
-- event sent again after a change is offered as an update of that row and not as a second one.
--
--   * app.event.source_uid / source_sequence: the file's UID and SEQUENCE; null for every event
--     the family made itself. Not unique: two households on one server may receive the same file,
--     and a family may keep two copies on purpose. Never shown by api.events and never written to
--     the outbound feed, which keeps the row's own uid.
--   * api.event_import_lookup: the household's event that came from this UID, or the household's
--     own event with that uid (the family opened a file it sent itself).
--   * api.event_import: api.event_save plus the origin, in one transaction. An update is only
--     taken for a row that came from the same UID.
--   * Guardians only, never a kiosk: the file is a stranger's text entering the family calendar.
--
-- api_version: unchanged. Additive: two columns and two functions; the previous app release
-- neither reads nor writes them. api.server_info announces 'event-import'; an app on an older
-- server adds the event with api.event_save and cannot recognise a second copy.

alter table app.event
  add column source_uid text check (source_uid is null or length(source_uid) between 1 and 512),
  add column source_sequence int check (source_sequence is null or source_sequence >= 0);
create index event_source_uid_idx on app.event (household_id, source_uid) where source_uid is not null;

-- The event of the caller's household that belongs to p_source_uid: {"id", "sequence", "own"}.
-- "own" is true when the uid is the row's own, false when the row was received with it;
-- "sequence" is the SEQUENCE it was last received with. Null when there is none.
create function api.event_import_lookup(p_actor uuid, p_source_uid text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  a     app.actor_t := app.actor(p_actor);
  v_uid text := btrim(coalesce(p_source_uid, ''));
  v     jsonb;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if v_uid = '' or length(v_uid) > 512 then
    return null;
  end if;
  select jsonb_build_object('id', e.id, 'sequence', e.source_sequence, 'own', e.uid = v_uid)
    into v
    from app.event e
   where e.household_id = a.household_id and e.deleted_at is null
     and (e.source_uid = v_uid or e.uid = v_uid)
   order by (e.uid = v_uid) desc, e.updated_at desc
   limit 1;
  return v;
end $$;

revoke all on function api.event_import_lookup(uuid, text) from public, anon;
grant execute on function api.event_import_lookup(uuid, text) to authenticated;

-- Saves p_event as api.event_save does and records where it came from. With an "id" in p_event
-- the row must be one this household received with the same UID.
create function api.event_import(
  p_actor uuid, p_event jsonb, p_source_uid text, p_source_sequence int default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.actor(p_actor);
  v_uid    text := btrim(coalesce(p_source_uid, ''));
  v_seq    int := greatest(coalesce(p_source_sequence, 0), 0);
  v_result jsonb;
  v_id     uuid;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_event) is distinct from 'object' or v_uid = '' or length(v_uid) > 512
     or p_event ->> 'kind' is distinct from 'appointment' then
    raise exception 'WW-CAL-001 invalid event' using errcode = '22023', hint = 'event_invalid';
  end if;
  if p_event ? 'id' and not exists (
       select 1 from app.event e
        where e.id::text = lower(p_event ->> 'id') and e.household_id = a.household_id
          and e.deleted_at is null and e.source_uid = v_uid) then
    raise exception 'event not found' using errcode = 'P0002', hint = 'event_not_found';
  end if;

  v_result := api.event_save(p_actor, p_event);
  v_id := (v_result ->> 'id')::uuid;
  update app.event set source_uid = v_uid, source_sequence = v_seq where id = v_id;
  perform app.audit(a, 'event', v_id, 'import', jsonb_build_object('source_sequence', v_seq));
  return v_result;
end $$;

revoke all on function api.event_import(uuid, jsonb, text, int) from public, anon;
grant execute on function api.event_import(uuid, jsonb, text, int) to authenticated;

-- As in 20261104110000_discovery_creation_mode.sql, plus 'event-import'.
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
      'lighter-day', 'event-templates', 'password-reset', 'claim', 'local-matching', 'event-import'
    )
  );
$$;
