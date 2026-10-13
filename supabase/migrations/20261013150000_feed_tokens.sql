-- M1.3b ICS feed tokens (specs/05 "The ICS feed", ADR-013 for the self-hosted stack).
--
-- A token is 32 random bytes, base64url-encoded, shown once at creation. Only its SHA-256 hash is
-- stored. The Edge Function `ics` calls api.ics_feed with the service-role key; that key is used for
-- this function only, because a calendar client has no user. The function returns only the data
-- of the one household the token belongs to, and nothing for a revoked or unknown token.

-- ------------------------------------------------------------------ table

create table app.calendar_feed_token (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  label                 text not null check (length(btrim(label)) between 1 and 60),
  token_hash            text not null unique,
  filter                jsonb not null
                          default '{"profile_ids":[],"calendar_ids":[],"kinds":["appointment"],"school":"off"}'
                          check (jsonb_typeof(filter) = 'object'),
  created_by_profile_id uuid references app.profile on delete set null,
  created_at            timestamptz not null default now(),
  last_fetched_at       timestamptz,
  fetch_count           int not null default 0,
  revoked_at            timestamptz
);
create index on app.calendar_feed_token (household_id);

-- ------------------------------------------------------------------ RLS

alter table app.calendar_feed_token enable row level security;
alter table app.calendar_feed_token force row level security;

create policy feed_token_read on app.calendar_feed_token for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.calendar_feed_token to postgres using (true) with check (true);

-- The hash never leaves the database: every column but token_hash is readable, and the view
-- below lists only the columns a settings page needs.
revoke all on app.calendar_feed_token from public, anon, authenticated;
grant select (id, household_id, label, filter, created_by_profile_id, created_at, last_fetched_at,
              fetch_count, revoked_at)
  on app.calendar_feed_token to authenticated;

-- ------------------------------------------------------------------ api: reads

create view api.feed_tokens with (security_invoker = true) as
  select id, label, filter, created_at, last_fetched_at, fetch_count, revoked_at
    from app.calendar_feed_token;

grant select on api.feed_tokens to authenticated;
revoke all on api.feed_tokens from anon;

-- ------------------------------------------------------------------ internals

-- The events a feed token selects, as app.event rows. Shared by the feed and its overrides and
-- attendees, so the three always agree. Kinds, calendars and members are the token's filter (an
-- empty list means all); a member filter also keeps events nobody is named on (whole family).
-- Soft-deleted events stay for 30 days so subscribers see the cancellation. One-off events are
-- kept from 90 days ago to 400 days ahead; series are always kept.
create function app.feed_matching_events(t app.calendar_feed_token, p_today date)
returns setof app.event language sql stable set search_path = '' as $$
  select e.* from app.event e
   where e.household_id = t.household_id
     and e.kind in (select j.v from jsonb_array_elements_text(t.filter -> 'kinds') as j(v))
     and (jsonb_array_length(t.filter -> 'calendar_ids') = 0
          or e.calendar_id in (select j.v::uuid from jsonb_array_elements_text(t.filter -> 'calendar_ids') as j(v)))
     and (jsonb_array_length(t.filter -> 'profile_ids') = 0
          or not exists (select 1 from app.event_attendee a where a.event_id = e.id)
          or exists (select 1 from app.event_attendee a
                      where a.event_id = e.id
                        and a.profile_id in (select j.v::uuid from jsonb_array_elements_text(t.filter -> 'profile_ids') as j(v))))
     and (e.deleted_at is null or e.deleted_at >= now() - interval '30 days')
     and (e.rrule is not null or e.rdates is not null
          or (e.is_all_day and e.end_date >= p_today - 90 and e.start_date <= p_today + 400)
          or (not e.is_all_day and e.ends_at >= now() - interval '90 days'
              and e.starts_at <= now() + interval '400 days'))
$$;

revoke all on function app.feed_matching_events(app.calendar_feed_token, date)
  from public, anon, authenticated;

-- ------------------------------------------------------------------ api: guardian functions

-- Creates a token and returns it once. The filter defaults to appointments only, school off
-- (specs/05): presence and school are switched on by a deliberate act.
create function api.feed_token_create(p_actor uuid, p_label text, p_filter jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a           app.actor_t := app.actor(p_actor);
  c_uuid      constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_label     text := btrim(coalesce(p_label, ''));
  v_filter    jsonb;
  v_profiles  uuid[];
  v_calendars uuid[];
  v_kinds     text[];
  v_school    text;
  v_id        uuid := gen_random_uuid();
  v_token     text;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);

  if length(v_label) not between 1 and 60 then
    raise exception 'WW-CAL-004 feed label invalid' using errcode = '22023', hint = 'feed_label_invalid';
  end if;

  -- Missing keys take the column default; an unknown key is an error, not silently ignored.
  if p_filter is not null and jsonb_typeof(p_filter) <> 'object' then
    raise exception 'WW-CAL-004 feed filter invalid' using errcode = '22023', hint = 'feed_filter_invalid';
  end if;
  v_filter := '{"profile_ids":[],"calendar_ids":[],"kinds":["appointment"],"school":"off"}'::jsonb
              || coalesce(p_filter, '{}'::jsonb);
  if exists (select 1 from jsonb_object_keys(v_filter) as k(key)
              where k.key not in ('profile_ids', 'calendar_ids', 'kinds', 'school')) then
    raise exception 'WW-CAL-004 feed filter invalid' using errcode = '22023', hint = 'feed_filter_invalid';
  end if;

  -- Types first: the checks below may expand arrays, which needs an array.
  if jsonb_typeof(v_filter -> 'profile_ids') is distinct from 'array'
     or jsonb_typeof(v_filter -> 'calendar_ids') is distinct from 'array'
     or jsonb_typeof(v_filter -> 'kinds') is distinct from 'array'
     or jsonb_typeof(v_filter -> 'school') is distinct from 'string' then
    raise exception 'WW-CAL-004 feed filter invalid' using errcode = '22023', hint = 'feed_filter_invalid';
  end if;
  if jsonb_array_length(v_filter -> 'kinds') = 0
     or exists (select 1 from jsonb_array_elements_text(v_filter -> 'kinds') as k(v)
                 where coalesce(k.v, '') not in ('appointment', 'presence'))
     or (v_filter ->> 'school') not in ('off', 'day', 'lessons')
     or exists (select 1 from jsonb_array_elements_text(v_filter -> 'profile_ids') as x(v)
                 where coalesce(x.v, '') !~* c_uuid)
     or exists (select 1 from jsonb_array_elements_text(v_filter -> 'calendar_ids') as x(v)
                 where coalesce(x.v, '') !~* c_uuid) then
    raise exception 'WW-CAL-004 feed filter invalid' using errcode = '22023', hint = 'feed_filter_invalid';
  end if;

  v_profiles := array(select distinct x.v::uuid from jsonb_array_elements_text(v_filter -> 'profile_ids') as x(v));
  v_calendars := array(select distinct x.v::uuid from jsonb_array_elements_text(v_filter -> 'calendar_ids') as x(v));
  v_kinds := array(select distinct k.v from jsonb_array_elements_text(v_filter -> 'kinds') as k(v) order by k.v);
  v_school := v_filter ->> 'school';

  -- Every named member and calendar must belong to this household.
  if (select count(*) from app.profile p
       where p.id = any(v_profiles) and p.household_id = a.household_id) <> cardinality(v_profiles)
     or (select count(*) from app.calendar c
          where c.id = any(v_calendars) and c.household_id = a.household_id) <> cardinality(v_calendars) then
    raise exception 'WW-CAL-004 feed filter invalid' using errcode = '22023', hint = 'feed_filter_invalid';
  end if;

  v_filter := jsonb_build_object('profile_ids', to_jsonb(v_profiles), 'calendar_ids', to_jsonb(v_calendars),
                                 'kinds', to_jsonb(v_kinds), 'school', v_school);

  -- 32 random bytes, base64url without padding: 43 characters.
  v_token := replace(replace(translate(encode(extensions.gen_random_bytes(32), 'base64'), '+/', '-_'), '=', ''),
                     E'\n', '');

  insert into app.calendar_feed_token (id, household_id, label, token_hash, filter, created_by_profile_id)
  values (v_id, a.household_id, v_label, encode(extensions.digest(v_token, 'sha256'), 'hex'),
          v_filter, a.profile_id);
  perform app.audit(a, 'feed_token', v_id, 'create', jsonb_build_object('label', v_label, 'filter', v_filter));
  return jsonb_build_object('id', v_id, 'token', v_token);
end $$;

-- Revokes one token; the others keep working. Revoking a revoked token is a no-op.
create function api.feed_token_revoke(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);

  if not exists (select 1 from app.calendar_feed_token t
                  where t.id = p_id and t.household_id = a.household_id) then
    raise exception 'feed token not found' using errcode = 'P0002', hint = 'feed_token_not_found';
  end if;

  update app.calendar_feed_token set revoked_at = now()
   where id = p_id and revoked_at is null;
  if found then
    perform app.audit(a, 'feed_token', p_id, 'revoke');
  end if;
end $$;

-- ------------------------------------------------------------------ api: the feed

-- Called by the Edge Function `ics` with the service-role key, for the token in the URL. Unknown
-- and revoked tokens return NULL. Output: specs/05 "The ICS feed" and the contract in
-- scratchpad/ics-contract.md. The revision is the newest change to any event of the household
-- (an override bumps its parent's updated_at) or the token's creation, so a 304 is safe.
create function api.ics_feed(p_token text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  t           app.calendar_feed_token;
  h           app.household;
  v_today     date;
  v_events    jsonb;
  v_overrides jsonb;
  v_attendees jsonb;
  v_revision  bigint;
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

  return jsonb_build_object(
    'household', jsonb_build_object('name', h.name, 'timezone', h.timezone, 'locale', h.locale),
    'filter', t.filter,
    'revision', v_revision,
    'events', v_events,
    'overrides', v_overrides,
    'attendees', v_attendees);
end $$;

-- ------------------------------------------------------------------ grants

-- New api functions are executable by authenticated by default (see the schema migration); the
-- feed function is for the service role only, and the guardian functions need an explicit list.
revoke all on function api.feed_token_create(uuid, text, jsonb), api.feed_token_revoke(uuid, uuid),
  api.ics_feed(text) from public, anon;
grant execute on function api.feed_token_create(uuid, text, jsonb), api.feed_token_revoke(uuid, uuid)
  to authenticated;

revoke all on function api.ics_feed(text) from authenticated;
grant usage on schema api to service_role;
grant execute on function api.ics_feed(text) to service_role;
