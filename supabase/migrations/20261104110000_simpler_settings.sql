-- Simpler settings (specs/21, specs/27).
--
-- Vorfreude starts 7 days before instead of 14. A family that set its own value keeps it.
--
-- The Tischfrage follows the children's ages, from their birthdays, so the choice between the
-- two decks goes: `rituals.table_question_age_limit` only blocks questions from an age upwards,
-- and is off by default. Nothing about the ages is stored here, the app reads the birthdays it
-- already has.
--
-- Additive for api_version: `rituals.table_question_deck` stays in the catalogue because the
-- previous app release reads it; this release does not offer it. The previous release lists the
-- new row under Advanced with its key as the title.

update app.setting_definition
   set default_value = '7'
 where key = 'rituals.countdown_days';

insert into app.setting_definition (key, scope, type, default_value, constraints, self_service, since_migration) values
  ('rituals.table_question_age_limit', 'household', 'integer', 'null', '{"min":6,"max":16,"nullable":true}', false, '20261104110000');

-- H2 may carry a child's birthday, so the questions fit from the first meal. Optional, and a
-- previous app release simply doesn't send it. The audit row says that it was set, not the date:
-- a child's birth date is personal data.

create or replace function api.household_add_members(p_actor uuid, p_members jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  r      jsonb;
  v_name text;
  v_kind text;
  v_birthday date;
  v_id   uuid;
  v_out  jsonb := '[]'::jsonb;
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_members) <> 'array' or jsonb_array_length(p_members) not between 1 and 12 then
    raise exception 'between 1 and 12 members' using errcode = '22023', hint = 'members_invalid';
  end if;
  for r in select value from jsonb_array_elements(p_members) loop
    if length(btrim(coalesce(r ->> 'display_name', ''))) not between 1 and 40 then
      raise exception 'name invalid' using errcode = '22023', hint = 'name_invalid';
    end if;
    if coalesce(r ->> 'kind', '') not in ('child', 'adult') then
      raise exception 'kind invalid' using errcode = '22023', hint = 'kind_invalid';
    end if;
    if r ->> 'birthday' is not null then
      if r ->> 'birthday' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
        raise exception 'birthday invalid' using errcode = '22023', hint = 'birthday_invalid';
      end if;
      begin
        v_birthday := (r ->> 'birthday')::date;
      exception when others then
        raise exception 'birthday invalid' using errcode = '22023', hint = 'birthday_invalid';
      end;
      if v_birthday < date '1900-01-01' or v_birthday > current_date then
        raise exception 'birthday invalid' using errcode = '22023', hint = 'birthday_invalid';
      end if;
    end if;
  end loop;

  for r in select value from jsonb_array_elements(p_members) loop
    v_name := btrim(r ->> 'display_name');
    v_kind := r ->> 'kind';
    insert into app.profile (household_id, display_name, color, role, kind, birthday)
    values (a.household_id, v_name, app.next_member_color(a.household_id),
            case when v_kind = 'adult' then 'guardian' else 'member' end, v_kind,
            (r ->> 'birthday')::date)
    returning id into v_id;
    perform app.audit(a, 'profile', v_id, 'create',
      jsonb_build_object('display_name', v_name, 'kind', v_kind)
      || case when r ->> 'birthday' is not null then jsonb_build_object('birthday', 'set') else '{}'::jsonb end);
    v_out := v_out || jsonb_build_array(jsonb_build_object('id', v_id, 'display_name', v_name, 'kind', v_kind));
  end loop;
  return v_out;
end $$;
