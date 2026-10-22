-- Proposals (specs/24 "Proposals"): what an assistant may hand the family without changing
-- anything. An assistant key stays read-only for every table of the household; the one write it
-- gets is api.mcp_propose, which stores a payload a guardian reviews in the app. The payload is
-- checked for shape and size only (app.proposal_check), never resolved: names, not ids, so a bad
-- proposal can touch nothing. Resolution happens in the app, by the guardian's own actor, through
-- the existing school functions; api.proposal_resolve then records the outcome so the audit log
-- reads "Papa applied a timetable proposed by Claude". Proposals expire after 14 days.
--
-- Additive for api_version: a table, a view, two functions. The previous app release never asks.
--
-- Errors (message 'WW-SCH-0nn ...', hint in the second column):
--   WW-SCH-003  proposal invalid      (proposal_invalid)   shape, size or kind
--   WW-SCH-004  too many open proposals (proposal_limit)   more than five open per person
--   proposal not found / not open    (proposal_not_found, proposal_not_open)

-- ------------------------------------------------------------------ table

create table app.proposal (
  id                     uuid primary key default gen_random_uuid(),
  household_id           uuid not null references app.household on delete cascade,
  kind                   text not null check (kind in ('timetable')),
  payload                jsonb not null,
  source                 text not null check (source in ('mcp', 'scan')),
  proposed_by_profile_id uuid references app.profile on delete set null,
  assistant_label        text check (assistant_label is null or length(assistant_label) <= 60),
  summary                text check (summary is null or length(summary) <= 200),
  client_key             text check (client_key is null or length(client_key) between 1 and 120),
  status                 text not null default 'open' check (status in ('open', 'applied', 'rejected')),
  created_at             timestamptz not null default now(),
  expires_at             timestamptz not null default now() + interval '14 days',
  resolved_by_profile_id uuid references app.profile on delete set null,
  resolved_at            timestamptz
);
create index on app.proposal (household_id, status);
create unique index proposal_client_key_once on app.proposal (household_id, client_key)
  where client_key is not null;

alter table app.proposal enable row level security;
alter table app.proposal force row level security;

-- The household reads its proposals; nobody but the functions writes them.
create policy proposal_read on app.proposal for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.proposal to postgres using (true) with check (true);

revoke all on app.proposal from public, anon, authenticated;
grant select on app.proposal to authenticated;

-- ------------------------------------------------------------------ view

-- An open proposal past its expiry reads as 'expired'; the app lists open ones only.
create view api.proposals with (security_invoker = true) as
  select id, kind, payload, source, proposed_by_profile_id, assistant_label, summary, client_key,
         case when status = 'open' and expires_at < now() then 'expired' else status end as status,
         created_at, expires_at, resolved_by_profile_id, resolved_at
    from app.proposal;
grant select on api.proposals to authenticated;

-- ------------------------------------------------------------------ shape check

-- The payload of specs/24 "The payload" (app/lib/features/school/domain/timetable_import.dart
-- reads the same shape): shape and size only. Strings are bounded, counts are bounded, nothing
-- is looked up. Raises WW-SCH-003 for anything else.
create function app.proposal_check(p_kind text, p_payload jsonb) returns void
language plpgsql immutable set search_path = '' as $$
declare
  v_item   jsonb;
  v_cell   jsonb;
  v_n      int := 0;
begin
  if p_kind is distinct from 'timetable' then
    raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 65536 then
    raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
  end if;
  if (p_payload ? 'format' and p_payload ->> 'format' <> 'wuselwall-timetable/1')
     or not app.proposal_text_ok(p_payload -> 'member', 60)
     or not app.proposal_text_ok(p_payload -> 'school', 120)
     or not app.proposal_text_ok(p_payload -> 'class', 20)
     or not app.proposal_text_ok(p_payload -> 'week_cycle', 12) then
    raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
  end if;

  if p_payload ? 'lessons' then
    if jsonb_typeof(p_payload -> 'lessons') <> 'array' or jsonb_array_length(p_payload -> 'lessons') > 200 then
      raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
    end if;
    for v_item in select x.v from jsonb_array_elements(p_payload -> 'lessons') as x(v) loop
      if jsonb_typeof(v_item) <> 'object'
         or not (v_item ? 'day' or v_item ? 'weekday')
         or not app.proposal_day_ok(coalesce(v_item -> 'day', v_item -> 'weekday'))
         or not app.proposal_text_ok(v_item -> 'subject', 60)
         or not app.proposal_text_ok(v_item -> 'title', 60)
         or not app.proposal_text_ok(v_item -> 'name', 60)
         or not app.proposal_text_ok(v_item -> 'teacher', 60)
         or not app.proposal_text_ok(v_item -> 'room', 40)
         or not app.proposal_text_ok(v_item -> 'week', 3)
         or not app.proposal_text_ok(v_item -> 'parity', 3)
         or not app.proposal_text_ok(v_item -> 'starts', 12)
         or not app.proposal_text_ok(v_item -> 'ends', 12)
         or not app.proposal_period_ok(v_item -> 'period') then
        raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
      end if;
      v_n := v_n + 1;
    end loop;
  end if;

  if p_payload ? 'grid' then
    if jsonb_typeof(p_payload -> 'grid') <> 'object'
       or (select count(*) from jsonb_object_keys(p_payload -> 'grid')) > 7 then
      raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
    end if;
    for v_item in select x.v from jsonb_each(p_payload -> 'grid') as x(k, v) loop
      if jsonb_typeof(v_item) <> 'array' or jsonb_array_length(v_item) > 15 then
        raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
      end if;
      for v_cell in select x.v from jsonb_array_elements(v_item) as x(v) loop
        if jsonb_typeof(v_cell) not in ('null', 'string', 'object')
           or (jsonb_typeof(v_cell) = 'string' and length(v_cell #>> '{}') > 60)
           or (jsonb_typeof(v_cell) = 'object' and length(v_cell::text) > 400) then
          raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
        end if;
        if jsonb_typeof(v_cell) <> 'null' then
          v_n := v_n + 1;
        end if;
      end loop;
    end loop;
  end if;

  if v_n = 0 or v_n > 200 then
    raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
  end if;

  if p_payload ? 'periods' then
    if jsonb_typeof(p_payload -> 'periods') <> 'array' or jsonb_array_length(p_payload -> 'periods') > 15 then
      raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
    end if;
    for v_item in select x.v from jsonb_array_elements(p_payload -> 'periods') as x(v) loop
      if jsonb_typeof(v_item) <> 'object' or length(v_item::text) > 200 then
        raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
      end if;
    end loop;
  end if;

  if p_payload ? 'care' then
    if jsonb_typeof(p_payload -> 'care') <> 'array' or jsonb_array_length(p_payload -> 'care') > 10 then
      raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
    end if;
    for v_item in select x.v from jsonb_array_elements(p_payload -> 'care') as x(v) loop
      if jsonb_typeof(v_item) <> 'object' or length(v_item::text) > 400
         or not app.proposal_text_ok(v_item -> 'title', 60) then
        raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
      end if;
    end loop;
  end if;
end $$;

-- Absent or null, or a string of at most p_max characters.
create function app.proposal_text_ok(p_value jsonb, p_max int) returns boolean
language sql immutable set search_path = '' as $$
  select p_value is null or jsonb_typeof(p_value) = 'null'
         or (jsonb_typeof(p_value) = 'string' and length(p_value #>> '{}') <= p_max)
$$;

-- A weekday as the payload may give it: 1-7, or a short name.
create function app.proposal_day_ok(p_value jsonb) returns boolean
language sql immutable set search_path = '' as $$
  select (jsonb_typeof(p_value) = 'number' and (p_value #>> '{}')::numeric between 1 and 7)
         or (jsonb_typeof(p_value) = 'string' and length(p_value #>> '{}') between 1 and 12)
$$;

-- A period as the payload may give it: absent, 1-15, or a short label ("1.", "1. Stunde").
create function app.proposal_period_ok(p_value jsonb) returns boolean
language sql immutable set search_path = '' as $$
  select p_value is null or jsonb_typeof(p_value) = 'null'
         or (jsonb_typeof(p_value) = 'number' and (p_value #>> '{}')::numeric between 1 and 15)
         or (jsonb_typeof(p_value) = 'string' and length(p_value #>> '{}') between 1 and 12)
$$;

revoke all on function app.proposal_check(text, jsonb), app.proposal_text_ok(jsonb, int),
  app.proposal_day_ok(jsonb), app.proposal_period_ok(jsonb) from public, anon, authenticated;

-- ------------------------------------------------------------------ api: the assistant's one write

-- Stores a proposal for the key's household. The key must be an assistant key (family:read);
-- nothing of the household changes. p_client_key makes a retry return the same proposal.
-- At most five open proposals per person, so a looping assistant stops early. Returns
-- {id, created}.
create function api.mcp_propose(p_token text, p_kind text, p_payload jsonb, p_summary text default null,
                                p_client_key text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a        app.actor_t := app.key_actor(p_token, 'assistant', false);
  v_id     uuid;
  v_label  text;
  v_key    text := nullif(btrim(coalesce(p_client_key, '')), '');
  v_summary text := left(nullif(btrim(coalesce(p_summary, '')), ''), 200);
begin
  if v_key is not null then
    if length(v_key) > 120 then
      raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
    end if;
    select p.id into v_id from app.proposal p
     where p.household_id = a.household_id and p.client_key = v_key;
    if found then
      return jsonb_build_object('id', v_id, 'created', false);
    end if;
  end if;

  perform app.proposal_check(p_kind, p_payload);

  if (select count(*) from app.proposal p
       where p.household_id = a.household_id and p.proposed_by_profile_id = a.profile_id
         and p.status = 'open' and p.expires_at >= now()) >= 5 then
    raise exception 'WW-SCH-004 too many open proposals' using errcode = '54000', hint = 'proposal_limit';
  end if;

  -- Old rows go on the way in: resolved or expired a month ago.
  delete from app.proposal p
   where p.household_id = a.household_id
     and ((p.status <> 'open' and p.resolved_at < now() - interval '30 days')
          or (p.status = 'open' and p.expires_at < now() - interval '30 days'));

  select k.label into v_label from app.shortcut_token k
   where k.token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex');

  insert into app.proposal (household_id, kind, payload, source, proposed_by_profile_id, assistant_label,
                            summary, client_key)
  values (a.household_id, p_kind, p_payload, 'mcp', a.profile_id, left(v_label, 60), v_summary, v_key)
  returning id into v_id;

  perform app.audit(a, 'proposal', v_id, 'create',
                    jsonb_build_object('kind', p_kind, 'summary', v_summary, 'assistant', v_label));
  perform app.broadcast(a.household_id, 'school');
  return jsonb_build_object('id', v_id, 'created', true);
end $$;

-- ------------------------------------------------------------------ api: the guardian's verdict

-- Marks an open proposal applied (the app has written its content through the school functions
-- with this same actor) or rejected. Guardians only, never on a kiosk.
create function api.proposal_resolve(p_actor uuid, p_id uuid, p_status text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  p app.proposal;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if p_status not in ('applied', 'rejected') then
    raise exception 'WW-SCH-003 proposal invalid' using errcode = '22023', hint = 'proposal_invalid';
  end if;
  select * into p from app.proposal x where x.id = p_id and x.household_id = a.household_id;
  if not found then
    raise exception 'proposal not found' using errcode = 'P0002', hint = 'proposal_not_found';
  end if;
  if p.status <> 'open' or p.expires_at < now() then
    raise exception 'proposal not open' using errcode = '22023', hint = 'proposal_not_open';
  end if;

  update app.proposal set status = p_status, resolved_by_profile_id = a.profile_id, resolved_at = now()
   where id = p_id;
  perform app.audit(a, 'proposal', p_id,
                    case p_status when 'applied' then 'apply' else 'reject' end,
                    jsonb_build_object('kind', p.kind, 'summary', p.summary, 'assistant', p.assistant_label,
                                       'proposed_by', p.proposed_by_profile_id));
  perform app.broadcast(a.household_id, 'school');
end $$;

-- ------------------------------------------------------------------ grants

revoke all on function api.mcp_propose(text, text, jsonb, text, text), api.proposal_resolve(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function api.proposal_resolve(uuid, uuid, text) to authenticated;
grant execute on function api.mcp_propose(text, text, jsonb, text, text) to service_role;
