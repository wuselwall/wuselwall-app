-- FR-7.12 Equipment reminders, the evening half (specs/15 "What to pack", specs/21 Notifications):
-- a member setting for the local "Für morgen einpacken" notification the app schedules on a
-- personal phone, from tomorrow's school days. Like the other notify.* settings it is computed and
-- shown by the phone alone; nothing is sent. JSON null switches it off.
--
-- The household setting school.equipment_hint (20261013120000) switches every equipment hint off,
-- this one included: the projection then carries no equipment (functions/_shared/school_data.ts).
-- Additive for api_version: one catalogue row; the previous app release simply does not show it.

insert into app.setting_definition (key, scope, type, default_value, constraints, self_service, since_migration) values
  ('notify.packing_reminder', 'member', 'time', '"19:00"', '{"nullable":true}', true, '20261016130000');
