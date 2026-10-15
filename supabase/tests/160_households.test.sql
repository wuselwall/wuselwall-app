begin;
select plan(56);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.enrol_attempt;
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values
  (encode(extensions.digest('founder-one', 'sha256'), 'hex')),
  (encode(extensions.digest('founder-two', 'sha256'), 'hex')),
  (encode(extensions.digest('founder-three', 'sha256'), 'hex'));

-- Accounts: an Auth user with a session each. Created as the test role (owner).
create temp table acc (name text primary key, uid uuid, sess uuid, sess2 uuid);
grant all on acc to public;
create function pg_temp.new_account(p_name text, p_email text, p_meta jsonb) returns void
language plpgsql as $$
declare v_uid uuid; v_sess uuid := gen_random_uuid(); v_sess2 uuid := gen_random_uuid();
begin
  v_uid := app.create_auth_user(p_email, 'longpassword1', p_meta);
  insert into auth.sessions (id, user_id, created_at, updated_at) values (v_sess, v_uid, now(), now());
  insert into auth.sessions (id, user_id, created_at, updated_at) values (v_sess2, v_uid, now(), now());
  insert into acc values (p_name, v_uid, v_sess, v_sess2);
end $$;

-- Claims of a signed-in account on its session, without a device (the caller keeps its role).
create function pg_temp.claims_of(p_name text) returns void language plpgsql as $$
declare r acc;
begin
  select * into r from acc where name = p_name;
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', r.uid, 'role', 'authenticated', 'session_id', r.sess)::text, true);
end $$;

-- Claims of a device: what the access-token hook would add.
create function pg_temp.as_device(p_user uuid, p_session uuid, p_household uuid, p_device uuid, p_class text)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'session_id', p_session,
    'household_id', p_household, 'device_id', p_device, 'device_class', p_class)::text, true);
end $$;

-- Act as the authenticated role with the account's claims (for RLS checks).
create function pg_temp.as_account(p_name text) returns void language plpgsql as $$
begin
  perform pg_temp.claims_of(p_name);
  perform set_config('role', 'authenticated', true);
end $$;

-- Rows visible in every api view to the current role; views the role may not read count 0.
create function pg_temp.visible_rows() returns bigint language plpgsql as $$
declare v record; n bigint := 0; c bigint;
begin
  for v in select cl.relname from pg_class cl join pg_namespace s on s.oid = cl.relnamespace
            where s.nspname = 'api' and cl.relkind = 'v' loop
    begin
      execute format('select count(*) from api.%I', v.relname) into c;
      n := n + c;
    exception when insufficient_privilege then null;
    end;
  end loop;
  return n;
end $$;

-- ---- a fresh account --------------------------------------------------------
select pg_temp.new_account('neu', 'neu@example.org', '{"full_name":"Daniel Huser"}'::jsonb);
select pg_temp.new_account('zwei', 'zwei@example.org', '{}'::jsonb);
select pg_temp.new_account('drei', 'drei@example.org', '{}'::jsonb);
select pg_temp.new_account('vier', 'vier@example.org', '{}'::jsonb);
select pg_temp.new_account('pruef', 'pruef@example.org', '{}'::jsonb);

select pg_temp.as_account('neu');
select is((api.my_account() ->> 'has_household')::boolean, false, 'a fresh account has no household');
select is(api.my_account() ->> 'household_creation', 'code', 'the instance starts in code mode');
select is(api.my_account() ->> 'given_name', 'Daniel', 'the given name is read from the account');
select is(api.my_account() ->> 'full_name', 'Daniel Huser', 'the full name is read from the account');
select is(pg_temp.visible_rows(), 0::bigint, 'a fresh account sees nothing in any api view');
select is((select count(*) from app.household), 0::bigint, 'a fresh account reads no household row');
select throws_ok($$ select * from app.instance_setting $$, '42501', 'permission denied for table instance_setting',
  'the instance settings are unreadable by authenticated');
reset role;
select is(has_table_privilege('authenticated', 'app.instance_setting', 'select'), false,
  'authenticated has no privilege on instance_setting');

set local role anon;
select throws_ok($$ select api.my_account() $$, '42501', 'permission denied for function my_account', 'anon cannot read the account');
select throws_ok($$ select api.household_create('H', 'D', '#7B3FE4', 'Europe/Berlin', 'de-DE', null, false, 'x') $$,
  '42501', 'permission denied for function household_create', 'anon cannot create a household');
reset role;

-- ---- input checks come first (raised, nothing written) ----------------------
select pg_temp.claims_of('neu');
select throws_ok($$ select api.household_create('  ', 'Daniel', '#7B3FE4', 'Europe/Berlin', 'de-DE', 'founder-one', false, 'x') $$,
  '22023', 'household name invalid', 'a blank family name is refused');
select throws_ok($$ select api.household_create('Huser', 'Daniel', 'red', 'Europe/Berlin', 'de-DE', 'founder-one', false, 'x') $$,
  '22023', 'colour invalid', 'a colour that is not hex is refused');
select throws_ok($$ select api.household_create('Huser', 'Daniel', '#7B3FE4', 'Mars/Olympus', 'de-DE', 'founder-one', false, 'x') $$,
  '22023', 'timezone invalid', 'an unknown time zone is refused');
select throws_ok($$ select api.household_create('Huser', 'Daniel', '#7B3FE4', 'Europe/Berlin', 'German', 'founder-one', false, 'x') $$,
  '22023', 'locale invalid', 'a malformed locale is refused');

-- ---- code mode: refusals are results and are logged --------------------------
select is((api.household_create('Huser', 'Daniel', '#7B3FE4', 'Europe/Berlin', 'de-DE', null, true, 'x') ->> 'reason'),
  'founder_code_required', 'code mode without a code is refused (a result)');
select is((api.household_create('Huser', 'Daniel', '#7B3FE4', 'Europe/Berlin', 'de-DE', 'nope', true, 'x') ->> 'reason'),
  'founder_code_invalid', 'a wrong founder code is refused (a result)');
select is((select count(*) from app.enrol_attempt where client_key = 'founder:unknown' and not success),
  1::bigint, 'the wrong code is logged as a failed attempt');

create temp table r1 as
  select api.household_create('Huser', 'Daniel', '#7B3FE4', 'Europe/Berlin', 'de-DE', 'FOUNDER-ONE', true, 'Daniels iPhone') as r;
grant all on r1 to public;
select is((select r ->> 'ok' from r1), 'true', 'a valid founder code (any case) creates the household');
select is((select consumed_by is not null from app.setup_token
            where token_hash = encode(extensions.digest('founder-one', 'sha256'), 'hex')),
  true, 'the founder code is consumed by the founder profile');
select throws_ok($$ select api.household_create('Zweites', 'Daniel', '#08737F', 'Europe/Berlin', 'de-DE', 'founder-two', false, 'x') $$,
  '42501', 'already in a household', 'a second household for the same account is refused');

-- ---- a second account: a used code, then a valid one without examples ---------
select pg_temp.claims_of('zwei');
select is((api.household_create('Zwei', 'Hans', '#08737F', 'Europe/Berlin', 'de-DE', 'founder-one', true, 'x') ->> 'reason'),
  'founder_code_invalid', 'a used founder code is refused');
create temp table r2 as
  select api.household_create('Zwei', 'Hans', '#08737F', 'Europe/Berlin', 'de-DE', 'founder-two', false, 'Hans iPhone') as r;
grant all on r2 to public;
select is((select r ->> 'ok' from r2), 'true', 'the second founder code creates the second household');

-- ---- rate limit: five failures per client, then refused even with a valid code ---
select pg_temp.claims_of('drei');
select is((api.household_create('Drei', 'Kai', '#C2255C', 'Europe/Berlin', 'de-DE', 'x1', false, 'x') ->> 'reason'), 'founder_code_invalid', 'failure 3 of 5 (the used code was 1 and 2)');
select is((api.household_create('Drei', 'Kai', '#C2255C', 'Europe/Berlin', 'de-DE', 'x2', false, 'x') ->> 'reason'), 'founder_code_invalid', 'failure 4 of 5');
select is((api.household_create('Drei', 'Kai', '#C2255C', 'Europe/Berlin', 'de-DE', 'x3', false, 'x') ->> 'reason'), 'founder_code_invalid', 'failure 5 of 5');
select is((api.household_create('Drei', 'Kai', '#C2255C', 'Europe/Berlin', 'de-DE', 'founder-three', false, 'x') ->> 'reason'),
  'rate_limited', 'after five failures a valid code is refused until the window passes');
select is((select consumed_at is null from app.setup_token
            where token_hash = encode(extensions.digest('founder-three', 'sha256'), 'hex')),
  true, 'a refused code is not consumed');

-- ---- open mode: no code needed --------------------------------------------------
update app.instance_setting set value = '"open"' where key = 'household_creation';
select pg_temp.as_account('vier');
select is(api.my_account() ->> 'household_creation', 'open', 'the account reports open mode');
reset role;
create temp table r4 as
  select api.household_create('Vier', 'Lena', '#1A4FA8', 'Europe/Berlin', 'de-DE', null, false, 'Lenas iPhone') as r;
grant all on r4 to public;
select is((select r ->> 'ok' from r4), 'true', 'open mode creates a household without a code');
update app.instance_setting set value = '"code"' where key = 'household_creation';

-- ---- what the founder's session gets ------------------------------------------
select is((select count(*)::int from app.device d join acc a on a.uid = d.auth_user_id
            where a.name = 'neu' and d.auth_session_id = a.sess and d.class = 'personal'),
  1, 'the founder session is registered as a personal device');
select is((select count(*)::int from app.profile p join app.household h on h.id = p.household_id
            where h.id = (select (r ->> 'household_id')::uuid from r1) and p.role = 'guardian' and p.kind = 'adult'),
  1, 'the founder is the household guardian (adult)');
select is((select created_by_profile_id from app.household where id = (select (r ->> 'household_id')::uuid from r1)),
  (select (r ->> 'profile_id')::uuid from r1), 'the household records its creator');
select is((app.custom_access_token_hook(jsonb_build_object(
  'user_id', (select uid from acc where name = 'neu'),
  'claims', jsonb_build_object('session_id', (select sess from acc where name = 'neu'))))
  -> 'claims' ->> 'household_id'),
  (select r ->> 'household_id' from r1), 'the access-token hook gives the household claims for that session');
select is((app.custom_access_token_hook(jsonb_build_object(
  'user_id', (select uid from acc where name = 'neu'),
  'claims', jsonb_build_object('session_id', (select sess2 from acc where name = 'neu'))))
  -> 'claims' ->> 'device_class'),
  null, 'another session of the same account gets no device claims');

-- ---- seeds ---------------------------------------------------------------------
select is((select count(*)::int from app.reward where household_id = (select (r ->> 'household_id')::uuid from r1)),
  3, 'examples on: three rewards');
select is((select count(*)::int from app.task_definition where household_id = (select (r ->> 'household_id')::uuid from r1)
            and title = 'Müll rausbringen'),
  1, 'examples on: the open bonus task (chores for children wait for the children)');
select is((select count(*)::int from app.reward where household_id = (select (r ->> 'household_id')::uuid from r2)),
  0, 'examples off: no rewards');
select is((select count(*)::int from app.task_definition where household_id = (select (r ->> 'household_id')::uuid from r2)),
  0, 'examples off: no tasks');

-- ---- the default shopping list and its categories ---------------------------
select is((select count(*)::int from app.shopping_list
            where household_id = (select (r ->> 'household_id')::uuid from r1) and is_default and name = 'Supermarkt'),
  1, 'the default list Supermarkt exists');
select is((select count(*)::int from app.shopping_category
            where household_id = (select (r ->> 'household_id')::uuid from r1)) > 0,
  true, 'the default list has its categories');

-- ---- H2: add members as the founder's personal device ----------------------------
select pg_temp.as_device((select uid from acc where name = 'neu'), (select sess from acc where name = 'neu'),
  (select (r ->> 'household_id')::uuid from r1), (select (r ->> 'device_id')::uuid from r1), 'personal');
create temp table added as
  select api.household_add_members(null, '[{"display_name":"Lotta","kind":"child"},{"display_name":"Hanna","kind":"child"},{"display_name":"Sabine","kind":"adult"}]'::jsonb) as r;
grant all on added to public;
select is(jsonb_array_length((select r from added)), 3, 'three rows are added');
select is((select count(distinct color)::int from app.profile where household_id = (select (r ->> 'household_id')::uuid from r1)),
  4, 'every member gets a different colour');
select is((select role || '/' || kind from app.profile where household_id = (select (r ->> 'household_id')::uuid from r1) and display_name = 'Lotta'),
  'member/child', 'a child is a member of kind child');
select is((select role || '/' || kind from app.profile where household_id = (select (r ->> 'household_id')::uuid from r1) and display_name = 'Sabine'),
  'guardian/adult', 'an adult is a guardian of kind adult');
select throws_ok($$ select api.household_add_members(null, '[{"display_name":"X","kind":"robot"}]') $$,
  '22023', 'kind invalid', 'an unknown kind is refused');
select throws_ok($$ select api.household_add_members(null, '[{"display_name":"","kind":"child"}]') $$,
  '22023', 'name invalid', 'an empty name is refused');
select throws_ok($$ select api.household_add_members(null, (select jsonb_agg(jsonb_build_object('display_name','P'||g,'kind','child')) from generate_series(1,13) g)) $$,
  '22023', 'between 1 and 12 members', 'at most twelve rows per call');

-- A child on a shared device cannot add members; a kiosk cannot at all.
create temp table devs as
  select (select app.create_auth_user('kids@devices.wuselwall.invalid', 'longpassword1', '{}'::jsonb)) as shared_user,
         (select app.create_auth_user('kiosk@devices.wuselwall.invalid', 'longpassword1', '{}'::jsonb)) as kiosk_user;
grant all on devs to public;
insert into app.device (household_id, auth_user_id, label, class, register)
  select (select (r ->> 'household_id')::uuid from r1), shared_user, 'Kinder-iPad', 'shared', 'kid' from devs;
insert into app.device (household_id, auth_user_id, label, class, register)
  select (select (r ->> 'household_id')::uuid from r1), kiosk_user, 'Wand', 'kiosk', 'kiosk' from devs;
create temp table devids as
  select (select id from app.device where label = 'Kinder-iPad') as shared_dev,
         (select id from app.device where label = 'Wand') as kiosk_dev,
         (select id from app.profile where display_name = 'Lotta' and household_id = (select (r ->> 'household_id')::uuid from r1)) as kid,
         (select id from app.profile where display_name = 'Daniel' and household_id = (select (r ->> 'household_id')::uuid from r1)) as guardian;
grant all on devids to public;

select pg_temp.as_device((select shared_user from devs), null, (select (r ->> 'household_id')::uuid from r1),
  (select shared_dev from devids), 'shared');
select throws_ok($$ select api.household_add_members((select kid from devids), '[{"display_name":"Y","kind":"child"}]') $$,
  '42501', 'guardian required', 'a child on a shared device cannot add members');

select pg_temp.as_device((select kiosk_user from devs), null, (select (r ->> 'household_id')::uuid from r1),
  (select kiosk_dev from devids), 'kiosk');
select throws_ok($$ select api.household_add_members((select guardian from devids), '[{"display_name":"Y","kind":"child"}]') $$,
  '42501', 'not allowed on a kiosk', 'a kiosk cannot add members');
update app.device set revoked_at = now() where id = (select kiosk_dev from devids);
select throws_ok($$ select api.household_add_members((select guardian from devids), '[{"display_name":"Y","kind":"child"}]') $$,
  '42501', 'device not usable', 'a revoked device cannot add members');

-- Another household's guardian writes into their own household only.
select pg_temp.as_device((select uid from acc where name = 'zwei'), (select sess from acc where name = 'zwei'),
  (select (r ->> 'household_id')::uuid from r2), (select (r ->> 'device_id')::uuid from r2), 'personal');
select lives_ok($$ select api.household_add_members(null, '[{"display_name":"Fremd","kind":"child"}]') $$,
  'the other household''s guardian can add members to their own household');
select is((select count(*)::int from app.profile where household_id = (select (r ->> 'household_id')::uuid from r1)),
  4, 'the other household''s call did not touch this household');

-- The examples' chores for children, once the children exist.
select pg_temp.as_device((select uid from acc where name = 'neu'), (select sess from acc where name = 'neu'),
  (select (r ->> 'household_id')::uuid from r1), (select (r ->> 'device_id')::uuid from r1), 'personal');
select lives_ok($$ select api.tasks_seed_starter(null) $$, 'the examples can be completed once children exist');
select is((select count(*)::int from app.task_definition where household_id = (select (r ->> 'household_id')::uuid from r1)
            and title = 'Tisch decken'),
  1, 'the child chores are added after the children');
reset role;

-- ---- catalogue: no anonymous access ------------------------------------------------
select is(has_function_privilege('anon', 'api.household_create(text, text, text, text, text, text, boolean, text)', 'execute'),
  false, 'anon cannot execute household_create');
select is(has_function_privilege('anon', 'api.my_account()', 'execute'), false, 'anon cannot execute my_account');

select * from finish();
rollback;
