begin;
select plan(27);

-- api.shopping_apply, the offline outbox's endpoint (specs/07#offline, ADR-006).
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

-- Household A: a guardian's phone and a shared tablet; household B: one phone.
create temp table a as select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'A', '#111111', '123456') r;
create temp table ctx as
  select (r ->> 'household_id')::uuid hh, (r ->> 'profile_id')::uuid guardian, p.auth_user_id usr
    from a join app.profile p on p.id = (a.r ->> 'profile_id')::uuid;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select hh, usr, 'A-Phone', 'personal', 'adult', guardian from ctx;
insert into app.profile (household_id, display_name, role) select hh, 'Kind', 'member' from ctx;
alter table ctx add column phone uuid, add column kid uuid, add column tablet uuid, add column tablet_usr uuid;
update ctx set phone = (select id from app.device where label = 'A-Phone'),
               kid = (select id from app.profile where display_name = 'Kind'),
               tablet_usr = app.create_auth_user('tablet@example.org', 'longpassword1');
insert into app.device (household_id, auth_user_id, label, class, register)
  select hh, tablet_usr, 'A-Tablet', 'shared', 'kid' from ctx;
update ctx set tablet = (select id from app.device where label = 'A-Tablet');

insert into app.household (name) values ('B');
create temp table b as
  select h.id hh, app.create_auth_user('b@example.org', 'longpassword1') usr from app.household h where h.name = 'B';
insert into app.profile (household_id, display_name, role, auth_user_id) select hh, 'B', 'guardian', usr from b;
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select b.hh, b.usr, 'B-Phone', 'personal', 'adult', (select id from app.profile where auth_user_id = b.usr) from b;
alter table b add column dev uuid, add column prof uuid;
update b set dev = (select id from app.device where label = 'B-Phone'),
             prof = (select id from app.profile where auth_user_id = b.usr);

-- Client-generated ids, as the app's outbox would make them.
create temp table ids as select
  gen_random_uuid() milk, gen_random_uuid() milk2, gen_random_uuid() bread, gen_random_uuid() trip,
  gen_random_uuid() o1, gen_random_uuid() o2, gen_random_uuid() o3, gen_random_uuid() o4,
  gen_random_uuid() o5, gen_random_uuid() o6, gen_random_uuid() o7, gen_random_uuid() o8,
  gen_random_uuid() o9, gen_random_uuid() o10, gen_random_uuid() o11, gen_random_uuid() o12;
grant all on ctx, b, ids to public;

select pg_temp.act_as((select usr from ctx), jsonb_build_object(
  'household_id', (select hh from ctx), 'device_id', (select phone from ctx), 'device_class', 'personal'));

create temp table r1 as select api.shopping_apply(null, jsonb_build_array(
  jsonb_build_object('op_id', o1, 'kind', 'add', 'item_id', milk, 'name', 'Milch'),
  jsonb_build_object('op_id', o2, 'kind', 'add', 'item_id', bread, 'name', 'Brot'),
  jsonb_build_object('op_id', o3, 'kind', 'check', 'item_id', bread, 'checked', true)
)) r from ids;
grant all on r1 to public;

select is((select jsonb_agg(x ->> 'status') from r1, jsonb_array_elements(r -> 'results') x),
  '["applied", "applied", "applied"]', 'a batch applies its operations in order');
select is((select count(*)::int from api.shopping_items where id in (select milk from ids union select bread from ids)), 2,
  'new items keep the client''s ids');
select is((select checked from api.shopping_items where id = (select bread from ids)), true,
  'a later op can refer to an item created earlier in the batch');
select is((select jsonb_array_length(r -> 'items') from r1), 2, 'the result carries the authoritative open items');

-- The same batch again, as after a timeout whose response was lost.
create temp table r2 as select api.shopping_apply(null, jsonb_build_array(
  jsonb_build_object('op_id', o1, 'kind', 'add', 'item_id', milk, 'name', 'Milch'),
  jsonb_build_object('op_id', o2, 'kind', 'add', 'item_id', bread, 'name', 'Brot')
)) r from ids;
grant all on r2 to public;
select is((select jsonb_agg(x ->> 'status') from r2, jsonb_array_elements(r -> 'results') x),
  '["duplicate", "duplicate"]', 'a replayed op is recognised by its op_id');
select is((select count(*)::int from api.shopping_items), 2, 'a replay duplicates nothing');

-- Two people add the same item while offline: one entry, 2x, and both ids work.
select api.shopping_apply(null, jsonb_build_array(
  jsonb_build_object('op_id', o4, 'kind', 'add', 'item_id', milk2, 'name', 'MILCH'))) from ids;
select is((select count from api.shopping_items where id = (select milk from ids)), 2, 'an add of an open name merges into it');
select is((select count(*)::int from api.shopping_items where id = (select milk2 from ids)), 0, 'no second row is created');
select api.shopping_apply(null, jsonb_build_array(
  jsonb_build_object('op_id', o5, 'kind', 'count', 'item_id', milk2, 'delta', -1),
  jsonb_build_object('op_id', o6, 'kind', 'spec', 'item_id', milk2, 'text', 'Bio'))) from ids;
select is((select count || ' ' || quantity from api.shopping_items where id = (select milk from ids)), '1 Bio',
  'ops naming the merged id reach the surviving item');

-- One bad op rejects only itself.
create temp table r3 as select api.shopping_apply(null, jsonb_build_array(
  jsonb_build_object('op_id', o7, 'kind', 'category', 'item_id', milk, 'category_id', gen_random_uuid()),
  jsonb_build_object('op_id', o8, 'kind', 'teleport', 'item_id', milk),
  jsonb_build_object('op_id', o9, 'kind', 'check', 'item_id', milk, 'checked', true)
)) r from ids;
grant all on r3 to public;
select is((select jsonb_agg(x - 'op_id') from r3, jsonb_array_elements(r -> 'results') x),
  '[{"code": "category_not_found", "status": "rejected"}, {"code": "op_unknown", "status": "rejected"}, {"status": "applied"}]',
  'rejected ops carry their code; the rest of the batch still applies');
reset role;
select is((select status from app.shopping_op where op_id = (select o7 from ids)), 'rejected',
  'a rejected op is recorded, so it is not retried forever');
select pg_temp.act_as((select usr from ctx), jsonb_build_object(
  'household_id', (select hh from ctx), 'device_id', (select phone from ctx), 'device_class', 'personal'));

-- Ops on items that are gone are skipped: the tombstone wins.
select is((select api.shopping_apply(null, jsonb_build_array(
  jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'check', 'item_id', gen_random_uuid(), 'checked', true)
)) -> 'results' -> 0 ->> 'status'), 'skipped', 'an op on an unknown item is skipped');

-- Finishing with the client's trip id, once.
select api.shopping_apply(null, jsonb_build_array(
  jsonb_build_object('op_id', o10, 'kind', 'finish', 'trip_id', trip,
                     'list_id', (select id from api.shopping_lists where is_default)))) from ids;
select is((select item_count from api.shopping_trips where id = (select trip from ids)), 2, 'finish creates the trip under the client''s id');
select is((select count(*)::int from api.shopping_items), 0, 'ticked items left the list');
select is((select api.shopping_apply(null, jsonb_build_array(
  jsonb_build_object('op_id', o11, 'kind', 'finish', 'trip_id', trip))) -> 'results' -> 0 ->> 'status') from ids,
  'skipped', 'a second finish for the same trip is skipped');
select is((select api.shopping_apply(null, jsonb_build_array(
  jsonb_build_object('op_id', o12, 'kind', 'check', 'item_id', milk, 'checked', false))) -> 'results' -> 0 ->> 'status') from ids,
  'skipped', 'an op on a bought item is skipped');

select throws_ok($$ select api.shopping_apply(null, '[{"op_id": "nope", "kind": "add"}]') $$,
  '22023', 'invalid operations', 'a malformed op id rejects the batch');
select throws_ok($$ select api.shopping_apply(null, '{"kind": "add"}') $$,
  '22023', 'invalid operations', 'the operations must be an array');
select throws_ok($$ select * from app.shopping_op $$, '42501', null, 'the op log is not readable by clients');
select throws_ok($$ select * from app.shopping_item_alias $$, '42501', null, 'the alias table is not readable by clients');

-- The shared tablet: each op names its acting profile.
reset role;
select pg_temp.act_as((select tablet_usr from ctx), jsonb_build_object(
  'household_id', (select hh from ctx), 'device_id', (select tablet from ctx), 'device_class', 'shared'));
create temp table r4 as select api.shopping_apply((select kid from ctx), jsonb_build_array(
  jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'add', 'item_id', gen_random_uuid(), 'name', 'Äpfel', 'actor', (select kid from ctx)),
  jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'add', 'item_id', gen_random_uuid(), 'name', 'Saft', 'actor', (select prof from b))
)) r;
grant all on r4 to public;
select is((select added_by from api.shopping_items where name = 'Äpfel'), (select kid from ctx), 'the op''s actor is recorded');
select is((select r -> 'results' -> 1 ->> 'code' from r4), 'actor_invalid', 'a foreign acting profile rejects that op');
select throws_ok($$ select api.shopping_apply(null, '[]') $$, '22023', 'acting profile required',
  'a shared device names an actor for the batch');

-- Household B can neither see nor reach A's items, even knowing their ids.
reset role;
insert into app.shopping_item (id, list_id, household_id, name, folded_name)
  select gen_random_uuid(), (select id from app.shopping_list where household_id = ctx.hh and is_default), hh, 'Käse', 'kaese' from ctx;
select pg_temp.act_as((select usr from b), jsonb_build_object(
  'household_id', (select hh from b), 'device_id', (select dev from b), 'device_class', 'personal'));
create temp table r5 as select api.shopping_apply(null, jsonb_build_array(
  jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'check', 'checked', true,
                     'item_id', (select id from app.shopping_item where name = 'Käse')),
  jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'add', 'name', 'Käse',
                     'item_id', (select id from app.shopping_item where name = 'Käse'))
)) r;
grant all on r5 to public;
select is((select r -> 'results' -> 0 ->> 'status' from r5), 'skipped', 'a foreign item is invisible to another household');
select is((select r -> 'results' -> 1 ->> 'status' from r5), 'rejected', 'a foreign item id cannot be claimed');
select is((select jsonb_array_length(r -> 'items') from r5), 0, 'the result carries only the caller''s items');

-- A revoked device gets nothing.
reset role;
update app.device set revoked_at = now() where id = (select dev from b);
select pg_temp.act_as((select usr from b), jsonb_build_object(
  'household_id', (select hh from b), 'device_id', (select dev from b), 'device_class', 'personal'));
select throws_ok($$ select api.shopping_apply(null, '[]') $$, '42501', 'device not usable', 'a revoked device is refused');

select * from finish();
rollback;
