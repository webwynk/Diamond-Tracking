-- =============================================================================
-- Attack checks for 20261017050000_admin_session_distance.sql
--
-- Run AFTER the migration is applied, in the Supabase SQL editor, in its own tab.
--
-- HOW TO READ THE RESULT
--   The script ends with an intentional error whose text is the full report:
--   one PASS or FAIL line per check, then a RESULT line. The error is how
--   everything the script created (test users, sessions, points) is rolled
--   back, so it leaves nothing behind. Any FAIL means: do not rely on the
--   migration. (docs/05 section 4: "Policies are not trusted until attacked.")
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
  v_admin   uuid := gen_random_uuid();
  v_blocked uuid := gen_random_uuid();
  v_e1      uuid := gen_random_uuid();
  v_s1      uuid := gen_random_uuid();
  v_s_empty uuid := gen_random_uuid();
  v_km      numeric;
  v_stored  numeric;
  v_msg     text;
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
     'rt-admin@test.invalid', 'x', now(), '{"role":"admin"}', '{}', now(), now()),
    (v_blocked, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'rt-blocked@test.invalid', 'x', now(), '{"role":"admin"}', '{}', now(), now()),
    (v_e1, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'rt-001@staff.test.invalid', 'x', now(), '{"role":"employee"}', '{}', now(), now());

  insert into public.profiles (id, email, role, status, full_name, must_change_pin)
  values
    (v_admin, 'rt-admin@test.invalid', 'admin', 'active', 'RT Admin', false),
    (v_blocked, 'rt-blocked@test.invalid', 'admin', 'blocked', 'RT Blocked Admin', false);
  insert into public.profiles (id, email, role, status, full_name, employee_code, phone, must_change_pin)
  values (v_e1, 'rt-001@staff.test.invalid', 'employee', 'active', 'RT One', 'RT-001', '+910000000021', true);

  -- An open session of three points, 90..88 minutes ago, ~111 m apart: about
  -- 0.222 km. An open session has no stored distance yet.
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s1, v_e1, 'open', now() - interval '3 hours');
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, recorded_at)
  values
    ('rt-a1', v_s1, v_e1, 20.000, 73.0, 5, now() - interval '90 minutes'),
    ('rt-a2', v_s1, v_e1, 20.001, 73.0, 5, now() - interval '89 minutes'),
    ('rt-a3', v_s1, v_e1, 20.002, 73.0, 5, now() - interval '88 minutes');

  -- A mock point and a poor reading must not count (the server's rule).
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, is_mock, recorded_at)
  values
    ('rt-m1', v_s1, v_e1, 21.500, 73.0, 5, true, now() - interval '87 minutes');
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, recorded_at)
  values
    ('rt-p1', v_s1, v_e1, 22.500, 73.0, 250, now() - interval '86 minutes');

  -- A session with no points at all.
  insert into public.duty_sessions (id, employee_id, status, started_at, ended_at)
  values (v_s_empty, v_e1, 'completed', now() - interval '2 days', now() - interval '2 days' + interval '1 hour');

  ---------------------------------------------------------------------------
  -- An active admin
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_admin);
  v_km := public.admin_session_distance(v_s1);
  perform pg_temp.check(
    v_km between 0.20 and 0.24,
    format('admin: the running distance of an open session is computed (%s km)', v_km));
  perform pg_temp.check(
    v_km < 1,
    'admin: the mock point and the 250 m reading are left out of the distance');
  perform pg_temp.check(
    public.admin_session_distance(v_s_empty) = 0,
    'admin: a session without points is 0 km, not an error');
  perform pg_temp.check(
    public.admin_session_distance(gen_random_uuid()) = 0,
    'admin: an unknown session is 0 km and reveals nothing');

  ---------------------------------------------------------------------------
  -- It reconciles with the figure stored when the session closes
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);
  update public.duty_sessions
     set status = 'completed', ended_at = now() - interval '80 minutes'
   where id = v_s1;
  perform pg_temp.act_as_server();
  select total_distance_km into v_stored from public.duty_sessions where id = v_s1;
  perform pg_temp.act_as(v_admin);
  v_km := public.admin_session_distance(v_s1);
  perform pg_temp.check(
    v_stored = v_km,
    format('reconcile: the running figure equals the stored total after closing (%s vs %s)', v_km, v_stored));

  ---------------------------------------------------------------------------
  -- Everyone else is refused
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);
  begin
    perform public.admin_session_distance(v_s1);
    perform pg_temp.check(false, 'access: an employee read a session distance');
  exception when others then
    v_msg := sqlerrm;
    perform pg_temp.check(v_msg = 'forbidden', format('access: an employee is refused (%s)', v_msg));
  end;

  perform pg_temp.act_as(v_blocked);
  begin
    perform public.admin_session_distance(v_s1);
    perform pg_temp.check(false, 'access: a blocked admin read a session distance');
  exception when others then
    v_msg := sqlerrm;
    perform pg_temp.check(v_msg = 'forbidden', format('access: a blocked admin is refused (%s)', v_msg));
  end;

  perform pg_temp.act_as_anon();
  begin
    perform public.admin_session_distance(v_s1);
    perform pg_temp.check(false, 'access: a signed-out visitor read a session distance');
  exception when others then
    v_msg := sqlerrm;
    perform pg_temp.check(v_msg like 'permission denied for function admin_session_distance%',
      format('access: a signed-out visitor is refused (%s)', v_msg));
  end;

  perform pg_temp.act_as(v_admin);
  begin
    perform private.session_distance_km(v_s1);
    perform pg_temp.check(false, 'access: an admin called the private helper directly');
  exception when others then
    perform pg_temp.check(true, format('access: the private helper stays unreachable from the API (%s)', sqlerrm));
  end;

  ---------------------------------------------------------------------------
  -- Report: always end with an exception; it carries the report AND rolls back
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();
  raise exception E'ROUTE ATTACK CHECK REPORT (intentional error: rolls everything back)\n%\n\nRESULT: % passed, % failed\n%',
    current_setting('attack.report', true),
    regexp_count(current_setting('attack.report', true), E'\nPASS  '),
    regexp_count(current_setting('attack.report', true), E'\nFAIL  '),
    case when regexp_count(current_setting('attack.report', true), E'\nFAIL  ') > 0
         then '>>> DO NOT RELY ON THIS MIGRATION <<<' else '>>> ALL CHECKS PASSED <<<' end;
end $$;

rollback;
