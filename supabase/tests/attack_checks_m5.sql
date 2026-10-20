-- =============================================================================
-- Attack checks for 20261019175510_duty_session_text_limits.sql
--
-- Run AFTER the migration is applied, in the Supabase SQL editor, in its own tab.
-- Everything it creates is rolled back by the intentional error at the end.
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

create or replace function pg_temp.act_as_server() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'postgres', true);
end $$;

do $$
declare
  v_e1 uuid := gen_random_uuid();
  v_e2 uuid := gen_random_uuid();
  v_e3 uuid := gen_random_uuid();
  v_e4 uuid := gen_random_uuid();
  v_e5 uuid := gen_random_uuid();
  v_s1 uuid := gen_random_uuid();
  v_s2 uuid := gen_random_uuid();
  v_s3 uuid := gen_random_uuid();
  v_s4 uuid := gen_random_uuid();
  v_s5 uuid := gen_random_uuid();
  v_reason text;
  v_len    int;
begin
  perform pg_temp.act_as_server();

  -- One open session per employee is allowed, so each check gets its own.
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                          created_at, updated_at)
  select e, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'm5-00' || n || '@staff.test.invalid', 'x', now(),
         json_build_object('role', 'employee')::jsonb, '{}', now(), now()
  from unnest(array[v_e1, v_e2, v_e3, v_e4, v_e5]) with ordinality as t(e, n);
  insert into public.profiles (id, email, role, status, full_name, employee_code, phone, must_change_pin)
  select e, 'm5-00' || n || '@staff.test.invalid', 'employee', 'active', 'M5 Test ' || n,
         'M5-00' || n, '+910000012345' || n, false
  from unnest(array[v_e1, v_e2, v_e3, v_e4, v_e5]) with ordinality as t(e, n);

  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s1, v_e1, 'open', now() - interval '3 hours'),
         (v_s2, v_e2, 'open', now() - interval '3 hours'),
         (v_s3, v_e3, 'open', now() - interval '3 hours'),
         (v_s4, v_e4, 'open', now() - interval '3 hours'),
         (v_s5, v_e5, 'open', now() - interval '1 hour');

  -- 1. An employee cannot write an invented end_reason.
  perform pg_temp.act_as(v_e1);
  begin
    update public.duty_sessions
       set status = 'completed', ended_at = now(), end_reason = 'because i said so'
     where id = v_s1;
    perform pg_temp.check(false, 'end_reason: an invented value was stored');
  exception when check_violation then
    perform pg_temp.check(true, 'end_reason: an invented value is refused');
  end;

  -- 2. An employee cannot write a 201-character note.
  begin
    update public.duty_sessions
       set status = 'completed', ended_at = now(), end_reason = 'normal', notes = repeat('x', 201)
     where id = v_s1;
    perform pg_temp.check(false, 'notes: 201 characters were stored');
  exception when check_violation then
    perform pg_temp.check(true, 'notes: 201 characters are refused');
  end;

  -- 3. A normal end with a 200-character note still works.
  perform pg_temp.act_as(v_e2);
  update public.duty_sessions
     set status = 'completed', ended_at = now(), end_reason = 'normal', notes = repeat('x', 200)
   where id = v_s2;
  perform pg_temp.act_as_server();
  select end_reason, char_length(notes) into v_reason, v_len from public.duty_sessions where id = v_s2;
  perform pg_temp.check(v_reason = 'normal' and v_len = 200,
    'a normal end with a 200-character note is accepted');

  -- 4. A normal end with no note still works (what the app sends today).
  perform pg_temp.act_as(v_e3);
  update public.duty_sessions
     set status = 'completed', ended_at = now(), end_reason = 'normal'
   where id = v_s3;
  perform pg_temp.act_as_server();
  select end_reason into v_reason from public.duty_sessions where id = v_s3;
  perform pg_temp.check(v_reason = 'normal', 'a normal end with no note is accepted');

  -- 5. The system's own end reasons are accepted.
  perform private.close_session(v_s4, 'auto_curfew', 'auto_curfew', 'Duty ended automatically', now());
  select end_reason into v_reason from public.duty_sessions where id = v_s4;
  perform pg_temp.check(v_reason = 'auto_curfew', 'the 23:00 auto-end is accepted');

  perform private.close_session(v_s5, 'blocked', 'blocked', 'Closed because the account was blocked', now());
  select end_reason into v_reason from public.duty_sessions where id = v_s5;
  perform pg_temp.check(v_reason = 'blocked', 'the block-closes-duty end is accepted');

  -- 6. The constraints exist and are validated.
  perform pg_temp.check(
    (select count(*) from pg_constraint
      where conrelid = 'public.duty_sessions'::regclass
        and conname in ('duty_sessions_end_reason_check', 'duty_sessions_notes_length_check')
        and convalidated) = 2,
    'both constraints exist and cover every existing row');

  perform pg_temp.act_as_server();
  raise exception E'M5 ATTACK CHECK REPORT (intentional error: rolls everything back)\n%\n\nRESULT: % passed, % failed\n%',
    current_setting('attack.report', true),
    regexp_count(current_setting('attack.report', true), E'\nPASS  '),
    regexp_count(current_setting('attack.report', true), E'\nFAIL  '),
    case when regexp_count(current_setting('attack.report', true), E'\nFAIL  ') > 0
         then '>>> DO NOT RELY ON THIS MIGRATION <<<' else '>>> ALL CHECKS PASSED <<<' end;
end $$;

rollback;
