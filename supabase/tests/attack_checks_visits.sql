-- =============================================================================
-- Attack checks for 20261018000000_visits.sql
--
-- Run AFTER the migration is applied, in the Supabase SQL editor, in its own tab.
--
-- HOW TO READ THE RESULT
--   The script ends with an intentional error whose text is the full report:
--   one PASS or FAIL line per check, then a RESULT line. The error is how
--   everything the script created (test users, duties, visits) is rolled back,
--   so it leaves nothing behind. Any FAIL means: do not rely on the migration.
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

-- Runs a statement as whoever is current and checks that it is refused with
-- the given text (a LIKE pattern).
create or replace function pg_temp.expect_error(p_label text, p_sql text, p_expect text)
returns void language plpgsql as $$
declare
  v_msg text;
begin
  execute p_sql;
  perform pg_temp.check(false, p_label || ' (was accepted)');
exception when others then
  v_msg := sqlerrm;
  perform pg_temp.check(v_msg like p_expect, format('%s (%s)', p_label, v_msg));
end $$;

create or replace function pg_temp.make_user(p_id uuid, p_role text, p_code text, p_status text default 'active')
returns void language plpgsql as $$
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                          created_at, updated_at)
  values (p_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          lower(p_code) || '@staff.test.invalid', 'x', now(),
          json_build_object('role', p_role)::jsonb, '{}', now(), now());
  if p_role = 'admin' then
    insert into public.profiles (id, email, role, status, full_name, must_change_pin)
    values (p_id, lower(p_code) || '@staff.test.invalid', 'admin', p_status, 'VT ' || p_code, false);
  else
    insert into public.profiles (id, email, role, status, full_name, employee_code, phone, must_change_pin)
    values (p_id, lower(p_code) || '@staff.test.invalid', 'employee', p_status, 'VT ' || p_code, p_code,
            '+9100001' || lpad((abs(hashtext(p_code)) % 1000000)::text, 6, '0'), true);
  end if;
end $$;

do $$
declare
  v_a   uuid := gen_random_uuid();   -- admin
  v_x   uuid := gen_random_uuid();   -- blocked admin
  v_e1  uuid := gen_random_uuid();
  v_e2  uuid := gen_random_uuid();
  v_e3  uuid := gen_random_uuid();   -- blocked employee
  v_s1  uuid := gen_random_uuid();   -- e1, open
  v_sc  uuid := gen_random_uuid();   -- e1, closed (earlier today)
  v_s2  uuid := gen_random_uuid();   -- e2, open
  v_s3  uuid := gen_random_uuid();   -- e3, open (account blocked)
  v_v1  uuid := gen_random_uuid();
  v_v2  uuid := gen_random_uuid();
  v_v3  uuid := gen_random_uuid();
  v_late uuid := gen_random_uuid();
  v_row record;
  v_n   int;
  v_n2  int;
  v_cnt int;
begin
  ---------------------------------------------------------------------------
  -- Fixtures (as the server)
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();
  perform pg_temp.make_user(v_a, 'admin', 'VT-A');
  perform pg_temp.make_user(v_x, 'admin', 'VT-X', 'blocked');
  perform pg_temp.make_user(v_e1, 'employee', 'VT-001');
  perform pg_temp.make_user(v_e2, 'employee', 'VT-002');
  perform pg_temp.make_user(v_e3, 'employee', 'VT-003', 'blocked');

  insert into public.duty_sessions (id, employee_id, status, started_at, ended_at)
  values (v_sc, v_e1, 'completed', now() - interval '6 hours', now() - interval '5 hours');
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s1, v_e1, 'open', now() - interval '3 hours'),
         (v_s2, v_e2, 'open', now() - interval '2 hours'),
         (v_s3, v_e3, 'open', now() - interval '1 hour');

  ---------------------------------------------------------------------------
  -- An employee adds a visit
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);
  insert into public.visits (id, session_id, store_name, note, latitude, longitude, accuracy, captured_at)
  values (v_v1, v_s1, '  Sharma Agro  ', '  checked stock  ', 20.0, 73.0, 12, now() - interval '10 minutes');

  perform pg_temp.act_as_server();
  select * into v_row from public.visits where id = v_v1;
  perform pg_temp.check(v_row.employee_id = v_e1, 'add: the owner is the signed-in employee');
  perform pg_temp.check(v_row.store_name = 'Sharma Agro' and v_row.note = 'checked stock',
    'add: store name and note are trimmed');
  perform pg_temp.check(v_row.photo_public_id is null and v_row.photo_attached_at is null and v_row.photo_removed_at is null,
    'add: a new visit has no photo');
  perform pg_temp.check(abs(extract(epoch from (now() - v_row.created_at))) < 5, 'add: the received time is the server''s');
  perform pg_temp.check((select visits_count from public.duty_sessions where id = v_s1) = 1,
    'count: the duty''s visits_count is 1');

  -- The same visit sent again (a retry after a timeout) changes nothing.
  perform pg_temp.act_as(v_e1);
  insert into public.visits (id, session_id, store_name, latitude, longitude, captured_at)
  values (v_v1, v_s1, 'Sharma Agro', 20.0, 73.0, now() - interval '10 minutes')
  on conflict (id) do nothing;
  perform pg_temp.act_as_server();
  select count(*) into v_n from public.visits where id = v_v1;
  perform pg_temp.check(v_n = 1 and (select visits_count from public.duty_sessions where id = v_s1) = 1,
    'retry: the same visit sent twice is one visit and is counted once');

  -- Optional text: nothing, or only spaces, is stored as no text.
  perform pg_temp.act_as(v_e1);
  insert into public.visits (id, session_id, store_name, note, latitude, longitude, captured_at)
  values (v_v2, v_s1, '   ', '', 20.1, 73.1, now() - interval '5 minutes');
  perform pg_temp.act_as_server();
  select * into v_row from public.visits where id = v_v2;
  perform pg_temp.check(v_row.store_name is null and v_row.note is null, 'add: empty or blank text is stored as none');
  perform pg_temp.check((select visits_count from public.duty_sessions where id = v_s1) = 2,
    'count: two visits make visits_count 2');

  -- A time in the future is held at the server's now.
  perform pg_temp.act_as(v_e1);
  insert into public.visits (id, session_id, latitude, longitude, captured_at)
  values (v_v3, v_s1, 20.2, 73.2, now() + interval '2 hours');
  perform pg_temp.act_as_server();
  perform pg_temp.check((select captured_at <= now() from public.visits where id = v_v3),
    'time: a visit time in the future is held at the server''s now');

  ---------------------------------------------------------------------------
  -- What an employee cannot do
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);
  perform pg_temp.expect_error('rule: a visit on someone else''s duty',
    format('insert into public.visits (id, session_id, latitude, longitude, captured_at) values (%L, %L, 20, 73, now())', gen_random_uuid(), v_s2),
    'session_not_found');
  perform pg_temp.expect_error('rule: a visit on a duty that does not exist',
    format('insert into public.visits (id, session_id, latitude, longitude, captured_at) values (%L, %L, 20, 73, now())', gen_random_uuid(), gen_random_uuid()),
    'session_not_found');
  perform pg_temp.expect_error('rule: a time before the duty began',
    format('insert into public.visits (id, session_id, latitude, longitude, captured_at) values (%L, %L, 20, 73, now() - interval ''10 hours'')', gen_random_uuid(), v_s1),
    'visit_outside_session');
  perform pg_temp.expect_error('rule: a time after a closed duty ended',
    format('insert into public.visits (id, session_id, latitude, longitude, captured_at) values (%L, %L, 20, 73, now() - interval ''1 hour'')', gen_random_uuid(), v_sc),
    'visit_outside_session');
  perform pg_temp.expect_error('columns: choosing the owner',
    format('insert into public.visits (id, employee_id, session_id, latitude, longitude, captured_at) values (%L, %L, %L, 20, 73, now())', gen_random_uuid(), v_e2, v_s1),
    'permission denied%');
  perform pg_temp.expect_error('columns: choosing a photo',
    format('insert into public.visits (id, session_id, latitude, longitude, captured_at, photo_public_id) values (%L, %L, 20, 73, now(), %L)', gen_random_uuid(), v_s1, 'someone-elses-photo'),
    'permission denied%');
  perform pg_temp.expect_error('columns: choosing the server time',
    format('insert into public.visits (id, session_id, latitude, longitude, captured_at, created_at) values (%L, %L, 20, 73, now(), now() - interval ''30 days'')', gen_random_uuid(), v_s1),
    'permission denied%');
  perform pg_temp.expect_error('limits: a store name of 81 characters',
    format('insert into public.visits (id, session_id, store_name, latitude, longitude, captured_at) values (%L, %L, %L, 20, 73, now())', gen_random_uuid(), v_s1, repeat('x', 81)),
    '%visits_store_name_check%');
  perform pg_temp.expect_error('limits: a note of 201 characters',
    format('insert into public.visits (id, session_id, note, latitude, longitude, captured_at) values (%L, %L, %L, 20, 73, now())', gen_random_uuid(), v_s1, repeat('x', 201)),
    '%visits_note_check%');
  perform pg_temp.expect_error('limits: a latitude of 91',
    format('insert into public.visits (id, session_id, latitude, longitude, captured_at) values (%L, %L, 91, 73, now())', gen_random_uuid(), v_s1),
    '%visits_latitude_check%');
  perform pg_temp.expect_error('limits: a longitude of 181',
    format('insert into public.visits (id, session_id, latitude, longitude, captured_at) values (%L, %L, 20, 181, now())', gen_random_uuid(), v_s1),
    '%visits_longitude_check%');
  perform pg_temp.expect_error('history: an employee cannot edit a visit',
    format('update public.visits set note = ''changed'' where id = %L', v_v1),
    'permission denied%');
  perform pg_temp.expect_error('history: an employee cannot delete a visit',
    format('delete from public.visits where id = %L', v_v1),
    'permission denied%');

  perform pg_temp.act_as(v_e3);
  perform pg_temp.expect_error('rule: a blocked employee cannot add a visit',
    format('insert into public.visits (id, session_id, latitude, longitude, captured_at) values (%L, %L, 20, 73, now())', gen_random_uuid(), v_s3),
    'account_not_active');

  ---------------------------------------------------------------------------
  -- A visit added late, after the duty was closed (a phone that was offline)
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);
  insert into public.visits (id, session_id, store_name, latitude, longitude, captured_at)
  values (v_late, v_sc, 'Late upload', 20.3, 73.3, now() - interval '5 hours 30 minutes');
  perform pg_temp.act_as_server();
  perform pg_temp.check((select visits_count from public.duty_sessions where id = v_sc) = 1,
    'late: a visit from inside a closed duty is accepted and counted on that duty');
  perform pg_temp.check((select status from public.duty_sessions where id = v_sc) = 'completed'
                        and (select ended_at from public.duty_sessions where id = v_sc) is not null,
    'late: the closed duty stays closed');

  ---------------------------------------------------------------------------
  -- At most 100 visits per duty
  ---------------------------------------------------------------------------
  select count(*) into v_cnt from public.visits where session_id = v_s1;
  perform pg_temp.act_as(v_e1);
  insert into public.visits (id, session_id, latitude, longitude, captured_at)
  select gen_random_uuid(), v_s1, 20, 73, now() - interval '1 minute'
  from generate_series(1, 100 - v_cnt);
  perform pg_temp.act_as_server();
  perform pg_temp.check((select count(*) from public.visits where session_id = v_s1) = 100
                        and (select visits_count from public.duty_sessions where id = v_s1) = 100,
    'limit: the duty holds 100 visits and visits_count says 100');
  perform pg_temp.act_as(v_e1);
  perform pg_temp.expect_error('limit: the 101st visit is refused',
    format('insert into public.visits (id, session_id, latitude, longitude, captured_at) values (%L, %L, 20, 73, now())', gen_random_uuid(), v_s1),
    'visit_limit');

  ---------------------------------------------------------------------------
  -- Who can read what
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);
  select count(*) into v_n from public.visits;
  perform pg_temp.check(v_n = 101, format('read: an employee sees their own visits (%s)', v_n));

  perform pg_temp.act_as(v_e2);
  select count(*) into v_n from public.visits;
  perform pg_temp.check(v_n = 0, 'read: another employee sees none of them');

  perform pg_temp.act_as(v_a);
  select count(*) into v_n from public.visits where employee_id = v_e1;
  perform pg_temp.check(v_n = 101, 'read: an admin sees every employee''s visits');

  perform pg_temp.act_as(v_x);
  select count(*) into v_n from public.visits;
  perform pg_temp.check(v_n = 0, 'read: a blocked admin sees nothing');

  perform pg_temp.act_as_anon();
  perform pg_temp.expect_error('read: a signed-out visitor is refused',
    'select count(*) from public.visits', 'permission denied%');

  perform pg_temp.act_as(v_a);
  perform pg_temp.expect_error('history: not even an admin can edit a visit',
    format('update public.visits set note = ''changed'' where id = %L', v_v1),
    'permission denied%');
  perform pg_temp.expect_error('history: not even an admin can delete a visit',
    format('delete from public.visits where id = %L', v_v1),
    'permission denied%');
  perform pg_temp.expect_error('rule: an admin cannot add a visit through the API',
    format('insert into public.visits (id, session_id, latitude, longitude, captured_at) values (%L, %L, 20, 73, now())', gen_random_uuid(), v_s2),
    'account_not_active');

  ---------------------------------------------------------------------------
  -- The server side: the photo is attached and removed only by the server
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();
  update public.visits
     set photo_public_id = 'visits/' || v_v1::text, photo_attached_at = now()
   where id = v_v1;
  perform pg_temp.check((select photo_public_id from public.visits where id = v_v1) = 'visits/' || v_v1::text,
    'server: the server can attach a photo');

  begin
    update public.visits set photo_removed_at = now() where id = v_v1;
    perform pg_temp.check(false, 'server: a visit holding a photo AND marked removed was accepted');
  exception when others then
    perform pg_temp.check(sqlerrm like '%visits_photo_state%',
      format('server: a photo cannot be both held and removed (%s)', sqlerrm));
  end;

  update public.visits
     set photo_public_id = null, photo_removed_at = now()
   where id = v_v1;
  perform pg_temp.check((select photo_public_id is null and photo_removed_at is not null from public.visits where id = v_v1),
    'server: removing a photo keeps the visit and says when it was removed');
  perform pg_temp.act_as(v_e1);
  perform pg_temp.check((select count(*) from public.visits where id = v_v1) = 1,
    'server: the employee still has the visit after its photo is removed');

  ---------------------------------------------------------------------------
  -- Plumbing
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();
  perform pg_temp.check((select relrowsecurity from pg_class where oid = 'public.visits'::regclass),
    'plumbing: row-level security is on');
  perform pg_temp.check(
    not has_table_privilege('authenticated', 'public.visits', 'UPDATE')
    and not has_table_privilege('authenticated', 'public.visits', 'DELETE')
    and not has_table_privilege('authenticated', 'public.visits', 'TRUNCATE')
    and not has_table_privilege('anon', 'public.visits', 'SELECT'),
    'plumbing: signed-in users cannot update, delete or truncate; visitors cannot read');
  perform pg_temp.check(
    has_column_privilege('authenticated', 'public.visits', 'store_name', 'INSERT')
    and not has_column_privilege('authenticated', 'public.visits', 'employee_id', 'INSERT')
    and not has_column_privilege('authenticated', 'public.visits', 'photo_public_id', 'INSERT')
    and not has_column_privilege('authenticated', 'public.visits', 'created_at', 'INSERT'),
    'plumbing: an employee can insert only the columns they are meant to send');
  perform pg_temp.check(
    exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'idx_visits_employee_captured')
    and exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'idx_visits_photo_due'),
    'plumbing: the list index and the 90-day clean-up index exist');
  select count(*) into v_n
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'private'
     and (has_function_privilege('anon', p.oid, 'EXECUTE')
          or has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  perform pg_temp.check(v_n = 0, format('plumbing: no function in the private schema is open to the API roles (%s open)', v_n));

  ---------------------------------------------------------------------------
  -- Report: always end with an exception; it carries the report AND rolls back
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();
  raise exception E'VISITS ATTACK CHECK REPORT (intentional error: rolls everything back)\n%\n\nRESULT: % passed, % failed\n%',
    current_setting('attack.report', true),
    regexp_count(current_setting('attack.report', true), E'\nPASS  '),
    regexp_count(current_setting('attack.report', true), E'\nFAIL  '),
    case when regexp_count(current_setting('attack.report', true), E'\nFAIL  ') > 0
         then '>>> DO NOT RELY ON THIS MIGRATION <<<' else '>>> ALL CHECKS PASSED <<<' end;
end $$;

rollback;
