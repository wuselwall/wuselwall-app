begin;
select plan(4);

-- The scheduled jobs do not see a deleted household (20261015105000_jobs_skip_deleted.sql).
delete from app.household;

insert into app.household (name) values ('Live'), ('Deleted');
update app.household set deleted_at = now() where name = 'Deleted';
insert into app.external_calendar (household_id, name, url, colour_hex)
  select id, 'Abfuhr', 'https://example.org/' || name || '.ics', '#336699' from app.household;

create temp table live as select id from app.household where name = 'Live';
grant select on live to public;

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;

select is((select count(*)::int from jsonb_array_elements(api.tasks_schedule_all())), 1,
  'tasks-nightly gets only the live household');
select is((select (e ->> 'household_id')::uuid from jsonb_array_elements(api.tasks_schedule_all()) e),
  (select id from live), 'and it is the live one');
select is((select count(*)::int from jsonb_array_elements(api.external_calendar_due(20))), 1,
  'calendar-import gets only the live household''s calendar');
select is((select e ->> 'url' from jsonb_array_elements(api.external_calendar_due(20)) e),
  'https://example.org/Live.ics', 'and it is the live one');

reset role;
select * from finish();
rollback;
