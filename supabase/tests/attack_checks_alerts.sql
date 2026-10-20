-- =============================================================================
-- Attack checks for 20261020020000_security_and_operational_alerts.sql
--
-- Run AFTER the migration is applied, in the Supabase SQL editor.
-- Everything it creates is rolled back by the intentional error at the end.
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
  v_emp      uuid := gen_random_uuid();
  v_session  uuid := gen_random_uuid();
  v_res_b    boolean;
  v_res_j    jsonb;
  v_notif    record;
  v_err      boolean;
begin
  -- Setup test employee
  perform pg_temp.act_as_server();

  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                          created_at, updated_at)
  values (v_emp, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'da99@diamondagritech.in', 'x', now(),
          '{"role": "employee"}'::jsonb, '{}', now(), now());

  insert into public.profiles (id, role, status, employee_code, full_name, phone, email, must_change_pin, device_id)
  values (v_emp, 'employee', 'active', 'DA-TEST99', 'Test Alerts Employee', '+919800099999', 'da99@diamondagritech.in', false, 'phone-registered');

  insert into private.employee_pins (user_id, pin_hash)
  values (v_emp, extensions.crypt('123456', extensions.gen_salt('bf', 10)));

  -- ---------------------------------------------------------------------------
  -- 1. notifications_type_check constraint tests
  -- ---------------------------------------------------------------------------
  v_err := false;
  begin
    insert into public.notifications (type, employee_id, dedupe_key)
    values ('malicious_type', v_emp, 'bad_type_test');
  exception when check_violation then
    v_err := true;
  end;
  perform pg_temp.check(v_err, 'notifications table rejects unknown types');

  -- ---------------------------------------------------------------------------
  -- 2. new_device_login alert test via bind_my_device
  -- ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_emp);
  -- Try binding with same device: should succeed, no notification
  v_res_b := public.bind_my_device('phone-registered');
  perform pg_temp.check(v_res_b, 'bind_my_device with matching device returns true');

  perform pg_temp.act_as_server();
  select * into v_notif from public.notifications where employee_id = v_emp and type = 'new_device_login';
  perform pg_temp.check(not found, 'no new_device_login notification on matching device');

  -- Try binding with different device: should return false, write new_device_login
  perform pg_temp.act_as(v_emp);
  v_res_b := public.bind_my_device('phone-stolen-unregistered');
  perform pg_temp.check(not v_res_b, 'bind_my_device with mismatched device returns false');

  perform pg_temp.act_as_server();
  select * into v_notif from public.notifications where employee_id = v_emp and type = 'new_device_login';
  perform pg_temp.check(found and (v_notif.details->>'attempted_device_id') = 'phone-stolen-unregistered',
    'new_device_login notification created with attempted device ID');

  -- ---------------------------------------------------------------------------
  -- 3. failed_login alert test via employee_login_check
  -- ---------------------------------------------------------------------------
  -- Attempt 1: wrong PIN
  v_res_j := public.employee_login_check('DA-TEST99', '000000');
  perform pg_temp.check((v_res_j->>'result') = 'invalid', 'attempt 1 returns invalid');

  -- Attempt 2: wrong PIN
  v_res_j := public.employee_login_check('DA-TEST99', '000000');
  perform pg_temp.check((v_res_j->>'result') = 'invalid', 'attempt 2 returns invalid');

  select * into v_notif from public.notifications where employee_id = v_emp and type = 'failed_login';
  perform pg_temp.check(not found, 'no failed_login notification before threshold');

  -- Attempt 3: threshold reached -> triggers failed_login
  v_res_j := public.employee_login_check('DA-TEST99', '000000');
  perform pg_temp.check((v_res_j->>'result') = 'invalid', 'attempt 3 returns invalid');

  select * into v_notif from public.notifications where employee_id = v_emp and type = 'failed_login';
  perform pg_temp.check(found and (v_notif.details->>'attempts')::int = 3,
    'failed_login notification created at 3 attempts');

  -- ---------------------------------------------------------------------------
  -- 4. gps_disabled alert test via report_gps_status
  -- ---------------------------------------------------------------------------
  -- Off duty: should return false, no notification
  perform pg_temp.act_as(v_emp);
  v_res_b := public.report_gps_status(false);
  perform pg_temp.check(not v_res_b, 'report_gps_status returns false when not on duty');

  perform pg_temp.act_as_server();
  select * into v_notif from public.notifications where employee_id = v_emp and type = 'gps_disabled';
  perform pg_temp.check(not found, 'no gps_disabled notification when off duty');

  -- Start open duty session
  insert into public.duty_sessions (id, employee_id, started_at, status)
  values (v_session, v_emp, now(), 'open');

  -- On duty: report GPS enabled -> returns true, no notification
  perform pg_temp.act_as(v_emp);
  v_res_b := public.report_gps_status(true);
  perform pg_temp.check(v_res_b, 'report_gps_status(true) returns true');

  perform pg_temp.act_as_server();
  select * into v_notif from public.notifications where employee_id = v_emp and type = 'gps_disabled';
  perform pg_temp.check(not found, 'no notification when GPS is enabled');

  -- On duty: report GPS disabled -> returns true, writes gps_disabled
  perform pg_temp.act_as(v_emp);
  v_res_b := public.report_gps_status(false);
  perform pg_temp.check(v_res_b, 'report_gps_status(false) returns true on duty');

  perform pg_temp.act_as_server();
  select * into v_notif from public.notifications where employee_id = v_emp and type = 'gps_disabled';
  perform pg_temp.check(found and v_notif.session_id = v_session,
    'gps_disabled notification created for active session');

  -- ---------------------------------------------------------------------------
  -- 5. RLS write protection on notifications table
  -- ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_emp);
  v_err := false;
  begin
    insert into public.notifications (type, employee_id, dedupe_key)
    values ('duty_on', v_emp, 'rogue_write');
  exception when others then
    v_err := true;
  end;
  perform pg_temp.check(v_err, 'authenticated employee cannot directly insert into notifications');
end $$;

-- Complete report and force rollback
do $$
declare
  v_report text := current_setting('attack.report', true);
  v_fails  int;
begin
  v_fails := cardinality(array(
    select 1 from regexp_matches(v_report, '^FAIL', 'gn')
  ));
  raise exception E'\n==== ATTACK CHECKS REPORT ====%s\n==== RESULT: % / % ====',
    v_report,
    case when v_fails = 0 then 'ALL PASSED' else v_fails || ' FAILED' end,
    case when v_fails = 0 then 'READY FOR DEPLOY' else 'BLOCKED' end;
end $$;

rollback;
