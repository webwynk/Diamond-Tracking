-- =============================================================================
-- Attack checks for 20261017080000_notifications_list_and_private_revokes.sql
--
-- Run AFTER the migration is applied, in the Supabase SQL editor, in its own tab.
--
-- HOW TO READ THE RESULT
--   The script ends with an intentional error whose text is the full report:
--   one PASS or FAIL line per check, then a RESULT line. The error is how
--   everything the script created is rolled back, so it leaves nothing behind.
--   Any FAIL means: do not rely on the migration.
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
    values (p_id, lower(p_code) || '@staff.test.invalid', 'admin', p_status, 'NL ' || p_code, false);
  else
    insert into public.profiles (id, email, role, status, full_name, employee_code, phone, must_change_pin)
    values (p_id, lower(p_code) || '@staff.test.invalid', 'employee', p_status, 'NL ' || p_code, p_code,
            '+9100000' || lpad((abs(hashtext(p_code)) % 1000000)::text, 6, '0'), true);
  end if;
end $$;

do $$
declare
  v_a  uuid := gen_random_uuid();
  v_b  uuid := gen_random_uuid();
  v_x  uuid := gen_random_uuid();
  v_e1 uuid := gen_random_uuid();
  v_e2 uuid := gen_random_uuid();
  v_s1 uuid := gen_random_uuid();
  v_s2 uuid := gen_random_uuid();
  v_id1 bigint;
  v_id2 bigint;
  v_n   int;
  v_bad text;
begin
  perform pg_temp.act_as_server();
  perform pg_temp.make_user(v_a, 'admin', 'NL-A');
  perform pg_temp.make_user(v_b, 'admin', 'NL-B');
  perform pg_temp.make_user(v_x, 'admin', 'NL-X', 'blocked');
  perform pg_temp.make_user(v_e1, 'employee', 'NL-001');
  perform pg_temp.make_user(v_e2, 'employee', 'NL-002');

  ---------------------------------------------------------------------------
  -- The trigger functions still fire with EXECUTE taken away from everyone
  ---------------------------------------------------------------------------
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s1, v_e1, 'open', now() - interval '2 hours');
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s2, v_e2, 'open', now() - interval '1 hour');
  select id into v_id1 from public.notifications where session_id = v_s1 and type = 'duty_on';
  select id into v_id2 from public.notifications where session_id = v_s2 and type = 'duty_on';
  perform pg_temp.check(v_id1 is not null and v_id2 is not null,
    'revoke: starting duty still writes its notification (triggers do not need EXECUTE)');

  select string_agg(p.proname, ', ') into v_bad
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private'
    and (has_function_privilege('anon', p.oid, 'execute')
         or has_function_privilege('authenticated', p.oid, 'execute')
         or has_function_privilege('public', p.oid, 'execute'));
  perform pg_temp.check(v_bad is null,
    format('revoke: no function in the private schema is executable by anon, signed-in users or public (%s)', coalesce(v_bad, 'none')));

  ---------------------------------------------------------------------------
  -- list_notifications: a page, per-admin read state, filters, paging
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_a);
  select count(*) into v_n from public.list_notifications();
  perform pg_temp.check(v_n >= 2, 'list: an admin gets a page of notifications');
  perform pg_temp.check(
    (select count(*) from public.list_notifications() where id in (v_id1, v_id2) and not is_read) = 2,
    'list: nothing is read yet');

  perform public.mark_notifications_read(array[v_id1]);
  perform pg_temp.check(
    (select is_read from public.list_notifications() where id = v_id1)
      and not (select is_read from public.list_notifications() where id = v_id2),
    'list: it says A has read the one A marked, and not the other');
  perform pg_temp.check(
    not exists (select 1 from public.list_notifications(p_unread_only => true) where id = v_id1)
      and exists (select 1 from public.list_notifications(p_unread_only => true) where id = v_id2),
    'list: "unread only" leaves out what A has read and keeps the rest');

  perform pg_temp.act_as(v_b);
  perform pg_temp.check(
    not (select is_read from public.list_notifications() where id = v_id1),
    'list: the same notification is still unread for B');

  perform pg_temp.act_as(v_a);
  perform pg_temp.check(
    (select count(*) from public.list_notifications(p_types => array['no_such_type'])) = 0
      and exists (select 1 from public.list_notifications(p_types => array['duty_on']) where id = v_id1),
    'list: the type filter narrows the page');
  perform pg_temp.check(
    (select count(*) from public.list_notifications(p_employees => array[gen_random_uuid()])) = 0
      and exists (select 1 from public.list_notifications(p_employees => array[v_e1]) where id = v_id1)
      and not exists (select 1 from public.list_notifications(p_employees => array[v_e1]) where id = v_id2),
    'list: the employee filter narrows the page');
  perform pg_temp.check(
    exists (select 1 from public.list_notifications(
              p_unread_only => true, p_types => array['duty_on'], p_employees => array[v_e2])
            where id = v_id2),
    'list: filters combine');

  perform pg_temp.check(
    (select count(*) from public.list_notifications(p_limit => 1)) = 1
      and (select count(*) from public.list_notifications(p_limit => 100000)) <= 100
      and (select count(*) from public.list_notifications(p_limit => 0)) = 1,
    'list: the page size is clamped to 1..100');

  perform pg_temp.check(
    not exists (select 1 from public.list_notifications(p_before => v_id2) where id >= v_id2)
      and (select count(*) from public.list_notifications(p_before => v_id2)) < (select count(*) from public.list_notifications(p_limit => 100)),
    'list: "before" returns only older notifications (paging)');
  perform pg_temp.check(
    (select id from public.list_notifications() limit 1) >= v_id2,
    'list: the page is newest first');

  ---------------------------------------------------------------------------
  -- Everyone else gets nothing
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_x);
  perform pg_temp.check((select count(*) from public.list_notifications()) = 0,
    'list: a blocked admin gets an empty page');
  perform pg_temp.act_as(v_e1);
  perform pg_temp.check((select count(*) from public.list_notifications()) = 0,
    'list: an employee gets an empty page');

  perform pg_temp.act_as_anon();
  begin
    perform * from public.list_notifications();
    perform pg_temp.check(false, 'list: a signed-out visitor called list_notifications');
  exception when others then
    perform pg_temp.check(true, format('list: a signed-out visitor is refused (%s)', sqlerrm));
  end;

  ---------------------------------------------------------------------------
  -- Report: always end with an exception; it carries the report AND rolls back
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();
  raise exception E'NOTIFICATION LIST ATTACK CHECK REPORT (intentional error: rolls everything back)\n%\n\nRESULT: % passed, % failed\n%',
    current_setting('attack.report', true),
    regexp_count(current_setting('attack.report', true), E'\nPASS  '),
    regexp_count(current_setting('attack.report', true), E'\nFAIL  '),
    case when regexp_count(current_setting('attack.report', true), E'\nFAIL  ') > 0
         then '>>> DO NOT RELY ON THIS MIGRATION <<<' else '>>> ALL CHECKS PASSED <<<' end;
end $$;

rollback;
