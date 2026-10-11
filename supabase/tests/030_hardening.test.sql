begin;
select plan(11);

delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create function pg_temp.act_as(p_sub uuid, p_claims jsonb) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_sub, 'role', 'authenticated') || p_claims)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- A guardian on a personal phone, a kid, and a shared iPad.
create temp table a as select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on a to public;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (a.r ->> 'household_id')::uuid, p.auth_user_id, 'Phone', 'personal', 'adult', p.id
    from a join app.profile p on p.id = (a.r ->> 'profile_id')::uuid;
insert into app.profile (household_id, display_name, role)
  select (a.r ->> 'household_id')::uuid, 'Kid', 'member' from a;
create temp table w as
  select (a.r ->> 'household_id')::uuid hh, (a.r ->> 'profile_id')::uuid guardian,
         (select id from app.profile where display_name = 'Kid') kid,
         (select auth_user_id from app.profile where id = (a.r ->> 'profile_id')::uuid) guser,
         (select id from app.device where label = 'Phone') phone
    from a;
grant all on w to public;
select app.create_auth_user('ipad@devices.invalid', 'x1234567890') into temp table ipad_user;
grant all on ipad_user to public;
insert into app.device (household_id, auth_user_id, label, class, register)
  select hh, (select * from ipad_user), 'iPad', 'shared', 'kid' from w;
create temp table ipad as select id, auth_user_id from app.device where label = 'iPad';
grant all on ipad to public;

select ok((select pin_hash from app.profile where id = (select guardian from w)) like '$2_$12$%', 'PINs are hashed at bcrypt cost 12');

-- On the shared iPad: the guardian verifies, but the window is hers alone.
select pg_temp.act_as((select auth_user_id from ipad), jsonb_build_object(
  'household_id', (select hh from w), 'device_id', (select id from ipad), 'device_class', 'shared'));
select is((api.guardian_verify_pin((select guardian from w), '123456')) ->> 'ok', 'true', 'the guardian verifies on the iPad');
select lives_ok(format($$ select api.devices_create_enrolment_code(%L, 'x', 'shared', 'kid') $$, (select guardian from w)),
  'the verified guardian can act');
reset role;
update app.device set guardian_verified_profile = (select kid from w) where id = (select id from ipad);
select pg_temp.act_as((select auth_user_id from ipad), jsonb_build_object(
  'household_id', (select hh from w), 'device_id', (select id from ipad), 'device_class', 'shared'));
select throws_ok(format($$ select api.devices_create_enrolment_code(%L, 'x', 'shared', 'kid') $$, (select guardian from w)),
  '42501', 'guardian required', 'a window recorded for another profile does not count');

-- A child keeps guessing (each failure past the third waits twice as long; jump to the tenth).
reset role;
update app.profile set pin_failures = 9, pin_locked_until = null where id = (select guardian from w);
select pg_temp.act_as((select auth_user_id from ipad), jsonb_build_object(
  'household_id', (select hh from w), 'device_id', (select id from ipad), 'device_class', 'shared'));
select api.guardian_verify_pin((select guardian from w), '000000');
select is((api.guardian_verify_pin((select guardian from w), '123456')) ->> 'reason', 'pin_locked', 'the tenth wrong PIN locks it for good');
select throws_ok($$ select api.guardian_set_pin((select guardian from w), '654321') $$, '42501', 'guardian required',
  'the shared iPad cannot reset the PIN');

-- Only the guardian's own phone can.
reset role;
select pg_temp.act_as((select guser from w), jsonb_build_object(
  'household_id', (select hh from w), 'device_id', (select phone from w), 'device_class', 'personal'));
select throws_ok($$ select api.guardian_set_pin(null, 'abc') $$, '22023', 'PIN must be 6 digits', 'the new PIN must be six digits');
select lives_ok($$ select api.guardian_set_pin(null, '654321') $$, 'the guardian resets the PIN on her phone');
reset role;
select is((select pin_failures from app.profile where id = (select guardian from w)), 0, 'the reset clears the lock');

-- app.fold must agree with core/text/fold.dart (test/core/fold_test.dart has the same cases).
select is(app.fold('Käse'), 'kaese', 'fold: umlauts');
select is(app.fold('Crème fraîche STRASSE Straße Öl'), 'creme fraiche strasse strasse oel', 'fold: accents, case and ß');

select * from finish();
rollback;
