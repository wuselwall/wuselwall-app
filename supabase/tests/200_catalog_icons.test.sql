begin;
select plan(19);

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

-- The matching rules, as the migration owner (before the role switch).
select is(app.catalog_icon_for('milch'), 'milk', 'a whole word matches');
select is(app.catalog_icon_for('vollmilch'), 'milk', 'a German compound ends with a known word');
select is(app.catalog_icon_for('bio-milch'), 'milk', 'the last word after a hyphen counts');
select is(app.catalog_icon_for('vollkornbrot'), 'bread', 'compound: Vollkornbrot');
select is(app.catalog_icon_for('orangensaft'), 'juice', 'compound: Orangensaft is juice, not orange');
select is(app.catalog_icon_for('apfelsaft'), 'juice', 'compound: Apfelsaft is juice, not apple');
select is(app.catalog_icon_for('zahnpasta'), 'toothbrush', 'an exact match beats a suffix: Zahnpasta is not pasta');
select is(app.catalog_icon_for('milchreis'), 'rice', 'compound: Milchreis is rice');
select is(app.catalog_icon_for('basmatireis'), 'rice', 'compound: Basmatireis');
select is(app.catalog_icon_for('olive oil'), 'oil', 'the last word after a space counts');
select is(app.catalog_icon_for('orange juice'), 'juice', 'the last word wins over the first');
select is(app.catalog_icon_for('gummy bears'), 'candy', 'a whole multi-word name matches first');
select is(app.catalog_icon_for('erdnussbutter'), 'nuts', 'an exact match beats the suffix butter');
select is(app.catalog_icon_for('erdaepfel'), 'potato', 'Swiss-German potatoes');
select is(app.catalog_icon_for('freilandeier'), 'egg', 'compound: Freilandeier');
select is(app.catalog_icon_for('gaensebluemchen'), null::text, 'an unknown name has no key');

create temp table ctxa as
  select (r ->> 'household_id')::uuid hh, p.auth_user_id usr, d.id dev
  from a join app.profile p on p.id = (a.r ->> 'profile_id')::uuid join app.device d on d.profile_id = p.id;
grant all on ctxa to public;

select pg_temp.act_as((select usr from ctxa), jsonb_build_object(
  'household_id', (select hh from ctxa), 'device_id', (select dev from ctxa), 'device_class', 'personal'));

-- Integration: a purchase gives the catalogue item its picture.
select api.shopping_add_item(null, 'Milch');
select api.shopping_add_item(null, 'Gänseblümchen');
select api.shopping_toggle_item(null, (select id from api.shopping_items where name = 'Milch'));
select api.shopping_toggle_item(null, (select id from api.shopping_items where name = 'Gänseblümchen'));
select api.shopping_finish(null);

select is((select icon_key from api.shopping_catalog where name = 'Milch'), 'milk', 'a bought item gets its icon key');
select is((select icon_key from api.shopping_catalog where name = 'Gänseblümchen'), null::text, 'an unknown bought item has no icon key');

-- The matcher is internal: the app never calls it.
select is(has_function_privilege('authenticated', 'app.catalog_icon_for(text)', 'execute'), false, 'authenticated cannot call the matcher');

select * from finish();
rollback;
