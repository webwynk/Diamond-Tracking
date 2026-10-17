-- =============================================================================
-- Attack checks for 20261017000000_foundation_security_and_live_tracking.sql
--
-- Run in the Supabase SQL editor AFTER applying the migration.
--
-- Updated 2026-10-17 for 20261017040000_cleanup_signup_trigger_and_grants.sql:
-- the new-user trigger no longer exists, so profiles are inserted explicitly
-- (as the create-employee function does), and the new privilege rules are
-- attacked at the end of the employee and admin sections.
--
-- HOW TO READ THE RESULT
--   The editor shows an intentional red "error" at the bottom. Its text is the
--   full report: one PASS or FAIL line per attack, then a RESULT line. The
--   error is how everything the script created (test users, sessions, points)
--   is rolled back, so it leaves nothing behind.
--   Any FAIL line means: do not rely on the migration.
--   (docs/05 section 4: "Policies are not trusted until attacked.")
-- =============================================================================
begin;

-- Append a line to the report (a custom setting works under any database role).
create or replace function pg_temp.note(p_line text) returns void
language plpgsql as $$
begin
  perform set_config('attack.report',
    coalesce(current_setting('attack.report', true), '') || E'\n' || p_line, true);
end $$;

-- Impersonate a signed-in user for the rest of the transaction.
create or replace function pg_temp.act_as(p_uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- Runs a statement as the current role and returns 'ok' or the error text, so a
-- permission failure can be told apart from a row-level-security refusal.
create or replace function pg_temp.try_sql(p_sql text) returns text
language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlerrm;
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
  v_admin uuid := gen_random_uuid();
  v_e1    uuid := gen_random_uuid();
  v_e2    uuid := gen_random_uuid();
  v_rogue uuid := gen_random_uuid();
  v_s1    uuid;
  v_count int;
  v_dist  numeric;
  v_ist_hour int := extract(hour from (now() at time zone 'Asia/Kolkata'));
  v_msg   text;
  v_fail  int := 0;
  v_pass  int := 0;
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
     'attack-admin@test.invalid', 'x', now(),
     '{"role":"admin","full_name":"Attack Admin"}', '{}', now(), now()),
    (v_e1, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz-001@staff.test.invalid', 'x', now(),
     '{"role":"employee","employee_code":"ZZ-001","phone":"+910000000001","full_name":"Employee One"}',
     '{}', now(), now()),
    (v_e2, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz-002@staff.test.invalid', 'x', now(),
     '{"role":"employee","employee_code":"ZZ-002","phone":"+910000000002","full_name":"Employee Two"}',
     '{}', now(), now());

  -- Profiles are made explicitly, as the create-employee function and the manual
  -- admin script do. No trigger builds them any more.
  insert into public.profiles (id, email, role, status, full_name, must_change_pin)
  values (v_admin, 'attack-admin@test.invalid', 'admin', 'active', 'Attack Admin', false);
  insert into public.profiles (id, email, role, status, full_name, employee_code, phone, must_change_pin)
  values
    (v_e1, 'zz-001@staff.test.invalid', 'employee', 'active', 'Employee One', 'ZZ-001', '+910000000001', true),
    (v_e2, 'zz-002@staff.test.invalid', 'employee', 'active', 'Employee Two', 'ZZ-002', '+910000000002', true);

  -- Self-promotion hole: user_metadata says admin, app_metadata does not.
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                          created_at, updated_at)
  values (v_rogue, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'rogue@test.invalid', 'x', now(), '{}', '{"role":"admin","full_name":"Rogue"}',
          now(), now());

  select count(*) into v_count from public.profiles where id = v_rogue;
  if v_count = 0 then
    perform pg_temp.note('PASS  user_metadata cannot create an admin profile'); v_pass := v_pass + 1;
  else
    perform pg_temp.note('FAIL  a user_metadata role created a profile'); v_fail := v_fail + 1;
  end if;

  -- A login that nothing made a profile for (a dashboard "Add user", a self
  -- sign-up) sees nothing and is not an admin.
  perform pg_temp.act_as(v_rogue);
  select count(*) into v_count from public.profiles;
  if v_count = 0 and public.is_admin() is not true then
    perform pg_temp.note('PASS  a login with no profile sees nothing and is not an admin'); v_pass := v_pass + 1;
  else
    perform pg_temp.note('FAIL  a login with no profile saw data or counted as admin'); v_fail := v_fail + 1;
  end if;
  perform pg_temp.act_as_server();

  -- E1 has an open session started 2h ago with three points ~111 m apart, 1 min apart.
  v_s1 := gen_random_uuid();
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s1, v_e1, 'open', now() - interval '2 hours');

  insert into public.location_points (id, session_id, employee_id, latitude, longitude,
                                      accuracy, recorded_at)
  values
    ('p1-' || v_s1, v_s1, v_e1, 20.000, 73.000, 5, now() - interval '3 minutes'),
    ('p2-' || v_s1, v_s1, v_e1, 20.001, 73.000, 5, now() - interval '2 minutes'),
    ('p3-' || v_s1, v_s1, v_e1, 20.002, 73.000, 5, now() - interval '1 minute');

  select count(*) into v_count from public.live_locations where employee_id = v_e1;
  if v_count = 1 then
    perform pg_temp.note('PASS  a point creates/updates the employee live_locations row'); v_pass := v_pass + 1;
  else
    perform pg_temp.note(format('FAIL  live_locations was not maintained (%s rows)', v_count)); v_fail := v_fail + 1;
  end if;

  ---------------------------------------------------------------------------
  -- Employee TWO attacks employee ONE
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e2);

  select count(*) into v_count from public.profiles where id = v_e1;
  if v_count = 0 then perform pg_temp.note('PASS  E2 cannot read E1 profile'); v_pass := v_pass + 1;
  else perform pg_temp.note('FAIL  E2 read E1 profile'); v_fail := v_fail + 1; end if;

  select count(*) into v_count from public.duty_sessions where employee_id = v_e1;
  if v_count = 0 then perform pg_temp.note('PASS  E2 cannot read E1 duty sessions'); v_pass := v_pass + 1;
  else perform pg_temp.note('FAIL  E2 read E1 duty sessions'); v_fail := v_fail + 1; end if;

  select count(*) into v_count from public.location_points where employee_id = v_e1;
  if v_count = 0 then perform pg_temp.note('PASS  E2 cannot read E1 location points'); v_pass := v_pass + 1;
  else perform pg_temp.note('FAIL  E2 read E1 location points'); v_fail := v_fail + 1; end if;

  select count(*) into v_count from public.live_locations;
  if v_count = 0 then perform pg_temp.note('PASS  E2 sees no other live locations'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  E2 saw %s live location(s)', v_count)); v_fail := v_fail + 1; end if;

  select count(*) into v_count from public.audit_log;
  if v_count = 0 then perform pg_temp.note('PASS  employees cannot read the audit log'); v_pass := v_pass + 1;
  else perform pg_temp.note('FAIL  employee read the audit log'); v_fail := v_fail + 1; end if;

  begin
    insert into public.duty_sessions (employee_id) values (v_e1);
    perform pg_temp.note('FAIL  E2 started duty as E1'); v_fail := v_fail + 1;
  exception when others then
    perform pg_temp.note(format('PASS  E2 cannot start duty as E1 (%s)', sqlerrm)); v_pass := v_pass + 1;
  end;

  begin
    insert into public.location_points (id, session_id, employee_id, latitude, longitude, recorded_at)
    values ('evil-1', v_s1, v_e1, 20.5, 73.5, now());
    perform pg_temp.note('FAIL  E2 wrote a point into E1 session'); v_fail := v_fail + 1;
  exception when others then
    perform pg_temp.note(format('PASS  E2 cannot write points into E1 session (%s)', sqlerrm)); v_pass := v_pass + 1;
  end;

  update public.duty_sessions set notes = 'hacked' where id = v_s1;
  get diagnostics v_count = row_count;
  if v_count = 0 then perform pg_temp.note('PASS  E2 cannot update E1 session'); v_pass := v_pass + 1;
  else perform pg_temp.note('FAIL  E2 updated E1 session'); v_fail := v_fail + 1; end if;

  update public.profiles set role = 'admin' where id = v_e2;
  get diagnostics v_count = row_count;
  if v_count = 0 then perform pg_temp.note('PASS  E2 cannot promote self to admin'); v_pass := v_pass + 1;
  else perform pg_temp.note('FAIL  E2 changed own profile role'); v_fail := v_fail + 1; end if;

  ---------------------------------------------------------------------------
  -- Employee ONE attacks their own record
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);

  begin
    insert into public.location_points (id, session_id, latitude, longitude, recorded_at)
    values ('future-1', v_s1, 20.0, 73.0, now() + interval '2 hours');
    perform pg_temp.note('FAIL  a future-dated point was accepted'); v_fail := v_fail + 1;
  exception when others then
    perform pg_temp.note(format('PASS  future-dated point rejected (%s)', sqlerrm)); v_pass := v_pass + 1;
  end;

  begin
    insert into public.location_points (id, session_id, latitude, longitude, recorded_at)
    values ('before-1', v_s1, 20.0, 73.0, now() - interval '1 day');
    perform pg_temp.note('FAIL  a point from before the session was accepted'); v_fail := v_fail + 1;
  exception when others then
    perform pg_temp.note(format('PASS  point outside the session rejected (%s)', sqlerrm)); v_pass := v_pass + 1;
  end;

  v_msg := pg_temp.try_sql(format('update public.location_points set latitude = 0 where session_id = %L', v_s1));
  if v_msg like 'permission denied for table location_points%' then
    perform pg_temp.note('PASS  points cannot be edited (no UPDATE privilege)'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  editing points answered: %s', v_msg)); v_fail := v_fail + 1; end if;

  v_msg := pg_temp.try_sql(format('delete from public.location_points where session_id = %L', v_s1));
  if v_msg like 'permission denied for table location_points%' then
    perform pg_temp.note('PASS  points cannot be deleted (no DELETE privilege)'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  deleting points answered: %s', v_msg)); v_fail := v_fail + 1; end if;

  -- Forging distance: the server must overwrite 9999 with the real figure.
  update public.duty_sessions
     set status = 'completed', total_distance_km = 9999, visits_count = 500
   where id = v_s1;
  perform pg_temp.act_as_server();
  select total_distance_km into v_dist from public.duty_sessions where id = v_s1;
  if v_dist is not null and v_dist <> 9999 and abs(v_dist - 0.222) < 0.02 then
    perform pg_temp.note(format('PASS  server computed distance %s km, client value 9999 ignored', v_dist));
    v_pass := v_pass + 1;
  else
    perform pg_temp.note(format('FAIL  distance stored as %s (expected about 0.222)', v_dist)); v_fail := v_fail + 1;
  end if;

  select count(*) into v_count from public.duty_sessions
   where id = v_s1 and ended_at is not null and visits_count = 0;
  if v_count = 1 then perform pg_temp.note('PASS  end time server-stamped, visits not client-set'); v_pass := v_pass + 1;
  else perform pg_temp.note('FAIL  close did not stamp the server end time'); v_fail := v_fail + 1; end if;

  select count(*) into v_count from public.live_locations where employee_id = v_e1;
  if v_count = 0 then perform pg_temp.note('PASS  going off duty removes the live marker'); v_pass := v_pass + 1;
  else perform pg_temp.note('FAIL  live marker survived the end of duty'); v_fail := v_fail + 1; end if;

  perform pg_temp.act_as(v_e1);
  begin
    update public.duty_sessions set total_distance_km = 1 where id = v_s1;
    perform pg_temp.note('FAIL  a closed session was edited'); v_fail := v_fail + 1;
  exception when others then
    perform pg_temp.note(format('PASS  closed session is read-only history (%s)', sqlerrm)); v_pass := v_pass + 1;
  end;

  -- Duty window: judged on server time, not the phone.
  begin
    insert into public.duty_sessions (employee_id) values (v_e1);
    if v_ist_hour >= 8 and v_ist_hour < 23 then
      perform pg_temp.note(format('PASS  duty started inside the 08:00-23:00 IST window (now %s IST)', v_ist_hour));
      v_pass := v_pass + 1;
    else
      perform pg_temp.note(format('FAIL  duty started OUTSIDE the window (now %s IST)', v_ist_hour)); v_fail := v_fail + 1;
    end if;
  exception when others then
    if v_ist_hour < 8 or v_ist_hour >= 23 then
      perform pg_temp.note(format('PASS  duty refused outside the window (now %s IST): %s', v_ist_hour, sqlerrm));
      v_pass := v_pass + 1;
    else
      perform pg_temp.note(format('FAIL  duty refused inside the window: %s', sqlerrm)); v_fail := v_fail + 1;
    end if;
  end;

  ---------------------------------------------------------------------------
  -- Privileges: even where a row-level policy would allow it, the table
  -- privilege must already say no (defence in depth)
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_anon();
  v_msg := pg_temp.try_sql('select count(*) from public.profiles');
  if v_msg like 'permission denied for table profiles%' then perform pg_temp.note('PASS  a signed-out visitor cannot read profiles'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  anon read profiles: %s', v_msg)); v_fail := v_fail + 1; end if;
  v_msg := pg_temp.try_sql('select count(*) from public.location_points');
  if v_msg like 'permission denied for table location_points%' then perform pg_temp.note('PASS  a signed-out visitor cannot read location points'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  anon read points: %s', v_msg)); v_fail := v_fail + 1; end if;
  v_msg := pg_temp.try_sql('select count(*) from public.live_locations');
  if v_msg like 'permission denied for table live_locations%' then perform pg_temp.note('PASS  a signed-out visitor cannot read live locations'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  anon read live locations: %s', v_msg)); v_fail := v_fail + 1; end if;
  v_msg := pg_temp.try_sql('select count(*) from public.audit_log');
  if v_msg like 'permission denied for table audit_log%' then perform pg_temp.note('PASS  a signed-out visitor cannot read the audit log'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  anon read the audit log: %s', v_msg)); v_fail := v_fail + 1; end if;

  perform pg_temp.act_as(v_e1);
  v_msg := pg_temp.try_sql('truncate public.location_points');
  if v_msg like 'permission denied for table location_points%' then perform pg_temp.note('PASS  an employee cannot truncate location points'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  truncate answered: %s', v_msg)); v_fail := v_fail + 1; end if;
  v_msg := pg_temp.try_sql(format('delete from public.duty_sessions where id = %L', v_s1));
  if v_msg like 'permission denied for table duty_sessions%' then perform pg_temp.note('PASS  an employee cannot delete a duty session'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  delete session answered: %s', v_msg)); v_fail := v_fail + 1; end if;
  v_msg := pg_temp.try_sql('insert into public.audit_log (action) values (''forged'')');
  if v_msg like 'permission denied for table audit_log%' then perform pg_temp.note('PASS  an employee cannot write the audit log'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  audit insert answered: %s', v_msg)); v_fail := v_fail + 1; end if;
  v_msg := pg_temp.try_sql(format('insert into public.live_locations (employee_id, session_id, latitude, longitude, recorded_at) values (%L, %L, 1, 1, now())', v_e1, v_s1));
  if v_msg like 'permission denied for table live_locations%' then perform pg_temp.note('PASS  an employee cannot put themselves on the live map'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  live_locations insert answered: %s', v_msg)); v_fail := v_fail + 1; end if;
  v_msg := pg_temp.try_sql('select private.session_distance_km(gen_random_uuid())');
  if v_msg like 'permission denied for schema private%' then perform pg_temp.note('PASS  an employee cannot call private functions'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  private function answered: %s', v_msg)); v_fail := v_fail + 1; end if;

  ---------------------------------------------------------------------------
  -- Admin
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_admin);

  -- Profiles are made only by the server; an admin cannot insert one either.
  v_msg := pg_temp.try_sql(format('insert into public.profiles (id, email, role, full_name) values (gen_random_uuid(), ''x@test.invalid'', ''admin'', ''Forged'')'));
  if v_msg like 'permission denied for table profiles%' then perform pg_temp.note('PASS  an admin cannot insert profiles through the API'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  admin profile insert answered: %s', v_msg)); v_fail := v_fail + 1; end if;

  select count(*) into v_count from public.profiles;
  if v_count >= 3 then perform pg_temp.note('PASS  admin can read all profiles'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  admin sees only %s profiles', v_count)); v_fail := v_fail + 1; end if;

  begin
    insert into public.duty_sessions (employee_id) values (v_e2);
    perform pg_temp.note('FAIL  an admin started duty for an employee'); v_fail := v_fail + 1;
  exception when others then
    perform pg_temp.note(format('PASS  admins cannot start duty for employees (%s)', sqlerrm)); v_pass := v_pass + 1;
  end;

  update public.duty_sessions set notes = 'admin edit' where id = v_s1;
  get diagnostics v_count = row_count;
  if v_count = 0 then perform pg_temp.note('PASS  admins have no direct edit on duty sessions'); v_pass := v_pass + 1;
  else perform pg_temp.note('FAIL  admin edited a duty session'); v_fail := v_fail + 1; end if;

  begin
    update public.profiles set employee_code = 'ZZ-999' where id = v_e2;
    perform pg_temp.note('FAIL  an admin changed an employee code'); v_fail := v_fail + 1;
  exception when others then
    perform pg_temp.note(format('PASS  employee code is immutable (%s)', sqlerrm)); v_pass := v_pass + 1;
  end;

  update public.profiles set status = 'blocked', blocked_reason = 'attack test' where id = v_e2;
  get diagnostics v_count = row_count;
  if v_count = 1 then perform pg_temp.note('PASS  an admin can block an employee'); v_pass := v_pass + 1;
  else perform pg_temp.note('FAIL  an admin could not block an employee'); v_fail := v_fail + 1; end if;

  perform pg_temp.act_as_server();
  select count(*) into v_count from public.audit_log
   where action = 'employee_blocked' and target_id = v_e2 and actor_id = v_admin;
  if v_count = 1 then perform pg_temp.note('PASS  blocking was written to the audit log'); v_pass := v_pass + 1;
  else perform pg_temp.note(format('FAIL  block audit rows: %s', v_count)); v_fail := v_fail + 1; end if;

  select count(*) into v_count from public.profiles
   where id = v_e2 and blocked_by = v_admin and blocked_at is not null;
  if v_count = 1 then perform pg_temp.note('PASS  block time and actor are server-stamped'); v_pass := v_pass + 1;
  else perform pg_temp.note('FAIL  block was not stamped by the server'); v_fail := v_fail + 1; end if;

  -- A blocked employee cannot start duty (needs the window open to be meaningful).
  perform pg_temp.act_as(v_e2);
  begin
    insert into public.duty_sessions (employee_id) values (v_e2);
    perform pg_temp.note('FAIL  a blocked employee started duty'); v_fail := v_fail + 1;
  exception when others then
    perform pg_temp.note(format('PASS  a blocked employee cannot start duty (%s)', sqlerrm)); v_pass := v_pass + 1;
  end;

  -- Always end with an exception: it carries the report AND rolls everything back.
  perform pg_temp.act_as_server();
  raise exception E'ATTACK CHECK REPORT (intentional error: rolls everything back)\n%\n\nRESULT: % passed, % failed\n%',
    current_setting('attack.report', true), v_pass, v_fail,
    case when v_fail > 0 then '>>> DO NOT RELY ON THIS MIGRATION <<<' else '>>> ALL CHECKS PASSED <<<' end;
end $$;

rollback;
