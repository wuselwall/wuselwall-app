-- A minimal stand-in for the parts of Supabase the migrations touch, so they and the
-- pgTAP suites can run on a bare Postgres 15. Not a Supabase emulator.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
  if not exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then create role supabase_auth_admin nologin; end if;
end $$;
create schema extensions;
create extension pgcrypto with schema extensions;
create extension "uuid-ossp" with schema extensions;
grant usage on schema extensions to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;

create schema auth;
grant usage on schema auth to anon, authenticated, service_role, supabase_auth_admin;
create table auth.users (
  instance_id uuid, id uuid primary key, aud text, role text, email text,
  encrypted_password text, email_confirmed_at timestamptz, raw_app_meta_data jsonb,
  raw_user_meta_data jsonb, created_at timestamptz, updated_at timestamptz,
  confirmation_token text, recovery_token text, email_change_token_new text,
  email_change text, is_anonymous boolean default false, last_sign_in_at timestamptz,
  phone text, banned_until timestamptz, deleted_at timestamptz);
create table auth.identities (
  id uuid primary key, user_id uuid references auth.users on delete cascade,
  provider_id text, provider text, identity_data jsonb, created_at timestamptz,
  updated_at timestamptz, last_sign_in_at timestamptz, email text);
create table auth.sessions (
  id uuid primary key default gen_random_uuid(), user_id uuid references auth.users on delete cascade,
  aal text default 'aal1', created_at timestamptz default now(), updated_at timestamptz,
  not_after timestamptz);
create table auth.mfa_factors (
  id uuid primary key default gen_random_uuid(), user_id uuid references auth.users on delete cascade,
  friendly_name text, factor_type text, status text, created_at timestamptz default now(),
  updated_at timestamptz);
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim', true), ''),
                  nullif(current_setting('request.jwt.claims', true), ''))::jsonb $$;
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'))::uuid $$;
create function auth.role() returns text language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'))::text $$;
grant execute on function auth.jwt(), auth.uid(), auth.role() to anon, authenticated, service_role;

create schema realtime;
grant usage on schema realtime to anon, authenticated, service_role;
create table realtime.messages (
  id bigserial primary key, topic text, extension text, payload jsonb, event text,
  private boolean, inserted_at timestamptz default now());
alter table realtime.messages enable row level security;
grant select on realtime.messages to authenticated;
create function realtime.topic() returns text language sql stable as $$
  select nullif(current_setting('realtime.topic', true), '') $$;
create function realtime.send(payload jsonb, event text, topic text, private boolean default true)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into realtime.messages (topic, extension, payload, event, private)
  values (topic, 'broadcast', payload, event, private);
end $$;
