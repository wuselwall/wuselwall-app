begin;
select plan(88);

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

create function pg_temp.act_as_dev(p_name text) returns void language plpgsql as $$
declare d devs;
begin
  select * into d from devs where name = p_name;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.usr, 'role', 'authenticated',
    'household_id', d.hh, 'device_id', d.dev, 'device_class', d.cls)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- The hint a statement fails with, or null when it succeeds.
create function pg_temp.error_hint(p_sql text) returns text language plpgsql as $$
declare v_hint text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint;
  return v_hint;
end $$;

-- ---- household A: Papa (guardian, personal phone), Emma (child), Paul (adult member) ----------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#7B3FE4', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into app.profile (household_id, display_name, role, kind)
  select (r ->> 'household_id')::uuid, 'Emma', 'member', 'child' from sa;
insert into app.profile (household_id, display_name, role)
  select (r ->> 'household_id')::uuid, 'Paul', 'member' from sa;
insert into ids select lower(p.display_name), p.id from app.profile p where p.household_id = pg_temp.id('hh_a');

insert into users values
  ('ipad', app.create_auth_user('ipad@devices.invalid', 'x1234567890')),
  ('kiosk', app.create_auth_user('kiosk@devices.invalid', 'x1234567890')),
  ('old', app.create_auth_user('old@example.org', 'longpassword1'));

insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.id('hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = pg_temp.id('papa');
insert into app.device (household_id, auth_user_id, label, class, register)
  select pg_temp.id('hh_a'), usr, 'iPad', 'shared', 'kid' from users where name = 'ipad';
insert into app.device (household_id, auth_user_id, label, class, register)
  select pg_temp.id('hh_a'), usr, 'Kiosk', 'kiosk', 'kiosk' from users where name = 'kiosk';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  select pg_temp.id('hh_a'), usr, 'Old-Phone', 'personal', 'adult', pg_temp.id('papa'), now()
    from users where name = 'old';

insert into devs
  select 'papa', d.auth_user_id, d.id, d.household_id, 'personal' from app.device d where d.label = 'A-Phone'
  union all
  select 'ipad', u.usr, d.id, d.household_id, 'shared' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'ipad'
  union all
  select 'kiosk', u.usr, d.id, d.household_id, 'kiosk' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'kiosk'
  union all
  select 'old', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id where u.name = 'old';
insert into ids select 'dev_' || name, dev from devs;

-- ---- household B, made by hand -----------------------------------------------------------------
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into users select 'b', app.create_auth_user('b@example.org', 'longpassword1');
insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_b'), 'B', 'guardian', usr from users where name = 'b';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select pg_temp.id('hh_b'), u.usr, 'B-Phone', 'personal', 'adult', p.id
    from users u join app.profile p on p.auth_user_id = u.usr where u.name = 'b';
insert into devs
  select 'b', u.usr, d.id, d.household_id, 'personal' from app.device d join users u on u.usr = d.auth_user_id
   where u.name = 'b';

-- ================================================================ members: update
select pg_temp.act_as_dev('ipad');

select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, 'Pauli', '#08737f', null, 'dog') $q$,
  pg_temp.id('paul'), pg_temp.id('paul'))), null, 'a member changes their own name, colour and avatar');
select is((select display_name || ' ' || color || ' ' || avatar_key from api.members where id = pg_temp.id('paul')),
  'Pauli #08737F dog', 'the change is visible, the colour upper-cased');
select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, 'Emmi') $q$, pg_temp.id('paul'), pg_temp.id('emma'))),
  'guardian_required', 'a member cannot rename someone else');
select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, null, null, 'child') $q$, pg_temp.id('paul'), pg_temp.id('paul'))),
  'guardian_required', 'a member cannot change their own kind');
select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, '   ') $q$, pg_temp.id('paul'), pg_temp.id('paul'))),
  'name_invalid', 'a blank name is refused');
select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, null, 'red') $q$, pg_temp.id('paul'), pg_temp.id('paul'))),
  'color_invalid', 'a colour must be a hex triplet');
select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, null, null, null, 'Dog!') $q$, pg_temp.id('paul'), pg_temp.id('paul'))),
  'avatar_invalid', 'an avatar key is a plain key');
select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, null, null, null, '') $q$, pg_temp.id('paul'), pg_temp.id('paul'))),
  null, 'the empty key removes the avatar');
select is((select avatar_key from api.members where id = pg_temp.id('paul')), null, 'the avatar is gone, the initial shows');

select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($q$ select api.member_update(null, %L, 'Emilia', '#C2255C', 'adult') $q$, pg_temp.id('emma'))),
  null, 'a guardian edits anyone, kind included');
select is((select display_name || ' ' || kind from api.members where id = pg_temp.id('emma')), 'Emilia adult', 'the kind changed');
select is(pg_temp.error_hint(format($q$ select api.member_update(null, %L, null, null, 'child') $q$, pg_temp.id('emma'))),
  null, 'and back to a child');
select is(pg_temp.error_hint(format($q$ select api.member_update(null, %L, null, null, 'child') $q$, pg_temp.id('papa'))),
  'kind_adult_required', 'a guardian stays an adult');
select is(pg_temp.error_hint(format($q$ select api.member_update(null, %L, null, null, 'teen') $q$, pg_temp.id('emma'))),
  'kind_invalid', 'an unknown kind is refused');
select is(pg_temp.error_hint($q$ select api.member_update(null, gen_random_uuid(), 'X') $q$),
  'member_not_found', 'an unknown profile is not found');
select is((select count(*)::int from app.audit_log where entity_id = pg_temp.id('emma') and action = 'update'), 2,
  'every accepted edit is audited, refused ones are not');

-- ================================================================ members: reorder
select is((select array_agg(display_name order by sort_order, id) from api.members where household_id = pg_temp.id('hh_a')),
  array['Papa', 'Emilia', 'Pauli'], 'members start in the order they were created');
select is(pg_temp.error_hint(format($q$ select api.members_reorder(null, array[%L, %L]::uuid[]) $q$,
  pg_temp.id('paul'), pg_temp.id('emma'))), null, 'a guardian reorders with a partial list');
select is((select array_agg(display_name || ':' || sort_order order by sort_order, id) from api.members where household_id = pg_temp.id('hh_a')),
  array['Pauli:10', 'Emilia:20', 'Papa:30'], 'the named ones lead in steps of ten, the rest follow');
select is(pg_temp.error_hint(format($q$ select api.members_reorder(null, array[%L, %L]::uuid[]) $q$,
  pg_temp.id('paul'), pg_temp.id('paul'))), 'members_invalid', 'a duplicate is refused');
select is(pg_temp.error_hint($q$ select api.members_reorder(null, array[gen_random_uuid()]) $q$),
  'members_invalid', 'a foreign id is refused');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($q$ select api.members_reorder(%L, array[%L]::uuid[]) $q$, pg_temp.id('paul'), pg_temp.id('paul'))),
  'guardian_required', 'a member cannot reorder');

-- ================================================================ members: role
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($q$ select api.member_set_role(null, %L, 'guardian') $q$, pg_temp.id('emma'))),
  'role_child', 'a child cannot be a guardian');
select is(pg_temp.error_hint(format($q$ select api.member_set_role(null, %L, 'member') $q$, pg_temp.id('papa'))),
  'last_guardian', 'the last guardian with an account stays one');
select is(pg_temp.error_hint(format($q$ select api.member_set_role(null, %L, 'boss') $q$, pg_temp.id('paul'))),
  'role_invalid', 'an unknown role is refused');
select is(pg_temp.error_hint(format($q$ select api.member_set_role(null, %L, 'guardian') $q$, pg_temp.id('paul'))),
  null, 'an adult member becomes a guardian');
select is((select role from api.members where id = pg_temp.id('paul')), 'guardian', 'the role is visible');
-- Paul verified his PIN on the iPad; demoting him ends that window.
reset role;
update app.device set guardian_verified_until = now() + interval '1 hour', guardian_verified_profile = pg_temp.id('paul')
 where id = pg_temp.id('dev_ipad');
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($q$ select api.member_set_role(null, %L, 'member') $q$, pg_temp.id('paul'))),
  null, 'and back to a member (Paul has no account, so Papa is not the last)');
select is((select guardian_verified_until from app.device where id = pg_temp.id('dev_ipad')), null,
  'the demoted guardian''s PIN window has ended');
select is((select count(*)::int from app.audit_log where entity_id = pg_temp.id('paul') and action = 'set_role'), 2,
  'role changes are audited');

-- ================================================================ members: deactivate
-- An open invitation for Paul, withdrawn when he leaves the family.
reset role;
insert into app.invitation (household_id, profile_id, role, token_hash, code_hash, expires_at)
  values (pg_temp.id('hh_a'), pg_temp.id('paul'), 'member', 'tok', 'code', now() + interval '7 days');
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($q$ select api.member_deactivate(null, %L) $q$, pg_temp.id('papa'))),
  'member_self', 'a guardian cannot retire themself');
select is(pg_temp.error_hint(format($q$ select api.member_deactivate(null, %L) $q$, pg_temp.id('paul'))),
  null, 'a person without an account is retired');
select is((select active from api.members where id = pg_temp.id('paul')), false, 'the member is inactive');
select is((select revoked_at is not null from app.invitation where profile_id = pg_temp.id('paul')), true,
  'the open invitation is withdrawn');
select is(pg_temp.error_hint(format($q$ select api.member_deactivate(null, %L) $q$, pg_temp.id('paul'))),
  null, 'retiring twice is a no-op');
select is((select count(*)::int from app.audit_log where entity_id = pg_temp.id('paul') and action = 'deactivate'), 1,
  'the no-op is not audited again');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($q$ select api.member_update(%L, %L, 'Nope') $q$, pg_temp.id('paul'), pg_temp.id('paul'))),
  'actor_invalid', 'an inactive member cannot act on a shared device');
select is(pg_temp.error_hint(format($q$ select api.member_reactivate(%L, %L) $q$, pg_temp.id('emma'), pg_temp.id('paul'))),
  'guardian_required', 'a member cannot bring someone back');
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($q$ select api.member_reactivate(null, %L) $q$, pg_temp.id('paul'))),
  null, 'a guardian brings the person back');
select is((select active from api.members where id = pg_temp.id('paul')), true, 'the member is active again');
-- Papa's account: he would have to leave first (J6).
select pg_temp.act_as_dev('b');
select is(pg_temp.error_hint(format($q$ select api.member_deactivate(null, %L) $q$, pg_temp.id('emma'))),
  'member_not_found', 'another household''s guardian does not see the member');
reset role;
-- A second guardian with an account, so Papa can be demoted and the account rule can be shown.
insert into users select 'mama', app.create_auth_user('mama@example.org', 'longpassword1');
insert into app.profile (household_id, display_name, role, auth_user_id)
  select pg_temp.id('hh_a'), 'Mama', 'guardian', usr from users where name = 'mama';
insert into ids select 'mama', id from app.profile where display_name = 'Mama';
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($q$ select api.member_deactivate(null, %L) $q$, pg_temp.id('mama'))),
  'member_has_account', 'an adult with an account leaves instead');
select is(pg_temp.error_hint(format($q$ select api.member_set_role(null, %L, 'member') $q$, pg_temp.id('papa'))),
  null, 'with a second guardian with an account, the founder can step down');
select is(pg_temp.error_hint(format($q$ select api.member_set_role(null, %L, 'guardian') $q$, pg_temp.id('papa'))),
  'guardian_required', 'and is then no guardian any more');
reset role;
update app.profile set role = 'guardian' where id = pg_temp.id('papa');

-- ================================================================ household
select is(pg_temp.error_hint($q$ select api.household_update(null, ' Familie Huser ', 'Europe/Zurich', 'de-CH') $q$),
  null, 'a guardian renames the family and moves its zone');
select is((select name || ' ' || timezone || ' ' || locale from api.household where id = pg_temp.id('hh_a')), 'Familie Huser Europe/Zurich de-CH',
  'the row shows the trimmed name, the zone and the locale');
select is(pg_temp.error_hint($q$ select api.household_update(null, null, 'Mars/Olympus') $q$),
  'timezone_invalid', 'an unknown zone is refused');
select is(pg_temp.error_hint($q$ select api.household_update(null, '') $q$),
  'household_name_invalid', 'an empty name is refused');
select is(pg_temp.error_hint($q$ select api.household_update(null, null, null, 'german') $q$),
  'locale_invalid', 'a locale is a language tag');
select is(pg_temp.error_hint($q$ select api.household_update(null) $q$), null, 'nothing to change is fine');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($q$ select api.household_update(%L, 'X') $q$, pg_temp.id('emma'))),
  'guardian_required', 'a member cannot rename the family');

-- ================================================================ devices
select is(pg_temp.error_hint(format($q$ select api.device_rename(%L, %L, 'Kinder-iPad') $q$, pg_temp.id('emma'), pg_temp.id('dev_ipad'))),
  null, 'a device renames itself');
select is(pg_temp.error_hint(format($q$ select api.device_rename(%L, %L, 'Wand') $q$, pg_temp.id('emma'), pg_temp.id('dev_kiosk'))),
  'guardian_required', 'a member cannot rename another device');
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($q$ select api.device_rename(null, %L, ' Küchenwand ') $q$, pg_temp.id('dev_kiosk'))),
  null, 'a guardian renames any device');
select is((select array_agg(label order by label) from api.devices where id in (pg_temp.id('dev_ipad'), pg_temp.id('dev_kiosk'))),
  array['Kinder-iPad', 'Küchenwand'], 'both labels changed, trimmed');
select is(pg_temp.error_hint(format($q$ select api.device_rename(null, %L, '') $q$, pg_temp.id('dev_kiosk'))),
  'label_invalid', 'an empty label is refused');
select is(pg_temp.error_hint(format($q$ select api.device_rename(null, %L, 'Alt') $q$, pg_temp.id('dev_old'))),
  'device_not_found', 'a revoked device is not renamed');
select is(pg_temp.error_hint($q$ select api.device_rename(null, gen_random_uuid(), 'X') $q$),
  'device_not_found', 'an unknown device is not found');

-- ================================================================ shopping structure
select pg_temp.act_as_dev('papa');
create temp table lists as select api.shopping_list_create(null, 'Baumarkt', 'hardware') hw;
grant all on lists to public;
-- The default list exists only once the first write made it.
alter table lists add column def uuid;
update lists set def = (select id from api.shopping_lists where is_default);
select is(pg_temp.error_hint(format($q$ select api.shopping_list_update(null, %L, ' Baumarkt Nord ') $q$, (select hw from lists))),
  null, 'a list is renamed');
select is((select name from api.shopping_lists where id = (select hw from lists)), 'Baumarkt Nord', 'the name is trimmed');
select is(pg_temp.error_hint(format($q$ select api.shopping_list_update(null, %L, 'supermarkt') $q$, (select hw from lists))),
  'list_exists', 'a second list with the same name is refused');
select is(pg_temp.error_hint(format($q$ select api.shopping_list_delete(null, %L) $q$, (select def from lists))),
  'list_default', 'the default list cannot be deleted');

-- Categories: one added, renamed, moved to the front, one seeded one renamed.
create temp table cats as
  select api.shopping_category_save(null, (select hw from lists), null, 'Farbe') farbe,
         (select id from api.shopping_categories where list_id = (select hw from lists) and key = 'tools') tools;
grant all on cats to public;
select is((select array_agg(coalesce(name, key) order by sort_order) from api.shopping_categories where list_id = (select hw from lists)),
  array['tools', 'screws', 'electrical', 'garden', 'other', 'Farbe'], 'a new category joins at the end of the walk');
select is(pg_temp.error_hint(format($q$ select api.shopping_category_save(null, %L, %L, 'Werkzeug & Co') $q$,
  (select hw from lists), (select tools from cats))), null, 'a seeded category gets a name of its own');
select is((select key || ' ' || name from api.shopping_categories where id = (select tools from cats)), 'tools Werkzeug & Co',
  'the key stays, the name shows');
select is(pg_temp.error_hint(format($q$ select api.shopping_categories_reorder(null, %L, array[%L]::uuid[]) $q$,
  (select hw from lists), (select farbe from cats))), null, 'a partial order moves one to the front');
select is((select array_agg(coalesce(name, key) order by sort_order) from api.shopping_categories where list_id = (select hw from lists)),
  array['Farbe', 'Werkzeug & Co', 'screws', 'electrical', 'garden', 'other'], 'the rest keep their order behind it');
select is(pg_temp.error_hint(format($q$ select api.shopping_categories_reorder(null, %L, array[%L]::uuid[]) $q$,
  (select def from lists), (select farbe from cats))), 'categories_invalid', 'a category of another list is refused');

-- Items and a tile on the hardware list; the item is categorised, then its category goes.
create temp table hwitems as
  select api.shopping_add_item(null, 'Schrauben', null, (select hw from lists)) screws,
         api.shopping_add_item(null, 'Dübel', null, (select hw from lists)) plugs;
grant all on hwitems to public;
select api.shopping_set_category(null, (select screws from hwitems), (select farbe from cats));
select api.shopping_toggle_item(null, (select plugs from hwitems));
select api.shopping_finish(null, (select hw from lists));
select is((select count(*)::int from api.shopping_catalog where list_id = (select hw from lists)), 1, 'the trip taught one tile');
select is(pg_temp.error_hint(format($q$ select api.shopping_category_delete(null, %L) $q$, (select farbe from cats))),
  null, 'a guardian removes a category');
select is((select category_id from app.shopping_item where id = (select screws from hwitems)), null,
  'its items become uncategorised');

-- The tile: renamed, then forgotten; the history keeps its text.
create temp table tile as select id from api.shopping_catalog where list_id = (select hw from lists);
grant all on tile to public;
select is(pg_temp.error_hint(format($q$ select api.catalog_item_update(null, %L, 'Dübel 8 mm') $q$, (select id from tile))),
  null, 'a tile is renamed');
select is((select name || ' ' || folded_name from api.shopping_catalog where id = (select id from tile)), 'Dübel 8 mm duebel 8 mm',
  'the folded name follows');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format($q$ select api.catalog_item_delete(%L, %L) $q$, pg_temp.id('emma'), (select id from tile))),
  'guardian_required', 'a member cannot forget a tile');
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format($q$ select api.catalog_item_delete(null, %L) $q$, (select id from tile))),
  null, 'a guardian forgets a tile');
select is((select count(*)::int from api.shopping_catalog where list_id = (select hw from lists)), 0, 'the tile is gone');
select is((select name from api.shopping_trip_items where list_id = (select hw from lists)), 'Dübel',
  'the history keeps what was bought');

-- Deleting the list: its open item moves to the default list, its history goes.
select is(pg_temp.error_hint(format($q$ select api.shopping_list_delete(null, %L) $q$, (select hw from lists))),
  null, 'a guardian deletes a list');
select is((select list_id from app.shopping_item where id = (select screws from hwitems)), (select def from lists),
  'the open item moved to the default list');
select is((select count(*)::int from api.shopping_trips), 0, 'the list''s trips went with it');
select is((select count(*)::int from api.shopping_lists), 1, 'one list remains');

-- ================================================================ perimeter
select pg_temp.act_as_dev('kiosk');
select is(pg_temp.error_hint(format($q$ select api.shopping_list_update(%L, %L, 'X') $q$, pg_temp.id('papa'), (select def from lists))),
  'kiosk_forbidden', 'the wall does not change the structure');
select pg_temp.act_as_dev('old');
select is(pg_temp.error_hint(format($q$ select api.device_rename(null, %L, 'X') $q$, pg_temp.id('dev_ipad'))),
  'device_revoked', 'a revoked device changes nothing');
select pg_temp.act_as_dev('b');
select is(pg_temp.error_hint(format($q$ select api.shopping_list_update(null, %L, 'X') $q$, (select def from lists))),
  'list_not_found', 'another household''s list is not found');
select is(pg_temp.error_hint(format($q$ select api.device_rename(null, %L, 'X') $q$, pg_temp.id('dev_ipad'))),
  'device_not_found', 'another household''s device is not found');
reset role;
set local role anon;
select throws_ok(format($q$ select api.member_update(null, %L, 'X') $q$, pg_temp.id('emma')), '42501',
  'permission denied for function member_update', 'anon cannot edit a member');
select throws_ok($q$ select api.household_update(null, 'X') $q$, '42501',
  'permission denied for function household_update', 'anon cannot rename the family');
select throws_ok($q$ select api.shopping_list_delete(null, gen_random_uuid()) $q$, '42501',
  'permission denied for function shopping_list_delete', 'anon cannot delete a list');
reset role;

select * from finish();
rollback;
