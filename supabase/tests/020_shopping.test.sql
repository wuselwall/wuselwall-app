begin;
select plan(11);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

create function pg_temp.act_as(p_sub uuid, p_claims jsonb) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_sub, 'role', 'authenticated') || p_claims)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- Two households, each with a guardian on a personal device.
create temp table a as select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'A', '#111111', '123456') r;
grant all on a to public;
insert into app.setup_token (token_hash) values (encode(extensions.digest('second', 'sha256'), 'hex'));
-- the setup guard allows a single household; create the second one by hand
insert into app.household (name) values ('B');
create temp table b as
  select h.id hh, app.create_auth_user('b@example.org', 'longpassword1') usr from app.household h where h.name = 'B';
insert into app.profile (household_id, display_name, role, auth_user_id) select hh, 'B', 'guardian', usr from b;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select b.hh, b.usr, 'B-Phone', 'personal', 'adult', (select id from app.profile where auth_user_id = b.usr) from b;
grant all on b to public;

insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (a.r ->> 'household_id')::uuid, p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
  from a join app.profile p on p.id = (a.r ->> 'profile_id')::uuid;
create temp table ctxa as
  select (r ->> 'household_id')::uuid hh, p.auth_user_id usr, d.id dev
  from a join app.profile p on p.id = (a.r ->> 'profile_id')::uuid join app.device d on d.profile_id = p.id;
grant all on ctxa to public;

select pg_temp.act_as((select usr from ctxa), jsonb_build_object(
  'household_id', (select hh from ctxa), 'device_id', (select dev from ctxa), 'device_class', 'personal'));

create temp table items as
  select api.shopping_add_item(null, '  Milch ', '2 l') m, api.shopping_add_item(null, 'Brot') br;
grant all on items to public;

select is((select count(*)::int from api.shopping_items), 2, 'items are listed');
select is((select name from api.shopping_items where id = (select m from items)), 'Milch', 'names are trimmed');
select throws_ok($$ select api.shopping_add_item(null, '   ') $$, '22023', 'name required', 'blank names are rejected');
select is(api.shopping_toggle_item(null, (select m from items)), true, 'toggle ticks an item');
select is((select checked_by from api.shopping_items where id = (select m from items)), (select (a.r ->> 'profile_id')::uuid from a), 'the ticker is recorded');
select is(api.shopping_toggle_item(null, (select m from items)), false, 'toggle again unticks');

select api.shopping_toggle_item(null, (select m from items));
select is(api.shopping_finish(null), '{"bought": 1, "carried_over": 1}'::jsonb, 'finish reports bought and carried-over');
select is((select name from api.shopping_items), 'Brot', 'unticked items carry over to the new list');

-- Another household sees nothing and cannot touch the item.
reset role;
select pg_temp.act_as((select usr from b), jsonb_build_object(
  'household_id', (select hh from b), 'device_id', (select id from app.device where auth_user_id = (select usr from b)), 'device_class', 'personal'));
select is((select count(*)::int from api.shopping_items), 0, 'other households see nothing (RLS)');
select throws_ok(
  format($$ select api.shopping_toggle_item(null, %L) $$, (select br from items)),
  'P0002', 'item not found', 'other households cannot toggle foreign items');

reset role;
select ok((select count(*) from app.audit_log where entity_type like 'shopping%') >= 6, 'writes are audited');

select * from finish();
rollback;
