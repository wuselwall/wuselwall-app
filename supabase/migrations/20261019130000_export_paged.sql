-- The household export for households with years of data (FR-5.16, specs/20 J6).
--
-- api.household_export builds one jsonb document in one statement: with years of events,
-- tasks and audit rows it outgrows the statement timeout, PostgREST's response and the
-- phone's memory. The export is now read in pages instead: api.household_export_begin
-- checks the caller and writes the audit row, api.household_export_page returns one page of
-- one table in primary-key order (keyset, so every page is an index range scan), and the
-- household-export Edge Function streams the pages into a zip file.
--
-- Which tables are exported, and which of their columns stay in the database, is now one
-- list, app.export_table: a new household table is one insert there. api.household_export
-- stays for the previous app release and is rebuilt on the same list (its rows now come in
-- primary-key order). Additive for api_version: a table, an internal function, two api
-- functions and indexes; the previous app release keeps calling api.household_export.

-- ------------------------------------------------------------------ the list

create table app.export_table (
  name     text primary key,
  -- The order of the tables in the export.
  position int not null unique,
  -- Columns of this table that stay in the database, besides the secrets every table drops
  -- (app.export_page's v_secret).
  omit     text[] not null default '{}',
  -- When set, only these columns leave the database: for tables whose new columns must not
  -- leak by default.
  keep     text[]
);

alter table app.export_table enable row level security;
alter table app.export_table force row level security;
create policy owner_all on app.export_table to postgres using (true) with check (true);
-- No grants: only the export functions read it.

insert into app.export_table (name, position, omit, keep) values
  ('profile',             10, '{}', null),
  -- Devices: label, class and dates only; the Auth user and guardian-verification state stay out.
  ('device',              20, '{}', array['id', 'label', 'class', 'register', 'profile_id',
                                          'created_at', 'last_seen_at', 'revoked_at']),
  ('household_setting',   30, '{}', null),
  ('audit_log',           40, '{}', null),
  ('calendar',            50, '{}', null),
  ('event',               60, '{}', null),
  ('event_attendee',      70, '{}', null),
  ('event_override',      80, '{}', null),
  ('usual_presence',      90, '{}', null),
  ('calendar_feed_token', 100, '{}', null),
  ('school',              110, '{}', null),
  ('school_period',       120, '{}', null),
  ('school_term',         130, '{}', null),
  ('school_holiday',      140, '{}', null),
  -- Subscribed calendars, without the fetch bookkeeping; their occurrences are a cache of the URL.
  ('external_calendar',   150, array['etag'], null),
  ('subject',             160, '{}', null),
  ('timetable',           170, '{}', null),
  ('timetable_lesson',    180, '{}', null),
  ('timetable_exception', 190, '{}', null),
  ('shopping_list',       200, '{}', null),
  ('shopping_item',       210, '{}', null),
  ('shopping_trip',       220, '{}', null),
  ('shopping_category',   230, '{}', null),
  ('catalog_item',        240, '{}', null),
  ('recipe',              250, '{}', null),
  ('recipe_ingredient',   260, '{}', null),
  ('meal_plan_entry',     270, '{}', null),
  ('task_definition',     280, '{}', null),
  ('task_instance',       290, '{}', null),
  ('point_transaction',   300, '{}', null),
  ('reward',              310, '{}', null),
  ('reward_redemption',   320, '{}', null),
  ('streak',              330, '{}', null),
  ('badge_definition',    340, '{}', null),
  ('badge_award',         350, '{}', null),
  ('tasks_day_closed',    360, '{}', null),
  -- Invitations: token and code hashes are secrets (v_secret); the accepting Auth user is one too.
  ('invitation',          370, array['accepted_by_user'], null),
  -- Shortcut tokens: label, holder and dates; the hash is a secret (v_secret), and the daily
  -- write counter is bookkeeping.
  ('shortcut_token',      380, array['writes_on', 'writes_count'], null);

-- ------------------------------------------------------------------ indexes

-- A page is "this household's rows after the last key, in key order". The tables that grow
-- with the years get an index on (household_id, primary key), so each page is one index range
-- scan however many pages came before. The other tables hold a few dozen rows per household.
create index audit_log_household_id_id_idx on app.audit_log (household_id, id);
create index event_household_id_id_idx on app.event (household_id, id);
create index event_attendee_household_id_key_idx on app.event_attendee (household_id, event_id, profile_id);
create index event_override_household_id_id_idx on app.event_override (household_id, id);
create index task_instance_household_id_id_idx on app.task_instance (household_id, id);
create index meal_plan_entry_household_id_id_idx on app.meal_plan_entry (household_id, id);
create index shopping_item_household_id_id_idx on app.shopping_item (household_id, id);
create index shopping_trip_household_id_id_idx on app.shopping_trip (household_id, id);
create index reward_redemption_household_id_id_idx on app.reward_redemption (household_id, id);
-- These three replace an index on household_id alone, which the new one covers.
create index point_transaction_household_id_id_idx on app.point_transaction (household_id, id);
drop index app.point_transaction_household_id_idx;
create index badge_award_household_id_id_idx on app.badge_award (household_id, id);
drop index app.badge_award_household_id_idx;
create index timetable_exception_household_id_id_idx on app.timetable_exception (household_id, id);
drop index app.timetable_exception_household_id_idx;

-- ------------------------------------------------------------------ one page

-- One page of one exported table of p_household: at most p_limit rows (null: all of them)
-- whose primary key is greater than p_after, in primary-key order, as
-- {rows: [...], next: <the last row's key, or null after the last page>}. p_after is a
-- previous page's `next`. Secrets never leave: the columns in v_secret are dropped from every
-- table, and app.export_table's omit and keep from its own. Called only by the api export
-- functions, after they checked the caller.
create function app.export_page(p_household uuid, p_table text, p_after jsonb, p_limit int)
returns jsonb language plpgsql stable set search_path = '' as $$
declare
  -- Columns that never leave the database, whichever table they sit in.
  v_secret constant text[] := array['pin_hash', 'pin_failures', 'pin_locked_until', 'auth_user_id',
                                    'auth_session_id', 'token_hash', 'code_hash'];
  t       app.export_table;
  v_key   text;  -- the primary key columns: r.a, r.b
  v_after text;  -- the cursor's values, typed like the key: ($2 ->> 'a')::uuid, …
  v_next  text;  -- the cursor of a row: 'a', r.a, 'b', r.b
  v_rows  jsonb;
  v_count int;
  v_last  jsonb;
begin
  select * into t from app.export_table where name = p_table;
  if not found then
    raise exception 'unknown export table' using errcode = '22023', hint = 'export_table_unknown';
  end if;

  select string_agg(format('r.%I', a.attname), ', ' order by k.ord),
         string_agg(format('($2 ->> %L)::%s', a.attname, format_type(a.atttypid, a.atttypmod)),
                    ', ' order by k.ord),
         string_agg(format('%L, r.%I', a.attname, a.attname), ', ' order by k.ord)
    into v_key, v_after, v_next
    from pg_index i
    cross join unnest(i.indkey) with ordinality k(attnum, ord)
    join pg_attribute a on a.attrelid = i.indrelid and a.attnum = k.attnum
   where i.indrelid = format('app.%I', t.name)::regclass and i.indisprimary;

  execute format($q$
    with page as (
      select r.* from app.%1$I r
       where r.household_id = $1 %2$s
       order by %3$s
       limit $3)
    select coalesce(jsonb_agg(
             case when $5::text[] is null then to_jsonb(r) - $4
                  else (select coalesce(jsonb_object_agg(e.key, e.value), '{}')
                          from jsonb_each(to_jsonb(r)) e
                         where e.key = any($5) and e.key <> all($4))
             end order by %3$s), '[]'),
           count(*),
           (select jsonb_build_object(%4$s) from page r order by %5$s limit 1)
      from page r
    $q$,
    t.name,
    -- No cursor (SQL or JSON null) is the first page.
    case when coalesce(jsonb_typeof(p_after), 'null') = 'null' then ''
         else format('and (%s) > (%s)', v_key, v_after) end,
    v_key,
    v_next,
    (select string_agg(c || ' desc', ', ') from unnest(string_to_array(v_key, ', ')) c))
  into v_rows, v_count, v_last
  using p_household, p_after, p_limit, v_secret || t.omit, t.keep;

  return jsonb_build_object(
    'rows', v_rows,
    'next', case when p_limit is not null and v_count = p_limit then v_last end);
end $$;

revoke execute on function app.export_page(uuid, text, jsonb, int) from public, anon, authenticated;

-- The caller of an export: a guardian on a personal device.
create function app.export_actor(p_actor uuid) returns app.actor_t
language plpgsql stable security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  perform app.require_guardian(a);
  if a.device_class <> 'personal' then
    raise exception 'personal device required' using errcode = '42501', hint = 'personal_device_required';
  end if;
  return a;
end $$;

revoke execute on function app.export_actor(uuid) from public, anon, authenticated;

-- ------------------------------------------------------------------ the api

-- Starts an export: checks the caller, writes the audit row, and returns what the export's
-- own description carries (format version 2: a zip file with one file per table) and the
-- tables to read, in order.
create function api.household_export_begin(p_actor uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.export_actor(p_actor);
begin
  perform app.audit(a, 'household', a.household_id, 'export');
  return jsonb_build_object(
    'format', 'wuselwall-export',
    'version', 2,
    'exported_at', now(),
    'household', coalesce((select to_jsonb(h) from app.household h where h.id = a.household_id), '{}'),
    'tables', (select jsonb_agg(t.name order by t.position) from app.export_table t));
end $$;

-- One page of one table (app.export_page); the caller is checked on every page.
create function api.household_export_page(p_actor uuid, p_table text, p_after jsonb default null,
                                          p_limit int default 1000) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare a app.actor_t := app.export_actor(p_actor);
begin
  if p_limit is null or p_limit < 1 or p_limit > 5000 then
    raise exception 'page size out of range' using errcode = '22023', hint = 'export_limit_invalid';
  end if;
  return app.export_page(a.household_id, p_table, p_after, p_limit);
end $$;

revoke execute on function api.household_export_begin(uuid) from public, anon;
revoke execute on function api.household_export_page(uuid, text, jsonb, int) from public, anon;
grant execute on function api.household_export_begin(uuid) to authenticated;
grant execute on function api.household_export_page(uuid, text, jsonb, int) to authenticated;

-- The one-document export (format version 1) of the previous app release, now built from
-- app.export_table. Replaces api.household_export of 20261019110000_usual_week.sql with the
-- same document; its grants stay.
create or replace function api.household_export(p_actor uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.export_actor(p_actor);
begin
  perform app.audit(a, 'household', a.household_id, 'export');
  return jsonb_build_object(
    'format', 'wuselwall-export',
    'version', 1,
    'exported_at', now(),
    'household', coalesce((select to_jsonb(h) from app.household h where h.id = a.household_id), '{}'),
    'tables', (select jsonb_object_agg(t.name, app.export_page(a.household_id, t.name, null, null) -> 'rows')
                 from app.export_table t));
end $$;
