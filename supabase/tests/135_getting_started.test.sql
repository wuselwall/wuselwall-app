begin;
select plan(47);

-- The getting-started card (specs/20): derived items, dismissal, restore, and the perimeter.
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

-- The card as "item:state" pairs in card order, for the actor given.
create function pg_temp.card(p_actor uuid) returns text language plpgsql as $$
declare v_text text;
begin
  select string_agg(x ->> 'item' || ':' || case when (x ->> 'done')::boolean then 'done' else 'open' end,
                    ',' order by o)
    into v_text
    from jsonb_array_elements(api.getting_started(p_actor)) with ordinality as t(x, o);
  return coalesce(v_text, '');
end $$;

-- A device of a household, by name; the name is the key of the devs table used by act_as_dev.
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

-- ---- household A: Papa (guardian with PIN, personal phone), Lotta (child) ----------------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;
with ins as (
  insert into app.profile (household_id, display_name, role)
    values (pg_temp.id('hh_a'), 'Lotta', 'member') returning id)
insert into ids select 'lotta', id from ins;

insert into users values
  ('papa', (select auth_user_id from app.profile where id = pg_temp.id('papa'))),
  ('ipad', app.create_auth_user('ipad@devices.invalid', 'x1234567890')),
  ('kiosk', app.create_auth_user('kiosk@devices.invalid', 'x1234567890')),
  ('mama', app.create_auth_user('mama@example.org', 'longpassword1')),
  ('old', app.create_auth_user('old@example.org', 'longpassword1')),
  ('b', app.create_auth_user('b@example.org', 'longpassword1'));

select pg_temp.add_dev('papa', 'papa', 'hh_a', 'papa', 'personal', 'adult');

-- ---- 1. A new household: the guardian sees the open items the data allows -----------------------
reset role;
select pg_temp.act_as_dev('papa');
select is(pg_temp.card(pg_temp.id('papa')),
  'invite_partner:open,connect_tablet:open,wall_display:open,subscribe_feed:open,school:open',
  'a new household: invite, tablet, wall, feed and school are open; set_pin is not shown yet');
select is(jsonb_array_length(api.getting_started(pg_temp.id('papa'))), 5,
  'the card holds five items for a household with a child and no tablet');
select is(api.getting_started(pg_temp.id('papa')) -> 0 ->> 'scope', 'household',
  'an item for the household has the household scope');

-- ---- 2. A shared tablet: connect_tablet done, set_pin shown and done for the PIN holder ---------
reset role;
select pg_temp.add_dev('ipad', 'ipad', 'hh_a', null, 'shared', 'kid');

select pg_temp.act_as_dev('ipad');
select is(pg_temp.card(pg_temp.id('lotta')), '',
  'a child acting on the tablet gets no card');
select is(pg_temp.card(pg_temp.id('papa')),
  'invite_partner:open,connect_tablet:done,wall_display:open,set_pin:done,subscribe_feed:open,school:open',
  'with a tablet: connect_tablet is done, set_pin appears and is done (Papa has a PIN)');
select is(api.getting_started(pg_temp.id('papa')) -> 3 ->> 'scope', 'profile',
  'set_pin has the profile scope');

-- ---- 3. A second guardian: invite_partner goes away, and an unpinned guardian sees set_pin open -
reset role;
with ins as (
  insert into app.profile (household_id, display_name, role, auth_user_id)
    select pg_temp.id('hh_a'), 'Mama', 'guardian', usr from users where name = 'mama'
    returning id)
insert into ids select 'mama', id from ins;

select pg_temp.act_as_dev('ipad');
select is(pg_temp.card(pg_temp.id('mama')),
  'connect_tablet:done,wall_display:open,set_pin:open,subscribe_feed:open,school:open',
  'a second guardian with an account: invite is no longer shown, Mama has no PIN yet');
select is(pg_temp.card(pg_temp.id('papa')),
  'connect_tablet:done,wall_display:open,set_pin:done,subscribe_feed:open,school:open',
  'Papa sees no invite once two guardians exist');

-- A guardian profile without an account does not count as a partner.
reset role;
insert into app.profile (household_id, display_name, role)
  values (pg_temp.id('hh_a'), 'Onkel', 'guardian');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.card(pg_temp.id('papa')),
  'connect_tablet:done,wall_display:open,set_pin:done,subscribe_feed:open,school:open',
  'a guardian without an account does not change the invite');

-- ---- 4. A kiosk: wall_display done; a kiosk itself gets no card ---------------------------------
reset role;
select pg_temp.add_dev('kiosk', 'kiosk', 'hh_a', null, 'kiosk', 'kiosk');

select pg_temp.act_as_dev('kiosk');
select is(pg_temp.card(pg_temp.id('papa')), '', 'a kiosk gets no card');

select pg_temp.act_as_dev('ipad');
select is(pg_temp.card(pg_temp.id('papa')),
  'connect_tablet:done,wall_display:done,set_pin:done,subscribe_feed:open,school:open',
  'with a kiosk: wall_display is done');

-- ---- 5. Feed token: a revoked token does not count ----------------------------------------------
reset role;
insert into app.calendar_feed_token (household_id, label, token_hash, revoked_at)
  values (pg_temp.id('hh_a'), 'Alt', encode(extensions.digest('feed-old', 'sha256'), 'hex'), now());
select pg_temp.act_as_dev('ipad');
select is(pg_temp.card(pg_temp.id('papa')),
  'connect_tablet:done,wall_display:done,set_pin:done,subscribe_feed:open,school:open',
  'a revoked feed token does not finish subscribe_feed');

reset role;
insert into app.calendar_feed_token (household_id, label, token_hash)
  values (pg_temp.id('hh_a'), 'Papa', encode(extensions.digest('feed-live', 'sha256'), 'hex'));
select pg_temp.act_as_dev('ipad');
select is(pg_temp.card(pg_temp.id('papa')),
  'connect_tablet:done,wall_display:done,set_pin:done,subscribe_feed:done,school:open',
  'a live feed token finishes subscribe_feed');

-- ---- 6. School: a school alone is not enough; a timetable finishes the item ---------------------
reset role;
with ins as (
  insert into app.school (household_id, name, timezone)
    values (pg_temp.id('hh_a'), 'Grundschule', 'Europe/Berlin') returning id)
insert into ids select 'school', id from ins;
with ins as (
  insert into app.school_term (household_id, school_id, name, starts_on, ends_on)
    values (pg_temp.id('hh_a'), pg_temp.id('school'), 'Herbst', date '2026-08-01', date '2026-12-31')
    returning id)
insert into ids select 'term', id from ins;
select pg_temp.act_as_dev('ipad');
select is(pg_temp.card(pg_temp.id('papa')),
  'connect_tablet:done,wall_display:done,set_pin:done,subscribe_feed:done,school:open',
  'a school without a timetable leaves school open');

reset role;
insert into app.timetable (household_id, profile_id, school_id, term_id, valid_from)
  values (pg_temp.id('hh_a'), pg_temp.id('lotta'), pg_temp.id('school'), pg_temp.id('term'), date '2026-08-01');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.card(pg_temp.id('papa')),
  'connect_tablet:done,wall_display:done,set_pin:done,subscribe_feed:done,school:done',
  'a school with a timetable finishes school');

-- A household without a child shows no school item.
reset role;
update app.profile set active = false where id = pg_temp.id('lotta');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.card(pg_temp.id('papa')),
  'wall_display:done,set_pin:done,subscribe_feed:done',
  'without an active child, connect_tablet and school are not shown');
reset role;
update app.profile set active = true where id = pg_temp.id('lotta');

-- ---- 7. Dismissal ----------------------------------------------------------------------------------
-- Papa's own PIN is set on the setup call, so set_pin is done for him; Mama has no PIN.
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format('select api.getting_started_dismiss(%L, %L)', pg_temp.id('papa'), 'school')),
  'no error', 'Papa dismisses school on his personal phone');
select is(pg_temp.card(pg_temp.id('papa')),
  'connect_tablet:done,wall_display:done,set_pin:done,subscribe_feed:done',
  'a household dismissal removes the item for Papa');

-- Mama on the shared tablet: a dismissal needs the PIN window (guardian required without it).
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format('select api.getting_started_dismiss(%L, %L)', pg_temp.id('mama'), 'set_pin')),
  'guardian_required', 'a guardian on the tablet without the PIN window cannot dismiss');

reset role;
update app.device set guardian_verified_until = now() + interval '15 minutes',
                      guardian_verified_profile = pg_temp.id('mama')
 where id = (select dev from devs where name = 'ipad');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.error_hint(format('select api.getting_started_dismiss(%L, %L)', pg_temp.id('mama'), 'set_pin')),
  'no error', 'with the PIN window Mama dismisses set_pin');
select is(pg_temp.card(pg_temp.id('mama')),
  'connect_tablet:done,wall_display:done,subscribe_feed:done',
  'Mama no longer sees set_pin, and Papa''s household dismissal of school hides it for her too');
select is(pg_temp.card(pg_temp.id('papa')),
  'connect_tablet:done,wall_display:done,set_pin:done,subscribe_feed:done',
  'Mama dismissing set_pin leaves Papa''s own set_pin alone');

select is(pg_temp.error_hint(format('select api.getting_started_dismiss(%L, %L)', pg_temp.id('mama'), 'nonsense')),
  'getting_started_item_unknown', 'an unknown item is refused with a stable hint');

select is(pg_temp.error_hint(format('select api.getting_started_dismiss(%L, %L)', pg_temp.id('lotta'), 'school')),
  'guardian_required', 'a child cannot dismiss anything');
select is(pg_temp.card(pg_temp.id('lotta')), '', 'a child gets no card, dismissed or not');

-- Papa restores: his household dismissals and his own go; Mama's set_pin dismissal stays.
select pg_temp.act_as_dev('papa');
select is(pg_temp.error_hint(format('select api.getting_started_restore(%L)', pg_temp.id('papa'))),
  'no error', 'Papa restores the card');
select is(pg_temp.card(pg_temp.id('papa')),
  'connect_tablet:done,wall_display:done,set_pin:done,subscribe_feed:done,school:done',
  'after restore Papa sees school again');
select pg_temp.act_as_dev('ipad');
select is(pg_temp.card(pg_temp.id('mama')),
  'connect_tablet:done,wall_display:done,subscribe_feed:done,school:done',
  'restore does not bring back Mama''s own dismissal of set_pin');

select is((select count(*)::int from app.getting_started_dismissal
            where household_id = pg_temp.id('hh_a')), 1,
  'one dismissal row is left: Mama''s set_pin');

-- Dismissing the same item twice keeps one row.
select pg_temp.act_as_dev('papa');
select api.getting_started_dismiss(pg_temp.id('papa'), 'school');
select api.getting_started_dismiss(pg_temp.id('papa'), 'school');
reset role;
select is((select count(*)::int from app.getting_started_dismissal
            where household_id = pg_temp.id('hh_a') and item = 'school'), 1,
  'a repeated dismissal is stored once');

-- Dismissing all open items empties the card.
select pg_temp.act_as_dev('papa');
select api.getting_started_restore(pg_temp.id('papa'));
select api.getting_started_dismiss(pg_temp.id('papa'), 'school');
select api.getting_started_dismiss(pg_temp.id('papa'), 'subscribe_feed');
select api.getting_started_dismiss(pg_temp.id('papa'), 'wall_display');
select api.getting_started_dismiss(pg_temp.id('papa'), 'connect_tablet');
select api.getting_started_dismiss(pg_temp.id('papa'), 'set_pin');
select is(pg_temp.card(pg_temp.id('papa')), '', 'dismissing every item empties the card');
select api.getting_started_restore(pg_temp.id('papa'));

-- ---- 8. Household B: isolated from A ---------------------------------------------------------------
reset role;
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
with ins as (
  insert into app.profile (household_id, display_name, role, auth_user_id)
    select pg_temp.id('hh_b'), 'B', 'guardian', usr from users where name = 'b'
    returning id)
insert into ids select 'b', id from ins;
select pg_temp.add_dev('b', 'b', 'hh_b', 'b', 'personal', 'adult');

select pg_temp.act_as_dev('b');
select is(pg_temp.card(pg_temp.id('b')), 'invite_partner:open,wall_display:open,subscribe_feed:open',
  'a household without children sees no tablet, PIN or school items');
select is(pg_temp.card(pg_temp.id('papa')), 'invite_partner:open,wall_display:open,subscribe_feed:open',
  'a personal device always acts as its own profile, never as another household''s');
reset role;
select pg_temp.act_as_dev('papa');
select is((select count(*)::int from app.getting_started_dismissal where household_id = pg_temp.id('hh_b')), 0,
  'A''s guardian sees no dismissals of B');

-- ---- 9. Revoked devices and the perimeter ----------------------------------------------------------
reset role;
select pg_temp.add_dev('old', 'old', 'hh_a', 'mama', 'personal', 'adult', true);
select pg_temp.act_as_dev('old');
select is(pg_temp.error_hint(format('select api.getting_started(%L)', pg_temp.id('mama'))),
  'device_revoked', 'a revoked device gets no card');
select is(pg_temp.error_hint(format('select api.getting_started_dismiss(%L, %L)', pg_temp.id('mama'), 'school')),
  'device_revoked', 'a revoked device cannot dismiss');
select is((select count(*)::int from app.getting_started_dismissal), 0,
  'a revoked device reads no dismissal rows');

select pg_temp.act_as_dev('papa');
select api.getting_started_dismiss(pg_temp.id('papa'), 'school');
select pg_temp.act_as_dev('b');
select is((select count(*)::int from app.getting_started_dismissal where household_id = pg_temp.id('hh_a')), 0,
  'B''s device reads no dismissal rows of A');

reset role;
select is(
  (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'app.getting_started_dismissal'::regclass),
  true, 'the dismissal table has RLS enabled and forced');
select is(has_table_privilege('anon', 'app.getting_started_dismissal', 'select'), false,
  'anon cannot read the dismissal table');
select is(has_table_privilege('authenticated', 'app.getting_started_dismissal', 'insert'), false,
  'authenticated cannot write the dismissal table directly');
select is(has_function_privilege('anon', 'api.getting_started(uuid)', 'execute'), false,
  'anon cannot execute api.getting_started');
select is(has_function_privilege('anon', 'api.getting_started_dismiss(uuid, text)', 'execute'), false,
  'anon cannot execute api.getting_started_dismiss');
select is(has_function_privilege('anon', 'api.getting_started_restore(uuid)', 'execute'), false,
  'anon cannot execute api.getting_started_restore');
select is(has_function_privilege('authenticated', 'app.getting_started_dismissed(uuid, uuid, text)', 'execute'), false,
  'authenticated cannot execute the internal dismissal check');

-- An audit row is written for each dismissal and restore.
select is((select count(*)::int from app.audit_log
            where household_id = pg_temp.id('hh_a') and entity_type = 'getting_started'
              and action = 'dismiss'), 10,
  'each dismissal writes an audit row');
select is((select count(*)::int from app.audit_log
            where household_id = pg_temp.id('hh_a') and entity_type = 'getting_started'
              and action = 'restore'), 3,
  'each restore writes an audit row');

select * from finish();
rollback;
