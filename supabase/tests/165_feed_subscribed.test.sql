begin;
select plan(20);

-- Start from an empty system, whatever the database already holds (all rolled back).
delete from app.household;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'));

-- Named things of the test: households and profiles (ids), tokens as created (tok), feeds (snap).
create temp table ids (name text primary key, id uuid);
grant all on ids to public;
create temp table tok (name text primary key, id uuid, token text);
grant all on tok to public;
create temp table snap (k text primary key, v jsonb);
grant all on snap to public;

-- Switches to Papa's personal phone, as PostgREST would with its JWT.
create function pg_temp.act_as_papa() returns void language plpgsql as $$
declare d app.device;
begin
  select * into d from app.device where label = 'A-Phone';
  perform set_config('request.jwt.claims', jsonb_build_object('sub', d.auth_user_id, 'role', 'authenticated',
    'household_id', d.household_id, 'device_id', d.id, 'device_class', 'personal')::text, true);
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

-- ---- household A: Papa (guardian), Lotta (child), Hanna (member) -------------------------------
create temp table sa as
  select api.setup_household('dev-setup', 'A', 'a@example.org', 'longpassword1', 'Papa', '#111111', '123456') r;
grant all on sa to public;
insert into ids select 'hh_a', (r ->> 'household_id')::uuid from sa;
insert into ids select 'papa', (r ->> 'profile_id')::uuid from sa;
insert into app.profile (household_id, display_name, role, kind)
  select (select id from ids where name = 'hh_a'), 'Lotta', 'member', 'child';
insert into app.profile (household_id, display_name, role, kind)
  select (select id from ids where name = 'hh_a'), 'Hanna', 'member', 'adult';
insert into ids select lower(p.display_name), p.id from app.profile p
 where p.household_id = (select id from ids where name = 'hh_a') and p.role = 'member';
insert into app.device (household_id, auth_user_id, label, class, register, profile_id)
  select (select id from ids where name = 'hh_a'), p.auth_user_id, 'A-Phone', 'personal', 'adult', p.id
    from app.profile p where p.id = (select id from ids where name = 'papa');

-- ---- imported calendars: whole family, Lotta's, Hanna's, and an inactive one ----------------
insert into app.external_calendar (id, household_id, name, url, colour_hex, member_ids, active)
  values ('11111111-1111-4111-8111-111111111111', (select id from ids where name = 'hh_a'), 'Müllabfuhr',
          'https://muell.example.org/feed.ics', '#2E7D32', '{}', true),
         ('22222222-2222-4222-8222-222222222222', (select id from ids where name = 'hh_a'), 'Fussball Lotta',
          'https://fc.example.org/lotta.ics', '#1565C0', array[(select id from ids where name = 'lotta')], true),
         ('33333333-3333-4333-8333-333333333333', (select id from ids where name = 'hh_a'), 'Chor Hanna',
          'https://chor.example.org/hanna.ics', '#8E24AA', array[(select id from ids where name = 'hanna')], true),
         ('44444444-4444-4444-8444-444444444444', (select id from ids where name = 'hh_a'), 'Alt',
          'https://alt.example.org/old.ics', '#616161', '{}', false);

insert into app.external_occurrence (calendar_id, household_id, uid, starts_at, ends_at, all_day, start_date,
                                     end_date, title, location)
  values ('11111111-1111-4111-8111-111111111111', (select id from ids where name = 'hh_a'), 'muell-1',
          null, null, true, current_date + 3, current_date + 3, 'Restmüll', null),
         ('22222222-2222-4222-8222-222222222222', (select id from ids where name = 'hh_a'), 'spiel-1',
          now() + interval '2 days', now() + interval '2 days 90 minutes', false, null, null, 'Spiel', 'Sportplatz'),
         ('33333333-3333-4333-8333-333333333333', (select id from ids where name = 'hh_a'), 'chor-1',
          now() + interval '3 days', now() + interval '3 days 1 hour', false, null, null, 'Chorprobe', null),
         ('44444444-4444-4444-8444-444444444444', (select id from ids where name = 'hh_a'), 'alt-1',
          now() + interval '4 days', now() + interval '4 days 1 hour', false, null, null, 'Alt-Termin', null);

-- ---- Papa creates tokens -----------------------------------------------------------------------
reset role;
select pg_temp.act_as_papa();

insert into tok (name, id, token)
  select 'oma', (r ->> 'id')::uuid, r ->> 'token' from (select api.feed_token_create(null, 'Oma', '{}'::jsonb) r) s;
insert into tok (name, id, token)
  select 'alles', (r ->> 'id')::uuid, r ->> 'token'
    from (select api.feed_token_create(null, 'Alles', '{"subscribed":true}'::jsonb) r) s;
insert into tok (name, id, token)
  select 'lotta', (r ->> 'id')::uuid, r ->> 'token'
    from (select api.feed_token_create(null, 'Lotta', jsonb_build_object(
            'profile_ids', jsonb_build_array((select id from ids where name = 'lotta')),
            'subscribed', true)) r) s;
insert into tok (name, id, token)
  select 'aus', (r ->> 'id')::uuid, r ->> 'token'
    from (select api.feed_token_create(null, 'Aus', '{"subscribed":false}'::jsonb) r) s;

select is((select filter ->> 'subscribed' from api.feed_tokens where id = (select id from tok where name = 'oma')),
  'false', 'a token without the key is not subscribed: the default is false');
select is((select filter -> 'subscribed' from api.feed_tokens where id = (select id from tok where name = 'alles')),
  'true'::jsonb, 'subscribed true is accepted and stored as a boolean');
select is((select filter -> 'subscribed' from api.feed_tokens where id = (select id from tok where name = 'aus')),
  'false'::jsonb, 'subscribed false is accepted');

select is(pg_temp.error_hint($$ select api.feed_token_create(null, 'Bad', '{"subscribed":"yes"}'::jsonb) $$),
  'feed_filter_invalid', 'a string is not a boolean');
select is(pg_temp.error_hint($$ select api.feed_token_create(null, 'Bad', '{"subscribed":1}'::jsonb) $$),
  'feed_filter_invalid', 'a number is not a boolean');
select is(pg_temp.error_hint($$ select api.feed_token_create(null, 'Bad', '{"subscribed":null}'::jsonb) $$),
  'feed_filter_invalid', 'null is not a boolean');
select throws_ok($$ select api.feed_token_create(null, 'Bad', '{"subscribed":["true"]}'::jsonb) $$,
  '22023', 'WW-CAL-004 feed filter invalid', 'an array is refused with WW-CAL-004');

-- ---- the feed, as the service role ---------------------------------------------------------------
reset role;
insert into snap select 'spiel_start', to_jsonb(starts_at) from app.external_occurrence where uid = 'spiel-1';
set local role service_role;
insert into snap select 'oma', api.ics_feed((select token from tok where name = 'oma'));
insert into snap select 'alles', api.ics_feed((select token from tok where name = 'alles'));
insert into snap select 'lotta', api.ics_feed((select token from tok where name = 'lotta'));

select ok(not ((select v from snap where k = 'oma') ? 'external'),
  'a token that is not subscribed has no external key');
select is((select array_agg(e ->> 'title' order by e ->> 'title')
             from snap s, jsonb_array_elements(s.v -> 'external') e where s.k = 'alles'),
  array['Chorprobe', 'Restmüll', 'Spiel']::text[],
  'a subscribed token carries every active calendar, the whole family and the members alike');
select is((select count(*)::int from snap s, jsonb_array_elements(s.v -> 'external') e
            where s.k = 'alles' and e ->> 'title' = 'Alt-Termin'), 0,
  'an inactive calendar is not in the feed');
select is((select array_agg(e ->> 'title' order by e ->> 'title')
             from snap s, jsonb_array_elements(s.v -> 'external') e where s.k = 'lotta'),
  array['Chorprobe', 'Restmüll', 'Spiel']::text[],
  'a token that names Lotta still gets every active calendar: the renderer applies the profile filter');
select is((select e -> 'member_ids' from snap s, jsonb_array_elements(s.v -> 'external') e
            where s.k = 'lotta' and e ->> 'title' = 'Spiel'),
  jsonb_build_array((select id::text from ids where name = 'lotta')),
  'each occurrence carries the member ids of its calendar');
select ok((select (e ->> 'uid_hash') ~ '^[0-9a-f]{64}$' and not (e ? 'uid')
             from snap s, jsonb_array_elements(s.v -> 'external') e
            where s.k = 'lotta' and e ->> 'title' = 'Spiel'),
  'the feed carries a SHA-256 of the occurrence UID, never the UID itself');
select is((select (e ->> 'starts_at')::timestamptz from snap s, jsonb_array_elements(s.v -> 'external') e
            where s.k = 'lotta' and e ->> 'title' = 'Spiel'),
  (select (v #>> '{}')::timestamptz from snap where k = 'spiel_start'), 'timed occurrences keep their instants');
select is((select e ->> 'start_date' from snap s, jsonb_array_elements(s.v -> 'external') e
            where s.k = 'lotta' and e ->> 'title' = 'Restmüll'),
  (current_date + 3)::text, 'all-day occurrences keep their dates');
select ok((select e ->> 'calendar_id' = '11111111-1111-4111-8111-111111111111' from snap s,
             jsonb_array_elements(s.v -> 'external') e where s.k = 'lotta' and e ->> 'title' = 'Restmüll'),
  'each occurrence names its calendar');
select ok(not (select e ? 'calendar_name' from snap s, jsonb_array_elements(s.v -> 'external') e
                where s.k = 'lotta' limit 1),
  'the calendar name is not exposed to the feed');
select ok(api.ics_feed('not-a-token') is null, 'an unknown token still gets nothing');

-- ---- what the owner sees in the token list ----------------------------------------------
reset role;
select is((select count(*)::int from app.calendar_feed_token where filter ->> 'subscribed' = 'true'), 2,
  'two tokens are subscribed: the owner sees both');

select is((select count(*)::int from api.feed_tokens where filter ->> 'subscribed' = 'false'), 2,
  'the other two tokens are not subscribed');

select * from finish();
rollback;
