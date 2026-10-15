-- Schedules WuselWall's four jobs inside the database, with pg_cron and pg_net, so a
-- server needs no cron on its host (docs/server). The same file serves the compose stack
-- and a hosted Supabase project; only the two variables differ:
--
--   psql -v functions_url=http://api-gw:8000/functions/v1 -v cron_secret=… -f schedule.sql
--     (compose stack: the gateway as the database container sees it; server/wuselwall)
--   functions_url=https://<project-id>.supabase.co/functions/v1   (hosted Supabase)
--
-- cron_secret is the CRON_SECRET the functions know. It sits in the jobs' text, which only
-- the database's administrators can read (cron.job), and it opens nothing but these two
-- jobs. Not in Vault: Vault's key lives outside the database and outside the server's .env,
-- so after a restore on a new machine Vault's secrets cannot be decrypted (found in the
-- restore test of 2026-10-14). Running the file again replaces the jobs in place
-- (cron.schedule replaces a job of the same name).
--
-- A server that runs the jobs from its host instead (infra/cron/*.sh) must not run this: both ways call
-- the same functions with the same secret, so they must not both be active.

\set ON_ERROR_STOP on

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

-- Times are UTC. 01:00 is 02:00 or 03:00 in Central Europe: after midnight everywhere a
-- family is likely to live, which is what closing "yesterday" needs.
select cron.schedule('wuselwall-tasks-nightly', '0 1 * * *', format($job$
  select net.http_post(
    url := %L,
    headers := jsonb_build_object('content-type', 'application/json', 'x-cron-secret', %L),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000)
$job$, :'functions_url' || '/tasks-nightly', :'cron_secret'));

-- Mondays, after the nightly job: the holiday cache (OpenHolidays) for every country the
-- households use. Countries refreshed within 7 days are skipped.
select cron.schedule('wuselwall-holidays-sync', '0 3 * * 1', format($job$
  select net.http_post(
    url := %L,
    headers := jsonb_build_object('content-type', 'application/json', 'x-cron-secret', %L),
    body := '{}'::jsonb,
    timeout_milliseconds := 300000)
$job$, :'functions_url' || '/holidays-sync', :'cron_secret'));

-- Every hour: the households' subscribed calendars (FR-1.9), at most 20 feeds per run, each
-- fetched from the internet by the function. 20 feeds at 15 seconds is the worst case.
select cron.schedule('wuselwall-calendar-import', '0 * * * *', format($job$
  select net.http_post(
    url := %L,
    headers := jsonb_build_object('content-type', 'application/json', 'x-cron-secret', %L),
    body := '{}'::jsonb,
    timeout_milliseconds := 900000)
$job$, :'functions_url' || '/calendar-import', :'cron_secret'));

-- Daily, after the nightly job: removes the families deleted more than 14 days ago and the
-- Auth users of their shared and kiosk devices (specs/20 J6).
select cron.schedule('wuselwall-household-purge', '0 2 * * *', format($job$
  select net.http_post(
    url := %L,
    headers := jsonb_build_object('content-type', 'application/json', 'x-cron-secret', %L),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000)
$job$, :'functions_url' || '/household-purge', :'cron_secret'));

select jobname, schedule from cron.job where jobname like 'wuselwall-%' order by jobname;
