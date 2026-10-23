-- Starter subjects per country, canton and language (specs/21 "Starter content", research in
-- specs/research/school-subjects/). The first school of a household brings a subject list in
-- the words its sheets use: Germany, Austria (the 2023/24 names), German-, French- and
-- Italian-speaking Switzerland, France, and Spain with the region's co-official language.
-- The list is written only into an empty subject list and belongs to the family from then on.
--
-- api.school_save gains an optional key: p_school ->> 'language' (the app's language, two
-- letters). It decides the list where the region does not: a bilingual canton, or a country
-- without a list of its own. Additive for api_version: same signature, the previous app
-- release sends no language and gets the lists it got before (German, Austrian, Swiss German).

create or replace function app.starter_subjects(p_household uuid, p_region text, p_language text)
returns int language plpgsql set search_path = '' as $$
declare
  v_country text := split_part(coalesce(p_region, ''), '-', 1);
  v_state   text := split_part(coalesce(p_region, ''), '-', 2);
  v_lang    text := lower(coalesce(p_language, ''));
  v_list    text;
  v_n       int;
begin
  if exists (select 1 from app.subject s where s.household_id = p_household) then
    return 0;
  end if;

  v_list := case
    when v_country = 'AT' then 'at'
    when v_country = 'FR' then 'fr'
    when v_country = 'ES' then 'es'
    when v_country in ('CH', 'LI') then
      case
        when v_state in ('GE', 'VD', 'NE', 'JU') then 'ch-fr'
        when v_state = 'TI' then 'ch-it'
        when v_lang = 'fr' then 'ch-fr'
        when v_lang = 'it' then 'ch-it'
        else 'ch-de'
      end
    when v_country = 'DE' then 'de'
    when v_lang = 'fr' then 'fr'
    when v_lang = 'es' then 'es'
    else 'de'
  end;

  if v_list = 'de' then
    insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
    values
      (p_household, 'Deutsch', 'D', 'rose', 'book', null, false),
      (p_household, 'Mathematik', 'Ma', 'blue', 'numbers', null, false),
      (p_household, 'Sachunterricht', 'SU', 'leaf', 'globe', null, false),
      (p_household, 'Englisch', 'E', 'lilac', 'chat', null, false),
      (p_household, 'Musik', 'Mu', 'lemon', 'music', null, false),
      (p_household, 'Kunst', 'Ku', 'mint', 'palette', null, false),
      (p_household, 'Werken', 'We', 'stone', 'hands', null, false),
      (p_household, 'Religion/Ethik', 'Rel', 'stone', 'hands', null, false),
      (p_household, 'Förderunterricht', 'Fö', 'lilac', 'book', null, false),
      (p_household, 'Sport', 'Sp', 'peach', 'run', 'Sportsachen', true),
      (p_household, 'Schwimmen', 'Sw', 'peach', 'swim', 'Schwimmsachen', true);
  elsif v_list = 'at' then
    insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
    values
      (p_household, 'Deutsch', 'D', 'rose', 'book', null, false),
      (p_household, 'Mathematik', 'M', 'blue', 'numbers', null, false),
      (p_household, 'Sachunterricht', 'SU', 'leaf', 'globe', null, false),
      (p_household, 'Englisch', 'E', 'lilac', 'chat', null, false),
      (p_household, 'Kunst und Gestaltung', 'KuG', 'mint', 'palette', null, false),
      (p_household, 'Musik', 'Mu', 'lemon', 'music', null, false),
      (p_household, 'Technik und Design', 'TD', 'stone', 'hands', null, false),
      (p_household, 'Religion', 'Rel', 'stone', 'hands', null, false),
      (p_household, 'Förderunterricht', 'FU', 'lilac', 'book', null, false),
      (p_household, 'Bewegung und Sport', 'BS', 'peach', 'run', 'Sportsachen', true);
  elsif v_list = 'ch-de' then
    insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
    values
      (p_household, 'Deutsch', 'D', 'rose', 'book', null, false),
      (p_household, 'Mathematik', 'M', 'blue', 'numbers', null, false),
      (p_household, 'Natur, Mensch, Gesellschaft', 'NMG', 'leaf', 'globe', null, false),
      (p_household, 'Englisch', 'E', 'lilac', 'chat', null, false),
      (p_household, 'Französisch', 'F', 'mint', 'chat', null, false),
      (p_household, 'Bildnerisches Gestalten', 'BG', 'peach', 'palette', null, false),
      (p_household, 'Textiles und Technisches Gestalten', 'TTG', 'stone', 'hands', null, false),
      (p_household, 'Musik', 'Mu', 'lemon', 'music', null, false),
      (p_household, 'Bewegung und Sport', 'BS', 'peach', 'run', 'Sportsachen', true),
      (p_household, 'Medien und Informatik', 'MI', 'blue', 'numbers', null, false);
  elsif v_list = 'ch-fr' then
    insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
    values
      (p_household, 'Français', 'FRA', 'rose', 'book', null, false),
      (p_household, 'Mathématiques', 'MAT', 'blue', 'numbers', null, false),
      (p_household, 'Allemand', 'ALL', 'lilac', 'chat', null, false),
      (p_household, 'Anglais', 'ANG', 'mint', 'chat', null, false),
      (p_household, 'Sciences de la nature', 'SN', 'leaf', 'globe', null, false),
      (p_household, 'Histoire', 'HIS', 'stone', 'globe', null, false),
      (p_household, 'Géographie', 'GEO', 'leaf', 'globe', null, false),
      (p_household, 'Arts visuels', 'AVI', 'peach', 'palette', null, false),
      (p_household, 'Activités créatrices manuelles', 'ACM', 'stone', 'hands', null, false),
      (p_household, 'Musique', 'MUS', 'lemon', 'music', null, false),
      (p_household, 'Éthique et cultures religieuses', 'ECR', 'stone', 'hands', null, false),
      (p_household, 'Éducation physique', 'EPH', 'peach', 'run', 'Affaires de gym', true);
  elsif v_list = 'ch-it' then
    insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
    values
      (p_household, 'Italiano', 'ITA', 'rose', 'book', null, false),
      (p_household, 'Matematica', 'MAT', 'blue', 'numbers', null, false),
      (p_household, 'Tedesco', 'TED', 'lilac', 'chat', null, false),
      (p_household, 'Francese', 'FRA', 'mint', 'chat', null, false),
      (p_household, 'Studio d''ambiente', 'AMB', 'leaf', 'globe', null, false),
      (p_household, 'Educazione visiva', 'EV', 'peach', 'palette', null, false),
      (p_household, 'Educazione alle arti plastiche', 'EAP', 'stone', 'hands', null, false),
      (p_household, 'Educazione musicale', 'EM', 'lemon', 'music', null, false),
      (p_household, 'Educazione fisica', 'EF', 'peach', 'run', 'Tenuta da ginnastica', true);
  elsif v_list = 'fr' then
    insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
    values
      (p_household, 'Français', 'FR', 'rose', 'book', null, false),
      (p_household, 'Mathématiques', 'MATHS', 'blue', 'numbers', null, false),
      (p_household, 'Anglais', 'ANG', 'lilac', 'chat', null, false),
      (p_household, 'Questionner le monde', 'QLM', 'leaf', 'globe', null, false),
      (p_household, 'Sciences et technologie', 'SCI', 'leaf', 'globe', null, false),
      (p_household, 'Histoire-géographie', 'HG', 'stone', 'globe', null, false),
      (p_household, 'Enseignement moral et civique', 'EMC', 'stone', 'hands', null, false),
      (p_household, 'Arts plastiques', 'ARTS', 'mint', 'palette', null, false),
      (p_household, 'Éducation musicale', 'EM', 'lemon', 'music', null, false),
      (p_household, 'Éducation physique et sportive', 'EPS', 'peach', 'run', 'Affaires de sport', true),
      (p_household, 'Natation', 'NAT', 'peach', 'swim', 'Affaires de piscine', true);
  elsif v_list = 'es' then
    insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
    values
      (p_household, 'Lengua Castellana y Literatura', 'LCL', 'rose', 'book', null, false),
      (p_household, 'Matemáticas', 'MAT', 'blue', 'numbers', null, false),
      (p_household, 'Inglés', 'ING', 'lilac', 'chat', null, false),
      (p_household, 'Conocimiento del Medio', 'CM', 'leaf', 'globe', null, false),
      (p_household, 'Educación Plástica y Visual', 'PLAS', 'mint', 'palette', null, false),
      (p_household, 'Música', 'MUS', 'lemon', 'music', null, false),
      (p_household, 'Religión', 'REL', 'stone', 'hands', null, false),
      (p_household, 'Atención Educativa', 'AE', 'stone', 'book', null, false),
      (p_household, 'Valores Cívicos y Éticos', 'VCE', 'stone', 'hands', null, false),
      (p_household, 'Tutoría', 'TUT', 'lilac', 'chat', null, false),
      (p_household, 'Educación Física', 'EF', 'peach', 'run', 'Ropa de deporte', true);
    -- The region's co-official language, where the school teaches one.
    if v_state in ('CT', 'IB') then
      insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
      values (p_household, 'Llengua Catalana i Literatura', 'CAT', 'rose', 'book', null, false);
    elsif v_state = 'VC' then
      insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
      values (p_household, 'Valencià: Llengua i Literatura', 'VAL', 'rose', 'book', null, false);
    elsif v_state = 'GA' then
      insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
      values (p_household, 'Lingua Galega e Literatura', 'LG', 'rose', 'book', null, false);
    elsif v_state in ('PV', 'NC') then
      insert into app.subject (household_id, name, short_name, tint, icon_key, equipment_note, notable_default)
      values (p_household, 'Euskara eta Literatura', 'EUS', 'rose', 'book', null, false);
    end if;
  end if;

  select count(*) into v_n from app.subject s where s.household_id = p_household;
  return v_n;
end $$;

revoke all on function app.starter_subjects(uuid, text, text) from public, anon, authenticated;

create or replace function api.school_save(p_actor uuid, p_school jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a         app.actor_t := app.actor(p_actor);
  v_old     app.school;
  v_found   boolean;
  v_id      uuid;
  v_name    text;
  v_region  text;
  v_state   text;
  v_tz      text;
  v_lang    text;
  c_region  constant text := '^[A-Z]{2}(-[A-Z0-9ÄÖÜ]{1,6}){1,4}$';
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  perform app.require_guardian(a);
  if jsonb_typeof(p_school) is distinct from 'object' then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;

  v_id := coalesce(app.school_uuid(p_school -> 'id'), gen_random_uuid());
  select * into v_old from app.school where id = v_id;
  v_found := found;
  if v_found and v_old.household_id <> a.household_id then
    raise exception 'school not found' using errcode = 'P0002', hint = 'school_not_found';
  end if;

  v_name := app.school_text(p_school -> 'name', 120);
  if v_name is null then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  -- A key that is not sent keeps the stored value; a sent null clears it.
  if p_school ? 'region_code' then
    v_region := app.school_text(p_school -> 'region_code', 30);
    if v_region is not null and v_region !~ c_region then
      raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'invalid_region';
    end if;
    v_state := case when v_region is null then null
                    else split_part(v_region, '-', 1) || '-' || split_part(v_region, '-', 2) end;
  elsif p_school ? 'state_code' then
    v_state := app.school_text(p_school -> 'state_code', 6);
    if v_state is not null and v_state !~ '^[A-Z]{2}-[A-Z0-9ÄÖÜ]{1,6}$' then
      raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
    end if;
    v_region := v_state;
  else
    v_region := v_old.region_code;
    v_state := v_old.state_code;
  end if;
  v_tz := coalesce(
    case when p_school ? 'timezone' then app.school_text(p_school -> 'timezone', 64) end,
    case when v_found then v_old.timezone end,
    (select h.timezone from app.household h where h.id = a.household_id));
  if not exists (select 1 from pg_timezone_names n where n.name = v_tz) then
    raise exception 'WW-SCH-001 school invalid' using errcode = '22023', hint = 'school_invalid';
  end if;
  -- The app's language, for the starter list only; anything but two letters is ignored.
  v_lang := app.school_text(p_school -> 'language', 8);
  if v_lang !~ '^[A-Za-z]{2}' then v_lang := null; end if;
  v_lang := lower(left(v_lang, 2));

  if v_found then
    update app.school set name = v_name, state_code = v_state, region_code = v_region, timezone = v_tz
     where id = v_id;
  else
    insert into app.school (id, household_id, name, state_code, region_code, timezone)
    values (v_id, a.household_id, v_name, v_state, v_region, v_tz);

    -- Bell-time template: six 45-minute lessons from 08:00, a 5-minute break after lessons 1, 3
    -- and 5, a 20-minute break after lessons 2 and 4.
    insert into app.school_period (household_id, school_id, index, label, starts_at, ends_at, kind)
    select a.household_id, v_id, t.idx, null, t.starts_at, t.ends_at, t.kind
      from (values
        (1, '08:00'::time, '08:45'::time, 'lesson'),
        (1, '08:45'::time, '08:50'::time, 'break'),
        (2, '08:50'::time, '09:35'::time, 'lesson'),
        (2, '09:35'::time, '09:55'::time, 'break'),
        (3, '09:55'::time, '10:40'::time, 'lesson'),
        (3, '10:40'::time, '10:45'::time, 'break'),
        (4, '10:45'::time, '11:30'::time, 'lesson'),
        (4, '11:30'::time, '11:50'::time, 'break'),
        (5, '11:50'::time, '12:35'::time, 'lesson'),
        (5, '12:35'::time, '12:40'::time, 'break'),
        (6, '12:40'::time, '13:25'::time, 'lesson')
      ) as t (idx, starts_at, ends_at, kind);

    -- Starter subjects in the words of the region (app.starter_subjects), only into an empty
    -- subject list.
    perform app.starter_subjects(a.household_id, v_region, v_lang);
  end if;

  perform app.audit(a, 'school', v_id, case when v_found then 'update' else 'create' end,
                    jsonb_build_object('name', v_name));
  perform app.broadcast(a.household_id, 'school');
  return jsonb_build_object('id', v_id);
end $$;
