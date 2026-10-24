-- Defaults that follow the household's country (specs/21, specs/27 "Tischfrage").
--
-- A few curated defaults only make sense for some countries: the table question's meal
-- windows (11:30–13:30, 17:30–19:30) miss both meals in Spain and most dinners in France.
-- app.setting_country_default holds the exceptions, keyed by the country of
-- `household.region` (`ES` of `ES-MD`). An unchanged setting still has no household row, so
-- the country's default applies until the family sets its own value, and a reset brings it
-- back. A household without a region keeps the catalogue default.

create table app.setting_country_default (
  key     text not null references app.setting_definition on delete cascade,
  country text not null check (country ~ '^[A-Z]{2}$'),
  value   jsonb not null,
  primary key (key, country)
);

alter table app.setting_country_default enable row level security;
alter table app.setting_country_default force row level security;
create policy setting_country_default_read on app.setting_country_default for select to authenticated
  using (app.device_ok());
create policy owner_all on app.setting_country_default to postgres using (true) with check (true);
grant select on app.setting_country_default to authenticated;

-- Spain: comida about 14:00–15:30, cena about 21:00. France: dinner between about 18:50 and
-- 21:30, most often at 20:00 (INSEE time-use surveys); lunch fits the catalogue default.
insert into app.setting_country_default (key, country, value) values
  ('rituals.table_question.lunch',  'ES', '{"from":"13:30","to":"15:30"}'),
  ('rituals.table_question.dinner', 'ES', '{"from":"20:00","to":"22:00"}'),
  ('rituals.table_question.dinner', 'FR', '{"from":"19:00","to":"21:00"}');

-- The country of a household's region, or null while it has none.
create function app.household_country(p_household uuid) returns text
language sql stable set search_path = '' as $$
  select upper(split_part(s.value #>> '{}', '-', 1))
    from app.household_setting s
   where s.household_id = p_household and s.key = 'household.region'
     and s.profile_id is null and s.device_id is null
     and jsonb_typeof(s.value) = 'string'
$$;

-- The default of p_key for a household: its country's, else the catalogue's.
create function app.setting_default(p_household uuid, p_key text) returns jsonb
language sql stable set search_path = '' as $$
  select coalesce(
    (select c.value from app.setting_country_default c
      where c.key = p_key and c.country = app.household_country(p_household)),
    (select d.default_value from app.setting_definition d where d.key = p_key))
$$;

revoke execute on function app.household_country(uuid), app.setting_default(uuid, text)
  from public, anon, authenticated;

-- The same two value readers as before, now with the country's default before the catalogue's.
create or replace function app.setting_value(p_household uuid, p_key text, p_profile uuid default null)
returns jsonb language sql stable set search_path = '' as $$
  select coalesce(
    (select s.value from app.household_setting s
      where s.household_id = p_household and s.key = p_key
        and s.profile_id = p_profile and s.device_id is null),
    (select s.value from app.household_setting s
      where s.household_id = p_household and s.key = p_key
        and s.profile_id is null and s.device_id is null),
    app.setting_default(p_household, p_key))
$$;

create or replace function app.household_setting_value(p_household uuid, p_key text) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select s.value from app.household_setting s
      where s.household_id = p_household and s.key = p_key
        and s.profile_id is null and s.device_id is null limit 1),
    app.setting_default(p_household, p_key))
$$;

-- api.settings with the country's default as `default_value`, so the app shows, applies and
-- resets to it. The view stays security_invoker: the joins read only rows RLS lets through.
create or replace view api.settings with (security_invoker = true) as
  select d.key, d.scope, d.type, d.constraints, d.self_service,
         coalesce(c.value, d.default_value) as default_value,
         coalesce(h.value, c.value, d.default_value) as value,
         h.id is null as is_default,
         null::uuid as profile_id,
         null::uuid as device_id
    from app.setting_definition d
    left join app.household_setting h
      on h.key = d.key and h.household_id = app.jwt_household()
     and h.profile_id is null and h.device_id is null
    left join app.household_setting r
      on r.key = 'household.region' and r.household_id = app.jwt_household()
     and r.profile_id is null and r.device_id is null and jsonb_typeof(r.value) = 'string'
    left join app.setting_country_default c
      on c.key = d.key and c.country = upper(split_part(r.value #>> '{}', '-', 1))
  union all
  select o.key, d.scope, d.type, d.constraints, d.self_service,
         coalesce(c.value, d.default_value),
         o.value, false, o.profile_id, o.device_id
    from app.household_setting o
    join app.setting_definition d on d.key = o.key
    left join app.household_setting r
      on r.key = 'household.region' and r.household_id = o.household_id
     and r.profile_id is null and r.device_id is null and jsonb_typeof(r.value) = 'string'
    left join app.setting_country_default c
      on c.key = o.key and c.country = upper(split_part(r.value #>> '{}', '-', 1))
   where o.household_id = app.jwt_household()
     and (o.profile_id is not null or o.device_id is not null);

grant select on api.settings to authenticated;
