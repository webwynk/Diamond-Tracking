-- =============================================================================
-- Attack checks for 20261017060000_location_points_retention.sql
--
-- Run AFTER the migration is applied, in the Supabase SQL editor, in its own tab.
--
-- This script runs the REAL purge function, so it can delete real rows older than
-- 30 days inside its own transaction. That transaction is always rolled back (the
-- intentional error at the end), so nothing it creates OR deletes is kept.
--
-- HOW TO READ THE RESULT
--   The script ends with an intentional error whose text is the full report:
--   one PASS or FAIL line per check, then a RESULT line. Any FAIL means: do not
--   rely on the migration. (docs/05 section 4: "Policies are not trusted until
--   attacked.")
-- =============================================================================
begin;

create or replace function pg_temp.note(p_line text) returns void
language plpgsql as $$
begin
  perform set_config('attack.report',
    coalesce(current_setting('attack.report', true), '') || E'\n' || p_line, true);
end $$;

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

do $$
declare
  v_e1      uuid := gen_random_uuid();
  v_cut     timestamptz;
  v_s_old   uuid := gen_random_uuid();  -- closed, 45 days ago
  v_s_before uuid := gen_random_uuid(); -- closed, the IST day before the cut
  v_s_on    uuid := gen_random_uuid();  -- closed, the first IST day kept
  v_s_new   uuid := gen_random_uuid();  -- closed, recent
  v_s_open  uuid := gen_random_uuid();  -- still open, but old points
  v_km_before numeric;
  v_km_after  numeric;
  v_hours_before timestamptz;
  v_deleted int;
  v_again   int;
  v_audits  int;
  v_res     jsonb;
  v_msg     text;
  v_tmp     timestamptz;
begin
  ---------------------------------------------------------------------------
  -- Fixtures (as the server). Each session starts 10:00 IST on its day.
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();
  v_cut := private.points_retention_cutoff();

  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                          created_at, updated_at)
  values (v_e1, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'rp-001@staff.test.invalid', 'x', now(), '{"role":"employee"}', '{}', now(), now());
  insert into public.profiles (id, email, role, status, full_name, employee_code, phone, must_change_pin)
  values (v_e1, 'rp-001@staff.test.invalid', 'employee', 'active', 'RP One', 'RP-001', '+910000000031', true);

  -- 45 days ago (cut day minus 15): everything is old.
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s_old, v_e1, 'open', v_cut - interval '15 days' + interval '10 hours');
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, recorded_at)
  values
    ('rp-old-1', v_s_old, v_e1, 20.000, 73.0, 5, v_cut - interval '15 days' + interval '10 hours 10 minutes'),
    ('rp-old-2', v_s_old, v_e1, 20.001, 73.0, 5, v_cut - interval '15 days' + interval '10 hours 11 minutes'),
    ('rp-old-3', v_s_old, v_e1, 20.002, 73.0, 5, v_cut - interval '15 days' + interval '10 hours 12 minutes');
  perform pg_temp.act_as(v_e1);
  update public.duty_sessions set status = 'completed',
         ended_at = v_cut - interval '15 days' + interval '12 hours'
   where id = v_s_old;
  perform pg_temp.act_as_server();

  -- The IST day just before the cut: deleted.
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s_before, v_e1, 'open', v_cut - interval '1 day' + interval '10 hours');
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, recorded_at)
  values
    ('rp-before-1', v_s_before, v_e1, 21.000, 73.0, 5, v_cut - interval '1 day' + interval '10 hours 10 minutes');
  perform pg_temp.act_as(v_e1);
  update public.duty_sessions set status = 'completed',
         ended_at = v_cut - interval '1 day' + interval '12 hours'
   where id = v_s_before;
  perform pg_temp.act_as_server();

  -- The first IST day kept (the route view's oldest day): must survive.
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s_on, v_e1, 'open', v_cut + interval '10 hours');
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, recorded_at)
  values
    ('rp-on-1', v_s_on, v_e1, 22.000, 73.0, 5, v_cut + interval '10 hours 10 minutes'),
    ('rp-on-2', v_s_on, v_e1, 22.001, 73.0, 5, v_cut + interval '10 hours 11 minutes');
  perform pg_temp.act_as(v_e1);
  update public.duty_sessions set status = 'completed',
         ended_at = v_cut + interval '12 hours'
   where id = v_s_on;
  perform pg_temp.act_as_server();

  -- Recent: must survive.
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s_new, v_e1, 'open', v_cut + interval '28 days' + interval '10 hours');
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, recorded_at)
  values
    ('rp-new-1', v_s_new, v_e1, 23.000, 73.0, 5, v_cut + interval '28 days' + interval '10 hours 10 minutes');
  perform pg_temp.act_as(v_e1);
  update public.duty_sessions set status = 'completed',
         ended_at = v_cut + interval '28 days' + interval '12 hours'
   where id = v_s_new;
  perform pg_temp.act_as_server();

  -- A session that is still open (it should have been closed, but the rule is
  -- "never delete the points of an open session").
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s_open, v_e1, 'open', v_cut - interval '10 days' + interval '10 hours');
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, recorded_at)
  values
    ('rp-open-1', v_s_open, v_e1, 24.000, 73.0, 5, v_cut - interval '10 days' + interval '10 hours 10 minutes');

  -- Not tested: a point with no session. The column allows null, and the purge
  -- handles it, but the live-map trigger needs a session, so such a row cannot
  -- be inserted today.

  select total_distance_km, ended_at into v_km_before, v_hours_before
  from public.duty_sessions where id = v_s_old;

  ---------------------------------------------------------------------------
  -- The cut
  ---------------------------------------------------------------------------
  perform pg_temp.check(
    (v_cut at time zone 'Asia/Kolkata')::time = time '00:00'
      and v_cut <= now() - interval '30 days'
      and v_cut > now() - interval '31 days',
    format('cutoff: 00:00 IST, 30 to 31 days ago (%s)', v_cut));

  ---------------------------------------------------------------------------
  -- The purge itself
  ---------------------------------------------------------------------------
  select count(*) into v_audits from public.audit_log where action = 'location_points_purged';
  v_deleted := private.purge_old_location_points();

  perform pg_temp.check(
    v_deleted >= 4,
    format('purge: deleted at least the 4 old fixture points (deleted %s)', v_deleted));
  perform pg_temp.check(
    not exists (select 1 from public.location_points
                where id in ('rp-old-1', 'rp-old-2', 'rp-old-3', 'rp-before-1')),
    'purge: old points of closed sessions are gone');
  perform pg_temp.check(
    (select count(*) from public.location_points where id in ('rp-on-1', 'rp-on-2')) = 2,
    'purge: the first day kept (the route view''s oldest day) is complete, to the point');
  perform pg_temp.check(
    exists (select 1 from public.location_points where id = 'rp-new-1'),
    'purge: recent points are kept');
  perform pg_temp.check(
    exists (select 1 from public.location_points where id = 'rp-open-1'),
    'purge: the points of a session that is still open are never deleted');

  ---------------------------------------------------------------------------
  -- The permanent record is untouched
  ---------------------------------------------------------------------------
  select total_distance_km, ended_at into v_km_after, v_tmp
  from public.duty_sessions where id = v_s_old;
  perform pg_temp.check(
    v_km_after is not distinct from v_km_before and v_tmp is not distinct from v_hours_before
      and v_km_after > 0,
    format('record: the old session keeps its km and end time (%s km)', v_km_after));
  perform pg_temp.check(
    (select count(*) from public.duty_sessions
     where id in (v_s_old, v_s_before, v_s_on, v_s_new, v_s_open)) = 5,
    'record: no session was deleted');

  ---------------------------------------------------------------------------
  -- Observable and repeatable
  ---------------------------------------------------------------------------
  perform pg_temp.check(
    (select count(*) from public.audit_log where action = 'location_points_purged') = v_audits + 1
      and exists (select 1 from public.audit_log
                  where action = 'location_points_purged'
                    and (details ->> 'deleted')::int = v_deleted),
    'audit: the run is recorded with how many rows it deleted');

  v_again := private.purge_old_location_points();
  perform pg_temp.check(
    v_again = 0
      and (select count(*) from public.audit_log where action = 'location_points_purged') = v_audits + 1,
    'repeat: a second run deletes nothing and writes no second audit row');

  perform pg_temp.check(
    exists (select 1 from cron.job
            where jobname = 'purge-old-location-points' and active
              and schedule = '30 21 * * *'),
    'schedule: the nightly job exists, is active, and runs at 21:30 UTC (03:00 IST)');

  ---------------------------------------------------------------------------
  -- A phone can no longer upload a point that would be deleted tonight
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);
  v_res := public.ingest_location_points(jsonb_build_array(
    jsonb_build_object('id', 'rp-late-old', 'session_id', v_s_old, 'latitude', 20.5,
      'longitude', 73.0, 'accuracy', 5,
      'recorded_at', v_cut - interval '15 days' + interval '10 hours 30 minutes'),
    jsonb_build_object('id', 'rp-late-new', 'session_id', v_s_new, 'latitude', 23.5,
      'longitude', 73.0, 'accuracy', 5,
      'recorded_at', v_cut + interval '28 days' + interval '10 hours 12 minutes')
  ));
  perform pg_temp.check(
    exists (select 1 from jsonb_array_elements(v_res -> 'results') r
            where r ->> 'id' = 'rp-late-old' and r ->> 'status' = 'rejected'
              and r ->> 'reason' = 'point_expired'),
    'ingest: a point older than the cut is rejected as point_expired');
  perform pg_temp.check(
    exists (select 1 from jsonb_array_elements(v_res -> 'results') r
            where r ->> 'id' = 'rp-late-new' and r ->> 'status' = 'accepted'),
    'ingest: a late point inside the window is still accepted');
  perform pg_temp.act_as_server();
  perform pg_temp.check(
    (select total_distance_km from public.duty_sessions where id = v_s_old) is not distinct from v_km_before,
    'ingest: the refused point did not change the old session''s distance');

  ---------------------------------------------------------------------------
  -- Nobody but the server can run it
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);
  begin
    perform private.purge_old_location_points();
    perform pg_temp.check(false, 'access: an employee ran the purge');
  exception when others then
    perform pg_temp.check(true, format('access: an employee cannot run the purge (%s)', sqlerrm));
  end;
  begin
    perform private.points_retention_cutoff();
    perform pg_temp.check(false, 'access: an employee called the cutoff helper');
  exception when others then
    perform pg_temp.check(true, format('access: an employee cannot call the cutoff helper (%s)', sqlerrm));
  end;

  perform pg_temp.act_as_anon();
  begin
    perform private.purge_old_location_points();
    perform pg_temp.check(false, 'access: a signed-out visitor ran the purge');
  exception when others then
    perform pg_temp.check(true, format('access: a signed-out visitor cannot run the purge (%s)', sqlerrm));
  end;

  ---------------------------------------------------------------------------
  -- Report: always end with an exception; it carries the report AND rolls back
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();
  raise exception E'RETENTION ATTACK CHECK REPORT (intentional error: rolls everything back)\n%\n\nRESULT: % passed, % failed\n%',
    current_setting('attack.report', true),
    regexp_count(current_setting('attack.report', true), E'\nPASS  '),
    regexp_count(current_setting('attack.report', true), E'\nFAIL  '),
    case when regexp_count(current_setting('attack.report', true), E'\nFAIL  ') > 0
         then '>>> DO NOT RELY ON THIS MIGRATION <<<' else '>>> ALL CHECKS PASSED <<<' end;
end $$;

rollback;
