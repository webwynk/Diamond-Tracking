-- =============================================================================
-- Attack checks for 20261017030000_m3_tracking_ingest_and_session_rules.sql
--
-- Run AFTER the migration is applied (or in the same rolled-back transaction as
-- the migration, see docs).
--
-- Updated 2026-10-17: profiles are inserted explicitly in the fixtures, because
-- the new-user trigger no longer exists (migration 20261017040000). Run supabase/tests/attack_checks.sql as well: the
-- earlier 24 checks must still pass after this migration.
--
-- HOW TO READ THE RESULT
--   The script ends with an intentional error whose text is the full report:
--   one PASS or FAIL line per check, then a RESULT line. The error is how
--   everything the script created (test users, sessions, points) is rolled
--   back, so it leaves nothing behind. Any FAIL means: do not rely on the
--   migration. (docs/05 section 4: "Policies are not trusted until attacked.")
--
-- NOT covered here (state it, do not pretend): the 10,000-points-per-session
-- guard (it would need 10,000 rows), and the pg_cron schedule itself (the job
-- runs on the platform clock; only the function it calls is exercised).
-- =============================================================================
begin;

create or replace function pg_temp.note(p_line text) returns void
language plpgsql as $$
begin
  perform set_config('attack.report',
    coalesce(current_setting('attack.report', true), '') || E'\n' || p_line, true);
end $$;

-- One line per check: PASS when the condition holds, FAIL otherwise.
create or replace function pg_temp.check(p_ok boolean, p_label text) returns void
language plpgsql as $$
begin
  perform pg_temp.note(case when coalesce(p_ok, false) then 'PASS  ' else 'FAIL  ' end || p_label);
end $$;

create or replace function pg_temp.act_as(p_uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create or replace function pg_temp.act_as_anon() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  perform set_config('role', 'anon', true);
end $$;

create or replace function pg_temp.act_as_server() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'postgres', true);
end $$;

-- Builds one point as the phone would send it.
create or replace function pg_temp.pt(p_id text, p_session uuid, p_lat double precision,
                                      p_at timestamptz) returns jsonb
language sql as $$
  select jsonb_build_object(
    'id', p_id, 'session_id', p_session, 'latitude', p_lat, 'longitude', 73.0,
    'accuracy', 5, 'recorded_at', p_at);
$$;

do $$
declare
  v_admin uuid := gen_random_uuid();
  v_e1    uuid := gen_random_uuid();
  v_e2    uuid := gen_random_uuid();
  v_e3    uuid := gen_random_uuid();
  v_e4    uuid := gen_random_uuid();
  v_s1    uuid := gen_random_uuid();
  v_s2    uuid := gen_random_uuid();
  v_s3    uuid := gen_random_uuid();
  v_s4    uuid := gen_random_uuid();
  v_res   jsonb;
  v_n     int;
  v_n2    int;
  v_ts    timestamptz;
  v_ts2   timestamptz;
  v_km    numeric;
  v_km2   numeric;
  v_status text;
  v_reason text;
  v_note   text;
  v_last   timestamptz;
  v_yesterday_start timestamptz;
  v_big   jsonb;
  v_lat   double precision;
begin
  ---------------------------------------------------------------------------
  -- Fixtures (as the server)
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();

  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                          created_at, updated_at)
  values
    (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'm3-admin@test.invalid', 'x', now(),
     '{"role":"admin","full_name":"M3 Admin"}', '{}', now(), now()),
    (v_e1, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zy-001@staff.test.invalid', 'x', now(),
     '{"role":"employee","employee_code":"ZY-001","phone":"+910000000011","full_name":"M3 One"}',
     '{}', now(), now()),
    (v_e2, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zy-002@staff.test.invalid', 'x', now(),
     '{"role":"employee","employee_code":"ZY-002","phone":"+910000000012","full_name":"M3 Two"}',
     '{}', now(), now()),
    (v_e3, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zy-003@staff.test.invalid', 'x', now(),
     '{"role":"employee","employee_code":"ZY-003","phone":"+910000000013","full_name":"M3 Three"}',
     '{}', now(), now()),
    (v_e4, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zy-004@staff.test.invalid', 'x', now(),
     '{"role":"employee","employee_code":"ZY-004","phone":"+910000000014","full_name":"M3 Four"}',
     '{}', now(), now());

  insert into public.profiles (id, email, role, status, full_name, must_change_pin)
  values (v_admin, 'm3-admin@test.invalid', 'admin', 'active', 'M3 Admin', false);
  insert into public.profiles (id, email, role, status, full_name, employee_code, phone, must_change_pin)
  values
    (v_e1, 'zy-001@staff.test.invalid', 'employee', 'active', 'M3 One',   'ZY-001', '+910000000011', true),
    (v_e2, 'zy-002@staff.test.invalid', 'employee', 'active', 'M3 Two',   'ZY-002', '+910000000012', true),
    (v_e3, 'zy-003@staff.test.invalid', 'employee', 'active', 'M3 Three', 'ZY-003', '+910000000013', true),
    (v_e4, 'zy-004@staff.test.invalid', 'employee', 'active', 'M3 Four',  'ZY-004', '+910000000014', true);

  -- S1 (E1): open since 3 h ago; three points 90..88 minutes ago, ~111 m apart.
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s1, v_e1, 'open', now() - interval '3 hours');
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, recorded_at)
  values
    ('m3-a1', v_s1, v_e1, 20.000, 73.0, 5, now() - interval '90 minutes'),
    ('m3-a2', v_s1, v_e1, 20.001, 73.0, 5, now() - interval '89 minutes'),
    ('m3-a3', v_s1, v_e1, 20.002, 73.0, 5, now() - interval '88 minutes');

  -- S2 (E2): open since 3 h ago, two points.
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s2, v_e2, 'open', now() - interval '3 hours');
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, recorded_at)
  values
    ('m3-b1', v_s2, v_e2, 21.000, 73.0, 5, now() - interval '100 minutes'),
    ('m3-b2', v_s2, v_e2, 21.001, 73.0, 5, now() - interval '99 minutes');

  -- S3 (E3): open since 2 h ago, two points; will be blocked while on duty.
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s3, v_e3, 'open', now() - interval '2 hours');
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, recorded_at)
  values
    ('m3-c1', v_s3, v_e3, 22.000, 73.0, 5, now() - interval '30 minutes'),
    ('m3-c2', v_s3, v_e3, 22.001, 73.0, 5, now() - interval '29 minutes');

  -- S4 (E4): started yesterday 10:00 IST and never closed (dead phone).
  v_yesterday_start := (date_trunc('day', now() at time zone 'Asia/Kolkata')
                        - interval '1 day' + interval '10 hours') at time zone 'Asia/Kolkata';
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s4, v_e4, 'open', v_yesterday_start);
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, recorded_at)
  values
    ('m3-d1', v_s4, v_e4, 23.000, 73.0, 5, v_yesterday_start + interval '5 minutes'),
    ('m3-d2', v_s4, v_e4, 23.001, 73.0, 5, v_yesterday_start + interval '6 minutes');

  perform pg_temp.check(
    (select count(*) from public.live_locations where employee_id in (v_e1, v_e2, v_e3, v_e4)) = 4,
    'setup: each open session has a live marker');

  ---------------------------------------------------------------------------
  -- A. Batch ingest, as employee ONE
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);

  -- Bad points first: they must not stop the good one behind them.
  v_res := public.ingest_location_points(jsonb_build_array(
    pg_temp.pt('m3-future', v_s1, 20.5, now() + interval '2 hours'),
    pg_temp.pt('m3-foreign', v_s2, 20.5, now() - interval '60 minutes'),
    jsonb_build_object('id', 'm3-malformed', 'session_id', v_s1,
                       'longitude', 73.0, 'recorded_at', now() - interval '61 minutes'),
    pg_temp.pt('m3-before', v_s1, 20.5, now() - interval '1 day'),
    pg_temp.pt('m3-a3', v_s1, 20.002, now() - interval '88 minutes'),
    pg_temp.pt('m3-p1', v_s1, 20.003, now() - interval '60 minutes')
  ));
  perform pg_temp.check(
    (v_res ->> 'accepted')::int = 1 and (v_res ->> 'duplicate')::int = 1
      and (v_res ->> 'rejected')::int = 4,
    format('ingest: 1 accepted, 1 duplicate, 4 rejected in one batch (got %s/%s/%s)',
           v_res ->> 'accepted', v_res ->> 'duplicate', v_res ->> 'rejected'));
  perform pg_temp.check(
    exists (select 1 from jsonb_array_elements(v_res -> 'results') r
            where r ->> 'id' = 'm3-future' and r ->> 'reason' = 'timestamp_in_future'),
    'ingest: a future-dated point is rejected with its reason');
  perform pg_temp.check(
    exists (select 1 from jsonb_array_elements(v_res -> 'results') r
            where r ->> 'id' = 'm3-foreign' and r ->> 'reason' = 'session_not_found'),
    'ingest: a point for ANOTHER employee''s session is rejected');
  perform pg_temp.check(
    exists (select 1 from jsonb_array_elements(v_res -> 'results') r
            where r ->> 'id' = 'm3-malformed' and r ->> 'reason' = 'invalid_point'),
    'ingest: a malformed point is rejected without leaking database text');
  perform pg_temp.check(
    exists (select 1 from jsonb_array_elements(v_res -> 'results') r
            where r ->> 'id' = 'm3-before' and r ->> 'reason' = 'point_outside_session'),
    'ingest: a point from before the session is rejected');
  perform pg_temp.check(
    exists (select 1 from jsonb_array_elements(v_res -> 'results') r
            where r ->> 'id' = 'm3-p1' and r ->> 'status' = 'accepted'),
    'ingest: the good point behind four bad ones was still stored');

  select count(*) into v_n from public.location_points where session_id = v_s1;
  -- Same batch again (what a retry after a timeout looks like).
  v_res := public.ingest_location_points(jsonb_build_array(
    pg_temp.pt('m3-a3', v_s1, 20.002, now() - interval '88 minutes'),
    pg_temp.pt('m3-p1', v_s1, 20.003, now() - interval '60 minutes')
  ));
  select count(*) into v_n2 from public.location_points where session_id = v_s1;
  perform pg_temp.check(
    (v_res ->> 'accepted')::int = 0 and (v_res ->> 'duplicate')::int = 2 and v_n = v_n2,
    'ingest: a retried batch creates no duplicates');

  select jsonb_agg(pg_temp.pt('m3-big-' || g, v_s1, 20.0, now() - interval '70 minutes'))
    into v_big from generate_series(1, 201) g;
  begin
    perform public.ingest_location_points(v_big);
    perform pg_temp.check(false, 'ingest: a batch of 201 was accepted');
  exception when others then
    perform pg_temp.check(sqlerrm = 'batch_too_large', format('ingest: a batch of 201 is refused (%s)', sqlerrm));
  end;

  begin
    perform public.ingest_location_points('{"not":"an array"}'::jsonb);
    perform pg_temp.check(false, 'ingest: a non-array body was accepted');
  exception when others then
    perform pg_temp.check(sqlerrm = 'invalid_batch', format('ingest: a non-array body is refused (%s)', sqlerrm));
  end;

  ---------------------------------------------------------------------------
  -- B. The marker follows the newest point and never goes backwards
  ---------------------------------------------------------------------------
  v_res := public.ingest_location_points(jsonb_build_array(
    pg_temp.pt('m3-old', v_s1, 20.0025, now() - interval '75 minutes')
  ));
  perform pg_temp.act_as_server();
  select latitude into v_lat from public.live_locations where employee_id = v_e1;
  perform pg_temp.check(
    (v_res ->> 'accepted')::int = 1 and abs(v_lat - 20.003) < 0.000001,
    format('marker: a late OLDER point is stored but does not move the marker back (lat %s)', v_lat));

  ---------------------------------------------------------------------------
  -- C. Ending duty: the phone's end time is believed only within the evidence
  ---------------------------------------------------------------------------
  select max(recorded_at) into v_last from public.location_points where session_id = v_s1;

  perform pg_temp.act_as(v_e1);
  update public.duty_sessions
     set status = 'completed', ended_at = now() + interval '3 hours'
   where id = v_s1;
  perform pg_temp.act_as_server();
  select ended_at, total_distance_km into v_ts, v_km from public.duty_sessions where id = v_s1;
  perform pg_temp.check(
    v_ts <= v_last + interval '5 minutes' and v_ts >= v_last and v_ts <= now(),
    format('end time: a phone claiming 3 h in the future is held to last point + 5 min (%s)', v_ts));
  perform pg_temp.check(
    v_km between 0.30 and 0.36,
    format('end time: distance is computed by the server (%s km)', v_km));

  -- E2 claims it ended before it started: held at the last point (the floor).
  select max(recorded_at) into v_last from public.location_points where session_id = v_s2;
  perform pg_temp.act_as(v_e2);
  update public.duty_sessions
     set status = 'completed', ended_at = now() - interval '10 days'
   where id = v_s2;
  perform pg_temp.act_as_server();
  select ended_at into v_ts from public.duty_sessions where id = v_s2;
  perform pg_temp.check(
    v_ts = v_last,
    format('end time: a claim from before the evidence is raised to the last point (%s vs %s)', v_ts, v_last));

  ---------------------------------------------------------------------------
  -- D. A late upload into a session that already ended
  ---------------------------------------------------------------------------
  select total_distance_km into v_km from public.duty_sessions where id = v_s1;

  perform pg_temp.act_as(v_e1);
  v_res := public.ingest_location_points(jsonb_build_array(
    pg_temp.pt('m3-late', v_s1, 20.004, now() - interval '57 minutes')
  ));
  perform pg_temp.act_as_server();
  select total_distance_km into v_km2 from public.duty_sessions where id = v_s1;
  perform pg_temp.check(
    (v_res ->> 'accepted')::int = 1 and v_km2 - v_km between 0.09 and 0.13,
    format('late upload: distance of the closed session grows by the new leg (%s -> %s km)', v_km, v_km2));
  perform pg_temp.check(
    not exists (select 1 from public.live_locations where employee_id = v_e1),
    'late upload: no ghost marker is created for an employee who is off duty');

  perform pg_temp.act_as(v_e1);
  begin
    update public.duty_sessions set total_distance_km = 1 where id = v_s1;
    perform pg_temp.check(false, 'late upload: the employee edited the closed session');
  exception when others then
    perform pg_temp.check(sqlerrm = 'session_already_closed',
      format('late upload: the employee still cannot edit the closed session (%s)', sqlerrm));
  end;
  perform pg_temp.act_as_server();

  ---------------------------------------------------------------------------
  -- E. Blocking an employee who is on duty
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_admin);
  update public.profiles set status = 'blocked', blocked_reason = 'm3 attack test' where id = v_e3;
  perform pg_temp.act_as_server();

  select status, end_reason, ended_at, total_distance_km
    into v_status, v_reason, v_ts, v_km
  from public.duty_sessions where id = v_s3;
  perform pg_temp.check(
    v_status = 'blocked' and v_reason = 'blocked' and v_ts is not null and v_ts <= now(),
    format('block: the open session is closed with reason blocked (%s / %s)', v_status, v_reason));
  perform pg_temp.check(v_km > 0, format('block: the closed session has its distance (%s km)', v_km));
  perform pg_temp.check(
    not exists (select 1 from public.live_locations where employee_id = v_e3),
    'block: the blocked employee disappears from the live map');
  perform pg_temp.check(
    exists (select 1 from public.audit_log
            where action = 'employee_blocked' and target_id = v_e3 and actor_id = v_admin),
    'block: still written to the audit log');

  ---------------------------------------------------------------------------
  -- F. 23:00 IST auto-end for a session the phone never closed
  ---------------------------------------------------------------------------
  perform private.auto_end_open_sessions();
  select status, end_reason, notes, ended_at, total_distance_km
    into v_status, v_reason, v_note, v_ts, v_km
  from public.duty_sessions where id = v_s4;
  perform pg_temp.check(
    v_status = 'auto_curfew' and v_reason = 'auto_curfew' and v_note = 'Duty ended automatically',
    format('auto-end: yesterday''s open session is closed as auto_curfew (%s)', v_status));
  perform pg_temp.check(
    v_ts = private.curfew_at(v_yesterday_start),
    format('auto-end: it ends at 23:00 IST of its own day, not at "now" (%s)', v_ts));
  perform pg_temp.check(v_km > 0, format('auto-end: distance computed (%s km)', v_km));
  perform pg_temp.check(
    not exists (select 1 from public.live_locations where employee_id = v_e4),
    'auto-end: the marker is removed');

  perform private.auto_end_open_sessions();
  select ended_at into v_ts2 from public.duty_sessions where id = v_s4;
  perform pg_temp.check(v_ts2 = v_ts, 'auto-end: running it again changes nothing (idempotent)');

  ---------------------------------------------------------------------------
  -- G. Who may call what
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);
  begin
    perform private.close_session(v_s2, 'completed', 'normal', null, now());
    perform pg_temp.check(false, 'access: an employee called private.close_session');
  exception when others then
    perform pg_temp.check(true, format('access: an employee cannot call private.close_session (%s)', sqlerrm));
  end;
  begin
    perform private.auto_end_open_sessions();
    perform pg_temp.check(false, 'access: an employee called private.auto_end_open_sessions');
  exception when others then
    perform pg_temp.check(true, format('access: an employee cannot trigger the auto-end (%s)', sqlerrm));
  end;

  select public.server_time() into v_ts;
  perform pg_temp.check(
    abs(extract(epoch from (now() - v_ts))) < 5,
    'server_time: a signed-in employee gets the server clock');

  perform pg_temp.act_as_anon();
  begin
    perform public.ingest_location_points('[]'::jsonb);
    perform pg_temp.check(false, 'access: a signed-out visitor called ingest_location_points');
  exception when others then
    perform pg_temp.check(true, format('access: a signed-out visitor cannot ingest points (%s)', sqlerrm));
  end;
  begin
    perform public.server_time();
    perform pg_temp.check(false, 'access: a signed-out visitor called server_time');
  exception when others then
    perform pg_temp.check(true, format('access: a signed-out visitor cannot call server_time (%s)', sqlerrm));
  end;

  ---------------------------------------------------------------------------
  -- Report: always end with an exception; it carries the report AND rolls back
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();
  raise exception E'M3 ATTACK CHECK REPORT (intentional error: rolls everything back)\n%\n\nRESULT: % passed, % failed\n%',
    current_setting('attack.report', true),
    regexp_count(current_setting('attack.report', true), E'\nPASS  '),
    regexp_count(current_setting('attack.report', true), E'\nFAIL  '),
    case when regexp_count(current_setting('attack.report', true), E'\nFAIL  ') > 0
         then '>>> DO NOT RELY ON THIS MIGRATION <<<' else '>>> ALL CHECKS PASSED <<<' end;
end $$;

rollback;
