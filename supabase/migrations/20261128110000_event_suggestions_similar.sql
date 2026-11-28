-- Near-identical event titles make one suggestion (specs/28 "Suggestions", specs/29 feature 3).
--
-- api.event_suggestions grouped by the exact signature, so "Fussballtraining", "Fussball-
-- Training" and "Fussball Training" were three groups of one or two events and never reached
-- the three that make a suggestion regular. Now signatures of the same kind that app.event_
-- signatures_alike calls alike are one group:
--
--   * Alike, word by word (see the function): equal; or equal once spaces, hyphens and other
--     punctuation are removed ("arzttermin" / "arzt termin", "judokurs" / "judo-kurs"); or the
--     same number of words, each pair equal or, from four characters, a pg_trgm similarity of
--     at least 0.62 ("grosi" / "grossi"). An added or a different name keeps titles apart:
--     "coiffeur" / "coiffeur mia" (a word more), "zahnarzt mia" / "zahnarzt lia" (names under
--     four characters must be equal), "oma kommt" / "opa kommt".
--   * Within a kind the distinct signatures of the window are ranked: most events, then the most
--     recent, then the signature text. A root is a signature no higher-ranked one is alike to;
--     each signature joins the best-ranked root it is alike to (a root joins itself). One hop,
--     no chains, deterministic; the group's representative is a signature that has events of its
--     own in it, and the suggestion's `signature` is the representative.
--   * The count (at least three), the weights, the weekday bonus and every most-frequent pick
--     use the whole group.
--   * A group is not offered when any signature in it is hidden or has a saved template of the
--     same kind. Hiding or saving still names one signature (the one the tile showed).
--
-- Nothing else changes: same signature, grants, output shape, limits and revoked-device rule.
-- Additive for api_version; no data changes. pg_trgm is a trusted extension, installed in the
-- extensions schema as fuzzystrmatch is (20261031151000).

create extension if not exists pg_trgm with schema extensions;

-- Whether two signatures (app.event_signature) name the same thing, word by word:
--   1. equal;
--   2. equal once every space, hyphen and other punctuation is removed;
--   3. otherwise the same number of words (runs of spaces and hyphens separate them) and every
--      pair of words equal or, when both have at least four characters, with a pg_trgm
--      similarity of at least c_word_similar.
-- A different number of words is never alike, so an added name keeps titles apart ("coiffeur" /
-- "coiffeur mia", "zahnarzt mia" / "zahnarzt mia und noah"); words under four characters must
-- be equal, so "mia" and "lia" or "oma" and "opa" never merge. Measured (specs/28): "grosi" /
-- "grossi" 0.625, "mia" / "lia" 0.14, "papa" / "mama" 0.00, "turnen" / "tennis" 0.08,
-- "elternabend" / "elterngespräch" 0.29; the threshold passes the first and none of the rest.
-- Symmetric; the relation is not transitive, and the grouping does not need it to be.
create function app.event_signatures_alike(p_a text, p_b text) returns boolean
language plpgsql immutable parallel safe set search_path = '' as $$
declare
  c_word_similar constant real := 0.62;
  c_min_length   constant int := 4;
  v_a text[];
  v_b text[];
begin
  if p_a is null or p_b is null then
    return false;
  end if;
  if p_a = p_b then
    return true;
  end if;
  if regexp_replace(p_a, '[[:space:][:punct:]]+', '', 'g') = regexp_replace(p_b, '[[:space:][:punct:]]+', '', 'g')
     and regexp_replace(p_a, '[[:space:][:punct:]]+', '', 'g') <> '' then
    return true;
  end if;
  v_a := regexp_split_to_array(p_a, '[[:space:]-]+');
  v_b := regexp_split_to_array(p_b, '[[:space:]-]+');
  if cardinality(v_a) <> cardinality(v_b) then
    return false;
  end if;
  return not exists (
    select 1
      from unnest(v_a, v_b) as w(x, y)
     where x <> y
       and not (length(x) >= c_min_length and length(y) >= c_min_length
                and extensions.similarity(x, y) >= c_word_similar));
end $$;

-- api.event_suggestions runs as the caller and calls it (it reads nothing).
revoke all on function app.event_signatures_alike(text, text) from public, anon, authenticated;
grant execute on function app.event_signatures_alike(text, text) to authenticated;

-- What the family enters often (specs/28 "Suggestions from the family's history"), as a jsonb
-- array of at most p_limit (1–12) elements:
--   {signature, title, icon_key, kind, presence_state, is_all_day, start_minute,
--    duration_minutes, days, attendee_ids, location, count, last_on}
-- 1. The household's one-off events: not deleted, no rrule or rdates, not a tradition, starting
--    (all day: start_date; timed: the start's day in the event's zone) within the last 365 days
--    or the next 60 of the household's today.
-- 2. Grouped by kind and by near-identical app.event_signature(title) (see above); 3. a group of
--    at least three events.
-- 4. The title of the group's most recent event; the most frequent picture, all-day value, ISO
--    weekday, start time (in the event's zone) and length (of the events with that all-day
--    value), people (as a set) and presence state; the most frequent place when at least half
--    of the events have it. "No picture" is a value like any other. Ties go to the value of the
--    most recent event.
-- 5. Not offered: a group with a hidden signature, and a group with a signature of a saved
--    template of the same kind.
-- 6. Each event weighs 1 from 90 days ago on, ½ before; with p_on, a group whose most frequent
--    weekday is p_on's weighs 1.5 times. Highest first, then the most recent, then signature.
-- Runs as the caller: RLS shows only the events the caller may read, and a caller without a
-- household or on a revoked device gets [].
create or replace function api.event_suggestions(p_on date default null, p_limit int default 4) returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
declare
  v_household uuid := app.jwt_household();
  v_tz        text;
  v_today     date;
  v_limit     int := least(greatest(coalesce(p_limit, 4), 1), 12);
  v_result    jsonb;
begin
  if v_household is null or not app.device_ok() then
    return '[]'::jsonb;
  end if;
  select coalesce(h.timezone, 'UTC') into v_tz from app.household h where h.id = v_household;
  v_today := (now() at time zone coalesce(v_tz, 'UTC'))::date;

  with ev as (
    select e.id, e.title, e.kind, e.presence_state, e.icon_key, e.is_all_day, e.location,
           e.created_at, x.signature, x.start_day, x.start_minute, x.duration_minutes, x.days,
           coalesce((select array_agg(at.profile_id order by at.profile_id)
                       from app.event_attendee at where at.event_id = e.id), '{}') as attendees
      from app.event e
      cross join lateral (
        select app.event_signature(e.title) as signature,
               case when e.is_all_day then e.start_date
                    else (e.starts_at at time zone coalesce(e.timezone, v_tz))::date end as start_day,
               case when not e.is_all_day then
                 (extract(hour from e.starts_at at time zone coalesce(e.timezone, v_tz)) * 60
                  + extract(minute from e.starts_at at time zone coalesce(e.timezone, v_tz)))::int
               end as start_minute,
               case when not e.is_all_day then
                 round(extract(epoch from e.ends_at - e.starts_at) / 60)::int end as duration_minutes,
               case when e.is_all_day then e.end_date - e.start_date + 1 end as days) x
     where e.household_id = v_household
       and e.deleted_at is null and e.rrule is null and e.rdates is null and not e.tradition
       -- A coarse range the indexes can use; the exact one is below.
       and (e.start_date between v_today - 366 and v_today + 61
            or e.starts_at between ((v_today - 367)::timestamp at time zone 'UTC')
                               and ((v_today + 62)::timestamp at time zone 'UTC'))
  ),
  win as (
    select ev.*, extract(isodow from ev.start_day)::int as dow
      from ev
     where ev.signature is not null
       and ev.start_day between v_today - 365 and v_today + 60
  ),
  -- The distinct (signature, kind) pairs of the window, ranked within a kind: most events, then
  -- the most recent, then the signature.
  sig as (
    select w.signature, w.kind, count(*) as n, max(w.start_day) as last_on,
           row_number() over (partition by w.kind
                              order by count(*) desc, max(w.start_day) desc, w.signature) as rk
      from win w
     group by w.signature, w.kind
  ),
  near as (
    select a.kind, a.signature as sig, b.signature as other, b.rk as other_rk
      from sig a
      join sig b on b.kind = a.kind and b.signature <> a.signature
     where app.event_signatures_alike(a.signature, b.signature)
  ),
  -- A root is a signature no higher-ranked one is alike to. Every signature joins the
  -- best-ranked root it is alike to (a root joins itself): one hop, no chains, and the
  -- representative is always a signature whose own events are in its group.
  roots as (
    select s.kind, s.signature, s.rk
      from sig s
     where not exists (select 1 from near m
                        where m.kind = s.kind and m.sig = s.signature and m.other_rk < s.rk)
  ),
  grp as (
    select s.kind, s.signature,
           coalesce((select r.signature
                       from roots r
                      where r.kind = s.kind
                        and (r.signature = s.signature
                             or exists (select 1 from near m
                                         where m.kind = s.kind and m.sig = s.signature
                                           and m.other = r.signature))
                      order by r.rk
                      limit 1), s.signature) as rep
      from sig s
  ),
  counted as (
    -- How many events of the group share each value, to pick the most frequent one.
    select w.*, g.rep,
           case when w.start_day >= v_today - 90 then 1.0 else 0.5 end as weight,
           count(*) over (partition by rep, kind, icon_key)             as n_icon,
           count(*) over (partition by rep, kind, is_all_day)           as n_all_day,
           count(*) over (partition by rep, kind, dow) as n_dow,
           count(*) over (partition by rep, kind, is_all_day, start_minute)     as n_start,
           count(*) over (partition by rep, kind, is_all_day, duration_minutes) as n_duration,
           count(*) over (partition by rep, kind, is_all_day, days)     as n_days,
           count(*) over (partition by rep, kind, attendees)            as n_people,
           count(*) over (partition by rep, kind, presence_state)       as n_presence,
           count(*) over (partition by rep, kind, location)             as n_location
      from win w
      join (select kind as g_kind, signature as g_signature, rep from grp) g
        on g.g_kind = w.kind and g.g_signature = w.signature
  ),
  grouped as (
    select c.rep as signature, c.kind,
           count(*)::int as n,
           sum(c.weight) as weight,
           max(c.start_day) as last_on,
           (array_agg(c.title order by c.start_day desc, c.created_at desc, c.id))[1] as title,
           (array_agg(c.icon_key order by c.n_icon desc, c.start_day desc, c.created_at desc))[1] as icon_key,
           (array_agg(c.is_all_day order by c.n_all_day desc, c.start_day desc, c.created_at desc))[1] as is_all_day,
           (array_agg(c.dow order by c.n_dow desc, c.start_day desc, c.created_at desc))[1] as dow,
           (array_agg(c.start_minute order by c.n_start desc, c.start_day desc, c.created_at desc)
              filter (where not c.is_all_day))[1] as start_minute_timed,
           (array_agg(c.duration_minutes order by c.n_duration desc, c.start_day desc, c.created_at desc)
              filter (where not c.is_all_day))[1] as duration_timed,
           (array_agg(c.days order by c.n_days desc, c.start_day desc, c.created_at desc)
              filter (where c.is_all_day))[1] as days_all_day,
           -- As text: array_agg cannot gather arrays of different lengths, or empty ones.
           (array_agg(c.attendees::text order by c.n_people desc, c.start_day desc, c.created_at desc))[1]::uuid[]
             as attendees,
           (array_agg(c.presence_state order by c.n_presence desc, c.start_day desc, c.created_at desc))[1]
             as presence_state,
           (array_agg(c.location order by c.n_location desc, c.start_day desc, c.created_at desc)
              filter (where c.location is not null))[1] as location,
           max(c.n_location) filter (where c.location is not null) as n_location
      from counted c
     group by c.rep, c.kind
    having count(*) >= 3
  ),
  offered as (
    select g.*,
           g.weight * case when p_on is not null and g.dow = extract(isodow from p_on)::int
                           then 1.5 else 1 end as score
      from grouped g
     where not exists (select 1 from grp m
                         join app.event_suggestion_hidden s
                           on s.household_id = v_household and s.signature = m.signature
                        where m.kind = g.kind and m.rep = g.signature)
       and not exists (select 1 from grp m
                         join app.event_template t
                           on t.household_id = v_household and t.kind = m.kind
                          and app.event_signature(t.title) = m.signature
                        where m.kind = g.kind and m.rep = g.signature)
     order by score desc, g.last_on desc, g.signature, g.kind
     limit v_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'signature', o.signature,
           'title', o.title,
           'icon_key', case when o.kind = 'presence' then null else o.icon_key end,
           'kind', o.kind,
           'presence_state', o.presence_state,
           'is_all_day', o.is_all_day,
           'start_minute', case when o.is_all_day then null else o.start_minute_timed end,
           'duration_minutes', case when o.is_all_day then null else o.duration_timed end,
           'days', case when o.is_all_day then o.days_all_day end,
           'attendee_ids', to_jsonb(o.attendees),
           'location', case when o.n_location * 2 >= o.n then o.location end,
           'count', o.n,
           'last_on', o.last_on)
         order by o.score desc, o.last_on desc, o.signature, o.kind), '[]'::jsonb)
    into v_result
    from offered o;
  return v_result;
end $$;

-- create or replace keeps the grants; stated again so the file stands alone.
revoke all on function api.event_suggestions(date, int) from public, anon;
grant execute on function api.event_suggestions(date, int) to authenticated;
