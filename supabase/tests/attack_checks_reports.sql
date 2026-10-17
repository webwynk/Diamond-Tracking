-- =============================================================================
-- Attack checks for 20261017090000_log_report_export.sql
--
-- Run AFTER the migration is applied, in the Supabase SQL editor, in its own tab.
--
-- HOW TO READ THE RESULT
--   The script ends with an intentional error whose text is the full report:
--   one PASS or FAIL line per check, then a RESULT line. The error is how
--   everything the script created (test users, audit rows) is rolled back, so it
--   leaves nothing behind. Any FAIL means: do not rely on the migration.
--   (docs/05 section 4: "Policies are not trusted until attacked.")
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

-- Calls the function and reports whether it was refused with the given text.
create or replace function pg_temp.refused(
  p_label text, p_type text, p_from date, p_to date, p_format text,
  p_employee uuid, p_expect text)
returns void
language plpgsql as $$
declare
  v_msg text;
begin
  perform public.log_report_export(p_type, p_from, p_to, p_format, p_employee);
  perform pg_temp.check(false, p_label || ' (was accepted)');
exception when others then
  v_msg := sqlerrm;
  perform pg_temp.check(v_msg like p_expect, format('%s (%s)', p_label, v_msg));
end $$;

do $$
declare
  v_admin   uuid := gen_random_uuid();
  v_blocked uuid := gen_random_uuid();
  v_e1      uuid := gen_random_uuid();
  v_before  bigint;
  v_rows    bigint;
  v_row     record;
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
     'rp-admin@test.invalid', 'x', now(), '{"role":"admin"}', '{}', now(), now()),
    (v_blocked, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'rp-blocked@test.invalid', 'x', now(), '{"role":"admin"}', '{}', now(), now()),
    (v_e1, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'rp-001@staff.test.invalid', 'x', now(), '{"role":"employee"}', '{}', now(), now());

  insert into public.profiles (id, email, role, status, full_name, must_change_pin)
  values
    (v_admin, 'rp-admin@test.invalid', 'admin', 'active', 'RP Admin', false),
    (v_blocked, 'rp-blocked@test.invalid', 'admin', 'blocked', 'RP Blocked Admin', false);
  insert into public.profiles (id, email, role, status, full_name, employee_code, phone, must_change_pin)
  values (v_e1, 'rp-001@staff.test.invalid', 'employee', 'active', 'RP One', 'RP-001', '+910000000031', true);

  select count(*) into v_before from public.audit_log where action = 'report_exported';

  ---------------------------------------------------------------------------
  -- An active admin: each report type writes exactly one row, as themselves
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_admin);
  perform public.log_report_export('team_summary', date '2026-10-01', date '2026-10-17', 'pdf');
  perform public.log_report_export('daily_detail', date '2026-10-16', date '2026-10-16', 'pdf');
  perform public.log_report_export('employee_summary', date '2026-09-01', date '2026-10-17', 'pdf', v_e1);

  select count(*) into v_rows from public.audit_log
   where action = 'report_exported' and actor_id = v_admin;
  perform pg_temp.check(v_rows = 3, format('admin: three exports wrote three rows as the admin (%s)', v_rows));

  select * into v_row from public.audit_log
   where action = 'report_exported' and details ->> 'type' = 'employee_summary' and actor_id = v_admin;
  perform pg_temp.check(v_row.target_id = v_e1, 'admin: the employee is the target of an employee summary');
  perform pg_temp.check(v_row.details ->> 'employee_code' = 'RP-001', 'admin: the employee code is in the details');
  perform pg_temp.check(v_row.details ->> 'from' = '2026-09-01' and v_row.details ->> 'to' = '2026-10-17',
    'admin: the period is in the details');
  perform pg_temp.check(v_row.details ->> 'format' = 'pdf', 'admin: the format is in the details');

  select * into v_row from public.audit_log
   where action = 'report_exported' and details ->> 'type' = 'team_summary' and actor_id = v_admin;
  perform pg_temp.check(v_row.target_id is null and not (v_row.details ? 'employee_code'),
    'admin: a team report has no target and no employee code');

  perform public.log_report_export('team_summary', date '2026-07-02', date '2026-10-01', 'excel');
  perform pg_temp.check(true, 'admin: the longest range (92 days) and the excel format are accepted');

  ---------------------------------------------------------------------------
  -- An active admin with bad input: refused, and nothing is written
  ---------------------------------------------------------------------------
  select count(*) into v_before from public.audit_log where action = 'report_exported';

  perform pg_temp.refused('input: an unknown report type', 'visit_log', date '2026-10-01', date '2026-10-02', 'pdf', null, 'invalid_report');
  perform pg_temp.refused('input: no report type', null, date '2026-10-01', date '2026-10-02', 'pdf', null, 'invalid_report');
  perform pg_temp.refused('input: an unknown format', 'team_summary', date '2026-10-01', date '2026-10-02', 'docx', null, 'invalid_report');
  perform pg_temp.refused('input: the end before the start', 'team_summary', date '2026-10-05', date '2026-10-01', 'pdf', null, 'invalid_report');
  perform pg_temp.refused('input: no dates', 'team_summary', null, null, 'pdf', null, 'invalid_report');
  perform pg_temp.refused('input: a range of 93 days', 'team_summary', date '2026-07-01', date '2026-10-01', 'pdf', null, 'invalid_report');
  perform pg_temp.refused('input: a daily report over several days', 'daily_detail', date '2026-10-01', date '2026-10-03', 'pdf', null, 'invalid_report');
  perform pg_temp.refused('input: an employee summary without an employee', 'employee_summary', date '2026-10-01', date '2026-10-03', 'pdf', null, 'invalid_report');
  perform pg_temp.refused('input: an employee summary for an unknown person', 'employee_summary', date '2026-10-01', date '2026-10-03', 'pdf', gen_random_uuid(), 'invalid_report');
  perform pg_temp.refused('input: an employee summary for an admin', 'employee_summary', date '2026-10-01', date '2026-10-03', 'pdf', v_admin, 'invalid_report');
  perform pg_temp.refused('input: a team report naming an employee', 'team_summary', date '2026-10-01', date '2026-10-03', 'pdf', v_e1, 'invalid_report');

  select count(*) into v_rows from public.audit_log where action = 'report_exported';
  perform pg_temp.check(v_rows = v_before, 'input: nothing was written by any refused call');

  ---------------------------------------------------------------------------
  -- Everyone else is refused, and nothing is written
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);
  perform pg_temp.refused('access: an employee is refused', 'team_summary', date '2026-10-01', date '2026-10-02', 'pdf', null, 'forbidden');

  perform pg_temp.act_as(v_blocked);
  perform pg_temp.refused('access: a blocked admin is refused', 'team_summary', date '2026-10-01', date '2026-10-02', 'pdf', null, 'forbidden');

  perform pg_temp.act_as_anon();
  perform pg_temp.refused('access: a signed-out visitor is refused', 'team_summary', date '2026-10-01', date '2026-10-02', 'pdf', null, 'permission denied for function log_report_export%');

  perform pg_temp.act_as_server();
  select count(*) into v_rows from public.audit_log where action = 'report_exported';
  perform pg_temp.check(v_rows = v_before, 'access: nothing was written for an employee, a blocked admin or a visitor');

  ---------------------------------------------------------------------------
  -- The log itself stays closed to direct writes
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_admin);
  begin
    insert into public.audit_log (actor_id, action) values (v_admin, 'report_exported');
    perform pg_temp.check(false, 'closed: an admin wrote to the audit log directly');
  exception when others then
    perform pg_temp.check(true, format('closed: the audit log refuses a direct insert (%s)', sqlerrm));
  end;

  perform pg_temp.act_as(v_e1);
  select count(*) into v_rows from public.audit_log;
  perform pg_temp.check(v_rows = 0, 'closed: an employee reads no audit rows');

  ---------------------------------------------------------------------------
  -- Report: always end with an exception; it carries the report AND rolls back
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();
  raise exception E'REPORTS ATTACK CHECK REPORT (intentional error: rolls everything back)\n%\n\nRESULT: % passed, % failed\n%',
    current_setting('attack.report', true),
    regexp_count(current_setting('attack.report', true), E'\nPASS  '),
    regexp_count(current_setting('attack.report', true), E'\nFAIL  '),
    case when regexp_count(current_setting('attack.report', true), E'\nFAIL  ') > 0
         then '>>> DO NOT RELY ON THIS MIGRATION <<<' else '>>> ALL CHECKS PASSED <<<' end;
end $$;

rollback;
