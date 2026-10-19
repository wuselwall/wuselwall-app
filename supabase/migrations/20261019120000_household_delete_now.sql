-- Deleting a family deletes it at once (specs/20 J6): no 14 days to restore it any more. The
-- guardian types the family's name (checked here, as before) and then the word DELETE (checked
-- in the app only). Every session of the family ends, the household is removed with all its
-- rows, and the Auth users of its shared and kiosk devices go with it, as the purge job does.
-- Adult accounts stay: they can start or join another family.
--
-- Same signature and grants; the answer keeps `purge_after` (now) for the previous app release,
-- which reads it. That release still says the family can be restored for 14 days; it no
-- longer can. Families deleted before this migration keep their window: household_restore and
-- the daily household-purge job are unchanged and still handle them, as they handle the family
-- that account_delete_prepare closes (app.household_close) when its only person goes.
create or replace function api.household_delete(p_actor uuid, p_confirm_name text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a       app.actor_t := app.actor(p_actor);
  v_hh    app.household;
  v_users uuid[];
begin
  if a.device_class <> 'personal' then
    raise exception 'personal device required' using errcode = '42501', hint = 'personal_device_required';
  end if;
  perform app.require_guardian(a);

  select * into v_hh from app.household where id = a.household_id for update;
  if lower(btrim(coalesce(p_confirm_name, ''))) is distinct from lower(btrim(v_hh.name)) then
    raise exception 'family name does not match' using errcode = '22023', hint = 'confirm_name_mismatch';
  end if;

  -- Everyone is signed out: the sessions of phones, and of shared and kiosk device users.
  delete from auth.sessions s
   where s.id in (select d.auth_session_id from app.device d
                   where d.household_id = a.household_id and d.auth_session_id is not null)
      or s.user_id in (select d.auth_user_id from app.device d
                        where d.household_id = a.household_id and d.class <> 'personal');

  select coalesce(array_agg(distinct d.auth_user_id), '{}') into v_users from app.device d
   where d.household_id = a.household_id and d.class <> 'personal' and d.auth_user_id is not null;

  -- Every row of the family cascades away, its audit rows too: nothing of it is kept.
  delete from app.household where id = a.household_id;

  -- Device accounts only: the address is the one app.enrol_device gives them.
  delete from auth.users u
   where u.id = any(v_users) and u.email like 'device-%@devices.wuselwall.invalid';

  return jsonb_build_object('ok', true, 'purge_after', now());
end $$;
