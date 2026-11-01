-- Claiming the server (specs/20 "Claiming the server", specs/10 §3).
--
-- Until now the setup key only guarded the founding of the family: anyone who knew the
-- server's address could create an account first, and the key was asked for last, on
-- "Neue Familie". Now the key comes first. While no household exists, Auth creates an
-- account only for an address that was announced with the key (api.setup_claim, anon,
-- rate-limited like founder-code guesses); the Before User Created hook refuses every other
-- sign-up. Once a household exists the hook lets every sign-up through, as invitations and
-- the second parent need. The claim also stands in for the key on "Neue Familie": the key
-- never travels through the app after the claim.
--
-- Additive for api_version: new columns, one new anon function, one hook; household_create
-- keeps its signature and still accepts a typed founder code.

-- ------------------------------------------------------------ the claim

-- The address that announced itself with this key, and when. Only the latest claim counts.
alter table app.setup_token
  add column claimed_email text,
  add column claimed_at    timestamptz;

-- A server is claimed once a household exists, deleted-but-waiting ones included: the same
-- rule `wuselwall setup-token` and scripts/remote-setup-token.sh apply.
create function app.server_claimed() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from app.household)
$$;
revoke execute on function app.server_claimed() from public, anon, authenticated;

-- The client as household_create sees it: the first forwarded address, or 'unknown'.
create function app.request_client_key() returns text
language sql stable set search_path = '' as $$
  select coalesce(nullif(split_part(coalesce(
           nullif(current_setting('request.headers', true), '')::json ->> 'x-forwarded-for', ''), ',', 1), ''),
         'unknown')
$$;
revoke execute on function app.request_client_key() from public, anon, authenticated;

-- 5 failures per client and 50 overall per 10 minutes, for founder codes and claims alike.
-- The overall limit keeps a guessing stranger from ever reaching a key: it also refuses
-- the honest founder for ten minutes.
create function app.founder_attempts_exceeded(p_client_key text) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select count(*) from app.founder_attempt
           where client_key = p_client_key and not success
             and attempted_at > now() - interval '10 minutes') >= 5
      or (select count(*) from app.founder_attempt
           where not success and attempted_at > now() - interval '10 minutes') >= 50
$$;
revoke execute on function app.founder_attempts_exceeded(text) from public, anon, authenticated;

-- S1 "Server einrichten": checks the key and, with an address, announces that address as
-- the one that will sign up. Without an address it only checks (a setup link opened on a
-- phone shows at once whether its key still counts). A claim with a new address replaces
-- the old one; a used key is refused. Reasons: key_required, email_invalid, rate_limited,
-- key_invalid, key_used.
create function api.setup_claim(p_key text, p_email text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_client text := app.request_client_key();
  v_email  text := nullif(lower(btrim(coalesce(p_email, ''))), '');
  v_token  app.setup_token;
begin
  if coalesce(btrim(p_key), '') = '' then
    return jsonb_build_object('ok', false, 'reason', 'key_required');
  end if;
  if v_email is not null and (v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or length(v_email) > 254) then
    return jsonb_build_object('ok', false, 'reason', 'email_invalid');
  end if;
  if app.founder_attempts_exceeded(v_client) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  select * into v_token from app.setup_token
   where token_hash = encode(extensions.digest(lower(btrim(p_key)), 'sha256'), 'hex')
   for update;
  if not found then
    insert into app.founder_attempt (client_key, success) values (v_client, false);
    return jsonb_build_object('ok', false, 'reason', 'key_invalid');
  end if;
  if v_token.consumed_at is not null then
    insert into app.founder_attempt (client_key, success) values (v_client, false);
    return jsonb_build_object('ok', false, 'reason', 'key_used');
  end if;
  if v_email is not null then
    update app.setup_token set claimed_email = v_email, claimed_at = now()
     where token_hash = v_token.token_hash;
  end if;
  return jsonb_build_object(
    'ok', true,
    'claimed', v_email is not null,
    'server_claimed', app.server_claimed(),
    'household_creation', app.household_creation_mode());
end $$;
revoke execute on function api.setup_claim(text, text) from public;
grant execute on function api.setup_claim(text, text) to anon, authenticated;

-- ------------------------------------------------------------ the gate

-- GoTrue's Before User Created hook (pg-functions://postgres/app/before_user_created_hook;
-- GoTrue 2.175 or newer, hosted projects included). An empty object lets the sign-up
-- through; an error object refuses it, and its message reaches the app as the error text.
-- Device users (tablets) are created by app.create_auth_user, not through GoTrue, so the
-- hook never sees them.
create function app.before_user_created_hook(event jsonb) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_email text := lower(btrim(coalesce(event -> 'user' ->> 'email', '')));
begin
  if app.server_claimed() or app.household_creation_mode() <> 'code' then
    return '{}'::jsonb;
  end if;
  if v_email <> '' and exists (
       select 1 from app.setup_token t
        where t.consumed_at is null and t.claimed_email = v_email
          and t.claimed_at > now() - interval '15 minutes') then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object('error', jsonb_build_object(
    'message', 'setup_key_required', 'http_code', 403));
end $$;
grant execute on function app.before_user_created_hook(jsonb) to supabase_auth_admin;
revoke execute on function app.before_user_created_hook(jsonb) from public, anon, authenticated;

-- ------------------------------------------------------------ household_create

-- As in 20261015104000_leave.sql, with one change: in `code` mode a missing founder code is
-- fine when the account's address claimed the key (api.setup_claim) within the last day.
-- A typed code is still checked as before, so an older app and a key typed on "Neue
-- Familie" keep working.
create or replace function api.household_create(
  p_name text, p_display_name text, p_color text, p_timezone text, p_locale text,
  p_founder_code text, p_seed_examples boolean, p_device_label text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user    uuid := auth.uid();
  v_session uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  v_key     text := app.request_client_key();
  v_mode    text := app.household_creation_mode();
  v_token   app.setup_token;
  v_hh      uuid;
  v_prof    uuid;
  v_dev     uuid;
  v_actor   app.actor_t;
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '42501', hint = 'auth_required';
  end if;
  if v_session is null or not exists (select 1 from auth.sessions where id = v_session and user_id = v_user) then
    raise exception 'no session' using errcode = '42501', hint = 'session_invalid';
  end if;
  -- Also refused for any device user (shared or kiosk tablets sign in as their own user), revoked or not.
  -- A phone row counts only while it is live: leaving a family revokes it.
  if exists (select 1 from app.profile where auth_user_id = v_user and active)
     or exists (select 1 from app.device where auth_user_id = v_user and (class <> 'personal' or revoked_at is null)) then
    raise exception 'already in a household' using errcode = '42501', hint = 'already_in_household';
  end if;

  if length(btrim(coalesce(p_name, ''))) not between 1 and 60 then
    raise exception 'household name invalid' using errcode = '22023', hint = 'household_name_invalid';
  end if;
  if length(btrim(coalesce(p_display_name, ''))) not between 1 and 40 then
    raise exception 'name invalid' using errcode = '22023', hint = 'name_invalid';
  end if;
  if coalesce(p_color, '') !~ '^#[0-9A-Fa-f]{6}$' then
    raise exception 'colour invalid' using errcode = '22023', hint = 'color_invalid';
  end if;
  if not exists (select 1 from pg_timezone_names where name = p_timezone) then
    raise exception 'timezone invalid' using errcode = '22023', hint = 'timezone_invalid';
  end if;
  if coalesce(p_locale, '') !~ '^[a-z]{2}(-[A-Z]{2})?$' then
    raise exception 'locale invalid' using errcode = '22023', hint = 'locale_invalid';
  end if;
  if length(btrim(coalesce(p_device_label, ''))) not between 1 and 60 then
    raise exception 'label required' using errcode = '22023', hint = 'label_invalid';
  end if;

  if v_mode = 'code' then
    if coalesce(btrim(p_founder_code), '') = '' then
      -- No code typed: the claim this account's address made before signing up stands in.
      select t.* into v_token from app.setup_token t
       where t.consumed_at is null
         and t.claimed_email = (select lower(u.email) from auth.users u where u.id = v_user)
         and t.claimed_at > now() - interval '24 hours'
       order by t.claimed_at desc limit 1
       for update;
      if not found then
        return jsonb_build_object('ok', false, 'reason', 'founder_code_required');
      end if;
    else
      -- The founder code. Only a guess counts against the client: a missing code is not one.
      if app.founder_attempts_exceeded(v_key) then
        return jsonb_build_object('ok', false, 'reason', 'rate_limited');
      end if;
      select * into v_token from app.setup_token
       where token_hash = encode(extensions.digest(lower(btrim(p_founder_code)), 'sha256'), 'hex')
         and consumed_at is null
       for update;
      if not found then
        insert into app.founder_attempt (client_key, success) values (v_key, false);
        return jsonb_build_object('ok', false, 'reason', 'founder_code_invalid');
      end if;
    end if;
  end if;

  insert into app.household (name, timezone, locale)
  values (btrim(p_name), p_timezone, p_locale) returning id into v_hh;
  insert into app.profile (household_id, display_name, color, role, kind, auth_user_id)
  values (v_hh, btrim(p_display_name), upper(p_color), 'guardian', 'adult', v_user)
  returning id into v_prof;
  update app.household set created_by_profile_id = v_prof where id = v_hh;
  insert into app.device (household_id, auth_user_id, auth_session_id, label, class, register, profile_id)
  values (v_hh, v_user, v_session, btrim(p_device_label), 'personal', 'adult', v_prof)
  returning id into v_dev;

  if v_mode = 'code' then
    update app.setup_token set consumed_at = now(), consumed_by = v_prof where token_hash = v_token.token_hash;
    insert into app.founder_attempt (client_key, success) values (v_key, true);
  end if;

  perform app.shopping_ensure_lists(v_hh);
  v_actor := row(v_hh, v_prof, 'guardian', v_dev, 'personal', 'ui', null::timestamptz, null::uuid)::app.actor_t;
  if coalesce(p_seed_examples, false) then
    perform app.tasks_seed_starter_for(v_actor);
  end if;
  perform app.audit(v_actor, 'household', v_hh, 'create',
                    jsonb_build_object('examples', coalesce(p_seed_examples, false), 'founder_code', v_mode = 'code'));
  perform app.audit(v_actor, 'device', v_dev, 'register_personal');
  return jsonb_build_object('ok', true, 'household_id', v_hh, 'profile_id', v_prof, 'device_id', v_dev);
end $$;

-- ------------------------------------------------------------ what the app is told

-- As in 20261026100000_mail_optional.sql, plus setup_claimed: whether this account's
-- address holds a live claim, so "Neue Familie" asks for no key.
create or replace function api.my_account() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'user_id',            u.id,
    'email',              u.email,
    -- A device user (a shared or kiosk tablet) has no profile but is not free to start one.
    -- A phone's own row counts only while it is live.
    'has_household',      (p.id is not null and p.deleted_at is null)
                          or exists (select 1 from app.device d where d.auth_user_id = u.id
                                      and (d.class <> 'personal' or d.revoked_at is null)),
    'household_id',       case when p.deleted_at is null then p.household_id end,
    -- The family's name, for the typed confirmation of a deletion.
    'household_name',     case when p.deleted_at is null then p.household_name end,
    'profile_id',         case when p.deleted_at is null then p.id end,
    'household_creation', app.household_creation_mode(),
    'setup_claimed',      exists (select 1 from app.setup_token t
                                   where t.consumed_at is null and t.claimed_email = lower(u.email)
                                     and t.claimed_at > now() - interval '24 hours'),
    'full_name', nullif(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')), ''),
    'given_name', coalesce(
      nullif(btrim(coalesce(u.raw_user_meta_data ->> 'given_name', '')), ''),
      nullif(split_part(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')), ' ', 1), '')),
    -- Why the caller cannot leave the family, for the app to say so before the attempt.
    'leave_blocked', case when p.id is not null and p.deleted_at is null and p.role = 'guardian'
                          and exists (select 1 from app.profile o where o.household_id = p.household_id
                                       and o.active and o.id <> p.id)
                          and not exists (select 1 from app.profile o where o.household_id = p.household_id
                                       and o.active and o.id <> p.id and o.role = 'guardian'
                                       and o.auth_user_id is not null)
                        then 'last_guardian' end,
    -- Invitations naming this account's proven email, never into a deleted family.
    'pending_invitations', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', i.id,
               'household_name', h.name,
               'inviter_first_name', nullif(split_part(btrim(coalesce(inv.display_name, '')), ' ', 1), ''),
               'profile_name', ip.display_name,
               'profile_color', ip.color,
               'role', i.role)
             order by i.created_at, i.id)
        from app.invitation i
        join app.household h on h.id = i.household_id and h.deleted_at is null
        join app.profile ip on ip.id = i.profile_id
        left join app.profile inv on inv.id = i.created_by_profile_id
       where i.email = app.proven_email(u.id)
         and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()
         and ip.active and ip.auth_user_id is null), '[]'::jsonb),
    'deleted_household', case when p.deleted_at is not null then jsonb_build_object(
      'id',         p.household_id,
      'name',       p.household_name,
      'deleted_at', p.deleted_at,
      'purge_after', p.deleted_at + app.household_retention(),
      'can_restore', p.role = 'guardian' and now() < p.deleted_at + app.household_retention())
    end)
    from auth.users u
    left join lateral (
      select pr.id, pr.household_id, pr.role, h.name as household_name, h.deleted_at
        from app.profile pr join app.household h on h.id = pr.household_id
       where pr.auth_user_id = u.id and pr.active
       order by (h.deleted_at is null) desc, pr.created_at limit 1) p on true
   where u.id = auth.uid()
$$;

-- The discovery document says whether the server has a family yet (`claimed`), so the app
-- shows the claim step before anyone types an address. No longer immutable: it reads
-- app.household, as its owner, since anon reads no app table.
create or replace function api.server_info()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'api_version', 1,
    'min_app_version', '1.0.0',
    'household_creation', 'token',
    'claimed', app.server_claimed(),
    'features', jsonb_build_array(
      'calendar', 'ics', 'calendar-import', 'school', 'tasks', 'meals', 'shopping', 'holidays',
      'lighter-day', 'event-templates', 'password-reset', 'claim'
    )
  );
$$;
