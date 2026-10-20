-- =============================================================================
-- Attack checks for 20261020000000_server_checked_pin.sql
--
-- Run AFTER the migration is applied, in the Supabase SQL editor, in its own tab.
-- (It writes throw-away users to the Auth tables, which is why it is run by the
-- project owner in the SQL editor.) Everything it creates is rolled back by the
-- intentional error at the end.
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

create or replace function pg_temp.act_as_service() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  perform set_config('role', 'service_role', true);
end $$;

create or replace function pg_temp.act_as_server() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'postgres', true);
end $$;

do $$
declare
  v_admin uuid := gen_random_uuid();
  v_e1    uuid := gen_random_uuid();   -- the one who gets locked
  v_e2    uuid := gen_random_uuid();   -- a bystander
  v_e3    uuid := gen_random_uuid();   -- no PIN set yet
  v_e4    uuid := gen_random_uuid();   -- blocked
  v_res   jsonb;
  v_res2  jsonb;
  v_n     int;
  v_text  text;
  v_pw1   text;
  v_pw2   text;
  v_hash  text;
  v_locked timestamptz;
begin
  perform pg_temp.act_as_server();

  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                          created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'pin-' || n || '@staff.test.invalid', 'x', now(),
         json_build_object('role', case when n = 1 then 'admin' else 'employee' end)::jsonb,
         '{}', now(), now()
  from unnest(array[v_admin, v_e1, v_e2, v_e3, v_e4]) with ordinality as t(u, n);

  insert into public.profiles (id, email, role, status, full_name, must_change_pin)
  values (v_admin, 'pin-1@staff.test.invalid', 'admin', 'active', 'PIN Admin', false);
  insert into public.profiles (id, email, role, status, full_name, employee_code, phone, must_change_pin)
  values
    (v_e1, 'pin-2@staff.test.invalid', 'employee', 'active',  'PIN Test 2', 'PN-002', '+910000088002', false),
    (v_e2, 'pin-3@staff.test.invalid', 'employee', 'active',  'PIN Test 3', 'PN-003', '+910000088003', false),
    (v_e3, 'pin-4@staff.test.invalid', 'employee', 'active',  'PIN Test 4', 'PN-004', '+910000088004', false),
    (v_e4, 'pin-5@staff.test.invalid', 'employee', 'blocked', 'PIN Test 5', 'PN-005', '+910000088005', false);

  perform pg_temp.check(
    exists (select 1 from vault.secrets where name = 'login_secret'),
    'setup: the login secret exists in the vault');

  ---------------------------------------------------------------------------
  -- A. The PIN rule
  ---------------------------------------------------------------------------
  perform pg_temp.check(
    private.pin_problem('482915') is null and private.pin_problem('135792') is null
      and private.pin_problem('907431') is null,
    'rule: ordinary PINs are accepted');
  perform pg_temp.check(
    private.pin_problem('12345') is not null and private.pin_problem('1234567') is not null
      and private.pin_problem('12345a') is not null and private.pin_problem(null) is not null
      and private.pin_problem('') is not null,
    'rule: wrong length, letters and empty are refused');
  perform pg_temp.check(
    private.pin_problem('111111') is not null and private.pin_problem('000000') is not null,
    'rule: one repeated digit is refused');
  perform pg_temp.check(
    private.pin_problem('123456') is not null and private.pin_problem('654321') is not null
      and private.pin_problem('012345') is not null and private.pin_problem('543210') is not null
      and private.pin_problem('890123') is not null and private.pin_problem('901234') is not null
      and private.pin_problem('109876') is not null,
    'rule: runs up or down, including ones that wrap round, are refused');
  perform pg_temp.check(
    private.pin_problem('123457') is null and private.pin_problem('121212') is null,
    'rule: almost-runs and patterns that are not runs are allowed');

  ---------------------------------------------------------------------------
  -- B. Setting a PIN (server key only)
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_service();
  perform public.set_employee_pin(v_e1, '482915', true);
  perform public.set_employee_pin(v_e2, '135792', false);
  perform public.set_employee_pin(v_e4, '482915', false);
  perform pg_temp.act_as_server();

  perform pg_temp.check(
    (select must_change_pin from public.profiles where id = v_e1)
      and not (select must_change_pin from public.profiles where id = v_e2),
    'set pin: the "must change" flag is set as asked');
  select pin_hash into v_hash from private.employee_pins where user_id = v_e1;
  perform pg_temp.check(
    v_hash like '$2%' and v_hash not like '%482915%',
    'set pin: only a bcrypt hash is stored, never the PIN');
  select private.login_password(v_e1), private.login_password(v_e2) into v_pw1, v_pw2;
  perform pg_temp.check(
    v_pw1 <> v_pw2 and length(v_pw1) >= 40 and v_pw1 !~ '^[0-9]+$',
    'set pin: every person has a different long Auth password, not the PIN');
  perform pg_temp.check(
    (select encrypted_password from auth.users where id = v_e1)
      = extensions.crypt(v_pw1, (select encrypted_password from auth.users where id = v_e1)),
    'set pin: the Auth password on file is the derived one');
  perform pg_temp.check(
    (select encrypted_password from auth.users where id = v_e1)
      <> extensions.crypt('482915', (select encrypted_password from auth.users where id = v_e1)),
    'set pin: the PIN itself is NOT the Auth password, so Supabase Auth cannot be guessed against');

  perform pg_temp.act_as_service();
  begin
    perform public.set_employee_pin(v_e3, '123456', true);
    perform pg_temp.check(false, 'set pin: a simple sequence was accepted');
  exception when others then
    perform pg_temp.check(sqlerrm = 'pin_invalid', format('set pin: a simple sequence is refused (%s)', sqlerrm));
  end;
  begin
    perform public.set_employee_pin(v_admin, '482915', true);
    perform pg_temp.check(false, 'set pin: a PIN was set for an admin');
  exception when others then
    perform pg_temp.check(sqlerrm = 'employee_not_found', format('set pin: admins have no PIN (%s)', sqlerrm));
  end;
  perform pg_temp.act_as_server();
  perform pg_temp.check(
    not exists (select 1 from private.employee_pins where user_id in (v_e3, v_admin)),
    'set pin: refused requests stored nothing');

  ---------------------------------------------------------------------------
  -- C. Logging in
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_service();
  v_res := public.employee_login_check('PN-002', '482915');
  perform pg_temp.check(
    v_res ->> 'result' = 'ok' and (v_res ->> 'user_id')::uuid = v_e1
      and v_res ->> 'login_password' = v_pw1 and (v_res ->> 'must_change_pin')::boolean,
    'login: the right code and PIN give the server what it needs to sign in');
  v_res := public.employee_login_check('  pn-002 ', '482915');
  perform pg_temp.check(v_res ->> 'result' = 'ok', 'login: the code is not case- or space-sensitive');

  v_res := public.employee_login_check('PN-002', '000001');
  v_res2 := public.employee_login_check('PN-999', '482915');
  perform pg_temp.check(
    v_res ->> 'result' = 'invalid' and v_res2 ->> 'result' = 'invalid'
      and v_res::text = v_res2::text,
    'login: a wrong PIN and an unknown code get the identical answer (nothing revealed)');
  perform pg_temp.check(
    not (v_res ? 'login_password') and not (v_res ? 'user_id'),
    'login: a failed answer carries no password and no user id');

  perform pg_temp.act_as_server();
  perform pg_temp.check(
    (select failed_login_attempts from public.profiles where id = v_e1) = 1,
    'lockout: the wrong PIN was counted (1)');

  perform pg_temp.act_as_service();
  perform public.employee_login_check('PN-002', '482915');
  perform pg_temp.act_as_server();
  perform pg_temp.check(
    (select failed_login_attempts from public.profiles where id = v_e1) = 0,
    'lockout: a right PIN resets the count');

  perform pg_temp.act_as_service();
  for v_n in 1..4 loop
    v_res := public.employee_login_check('PN-002', '00000' || v_n);
  end loop;
  perform pg_temp.check(v_res ->> 'result' = 'invalid', 'lockout: the 4th wrong try is still just "invalid"');
  v_res := public.employee_login_check('PN-002', '000009');
  perform pg_temp.check(
    v_res ->> 'result' = 'locked' and (v_res ->> 'retry_after_seconds')::int = 900,
    format('lockout: the 5th wrong try locks for 15 minutes (%s)', v_res));
  perform pg_temp.act_as_server();
  select locked_until into v_locked from public.profiles where id = v_e1;
  perform pg_temp.check(
    v_locked > now() + interval '14 minutes' and v_locked <= now() + interval '15 minutes 5 seconds',
    format('lockout: locked_until is set about 15 minutes ahead (%s)', v_locked));
  perform pg_temp.check(
    (select count(*) from public.notifications where type = 'account_locked' and employee_id = v_e1) = 1,
    'lockout: the admins get exactly one "account locked" notification');

  perform pg_temp.act_as_service();
  v_res := public.employee_login_check('PN-002', '482915');
  perform pg_temp.check(
    v_res ->> 'result' = 'locked' and not (v_res ? 'login_password'),
    'lockout: while locked, even the RIGHT PIN is refused and gives nothing');
  v_res := public.employee_login_check('PN-002', '000001');
  perform pg_temp.act_as_server();
  perform pg_temp.check(
    (select failed_login_attempts from public.profiles where id = v_e1) = 0
      and (select count(*) from public.notifications where type = 'account_locked' and employee_id = v_e1) = 1,
    'lockout: tries while locked are not counted and raise no second alert');

  update public.profiles set locked_until = now() - interval '1 second' where id = v_e1;
  perform pg_temp.act_as_service();
  v_res := public.employee_login_check('PN-002', '482915');
  perform pg_temp.act_as_server();
  perform pg_temp.check(
    v_res ->> 'result' = 'ok'
      and (select locked_until from public.profiles where id = v_e1) is null,
    'lockout: after the 15 minutes the right PIN works and clears the lock');

  -- bystanders and special cases
  perform pg_temp.check(
    (select failed_login_attempts from public.profiles where id = v_e2) = 0
      and (select locked_until from public.profiles where id = v_e2) is null,
    'bystander: another employee was not counted or locked');
  perform pg_temp.act_as_service();
  v_res := public.employee_login_check('PN-004', '482915');
  perform pg_temp.check(v_res ->> 'result' = 'invalid', 'login: someone with no PIN set yet cannot get in');
  v_res := public.employee_login_check('PN-005', '482915');
  perform pg_temp.check(v_res ->> 'result' = 'blocked' and not (v_res ? 'login_password'),
    'login: a blocked employee is refused even with the right PIN');
  v_res := public.employee_login_check('PN-001', '482915');
  perform pg_temp.check(v_res ->> 'result' = 'invalid', 'login: an admin''s code is not an employee login');
  v_res := public.employee_login_check(null, null);
  perform pg_temp.check(v_res ->> 'result' = 'invalid', 'login: empty input is "invalid", not an error');

  ---------------------------------------------------------------------------
  -- D. Who may call what
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e2);
  begin
    perform public.employee_login_check('PN-003', '135792');
    perform pg_temp.check(false, 'access: an employee called employee_login_check');
  exception when others then
    perform pg_temp.check(true, format('access: an employee cannot call the login check (%s)', sqlerrm));
  end;
  begin
    perform public.set_employee_pin(v_e2, '246810', false);
    perform pg_temp.check(false, 'access: an employee called set_employee_pin');
  exception when others then
    perform pg_temp.check(true, format('access: an employee cannot set a PIN (%s)', sqlerrm));
  end;
  perform pg_temp.act_as(v_admin);
  begin
    perform public.set_employee_pin(v_e2, '246810', false);
    perform pg_temp.check(false, 'access: an admin session called set_employee_pin directly');
  exception when others then
    perform pg_temp.check(true, format('access: not even an admin session can set a PIN directly (%s)', sqlerrm));
  end;
  begin
    perform 1 from private.employee_pins limit 1;
    perform pg_temp.check(false, 'access: an admin session read the PIN hashes');
  exception when others then
    perform pg_temp.check(true, format('access: the PIN hashes cannot be read from the API (%s)', sqlerrm));
  end;
  perform pg_temp.act_as_anon();
  begin
    perform public.employee_login_check('PN-002', '482915');
    perform pg_temp.check(false, 'access: a signed-out visitor called employee_login_check');
  exception when others then
    perform pg_temp.check(true, format('access: a signed-out visitor cannot call the login check (%s)', sqlerrm));
  end;

  ---------------------------------------------------------------------------
  -- E. The old shortcut is gone
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);
  begin
    perform public.complete_pin_change();
    perform pg_temp.check(false, 'old way: complete_pin_change still exists');
  exception when others then
    perform pg_temp.check(true, format('old way: complete_pin_change is gone (%s)', sqlerrm));
  end;
  perform pg_temp.act_as_server();

  perform pg_temp.act_as_server();
  raise exception E'PIN ATTACK CHECK REPORT (intentional error: rolls everything back)\n%\n\nRESULT: % passed, % failed\n%',
    current_setting('attack.report', true),
    regexp_count(current_setting('attack.report', true), E'\nPASS  '),
    regexp_count(current_setting('attack.report', true), E'\nFAIL  '),
    case when regexp_count(current_setting('attack.report', true), E'\nFAIL  ') > 0
         then '>>> DO NOT RELY ON THIS MIGRATION <<<' else '>>> ALL CHECKS PASSED <<<' end;
end $$;

rollback;
