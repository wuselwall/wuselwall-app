begin;
select plan(7);

-- Leaving one family and joining another (specs/20 J2 and J6): the revoked phone of the old
-- family must not block the invitation, and the invitation shows up in my_account.
delete from app.household;
delete from app.setup_token;

create temp table pp (name text primary key, uid uuid, prof uuid, hh uuid, sid uuid, dev uuid);
create temp table res (r jsonb);
grant all on pp, res to public;

-- An adult with an account, a live session and a personal phone in household p_hh.
create function pg_temp.adult(p_name text, p_hh uuid, p_email text) returns void language plpgsql as $$
declare v_uid uuid; v_sid uuid := gen_random_uuid(); v_prof uuid; v_dev uuid;
begin
  v_uid := app.create_auth_user(p_email, 'longpassword1', '{}');
  -- Signed up with a mailed code, so the address counts as proven (20261026100000).
  update auth.users set confirmation_sent_at = now() where id = v_uid;
  insert into auth.sessions (id, user_id, created_at, updated_at) values (v_sid, v_uid, now(), now());
  insert into app.profile (household_id, display_name, color, role, kind, auth_user_id)
  values (p_hh, p_name, '#7B3FE4', 'guardian', 'adult', v_uid) returning id into v_prof;
  insert into app.device (household_id, auth_user_id, auth_session_id, label, class, register, profile_id)
  values (p_hh, v_uid, v_sid, p_name || 's Handy', 'personal', 'adult', v_prof) returning id into v_dev;
  insert into pp values (p_name, v_uid, v_prof, p_hh, v_sid, v_dev);
end $$;

-- Acts as the person's phone (with household claims) or, with p_bare, as the bare account.
create function pg_temp.act(p_name text, p_bare boolean default false) returns void language plpgsql as $$
declare p pp;
begin
  select * into p from pp where name = p_name;
  perform set_config('request.jwt.claims', case when p_bare
    then jsonb_build_object('sub', p.uid, 'role', 'authenticated', 'session_id', p.sid)
    else jsonb_build_object('sub', p.uid, 'role', 'authenticated', 'session_id', p.sid,
      'household_id', p.hh, 'device_id', p.dev, 'device_class', 'personal', 'profile_id', p.prof)
    end::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

insert into app.household (name) values ('Familie A'), ('Familie B');
select pg_temp.adult('Papa', (select id from app.household where name = 'Familie A'), 'papa@example.org');
select pg_temp.adult('Mama', (select id from app.household where name = 'Familie A'), 'mama@example.org');
select pg_temp.adult('Bea',  (select id from app.household where name = 'Familie B'), 'bea@example.org');

-- Mama leaves Familie A; her phone there is revoked.
select pg_temp.act('Mama');
select is((api.account_leave((select prof from pp where name = 'Mama')) ->> 'ok')::boolean, true,
  'a second guardian leaves her family');
reset role;
select ok((select revoked_at is not null from app.device where id = (select dev from pp where name = 'Mama')),
  'her phone in the old family is revoked');

-- Bea invites mama@example.org into Familie B.
select pg_temp.act('Bea');
insert into res select api.invitation_create((select prof from pp where name = 'Bea'), null, 'Mama', 'guardian',
  'mama@example.org');
reset role;
select ok((select r ? 'code' from res), 'Bea creates an invitation naming Mama''s address');

-- Mama, now without a family, sees it and accepts it on a fresh session.
update pp set sid = gen_random_uuid() where name = 'Mama';
insert into auth.sessions (id, user_id, created_at, updated_at)
  select sid, uid, now(), now() from pp where name = 'Mama';
select pg_temp.act('Mama', true);
select is((select jsonb_array_length(api.my_account() -> 'pending_invitations')), 1,
  'the invitation waits for her after leaving');
select is((api.my_account() -> 'pending_invitations' -> 0 ->> 'household_name'), 'Familie B',
  'it names the new family');
select is((api.invitation_accept((select r ->> 'code' from res), null, null, null, 'Mamas Handy') ->> 'ok')::boolean,
  true, 'the revoked phone of the old family does not block joining the new one');
reset role;
select is((select h.name from app.profile p join app.household h on h.id = p.household_id
            where p.auth_user_id = (select uid from pp where name = 'Mama') and p.active),
  'Familie B', 'she is now in Familie B');

select * from finish();
rollback;
