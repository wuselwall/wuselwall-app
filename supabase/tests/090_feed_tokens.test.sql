begin;
select plan(41);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

-- Named things of the test: profiles and households (ids), devices (devs), auth users (users),
-- tokens as created (tok), events by name (ev) and the feed as the service role saw it (snap).
create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table devs (name text primary key, usr uuid, dev uuid, hh uuid, cls text);
grant all on devs to public;
create temp table users (name text primary key, usr uuid);
grant all on users to public;
create temp table tok (name text primary key, id uuid, token text);
grant all on tok to public;
create temp table ev (name text primary key, id uuid not null default gen_random_uuid());
grant all on ev to public;
create temp table snap (k text primary key, v jsonb);
grant all on snap to public;

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

-- An appointment or presence in household A, attended by the named members.
create function pg_temp.new_event(p_name text, p_kind text, p_state text, p_starts timestamptz,
  p_ends timestamptz, p_rrule text, p_deleted timestamptz, p_attendees text[]) returns void
language plpgsql as $$
declare
  v_hh uuid := (select id from ids where name = 'hh_a');
  v_id uuid;
begin
  insert into ev (name) values (p_name) returning id into v_id;
  insert into app.event (id, household_id, calendar_id, title, kind, presence_state, is_all_day,
                         starts_at, ends_at, timezone, rrule, uid, deleted_at)
  values (v_id, v_hh, (select id from app.calendar where household_id = v_hh), p_name, p_kind, p_state,
          false, p_starts, p_ends, 'Europe/Berlin', p_rrule, v_id::text || '@wuselwall.app', p_deleted);
  insert into app.event_attendee (event_id, profile_id, household_id)
    select v_id, p.id, v_hh from app.profile p
     where p.household_id = v_hh and p.display_name = any(p_attendees);
end $$;

-- ---- household A: Papa (guardian, personal phone), Lotta and Hanna (members) ------------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;
insert into app.profile (household_id, display_name, role)
  select (select id from ids where name = 'hh_a'), n, 'member' from (values ('Lotta'), ('Hanna')) v(n);
insert into ids select lower(p.display_name), p.id from app.profile p
 where p.household_id = (select id from ids where name = 'hh_a') and p.role = 'member';

insert into users values
  ('hanna', app.create_auth_user('hanna@example.org', 'longpassword1')),
  ('old', app.create_auth_user('old@example.org', 'longpassword1'));

insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (select id from ids where name = 'hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = (select id from ids where name = 'papa');
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (select id from ids where name = 'hh_a'), usr, 'Hanna-Phone', 'personal', 'adult', (select id from ids where name = 'hanna')
    from users where name = 'hanna';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id, revoked_at)
  select (select id from ids where name = 'hh_a'), usr, 'Old-Phone', 'personal', 'adult', (select id from ids where name = 'papa'), now()
    from users where name = 'old';

-- ---- household B, made by hand (setup closes after the first household) -----------------------
insert into app.household (name) values ('B');
insert into ids select 'hh_b', id from app.household where name = 'B';
insert into users values ('b', app.create_auth_user('b@example.org', 'longpassword1'));
insert into app.profile (household_id, display_name, role, auth_user_id)
  select (select id from ids where name = 'hh_b'), 'B', 'guardian', usr from users where name = 'b';
insert into ids select 'b_profile', p.id from app.profile p where p.display_name = 'B';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (select id from ids where name = 'hh_b'), u.usr, 'B-Phone', 'personal', 'adult', p.id
    from users u join app.profile p on p.auth_user_id = u.usr where u.name = 'b';

insert into devs
  select n, d.auth_user_id, d.id, d.household_id, 'personal'
    from (values ('papa', 'A-Phone'), ('hanna', 'Hanna-Phone'), ('old', 'Old-Phone'), ('b', 'B-Phone')) v(n, label)
    join app.device d on d.label = v.label;

-- ---- events of household A, made as the owner --------------------------------------------------
-- Appointments: a lesson-like one for Lotta, a whole-family day, a series, a recent cancellation.
-- Presence: Hanna's shift. Out of the window: far ahead, long over, cancelled long ago.
select pg_temp.new_event('presence', 'presence', 'working', now() + interval '1 day',
  now() + interval '1 day 8 hours', null, null, array['Hanna']);
select pg_temp.new_event('lotta', 'appointment', null, now() + interval '2 days',
  now() + interval '2 days 1 hour', null, null, array['Lotta']);
select pg_temp.new_event('far', 'appointment', null, now() + interval '500 days',
  now() + interval '500 days 1 hour', null, null, null);
select pg_temp.new_event('ancient', 'appointment', null, now() - interval '120 days',
  now() - interval '119 days 23 hours', null, null, null);
select pg_temp.new_event('deleted_recent', 'appointment', null, now() + interval '3 days',
  now() + interval '3 days 1 hour', null, now() - interval '10 days', array['Hanna']);
select pg_temp.new_event('deleted_old', 'appointment', null, now() + interval '4 days',
  now() + interval '4 days 1 hour', null, now() - interval '40 days', null);
select pg_temp.new_event('series', 'appointment', null, now() - interval '2 years',
  now() - interval '2 years' + interval '1 hour', 'FREQ=WEEKLY', null, array['Hanna']);
insert into ev (name) values ('family');
insert into app.event (id, household_id, calendar_id, title, kind, is_all_day, start_date, end_date, timezone, uid)
  select e.id, (select id from ids where name = 'hh_a'),
         (select id from app.calendar where household_id = (select id from ids where name = 'hh_a')),
         'family', 'appointment', true, current_date + 5, current_date + 5, 'Europe/Berlin',
         e.id::text || '@wuselwall.app'
    from ev e where e.name = 'family';

-- ---- Papa creates tokens -----------------------------------------------------------------------
reset role;
select pg_temp.act_as_dev('papa');

insert into tok (name, id, token)
  select 'oma', (r ->> 'id')::uuid, r ->> 'token' from (select api.feed_token_create(null, 'Oma', '{}'::jsonb) r) s;
insert into tok (name, id, token)
  select 'papa', (r ->> 'id')::uuid, r ->> 'token'
    from (select api.feed_token_create(null, 'Papa', '{"kinds":["appointment","presence"]}'::jsonb) r) s;
insert into tok (name, id, token)
  select 'lotta', (r ->> 'id')::uuid, r ->> 'token'
    from (select api.feed_token_create(null, 'Lotta only', jsonb_build_object(
            'profile_ids', jsonb_build_array((select id from ids where name = 'lotta')),
            'kinds', jsonb_build_array('appointment', 'presence'))) r) s;
insert into tok (name, id, token)
  select 'weg', (r ->> 'id')::uuid, r ->> 'token' from (select api.feed_token_create(null, 'Weg', '{}'::jsonb) r) s;

select is(length((select token from tok where name = 'oma')), 43, 'a token is 43 characters');
select ok((select token from tok where name = 'oma') ~ '^[A-Za-z0-9_-]{43}$', 'a token is base64url without padding');
select is((select filter from api.feed_tokens where id = (select id from tok where name = 'oma')),
  '{"profile_ids":[],"calendar_ids":[],"kinds":["appointment"],"school":"off","subscribed":false}'::jsonb,
  'an empty filter takes the defaults: appointments only, school off');
select is((select count(*)::int from api.feed_tokens), 4, 'the guardian lists every token of the household');
select throws_ok($$ select api.feed_token_create(null, 'Bad', '{"kinds":["sms"]}'::jsonb) $$,
  '22023', 'WW-CAL-004 feed filter invalid', 'an unknown kind raises WW-CAL-004');
select is(pg_temp.error_hint($$ select api.feed_token_create(null, 'Bad', '{"kinds":["sms"]}'::jsonb) $$),
  'feed_filter_invalid', 'an unknown kind is hinted feed_filter_invalid');
select throws_ok($$ select api.feed_token_create(null, 'Bad', '{"school":"all"}'::jsonb) $$,
  '22023', 'WW-CAL-004 feed filter invalid', 'an unknown school value is refused');
select throws_ok($$ select api.feed_token_create(null, 'Bad', jsonb_build_object('profile_ids',
  jsonb_build_array((select id from ids where name = 'b_profile')))) $$,
  '22023', 'WW-CAL-004 feed filter invalid', 'a member of another household is refused');
select lives_ok($$ select api.feed_token_revoke(null, (select id from tok where name = 'weg')) $$,
  'a guardian revokes a token');
select lives_ok($$ select api.feed_token_revoke(null, (select id from tok where name = 'weg')) $$,
  'revoking a revoked token is harmless');
select is((select revoked_at is not null from api.feed_tokens where id = (select id from tok where name = 'weg')),
  true, 'a revoked token is marked, not deleted');
select is(pg_temp.error_hint($$ select api.feed_token_revoke(null, gen_random_uuid()) $$),
  'feed_token_not_found', 'an unknown token cannot be revoked');

-- ---- Hanna, a member on her own phone ----------------------------------------------------------
reset role;
select pg_temp.act_as_dev('hanna');
select throws_ok($$ select api.feed_token_create(null, 'Mine', '{}'::jsonb) $$,
  '42501', 'guardian required', 'a member cannot create a feed token');
select is(pg_temp.error_hint($$ select api.feed_token_create(null, 'Mine', '{}'::jsonb) $$),
  'guardian_required', 'a member is refused with guardian_required');
select throws_ok($$ select api.feed_token_revoke(null, (select id from tok where name = 'oma')) $$,
  '42501', 'guardian required', 'a member cannot revoke a feed token');

-- ---- a revoked phone and another household -----------------------------------------------------
reset role;
select pg_temp.act_as_dev('old');
select is((select count(*)::int from api.feed_tokens), 0, 'a revoked phone lists no tokens');

reset role;
select pg_temp.act_as_dev('b');
select is((select count(*)::int from api.feed_tokens), 0, 'another household lists none of these tokens');
select throws_ok($$ select api.feed_token_revoke(null, (select id from tok where name = 'oma')) $$,
  'P0002', 'feed token not found', 'another household cannot revoke a token');

-- ---- anonymous and authenticated callers cannot run the feed -------------------------------------
reset role;
set local role anon;
select throws_ok('select count(*) from api.feed_tokens', '42501', 'permission denied for view feed_tokens',
  'anonymous callers cannot read feed tokens');
select throws_ok($$ select api.ics_feed('x') $$, '42501', 'permission denied for function ics_feed',
  'anonymous callers cannot run the feed');

reset role;
select pg_temp.act_as_dev('papa');
select throws_ok($$ select api.ics_feed('x') $$, '42501', 'permission denied for function ics_feed',
  'an authenticated guardian cannot run the feed');
select throws_ok('select token_hash from app.calendar_feed_token', '42501',
  'permission denied for table calendar_feed_token', 'authenticated callers cannot read token hashes');

-- ---- the feed, as the service role --------------------------------------------------------------
reset role;
set local role service_role;
insert into snap select 'oma', api.ics_feed((select token from tok where name = 'oma'));

select is(jsonb_array_length((select v from snap where k = 'oma') -> 'events'), 4,
  'the default feed holds appointments only: the lesson, the family day, the series and a recent cancellation');
select ok(not exists (select 1 from snap s, jsonb_array_elements(s.v -> 'events') e
                       where s.k = 'oma' and e ->> 'kind' = 'presence'),
  'presence stays out of the default feed');
select ok(exists (select 1 from snap s, jsonb_array_elements(s.v -> 'events') e
                   where s.k = 'oma' and e ->> 'title' = 'deleted_recent' and (e ->> 'deleted')::boolean),
  'a cancellation within 30 days is fed with deleted true');
select is((select v -> 'household' ->> 'name' from snap where k = 'oma'), 'A', 'the feed names the household');
select is((select v -> 'household' ->> 'locale' from snap where k = 'oma'), 'de-DE',
  'the feed carries the household locale for the renderer');
select is((select v -> 'attendees' ->> (select id::text from ids where name = 'lotta') from snap where k = 'oma'),
  'Lotta', 'attendee names travel with the feed');
select ok((select (v ->> 'revision')::bigint > 0 from snap where k = 'oma'), 'the feed carries a revision');
select is(jsonb_array_length(api.ics_feed((select token from tok where name = 'papa')) -> 'events'), 5,
  'presence and appointments both: the shift is fed too');
select is((select array_agg(e ->> 'title' order by e ->> 'title')
             from tok t, jsonb_array_elements(api.ics_feed(t.token) -> 'events') e
            where t.name = 'lotta'),
  array['family', 'lotta'], 'a member filter keeps that member and the whole-family events');
select ok(api.ics_feed('not-a-token') is null, 'an unknown token gets nothing');
select ok(api.ics_feed((select token from tok where name = 'weg')) is null, 'a revoked token gets nothing');
select ok(api.ics_feed((select token from tok where name = 'oma')) is not null, 'the same token fetches again');

-- ---- owner checks: counts, hashes, audit -------------------------------------------------------
reset role;
select is((select fetch_count from app.calendar_feed_token where id = (select id from tok where name = 'oma')), 2,
  'every fetch counts');
select ok((select last_fetched_at is not null from app.calendar_feed_token where id = (select id from tok where name = 'oma')),
  'a fetch records when it happened');
select is((select count(*)::int from app.calendar_feed_token
            where token_hash = encode(extensions.digest((select token from tok where name = 'oma'), 'sha256'), 'hex')), 1,
  'only the hash of a token is stored');
select is((select count(*)::int from app.calendar_feed_token
            where token_hash = (select token from tok where name = 'oma')), 0,
  'the token itself is not stored');
select is((select count(*)::int from information_schema.columns
            where table_schema = 'api' and table_name = 'feed_tokens' and column_name = 'token_hash'), 0,
  'the api view never exposes token_hash');
select ok(exists (select 1 from app.audit_log where entity_type = 'feed_token' and action = 'create'),
  'creating a token is audited');
select ok(exists (select 1 from app.audit_log where entity_type = 'feed_token' and action = 'revoke'),
  'revoking a token is audited');

select * from finish();
rollback;
