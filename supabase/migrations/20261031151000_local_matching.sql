-- Local matching, the server side (specs/29, ADR-021): one layered matcher over the generated
-- dictionary (app.match_word, 20261031150000), the household's corrections, and the pictures and
-- categories that now come from them.
--
-- 1. app.match_dictionary(domain, text) is the server's twin of the app's Matcher
--    (app/lib/core/matching/matcher.dart). The first layer that hits wins: the whole normalised
--    text is a dictionary word (phrase); the longest run of its words that is one (word; the head
--    side first: with a connector such as "de", "of" or "mit" among the words the earliest run
--    wins, otherwise the latest); a word without a plural or case ending (stem); a word that ends
--    with a dictionary word of four letters or more (compound); a near spelling, Damerau-
--    Levenshtein distance 1, or 2 from nine letters (fuzzy). It answers one row (key, the
--    categories of the entry, the layer, the dictionary word that hit) or none. A key starting
--    with @ names no picture, only categories. The connectors, endings, stopwords and tie-breaks
--    are the app's; change them in both places.
--    The server does not strip a quantity ("2 Liter Milch", "Milch 1l"): the app does, with the
--    shared parser, before it sends a name, and a name typed on the list is a name. Digits-only
--    words never name anything, so "2 liter milch" still finds "milch".
--    app.damerau_levenshtein is the app's edit distance (optimal string alignment, same early
--    exits); extensions.levenshtein_less_equal (fuzzystrmatch, a trusted extension) only
--    prefilters the candidates: a distance of at most d here is at most 2d there.
-- 2. The functions that were word lists now ask the matcher. app.catalog_icon_for and
--    app.meal_icon_for are stable instead of immutable, so the generated columns
--    app.recipe.icon_key and app.meal_plan_entry.icon_key become plain columns kept by triggers
--    (the picture follows a new title as before). app.catalog_category_keys_for keeps its
--    "Tiefkühl…" rule and then lists the entry's categories, most likely first.
--    Everything the old functions produced by themselves is recomputed: catalogue pictures,
--    recipe and plan pictures, wish pictures that were the old guess (one chosen in the picker
--    stays), and the inferred categories (category_auto) of open items and catalogue entries.
--    A category a person chose is never touched.
-- 3. The household's corrections (app.match_correction, "Learning from the family"): choosing a
--    category for a name (api.shopping_set_category, the 'category' operation of
--    api.shopping_apply, api.catalog_item_update) is remembered for that household, in the same
--    transaction, as the seeded key the category stands for (its key, or for a custom category
--    the key of its name, app.shopping_key_for_name; a custom name that stands for no key writes
--    nothing and forgets an older correction of that name). app.shopping_category_for reads it
--    first: the next add of that name on any list of the household lands in the list's category
--    with that key. Clearing the category forgets the name. Guardians list the corrections
--    (api.match_corrections) and forget one (api.match_correction_forget). Nothing leaves the
--    household; the table is in the export and goes with the household.
--
-- api_version: unchanged. Additive: a table, a view and a function; the previous app release
-- ignores them.

-- ------------------------------------------------------------------ the matcher

create extension if not exists fuzzystrmatch with schema extensions;

-- The one spelling the matcher compares: folded, every run of other characters one space.
create function app.match_normalize(p_text text) returns text
language sql immutable parallel safe set search_path = '' as $$
  select btrim(regexp_replace(app.fold(p_text), '[^a-z0-9]+', ' ', 'g'))
$$;

-- Optimal string alignment distance (app/lib/core/matching/edit_distance.dart): insert, delete,
-- replace and swapping two neighbours cost one each. Returns p_max + 1 as soon as the result is
-- certain to exceed p_max.
create function app.damerau_levenshtein(a text, b text, p_max int default 1048576) returns int
language plpgsql immutable parallel safe cost 500 set search_path = '' as $$
declare
  la       int := length(a);
  lb       int := length(b);
  ca       text[];
  cb       text[];
  two_ago  int[];
  previous int[];
  curr     int[];
  spare    int[];
  row_min  int;
  d        int;
  cost     int;
  result   int;
begin
  if a = b then return 0; end if;
  if abs(la - lb) > p_max then return p_max + 1; end if;
  if la = 0 then return case when lb > p_max then p_max + 1 else lb end; end if;
  if lb = 0 then return case when la > p_max then p_max + 1 else la end; end if;

  ca := string_to_array(a, null);
  cb := string_to_array(b, null);
  -- Row arrays are one-based: element j + 1 is column j.
  two_ago  := array_fill(0, array[lb + 1]);
  previous := array(select generate_series(0, lb));
  curr     := array_fill(0, array[lb + 1]);

  for i in 1..la loop
    curr[1] := i;
    row_min := i;
    for j in 1..lb loop
      cost := case when ca[i] = cb[j] then 0 else 1 end;
      d := previous[j] + cost;
      if previous[j + 1] + 1 < d then d := previous[j + 1] + 1; end if;
      if curr[j] + 1 < d then d := curr[j] + 1; end if;
      if i > 1 and j > 1 and ca[i] = cb[j - 1] and ca[i - 1] = cb[j] and two_ago[j - 1] + 1 < d then
        d := two_ago[j - 1] + 1;
      end if;
      curr[j + 1] := d;
      if d < row_min then row_min := d; end if;
    end loop;
    if row_min > p_max then return p_max + 1; end if;
    spare := two_ago; two_ago := previous; previous := curr; curr := spare;
  end loop;
  result := previous[lb + 1];
  return case when result > p_max then p_max + 1 else result end;
end $$;

-- The fuzzy layer looks at single words of a near length only.
create index match_word_single_length_idx on app.match_word (domain, (length(word)))
  where position(' ' in word) = 0;

-- What a text was recognised as: one row (key, categories, layer, matched) or none. See the header.
create function app.match_dictionary(p_domain text, p_text text)
returns table (key text, categories text[], layer text, matched text)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  c_connectors constant text[] := array[
    'de', 'd', 'du', 'des', 'della', 'di', 'con', 'au', 'aux', 'a', 'al',
    'of', 'mit', 'with', 'et', 'y', 'und', 'and',
    'vom', 'von',
    'ohne', 'without', 'sans', 'sin'];
  c_suffixes constant text[] := array['ern', 'en', 'er', 'es', 's', 'n', 'e'];
  c_stopwords constant text[] := array[
    'bio', 'frisch', 'fresh', 'organic', 'gross', 'klein', 'large', 'small',
    'neu', 'new', 'mit', 'ohne', 'with', 'without', 'the', 'le', 'la', 'les',
    'el', 'los', 'las', 'der', 'die', 'das'];
  n         text := app.match_normalize(p_text);
  toks      text[];
  ntok      int;
  connected boolean;
  v_order   int[];
  v_t       text;
  v_max     int;
  r         record;
begin
  if n is null or n = '' then
    return;
  end if;
  toks := string_to_array(n, ' ');
  ntok := array_length(toks, 1);

  -- phrase: the whole text is a dictionary word
  return query
    select w.key, w.categories, 'phrase'::text, w.word
      from app.match_word w where w.domain = p_domain and w.word = n;
  if found then return; end if;

  -- Token positions in head-first order; digits never name anything.
  connected := toks && c_connectors;
  select coalesce(array_agg(g.i order by case when connected then g.i else -g.i end), '{}')
    into v_order
    from generate_series(1, ntok) as g(i)
   where toks[g.i] !~ '^[0-9]+$';

  -- word: the longest run of tokens that is a dictionary word, the head's side first
  return query
    select w.key, w.categories, 'word'::text, w.word
      from generate_series(ntok - 1, 1, -1) as l(len)
     cross join lateral generate_series(1, ntok - l.len + 1) as s(i)
      join app.match_word w
        on w.domain = p_domain and w.word = array_to_string(toks[s.i : s.i + l.len - 1], ' ')
     where w.word !~ '^[0-9 ]+$'
     order by l.len desc, case when connected then s.i else -s.i end
     limit 1;
  if found then return; end if;

  -- stem: "tomates" is "tomate" with an ending
  return query
    select w.key, w.categories, 'stem'::text, w.word
      from unnest(v_order) with ordinality as o(i, r)
     cross join unnest(c_suffixes) with ordinality as s(sfx, sr)
      join app.match_word w
        on w.domain = p_domain
       and w.word = left(toks[o.i], length(toks[o.i]) - length(s.sfx))
       and position(' ' in w.word) = 0
     where length(toks[o.i]) - length(s.sfx) >= 3
       and right(toks[o.i], length(s.sfx)) = s.sfx
     order by o.r, s.sr
     limit 1;
  if found then return; end if;

  -- compound: the token ends with a dictionary word (sfx '' is the tail itself), possibly
  -- without an ending of its own; the first token with a hit, then the longest word
  return query
    select w.key, w.categories, 'compound'::text, w.word
      from unnest(v_order) with ordinality as o(i, r)
     cross join lateral generate_series(2, length(toks[o.i]) - 3) as st(p)
     cross join unnest(array_prepend(''::text, c_suffixes)) with ordinality as s(sfx, sr)
      join app.match_word w
        on w.domain = p_domain
       and w.word = left(substr(toks[o.i], st.p), length(substr(toks[o.i], st.p)) - length(s.sfx))
       and position(' ' in w.word) = 0
     where s.sfx = ''
        or (right(substr(toks[o.i], st.p), length(s.sfx)) = s.sfx
            and length(substr(toks[o.i], st.p)) - length(s.sfx) >= 4)
     order by o.r, length(w.word) desc, st.p, s.sr
     limit 1;
  if found then return; end if;

  -- fuzzy: one or two typos; the smallest distance, then the longer word, then alphabetical
  foreach v_t in array (select coalesce(array_agg(toks[x]), '{}') from unnest(v_order) as x) loop
    if length(v_t) < 5 or length(v_t) > 100 or v_t = any (c_stopwords) then
      continue;
    end if;
    v_max := case when length(v_t) >= 9 then 2 else 1 end;
    select w.key, w.categories, w.word into r
      from app.match_word w
     cross join lateral (select app.damerau_levenshtein(v_t, w.word, v_max) as d) x
     where w.domain = p_domain and position(' ' in w.word) = 0
       and length(w.word) between length(v_t) - v_max and length(v_t) + v_max
       and extensions.levenshtein_less_equal(v_t, w.word, 2 * v_max) <= 2 * v_max
       and x.d <= v_max
     order by x.d, length(w.word) desc, w.word collate "C"
     limit 1;
    if found then
      return query select r.key, r.categories, 'fuzzy'::text, r.word;
      return;
    end if;
  end loop;
end $$;

-- Just the key, or null.
create function app.match_key(p_domain text, p_text text) returns text
language sql stable set search_path = '' as $$
  select m.key from app.match_dictionary(p_domain, p_text) m
$$;

revoke execute on function app.match_normalize(text), app.damerau_levenshtein(text, text, int),
  app.match_dictionary(text, text), app.match_key(text, text) from public, anon, authenticated;

-- ------------------------------------------------------------------ before the old guesses go

-- A wish picture that is what the old word list gives was a guess, not the family's pick: it is
-- recomputed below. The trigger would hand the guess straight back, so it sleeps meanwhile.
alter table app.meal_wish disable trigger meal_wish_icon;
update app.meal_wish set icon_key = null where icon_key = app.meal_icon_for(free_text);

-- ------------------------------------------------------------------ pictures and categories

-- The picture of a shopping name: the match's key, nothing for a category-only (@) entry.
create or replace function app.catalog_icon_for(p_folded text) returns text
language sql stable set search_path = '' as $$
  select case when m.key like '@%' then null else m.key end
    from app.match_dictionary('shopping', p_folded) m
$$;

-- The seeded category keys a folded name belongs to, most likely first; empty when unknown.
-- A frozen prefix ("Tiefkühl…", "TK-…") comes first, then the entry's categories.
create or replace function app.catalog_category_keys_for(p_folded text) returns text[]
language sql stable set search_path = '' as $$
  with parts(ord, k, pos) as (
    select 1, 'frozen', 1
     where btrim(p_folded) like 'tiefkuehl%' or btrim(p_folded) like 'tiefgekuehlt%'
        or btrim(p_folded) like 'tk-%' or btrim(p_folded) like 'tk %'
        or btrim(p_folded) like 'frozen %'
    union all
    select 2, t.k, t.pos
      from app.match_dictionary('shopping', p_folded) m, unnest(m.categories) with ordinality as t(k, pos)
  ),
  flat as (
    select k, min(ord * 100 + pos) as rank from parts group by k
  )
  select coalesce(array_agg(k order by rank), array[]::text[]) from flat
$$;

-- The dish picture of a name, from the `meals` words.
alter table app.recipe alter column icon_key drop expression;
alter table app.meal_plan_entry alter column icon_key drop expression;

create or replace function app.meal_icon_for(p_title text) returns text
language sql stable set search_path = '' as $$
  select case when m.key like '@%' then null else m.key end
    from app.match_dictionary('meals', p_title) m
$$;

-- The picture follows the title, as the generated columns did.
create function app.recipe_icon() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.icon_key := app.meal_icon_for(new.title);
  return new;
end $$;
create function app.meal_plan_entry_icon() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.icon_key := app.meal_icon_for(new.free_text);
  return new;
end $$;
create trigger recipe_icon before insert or update of title on app.recipe
  for each row execute function app.recipe_icon();
create trigger meal_plan_entry_icon before insert or update of free_text on app.meal_plan_entry
  for each row execute function app.meal_plan_entry_icon();

revoke execute on function app.recipe_icon(), app.meal_plan_entry_icon() from public, anon, authenticated;

-- Everything the old functions produced is recomputed (only the rows that change).
update app.catalog_item set icon_key = app.catalog_icon_for(folded_name)
 where icon_key is distinct from app.catalog_icon_for(folded_name);
update app.recipe set icon_key = app.meal_icon_for(title)
 where icon_key is distinct from app.meal_icon_for(title);
update app.meal_plan_entry set icon_key = app.meal_icon_for(free_text)
 where icon_key is distinct from app.meal_icon_for(free_text);
update app.meal_wish set icon_key = app.meal_icon_for(free_text) where icon_key is null;
alter table app.meal_wish enable trigger meal_wish_icon;

-- ------------------------------------------------------------------ the household's corrections

create table app.match_correction (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references app.household on delete cascade,
  domain       text not null check (domain in ('shopping_category')),
  -- What the person typed, and its folded form, which is what is looked up.
  text         text not null,
  folded_text  text not null,
  -- The seeded key the person's choice stands for (a category key for shopping_category).
  key          text not null,
  set_by       uuid references app.profile on delete set null,
  set_at       timestamptz not null default now(),
  unique (household_id, domain, folded_text)
);
alter table app.match_correction enable row level security;
alter table app.match_correction force row level security;
create policy match_correction_read on app.match_correction for select to authenticated
  using (household_id = app.jwt_household() and app.device_ok());
create policy owner_all on app.match_correction to postgres using (true) with check (true);
revoke all on app.match_correction from public, anon, authenticated;
grant select on app.match_correction to authenticated;

create view api.match_corrections with (security_invoker = true) as
  select id, domain, text, folded_text, key, set_by, set_at
    from app.match_correction;
grant select on api.match_corrections to authenticated;

-- A guardian forgets what the household taught the app; the next add falls back to the dictionary.
create function api.match_correction_forget(p_actor uuid, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  a app.actor_t := app.actor(p_actor);
  v_text text;
begin
  perform app.require_guardian(a);
  delete from app.match_correction where id = p_id and household_id = a.household_id
    returning text into v_text;
  if not found then
    raise exception 'correction not found' using errcode = 'P0002', hint = 'correction_not_found';
  end if;
  perform app.audit(a, 'match_correction', p_id, 'forget', jsonb_build_object('text', v_text));
  perform app.broadcast(a.household_id, 'shopping');
end $$;

revoke execute on function api.match_correction_forget(uuid, uuid) from public, anon;
grant execute on function api.match_correction_forget(uuid, uuid) to authenticated;

-- Remembers (or, for no category, forgets) the choice of a category for a name. The key is the
-- category's own, or the one its name stands for; a name that stands for none teaches nothing and
-- replaces an older lesson for that name. Called by the functions that apply the choice.
create function app.shopping_correction_save(a app.actor_t, p_name text, p_folded text, p_category uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_key text;
begin
  if p_category is not null then
    select coalesce(c.key, app.shopping_key_for_name(app.fold(c.name))) into v_key
      from app.shopping_category c
     where c.id = p_category and c.household_id = a.household_id;
  end if;
  if v_key is null then
    delete from app.match_correction
     where household_id = a.household_id and domain = 'shopping_category' and folded_text = p_folded;
    return;
  end if;
  insert into app.match_correction (household_id, domain, text, folded_text, key, set_by, set_at)
    values (a.household_id, 'shopping_category', p_name, p_folded, v_key, a.profile_id, now())
  on conflict (household_id, domain, folded_text) do update
    set text = excluded.text, key = excluded.key, set_by = excluded.set_by, set_at = excluded.set_at;
end $$;

revoke execute on function app.shopping_correction_save(app.actor_t, text, text, uuid)
  from public, anon, authenticated;

-- The list's own category for a folded name; null when nothing fits. In this precedence:
--   0. the household's correction for the name: the list's category with that key (a seeded one,
--      or a custom one whose name stands for it), the walk's first;
--   a. and b. as in 20261031120000_shopping_custom_match_auto_pins.sql.
create or replace function app.shopping_category_for(p_list uuid, p_folded text) returns uuid
language sql stable security definer set search_path = '' as $$
  select coalesce(
    -- 0. what the household taught
    (select c.id
       from app.shopping_list l
       join app.match_correction m
         on m.household_id = l.household_id and m.domain = 'shopping_category'
        and m.folded_text = btrim(p_folded)
       join app.shopping_category c
         on c.list_id = l.id
        and (c.key = m.key
             or (c.key is null and app.shopping_key_for_name(app.fold(c.name)) = m.key))
      where l.id = p_list
      order by c.sort_order, c.id
      limit 1),
    -- a. a custom category named in the item
    (select c.id
       from app.shopping_category c
      where c.list_id = p_list and c.key is null and c.name is not null
        and length(app.fold(btrim(c.name))) >= 3
        and position(' ' || regexp_replace(app.fold(btrim(c.name)), '[-/]', ' ', 'g') || ' '
                     in ' ' || regexp_replace(btrim(p_folded), '[-/]', ' ', 'g') || ' ') > 0
      order by length(app.fold(btrim(c.name))) desc, c.sort_order, c.id
      limit 1),
    -- b. the first candidate key the list has, as a seeded or an equally named custom category
    (select c.id
       from unnest(app.catalog_category_keys_for(p_folded)) with ordinality as k(key, pos)
       join app.shopping_category c
         on c.list_id = p_list
        and (c.key = k.key
             or (c.key is null and app.shopping_key_for_name(app.fold(c.name)) = k.key))
      order by k.pos, c.sort_order, c.id
      limit 1))
$$;

-- As in 20261031120000_shopping_custom_match_auto_pins.sql; the choice is also remembered.
create or replace function app.shopping_do_category(a app.actor_t, p_item uuid, p_category uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_item app.shopping_item;
begin
  select * into v_item from app.shopping_item
   where id = p_item and household_id = a.household_id and trip_id is null;
  if not found then
    return false;
  end if;
  if p_category is not null and not exists (
       select 1 from app.shopping_category where id = p_category and list_id = v_item.list_id) then
    raise exception 'category not found' using errcode = 'P0002', hint = 'category_not_found';
  end if;
  update app.shopping_item set category_id = p_category, category_auto = false where id = p_item;
  update app.catalog_item set category_id = p_category, category_auto = false
   where id = v_item.catalog_item_id;
  perform app.shopping_correction_save(a, v_item.name, v_item.folded_name, p_category);
  perform app.audit(a, 'shopping_item', p_item, 'categorise');
  return true;
end $$;

-- As in 20261031120000_shopping_custom_match_auto_pins.sql; a category chosen for the entry is
-- also remembered, under the entry's (new) name.
create or replace function api.catalog_item_update(p_actor uuid, p_item uuid, p_name text default null, p_category uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a      app.actor_t := app.actor(p_actor);
  v      app.catalog_item;
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
begin
  if a.device_class = 'kiosk' then
    raise exception 'not allowed on a kiosk' using errcode = '42501', hint = 'kiosk_forbidden';
  end if;
  select * into v from app.catalog_item where id = p_item and household_id = a.household_id;
  if not found then
    raise exception 'tile not found' using errcode = 'P0002', hint = 'catalog_not_found';
  end if;
  if p_name is not null then
    if v_name is null or length(v_name) > 120 then
      raise exception 'name required' using errcode = '22023', hint = 'name_required';
    end if;
    if exists (select 1 from app.catalog_item
                where list_id = v.list_id and id <> p_item and folded_name = app.fold(v_name)) then
      raise exception 'tile exists' using errcode = '23505', hint = 'catalog_exists';
    end if;
  end if;
  if p_category is not null and not exists (select 1 from app.shopping_category
                                              where id = p_category and list_id = v.list_id) then
    raise exception 'category not found' using errcode = 'P0002', hint = 'category_not_found';
  end if;
  update app.catalog_item set
    name          = coalesce(v_name, name),
    folded_name   = coalesce(app.fold(v_name), folded_name),
    category_id   = coalesce(p_category, category_id),
    category_auto = case when p_category is not null then false else category_auto end
  where id = p_item;
  if p_category is not null then
    perform app.shopping_correction_save(a, coalesce(v_name, v.name),
                                         coalesce(app.fold(v_name), v.folded_name), p_category);
  end if;
  perform app.audit(a, 'catalog_item', p_item, 'update',
                    jsonb_strip_nulls(jsonb_build_object('name', v_name, 'category_id', p_category)));
  perform app.broadcast(a.household_id, 'shopping');
end $$;

-- ------------------------------------------------------------------ once for what exists

-- The dictionary changed: what the app inferred (category_auto) is inferred again. A category a
-- person chose is not marked auto and stays.
update app.shopping_item i set category_id = s.cid, category_auto = (s.cid is not null)
  from (select id, app.shopping_category_for(list_id, folded_name) as cid
          from app.shopping_item where trip_id is null and category_auto) s
 where i.id = s.id and (i.category_id is distinct from s.cid or s.cid is null);

update app.catalog_item c set category_id = s.cid, category_auto = (s.cid is not null)
  from (select id, app.shopping_category_for(list_id, folded_name) as cid
          from app.catalog_item where category_auto) s
 where c.id = s.id and (c.category_id is distinct from s.cid or s.cid is null);

-- ------------------------------------------------------------------ export

-- After the shortcut tokens.
insert into app.export_table (name, position, omit, keep) values ('match_correction', 390, '{}', null);

-- ------------------------------------------------------------------ the discovery document

-- As in 20261030100000_claim_server.sql, plus 'local-matching': the app shows "Gelernte Wörter"
-- only on a server that keeps corrections.
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
      'lighter-day', 'event-templates', 'password-reset', 'claim', 'local-matching'
    )
  );
$$;
