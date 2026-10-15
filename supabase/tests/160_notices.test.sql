begin;
select plan(33);

-- In-app notices (specs/20 J2, J4): the join notice for guardians, the new-sign-in notice for the
-- same account's other personal devices, per-profile dismissal, ageing, and the perimeter.
-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;

create function pg_temp.id(p_name text) returns uuid language sql as $$
  select id from ids where name = p_name
$$;

-- Switches to the device's Auth user, as PostgREST would with its JWT.
create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- The hint of the error a statement raises, or 'no error'.
create function pg_temp.error_hint(p_sql text) returns text language plpgsql as $$
declare v_hint text;
begin
  execute p_sql;
  return 'no error';
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint;
  return v_hint;
end $$;

-- A device of a household, by name; the name is its label and the key of the devs table.
create function pg_temp.add_dev(p_name text, p_user text, p_hh text, p_profile text, p_class text,
  p_register text, p_revoked boolean default false) returns void language plpgsql as $$
declare
  v_id  uuid := gen_random_uuid();
  v_usr uuid := (select usr from users where name = p_user);
  v_hh  uuid := pg_temp.id(p_hh);
begin
  insert into app.device (id, household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  values (v_id, v_hh, v_usr, p_name, p_class, p_register, pg_temp.id(p_profile),
          case when p_revoked then now() end);
  insert into devs values (p_name, v_usr, v_id, v_hh, p_class);
end $$;

-- Notices as "kind:name" pairs, newest first.
create function pg_temp.keys(p_actor uuid) returns text language sql as $$
  select coalesce(string_agg(x ->> 'kind' || ':' || coalesce(x ->> 'name', ''), ',' order by x ->> 'at' desc), '')
    from jsonb_array_elements(api.notices(p_actor)) x
$$;
create function pg_temp.key_of(p_actor uuid, p_kind text) returns text language sql as $$
  select x ->> 'key' from jsonb_array_elements(api.notices(p_actor)) x where x ->> 'kind' = p_kind limit 1
$$;

-- ---- household A: Papa and Mama (guardians), Opa (member); household B: Bea ---------------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;
insert into users select 'papa', auth_user_id from app.profile where id = pg_temp.id('papa');
insert into users select n, app.create_auth_user(n || '@example.org', 'longpassword1')
  from unnest(array['bea', 'mama', 'opa', 'mama2', 'mama3', 'mama4', 'papa_old', 'ipad', 'kiosk']) n;

insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
with ins as (insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_b'), 'Bea', 'guardian', usr from users where name = 'bea' returning id)
insert into ids select 'bea', id from ins;

with ins as (insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_a'), 'Mama', 'guardian', usr from users where name = 'mama' returning id)
insert into ids select 'mama', id from ins;
with ins as (insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_a'), 'Opa', 'member', usr from users where name = 'opa' returning id)
insert into ids select 'opa', id from ins;

select pg_temp.add_dev('papa', 'papa', 'hh_a', 'papa', 'personal', 'adult');
select pg_temp.add_dev('bea', 'bea', 'hh_b', 'bea', 'personal', 'adult');
select pg_temp.add_dev('mama', 'mama', 'hh_a', 'mama', 'personal', 'adult');
select pg_temp.add_dev('opa', 'opa', 'hh_a', 'opa', 'personal', 'adult');
-- Mama's first phone is older than everything below.
update app.device set created_at = now() - interval '30 days' where label = 'mama';

-- ---- 1. A quiet household ---------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');
select is(pg_temp.keys(pg_temp.id('papa')), '', 'no notices in a quiet household');

-- ---- 2. Mama and Opa join (the audit rows invitation acceptance writes) ------------------------
reset role;
insert into app.audit_log (occurred_at, household_id, actor_profile_id, entity_type, entity_id, action, diff)
  values (now() - interval '2 hours', pg_temp.id('hh_a'), pg_temp.id('mama'), 'invitation', gen_random_uuid(),
          'accept', jsonb_build_object('inviter_profile_id', pg_temp.id('papa'))),
         (now() - interval '1 hour', pg_temp.id('hh_a'), pg_temp.id('opa'), 'invitation', gen_random_uuid(),
          'accept', jsonb_build_object('inviter_profile_id', pg_temp.id('papa'))),
         -- Too old: it ages out on its own.
         (now() - interval '15 days', pg_temp.id('hh_a'), pg_temp.id('opa'), 'invitation', gen_random_uuid(),
          'accept', null),
         -- Another household's join.
         (now() - interval '1 hour', pg_temp.id('hh_b'), pg_temp.id('bea'), 'invitation', gen_random_uuid(),
          'accept', null);

select pg_temp.act_as_dev('papa');
select is(pg_temp.keys(pg_temp.id('papa')), 'join:Opa,join:Mama',
  'a guardian gets one join notice per joiner, newest first, with the joiner''s name');
select is((api.notices(pg_temp.id('papa')) -> 0 ->> 'at') is not null, true, 'a notice carries its time');
select is(jsonb_array_length(api.notices(pg_temp.id('papa'))), 2, 'a join older than 14 days is gone');

select pg_temp.act_as_dev('mama');
select is(pg_temp.keys(pg_temp.id('mama')), 'join:Opa', 'the second guardian sees the other join, never her own');

select pg_temp.act_as_dev('opa');
select is(pg_temp.keys(pg_temp.id('opa')), '', 'a non-guardian member gets no join notice');

select pg_temp.act_as_dev('bea');
select is(pg_temp.keys(pg_temp.id('bea')), '', 'another household sees nothing of household A');

-- Shared and kiosk devices.
reset role;
select pg_temp.add_dev('ipad', 'ipad', 'hh_a', null, 'shared', 'kid');
select pg_temp.add_dev('kiosk', 'kiosk', 'hh_a', null, 'kiosk', 'kiosk');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.keys(pg_temp.id('papa')), '', 'on a shared device a guardian without the PIN step-up gets nothing');
reset role;
update app.device set guardian_verified_until = now() + interval '5 minutes' where label = 'ipad';
select pg_temp.act_as_dev('ipad');
select is(pg_temp.keys(pg_temp.id('papa')), 'join:Opa,join:Mama', 'with the step-up valid the guardian sees the join notices');
select is(pg_temp.keys(pg_temp.id('opa')), '', 'a member acting on a shared device gets nothing');
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.keys(pg_temp.id('papa')), '', 'a kiosk gets no notices');

-- ---- 3. Dismissal is per profile --------------------------------------------------------------
select pg_temp.act_as_dev('papa');
create temp table k as select pg_temp.key_of(pg_temp.id('papa'), 'join') as opa_key;
grant all on k to public;
select lives_ok(format($$ select api.notice_dismiss(%L, %L) $$, pg_temp.id('papa'), (select opa_key from k)),
  'a guardian dismisses a notice');
select is(pg_temp.keys(pg_temp.id('papa')), 'join:Mama', 'the dismissed notice is gone for Papa');
select lives_ok(format($$ select api.notice_dismiss(%L, %L) $$, pg_temp.id('papa'), (select opa_key from k)),
  'dismissing twice is harmless');
select pg_temp.act_as_dev('mama');
select is(pg_temp.keys(pg_temp.id('mama')), 'join:Opa', 'Mama still sees it: dismissal is per profile');
select is(pg_temp.error_hint(format($$ select api.notice_dismiss(%L, %L) $$, pg_temp.id('mama'), 'join:' || gen_random_uuid())),
  'notice_unknown', 'a notice that does not exist cannot be dismissed');
select is(pg_temp.error_hint(format($$ select api.notice_dismiss(%L, %L) $$, pg_temp.id('mama'), 'bogus')),
  'notice_unknown', 'a malformed key cannot be dismissed');
select pg_temp.act_as_dev('opa');
select is(pg_temp.error_hint(format($$ select api.notice_dismiss(%L, %L) $$, pg_temp.id('opa'), (select opa_key from k))),
  'notice_unknown', 'a member cannot dismiss a guardian notice');
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.error_hint(format($$ select api.notice_dismiss(%L, %L) $$, pg_temp.id('papa'), (select opa_key from k))),
  'kiosk_forbidden', 'a kiosk cannot dismiss');

reset role;
select is((select count(*)::int from app.audit_log where entity_type = 'notice' and action = 'dismiss'), 2,
  'each dismissal is audited (the repeat too)');

-- ---- 4. A new sign-in reaches the same account's other devices only ----------------------------
select pg_temp.add_dev('mama2', 'mama2', 'hh_a', 'mama', 'personal', 'adult');
select pg_temp.add_dev('mama3', 'mama3', 'hh_a', 'mama', 'personal', 'adult', true);
select pg_temp.add_dev('mama4', 'mama4', 'hh_a', 'mama', 'personal', 'adult');
update app.device set created_at = now() - interval '15 days' where label = 'mama4';

select pg_temp.act_as_dev('mama');
select is(pg_temp.keys(pg_temp.id('mama')), 'signin:mama2,join:Opa',
  'the old phone is told about the new one (not the revoked or the 15-day-old one)');
select pg_temp.act_as_dev('mama2');
select is(pg_temp.keys(pg_temp.id('mama')), 'join:Opa', 'the new phone is not told about itself or the older phones');
select pg_temp.act_as_dev('papa');
select is(pg_temp.keys(pg_temp.id('papa')), 'join:Mama', 'another account in the household gets no sign-in notice');
select pg_temp.act_as_dev('opa');
select is(pg_temp.keys(pg_temp.id('opa')), '', 'nor does a member');

select pg_temp.act_as_dev('mama');
select lives_ok(format($$ select api.notice_dismiss(%L, %L) $$, pg_temp.id('mama'), pg_temp.key_of(pg_temp.id('mama'), 'signin')),
  'the sign-in notice is dismissed');
select is(pg_temp.keys(pg_temp.id('mama')), 'join:Opa', 'and gone');

-- ---- 5. The perimeter -------------------------------------------------------------------------
select is((select count(*)::int from app.notice_dismissal), 2, 'a household reads its own dismissals through RLS');
select pg_temp.act_as_dev('bea');
select is((select count(*)::int from app.notice_dismissal), 0, 'another household reads none');
select throws_ok($$ insert into app.notice_dismissal (household_id, profile_id, notice_key) values (gen_random_uuid(), gen_random_uuid(), 'join:x') $$,
  '42501', null, 'authenticated cannot write the dismissal table');

reset role;
select pg_temp.add_dev('papa_old', 'papa_old', 'hh_a', 'papa', 'personal', 'adult', true);
select pg_temp.act_as_dev('papa_old');
select is(pg_temp.error_hint(format($$ select api.notices(%L) $$, pg_temp.id('papa'))), 'device_revoked',
  'a revoked device is refused');
select is(pg_temp.error_hint(format($$ select api.notice_dismiss(%L, %L) $$, pg_temp.id('papa'), 'join:x')), 'device_revoked',
  'a revoked device cannot dismiss');

reset role;
set local role anon;
select throws_ok($$ select api.notices(null) $$, '42501', null, 'anonymous cannot read notices');
select throws_ok($$ select api.notice_dismiss(null, 'join:x') $$, '42501', null, 'anonymous cannot dismiss');

select * from finish();
rollback;
