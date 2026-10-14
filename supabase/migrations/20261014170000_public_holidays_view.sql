-- Public holidays applied from the region (specs/04 "Holidays", ADR-008). No import step: a
-- school's day is free on a public holiday that covers the school's region_code, and the week
-- board marks a day that the household's region (household.region) covers. The cache rows are
-- read by the Edge Functions through these views, as the caller (RLS: live devices only).

-- ------------------------------------------------------------------ api: reads

-- The public holiday cache, for the holidays the apps and the board apply by region. The
-- region-matching rule is app.region_covers (the same rule the Edge Functions mirror in
-- _shared/openholidays.ts). Anonymous callers read nothing.
create view api.holiday_feed with (security_invoker = true) as
  select id, country, kind, starts_on, ends_on, names, nationwide, subdivisions from app.holiday_feed;

-- The household's own row: its timezone and locale. Read by the week board for the language
-- of a holiday name (household.locale). app.household is readable by the household's live
-- devices already (household_read); the view only narrows the columns.
create view api.household with (security_invoker = true) as
  select id, name, timezone, locale from app.household;

grant select on api.holiday_feed, api.household to authenticated;
revoke all on api.holiday_feed, api.household from public, anon;
