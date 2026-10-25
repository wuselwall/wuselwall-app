-- Subscribed calendars: an unchanged feed no longer rewrites its occurrences or wakes the devices.
--
-- Since the import always fetches the whole feed (a 304 cannot rebuild the rolling window), the
-- hourly job stored every calendar again: delete, insert, broadcast 'calendar', and every device
-- refetched its calendar views and the board for nothing. app.external_calendar.rows_hash is the
-- SHA-256 of the canonical rows last stored. api.external_calendar_store compares the new rows
-- with it: equal (and the stored rows still all there) only records the attempt, different
-- replaces the rows and broadcasts as before. The hash sorts the rows itself, so the order the
-- Edge Function sends them in does not matter. A calendar without a hash (stored before this
-- migration) is replaced once and broadcast once.
--
-- No change to the contract: same signature, same grants (service role only), same return
-- value (the number of rows the calendar now has). api_version: unchanged.

alter table app.external_calendar add column rows_hash text
  check (rows_hash is null or length(rows_hash) = 64);

-- Fetch bookkeeping, like the etag: not part of the family's export.
update app.export_table set omit = array['etag', 'rows_hash'] where name = 'external_calendar';

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
           etag = left(p_etag, 300)
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
         etag = left(p_etag, 300), rows_hash = v_hash
   where id = p_id;
  perform app.broadcast(v_household, 'calendar');
  return n;
end $$;
