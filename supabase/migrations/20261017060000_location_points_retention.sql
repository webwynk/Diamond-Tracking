-- =============================================================================
-- Migration: 20261017060000_location_points_retention.sql
-- Description: Keep raw GPS points for 30 days, then delete them (PRD section 5).
-- Nothing here is applied until the owner approves it. DESTRUCTIVE: read the
-- "What is deleted" part first.
--
-- Why
--   Raw points are the bulk of the database (a heavy day is about 3,000 per
--   employee). Supabase Free holds 500 MB, so they cannot be kept forever. The
--   PRD fixes retention at 30 days (docs/01 section 5, owner decision
--   2026-10-13). The permanent record is the session row (start, end, hours,
--   km, visits, flags), which is NOT touched.
--
-- What is deleted
--   Rows of public.location_points that are BOTH
--     - recorded before the start of the IST day that is 30 days ago, and
--     - in a session that has ended (or in no session at all).
--   Nothing else. Sessions, profiles, visits, the audit log and the live map are
--   untouched. A point of a session that is still open is never deleted.
--   The cut is made at an IST midnight, so a day is never half-deleted: the
--   route view's oldest day (today minus 30 days) is always complete.
--   Deleted points CANNOT be recovered (there is no backup on Free; the owner
--   decided on 2026-10-17 not to build the weekly export).
--
-- What stays correct
--   A session never crosses midnight IST (duty runs 08:00-23:00), so a session is
--   wholly before or after the cut. A late upload into an old closed session
--   used to recompute that session's distance from the points that remain; once
--   points are deleted that would shrink the total. So a phone can no longer
--   upload a point older than the cut: it is rejected as 'point_expired' (the
--   phone discards a rejected point and does not retry it).
--
-- How it runs
--   A pg_cron job at 21:30 UTC (03:00 IST), in batches of 50,000 rows, at most
--   20 batches a run, each run recorded in the audit log ('location_points_purged')
--   only when it deleted something. Nobody can call the functions from the API.
--
-- See what the first run would delete (read-only):
--   select count(*), min(recorded_at), max(recorded_at)
--   from public.location_points p
--   where p.recorded_at < private.points_retention_cutoff()
--     and (p.session_id is null or exists (
--           select 1 from public.duty_sessions s
--           where s.id = p.session_id and s.ended_at is not null));
--
-- Rollback (stops future deletes; deleted rows cannot come back):
--   select cron.unschedule('purge-old-location-points');
--   drop function if exists private.purge_old_location_points();
--   drop function if exists private.points_retention_cutoff();
--   and restore private.location_points_before_insert() from
--   20261017000000_foundation_security_and_live_tracking.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Where the cut is: 00:00 IST, 30 days ago
-- -----------------------------------------------------------------------------
create or replace function private.points_retention_cutoff()
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select (date_trunc('day', now() at time zone 'Asia/Kolkata') - interval '30 days')
         at time zone 'Asia/Kolkata';
$$;

revoke all on function private.points_retention_cutoff() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. A point older than the cut is refused (replaces the insert guard)
-- -----------------------------------------------------------------------------
create or replace function private.location_points_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner   uuid;
  v_started timestamptz;
  v_ended   timestamptz;
begin
  if new.recorded_at > now() + interval '5 minutes' then
    raise exception 'timestamp_in_future' using errcode = 'P0001';
  end if;

  if auth.uid() is null then
    return new;
  end if;

  -- It would be deleted tonight, and a late upload into an old closed session
  -- must not recompute that session's distance from a thinned-out point set.
  if new.recorded_at < private.points_retention_cutoff() then
    raise exception 'point_expired' using errcode = 'P0001';
  end if;

  select employee_id, started_at, ended_at
    into v_owner, v_started, v_ended
  from public.duty_sessions
  where id = new.session_id;

  if v_owner is null or v_owner <> auth.uid() then
    raise exception 'session_not_found' using errcode = 'P0001';
  end if;

  -- Late uploads are fine, but only for moments inside the session.
  if new.recorded_at < v_started - interval '1 minute'
     or new.recorded_at > coalesce(v_ended, now()) + interval '5 minutes' then
    raise exception 'point_outside_session' using errcode = 'P0001';
  end if;

  new.employee_id := auth.uid();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. The purge
-- -----------------------------------------------------------------------------
create or replace function private.purge_old_location_points()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_batch       constant int := 50000;
  c_max_batches constant int := 20;
  v_cutoff  timestamptz := private.points_retention_cutoff();
  v_deleted int := 0;
  v_n       int;
  v_batches int := 0;
begin
  loop
    delete from public.location_points
    where id in (
      select q.id
      from public.location_points q
      where q.recorded_at < v_cutoff
        and (
          q.session_id is null
          or exists (
            select 1 from public.duty_sessions s
            where s.id = q.session_id and s.ended_at is not null
          )
        )
      limit c_batch
    );
    get diagnostics v_n = row_count;
    v_deleted := v_deleted + v_n;
    v_batches := v_batches + 1;
    exit when v_n < c_batch or v_batches >= c_max_batches;
  end loop;

  if v_deleted > 0 then
    insert into public.audit_log (actor_id, action, details)
    values (
      null,
      'location_points_purged',
      jsonb_build_object('deleted', v_deleted, 'recorded_before', v_cutoff)
    );
  end if;

  return v_deleted;
end;
$$;

revoke all on function private.purge_old_location_points() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. Every night at 03:00 IST (21:30 UTC)
-- -----------------------------------------------------------------------------
create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'purge-old-location-points',
  '30 21 * * *',
  $job$select private.purge_old_location_points()$job$
);
