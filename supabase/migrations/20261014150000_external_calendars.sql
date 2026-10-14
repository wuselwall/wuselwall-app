-- Imported external calendars (FR-1.9, specs/05 "Later: importing external calendars", ADR-013).
--
-- A household subscribes to read-only ICS feeds published elsewhere (a football club's fixtures,
-- the bin collection, a school's events). The SERVER fetches them (supabase/functions/
-- calendar-import, hourly, and on demand for a guardian); the apps never do (NFR-9). The fetched
-- feed is expanded there (supabase/functions/_shared/ical_parse.ts) and stored as plain rows in
-- app.external_occurrence, one row per occurrence inside the window the job keeps (30 days back,
-- 400 days ahead). Occurrences are read-only everywhere: the apps show them in the calendar's
-- read path with source 'imported' and never write them.
--
-- ============================================================================ APP CONTRACT
--
-- Read (authenticated, live device of the household; RLS as everywhere):
--
--   api.external_calendars   id, name, url_host, colour_hex, member_ids uuid[], show_on_board,
--                            active, last_fetched_at, last_error, created_at, updated_at
--                            (etag and the full url are not exposed). url_host is only the host name
--                            (www.fc-beispiel.de), for display: a feed address often carries a secret
--                            token, so every live device of the household sees the host and no more.
--                            last_fetched_at is the last ATTEMPT, success or failure; last_error is a
--                            short code (see below) or null after success.
--
--   api.external_calendar_url(p_actor uuid, p_id uuid) returns text
--       The full feed address, for the guardian's edit form. Guardians only (a child's device and
--       a kiosk are refused, a member gets guardian_required); the calendar must belong to the
--       actor's household (else WW-CAL-007). Read-only: writes no audit row.
--
--   api.external_occurrences id, calendar_id, calendar_name, colour_hex, member_ids,
--                            show_on_board, uid, starts_at, ends_at, all_day, start_date,
--                            end_date (inclusive, all-day only), title, location.
--                            Only rows of active calendars. Expanded: no RRULE, no overrides.
--
-- Write (authenticated, guardians only, with a current step-up on a shared device; a kiosk is
-- refused with 42501 kiosk_forbidden; a member gets 42501 guardian_required):
--
--   api.external_calendar_save(p_actor uuid, p_calendar jsonb) returns jsonb
--       Create (no "id") or update ("id" set). Keys: id, name (1-60 after trim), url, colour_hex
--       (#RRGGBB), member_ids (uuid[] of active profiles of the household; [] = whole family),
--       show_on_board (boolean), active (boolean). A key that is not sent keeps the stored value on
--       update; on create name and url are required, colour defaults to #B5651D, member_ids to [],
--       show_on_board and active to false and true. url is https only; webcal:// is stored as
--       https://. Returns {id}. Changing the URL deletes the calendar's occurrences and clears
--       last_fetched_at, etag and last_error, so the next hourly run fetches it at once.
--       Audit entity 'external_calendar' (the URL is not written to the audit log). A save that does
--       not send "url" keeps the stored address, so the apps leave the key out unless it was edited.
--
--   api.external_calendar_delete(p_actor uuid, p_id uuid) returns void
--       Deletes the calendar and its occurrences.
--
--   api.external_calendar_refresh_request(p_actor uuid, p_id uuid) returns jsonb
--       Guardian gate for the on-demand fetch (calendar-import, POST {calendar_id}). Returns
--       {id, active, last_fetched_at, last_error}. Writes nothing.
--
-- Errors (raised with the message 'WW-CAL-0nn ...' and the hint in the second column):
--   WW-CAL-003  attendee invalid  (hint attendee_invalid)  member_ids not active profiles of the household
--   WW-CAL-005  external calendar invalid  (hint external_calendar_invalid)  name, colour, flags, shape
--   WW-CAL-006  external calendar url invalid  (hint external_calendar_url_invalid)  not https, too long, malformed
--   WW-CAL-007  external calendar not found  (hint external_calendar_not_found, SQLSTATE P0002)
--   42501 kiosk_forbidden / guardian_required / service_role_required / device_revoked
--
-- Fetch failures (stored in last_error, never shown as an exception). A short code:
--   unreachable   network error, DNS failure, connection refused, too many redirects
--   timeout       no complete answer within 15 seconds
--   forbidden_host  the URL or a redirect target is not a public https host
--   too_large     the body is over 2 MB
--   not_ics       the answer is not an iCalendar document
--   http_<status> e.g. http_404, http_503 (a 304 without a stored etag is http_304)
--   internal      anything else on the server side
--   db            the store failed (database error, code in the function log only)
--
-- Service role only (the calendar-import Edge Function; revoked from every other role):
--   api.external_calendar_due(p_max int) returns jsonb    [{id, url, etag, timezone}] of active
--       calendars whose last attempt is older than 55 minutes or missing, oldest first.
--   api.external_calendar_get(p_id uuid) returns jsonb    {id, url, etag, timezone, active, last_fetched_at}
--   api.external_calendar_store(p_id uuid, p_rows jsonb, p_etag text) returns int
--       Replaces the calendar's occurrences in one transaction (p_rows: [{uid, starts_at, ends_at,
--       all_day, start_date, end_date, title, location}]), sets etag, last_fetched_at = now(),
--       last_error = null, and broadcasts 'calendar' to the household. Returns the row count.
--   api.external_calendar_not_modified(p_id uuid) returns void   (304: last_fetched_at = now())
--   api.external_calendar_fail(p_id uuid, p_error text) returns void   (last_error, last_fetched_at = now())
--
-- Realtime: every write that changes what the calendar shows broadcasts 'calendar' (the same
-- invalidation as events), so the apps refetch. The payload carries no data.
--
-- Edge Function supabase/functions/calendar-import (not in this file, the same contract):
--   Scheduled: POST with header x-cron-secret, hourly (infra/cron/calendar-import.sh). Answers
--     {calendars: n, results: [{id, status, rows?, skipped?, unsupported?, truncated?, code?}]}.
--   On demand: POST {calendar_id, actor_profile_id?} with the user's JWT (a guardian; the apps'
--     refresh action). Answers 200 {calendar_id, status, ...} where status is
--     'refreshed' | 'not_modified' | 'failed' (code = the last_error short code) | 'recent'
--     (fetched less than five minutes ago: nothing fetched, last_fetched_at and last_error
--     returned). Errors: 400 calendar_invalid, 401 unauthorized, 409 calendar_inactive, and the
--     database's own: 403 guardian_required / kiosk_forbidden, 404 WW-CAL-007
--     external_calendar_not_found (SQLSTATE P0002 mapped to 400 by the shared error mapper).
--
-- Occurrences (the `occurrences` and `board-week` functions, unchanged paths): imported rows are
-- read-only Occurrence JSON with source 'imported', calendar_id = the imported calendar,
-- colour_hex = its colour, attendee_ids = member_ids ([] = whole family), event_id
-- '<calendar_id>|<uid>', id 'imported|<row id>', is_recurring and is_override false. Two
-- fields are ADDED to every occurrence (additive JSON, read by no field that exists today):
--   source     'event' (the household's own event, editable) | 'imported' (read-only)
--   colour_hex null for events (they take the member colour), the calendar colour for imported
-- An imported occurrence is a key appointment (importance 'key') on the week board only when its
-- calendar has show_on_board; otherwise it is in the calendar views only.
--
-- api_version: additive only (new tables, views and functions); no bump needed.

-- ------------------------------------------------------------------ tables

create table app.external_calendar (
  id              uuid primary key default gen_random_uuid(),
  household_id    uuid not null references app.household on delete cascade,
  name            text not null check (length(btrim(name)) between 1 and 60),
  url             text not null check (length(url) <= 1000 and url ~ '^https://'),
  colour_hex      text not null check (colour_hex ~ '^#[0-9A-Fa-f]{6}$'),
  member_ids      uuid[] not null default '{}',
  show_on_board   boolean not null default false,
  active          boolean not null default true,
  last_fetched_at timestamptz,
  last_error      text check (last_error is null or length(last_error) <= 200),
  etag            text check (etag is null or length(etag) <= 300),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index on app.external_calendar (household_id);

create table app.external_occurrence (
  id           uuid primary key default gen_random_uuid(),
  calendar_id  uuid not null references app.external_calendar on delete cascade,
  household_id uuid not null references app.household on delete cascade,
  uid          text not null check (length(uid) between 1 and 500),
  starts_at    timestamptz,
  ends_at      timestamptz,
  all_day      boolean not null,
  start_date   date,
  end_date     date,
  title        text not null check (length(btrim(title)) between 1 and 200),
  location     text check (location is null or length(location) <= 200),
  -- Timed rows carry instants, all-day rows carry inclusive dates (the calendar's convention).
  check (case when all_day then
           start_date is not null and end_date is not null and end_date >= start_date
           and starts_at is null and ends_at is null
         else
           starts_at is not null and ends_at is not null and ends_at > starts_at
           and start_date is null and end_date is null
         end)
);
create index on app.external_occurrence (household_id, starts_at);
create index on app.external_occurrence (household_id, start_date);
create index on app.external_occurrence (calendar_id);

-- ------------------------------------------------------------------ RLS

alter table app.external_calendar   enable row level security;
alter table app.external_occurrence enable row level security;
alter table app.external_calendar   force row level security;
alter table app.external_occurrence force row level security;

create policy external_calendar_read on app.external_calendar for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy external_occurrence_read on app.external_occurrence for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());

create policy owner_all on app.external_calendar   to postgres using (true) with check (true);
create policy owner_all on app.external_occurrence to postgres using (true) with check (true);

-- No write grants: every change goes through the api functions below.
grant select on app.external_calendar, app.external_occurrence to authenticated;

-- ------------------------------------------------------------------ api: reads

-- url_host is the only part of the feed address every device may see (see the contract above).
create view api.external_calendars with (security_invoker = true) as
  select id, name, substring(url from '^https://([^/?#:]+)') as url_host, colour_hex, member_ids,
         show_on_board, active, last_fetched_at, last_error, created_at, updated_at
    from app.external_calendar;

create view api.external_occurrences with (security_invoker = true) as
  select o.id, o.calendar_id, c.name as calendar_name, c.colour_hex, c.member_ids, c.show_on_board,
         o.uid, o.starts_at, o.ends_at, o.all_day, o.start_date, o.end_date, o.title, o.location
    from app.external_occurrence o
    join app.external_calendar c on c.id = o.calendar_id
   where c.active;

grant select on api.external_calendars, api.external_occurrences to authenticated;
revoke all on api.external_calendars, api.external_occurrences from public, anon;

-- ------------------------------------------------------------------ api: guardian writes

-- Create or update one imported calendar. See the contract above.
create function api.external_calendar_save(p_actor uuid, p_calendar jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a          app.actor_t := app.actor(p_actor);
  c_uuid     constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_old      app.external_calendar;
  v_found    boolean;
  v_id       uuid;
  v_name     text;
  v_url      text;
  v_colour   text;
  v_members  uuid[];
  v_board    boolean;
  v_active   boolean;
  v_changed  boolean := false;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_calendar) is distinct from 'object' then
    raise exception 'WW-CAL-005 external calendar invalid' using errcode = '22023', hint = 'external_calendar_invalid';
  end if;

  if nullif(p_calendar ->> 'id', '') is null then
    v_id := gen_random_uuid();
    v_found := false;
  else
    if (p_calendar ->> 'id') !~* c_uuid then
      raise exception 'WW-CAL-005 external calendar invalid' using errcode = '22023', hint = 'external_calendar_invalid';
    end if;
    v_id := (p_calendar ->> 'id')::uuid;
    select * into v_old from app.external_calendar where id = v_id for update;
    v_found := found;
    if v_found and v_old.household_id <> a.household_id then
      raise exception 'external calendar not found' using errcode = 'P0002', hint = 'external_calendar_not_found';
    end if;
  end if;

  -- Name.
  v_name := case when p_calendar ? 'name' then btrim(coalesce(p_calendar ->> 'name', '')) else v_old.name end;
  if v_name is null or length(v_name) not between 1 and 60 then
    raise exception 'WW-CAL-005 external calendar invalid' using errcode = '22023', hint = 'external_calendar_invalid';
  end if;

  -- URL: webcal:// is the same feed over https. Anything else that is not https is refused.
  if p_calendar ? 'url' then
    v_url := btrim(coalesce(p_calendar ->> 'url', ''));
    if lower(left(v_url, 9)) = 'webcal://' then
      v_url := 'https://' || substring(v_url from 10);
    elsif lower(left(v_url, 8)) = 'https://' then
      v_url := 'https://' || substring(v_url from 9);
    end if;
    if length(v_url) > 1000 or v_url !~ '^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?([/?#][[:graph:]]*)?$' then
      raise exception 'WW-CAL-006 external calendar url invalid' using errcode = '22023',
        hint = 'external_calendar_url_invalid';
    end if;
  else
    v_url := v_old.url;
  end if;
  if v_url is null then
    raise exception 'WW-CAL-006 external calendar url invalid' using errcode = '22023',
      hint = 'external_calendar_url_invalid';
  end if;

  -- Colour.
  v_colour := case when p_calendar ? 'colour_hex' then p_calendar ->> 'colour_hex'
                   else coalesce(v_old.colour_hex, '#B5651D') end;
  if coalesce(v_colour, '') !~ '^#[0-9A-Fa-f]{6}$' then
    raise exception 'WW-CAL-005 external calendar invalid' using errcode = '22023', hint = 'external_calendar_invalid';
  end if;

  -- Flags.
  if (p_calendar ? 'show_on_board' and jsonb_typeof(p_calendar -> 'show_on_board') is distinct from 'boolean')
     or (p_calendar ? 'active' and jsonb_typeof(p_calendar -> 'active') is distinct from 'boolean') then
    raise exception 'WW-CAL-005 external calendar invalid' using errcode = '22023', hint = 'external_calendar_invalid';
  end if;
  v_board  := case when p_calendar ? 'show_on_board' then (p_calendar ->> 'show_on_board')::boolean
                   else coalesce(v_old.show_on_board, false) end;
  v_active := case when p_calendar ? 'active' then (p_calendar ->> 'active')::boolean
                   else coalesce(v_old.active, true) end;

  -- Members: who the calendar concerns. Empty = the whole family. Each must be an active profile
  -- of this household.
  if p_calendar ? 'member_ids' then
    if jsonb_typeof(p_calendar -> 'member_ids') = 'null' then
      v_members := '{}';
    elsif jsonb_typeof(p_calendar -> 'member_ids') is distinct from 'array' then
      raise exception 'WW-CAL-003 attendee invalid' using errcode = '22023', hint = 'attendee_invalid';
    else
      if exists (select 1 from jsonb_array_elements_text(p_calendar -> 'member_ids') as x(v)
                  where coalesce(x.v, '') !~* c_uuid) then
        raise exception 'WW-CAL-003 attendee invalid' using errcode = '22023', hint = 'attendee_invalid';
      end if;
      v_members := array(select distinct x.v::uuid
                           from jsonb_array_elements_text(p_calendar -> 'member_ids') as x(v));
    end if;
    if (select count(*) from app.profile p
         where p.id = any(v_members) and p.household_id = a.household_id and p.active)
       <> cardinality(v_members) then
      raise exception 'WW-CAL-003 attendee invalid' using errcode = '22023', hint = 'attendee_invalid';
    end if;
  else
    v_members := coalesce(v_old.member_ids, '{}');
  end if;

  v_changed := v_found and v_url is distinct from v_old.url;

  if v_found then
    if v_changed then
      delete from app.external_occurrence where calendar_id = v_id;
    end if;
    update app.external_calendar set
      name = v_name, url = v_url, colour_hex = v_colour, member_ids = v_members,
      show_on_board = v_board, active = v_active, updated_at = now(),
      last_fetched_at = case when v_changed then null else last_fetched_at end,
      etag            = case when v_changed then null else etag end,
      last_error      = case when v_changed then null else last_error end
     where id = v_id;
  else
    insert into app.external_calendar (id, household_id, name, url, colour_hex, member_ids,
                                       show_on_board, active)
    values (v_id, a.household_id, v_name, v_url, v_colour, v_members, v_board, v_active);
  end if;

  perform app.audit(a, 'external_calendar', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('name', v_name, 'active', v_active));
  perform app.broadcast(a.household_id, 'calendar');
  return jsonb_build_object('id', v_id);
end $$;

-- The full feed address, for the guardian's edit form. Reads only; no audit row.
create function api.external_calendar_url(p_actor uuid, p_id uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  a     app.actor_t := app.actor(p_actor);
  v_url text;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  select c.url into v_url from app.external_calendar c
   where c.id = p_id and c.household_id = a.household_id;
  if not found then
    raise exception 'external calendar not found' using errcode = 'P0002', hint = 'external_calendar_not_found';
  end if;
  return v_url;
end $$;

-- Deletes one imported calendar and its occurrences.
create function api.external_calendar_delete(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a     app.actor_t := app.actor(p_actor);
  v_old app.external_calendar;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  select * into v_old from app.external_calendar
   where id = p_id and household_id = a.household_id for update;
  if not found then
    raise exception 'external calendar not found' using errcode = 'P0002', hint = 'external_calendar_not_found';
  end if;
  delete from app.external_calendar where id = p_id;
  perform app.audit(a, 'external_calendar', p_id, 'delete', jsonb_build_object('name', v_old.name));
  perform app.broadcast(a.household_id, 'calendar');
end $$;

-- The guardian gate of the on-demand fetch. Writes nothing; the Edge Function then fetches with
-- the service role (api.external_calendar_get and the store functions below).
create function api.external_calendar_refresh_request(p_actor uuid, p_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a     app.actor_t := app.actor(p_actor);
  v_old app.external_calendar;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  select * into v_old from app.external_calendar
   where id = p_id and household_id = a.household_id;
  if not found then
    raise exception 'external calendar not found' using errcode = 'P0002', hint = 'external_calendar_not_found';
  end if;
  return jsonb_build_object('id', v_old.id, 'active', v_old.active,
                            'last_fetched_at', v_old.last_fetched_at, 'last_error', v_old.last_error);
end $$;

-- ------------------------------------------------------------------ service role (calendar-import)

-- The calendars the hourly job should fetch. "Older than 55 minutes" rather than an hour: the
-- job runs at the top of every hour, so a calendar fetched at 10:00:03 must be due at 11:00:01.
create function api.external_calendar_due(p_max int) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'url', d.url, 'etag', d.etag,
                                                 'timezone', d.timezone)), '[]'::jsonb)
      from (
        select c.id, c.url, c.etag, h.timezone
          from app.external_calendar c
          join app.household h on h.id = c.household_id
         where c.active
           and (c.last_fetched_at is null or c.last_fetched_at < now() - interval '55 minutes')
         order by c.last_fetched_at nulls first, c.id
         limit least(greatest(coalesce(p_max, 1), 1), 100)
      ) d);
end $$;

-- One calendar for the fetch: its URL, etag and the household timezone (the expansion zone).
create function api.external_calendar_get(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_row app.external_calendar;
  v_tz  text;
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  select * into v_row from app.external_calendar where id = p_id;
  if not found then
    raise exception 'external calendar not found' using errcode = 'P0002', hint = 'external_calendar_not_found';
  end if;
  select h.timezone into v_tz from app.household h where h.id = v_row.household_id;
  return jsonb_build_object('id', v_row.id, 'url', v_row.url, 'etag', v_row.etag, 'timezone', v_tz,
                            'active', v_row.active, 'last_fetched_at', v_row.last_fetched_at);
end $$;

-- Replaces the calendar's occurrences in one transaction. p_rows: [{uid, starts_at, ends_at,
-- all_day, start_date, end_date, title, location}]. Returns the number of rows stored.
create function api.external_calendar_store(p_id uuid, p_rows jsonb, p_etag text) returns int
language plpgsql security definer set search_path = '' as $$
declare
  n  int;
  v_household uuid;
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then
    raise exception 'WW-CAL-005 external calendar invalid' using errcode = '22023', hint = 'external_calendar_invalid';
  end if;
  select c.household_id into v_household from app.external_calendar c where c.id = p_id for update;
  if not found then
    raise exception 'external calendar not found' using errcode = 'P0002', hint = 'external_calendar_not_found';
  end if;

  delete from app.external_occurrence where calendar_id = p_id;
  insert into app.external_occurrence (calendar_id, household_id, uid, starts_at, ends_at, all_day,
                                       start_date, end_date, title, location)
  select p_id, v_household, r.uid, r.starts_at, r.ends_at, r.all_day, r.start_date, r.end_date,
         r.title, r.location
    from jsonb_to_recordset(p_rows) as r(uid text, starts_at timestamptz, ends_at timestamptz,
         all_day boolean, start_date date, end_date date, title text, location text);
  get diagnostics n = row_count;

  update app.external_calendar set last_fetched_at = now(), last_error = null,
         etag = left(p_etag, 300)
   where id = p_id;
  perform app.broadcast(v_household, 'calendar');
  return n;
end $$;

-- 304 Not Modified: the feed is unchanged since the stored etag.
create function api.external_calendar_not_modified(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  update app.external_calendar set last_fetched_at = now(), last_error = null where id = p_id;
end $$;

-- A failed attempt: the short code goes to last_error; the stored occurrences are kept.
create function api.external_calendar_fail(p_id uuid, p_error text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  update app.external_calendar set last_fetched_at = now(), last_error = left(coalesce(p_error, 'internal'), 200)
   where id = p_id;
end $$;

-- ------------------------------------------------------------------ grants

-- Guardian writes and the guardian gate: authenticated only.
revoke all on function api.external_calendar_save(uuid, jsonb), api.external_calendar_delete(uuid, uuid),
  api.external_calendar_refresh_request(uuid, uuid), api.external_calendar_url(uuid, uuid) from public, anon;
grant execute on function api.external_calendar_save(uuid, jsonb), api.external_calendar_delete(uuid, uuid),
  api.external_calendar_refresh_request(uuid, uuid), api.external_calendar_url(uuid, uuid) to authenticated;

-- The fetch job: the service role only. New functions are executable by PUBLIC unless revoked.
revoke all on function api.external_calendar_due(int), api.external_calendar_get(uuid),
  api.external_calendar_store(uuid, jsonb, text), api.external_calendar_not_modified(uuid),
  api.external_calendar_fail(uuid, text) from public, anon, authenticated;
grant execute on function api.external_calendar_due(int), api.external_calendar_get(uuid),
  api.external_calendar_store(uuid, jsonb, text), api.external_calendar_not_modified(uuid),
  api.external_calendar_fail(uuid, text) to service_role;
