-- M1.2 Tasks and gamification backend (specs/06, specs/04 "Tasks & gamification", specs/21 tasks).
--
-- A definition is a template; an instance is one occurrence with state, and snapshots its title,
-- points and kind. Points are an append-only ledger: a balance is a sum, never a column. Every
-- write goes through one api function that starts with app.actor, writes an audit row and
-- broadcasts 'tasks'. The two system jobs (materialise and close day, called by Edge Functions
-- with the service role) have no acting profile, so they write no audit row.
--
-- Errors: WW-TSK-001 task invalid, 002 not yours (42501), 003 balance insufficient,
-- 004 reward out of stock, 005 not open. The hints are the stable names the app maps.

-- ------------------------------------------------------------------ tables

create table app.task_definition (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  title                 text not null check (length(btrim(title)) between 1 and 80),
  description           text check (description is null or length(description) <= 500),
  icon_key              text check (icon_key is null or length(icon_key) between 1 and 40),
  kind                  text not null check (kind in ('duty', 'bonus')),
  points                int not null check (points between 0 and 1000),
  rrule                 text check (rrule is null or length(rrule) between 1 and 300),
  starts_on             date not null default current_date,
  window_days           int not null default 1 check (window_days between 1 and 14),
  assignment            text not null check (assignment in ('fixed', 'rotating', 'open', 'each')),
  -- The pool. For 'open' an empty pool means anyone may claim the task.
  assignee_profile_ids  uuid[] not null default '{}',
  rotation_cursor       int not null default 0 check (rotation_cursor >= 0),
  requires_verification boolean not null default false,
  is_active             boolean not null default true,
  created_by_profile_id uuid references app.profile on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  check (case assignment
           when 'fixed' then cardinality(assignee_profile_ids) = 1
           when 'open' then true
           else cardinality(assignee_profile_ids) >= 1 end)
);
create index on app.task_definition (household_id);

create table app.task_instance (
  id                      uuid primary key default gen_random_uuid(),
  household_id            uuid not null references app.household on delete cascade,
  definition_id           uuid references app.task_definition on delete set null,
  title                   text not null check (length(btrim(title)) between 1 and 80),
  points                  int not null check (points between 0 and 1000),
  kind                    text not null check (kind in ('duty', 'bonus')),
  icon_key                text check (icon_key is null or length(icon_key) between 1 and 40),
  due_on                  date not null,
  opens_on                date not null,
  closes_on               date not null,
  check (opens_on <= closes_on and due_on <= closes_on),
  assigned_profile_id     uuid references app.profile on delete set null,
  status                  text not null default 'open'
                            check (status in ('open', 'done', 'verified', 'skipped', 'expired')),
  completion_count        int not null default 0 check (completion_count >= 0),
  completed_by_profile_id uuid references app.profile on delete set null,
  completed_at            timestamptz,
  verified_by_profile_id  uuid references app.profile on delete set null,
  verified_at             timestamptz,
  requires_verification   boolean not null default false,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);
create index on app.task_instance (household_id, due_on);
create index on app.task_instance (assigned_profile_id, status);
-- One instance per definition, day and assignee. NULLS NOT DISTINCT makes the unassigned (open)
-- instance unique as well. Ad-hoc tasks have no definition and sit outside the key: two of them
-- on one day with no assignee must both exist.
create unique index task_instance_key on app.task_instance (definition_id, due_on, assigned_profile_id)
  nulls not distinct where definition_id is not null;

-- Append-only. A task credit's source is '<instance>:<completion count>', so a retried request
-- can never credit twice; the unique key is the guarantee.
create table app.point_transaction (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  profile_id            uuid not null references app.profile,
  occurred_at           timestamptz not null default now(),
  amount                int not null check (amount <> 0),
  reason                text not null check (reason in ('task', 'redemption', 'adjustment', 'badge', 'bonus')),
  source_type           text not null,
  source_id             text not null,
  created_by_profile_id uuid references app.profile on delete set null,
  note                  text check (note is null or length(btrim(note)) between 1 and 300),
  unique (source_type, source_id)
);
create index on app.point_transaction (household_id);
create index on app.point_transaction (profile_id);

create table app.reward (
  id                uuid primary key default gen_random_uuid(),
  household_id      uuid not null references app.household on delete cascade,
  title             text not null check (length(btrim(title)) between 1 and 80),
  description       text check (description is null or length(description) <= 500),
  icon_key          text check (icon_key is null or length(icon_key) between 1 and 40),
  cost_points       int not null check (cost_points > 0),
  stock             int check (stock is null or stock >= 0),
  requires_approval boolean not null default true,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index on app.reward (household_id);

create table app.reward_redemption (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references app.household on delete cascade,
  reward_id             uuid not null references app.reward,
  profile_id            uuid not null references app.profile,
  cost_points           int not null check (cost_points > 0),
  status                text not null default 'requested'
                          check (status in ('requested', 'approved', 'declined', 'fulfilled')),
  requested_at          timestamptz not null default now(),
  decided_by_profile_id uuid references app.profile on delete set null,
  decided_at            timestamptz,
  note                  text check (note is null or length(btrim(note)) between 1 and 300)
);
create index on app.reward_redemption (household_id, status);
create index on app.reward_redemption (profile_id);

create table app.streak (
  id                 uuid primary key default gen_random_uuid(),
  household_id       uuid not null references app.household on delete cascade,
  profile_id         uuid not null references app.profile on delete cascade,
  definition_id      uuid not null references app.task_definition on delete cascade,
  current_length     int not null default 0 check (current_length >= 0),
  longest_length     int not null default 0 check (longest_length >= 0),
  last_completed_on  date,
  jokers_used        int not null default 0 check (jokers_used >= 0),
  jokers_month       date,
  unique (profile_id, definition_id),
  check (longest_length >= current_length)
);
create index on app.streak (household_id);

create table app.badge_definition (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references app.household on delete cascade,
  key          text not null check (key ~ '^[a-z0-9_]{1,40}$'),
  title        text not null check (length(btrim(title)) between 1 and 80),
  description  text check (description is null or length(description) <= 300),
  icon_key     text check (icon_key is null or length(icon_key) between 1 and 40),
  rule         jsonb not null check (jsonb_typeof(rule) = 'object'),
  unique (household_id, key)
);

create table app.badge_award (
  id                  uuid primary key default gen_random_uuid(),
  household_id        uuid not null references app.household on delete cascade,
  profile_id          uuid not null references app.profile on delete cascade,
  badge_definition_id uuid not null references app.badge_definition on delete cascade,
  awarded_at          timestamptz not null default now(),
  context             jsonb not null default '{}' check (jsonb_typeof(context) = 'object'),
  unique (profile_id, badge_definition_id)
);
create index on app.badge_award (household_id);

-- Makes the nightly close idempotent: a day is closed once.
create table app.tasks_day_closed (
  household_id uuid not null references app.household on delete cascade,
  day          date not null,
  closed_at    timestamptz not null default now(),
  primary key (household_id, day)
);

-- ------------------------------------------------------------------ RLS

alter table app.task_definition     enable row level security;
alter table app.task_instance       enable row level security;
alter table app.point_transaction   enable row level security;
alter table app.reward              enable row level security;
alter table app.reward_redemption   enable row level security;
alter table app.streak              enable row level security;
alter table app.badge_definition    enable row level security;
alter table app.badge_award         enable row level security;
alter table app.tasks_day_closed    enable row level security;
alter table app.task_definition     force row level security;
alter table app.task_instance       force row level security;
alter table app.point_transaction   force row level security;
alter table app.reward              force row level security;
alter table app.reward_redemption   force row level security;
alter table app.streak              force row level security;
alter table app.badge_definition    force row level security;
alter table app.badge_award         force row level security;
alter table app.tasks_day_closed    force row level security;

create policy task_definition_read on app.task_definition for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy task_instance_read on app.task_instance for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy point_transaction_read on app.point_transaction for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy reward_read on app.reward for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy reward_redemption_read on app.reward_redemption for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy streak_read on app.streak for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy badge_definition_read on app.badge_definition for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy badge_award_read on app.badge_award for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());

create policy owner_all on app.task_definition   to postgres using (true) with check (true);
create policy owner_all on app.task_instance     to postgres using (true) with check (true);
create policy owner_all on app.point_transaction to postgres using (true) with check (true);
create policy owner_all on app.reward            to postgres using (true) with check (true);
create policy owner_all on app.reward_redemption to postgres using (true) with check (true);
create policy owner_all on app.streak            to postgres using (true) with check (true);
create policy owner_all on app.badge_definition  to postgres using (true) with check (true);
create policy owner_all on app.badge_award       to postgres using (true) with check (true);
create policy owner_all on app.tasks_day_closed  to postgres using (true) with check (true);

-- No write grants: every change goes through the api functions below.
grant select on app.task_definition, app.task_instance, app.point_transaction, app.reward,
  app.reward_redemption, app.streak, app.badge_definition, app.badge_award to authenticated;
revoke all on app.tasks_day_closed from public, anon, authenticated;

-- The ledger is append-only. Updates are refused by the trigger below. Deletes are not trapped
-- by a trigger, on purpose: the owner's cascades from a household or profile delete must still
-- work, and a trigger on DELETE would stop them. Instead no role but the owner holds delete (the
-- revoke below), and the API has no delete path at all.
revoke all on app.point_transaction from public, anon, authenticated, service_role;
grant select on app.point_transaction to authenticated;

create function app.point_transaction_append_only() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'point ledger is append-only' using errcode = '42501', hint = 'ledger_append_only';
end $$;

create trigger point_transaction_append_only before update on app.point_transaction
  for each row execute function app.point_transaction_append_only();

-- ------------------------------------------------------------------ internals

-- True for the service role (the two system jobs). PostgREST sets the JWT claims per request.
create function app.is_service_role() returns boolean
language sql stable set search_path = '' as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '') = 'service_role'
$$;

-- The effective value of a setting: a member override (when a profile is named), else the
-- household's value, else the curated default (specs/21).
create function app.setting_value(p_household uuid, p_key text, p_profile uuid default null)
returns jsonb language sql stable set search_path = '' as $$
  select coalesce(
    (select s.value from app.household_setting s
      where s.household_id = p_household and s.key = p_key
        and s.profile_id = p_profile and s.device_id is null),
    (select s.value from app.household_setting s
      where s.household_id = p_household and s.key = p_key
        and s.profile_id is null and s.device_id is null),
    (select d.default_value from app.setting_definition d where d.key = p_key))
$$;

-- "Today" in the household's own time zone.
create function app.tasks_today(p_household uuid) returns date
language sql stable set search_path = '' as $$
  select (now() at time zone h.timezone)::date from app.household h where h.id = p_household
$$;

create function app.tasks_balance(p_profile uuid) returns int
language sql stable set search_path = '' as $$
  select coalesce(sum(t.amount), 0)::int from app.point_transaction t where t.profile_id = p_profile
$$;

-- The net points a task instance has been credited: its completions less its undos.
create function app.tasks_credited(p_instance uuid) returns int
language sql stable set search_path = '' as $$
  select coalesce(sum(t.amount), 0)::int from app.point_transaction t
   where t.source_type in ('task', 'task_undo') and t.source_id like p_instance::text || ':%'
$$;

-- A completed due day. It advances the chain only when it is later than the last one counted,
-- so a late tick of an earlier day does not count twice.
create function app.tasks_streak_complete(p_household uuid, p_profile uuid, p_definition uuid, p_due date)
returns void language plpgsql set search_path = '' as $$
declare s app.streak;
begin
  insert into app.streak (household_id, profile_id, definition_id)
  values (p_household, p_profile, p_definition)
  on conflict (profile_id, definition_id) do nothing;
  select * into s from app.streak where profile_id = p_profile and definition_id = p_definition for update;
  if s.last_completed_on is null or p_due > s.last_completed_on then
    update app.streak set current_length = s.current_length + 1,
           longest_length = greatest(s.longest_length, s.current_length + 1),
           last_completed_on = p_due
     where id = s.id;
  end if;
end $$;

-- A completion or a verified rejection is taken back: the chain steps back by one when this
-- due day was the one that advanced it, and the last completed day becomes the one before.
-- Jokers already spent stay spent.
create function app.tasks_streak_revert(p_profile uuid, p_definition uuid, p_due date, p_instance uuid)
returns void language plpgsql set search_path = '' as $$
begin
  update app.streak s set
         current_length = greatest(s.current_length - 1, 0),
         last_completed_on = (select max(i.due_on) from app.task_instance i
                               where i.assigned_profile_id = p_profile and i.definition_id = p_definition
                                 and i.status in ('done', 'verified') and i.id <> p_instance)
   where s.profile_id = p_profile and s.definition_id = p_definition and s.last_completed_on = p_due;
end $$;

-- A missed due day. A joker left for the month keeps the chain; otherwise it breaks. Skipped
-- instances never reach here: only expired (missed) ones do.
create function app.tasks_streak_miss(p_household uuid, p_profile uuid, p_definition uuid, p_due date)
returns void language plpgsql set search_path = '' as $$
declare
  s         app.streak;
  v_month   date := date_trunc('month', p_due::timestamp)::date;
  v_used    int;
  v_allowed int := (app.setting_value(p_household, 'tasks.jokers_per_month', p_profile) #>> '{}')::int;
begin
  insert into app.streak (household_id, profile_id, definition_id)
  values (p_household, p_profile, p_definition)
  on conflict (profile_id, definition_id) do nothing;
  select * into s from app.streak where profile_id = p_profile and definition_id = p_definition for update;
  -- A chain of zero has nothing to protect.
  if s.current_length = 0 then
    return;
  end if;
  v_used := case when s.jokers_month is distinct from v_month then 0 else s.jokers_used end;
  if v_used < v_allowed then
    update app.streak set jokers_used = v_used + 1, jokers_month = v_month where id = s.id;
  else
    update app.streak set current_length = 0, jokers_used = v_used, jokers_month = v_month where id = s.id;
  end if;
end $$;

-- Writes instances for one definition and one due day. Returns how many were new.
create function app.tasks_insert_instance(p_def app.task_definition, p_due date, p_who uuid)
returns int language plpgsql set search_path = '' as $$
declare v_rows int;
begin
  insert into app.task_instance (household_id, definition_id, title, points, kind, icon_key, due_on,
                                 opens_on, closes_on, assigned_profile_id, requires_verification)
  values (p_def.household_id, p_def.id, p_def.title, p_def.points, p_def.kind, p_def.icon_key, p_due,
          p_due, p_due + (p_def.window_days - 1), p_who, p_def.requires_verification)
  on conflict (definition_id, due_on, assigned_profile_id) where definition_id is not null
  do nothing;
  get diagnostics v_rows = row_count;
  return v_rows;
end $$;

-- The materialiser's state change. p_items is [{definition_id, due_on}]; the caller has already
-- applied the horizon. Ordered by due day, so a rotation moves on in calendar order.
create function app.tasks_materialise_rows(p_household uuid, p_items jsonb) returns int
language plpgsql set search_path = '' as $$
declare
  it     record;
  d      app.task_definition;
  v_pool uuid[];
  v_who  uuid;
  v_ins  int;
  v_n    int := 0;
begin
  for it in
    select t.definition_id, t.due_on from (
      select (x ->> 'definition_id')::uuid as definition_id, (x ->> 'due_on')::date as due_on
        from jsonb_array_elements(p_items) x) t
     where t.definition_id is not null and t.due_on is not null
     order by t.due_on, t.definition_id
  loop
    select * into d from app.task_definition
     where id = it.definition_id and household_id = p_household and is_active
     for update;
    continue when not found;

    -- The pool in its stored order, active members only.
    select coalesce(array_agg(p.id order by u.ord), '{}'::uuid[]) into v_pool
      from unnest(d.assignee_profile_ids) with ordinality as u(id, ord)
      join app.profile p on p.id = u.id and p.household_id = p_household and p.active;

    if d.assignment = 'open' then
      v_n := v_n + app.tasks_insert_instance(d, it.due_on, null);
    elsif d.assignment = 'rotating' then
      continue when cardinality(v_pool) = 0;
      -- A due day that already has an instance does not move the rotation on (a re-run is a no-op).
      continue when exists (select 1 from app.task_instance i
                             where i.definition_id = d.id and i.due_on = it.due_on);
      v_who := v_pool[(d.rotation_cursor % cardinality(v_pool)) + 1];
      v_ins := app.tasks_insert_instance(d, it.due_on, v_who);
      if v_ins = 1 then
        update app.task_definition set rotation_cursor = rotation_cursor + 1 where id = d.id;
        v_n := v_n + 1;
      end if;
    elsif d.assignment = 'each' then
      foreach v_who in array v_pool loop
        v_n := v_n + app.tasks_insert_instance(d, it.due_on, v_who);
      end loop;
    else
      -- fixed
      continue when cardinality(v_pool) = 0;
      v_n := v_n + app.tasks_insert_instance(d, it.due_on, v_pool[1]);
    end if;
  end loop;
  return v_n;
end $$;

-- The schedule of one household, as the Edge Functions expand it.
create function app.tasks_schedule_of(p_household uuid) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'household_id', h.id,
    'timezone', h.timezone,
    'today', to_char(app.tasks_today(h.id)::timestamp, 'YYYY-MM-DD'),
    'definitions', coalesce((
       select jsonb_agg(jsonb_build_object(
                'id', d.id, 'rrule', d.rrule,
                'starts_on', to_char(d.starts_on::timestamp, 'YYYY-MM-DD'),
                'window_days', d.window_days)
              order by d.created_at, d.id)
         from app.task_definition d
        where d.household_id = h.id and d.is_active and d.rrule is not null), '[]'::jsonb))
    from app.household h
   where h.id = p_household
$$;

-- Badge predicates, evaluated by the nightly close. Awarded once per member; a badge with a
-- "points" value also writes one ledger row (reason 'badge').
create function app.tasks_evaluate_badges(p_household uuid) returns int
language plpgsql set search_path = '' as $$
declare
  b       app.badge_definition;
  p       record;
  v_ok    boolean;
  v_award uuid;
  v_bonus int;
  v_n     int := 0;
begin
  for b in select * from app.badge_definition where household_id = p_household loop
    for p in select pr.id from app.profile pr where pr.household_id = p_household and pr.active loop
      v_ok := case b.rule ->> 'type'
        when 'first_task' then exists (
          select 1 from app.task_instance i
           where i.assigned_profile_id = p.id and i.status in ('done', 'verified'))
        when 'streak_reached' then exists (
          select 1 from app.streak s
           where s.profile_id = p.id and s.longest_length >= (b.rule ->> 'length')::int)
        when 'total_tasks' then (
          select count(*) from app.task_instance i
           where i.assigned_profile_id = p.id and i.status in ('done', 'verified'))
          >= (b.rule ->> 'count')::int
        when 'points_earned' then (
          select coalesce(sum(t.amount), 0) from app.point_transaction t
           where t.profile_id = p.id and t.reason = 'task' and t.amount > 0)
          >= (b.rule ->> 'amount')::int
        else false
      end;
      if coalesce(v_ok, false) then
        v_award := null;
        insert into app.badge_award (household_id, profile_id, badge_definition_id, context)
        values (p_household, p.id, b.id, jsonb_build_object('rule', b.rule))
        on conflict (profile_id, badge_definition_id) do nothing
        returning id into v_award;
        if v_award is not null then
          v_n := v_n + 1;
          v_bonus := coalesce((b.rule ->> 'points')::int, 0);
          if v_bonus > 0 then
            insert into app.point_transaction (household_id, profile_id, amount, reason, source_type, source_id)
            values (p_household, p.id, v_bonus, 'badge', 'badge', v_award::text);
          end if;
        end if;
      end if;
    end loop;
  end loop;
  return v_n;
end $$;

-- ------------------------------------------------------------------ api: reads

create view api.task_definitions with (security_invoker = true) as
  select id, title, description, icon_key, kind, points, rrule, starts_on, window_days, assignment,
         assignee_profile_ids, rotation_cursor, requires_verification, is_active,
         created_by_profile_id, created_at, updated_at
    from app.task_definition;

create view api.task_instances with (security_invoker = true) as
  select id, definition_id, title, points, kind, icon_key, due_on, opens_on, closes_on,
         assigned_profile_id, status, completion_count, completed_by_profile_id, completed_at,
         verified_by_profile_id, verified_at, requires_verification
    from app.task_instance;

-- Sum of the ledger per active member; 0 when a member has no rows.
create view api.point_balances with (security_invoker = true) as
  select p.id as profile_id, coalesce(sum(t.amount), 0)::int as balance
    from app.profile p
    left join app.point_transaction t on t.profile_id = p.id
   where p.active
   group by p.id;

create view api.point_transactions with (security_invoker = true) as
  select id, profile_id, occurred_at, amount, reason, source_type, source_id,
         created_by_profile_id, note
    from app.point_transaction;

create view api.rewards with (security_invoker = true) as
  select id, title, description, icon_key, cost_points, stock, requires_approval, is_active
    from app.reward;

create view api.reward_redemptions with (security_invoker = true) as
  select id, reward_id, profile_id, cost_points, status, requested_at, decided_by_profile_id,
         decided_at, note
    from app.reward_redemption;

create view api.streaks with (security_invoker = true) as
  select id, profile_id, definition_id, current_length, longest_length, last_completed_on,
         jokers_used, jokers_month
    from app.streak;

create view api.badge_definitions with (security_invoker = true) as
  select id, key, title, description, icon_key, rule from app.badge_definition;

create view api.badge_awards with (security_invoker = true) as
  select id, profile_id, badge_definition_id, awarded_at, context from app.badge_award;

grant select on api.task_definitions, api.task_instances, api.point_balances, api.point_transactions,
  api.rewards, api.reward_redemptions, api.streaks, api.badge_definitions, api.badge_awards
  to authenticated;
revoke all on api.task_definitions, api.task_instances, api.point_balances, api.point_transactions,
  api.rewards, api.reward_redemptions, api.streaks, api.badge_definitions, api.badge_awards
  from anon;

-- ------------------------------------------------------------------ api: definitions

-- Saves a recurring or one-off definition. Absent keys take the household's defaults (specs/21).
-- A one-off gets its instance at once; recurring ones are materialised by tasks-materialise.
create function api.task_definition_save(p_actor uuid, p_def jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a             app.actor_t := app.actor(p_actor);
  c_uuid        constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  c_date        constant text := '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';
  c_rrule_part  constant text := '^(FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)|INTERVAL=[1-9][0-9]{0,2}|COUNT=[1-9][0-9]{0,3}|UNTIL=[0-9]{8}(T[0-9]{6}Z)?|BYDAY=([+-]?[1-5]?(MO|TU|WE|TH|FR|SA|SU))(,([+-]?[1-5]?(MO|TU|WE|TH|FR|SA|SU)))*|BYMONTHDAY=-?[0-9]{1,2}(,-?[0-9]{1,2})*|BYMONTH=[0-9]{1,2}(,[0-9]{1,2})*|BYSETPOS=-?[0-9]{1,3}|WKST=(MO|TU|WE|TH|FR|SA|SU))$';
  v_today       date := app.tasks_today(a.household_id);
  v_old         app.task_definition;
  v_found       boolean := false;
  v_id          uuid;
  v_title       text;
  v_description text;
  v_icon        text;
  v_kind        text;
  v_points_j    jsonb;
  v_points      int;
  v_verify_j    jsonb;
  v_verify      boolean;
  v_rrule       text;
  v_starts      date;
  v_window_j    jsonb;
  v_window      int;
  v_assignment  text;
  v_ids         jsonb;
  v_pool        uuid[];
  v_active      int;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_def) is distinct from 'object' then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  if nullif(p_def ->> 'id', '') is null then
    v_id := gen_random_uuid();
  else
    if (p_def ->> 'id') !~* c_uuid then
      raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
    end if;
    select * into v_old from app.task_definition
     where id = (p_def ->> 'id')::uuid and household_id = a.household_id for update;
    if not found then
      raise exception 'task not found' using errcode = 'P0002', hint = 'task_not_found';
    end if;
    v_id := v_old.id;
    v_found := true;
  end if;

  v_title       := btrim(coalesce(p_def ->> 'title', ''));
  v_description := nullif(btrim(coalesce(p_def ->> 'description', '')), '');
  v_icon        := nullif(btrim(coalesce(p_def ->> 'icon_key', '')), '');
  v_kind        := coalesce(nullif(p_def ->> 'kind', ''),
                            app.setting_value(a.household_id, 'tasks.kind_default') #>> '{}');
  v_assignment  := nullif(p_def ->> 'assignment', '');
  v_rrule       := nullif(btrim(coalesce(p_def ->> 'rrule', '')), '');
  if length(v_title) not between 1 and 80
     or length(coalesce(v_description, '')) > 500
     or length(coalesce(v_icon, '')) > 40
     or v_kind not in ('duty', 'bonus')
     or v_assignment is null or v_assignment not in ('fixed', 'rotating', 'open', 'each') then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  -- Points: absent or null takes the default for the kind.
  v_points_j := nullif(p_def -> 'points', 'null'::jsonb);
  if v_points_j is null then
    v_points := (app.setting_value(a.household_id, case when v_kind = 'bonus'
                   then 'tasks.points.bonus_default' else 'tasks.points.duty_default' end) #>> '{}')::int;
  elsif jsonb_typeof(v_points_j) = 'number' and (v_points_j #>> '{}') ~ '^[0-9]{1,4}$' then
    v_points := (v_points_j #>> '{}')::int;
  else
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  if v_points not between 0 and 1000 then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  v_verify_j := nullif(p_def -> 'requires_verification', 'null'::jsonb);
  if v_verify_j is null then
    v_verify := (app.setting_value(a.household_id, 'tasks.verification_default') #>> '{}')::boolean;
  elsif jsonb_typeof(v_verify_j) = 'boolean' then
    v_verify := v_verify_j::boolean;
  else
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  -- Recurrence: the supported subset of the calendar's RFC 5545 rules, FREQ exactly once.
  if v_rrule is not null and (
       length(v_rrule) > 300
       or exists (select 1 from regexp_split_to_table(v_rrule, ';') as x(part)
                   where x.part !~ c_rrule_part)
       or (select count(*) from regexp_split_to_table(v_rrule, ';') as x(part)
            where x.part like 'FREQ=%') <> 1
       or (v_rrule ~ '(^|;)COUNT=' and v_rrule ~ '(^|;)UNTIL=')) then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  if nullif(p_def ->> 'starts_on', '') is null then
    v_starts := v_today;
  elsif (p_def ->> 'starts_on') ~ c_date then
    v_starts := (p_def ->> 'starts_on')::date;
  else
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  v_window_j := nullif(p_def -> 'window_days', 'null'::jsonb);
  if v_window_j is null then
    v_window := 1;
  elsif jsonb_typeof(v_window_j) = 'number' and (v_window_j #>> '{}') ~ '^[0-9]{1,2}$' then
    v_window := (v_window_j #>> '{}')::int;
  else
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  if v_window not between 1 and 14 then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  -- The pool: distinct, in the order given (rotation follows it), every one an active member.
  v_ids := coalesce(nullif(p_def -> 'assignee_profile_ids', 'null'::jsonb), '[]'::jsonb);
  if jsonb_typeof(v_ids) <> 'array'
     or exists (select 1 from jsonb_array_elements_text(v_ids) as x(v)
                 where coalesce(x.v, '') !~* c_uuid) then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  v_pool := array(select x.v::uuid from jsonb_array_elements_text(v_ids) with ordinality as x(v, n)
                   group by x.v order by min(x.n));
  select count(*) into v_active from app.profile p
   where p.id = any(v_pool) and p.household_id = a.household_id and p.active;
  if v_active <> cardinality(v_pool)
     or (v_assignment = 'fixed' and cardinality(v_pool) <> 1)
     or (v_assignment in ('rotating', 'each') and cardinality(v_pool) < 1) then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  if v_found then
    update app.task_definition set
      title = v_title, description = v_description, icon_key = v_icon, kind = v_kind, points = v_points,
      rrule = v_rrule, starts_on = v_starts, window_days = v_window, assignment = v_assignment,
      assignee_profile_ids = v_pool, requires_verification = v_verify, updated_at = now()
     where id = v_id;
  else
    insert into app.task_definition (id, household_id, title, description, icon_key, kind, points, rrule,
                                     starts_on, window_days, assignment, assignee_profile_ids,
                                     requires_verification, created_by_profile_id)
    values (v_id, a.household_id, v_title, v_description, v_icon, v_kind, v_points, v_rrule,
            v_starts, v_window, v_assignment, v_pool, v_verify, a.profile_id);
  end if;

  if v_rrule is null then
    perform app.tasks_materialise_rows(a.household_id, jsonb_build_array(
      jsonb_build_object('definition_id', v_id, 'due_on', v_starts)));
  end if;

  perform app.audit(a, 'task_definition', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('title', v_title, 'assignment', v_assignment, 'rrule', v_rrule));
  perform app.broadcast(a.household_id, 'tasks');
  return jsonb_build_object('id', v_id);
end $$;

-- Ends a definition: no more instances, and the open instances in the future are removed.
-- History (done, expired, verified) stays, and so does the ledger.
create function api.task_definition_archive(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  v_today date := app.tasks_today(a.household_id);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  update app.task_definition set is_active = false, updated_at = now()
   where id = p_id and household_id = a.household_id;
  if not found then
    raise exception 'task not found' using errcode = 'P0002', hint = 'task_not_found';
  end if;
  delete from app.task_instance
   where definition_id = p_id and household_id = a.household_id and status = 'open' and due_on > v_today;
  perform app.audit(a, 'task_definition', p_id, 'archive');
  perform app.broadcast(a.household_id, 'tasks');
end $$;

-- A task without a definition: a one-off, possibly for a member or unassigned.
create function api.task_create_adhoc(p_actor uuid, p_task jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a            app.actor_t := app.actor(p_actor);
  v_today      date := app.tasks_today(a.household_id);
  v_title      text := btrim(coalesce(p_task ->> 'title', ''));
  v_icon       text := nullif(btrim(coalesce(p_task ->> 'icon_key', '')), '');
  v_kind       text;
  v_points_j   jsonb := nullif(p_task -> 'points', 'null'::jsonb);
  v_points     int;
  v_verify     boolean;
  v_due        date;
  v_window     int;
  v_who        uuid;
  v_id         uuid := gen_random_uuid();
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_task) is distinct from 'object' then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  v_kind := coalesce(nullif(p_task ->> 'kind', ''), app.setting_value(a.household_id, 'tasks.kind_default') #>> '{}');
  if length(v_title) not between 1 and 80 or length(coalesce(v_icon, '')) > 40 or v_kind not in ('duty', 'bonus') then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  if v_points_j is null then
    v_points := (app.setting_value(a.household_id, case when v_kind = 'bonus'
                   then 'tasks.points.bonus_default' else 'tasks.points.duty_default' end) #>> '{}')::int;
  elsif jsonb_typeof(v_points_j) = 'number' and (v_points_j #>> '{}') ~ '^[0-9]{1,4}$' then
    v_points := (v_points_j #>> '{}')::int;
  else
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  if v_points > 1000 then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  if nullif(p_task -> 'requires_verification', 'null'::jsonb) is null then
    v_verify := (app.setting_value(a.household_id, 'tasks.verification_default') #>> '{}')::boolean;
  elsif jsonb_typeof(p_task -> 'requires_verification') = 'boolean' then
    v_verify := (p_task -> 'requires_verification')::boolean;
  else
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  if nullif(p_task ->> 'due_on', '') is null then
    v_due := v_today;
  elsif (p_task ->> 'due_on') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    v_due := (p_task ->> 'due_on')::date;
  else
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  if nullif(p_task -> 'window_days', 'null'::jsonb) is null then
    v_window := 1;
  elsif jsonb_typeof(p_task -> 'window_days') = 'number' and (p_task ->> 'window_days') ~ '^[0-9]{1,2}$' then
    v_window := (p_task ->> 'window_days')::int;
  else
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  if v_window not between 1 and 14 then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  -- Unassigned unless a member is named (an open task is claimed by whoever ticks it).
  if nullif(p_task ->> 'assigned_profile_id', '') is not null then
    if (p_task ->> 'assigned_profile_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or not exists (select 1 from app.profile p where p.id = (p_task ->> 'assigned_profile_id')::uuid
                       and p.household_id = a.household_id and p.active) then
      raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
    end if;
    v_who := (p_task ->> 'assigned_profile_id')::uuid;
  end if;

  insert into app.task_instance (id, household_id, title, points, kind, icon_key, due_on, opens_on, closes_on,
                                 assigned_profile_id, requires_verification)
  values (v_id, a.household_id, v_title, v_points, v_kind, v_icon, v_due, v_due, v_due + (v_window - 1),
          v_who, v_verify);
  perform app.audit(a, 'task_instance', v_id, 'create', jsonb_build_object('title', v_title));
  perform app.broadcast(a.household_id, 'tasks');
  return jsonb_build_object('id', v_id);
end $$;

-- ------------------------------------------------------------------ api: completing

-- The acting profile ticks a task. Allowed on kiosks and shared devices: ticking is one of the
-- three mutations the wall allows (specs/09). Completing again returns the state reached, with
-- no second credit (the retry of a flaky connection).
create function api.task_complete(p_actor uuid, p_instance_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.actor(p_actor);
  i        app.task_instance;
  v_tz     text;
  v_today  date;
  v_pool   uuid[];
  v_count  int;
  v_credit int := 0;
begin
  select * into i from app.task_instance
   where id = p_instance_id and household_id = a.household_id for update;
  if not found then
    raise exception 'task not found' using errcode = 'P0002', hint = 'task_not_found';
  end if;
  -- Someone else's task stays someone else's, even when it is already ticked: the
  -- idempotent answer below is for a retry by the same person, not a probe by another.
  if i.assigned_profile_id is not null and i.assigned_profile_id <> a.profile_id
     and a.profile_role <> 'guardian' then
    raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
  end if;
  if i.status in ('done', 'verified') then
    return jsonb_build_object('status', i.status, 'points_credited', app.tasks_credited(i.id));
  end if;

  select h.timezone into v_tz from app.household h where h.id = a.household_id;
  v_today := (now() at time zone v_tz)::date;
  if i.status <> 'open' or i.opens_on > v_today then
    raise exception 'WW-TSK-005 task not open' using errcode = '22023', hint = 'task_not_open';
  end if;

  -- The assignee ticks their task; a guardian may tick an assigned task for anyone. An unassigned
  -- (open) task is claimed by the member who ticks it, from its pool when the definition has one.
  if i.assigned_profile_id is not null then
    if i.assigned_profile_id <> a.profile_id and a.profile_role <> 'guardian' then
      raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
    end if;
  else
    if a.profile_role <> 'member' then
      raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
    end if;
    if i.definition_id is not null then
      select d.assignee_profile_ids into v_pool from app.task_definition d where d.id = i.definition_id;
      if cardinality(v_pool) > 0 and not (a.profile_id = any(v_pool)) then
        raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
      end if;
    end if;
    i.assigned_profile_id := a.profile_id;
  end if;

  v_count := i.completion_count + 1;
  -- A task that needs verification holds its points until a guardian approves it.
  if not i.requires_verification and i.points > 0 then
    insert into app.point_transaction (household_id, profile_id, amount, reason, source_type, source_id,
                                       created_by_profile_id)
    values (a.household_id, i.assigned_profile_id, i.points, 'task', 'task',
            i.id::text || ':' || v_count::text, a.profile_id);
    v_credit := i.points;
  end if;

  update app.task_instance set status = 'done', completion_count = v_count,
         completed_by_profile_id = a.profile_id, completed_at = now(),
         assigned_profile_id = i.assigned_profile_id, updated_at = now()
   where id = i.id;
  if i.definition_id is not null then
    perform app.tasks_streak_complete(a.household_id, i.assigned_profile_id, i.definition_id, i.due_on);
  end if;

  perform app.audit(a, 'task_instance', i.id, 'complete',
                    jsonb_build_object('points', v_credit, 'profile_id', i.assigned_profile_id));
  perform app.broadcast(a.household_id, 'tasks');
  return jsonb_build_object('status', 'done', 'points_credited', v_credit);
end $$;

-- Takes back a tick from the same day: the completer (or a guardian) only. The credit is reversed
-- with its own ledger row, so the history shows both. Allowed on kiosks, like the tick itself.
create function api.task_undo(p_actor uuid, p_instance_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  i       app.task_instance;
  v_tz    text;
  v_today date;
begin
  select * into i from app.task_instance
   where id = p_instance_id and household_id = a.household_id for update;
  if not found then
    raise exception 'task not found' using errcode = 'P0002', hint = 'task_not_found';
  end if;
  if i.status <> 'done' then
    raise exception 'WW-TSK-005 task not open' using errcode = '22023', hint = 'task_not_open';
  end if;

  select h.timezone into v_tz from app.household h where h.id = a.household_id;
  v_today := (now() at time zone v_tz)::date;
  if (i.completed_at at time zone v_tz)::date <> v_today then
    raise exception 'WW-TSK-005 task not open' using errcode = '22023', hint = 'undo_window_closed';
  end if;
  if a.profile_role <> 'guardian' and a.profile_id is distinct from i.completed_by_profile_id then
    raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
  end if;

  if not i.requires_verification and i.points > 0 then
    insert into app.point_transaction (household_id, profile_id, amount, reason, source_type, source_id,
                                       created_by_profile_id)
    values (a.household_id, i.assigned_profile_id, -i.points, 'task', 'task_undo',
            i.id::text || ':' || i.completion_count::text, a.profile_id);
  end if;

  update app.task_instance set status = 'open', completed_by_profile_id = null, completed_at = null,
         updated_at = now()
   where id = i.id;
  if i.definition_id is not null then
    perform app.tasks_streak_revert(i.assigned_profile_id, i.definition_id, i.due_on, i.id);
  end if;

  perform app.audit(a, 'task_instance', i.id, 'undo');
  perform app.broadcast(a.household_id, 'tasks');
end $$;

-- A guardian approves (credits the points) or rejects (back to open) a done task that needs
-- verification.
create function api.task_verify(p_actor uuid, p_instance_id uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  i app.task_instance;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  select * into i from app.task_instance
   where id = p_instance_id and household_id = a.household_id for update;
  if not found then
    raise exception 'task not found' using errcode = 'P0002', hint = 'task_not_found';
  end if;
  if i.status <> 'done' or not i.requires_verification or p_approve is null then
    raise exception 'WW-TSK-005 task not open' using errcode = '22023', hint = 'task_not_open';
  end if;

  if p_approve then
    update app.task_instance set status = 'verified', verified_by_profile_id = a.profile_id,
           verified_at = now(), updated_at = now()
     where id = i.id;
    if i.points > 0 then
      insert into app.point_transaction (household_id, profile_id, amount, reason, source_type, source_id,
                                         created_by_profile_id)
      values (a.household_id, i.assigned_profile_id, i.points, 'task', 'task',
              i.id::text || ':' || i.completion_count::text, a.profile_id);
    end if;
  else
    update app.task_instance set status = 'open', completed_by_profile_id = null, completed_at = null,
           updated_at = now()
     where id = i.id;
    if i.definition_id is not null then
      perform app.tasks_streak_revert(i.assigned_profile_id, i.definition_id, i.due_on, i.id);
    end if;
  end if;

  perform app.audit(a, 'task_instance', i.id, case when p_approve then 'verify' else 'reject' end);
  perform app.broadcast(a.household_id, 'tasks');
end $$;

-- A guardian skips an open task. A skip is neither a miss nor a completion: the chain stands.
create function api.task_skip(p_actor uuid, p_instance_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a app.actor_t := app.actor(p_actor);
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  update app.task_instance set status = 'skipped', updated_at = now()
   where id = p_instance_id and household_id = a.household_id and status = 'open';
  if not found then
    if not exists (select 1 from app.task_instance
                    where id = p_instance_id and household_id = a.household_id) then
      raise exception 'task not found' using errcode = 'P0002', hint = 'task_not_found';
    end if;
    raise exception 'WW-TSK-005 task not open' using errcode = '22023', hint = 'task_not_open';
  end if;
  perform app.audit(a, 'task_instance', p_instance_id, 'skip');
  perform app.broadcast(a.household_id, 'tasks');
end $$;

-- A guardian's correction. The note is required; the balance may never go below zero.
create function api.points_adjust(p_actor uuid, p_profile_id uuid, p_amount int, p_note text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_note    text := btrim(coalesce(p_note, ''));
  v_balance int;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if p_amount is null or p_amount = 0 or abs(p_amount) > 100000 or length(v_note) not between 1 and 300 then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  if not exists (select 1 from app.profile p
                  where p.id = p_profile_id and p.household_id = a.household_id and p.active) then
    raise exception 'profile not found' using errcode = 'P0002', hint = 'profile_not_found';
  end if;

  -- Lock the member's row, so two corrections cannot both see the same balance.
  perform 1 from app.profile where id = p_profile_id for update;
  v_balance := app.tasks_balance(p_profile_id);
  if v_balance + p_amount < 0 then
    raise exception 'WW-TSK-003 balance insufficient' using errcode = '22023', hint = 'balance_insufficient';
  end if;

  insert into app.point_transaction (household_id, profile_id, amount, reason, source_type, source_id,
                                     created_by_profile_id, note)
  values (a.household_id, p_profile_id, p_amount, 'adjustment', 'adjustment', gen_random_uuid()::text,
          a.profile_id, v_note);
  perform app.audit(a, 'profile', p_profile_id, 'points_adjust',
                    jsonb_build_object('amount', p_amount, 'note', v_note));
  perform app.broadcast(a.household_id, 'tasks');
end $$;

-- ------------------------------------------------------------------ api: rewards

create function api.reward_save(p_actor uuid, p_reward jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a          app.actor_t := app.actor(p_actor);
  c_uuid     constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_old      app.reward;
  v_found    boolean := false;
  v_id       uuid;
  v_title    text;
  v_desc     text;
  v_icon     text;
  v_cost_j   jsonb := p_reward -> 'cost_points';
  v_cost     int;
  v_stock_j  jsonb := nullif(p_reward -> 'stock', 'null'::jsonb);
  v_stock    int;
  v_appr_j   jsonb := nullif(p_reward -> 'requires_approval', 'null'::jsonb);
  v_approval boolean;
  v_active   boolean;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_reward) is distinct from 'object' then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  if nullif(p_reward ->> 'id', '') is null then
    v_id := gen_random_uuid();
  else
    if (p_reward ->> 'id') !~* c_uuid then
      raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
    end if;
    select * into v_old from app.reward
     where id = (p_reward ->> 'id')::uuid and household_id = a.household_id for update;
    if not found then
      raise exception 'reward not found' using errcode = 'P0002', hint = 'reward_not_found';
    end if;
    v_id := v_old.id;
    v_found := true;
  end if;

  v_title := btrim(coalesce(p_reward ->> 'title', ''));
  v_desc  := nullif(btrim(coalesce(p_reward ->> 'description', '')), '');
  v_icon  := nullif(btrim(coalesce(p_reward ->> 'icon_key', '')), '');
  if length(v_title) not between 1 and 80 or length(coalesce(v_desc, '')) > 500
     or length(coalesce(v_icon, '')) > 40
     or jsonb_typeof(v_cost_j) is distinct from 'number' or (v_cost_j #>> '{}') !~ '^[0-9]{1,6}$' then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  v_cost := (v_cost_j #>> '{}')::int;
  if v_cost not between 1 and 100000 then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  -- Stock: absent or null is unlimited.
  if v_stock_j is null then
    v_stock := null;
  elsif jsonb_typeof(v_stock_j) = 'number' and (v_stock_j #>> '{}') ~ '^[0-9]{1,6}$' then
    v_stock := (v_stock_j #>> '{}')::int;
  else
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  -- Approval: absent takes the household default (specs/21), "required" by default.
  if v_appr_j is null then
    v_approval := (app.setting_value(a.household_id, 'tasks.reward_approval_default') #>> '{}') = 'required';
  elsif jsonb_typeof(v_appr_j) = 'boolean' then
    v_approval := v_appr_j::boolean;
  else
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  v_active := coalesce(nullif(p_reward -> 'is_active', 'null'::jsonb)::boolean,
                       case when v_found then v_old.is_active else true end);

  if v_found then
    update app.reward set title = v_title, description = v_desc, icon_key = v_icon, cost_points = v_cost,
           stock = v_stock, requires_approval = v_approval, is_active = v_active, updated_at = now()
     where id = v_id;
  else
    insert into app.reward (id, household_id, title, description, icon_key, cost_points, stock,
                            requires_approval, is_active)
    values (v_id, a.household_id, v_title, v_desc, v_icon, v_cost, v_stock, v_approval, v_active);
  end if;

  perform app.audit(a, 'reward', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('title', v_title, 'cost_points', v_cost));
  perform app.broadcast(a.household_id, 'tasks');
  return jsonb_build_object('id', v_id);
end $$;

-- The acting profile asks for a reward. Without approval, with enough points and stock, it is
-- approved at once and debited; otherwise it waits as 'requested' and nothing is debited.
create function api.reward_request(p_actor uuid, p_reward_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.actor(p_actor);
  r        app.reward;
  v_id     uuid := gen_random_uuid();
  v_status text := 'requested';
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  select * into r from app.reward
   where id = p_reward_id and household_id = a.household_id and is_active for update;
  if not found then
    raise exception 'reward not found' using errcode = 'P0002', hint = 'reward_not_found';
  end if;
  perform 1 from app.profile where id = a.profile_id for update;

  if not r.requires_approval
     and app.tasks_balance(a.profile_id) >= r.cost_points
     and (r.stock is null or r.stock > 0) then
    v_status := 'approved';
  end if;

  insert into app.reward_redemption (id, household_id, reward_id, profile_id, cost_points, status, decided_at)
  values (v_id, a.household_id, r.id, a.profile_id, r.cost_points, v_status,
          case when v_status = 'approved' then now() end);
  if v_status = 'approved' then
    insert into app.point_transaction (household_id, profile_id, amount, reason, source_type, source_id,
                                       created_by_profile_id)
    values (a.household_id, a.profile_id, -r.cost_points, 'redemption', 'redemption', v_id::text, a.profile_id);
    if r.stock is not null then
      update app.reward set stock = stock - 1, updated_at = now() where id = r.id;
    end if;
  end if;

  perform app.audit(a, 'reward_redemption', v_id, 'request', jsonb_build_object('status', v_status));
  perform app.broadcast(a.household_id, 'tasks');
  return jsonb_build_object('id', v_id, 'status', v_status);
end $$;

-- A guardian decides a request. Approval revalidates the balance and the stock, and debits; a
-- decline may carry a note ("not this week, we are away").
create function api.reward_decide(p_actor uuid, p_redemption_id uuid, p_approve boolean, p_note text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  rd     app.reward_redemption;
  r      app.reward;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if p_approve is null or length(coalesce(v_note, '')) > 300 then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  select * into rd from app.reward_redemption
   where id = p_redemption_id and household_id = a.household_id for update;
  if not found then
    raise exception 'redemption not found' using errcode = 'P0002', hint = 'redemption_not_found';
  end if;
  if rd.status <> 'requested' then
    raise exception 'WW-TSK-005 task not open' using errcode = '22023', hint = 'task_not_open';
  end if;

  if p_approve then
    select * into r from app.reward where id = rd.reward_id for update;
    perform 1 from app.profile where id = rd.profile_id for update;
    if app.tasks_balance(rd.profile_id) < rd.cost_points then
      raise exception 'WW-TSK-003 balance insufficient' using errcode = '22023', hint = 'balance_insufficient';
    end if;
    if r.stock is not null and r.stock <= 0 then
      raise exception 'WW-TSK-004 reward out of stock' using errcode = '22023', hint = 'reward_out_of_stock';
    end if;
    insert into app.point_transaction (household_id, profile_id, amount, reason, source_type, source_id,
                                       created_by_profile_id)
    values (rd.household_id, rd.profile_id, -rd.cost_points, 'redemption', 'redemption', rd.id::text, a.profile_id);
    if r.stock is not null then
      update app.reward set stock = stock - 1, updated_at = now() where id = r.id;
    end if;
    update app.reward_redemption set status = 'approved', decided_by_profile_id = a.profile_id,
           decided_at = now(), note = v_note
     where id = rd.id;
  else
    update app.reward_redemption set status = 'declined', decided_by_profile_id = a.profile_id,
           decided_at = now(), note = v_note
     where id = rd.id;
  end if;

  perform app.audit(a, 'reward_redemption', rd.id, case when p_approve then 'approve' else 'decline' end);
  perform app.broadcast(a.household_id, 'tasks');
end $$;

-- The reward has been handed over.
create function api.reward_fulfil(p_actor uuid, p_redemption_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a  app.actor_t := app.actor(p_actor);
  rd app.reward_redemption;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  select * into rd from app.reward_redemption
   where id = p_redemption_id and household_id = a.household_id for update;
  if not found then
    raise exception 'redemption not found' using errcode = 'P0002', hint = 'redemption_not_found';
  end if;
  if rd.status <> 'approved' then
    raise exception 'WW-TSK-005 task not open' using errcode = '22023', hint = 'task_not_open';
  end if;
  update app.reward_redemption set status = 'fulfilled' where id = rd.id;
  perform app.audit(a, 'reward_redemption', rd.id, 'fulfil');
  perform app.broadcast(a.household_id, 'tasks');
end $$;

-- ------------------------------------------------------------------ api: starter content

-- The starter chores, rewards and badges of specs/21, for a new household. They are German,
-- because they are household data the family reads, not interface strings: the household's
-- own names are changed in the app, and an English household would rename them the same way.
-- Chores draw on the household's child members; rotating and each need at least one child.
-- Idempotent by title and by key.
create function api.tasks_seed_starter(p_actor uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_today   date := app.tasks_today(a.household_id);
  v_kids    uuid[];
  v_approve boolean := (app.setting_value(a.household_id, 'tasks.reward_approval_default') #>> '{}') = 'required';
  v_defs    int := 0;
  v_rewards int := 0;
  v_badges  int := 0;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);

  select coalesce(array_agg(p.id order by p.sort_order, p.id), '{}'::uuid[]) into v_kids
    from app.profile p where p.household_id = a.household_id and p.active and p.kind = 'child';

  if cardinality(v_kids) >= 1 and not exists (select 1 from app.task_definition
       where household_id = a.household_id and title = 'Tisch decken') then
    insert into app.task_definition (household_id, title, kind, points, rrule, starts_on, assignment,
                                     assignee_profile_ids)
    values (a.household_id, 'Tisch decken', 'duty', 1, 'FREQ=DAILY', v_today, 'rotating', v_kids);
    v_defs := v_defs + 1;
  end if;
  if cardinality(v_kids) >= 1 and not exists (select 1 from app.task_definition
       where household_id = a.household_id and title = 'Spülmaschine ausräumen') then
    insert into app.task_definition (household_id, title, kind, points, rrule, starts_on, assignment,
                                     assignee_profile_ids)
    values (a.household_id, 'Spülmaschine ausräumen', 'duty', 1, 'FREQ=DAILY', v_today, 'rotating', v_kids);
    v_defs := v_defs + 1;
  end if;
  if cardinality(v_kids) >= 1 and not exists (select 1 from app.task_definition
       where household_id = a.household_id and title = 'Zimmer aufräumen') then
    insert into app.task_definition (household_id, title, kind, points, rrule, starts_on, assignment,
                                     assignee_profile_ids, requires_verification)
    values (a.household_id, 'Zimmer aufräumen', 'duty', 2, 'FREQ=WEEKLY;BYDAY=SA', v_today, 'each',
            v_kids, true);
    v_defs := v_defs + 1;
  end if;
  if not exists (select 1 from app.task_definition
       where household_id = a.household_id and title = 'Müll rausbringen') then
    insert into app.task_definition (household_id, title, kind, points, rrule, starts_on, assignment,
                                     assignee_profile_ids)
    values (a.household_id, 'Müll rausbringen', 'bonus', 5, 'FREQ=WEEKLY', v_today, 'open', v_kids);
    v_defs := v_defs + 1;
  end if;
  if not exists (select 1 from app.task_definition
       where household_id = a.household_id and title = 'Beim Kochen helfen') then
    insert into app.task_definition (household_id, title, kind, points, rrule, starts_on, assignment,
                                     assignee_profile_ids)
    values (a.household_id, 'Beim Kochen helfen', 'bonus', 8, 'FREQ=WEEKLY', v_today, 'open', v_kids);
    v_defs := v_defs + 1;
  end if;

  -- Rewards at 5, 15 and 50 points: the 1 : 3 : 10 ratio of specs/06.
  if not exists (select 1 from app.reward where household_id = a.household_id and title = 'Samstagsfilm aussuchen') then
    insert into app.reward (household_id, title, cost_points, requires_approval)
    values (a.household_id, 'Samstagsfilm aussuchen', 5, v_approve);
    v_rewards := v_rewards + 1;
  end if;
  if not exists (select 1 from app.reward where household_id = a.household_id and title = '15 Minuten länger aufbleiben') then
    insert into app.reward (household_id, title, cost_points, requires_approval)
    values (a.household_id, '15 Minuten länger aufbleiben', 15, v_approve);
    v_rewards := v_rewards + 1;
  end if;
  if not exists (select 1 from app.reward where household_id = a.household_id and title = 'Ausflug nach Wahl') then
    insert into app.reward (household_id, title, cost_points, requires_approval)
    values (a.household_id, 'Ausflug nach Wahl', 50, v_approve);
    v_rewards := v_rewards + 1;
  end if;

  insert into app.badge_definition (household_id, key, title, description, rule)
  values
    (a.household_id, 'erste_aufgabe', 'Erste Aufgabe', 'Die erste Aufgabe erledigt', '{"type":"first_task"}'),
    (a.household_id, 'sieben_tage', 'Sieben Tage am Stück', 'Sieben Fälligkeiten hintereinander erledigt', '{"type":"streak_reached","length":7}'),
    (a.household_id, 'fuenfundzwanzig', 'Fünfundzwanzig Aufgaben', 'Fünfundzwanzig Aufgaben erledigt', '{"type":"total_tasks","count":25}'),
    (a.household_id, 'hundert_punkte', 'Hundert Punkte', 'Hundert Punkte verdient', '{"type":"points_earned","amount":100}')
  on conflict (household_id, key) do nothing;
  get diagnostics v_badges = row_count;

  perform app.audit(a, 'household', a.household_id, 'tasks_seed_starter',
                    jsonb_build_object('definitions', v_defs, 'rewards', v_rewards, 'badges', v_badges));
  perform app.broadcast(a.household_id, 'tasks');
  return jsonb_build_object('definitions', v_defs, 'rewards', v_rewards, 'badges', v_badges);
end $$;

-- ------------------------------------------------------------------ api: the jobs

-- The schedule of the caller's household, for the Edge Function tasks-materialise.
create function api.tasks_schedule() returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not app.device_ok() then
    raise exception 'device not usable' using errcode = '42501', hint = 'device_revoked';
  end if;
  return app.tasks_schedule_of(app.jwt_household());
end $$;

-- Every household's schedule, for tasks-nightly (service role only).
create function api.tasks_schedule_all() returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  return coalesce((select jsonb_agg(app.tasks_schedule_of(h.id) order by h.id)
                     from app.household h), '[]'::jsonb);
end $$;

-- Creates the instances of [{definition_id, due_on}]. A household member may call it for their own
-- household; the service role for any. Due days beyond today + 14 are ignored. No audit row: a
-- system write, not a member's act.
create function api.tasks_materialise(p_household uuid, p_due jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_today   date;
  v_created int;
begin
  if p_household is null or jsonb_typeof(p_due) is distinct from 'array' then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;
  if not app.is_service_role()
     and (p_household is distinct from app.jwt_household() or not app.device_ok()) then
    raise exception 'WW-TSK-002 task not yours' using errcode = '42501', hint = 'task_not_yours';
  end if;
  v_today := app.tasks_today(p_household);
  if v_today is null then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  v_created := app.tasks_materialise_rows(p_household, (
    select coalesce(jsonb_agg(x), '[]'::jsonb) from jsonb_array_elements(p_due) x
     where (x ->> 'due_on')::date <= v_today + 14));
  if v_created > 0 then
    perform app.broadcast(p_household, 'tasks');
  end if;
  return jsonb_build_object('created', v_created);
end $$;

-- The nightly close of one household's day (service role only). Idempotent per day. Order:
-- open instances whose window has passed expire; each expired instance counts as a miss for its
-- chain (a joker or a break); then the badges are evaluated.
create function api.tasks_close_day(p_household uuid, p_day date) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  i         app.task_instance;
  v_closed  int;
  v_expired int := 0;
  v_badges  int;
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  if p_household is null or p_day is null then
    raise exception 'WW-TSK-001 task invalid' using errcode = '22023', hint = 'task_invalid';
  end if;

  insert into app.tasks_day_closed (household_id, day) values (p_household, p_day)
  on conflict do nothing;
  get diagnostics v_closed = row_count;
  if v_closed = 0 then
    return jsonb_build_object('already_closed', true, 'expired', 0, 'badges_awarded', 0);
  end if;

  for i in select * from app.task_instance
            where household_id = p_household and status = 'open' and closes_on <= p_day
            order by due_on, id
            for update
  loop
    update app.task_instance set status = 'expired', updated_at = now() where id = i.id;
    v_expired := v_expired + 1;
    if i.assigned_profile_id is not null and i.definition_id is not null then
      perform app.tasks_streak_miss(p_household, i.assigned_profile_id, i.definition_id, i.due_on);
    end if;
  end loop;

  v_badges := app.tasks_evaluate_badges(p_household);
  if v_expired > 0 or v_badges > 0 then
    perform app.broadcast(p_household, 'tasks');
  end if;
  return jsonb_build_object('already_closed', false, 'expired', v_expired, 'badges_awarded', v_badges);
end $$;

-- ------------------------------------------------------------------ grants

grant usage on schema api to service_role;

revoke all on function api.task_definition_save(uuid, jsonb), api.task_definition_archive(uuid, uuid),
  api.task_create_adhoc(uuid, jsonb), api.task_complete(uuid, uuid), api.task_undo(uuid, uuid),
  api.task_verify(uuid, uuid, boolean), api.task_skip(uuid, uuid), api.points_adjust(uuid, uuid, int, text),
  api.reward_save(uuid, jsonb), api.reward_request(uuid, uuid), api.reward_decide(uuid, uuid, boolean, text),
  api.reward_fulfil(uuid, uuid), api.tasks_seed_starter(uuid), api.tasks_schedule(),
  api.tasks_schedule_all(), api.tasks_materialise(uuid, jsonb), api.tasks_close_day(uuid, date)
  from public, anon;
grant execute on function api.task_definition_save(uuid, jsonb), api.task_definition_archive(uuid, uuid),
  api.task_create_adhoc(uuid, jsonb), api.task_complete(uuid, uuid), api.task_undo(uuid, uuid),
  api.task_verify(uuid, uuid, boolean), api.task_skip(uuid, uuid), api.points_adjust(uuid, uuid, int, text),
  api.reward_save(uuid, jsonb), api.reward_request(uuid, uuid), api.reward_decide(uuid, uuid, boolean, text),
  api.reward_fulfil(uuid, uuid), api.tasks_seed_starter(uuid), api.tasks_schedule(),
  api.tasks_materialise(uuid, jsonb)
  to authenticated;
grant execute on function api.tasks_materialise(uuid, jsonb) to service_role;

-- The two system jobs: the service role only (ICS-style, see 20261013150000_feed_tokens.sql).
revoke all on function api.tasks_schedule_all(), api.tasks_close_day(uuid, date) from authenticated;
grant execute on function api.tasks_schedule_all(), api.tasks_close_day(uuid, date) to service_role;

-- Internal: a new app function is executable by PUBLIC unless revoked here.
revoke all on function app.point_transaction_append_only(), app.is_service_role(),
  app.setting_value(uuid, text, uuid), app.tasks_today(uuid), app.tasks_balance(uuid),
  app.tasks_credited(uuid), app.tasks_streak_complete(uuid, uuid, uuid, date),
  app.tasks_streak_revert(uuid, uuid, date, uuid), app.tasks_streak_miss(uuid, uuid, uuid, date),
  app.tasks_insert_instance(app.task_definition, date, uuid), app.tasks_materialise_rows(uuid, jsonb),
  app.tasks_schedule_of(uuid), app.tasks_evaluate_badges(uuid)
  from public, anon, authenticated, service_role;

-- The board's open-task counts (specs/09). The body is the one of 20261013130000_week_board.sql,
-- with open_tasks filled in; the rest is copied verbatim.
create or replace function api.board_week(p_week_start date default null) returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
declare
  h              app.household;
  v_now          timestamp;
  v_today        date;
  v_monday       date;
  v_rollover     jsonb;
  v_rollover_at  timestamp;
  v_day_parts    jsonb;
  v_member_label jsonb;
  v_members      jsonb;
  v_days         jsonb;
  v_shopping     int;
  v_open_tasks   jsonb;
begin
  if not app.device_ok() then
    raise exception 'WW-BOARD-001 no household' using errcode = '42501', hint = 'device_revoked';
  end if;
  select * into h from app.household where id = app.jwt_household();
  if not found then
    raise exception 'WW-BOARD-001 no household' using errcode = '42501', hint = 'device_revoked';
  end if;

  -- Effective settings: the household's override, else the curated default (specs/21).
  v_rollover := coalesce(
    (select s.value from app.household_setting s
      where s.household_id = h.id and s.key = 'board.rollover' and s.profile_id is null and s.device_id is null
      limit 1),
    (select d.default_value from app.setting_definition d where d.key = 'board.rollover'));
  v_day_parts := coalesce(
    (select s.value from app.household_setting s
      where s.household_id = h.id and s.key = 'board.day_parts' and s.profile_id is null and s.device_id is null
      limit 1),
    (select d.default_value from app.setting_definition d where d.key = 'board.day_parts'));
  v_member_label := coalesce(
    (select s.value from app.household_setting s
      where s.household_id = h.id and s.key = 'board.member_label' and s.profile_id is null and s.device_id is null
      limit 1),
    (select d.default_value from app.setting_definition d where d.key = 'board.member_label'));

  -- Local wall-clock time of the household. The week is the one containing today, unless the
  -- rollover point of the week has passed (Saturday noon by default: Sunday's planning
  -- session looks at the week it plans). An explicit week start is taken as given.
  v_now   := now() at time zone h.timezone;
  v_today := v_now::date;
  if p_week_start is not null then
    v_monday := date_trunc('week', p_week_start::timestamp)::date;
  else
    v_monday := date_trunc('week', v_today::timestamp)::date;
    v_rollover_at := (v_monday + ((v_rollover ->> 'weekday')::int - 1)) + (v_rollover ->> 'time')::time;
    if v_now >= v_rollover_at then
      v_monday := v_monday + 7;
    end if;
  end if;

  -- Members in the household's order. The baseline is the default presence, if one is set.
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', p.id,
           'display_name', p.display_name,
           'color', p.color,
           'kind', p.kind,
           'baseline', case when p.default_presence_state is not null
                            then jsonb_build_object('state', p.default_presence_state,
                                                    'label', p.default_presence_label)
                       end)
         -- created_at is not in authenticated's column grant; ties are broken by id.
         order by p.sort_order, p.id), '[]'::jsonb)
    into v_members
    from app.profile p
   where p.household_id = h.id and p.active;

  -- Seven days, always: every column has the same zones (specs/09). The zones that do not
  -- exist yet (calendar, timetables, meals) are present and empty.
  select coalesce(jsonb_agg(jsonb_build_object(
           'date', to_char((v_monday + g)::timestamp, 'YYYY-MM-DD'),
           'events', '[]'::jsonb,
           'busy_until', '[]'::jsonb,
           'school', '[]'::jsonb,
           'meal', null::jsonb)
         order by g), '[]'::jsonb)
    into v_days
    from generate_series(0, 6) g;

  -- Open items on the household's default list. Open means not ticked and not bought:
  -- a finished trip moves its items out of the list (trip_id), see the shopping migrations.
  select count(*)::int into v_shopping
    from app.shopping_item i
    join app.shopping_list l on l.id = i.list_id
   where l.household_id = h.id and l.is_default and i.trip_id is null and not i.checked;

  -- Open tasks per member: open instances due today or still inside their window. Unassigned
  -- (open-assignment) instances count for nobody, and members without open tasks are left out.
  select coalesce(jsonb_agg(jsonb_build_object('member_id', x.assigned_profile_id, 'count', x.n)
           order by x.assigned_profile_id), '[]'::jsonb)
    into v_open_tasks
    from (select i.assigned_profile_id, count(*)::int as n
            from app.task_instance i
            join app.profile p on p.id = i.assigned_profile_id and p.active
           where i.household_id = h.id and i.status = 'open'
             and i.opens_on <= v_today and i.closes_on >= v_today
           group by i.assigned_profile_id) x;

  return jsonb_build_object(
    'week_start', to_char(v_monday::timestamp, 'YYYY-MM-DD'),
    'today', to_char(v_today::timestamp, 'YYYY-MM-DD'),
    'generated_at', now(),
    'timezone', h.timezone,
    'settings', jsonb_build_object('day_parts', v_day_parts, 'member_label', v_member_label),
    'members', v_members,
    'presence', '[]'::jsonb,
    'timetables', '[]'::jsonb,
    'days', v_days,
    'open_tasks', v_open_tasks,
    'shopping_count', v_shopping);
end $$;

revoke all on function api.board_week(date) from public, anon;
grant execute on function api.board_week(date) to authenticated;
