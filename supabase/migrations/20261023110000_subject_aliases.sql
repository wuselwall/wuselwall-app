-- A subject remembers the words a sheet used for it (specs/24 "Recognition roadmap", step 2).
-- When the parent takes a scanned "Sachkunde" as the family's Sachunterricht, "Sachkunde"
-- becomes an alias of that subject; the next scan sends the aliases with its hints and the
-- parser names the subject straight away, so the twice-yearly sheet needs no correction.
--
-- Additive for api_version: a column with a default, the view gains a column at its end, and
-- api.subject_save keeps its signature (a sent `aliases` array replaces the stored one, an
-- absent key keeps it). The previous app release never sends or reads aliases.

alter table app.subject
  add column aliases text[] not null default '{}'
  check (cardinality(aliases) <= 20);

create or replace view api.subjects with (security_invoker = true) as
  select id, name, short_name, tint, icon_key, equipment_note, notable_default, aliases
    from app.subject;

create or replace function api.subject_save(p_actor uuid, p_subject jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_old     app.subject;
  v_found   boolean;
  v_id      uuid;
  v_name    text;
  v_short   text;
  v_tint    text;
  v_icon    text;
  v_equip   text;
  v_notable boolean;
  v_aliases text[];
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_subject) is distinct from 'object' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  v_id := coalesce(app.school_uuid(p_subject -> 'id'), gen_random_uuid());
  select * into v_old from app.subject where id = v_id;
  v_found := found;
  if v_found and v_old.household_id <> a.household_id then
    raise exception 'subject not found' using errcode = 'P0002', hint = 'subject_not_found';
  end if;

  v_name := app.school_text(p_subject -> 'name', 60);
  v_short := app.school_text(p_subject -> 'short_name', 12);
  v_tint := coalesce(p_subject ->> 'tint', '');
  v_icon := app.school_text(p_subject -> 'icon_key', 40);
  v_equip := app.school_text(p_subject -> 'equipment_note', 80);
  v_notable := coalesce(app.school_bool(p_subject -> 'notable_default'), false);
  if v_name is null or v_short is null
     or v_tint not in ('blue', 'rose', 'lilac', 'leaf', 'peach', 'lemon', 'mint', 'stone')
     or exists (select 1 from app.subject s
                 where s.household_id = a.household_id and s.name = v_name and s.id <> v_id) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  -- The aliases: trimmed, distinct, at most twenty of at most forty characters; an absent key
  -- keeps the stored ones, a sent null or empty array clears them.
  if p_subject ? 'aliases' then
    if jsonb_typeof(p_subject -> 'aliases') = 'array' then
      select coalesce(array_agg(distinct btrim(x) order by btrim(x)), '{}')
        into v_aliases
        from jsonb_array_elements_text(p_subject -> 'aliases') as t(x)
       where btrim(x) <> '' and length(btrim(x)) <= 40;
      if cardinality(v_aliases) > 20 then
        raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
      end if;
    elsif jsonb_typeof(p_subject -> 'aliases') = 'null' then
      v_aliases := '{}';
    else
      raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
    end if;
  else
    v_aliases := coalesce(v_old.aliases, '{}');
  end if;

  if v_found then
    update app.subject set name = v_name, short_name = v_short, tint = v_tint, icon_key = v_icon,
           equipment_note = v_equip, notable_default = v_notable, aliases = v_aliases
     where id = v_id;
  else
    insert into app.subject (id, household_id, name, short_name, tint, icon_key, equipment_note,
                             notable_default, aliases)
    values (v_id, a.household_id, v_name, v_short, v_tint, v_icon, v_equip, v_notable, v_aliases);
  end if;

  perform app.audit(a, 'subject', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('name', v_name));
  perform app.broadcast(a.household_id, 'school');
  return jsonb_build_object('id', v_id);
end $$;
