-- A lighter day (ADR-020, specs/21 "A lighter day"): the settings of Wusel (specs/25), the
-- colour, ambience and sound layer (specs/26) and the family rituals (specs/27).
--
-- Defaults that depend on who or where (a child or an adult, a wall or a phone, the country of
-- the household's region) are the enum value 'auto'; the app resolves it, so a household that
-- never touches a row keeps following the curated rule. Every ritual is on by default, because
-- the pilot's two weeks judge them and a default that is off cannot be judged.
--
-- Additive for api_version: catalogue rows only; the previous app release lists them under
-- Advanced with their key as the title and otherwise ignores them.

insert into app.setting_definition (key, scope, type, default_value, constraints, self_service, since_migration) values
  -- Wusel (specs/25 "Settings")
  ('member.wusel',                    'member',    'enum',         '"auto"',                          '{"values":["auto","lively","quiet","off"]}',  true,  '20261024100000'),
  ('member.wusel_outfit',             'member',    'enum',         '"none"',                          '{"values":["none","party","crown","wizard","wreath","sunglasses","scarf","headphones","bow"]}', true, '20261024100000'),
  ('device.wusel',                    'device',    'enum',         '"lively"',                        '{"values":["lively","quiet","off"]}',         false, '20261024100000'),
  -- Sound, the sky and burn-in (specs/26)
  ('device.sounds',                   'device',    'enum',         '"auto"',                          '{"values":["auto","on","off"]}',              false, '20261024100000'),
  ('device.sky',                      'device',    'boolean',      'true',                            '{}',                                          false, '20261024100000'),
  ('device.pixel_shift',              'device',    'enum',         '"auto"',                          '{"values":["auto","on","off"]}',              false, '20261024100000'),
  -- Occasions (specs/26 "Defaults per country"): one switch each; 'auto' follows the country.
  ('ambience.season',                 'household', 'boolean',      'true',                            '{}',                                          false, '20261024100000'),
  ('ambience.birthdays',              'household', 'boolean',      'true',                            '{}',                                          false, '20261024100000'),
  ('ambience.ferien',                 'household', 'boolean',      'true',                            '{}',                                          false, '20261024100000'),
  ('ambience.advent',                 'household', 'enum',         '"auto"',                          '{"values":["auto","on","off"]}',              false, '20261024100000'),
  ('ambience.easter_western',         'household', 'enum',         '"auto"',                          '{"values":["auto","on","off"]}',              false, '20261024100000'),
  ('ambience.easter_orthodox',        'household', 'enum',         '"auto"',                          '{"values":["auto","on","off"]}',              false, '20261024100000'),
  ('ambience.new_year',               'household', 'boolean',      'false',                           '{}',                                          false, '20261024100000'),
  -- Rituals (specs/27)
  ('rituals.countdown_days',          'household', 'integer',      '14',                              '{"min":7,"max":60}',                          false, '20261024100000'),
  ('rituals.countdown_return',        'household', 'boolean',      'true',                            '{}',                                          false, '20261024100000'),
  ('meals.wishes',                    'household', 'enum',         '"children"',                      '{"values":["children","everyone","off"]}',    false, '20261024100000'),
  ('meals.wishes_per_week',           'household', 'integer',      '1',                               '{"min":1,"max":3}',                           false, '20261024100000'),
  ('rituals.table_question',          'household', 'enum',         '"warm_meal"',                     '{"values":["warm_meal","main_meals","off"]}', false, '20261024100000'),
  ('rituals.table_question.lunch',    'household', 'time_range',   '{"from":"11:30","to":"13:30"}',   '{}',                                          false, '20261024100000'),
  ('rituals.table_question.dinner',   'household', 'time_range',   '{"from":"17:30","to":"19:30"}',   '{}',                                          false, '20261024100000'),
  ('rituals.table_question_deck',     'household', 'enum',         '"family"',                        '{"values":["family","older"]}',               false, '20261024100000'),
  ('rituals.week_review',             'household', 'weekday_time', '{"weekday":7,"time":"16:00"}',    '{"nullable":true}',                           false, '20261024100000');
