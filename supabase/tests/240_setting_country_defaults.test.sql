begin;
select plan(17);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;

-- Switches to the device's Auth user, as PostgREST would with its JWT.
create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- The household-level row of api.settings for a key, as the acting device sees it.
create function pg_temp.row(p_key text) returns api.settings language sql as $$
  select * from api.settings where key = p_key and profile_id is null and device_id is null
$$;

create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (r ->> 'household_id')::uuid, p.auth_user_id, 'Papa-Phone', 'personal', 'adult', p.id
    from sa join app.profile p on p.id = (sa.r ->> 'profile_id')::uuid;
insert into devs
  select 'papa', p.auth_user_id, d.id, d.household_id, 'personal'
    from sa join app.profile p on p.household_id = (sa.r ->> 'household_id')::uuid
    join app.device d on d.profile_id = p.id;

-- ---- the table, as the owner ----------------------------------------------------------------
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'app.setting_country_default'::regclass),
  'the country defaults have RLS enabled and forced');
select is((select count(*)::int from app.setting_country_default c
            join app.setting_definition d on d.key = c.key
           where not app.setting_valid(d, c.value)),
  0, 'every country default satisfies its setting''s constraints');

-- ---- no region: the catalogue's default -----------------------------------------------------
select pg_temp.act_as_dev('papa');
select is((pg_temp.row('rituals.table_question.dinner')).value, '{"from":"17:30","to":"19:30"}'::jsonb,
  'without a region the dinner window is the catalogue default');
select ok((select count(*) > 0 from app.setting_country_default), 'a device reads the country defaults');

-- ---- Spain: both windows move ---------------------------------------------------------------
select lives_ok($$ select api.set_setting(null, 'household.region', '"ES-MD"'::jsonb) $$,
  'a guardian sets the region to Madrid');
select is((pg_temp.row('rituals.table_question.lunch')).value, '{"from":"13:30","to":"15:30"}'::jsonb,
  'in Spain the lunch window is 13:30-15:30');
select is((pg_temp.row('rituals.table_question.dinner')).value, '{"from":"20:00","to":"22:00"}'::jsonb,
  'in Spain the dinner window is 20:00-22:00');
select is((pg_temp.row('rituals.table_question.dinner')).default_value, '{"from":"20:00","to":"22:00"}'::jsonb,
  'the Spanish window is reported as the default');
select ok((pg_temp.row('rituals.table_question.dinner')).is_default, 'and the setting still counts as unchanged');
select is((pg_temp.row('rituals.table_question')).value, '"warm_meal"'::jsonb,
  'a setting without a country default keeps the catalogue default');

reset role;
select is(app.setting_value((select hh from devs where name = 'papa'), 'rituals.table_question.dinner'),
  '{"from":"20:00","to":"22:00"}'::jsonb, 'app.setting_value applies the country default');
select is(app.household_setting_value((select hh from devs where name = 'papa'), 'rituals.table_question.lunch'),
  '{"from":"13:30","to":"15:30"}'::jsonb, 'app.household_setting_value applies the country default');

-- ---- the family's own value wins, and a reset brings the country's back ---------------------
select pg_temp.act_as_dev('papa');
select lives_ok($$ select api.set_setting(null, 'rituals.table_question.dinner', '{"from":"19:00","to":"20:30"}'::jsonb) $$,
  'a guardian sets their own dinner window');
select is((pg_temp.row('rituals.table_question.dinner')).value, '{"from":"19:00","to":"20:30"}'::jsonb,
  'the family''s own window wins over the country''s');
select lives_ok($$ select api.reset_setting(null, 'rituals.table_question.dinner') $$, 'and resets it');
select is((pg_temp.row('rituals.table_question.dinner')).value, '{"from":"20:00","to":"22:00"}'::jsonb,
  'after the reset the Spanish window applies again');

-- ---- France: only dinner moves --------------------------------------------------------------
select api.set_setting(null, 'household.region', '"FR-IDF"'::jsonb);
select is(array[(pg_temp.row('rituals.table_question.lunch')).value, (pg_temp.row('rituals.table_question.dinner')).value],
  array['{"from":"11:30","to":"13:30"}'::jsonb, '{"from":"19:00","to":"21:00"}'::jsonb],
  'in France lunch keeps the catalogue window and dinner is 19:00-21:00');

select * from finish();
rollback;
