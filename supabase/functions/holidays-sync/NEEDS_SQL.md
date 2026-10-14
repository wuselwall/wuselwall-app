# holidays-sync needs these SQL functions

`holidays-sync` (index.ts) writes the public holiday cache with the service role. As
`tasks-nightly` does, it reaches `app` tables only through `api` functions that check
`app.is_service_role()` and are granted to `service_role` alone. PostgREST does not expose
`app`, so no migration of this package adds these: the integrator adds the following to the
holidays migration (after the tables `app.region`, `app.holiday_feed`, `app.holiday_feed_sync`
and the school and `household.region` override exist).

The functions are called by the Edge Function through `rpc` with the names and parameters
below, so keep the names exact. Every function is `security definer` with `search_path = ''`,
like the other api functions; its owner (postgres) is covered by the owner policy the other
app tables use, so the holiday tables need one too (see the note at the end).

```sql
-- ---------------------------------------------------------------- holiday cache (service role)
-- Service-role-only functions for holidays-sync. The cache holds no household data.

-- Countries to refresh: those in the sync table, the schools' region codes and the household
-- region overrides. Country = the two-letter prefix of a region code ("CH-ZH" -> "CH").
create function api.holiday_cache_countries() returns text[]
language plpgsql stable security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  return coalesce((
    select array_agg(distinct c order by c)
      from (
        select s.country as c from app.holiday_feed_sync s
        union
        select split_part(sc.region_code, '-', 1) from app.school sc where sc.region_code is not null
        union
        select split_part(hs.value #>> '{}', '-', 1)
          from app.household_setting hs
         where hs.key = 'household.region' and jsonb_typeof(hs.value) = 'string'
      ) x
     where x.c ~ '^[A-Z]{2}$'
  ), '{}'::text[]);
end $$;

-- The cache state of one country: {fetched_at, regions, holidays}. fetched_at is null when the
-- country was never fetched.
create function api.holiday_cache_state(p_country text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  return jsonb_build_object(
    'fetched_at', (select s.fetched_at from app.holiday_feed_sync s where s.country = p_country),
    'regions',    (select count(*) from app.region r where r.country = p_country),
    'holidays',   (select count(*) from app.holiday_feed h where h.country = p_country));
end $$;

-- Claims a refresh attempt: sets requested_at to p_at unless an attempt is recorded at or after
-- p_retry_before. Returns false when the claim was refused (a recent attempt is on record).
-- The on-demand call passes p_retry_before = now - 10 minutes; the scheduled job passes now.
create function api.holiday_cache_claim(p_country text, p_at timestamptz, p_retry_before timestamptz)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  insert into app.holiday_feed_sync (country, requested_at) values (p_country, p_at)
  on conflict (country) do update set requested_at = excluded.requested_at
    where app.holiday_feed_sync.requested_at is null
       or app.holiday_feed_sync.requested_at < p_retry_before;
  return found;
end $$;

-- Upserts regions: p_rows is a JSON array of {code, country, parent_code, level, category,
-- short_name, names, fetched_at}. Returns the number of rows written.
create function api.holiday_cache_put_regions(p_rows jsonb) returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then
    raise exception 'holiday cache rows invalid' using errcode = '22023', hint = 'holiday_cache_invalid';
  end if;
  insert into app.region (code, country, parent_code, level, category, short_name, names, fetched_at)
  select r.code, r.country, r.parent_code, r.level, r.category, r.short_name, r.names, r.fetched_at
    from jsonb_to_recordset(p_rows) as r(code text, country text, parent_code text, level smallint,
         category text, short_name text, names jsonb, fetched_at timestamptz)
  on conflict (code) do update set
    country = excluded.country, parent_code = excluded.parent_code, level = excluded.level,
    category = excluded.category, short_name = excluded.short_name, names = excluded.names,
    fetched_at = excluded.fetched_at;
  get diagnostics n = row_count;
  return n;
end $$;

-- Upserts holidays: p_rows is a JSON array of {id, country, kind, starts_on, ends_on, names,
-- nationwide, subdivisions, fetched_at}. Returns the number of rows written.
create function api.holiday_cache_put_holidays(p_rows jsonb) returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then
    raise exception 'holiday cache rows invalid' using errcode = '22023', hint = 'holiday_cache_invalid';
  end if;
  insert into app.holiday_feed (id, country, kind, starts_on, ends_on, names, nationwide, subdivisions, fetched_at)
  select h.id, h.country, h.kind, h.starts_on, h.ends_on, h.names, h.nationwide, h.subdivisions, h.fetched_at
    from jsonb_to_recordset(p_rows) as h(id text, country text, kind text, starts_on date, ends_on date,
         names jsonb, nationwide boolean, subdivisions text[], fetched_at timestamptz)
  on conflict (id) do update set
    country = excluded.country, kind = excluded.kind, starts_on = excluded.starts_on,
    ends_on = excluded.ends_on, names = excluded.names, nationwide = excluded.nationwide,
    subdivisions = excluded.subdivisions, fetched_at = excluded.fetched_at;
  get diagnostics n = row_count;
  return n;
end $$;

-- Removes the country's holidays of one kind that start in [p_from, p_to] and are not in p_keep
-- (the ids the API returned): corrections propagate. Returns the number removed.
create function api.holiday_cache_prune(p_country text, p_kind text, p_from date, p_to date, p_keep text[])
returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  delete from app.holiday_feed h
   where h.country = p_country
     and h.kind = p_kind
     and h.starts_on between p_from and p_to
     and not (h.id = any (coalesce(p_keep, '{}'::text[])));
  get diagnostics n = row_count;
  return n;
end $$;

-- Records a successful refresh: fetched_at, the window, and last_error cleared.
create function api.holiday_cache_finish(p_country text, p_fetched_at timestamptz, p_from date, p_to date)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  insert into app.holiday_feed_sync (country, fetched_at, valid_from, valid_to, last_error)
  values (p_country, p_fetched_at, p_from, p_to, null)
  on conflict (country) do update set
    fetched_at = excluded.fetched_at, valid_from = excluded.valid_from,
    valid_to = excluded.valid_to, last_error = null;
end $$;

-- Records a failed refresh in last_error (fetched_at is kept, so the last good data stays).
create function api.holiday_cache_fail(p_country text, p_error text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  insert into app.holiday_feed_sync (country, last_error) values (p_country, left(p_error, 200))
  on conflict (country) do update set last_error = excluded.last_error;
end $$;

-- Grants: the service role only, never the apps. New functions are executable by PUBLIC unless
-- revoked.
revoke all on function api.holiday_cache_countries(), api.holiday_cache_state(text),
  api.holiday_cache_claim(text, timestamptz, timestamptz), api.holiday_cache_put_regions(jsonb),
  api.holiday_cache_put_holidays(jsonb), api.holiday_cache_prune(text, text, date, date, text[]),
  api.holiday_cache_finish(text, timestamptz, date, date), api.holiday_cache_fail(text, text)
  from public, anon, authenticated;
grant execute on function api.holiday_cache_countries(), api.holiday_cache_state(text),
  api.holiday_cache_claim(text, timestamptz, timestamptz), api.holiday_cache_put_regions(jsonb),
  api.holiday_cache_put_holidays(jsonb), api.holiday_cache_prune(text, text, date, date, text[]),
  api.holiday_cache_finish(text, timestamptz, date, date), api.holiday_cache_fail(text, text)
  to service_role;
```

## Notes for the integrator

- **Assumed names.** `app.school.region_code` (the contract's name). The school table in this
  checkout has `state_code` (`^[A-Z]{2}-[A-Z0-9]{1,3}$`) and no `region_code`; if the holidays
  migration renames or adds the column, keep the `split_part(sc.region_code, ...)` branch in
  `holiday_cache_countries` in step with it. The household override is read as
  `app.household_setting` with `key = 'household.region'` and a JSON string value. That key
  is not in `app.setting_definition` yet, and the `type` check there (boolean, integer, time,
  enum, weekday_time, time_range, times) has no free-text type: the migration must either add a
  type (e.g. `region`) to that check or store the region as a closed `enum`. Until then the
  override cannot be stored, and the third branch of `holiday_cache_countries` only matches
  rows that exist.
- **Catalogue test.** `supabase/tests/040_catalogue.test.sql` enumerates the exposed functions
  and must list these eight, and pgTAP should cover the guard (a non-service caller gets 42501)
  and the prune and claim behaviour.
- **RLS of the cache tables.** The functions run as the owner, like the other api functions.
  The holiday cache tables need `enable row level security` and `force row level security`, and
  the same `owner_all ... to postgres using (true) with check (true)` policy the other app tables
  have, or the owner's writes are blocked by forced RLS. The apps get `select` only, through
  views that read the cache for any signed-in device (`app.device_ok()`), not by household.
- **Region picker.** The app reads the regions and holidays from api views; this function only
  fills them. Its response is `{country, fetched_at, regions, holidays}` (counts).
- **Array parameters.** `jsonb_to_recordset` maps JSON arrays onto the `text[]` columns
  (`subdivisions`, `p_keep`); check this on the server with the pgTAP run.
