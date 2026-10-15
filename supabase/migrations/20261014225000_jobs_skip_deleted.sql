-- The scheduled jobs leave a deleted household alone (specs/20 J6): until the purge removes it,
-- nothing writes into it. The jobs find their work through these two functions only, so they
-- are where a deleted household drops out.

-- Every live household's schedule, for tasks-nightly (service role only).
create or replace function api.tasks_schedule_all() returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  return coalesce((select jsonb_agg(app.tasks_schedule_of(h.id) order by h.id)
                     from app.household h
                    where h.deleted_at is null), '[]'::jsonb);
end $$;

-- The subscribed calendars due for a fetch, in live households only (service role only).
create or replace function api.external_calendar_due(p_max int) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not app.is_service_role() then
    raise exception 'service role required' using errcode = '42501', hint = 'service_role_required';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'url', d.url, 'etag', d.etag,
                                                 'timezone', d.timezone)), '[]'::jsonb)
      from (
        select c.id, c.url, c.etag, h.timezone
          from app.external_calendar c
          join app.household h on h.id = c.household_id and h.deleted_at is null
         where c.active
           and (c.last_fetched_at is null or c.last_fetched_at < now() - interval '55 minutes')
         order by c.last_fetched_at nulls first, c.id
         limit least(greatest(coalesce(p_max, 1), 1), 100)
      ) d);
end $$;
