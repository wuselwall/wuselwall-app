-- The Shopping tab of the kid register becomes a switch for guardians (specs/09 "Screens by
-- register", specs/21 "Shopping"): off for a new family, so the children's view has four tabs,
-- and on for every family that exists now, so nothing they use disappears with the update.
-- Children can still add items on the wall (Q33), whatever this says.
--
-- Additive for api_version: a catalogue row and its values. The previous app release keeps its
-- five tabs and lists the row under Family in Advanced with its key as the title.

insert into app.setting_definition (key, scope, type, default_value, constraints, self_service, since_migration) values
  ('household.kid_shopping',          'household', 'boolean',      'false',                           '{}',                                          false, '20261104100000');

insert into app.household_setting (household_id, key, value)
select id, 'household.kid_shopping', 'true'::jsonb from app.household;
