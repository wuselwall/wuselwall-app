-- Subscribed calendars record every fetch attempt before the fetch and back off after repeated
-- failures; a recurrence rule that can never match is refused at the door (security review
-- 2026-11-01, F6).
--
-- Why. The hourly import fetched the calendar with the oldest last_fetched_at first, and that
-- column was written only when a fetch ended (store or fail). A worker the runtime stops before
-- the end, as it does for a feed whose rules take minutes to expand, wrote nothing, so the same
-- calendar came first again every hour and nothing after it was fetched any more. The guardian's
-- "fetch now" read the same unwritten column and could start the same fetch again at once. The
-- same recurrence rules were accepted for the household's own events and chores, where the
-- expansion is the same code.
--
-- What changes.
--   app.external_calendar.last_attempt_at      when the last fetch was started (begin); the
--                                              existing rows take their last_fetched_at.
--   app.external_calendar.consecutive_failures failures in a row, 0 after a success.
--   api.external_calendar_begin(p_id)          service role; records the attempt before the fetch.
--       An attempt that was never concluded (last_attempt_at newer than last_fetched_at) is
--       counted as a failure with last_error 'interrupted' when the next one begins.
--   api.external_calendar_due(p_max)           orders by last_attempt_at and waits longer for a
--       calendar that keeps failing: 55 minutes as before up to two failures in a row, six hours
--       from the third, a day from the sixth. The guardian's "fetch now" is not held back by it.
--   api.external_calendar_fail                 counts the failure; store and not_modified reset.
--   api.external_calendar_get, api.external_calendar_refresh_request and the view
--       api.external_calendars carry last_attempt_at and consecutive_failures in addition.
--   A changed URL clears the attempt record with the rest (trigger).
--   app.rrule_valid(p_rrule)                   the recurrence check of the Edge Functions in SQL:
--       the supported subset as before, and no rule that can never match (a BYMONTHDAY none of
--       its months has such as 30 February, BYDAY mixing plain and n-th weekdays, a BYSETPOS
--       beyond what a period can hold, INTERVAL above 999, COUNT above 9999).
--   Triggers on app.event and app.task_definition refuse such a rule, a series that starts
--       before 1900 and an UNTIL before the start with the module's own error (WW-CAL-002,
--       WW-TSK-001), whichever function writes the row. Rows stored before this migration are
--       not touched: they keep showing, but such a row cannot be saved again until its rule
--       is changed. The migration lists them (app.rrule_invalid_rows, a count per household,
--       no content) as notices in the migrate output, so the operator knows.
--
-- Compatibility: signatures unchanged, JSON answers and the view gain keys and columns at the
-- end only, the fetch codes gain 'interrupted' (shown as a general problem by the apps).
-- api_version: unchanged.

-- ------------------------------------------------------------------ the attempt record

alter table app.external_calendar
  add column last_attempt_at timestamptz,
  add column consecutive_failures int not null default 0 check (consecutive_failures >= 0);
update app.external_calendar set last_attempt_at = last_fetched_at;

-- Fetch bookkeeping, like the etag: not part of the family's export.
update app.export_table set omit = array['etag', 'rows_hash', 'last_attempt_at', 'consecutive_failures']
 where name = 'external_calendar';

create or replace view api.external_calendars with (security_invoker = true) as
  select id, name, substring(url from '^https://([^/?#:]+)') as url_host, colour_hex, member_ids,
         show_on_board, active, last_fetched_at, last_error, created_at, updated_at,
         last_attempt_at, consecutive_failures
    from app.external_calendar;

-- A new URL is a new feed: what was learnt about the old one goes with it (external_calendar_save
-- clears the occurrences, the etag and the fetch record itself).
create function app.external_calendar_url_changed() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.url is distinct from old.url then
    new.last_attempt_at := null;
    new.consecutive_failures := 0;
  end if;
  return new;
end $$;
create trigger external_calendar_url_changed before update of url on app.external_calendar
  for each row execute function app.external_calendar_url_changed();

-- Records that a fetch starts now. The previous attempt, if it never ended, is counted as a
-- failure here: the worker that ran it was stopped and could not say so itself.
create function api.external_calendar_begin(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_row app.external_calendar;
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  select * into v_row from app.external_calendar where id = p_id for update;
  if not found then
    raise exception 'external calendar not found' using errcode = 'P0002', hint = 'external_calendar_not_found';
  end if;
  if v_row.last_attempt_at is not null
     and (v_row.last_fetched_at is null or v_row.last_fetched_at < v_row.last_attempt_at) then
    update app.external_calendar
       set consecutive_failures = consecutive_failures + 1, last_error = 'interrupted'
     where id = p_id;
  end if;
  update app.external_calendar set last_attempt_at = now() where id = p_id;
end $$;

-- The calendars the hourly job should fetch, the longest-waiting first. "Older than 55 minutes"
-- rather than an hour: the job runs at the top of every hour, so a calendar fetched at 10:00:03
-- must be due at 11:00:01. The clock is the later of the last attempt and the last result, so a
-- result recorded without a begin (an older Edge Function) counts as well. A calendar that fails
-- again and again waits longer, so that one broken feed costs the others nothing.
create or replace function api.external_calendar_due(p_max int) returns jsonb
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
          join app.household h on h.id = c.household_id and h.deleted_at is null
         where c.active
           and (greatest(c.last_attempt_at, c.last_fetched_at) is null
                or greatest(c.last_attempt_at, c.last_fetched_at) < now() - case
                     when c.consecutive_failures >= 6 then interval '24 hours'
                     when c.consecutive_failures >= 3 then interval '6 hours'
                     else interval '55 minutes' end)
         order by greatest(c.last_attempt_at, c.last_fetched_at) nulls first, c.id
         limit least(greatest(coalesce(p_max, 1), 1), 100)
      ) d);
end $$;

create or replace function api.external_calendar_get(p_id uuid) returns jsonb
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
                            'active', v_row.active, 'last_fetched_at', v_row.last_fetched_at,
                            'last_attempt_at', v_row.last_attempt_at,
                            'consecutive_failures', v_row.consecutive_failures);
end $$;

create or replace function api.external_calendar_refresh_request(p_actor uuid, p_id uuid) returns jsonb
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
                            'last_fetched_at', v_old.last_fetched_at, 'last_error', v_old.last_error,
                            'last_attempt_at', v_old.last_attempt_at,
                            'consecutive_failures', v_old.consecutive_failures);
end $$;

-- Replaces the calendar's occurrences in one transaction (20261025160000: only when they differ,
-- by rows_hash). A success ends the run of failures.
create or replace function api.external_calendar_store(p_id uuid, p_rows jsonb, p_etag text) returns int
language plpgsql security definer set search_path = '' as $$
declare
  n  int;
  v_household uuid;
  v_old text;
  v_hash text;
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then
    raise exception 'WW-CAL-005 external calendar invalid' using errcode = '22023', hint = 'external_calendar_invalid';
  end if;
  select c.household_id, c.rows_hash into v_household, v_old
    from app.external_calendar c where c.id = p_id for update;
  if not found then
    raise exception 'external calendar not found' using errcode = 'P0002', hint = 'external_calendar_not_found';
  end if;

  -- One line per row (a JSON array: null stays distinct from empty, instants in UTC whatever the
  -- session zone), the lines sorted bytewise so the hash does not depend on the order sent.
  select encode(extensions.digest(coalesce(string_agg(x.line, E'\n' order by x.line collate "C"), ''), 'sha256'), 'hex'),
         count(*)::int
    into v_hash, n
    from (select jsonb_build_array(r.uid, r.starts_at at time zone 'UTC', r.ends_at at time zone 'UTC',
                                   r.all_day, r.start_date, r.end_date, r.title, r.location)::text as line
            from jsonb_to_recordset(p_rows) as r(uid text, starts_at timestamptz, ends_at timestamptz,
                 all_day boolean, start_date date, end_date date, title text, location text)) x;

  -- The row count guards against rows deleted elsewhere (a changed URL clears them).
  if v_old = v_hash
     and (select count(*) from app.external_occurrence where calendar_id = p_id) = n then
    update app.external_calendar set last_fetched_at = now(), last_error = null,
           etag = left(p_etag, 300), consecutive_failures = 0
     where id = p_id;
    return n;
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
         etag = left(p_etag, 300), rows_hash = v_hash, consecutive_failures = 0
   where id = p_id;
  perform app.broadcast(v_household, 'calendar');
  return n;
end $$;

create or replace function api.external_calendar_not_modified(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  update app.external_calendar set last_fetched_at = now(), last_error = null, consecutive_failures = 0
   where id = p_id;
end $$;

create or replace function api.external_calendar_fail(p_id uuid, p_error text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  update app.external_calendar
     set last_fetched_at = now(), last_error = left(coalesce(p_error, 'internal'), 200),
         consecutive_failures = consecutive_failures + 1
   where id = p_id;
end $$;

revoke all on function api.external_calendar_begin(uuid) from public, anon, authenticated;
grant execute on function api.external_calendar_begin(uuid) to service_role;

-- ------------------------------------------------------------------ the recurrence check

-- The supported RRULE subset (specs/05 "Recurrence", occurrences.ts parseRrule), and the rules
-- of that subset which can never match. The Edge Functions' parser refuses the same rules, so
-- what the database stores is what the server will expand.
create function app.rrule_valid(p_rrule text) returns boolean
language plpgsql immutable set search_path = '' as $$
declare
  c_part      constant text := '^(FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)|INTERVAL=[1-9][0-9]{0,2}|COUNT=[1-9][0-9]{0,3}|UNTIL=[0-9]{8}(T[0-9]{6}Z)?|BYDAY=([+-]?[0-9]{1,2})?(MO|TU|WE|TH|FR|SA|SU)(,([+-]?[0-9]{1,2})?(MO|TU|WE|TH|FR|SA|SU))*|BYMONTHDAY=-?[0-9]{1,2}(,-?[0-9]{1,2})*|BYMONTH=[0-9]{1,2}(,[0-9]{1,2})*|BYSETPOS=-?[0-9]{1,3}|WKST=(MO|TU|WE|TH|FR|SA|SU))$';
  c_max_days  constant int[] := array[31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  v_parts     text[];
  v_freq      text;
  v_until     text;
  v_byday     text[];
  v_monthdays int[];
  v_months    int[];
  v_setpos    int;
  v_nord      int := 0;
  v_nplain    int := 0;
  v_largest   int;
  v_nmonths   int;
begin
  if p_rrule is null or length(p_rrule) not between 1 and 300 then return false; end if;
  v_parts := regexp_split_to_array(p_rrule, ';');
  if exists (select 1 from unnest(v_parts) as x(part) where x.part !~ c_part) then return false; end if;
  -- Every part once, FREQ among them.
  if (select count(distinct split_part(x.part, '=', 1)) from unnest(v_parts) as x(part)) <> cardinality(v_parts)
     or not exists (select 1 from unnest(v_parts) as x(part) where x.part like 'FREQ=%') then
    return false;
  end if;
  v_freq      := (select split_part(x.part, '=', 2) from unnest(v_parts) as x(part) where x.part like 'FREQ=%');
  v_until     := (select split_part(x.part, '=', 2) from unnest(v_parts) as x(part) where x.part like 'UNTIL=%');
  v_byday     := (select string_to_array(split_part(x.part, '=', 2), ',') from unnest(v_parts) as x(part) where x.part like 'BYDAY=%');
  v_monthdays := (select string_to_array(split_part(x.part, '=', 2), ',')::int[] from unnest(v_parts) as x(part) where x.part like 'BYMONTHDAY=%');
  v_months    := (select string_to_array(split_part(x.part, '=', 2), ',')::int[] from unnest(v_parts) as x(part) where x.part like 'BYMONTH=%');
  v_setpos    := (select split_part(x.part, '=', 2)::int from unnest(v_parts) as x(part) where x.part like 'BYSETPOS=%');

  -- RFC 5545: COUNT and UNTIL never together; UNTIL is a real date.
  if p_rrule ~ '(^|;)COUNT=' and v_until is not null then return false; end if;
  if v_until is not null then
    begin
      perform to_date(left(v_until, 8), 'YYYYMMDD');
    exception when others then
      return false;
    end;
    if left(v_until, 8) <> to_char(to_date(left(v_until, 8), 'YYYYMMDD'), 'YYYYMMDD') then return false; end if;
  end if;

  -- Values in range; n-th weekdays only by month (up to the 5th) or year (up to the 53rd), and
  -- mixed with plain weekdays only when one of the n-th weekdays is among the plain ones (the
  -- plain ones filter the n-th ones: MO,1MO is the first Monday, MO,1TU never matches).
  if v_monthdays is not null and exists (select 1 from unnest(v_monthdays) d where d = 0 or abs(d) > 31) then return false; end if;
  if v_months is not null and exists (select 1 from unnest(v_months) m where m < 1 or m > 12) then return false; end if;
  if v_byday is not null then
    v_nord := (select count(*) from unnest(v_byday) d where d ~ '^[+-]?[0-9]');
    v_nplain := cardinality(v_byday) - v_nord;
    if v_nord > 0 then
      if v_freq not in ('MONTHLY', 'YEARLY') then return false; end if;
      if exists (select 1 from unnest(v_byday) d
                  where d ~ '^[+-]?[0-9]'
                    and (abs(substring(d from '^[+-]?[0-9]+')::int) = 0
                         or abs(substring(d from '^[+-]?[0-9]+')::int) > case when v_freq = 'MONTHLY' then 5 else 53 end)) then
        return false;
      end if;
      if v_nplain > 0 and not exists (
           select 1 from unnest(v_byday) o join unnest(v_byday) pl on right(pl, 2) = right(o, 2)
            where o ~ '^[+-]?[0-9]' and pl !~ '^[+-]?[0-9]') then
        return false;
      end if;
    end if;
  end if;

  -- A BYMONTHDAY that none of the listed months has (30 February, 31 April, -31 in June).
  if v_monthdays is not null and not exists (
       select 1 from unnest(coalesce(v_months, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])) m
         join unnest(v_monthdays) d on abs(d) <= c_max_days[m]) then
    return false;
  end if;

  -- BYSETPOS beyond the largest set a period can hold (the loosest true bound, as in the parser).
  if v_setpos is not null then
    if v_setpos = 0 or abs(v_setpos) > 366 then return false; end if;
    v_nmonths := coalesce(cardinality(v_months), 12);
    if v_freq = 'DAILY' then
      v_largest := 1;
    elsif v_freq = 'WEEKLY' then
      v_largest := coalesce(cardinality(v_byday), 1);
    elsif v_freq = 'MONTHLY' then
      if v_byday is null and v_monthdays is null then
        v_largest := 1;
      else
        v_largest := 31;
        if v_byday is not null then
          v_largest := least(v_largest, case when v_nord > 0 then v_nord else 5 * v_nplain end);
        end if;
        if v_monthdays is not null then v_largest := least(v_largest, cardinality(v_monthdays)); end if;
      end if;
    else
      if v_byday is null and v_monthdays is null then
        v_largest := coalesce(cardinality(v_months), 1); -- DTSTART's day in each listed month
      else
        v_largest := 366;
        if v_byday is not null then
          v_largest := least(v_largest, case
            when v_nord > 0 and v_months is not null then v_nord * v_nmonths
            when v_nord > 0 then v_nord
            when v_months is not null then 5 * v_nplain * v_nmonths
            else 53 * v_nplain end);
        end if;
        if v_monthdays is not null then v_largest := least(v_largest, cardinality(v_monthdays) * v_nmonths); end if;
      end if;
    end if;
    if abs(v_setpos) > v_largest then return false; end if;
  end if;
  return true;
end $$;

-- The rows stored before this migration whose rule the check refuses, counted per household.
-- They keep showing (the walk is bounded whatever the rule); saving one again is refused until
-- its rule is changed, so the operator is told about them when migrating.
create function app.rrule_invalid_rows() returns table (household_id uuid, events int, chores int)
language sql stable set search_path = '' as $$
  select h.id,
         (select count(*) from app.event e
           where e.household_id = h.id and e.deleted_at is null
             and e.rrule is not null and not app.rrule_valid(e.rrule))::int,
         (select count(*) from app.task_definition t
           where t.household_id = h.id and t.is_active
             and t.rrule is not null and not app.rrule_valid(t.rrule))::int
    from app.household h
   where exists (select 1 from app.event e where e.household_id = h.id and e.deleted_at is null
                    and e.rrule is not null and not app.rrule_valid(e.rrule))
      or exists (select 1 from app.task_definition t where t.household_id = h.id and t.is_active
                    and t.rrule is not null and not app.rrule_valid(t.rrule))
$$;
do $$
declare r record;
begin
  for r in select * from app.rrule_invalid_rows() loop
    raise notice 'household %: % event(s) and % chore(s) carry a recurrence rule the new check refuses; they keep showing but cannot be saved again until the rule is changed',
      r.household_id, r.events, r.chores;
  end loop;
end $$;

-- An event's rule, its start and its UNTIL, whichever function writes the row. The same error as
-- api.event_save gives for a rule outside the subset.
create function app.event_rrule_check() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_start date;
  v_until text;
begin
  if new.rrule is null then return new; end if;
  if not app.rrule_valid(new.rrule) then
    raise exception 'WW-CAL-002 rrule invalid' using errcode = '22023', hint = 'rrule_invalid';
  end if;
  v_start := case when new.is_all_day then new.start_date
                  else (new.starts_at at time zone new.timezone)::date end;
  if v_start is not null and extract(year from v_start) < 1900 then
    raise exception 'WW-CAL-002 rrule invalid' using errcode = '22023', hint = 'rrule_invalid';
  end if;
  v_until := substring(new.rrule from '(?:^|;)UNTIL=([0-9]{8})');
  if v_start is not null and v_until is not null and to_date(v_until, 'YYYYMMDD') < v_start then
    raise exception 'WW-CAL-002 rrule invalid' using errcode = '22023', hint = 'rrule_invalid';
  end if;
  return new;
end $$;
create trigger event_rrule_check before insert or update of rrule, starts_at, start_date, is_all_day, timezone
  on app.event for each row execute function app.event_rrule_check();

-- A chore's rule the same way, with the tasks module's error.
create function app.task_definition_rrule_check() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_until text;
begin
  if new.rrule is null then return new; end if;
  if not app.rrule_valid(new.rrule) then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  if new.starts_on is not null and extract(year from new.starts_on) < 1900 then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  v_until := substring(new.rrule from '(?:^|;)UNTIL=([0-9]{8})');
  if new.starts_on is not null and v_until is not null and to_date(v_until, 'YYYYMMDD') < new.starts_on then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  return new;
end $$;
create trigger task_definition_rrule_check before insert or update of rrule, starts_on
  on app.task_definition for each row execute function app.task_definition_rrule_check();

-- The app schema's functions are the database's own; nothing in app is called from a client.
revoke all on function app.rrule_valid(text), app.rrule_invalid_rows(), app.event_rrule_check(),
  app.task_definition_rrule_check(), app.external_calendar_url_changed() from public, anon, authenticated;
