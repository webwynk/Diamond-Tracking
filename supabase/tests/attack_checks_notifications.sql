-- =============================================================================
-- Attack checks for 20261017070000_notifications.sql
--
-- Run AFTER the migration is applied, in the Supabase SQL editor, in its own tab.
--
-- HOW TO READ THE RESULT
--   The script ends with an intentional error whose text is the full report:
--   one PASS or FAIL line per check, then a RESULT line. The error is how
--   everything the script created (test users, duties, points, notifications)
--   is rolled back, so it leaves nothing behind. Any FAIL means: do not rely on
--   the migration. (docs/05 section 4: "Policies are not trusted until
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

-- Makes a login plus its profile.
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
    values (p_id, lower(p_code) || '@staff.test.invalid', 'admin', p_status, 'NT ' || p_code, false);
  else
    insert into public.profiles (id, email, role, status, full_name, employee_code, phone, must_change_pin)
    values (p_id, lower(p_code) || '@staff.test.invalid', 'employee', p_status, 'NT ' || p_code, p_code,
            '+9100000' || lpad((abs(hashtext(p_code)) % 1000000)::text, 6, '0'), true);
  end if;
end $$;

do $$
declare
  v_a  uuid := gen_random_uuid();  -- admin A
  v_b  uuid := gen_random_uuid();  -- admin B
  v_x  uuid := gen_random_uuid();  -- blocked admin
  v_e1 uuid := gen_random_uuid();
  v_e2 uuid := gen_random_uuid();
  v_e3 uuid := gen_random_uuid();
  v_e4 uuid := gen_random_uuid();
  v_e5 uuid := gen_random_uuid();
  v_e6 uuid := gen_random_uuid();
  v_e7 uuid := gen_random_uuid();
  v_s1 uuid := gen_random_uuid();
  v_s2 uuid := gen_random_uuid();
  v_s3 uuid := gen_random_uuid();
  v_s4 uuid := gen_random_uuid();
  v_s5 uuid := gen_random_uuid();
  v_s5b uuid := gen_random_uuid();
  v_s6 uuid := gen_random_uuid();
  v_s7 uuid := gen_random_uuid();
  v_id    bigint;
  v_n     int;
  v_n2    int;
  v_a_before int;
  v_b_before int;
  v_msg   text;
  v_details jsonb;
begin
  ---------------------------------------------------------------------------
  -- Fixtures (as the server)
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();
  perform pg_temp.make_user(v_a, 'admin', 'NT-A');
  perform pg_temp.make_user(v_b, 'admin', 'NT-B');
  perform pg_temp.make_user(v_x, 'admin', 'NT-X', 'blocked');
  perform pg_temp.make_user(v_e1, 'employee', 'NT-001');
  perform pg_temp.make_user(v_e2, 'employee', 'NT-002');
  perform pg_temp.make_user(v_e3, 'employee', 'NT-003');
  perform pg_temp.make_user(v_e4, 'employee', 'NT-004');
  perform pg_temp.make_user(v_e5, 'employee', 'NT-005');
  perform pg_temp.make_user(v_e6, 'employee', 'NT-006');
  perform pg_temp.make_user(v_e7, 'employee', 'NT-007');

  ---------------------------------------------------------------------------
  -- Duty started: exactly one notification
  ---------------------------------------------------------------------------
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s1, v_e1, 'open', now() - interval '3 hours');

  select count(*) into v_n from public.notifications
   where type = 'duty_on' and session_id = v_s1 and employee_id = v_e1;
  perform pg_temp.check(v_n = 1, format('duty on: starting duty writes exactly one notification (%s)', v_n));

  ---------------------------------------------------------------------------
  -- Who can read, who can write
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_a);
  select count(*) into v_n from public.notifications where session_id = v_s1;
  perform pg_temp.check(v_n >= 1, 'read: an active admin sees the notification');

  perform pg_temp.act_as(v_x);
  select count(*) into v_n from public.notifications;
  perform pg_temp.check(v_n = 0, 'read: a blocked admin sees nothing');

  perform pg_temp.act_as(v_e1);
  select count(*) into v_n from public.notifications;
  perform pg_temp.check(v_n = 0, 'read: an employee sees no notifications, not even their own');

  perform pg_temp.act_as_anon();
  begin
    perform count(*) from public.notifications;
    perform pg_temp.check(false, 'read: a signed-out visitor read notifications');
  exception when others then
    perform pg_temp.check(true, format('read: a signed-out visitor is refused (%s)', sqlerrm));
  end;

  perform pg_temp.act_as(v_e1);
  begin
    insert into public.notifications (type, employee_id, dedupe_key) values ('duty_on', v_e1, 'forged');
    perform pg_temp.check(false, 'write: an employee forged a notification');
  exception when others then
    perform pg_temp.check(true, format('write: an employee cannot forge a notification (%s)', sqlerrm));
  end;

  perform pg_temp.act_as(v_a);
  begin
    insert into public.notifications (type, employee_id, dedupe_key) values ('duty_on', v_e1, 'forged-by-admin');
    perform pg_temp.check(false, 'write: an admin inserted a notification through the API');
  exception when others then
    perform pg_temp.check(true, format('write: not even an admin can insert one (%s)', sqlerrm));
  end;
  begin
    update public.notifications set type = 'duty_off' where session_id = v_s1;
    get diagnostics v_n = row_count;
    perform pg_temp.check(false, 'write: an admin updated a notification');
  exception when others then
    perform pg_temp.check(true, format('write: nobody can edit a notification (%s)', sqlerrm));
  end;
  begin
    delete from public.notifications where session_id = v_s1;
    perform pg_temp.check(false, 'write: an admin deleted a notification');
  exception when others then
    perform pg_temp.check(true, format('write: nobody can delete a notification through the API (%s)', sqlerrm));
  end;

  ---------------------------------------------------------------------------
  -- Read state is per admin
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_a);
  v_a_before := public.unread_notification_count();
  perform pg_temp.act_as(v_b);
  v_b_before := public.unread_notification_count();
  perform pg_temp.check(v_a_before >= 1 and v_a_before = v_b_before,
    format('read state: both admins start with the same unread count (%s / %s)', v_a_before, v_b_before));

  perform pg_temp.act_as(v_a);
  select id into v_id from public.notifications where session_id = v_s1 and type = 'duty_on';
  v_n := public.mark_notifications_read(array[v_id]);
  perform pg_temp.check(v_n = 1 and public.unread_notification_count() = v_a_before - 1,
    'read state: admin A marking one read lowers A''s unread count by one');
  v_n2 := public.mark_notifications_read(array[v_id]);
  perform pg_temp.check(v_n2 = 0 and public.unread_notification_count() = v_a_before - 1,
    'read state: marking it again changes nothing and raises no error');

  perform pg_temp.act_as(v_b);
  perform pg_temp.check(public.unread_notification_count() = v_b_before,
    'read state: B still has it unread after A read it');

  perform pg_temp.act_as(v_a);
  begin
    insert into public.notification_reads (notification_id, admin_id) values (v_id, v_b)
      on conflict do nothing;
    perform pg_temp.check(false, 'read state: A marked a notification read on behalf of B');
  exception when others then
    perform pg_temp.check(true, format('read state: A cannot mark things read for B (%s)', sqlerrm));
  end;

  perform pg_temp.act_as(v_e1);
  perform pg_temp.check(public.unread_notification_count() = 0,
    'employee: the unread count is 0 (nothing is visible to them)');
  perform pg_temp.check(public.mark_all_notifications_read() = 0,
    'employee: mark-all marks nothing');

  ---------------------------------------------------------------------------
  -- First fake-GPS point: one notification, however many fake points
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, is_mock, recorded_at)
  select 'nt-m-' || g, v_s1, v_e1, 20 + g * 0.0001, 73.0, 5, true, now() - interval '100 minutes' + g * interval '10 seconds'
  from generate_series(1, 10) g;
  select count(*) into v_n from public.notifications where type = 'mock_gps' and session_id = v_s1;
  perform pg_temp.check(v_n = 1, format('mock gps: ten fake points raise exactly one notification (%s)', v_n));

  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, is_mock, recorded_at)
  values ('nt-ok-1', v_s1, v_e1, 20.5, 73.0, 5, false, now() - interval '90 minutes');
  select count(*) into v_n from public.notifications where type = 'mock_gps' and session_id = v_s1;
  perform pg_temp.check(v_n = 1, 'mock gps: an ordinary point raises nothing');

  ---------------------------------------------------------------------------
  -- Battery under 15%: once per duty, and only for a recent reading
  ---------------------------------------------------------------------------
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, battery_level, recorded_at)
  values ('nt-b-1', v_s1, v_e1, 20.6, 73.0, 5, 14, now() - interval '1 minute');
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, battery_level, recorded_at)
  values ('nt-b-2', v_s1, v_e1, 20.61, 73.0, 5, 9, now());
  select count(*) into v_n from public.notifications where type = 'battery_low' and session_id = v_s1;
  perform pg_temp.check(v_n = 1, format('battery: two low readings raise one notification (%s)', v_n));
  select details into v_details from public.notifications where type = 'battery_low' and session_id = v_s1;
  perform pg_temp.check((v_details ->> 'battery_level')::int = 14, 'battery: it records the first low reading');

  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, battery_level, recorded_at)
  values ('nt-b-ok', v_s1, v_e1, 20.62, 73.0, 5, 15, now());
  select count(*) into v_n from public.notifications where type = 'battery_low' and session_id = v_s1;
  perform pg_temp.check(v_n = 1, 'battery: exactly 15% is not low');

  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s2, v_e2, 'open', now() - interval '3 hours');
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, battery_level, recorded_at)
  values ('nt-b-old', v_s2, v_e2, 21.0, 73.0, 5, 5, now() - interval '2 hours');
  select count(*) into v_n from public.notifications where type = 'battery_low' and session_id = v_s2;
  perform pg_temp.check(v_n = 0, 'battery: a low reading from 2 hours ago (a late upload) is not news');

  ---------------------------------------------------------------------------
  -- Duty ended: normal, automatic, blocked
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_e1);
  update public.duty_sessions set status = 'completed', ended_at = now() where id = v_s1;
  perform pg_temp.act_as_server();
  select count(*) into v_n from public.notifications where type = 'duty_off' and session_id = v_s1;
  perform pg_temp.check(v_n = 1, 'duty off: ending duty writes exactly one notification');

  perform private.close_session(v_s2, 'auto_curfew', 'auto_curfew', 'Duty ended automatically', now());
  select count(*) into v_n from public.notifications where type = 'duty_auto_ended' and session_id = v_s2;
  perform pg_temp.check(v_n = 1, 'auto end: the 23:00 end is its own notification type');
  select count(*) into v_n from public.notifications where type = 'duty_off' and session_id = v_s2;
  perform pg_temp.check(v_n = 0, 'auto end: it is not also reported as a normal end');

  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s3, v_e3, 'open', now() - interval '1 hour');
  perform pg_temp.act_as(v_a);
  update public.profiles set status = 'blocked', blocked_reason = 'nt test' where id = v_e3;
  perform pg_temp.act_as_server();
  select details ->> 'status' into v_msg from public.notifications where type = 'duty_off' and session_id = v_s3;
  perform pg_temp.check(v_msg = 'blocked', format('block: blocking an employee on duty ends it and says why (%s)', v_msg));

  ---------------------------------------------------------------------------
  -- Tracking broken: no data for 10 minutes
  ---------------------------------------------------------------------------
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s4, v_e4, 'open', now() - interval '2 hours');
  insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, recorded_at)
  values ('nt-s4-1', v_s4, v_e4, 22.0, 73.0, 5, now());

  v_n := private.raise_no_signal_alerts();
  select count(*) into v_n2 from public.notifications where type = 'no_signal' and session_id = v_s4;
  perform pg_temp.check(v_n2 = 0, 'silence: data that just arrived raises nothing');

  update public.live_locations set updated_at = now() - interval '9 minutes' where employee_id = v_e4;
  perform private.raise_no_signal_alerts();
  select count(*) into v_n2 from public.notifications where type = 'no_signal' and session_id = v_s4;
  perform pg_temp.check(v_n2 = 0, 'silence: 9 minutes is not yet an alert');

  update public.live_locations set updated_at = now() - interval '11 minutes' where employee_id = v_e4;
  v_n := private.raise_no_signal_alerts();
  select count(*) into v_n2 from public.notifications where type = 'no_signal' and session_id = v_s4;
  perform pg_temp.check(v_n2 = 1 and v_n >= 1, format('silence: 11 minutes without data raises one alert (%s)', v_n2));

  perform private.raise_no_signal_alerts();
  perform private.raise_no_signal_alerts();
  select count(*) into v_n2 from public.notifications where type = 'no_signal' and session_id = v_s4;
  perform pg_temp.check(v_n2 = 1, 'silence: the job running every minute does not repeat the alert');

  update public.live_locations set updated_at = now() where employee_id = v_e4;
  perform private.raise_no_signal_alerts();
  select count(*) into v_n2 from public.notifications where type = 'no_signal' and session_id = v_s4;
  perform pg_temp.check(v_n2 = 1, 'silence: data resuming raises nothing');

  update public.live_locations set updated_at = now() - interval '12 minutes' where employee_id = v_e4;
  perform private.raise_no_signal_alerts();
  select count(*) into v_n2 from public.notifications where type = 'no_signal' and session_id = v_s4;
  perform pg_temp.check(v_n2 = 2, 'silence: a NEW silence after data resumed is a new alert');

  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s5, v_e5, 'open', now() - interval '15 minutes');
  insert into public.duty_sessions (id, employee_id, status, started_at)
  values (v_s5b, v_e6, 'open', now() - interval '5 minutes');
  perform private.raise_no_signal_alerts();
  select (details ->> 'never_sent')::boolean into v_msg from public.notifications where type = 'no_signal' and session_id = v_s5;
  perform pg_temp.check(v_msg::boolean is true, 'silence: a duty that never sent a first point, 15 minutes in, raises an alert');
  select count(*) into v_n2 from public.notifications where type = 'no_signal' and session_id = v_s5b;
  perform pg_temp.check(v_n2 = 0, 'silence: a duty only 5 minutes old with no point yet is not an alert');

  perform private.close_session(v_s4, 'completed', 'normal', null, now());
  update public.live_locations set updated_at = now() - interval '30 minutes' where employee_id = v_e4;
  select count(*) into v_n from public.notifications where type = 'no_signal' and session_id = v_s4;
  perform private.raise_no_signal_alerts();
  select count(*) into v_n2 from public.notifications where type = 'no_signal' and session_id = v_s4;
  perform pg_temp.check(v_n2 = v_n, 'silence: a duty that has ended is never alerted about');

  ---------------------------------------------------------------------------
  -- A notification that cannot be written must not stop tracking
  ---------------------------------------------------------------------------
  alter table public.notifications add constraint zz_nt_always_fails check (false) not valid;
  begin
    insert into public.duty_sessions (id, employee_id, status, started_at)
    values (v_s6, v_e7, 'open', now() - interval '30 seconds');
    insert into public.location_points (id, session_id, employee_id, latitude, longitude, accuracy, is_mock, battery_level, recorded_at)
    values ('nt-safe-1', v_s6, v_e7, 23.0, 73.0, 5, true, 3, now());
    perform pg_temp.check(
      exists (select 1 from public.duty_sessions where id = v_s6)
        and exists (select 1 from public.location_points where id = 'nt-safe-1'),
      'safety: with notification writes failing, a duty still starts and a fake, low-battery point is still stored');
  exception when others then
    perform pg_temp.check(false, format('safety: a failing notification write BROKE tracking (%s)', sqlerrm));
  end;
  alter table public.notifications drop constraint zz_nt_always_fails;

  ---------------------------------------------------------------------------
  -- Plumbing: Realtime, jobs, and who can run the internals
  ---------------------------------------------------------------------------
  perform pg_temp.check(
    exists (select 1 from pg_publication_tables
            where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'),
    'realtime: notifications are published, so admins get them live');
  perform pg_temp.check(
    (select count(*) from cron.job
      where active and (
        (jobname = 'raise-no-signal-alerts' and schedule = '* * * * *') or
        (jobname = 'purge-old-notifications' and schedule = '0 22 * * 0'))) = 2,
    'jobs: the silence check (every minute) and the 6-month cleanup (weekly) are scheduled');

  perform pg_temp.act_as(v_e1);
  begin
    perform private.raise_no_signal_alerts();
    perform pg_temp.check(false, 'access: an employee ran the silence check');
  exception when others then
    perform pg_temp.check(true, format('access: an employee cannot run the silence check (%s)', sqlerrm));
  end;
  begin
    perform private.notify('duty_on', v_e1, null, 'x', '{}');
    perform pg_temp.check(false, 'access: an employee called private.notify');
  exception when others then
    perform pg_temp.check(true, format('access: an employee cannot call private.notify (%s)', sqlerrm));
  end;
  perform pg_temp.act_as_anon();
  begin
    perform public.unread_notification_count();
    perform pg_temp.check(false, 'access: a signed-out visitor called unread_notification_count');
  exception when others then
    perform pg_temp.check(true, format('access: a signed-out visitor is refused (%s)', sqlerrm));
  end;

  ---------------------------------------------------------------------------
  -- Mark all read, and the 6-month cleanup
  ---------------------------------------------------------------------------
  perform pg_temp.act_as(v_a);
  perform public.mark_all_notifications_read();
  perform pg_temp.check(public.unread_notification_count() = 0, 'read state: mark-all leaves admin A with nothing unread');
  perform pg_temp.act_as(v_b);
  perform pg_temp.check(public.unread_notification_count() > 0, 'read state: and admin B still has unread ones');

  perform pg_temp.act_as_server();
  insert into public.notifications (type, employee_id, session_id, dedupe_key, details, created_at)
  values ('duty_on', v_e1, null, 'nt-old', '{}', now() - interval '7 months'),
         ('duty_on', v_e1, null, 'nt-recent', '{}', now() - interval '5 months');
  v_n := private.purge_old_notifications();
  perform pg_temp.check(
    v_n >= 1
      and not exists (select 1 from public.notifications where dedupe_key = 'nt-old')
      and exists (select 1 from public.notifications where dedupe_key = 'nt-recent'),
    format('cleanup: a 7-month-old notification is deleted, a 5-month-old one is kept (deleted %s)', v_n));

  ---------------------------------------------------------------------------
  -- Report: always end with an exception; it carries the report AND rolls back
  ---------------------------------------------------------------------------
  perform pg_temp.act_as_server();
  raise exception E'NOTIFICATIONS ATTACK CHECK REPORT (intentional error: rolls everything back)\n%\n\nRESULT: % passed, % failed\n%',
    current_setting('attack.report', true),
    regexp_count(current_setting('attack.report', true), E'\nPASS  '),
    regexp_count(current_setting('attack.report', true), E'\nFAIL  '),
    case when regexp_count(current_setting('attack.report', true), E'\nFAIL  ') > 0
         then '>>> DO NOT RELY ON THIS MIGRATION <<<' else '>>> ALL CHECKS PASSED <<<' end;
end $$;

rollback;
