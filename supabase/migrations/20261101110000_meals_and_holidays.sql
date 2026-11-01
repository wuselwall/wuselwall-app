-- Warm meals and holidays (specs/21 "Meals (M1.4)", specs/26 "Seasons and occasions").
--
-- A family may eat warm at lunch and at dinner, or at neither: `meals.warm_meal.*` gain the
-- values `both` and `none`. The board then shows both meals of a day (`days[i].meals`, `meal`
-- stays the dinner for the previous app release) or none (`meal` null, which every release
-- already handles).
--
-- Three more holidays decorate the sky, each one switch whose 'auto' follows the country of
-- `household.region` like Advent and Easter: Christmas, Saint Nicholas (Nikolaus, Samichlaus)
-- and the country's national day.
--
-- Additive for api_version: two wider enums and three catalogue rows. The previous app release
-- reads `both` and `none` as its default slot, and lists the three new rows under Advanced with
-- their key as the title.

update app.setting_definition
   set constraints = '{"values":["lunch","dinner","both","none"]}'
 where key in ('meals.warm_meal.school_day', 'meals.warm_meal.free_day');

insert into app.setting_definition (key, scope, type, default_value, constraints, self_service, since_migration) values
  ('ambience.christmas',              'household', 'enum',         '"auto"',                          '{"values":["auto","on","off"]}',              false, '20261101110000'),
  ('ambience.st_nicholas',            'household', 'enum',         '"auto"',                          '{"values":["auto","on","off"]}',              false, '20261101110000'),
  ('ambience.national_day',           'household', 'enum',         '"auto"',                          '{"values":["auto","on","off"]}',              false, '20261101110000');
