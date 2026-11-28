-- What a child sees becomes two switches for guardians (specs/09 "What a child sees",
-- specs/21 "Family"): `household.kid_shopping`, which exists, and `household.kid_calendar`,
-- new here. With the calendar on, a child looks at today and the next three days; off, only
-- today. Both also apply to a shared tablet and the wall while nobody is chosen there.
--
-- On by default and for every family that exists: the look ahead is new, so nothing a family
-- uses disappears with the update.
--
-- Additive for api_version: one catalogue row. The app that knows the switch treats a server
-- without the row as "on"; the previous app release lists the row under Family in Advanced
-- with its key as the title and does nothing with it.

insert into app.setting_definition (key, scope, type, default_value, constraints, self_service, since_migration) values
  ('household.kid_calendar',          'household', 'boolean',      'true',                            '{}',                                          false, '20261128100000');
