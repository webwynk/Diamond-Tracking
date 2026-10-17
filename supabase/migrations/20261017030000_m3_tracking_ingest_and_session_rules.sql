-- =============================================================================
-- Migration: 20261017030000_m3_tracking_ingest_and_session_rules.sql
-- Description: Server side of Milestone 3 (employee goes on duty, the phone
--   sends GPS). Nothing here is applied until the owner approves it.
--
-- Decisions it implements (owner, 2026-10-17):
--   D3  Starting duty needs a connection: the phone can show the duty window
--       from the SERVER clock via public.server_time().
--   D4  Duty ended while offline: the phone's end time is accepted only within
--       the evidence (after the start, not in the future, no later than 5
--       minutes after the last recorded point, never after 23:00 IST).
--   D5  Duty ends at 23:00 IST on the server even if the phone is offline or
--       dead (BR-2). Idempotent job, with a 15-minute catch-up sweep.
--   D6  Blocking an employee closes their open session in the same
--       transaction (BR-6, PRD F2).
--
-- Also fixes a bug in 20261017000000: a late (offline) upload into a session
-- that had already ended re-created the employee's live_locations row, leaving
-- a ghost marker on the admin map.
--
-- Forward-only and idempotent: safe to run twice.
--
-- Rollback (manual): cron.unschedule('auto-end-duty-curfew' and
-- 'auto-end-duty-sweep'); drop trigger trg_profiles_after_block on
-- public.profiles; drop functions public.ingest_location_points,
-- public.server_time, private.auto_end_open_sessions, private.close_session,
-- private.curfew_at, private.profiles_after_block; restore the previous bodies
-- of private.duty_sessions_before_update and
-- private.location_points_after_insert from 20261017000000.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Server clock for the phone (D3)
-- -----------------------------------------------------------------------------
create or replace function public.server_time()
returns timestamptz
language sql
stable
security invoker
set search_path = ''
as $$
  select now();
$$;

revoke execute on function public.server_time() from public, anon;
grant execute on function public.server_time() to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Helpers (private schema: not reachable through the API)
-- -----------------------------------------------------------------------------

-- 23:00 IST on the IST calendar day the session started (BR-2).
create or replace function private.curfew_at(p_started timestamptz)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select (((p_started at time zone 'Asia/Kolkata')::date + time '23:00')
          at time zone 'Asia/Kolkata');
$$;

-- Closes one open session on the server's authority (block, curfew). Stamps the
-- end time (never after now, 23:00 IST of the start day, or before the start),
-- the distance and the mock-point count. The 'app.system_write' flag tells the
-- duty_sessions update trigger that this is the server speaking, not the phone;
-- it is transaction-local and cannot be set from the API.
create or replace function private.close_session(
  p_session  uuid,
  p_status   text,
  p_reason   text,
  p_note     text,
  p_ended_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('app.system_write', 'on', true);

  update public.duty_sessions
  set status            = p_status,
      end_reason        = p_reason,
      notes             = coalesce(p_note, notes),
      ended_at          = greatest(
                            started_at,
                            least(p_ended_at, now(), private.curfew_at(started_at))
                          ),
      total_distance_km = private.session_distance_km(id),
      mock_points_count = (
        select count(*)::int
        from public.location_points
        where session_id = p_session and is_mock
      )
  where id = p_session and ended_at is null;

  perform set_config('app.system_write', 'off', true);
end;
$$;

revoke all on function private.close_session(uuid, text, text, text, timestamptz)
  from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. Employee closes their own session: accept the phone's end time (D4)
-- -----------------------------------------------------------------------------
create or replace function private.duty_sessions_before_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_last      timestamptz;
  v_floor     timestamptz;
  v_candidate timestamptz;
begin
  -- Server jobs (no JWT) and private.close_session are trusted.
  if auth.uid() is null
     or coalesce(current_setting('app.system_write', true), '') = 'on' then
    return new;
  end if;

  -- BR-15: a closed session is history and never changes.
  if old.ended_at is not null then
    raise exception 'session_already_closed' using errcode = 'P0001';
  end if;

  -- An employee update can only CLOSE their own open session.
  new.employee_id := old.employee_id;
  new.started_at := old.started_at;
  new.visits_count := old.visits_count;
  new.status := case when new.status = 'auto_curfew' then 'auto_curfew' else 'completed' end;

  select max(recorded_at) into v_last
  from public.location_points
  where session_id = old.id;

  v_floor := greatest(old.started_at, coalesce(v_last, old.started_at));

  if new.ended_at is null then
    -- Closed while online: the server's own clock.
    v_candidate := now();
  else
    -- Closed while offline: the phone's time, believed only as far as the
    -- evidence goes. The tracker stops recording the moment duty is turned
    -- off, so the last point is close to the real end.
    v_candidate := least(
      new.ended_at,
      coalesce(v_last, old.started_at) + interval '5 minutes'
    );
  end if;

  new.ended_at := least(
    greatest(v_floor, least(v_candidate, private.curfew_at(old.started_at))),
    now()
  );
  new.total_distance_km := private.session_distance_km(old.id);
  new.mock_points_count := (
    select count(*)::int
    from public.location_points
    where session_id = old.id and is_mock
  );
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. A point after the fact: no ghost marker, totals stay right
-- -----------------------------------------------------------------------------
create or replace function private.location_points_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ended timestamptz;
begin
  select ended_at into v_ended
  from public.duty_sessions
  where id = new.session_id;

  if v_ended is null then
    insert into public.live_locations (
      employee_id, session_id, latitude, longitude, accuracy,
      battery_level, is_mock, recorded_at, updated_at
    ) values (
      new.employee_id, new.session_id, new.latitude, new.longitude, new.accuracy,
      new.battery_level, new.is_mock, new.recorded_at, now()
    )
    on conflict (employee_id) do update
      set session_id    = excluded.session_id,
          latitude      = excluded.latitude,
          longitude     = excluded.longitude,
          accuracy      = excluded.accuracy,
          battery_level = excluded.battery_level,
          is_mock       = excluded.is_mock,
          recorded_at   = excluded.recorded_at,
          updated_at    = now()
      -- A late-arriving old point must never move the marker backwards.
      where public.live_locations.recorded_at < excluded.recorded_at;
  else
    -- Late upload into a session that already ended (the phone was offline):
    -- the employee is not on duty, so there is no marker, but the session's
    -- distance and mock count must include the new point (BR-8). This is a
    -- server correction of a closed record, flagged for the update trigger.
    perform set_config('app.system_write', 'on', true);

    update public.duty_sessions
    set total_distance_km = private.session_distance_km(id),
        mock_points_count = (
          select count(*)::int
          from public.location_points
          where session_id = new.session_id and is_mock
        )
    where id = new.session_id;

    perform set_config('app.system_write', 'off', true);
  end if;
  return null;
end;
$$;

-- -----------------------------------------------------------------------------
-- 5. Batch ingest: the phone's one way to send points (idempotent, per point)
-- -----------------------------------------------------------------------------
-- Runs as the CALLER (security invoker), so row-level security and the
-- location_points triggers still decide what is allowed. Each point gets its
-- own outcome, so one bad point can never block the rest of the queue:
--   accepted   stored now
--   duplicate  already on the server (a retry after a timeout): safe to delete
--   rejected   will never be accepted (reason given): safe to discard
create or replace function public.ingest_location_points(p_points jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  c_max_batch       constant int := 200;
  c_max_per_session constant int := 10000;  -- storage guard; a shift is ~1,500

  v_elem      jsonb;
  v_id        text;
  v_key       text;
  v_counts    jsonb := '{}'::jsonb;
  v_results   jsonb := '[]'::jsonb;
  v_inserted  int;
  v_accepted  int := 0;
  v_duplicate int := 0;
  v_rejected  int := 0;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_points is null or jsonb_typeof(p_points) <> 'array' then
    raise exception 'invalid_batch' using errcode = 'P0001';
  end if;
  if jsonb_array_length(p_points) > c_max_batch then
    raise exception 'batch_too_large' using errcode = 'P0001';
  end if;

  for v_elem in select value from jsonb_array_elements(p_points) loop
    v_id := v_elem ->> 'id';
    begin
      v_key := v_elem ->> 'session_id';

      -- Points already stored for this session, read once per session.
      if not v_counts ? v_key then
        v_counts := v_counts || jsonb_build_object(
          v_key,
          (select count(*) from public.location_points where session_id = v_key::uuid)
        );
      end if;
      if (v_counts ->> v_key)::int >= c_max_per_session then
        raise exception 'session_point_limit' using errcode = 'P0001';
      end if;

      insert into public.location_points (
        id, session_id, latitude, longitude, accuracy, speed, heading,
        altitude, battery_level, is_mock, recorded_at
      ) values (
        v_id,
        v_key::uuid,
        (v_elem ->> 'latitude')::double precision,
        (v_elem ->> 'longitude')::double precision,
        (v_elem ->> 'accuracy')::double precision,
        (v_elem ->> 'speed')::double precision,
        (v_elem ->> 'heading')::double precision,
        (v_elem ->> 'altitude')::double precision,
        (v_elem ->> 'battery_level')::int,
        coalesce((v_elem ->> 'is_mock')::boolean, false),
        (v_elem ->> 'recorded_at')::timestamptz
      )
      on conflict (id) do nothing;
      get diagnostics v_inserted = row_count;

      if v_inserted = 1 then
        v_accepted := v_accepted + 1;
        v_counts := v_counts || jsonb_build_object(v_key, (v_counts ->> v_key)::int + 1);
        v_results := v_results || jsonb_build_object('id', v_id, 'status', 'accepted');
      else
        v_duplicate := v_duplicate + 1;
        v_results := v_results || jsonb_build_object('id', v_id, 'status', 'duplicate');
      end if;
    exception when others then
      v_rejected := v_rejected + 1;
      v_results := v_results || jsonb_build_object(
        'id', v_id,
        'status', 'rejected',
        -- Our own rule names (P0001) are safe to show; anything else is not.
        'reason', case when sqlstate = 'P0001' then sqlerrm else 'invalid_point' end
      );
    end;
  end loop;

  return jsonb_build_object(
    'accepted', v_accepted,
    'duplicate', v_duplicate,
    'rejected', v_rejected,
    'results', v_results,
    'server_time', now()
  );
end;
$$;

revoke execute on function public.ingest_location_points(jsonb) from public, anon;
grant execute on function public.ingest_location_points(jsonb) to authenticated;

-- -----------------------------------------------------------------------------
-- 6. Blocking an employee closes their open session (D6, BR-6)
-- -----------------------------------------------------------------------------
create or replace function private.profiles_after_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session uuid;
begin
  if new.status = 'blocked' and old.status is distinct from 'blocked' then
    for v_session in
      select id from public.duty_sessions
      where employee_id = new.id and ended_at is null
    loop
      perform private.close_session(
        v_session, 'blocked', 'blocked', 'Closed because the account was blocked', now()
      );
    end loop;

    -- Whatever happened above, a blocked employee must not stay on the map.
    delete from public.live_locations where employee_id = new.id;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_profiles_after_block on public.profiles;
create trigger trg_profiles_after_block
after update on public.profiles
for each row execute function private.profiles_after_block();

-- -----------------------------------------------------------------------------
-- 7. 23:00 IST auto-end (D5, BR-2)
-- -----------------------------------------------------------------------------
-- Closes every open session whose 23:00 IST has passed, at 23:00 exactly (not
-- at "now"), so a late run does not stretch a shift. Safe to run any number of
-- times: a closed session is skipped, a session being closed right now by its
-- owner is skipped (skip locked) and caught on the next run.
create or replace function private.auto_end_open_sessions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row   record;
  v_count integer := 0;
begin
  for v_row in
    select id, started_at
    from public.duty_sessions
    where ended_at is null
      and now() >= private.curfew_at(started_at)
    for update skip locked
  loop
    perform private.close_session(
      v_row.id,
      'auto_curfew',
      'auto_curfew',
      'Duty ended automatically',
      private.curfew_at(v_row.started_at)
    );
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function private.auto_end_open_sessions() from public, anon, authenticated;

-- Needs the pg_cron extension (available on the Free plan). Times are UTC:
-- 17:25-17:35 UTC is 22:55-23:05 IST, once a minute around the boundary; the
-- 15-minute sweep catches anything missed (job outage, a session left open
-- from an earlier day).
create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'auto-end-duty-curfew',
  '25-35 17 * * *',
  $job$select private.auto_end_open_sessions()$job$
);
select cron.schedule(
  'auto-end-duty-sweep',
  '*/15 * * * *',
  $job$select private.auto_end_open_sessions()$job$
);
