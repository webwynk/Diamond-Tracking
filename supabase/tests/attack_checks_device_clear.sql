-- =============================================================================
-- Attack checks for 20261020010000_admin_clear_device.sql
--
-- Run AFTER the migration is applied, in the Supabase SQL editor, in its own tab.
-- (It writes throw-away users and sessions to the Auth tables, which is why it is
-- run by the project owner in the SQL editor.) Everything it creates is rolled
-- back by the intentional error at the end.
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
  v_admin  uuid := gen_random_uuid();
  v_admin2 uuid := gen_random_uuid();   -- a second active admin
  v_badm   uuid := gen_random_uuid();   -- a blocked admin
  v_e1     uuid := gen_random_uuid();   -- has a phone and two sessions: gets cleared
  v_e2     uuid := gen_random_uuid();   -- bystander with a phone and a session
  v_e3     uuid := gen_random_uuid();   -- no phone registered
  v_s1a    uuid := gen_random_uuid();
  v_s1b    uuid := gen_random_uuid();
  v_s2     uuid := gen_random_uuid();
  v_res    boolean;
  v_n      int;
  v_text   text;
  v_dev    text;
begin
  perform pg_temp.act_as_server();

  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                          created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'dc-' || n || '@staff.test.invalid', 'x', now(),
         json_build_object('role', case when n <= 3 then 'admin' else 'employee' end)::jsonb,
         '{}', now(), now()
  from unnest(array[v_admin, v_admin2, v_badm, v_e1, v_e2, v_e3]) with ordinality as t(u, n);

  insert into public.profiles (id, email, role, status, full_name, must_change_pin)
  values
    (v_admin,  'dc-1@staff.test.invalid', 'admin', 'active',  'DC Admin',   false),
    (v_admin2, 'dc-2@staff.test.invalid', 'admin', 'active',  'DC Admin 2', false),
    (v_badm,   'dc-3@staff.test.invalid', 'admin', 'blocked', 'DC Blocked', false);
  insert into public.profiles (id, email, role, status, full_name, employee_code, phone, device_id, must_change_pin)
  values
    (v_e1, 'dc-4@staff.test.invalid', 'employee', 'active', 'DC One',   'DC-001', '+910000077001', 'phone-old', false),
    (v_e2, 'dc-5@staff.test.invalid', 'employee', 'active', 'DC Two',   'DC-002', '+910000077002', 'phone-two', false),
    (v_e3, 'dc-6@staff.test.invalid', 'employee', 'active', 'DC Three', 'DC-003', '+910000077003', null,        false);

  insert into auth.sessions (id, user_id) values (v_s1a, v_e1), (v_s1b, v_e1), (v_s2, v_e2);
  insert into auth.refresh_tokens (token, user_id, session_id, revoked) values
    ('dc-tok-1a', v_e1::text, v_s1a, false),
    ('dc-tok-1b', v_e1::text, v_s1b, false),
    ('dc-tok-2',  v_e2::text, v_s2,  false);

  ---------------------------------------------------------------------------
  -- A. An admin clears the binding
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_admin);
  v_res := public.admin_clear_device(v_e1);
  perform pg_temp.act_as_server();

  perform pg_temp.check(v_res is true, 'clear: returns true when a phone was registered');
  perform pg_temp.check(
    (select device_id from public.profiles where id = v_e1) is null,
    'clear: the registered phone is gone');
  perform pg_temp.check(
    (select count(*) from auth.sessions where user_id = v_e1) = 0
      and (select count(*) from auth.refresh_tokens where user_id = v_e1::text) = 0,
    'clear: the old phone is signed out (sessions and refresh tokens deleted)');
  perform pg_temp.check(
    (select device_id from public.profiles where id = v_e2) = 'phone-two'
      and (select count(*) from auth.sessions where user_id = v_e2) = 1
      and (select count(*) from auth.refresh_tokens where user_id = v_e2::text) = 1,
    'bystander: another employee''s phone, session and token are untouched');
  perform pg_temp.check(
    (select count(*) from public.audit_log
      where action = 'device_binding_cleared' and target_id = v_e1
        and actor_id = v_admin and details ->> 'employee_code' = 'DC-001') = 1,
    'audit: exactly one row says who cleared whose phone');

  ---------------------------------------------------------------------------
  -- B. Repeating it changes nothing
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_admin2);
  v_res := public.admin_clear_device(v_e1);
  perform pg_temp.act_as_server();
  perform pg_temp.check(v_res is false, 'repeat: a second clear returns false (no phone to clear)');
  perform pg_temp.check(
    (select count(*) from public.audit_log where action = 'device_binding_cleared' and target_id = v_e1) = 1,
    'repeat: and writes no second audit row');

  perform pg_temp.act_as(v_admin);
  v_res := public.admin_clear_device(v_e3);
  perform pg_temp.act_as_server();
  perform pg_temp.check(
    v_res is false
      and not exists (select 1 from public.audit_log where target_id = v_e3 and action = 'device_binding_cleared'),
    'no phone: an employee with nothing registered returns false and is not logged');

  ---------------------------------------------------------------------------
  -- C. Who may call it, and for whom
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_admin);
  begin
    perform public.admin_clear_device(v_admin2);
    perform pg_temp.check(false, 'target: an admin account was accepted as the target');
  exception when others then
    perform pg_temp.check(sqlerrm = 'employee_not_found', format('target: only employees can be cleared (%s)', sqlerrm));
  end;
  begin
    perform public.admin_clear_device(gen_random_uuid());
    perform pg_temp.check(false, 'target: an unknown id was accepted');
  exception when others then
    perform pg_temp.check(sqlerrm = 'employee_not_found', format('target: an unknown id is refused (%s)', sqlerrm));
  end;

  perform pg_temp.act_as(v_e2);
  begin
    perform public.admin_clear_device(v_e2);
    perform pg_temp.check(false, 'access: an employee cleared a phone');
  exception when others then
    perform pg_temp.check(true, format('access: an employee cannot clear a phone, not even their own (%s)', sqlerrm));
  end;
  perform pg_temp.act_as(v_badm);
  begin
    perform public.admin_clear_device(v_e2);
    perform pg_temp.check(false, 'access: a blocked admin cleared a phone');
  exception when others then
    perform pg_temp.check(sqlerrm = 'forbidden', format('access: a blocked admin is refused (%s)', sqlerrm));
  end;
  perform pg_temp.act_as_anon();
  begin
    perform public.admin_clear_device(v_e2);
    perform pg_temp.check(false, 'access: a signed-out visitor cleared a phone');
  exception when others then
    perform pg_temp.check(true, format('access: a signed-out visitor is refused (%s)', sqlerrm));
  end;
  perform pg_temp.act_as_server();
  perform pg_temp.check(
    (select device_id from public.profiles where id = v_e2) = 'phone-two',
    'access: and the bystander''s phone is still registered');

  ---------------------------------------------------------------------------
  -- D. After clearing, the next phone to sign in is registered
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);
  v_res := public.bind_my_device('phone-new');
  perform pg_temp.check(v_res is true, 'rebind: the new phone binds');
  v_res := public.bind_my_device('phone-old');
  perform pg_temp.check(v_res is false, 'rebind: and the old phone is now the one refused');
  perform pg_temp.act_as_server();
  select device_id into v_dev from public.profiles where id = v_e1;
  perform pg_temp.check(v_dev = 'phone-new', 'rebind: the new phone is what is stored');

  ---------------------------------------------------------------------------
  -- E. The unaudited way is closed (least privilege on profiles)
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_admin);
  begin
    update public.profiles set device_id = null where id = v_e2;
    perform pg_temp.check(false, 'direct: an admin cleared a phone through the table');
  exception when others then
    perform pg_temp.check(true, format('direct: an admin cannot clear device_id through the table (%s)', sqlerrm));
  end;
  begin
    update public.profiles set locked_until = null where id = v_e2;
    perform pg_temp.check(false, 'direct: an admin changed locked_until through the table');
  exception when others then
    perform pg_temp.check(true, format('direct: nor locked_until (%s)', sqlerrm));
  end;
  begin
    update public.profiles set failed_login_attempts = 0 where id = v_e2;
    perform pg_temp.check(false, 'direct: an admin changed failed_login_attempts through the table');
  exception when others then
    perform pg_temp.check(true, format('direct: nor failed_login_attempts (%s)', sqlerrm));
  end;
  begin
    update public.profiles set must_change_pin = false where id = v_e2;
    perform pg_temp.check(false, 'direct: an admin changed must_change_pin through the table');
  exception when others then
    perform pg_temp.check(true, format('direct: nor must_change_pin (%s)', sqlerrm));
  end;
  begin
    update public.profiles set role = 'admin' where id = v_e2;
    perform pg_temp.check(false, 'direct: an admin changed a role through the table');
  exception when others then
    perform pg_temp.check(true, format('direct: nor role (%s)', sqlerrm));
  end;
  perform pg_temp.act_as_server();
  perform pg_temp.check(
    (select device_id from public.profiles where id = v_e2) = 'phone-two'
      and (select role from public.profiles where id = v_e2) = 'employee',
    'direct: none of those attempts changed anything');

  -- and what the app really does still works
  perform pg_temp.act_as(v_admin);
  update public.profiles set full_name = 'DC Two Renamed', phone = '+910000077099', contact_email = 'dc@example.com' where id = v_e2;
  get diagnostics v_n = row_count;
  perform pg_temp.check(v_n = 1, 'app: an admin can still edit name, phone and contact email');
  update public.profiles set status = 'blocked', blocked_reason = 'dc test' where id = v_e2;
  get diagnostics v_n = row_count;
  perform pg_temp.check(v_n = 1, 'app: an admin can still block');
  update public.profiles set status = 'active' where id = v_e2;
  get diagnostics v_n = row_count;
  perform pg_temp.check(v_n = 1, 'app: an admin can still unblock');

  perform pg_temp.act_as(v_e2);
  begin
    update public.profiles set full_name = 'Hacked' where id = v_e2;
    get diagnostics v_n = row_count;
    perform pg_temp.check(v_n = 0, 'app: an employee still cannot edit their own profile');
  exception when others then
    perform pg_temp.check(true, format('app: an employee still cannot edit their own profile (%s)', sqlerrm));
  end;

  perform pg_temp.act_as_server();
  raise exception E'DEVICE CLEAR ATTACK CHECK REPORT (intentional error: rolls everything back)\n%\n\nRESULT: % passed, % failed\n%',
    current_setting('attack.report', true),
    regexp_count(current_setting('attack.report', true), E'\nPASS  '),
    regexp_count(current_setting('attack.report', true), E'\nFAIL  '),
    case when regexp_count(current_setting('attack.report', true), E'\nFAIL  ') > 0
         then '>>> DO NOT RELY ON THIS MIGRATION <<<' else '>>> ALL CHECKS PASSED <<<' end;
end $$;

rollback;
