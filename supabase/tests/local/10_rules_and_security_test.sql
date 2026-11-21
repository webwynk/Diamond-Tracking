-- Tests for the baseline migration, run on a plain local Postgres after
-- 00_supabase_stub.sql and the migration (see supabase/tests/README.txt).
-- Every check raises an exception on failure, so psql stops with the reason.

\set ON_ERROR_STOP 1

create schema t;

-- Act as a signed-in user (or anon when uid is null).
create function t.act_as(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), false);
  perform set_config('role', case when p_uid is null then 'anon' else 'authenticated' end, false);
end;
$$;

create function t.act_as_owner() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', false);
  perform set_config('request.jwt.claim.sub', '', false);
end;
$$;

-- Runs p_sql and checks that it fails with a message containing p_expected.
-- The "it succeeded" error is raised outside the handler: raised inside, its
-- own text contains the expected word and the check passed by mistake.
create function t.expect_error(p_sql text, p_expected text) returns void
language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if sqlerrm not like '%' || p_expected || '%' then
      raise exception 'expected error "%" but got "%" for: %', p_expected, sqlerrm, p_sql;
    end if;
    return;
  end;
  raise exception 'expected error "%" but it succeeded: %', p_expected, p_sql;
end;
$$;

create function t.eq(p_actual anyelement, p_expected anyelement, p_what text) returns void
language plpgsql as $$
begin
  if p_actual is distinct from p_expected then
    raise exception '%: expected %, got %', p_what, p_expected, p_actual;
  end if;
end;
$$;

grant usage on schema t to anon, authenticated, service_role;
grant execute on all functions in schema t to anon, authenticated, service_role;

-- People
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'admin@test'),
  ('00000000-0000-0000-0000-000000000001', 'e1@test'),
  ('00000000-0000-0000-0000-000000000002', 'e2@test'),
  ('00000000-0000-0000-0000-000000000003', 'e3@test');
insert into public.profiles (id, user_code, full_name, role, created_at) values
  ('00000000-0000-0000-0000-00000000000a', 'ADMIN1', 'Admin One', 'admin', now() - interval '30 days'),
  ('00000000-0000-0000-0000-000000000001', 'DA-001', 'Employee One', 'employee', now() - interval '30 days'),
  ('00000000-0000-0000-0000-000000000002', 'DA-002', 'Employee Two', 'employee', now() - interval '30 days'),
  ('00000000-0000-0000-0000-000000000003', 'DA-003', 'Employee Three', 'employee', now() - interval '30 days');

update public.profiles set active_device_id = 'dev-e1-0001' where user_code = 'DA-001';
update public.profiles set active_device_id = 'dev-e2-0001' where user_code = 'DA-002';
update public.profiles set active_device_id = 'dev-e3-0001' where user_code = 'DA-003';

\echo '--- helpers'
do $$
begin
  perform t.eq(round(private.dist_m(0, 0, 1000000, 0))::int, 111195, '1 degree of latitude');
  -- Google's documented example: (38.5, -120.2), (40.7, -120.95), (43.252, -126.453)
  perform t.eq(
    private.polyline_chunk(3850000) || private.polyline_chunk(-12020000)
    || private.polyline_chunk(220000) || private.polyline_chunk(-75000)
    || private.polyline_chunk(255200) || private.polyline_chunk(-550300),
    '_p~iF~ps|U_ulLnnqC_mqNvxq`@', 'polyline encoding');
  perform t.eq(private.auto_off_at(date '2026-11-20'),
               timestamptz '2026-11-20 17:30:00+00', '23:00 IST in UTC');
end;
$$;

\echo '--- anonymous visitors see and do nothing'
select t.act_as(null);
select t.expect_error('select count(*) from public.profiles', 'permission denied');
select t.expect_error($$select public.duty_on('dev-e1-0001')$$, 'permission denied');
select t.act_as_owner();

\echo '--- an employee sees only their own rows and cannot write tables'
select t.act_as('00000000-0000-0000-0000-000000000001');
do $$
begin
  perform t.eq((select count(*) from public.profiles), 1::bigint, 'employee sees own profile only');
end;
$$;
select t.expect_error($$update public.profiles set role = 'admin'$$, 'permission denied');
select t.expect_error($$insert into public.duty_days (user_id, day, status)
  values ('00000000-0000-0000-0000-000000000001', current_date, 'present')$$, 'permission denied');
select t.expect_error($$delete from public.notifications$$, 'permission denied');
select t.expect_error($$select public.set_day_status('00000000-0000-0000-0000-000000000002',
  current_date - 1, 'absent')$$, 'not_admin');
select t.expect_error($$select public.decide_request(1, 'present')$$, 'not_admin');
select t.expect_error($$select private.auto_duty_off()$$, 'permission denied');
select t.act_as_owner();

\echo '--- admins see everyone'
select t.act_as('00000000-0000-0000-0000-00000000000a');
do $$
begin
  perform t.eq((select count(*) from public.profiles), 4::bigint, 'admin sees all profiles');
end;
$$;
select t.expect_error($$select public.duty_on('dev-ad-0001')$$, 'not_active_employee');
select t.act_as_owner();

\echo '--- duty on follows the 05:00 to 08:30 IST window'
select t.act_as('00000000-0000-0000-0000-000000000003');
do $$
declare
  v_time time := (now() at time zone 'Asia/Kolkata')::time;
begin
  if v_time >= time '05:00' and v_time < time '08:31' then
    perform t.eq(length(public.duty_on('dev-e3-0001')->>'upload_pass'), 64, 'duty on gives an upload pass');
    perform t.expect_error($q$select public.duty_on('dev-e3-0001')$q$, 'already_on_duty_today');
    -- Leave no duty behind: later checks set up their own (L94).
    perform t.act_as_owner();
    delete from public.duty_days where user_id = '00000000-0000-0000-0000-000000000003';
  else
    perform t.expect_error($q$select public.duty_on('dev-e3-0001')$q$, 'duty_on_closed');
  end if;
end;
$$;
select t.act_as_owner();

\echo '--- permissions end at 9:00 PM India time (L28)'
select t.act_as_owner();
select t.eq(private.permit_cutoff_at(date '2026-11-21'), timestamptz '2026-11-21 21:00:00+05:30',
            'permission cut-off is 9:00 PM IST');
select t.eq(private.permit_cutoff_at(date '2026-11-21') < private.auto_off_at(date '2026-11-21'), true,
            'cut-off is before the 11 PM auto duty off');

\echo '--- the admin can allow duty on outside the window, for today, once'
select t.act_as_owner();
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000004', 'e4@test');
insert into public.profiles (id, user_code, full_name, role, created_at, active_device_id)
values ('00000000-0000-0000-0000-000000000004', 'DA-004', 'Employee Four', 'employee',
        now() - interval '30 days', 'dev-e4-0001');
do $$
declare
  v_time time := (now() at time zone 'Asia/Kolkata')::time;
  v_closed boolean := v_time < time '05:00' or v_time >= time '08:31';
  v_late boolean := v_time >= time '21:00';  -- permission cut-off (L28)
  e4 constant uuid := '00000000-0000-0000-0000-000000000004';
begin
  -- Only an admin can allow, and only for an active employee.
  perform t.act_as(e4);
  perform t.expect_error(format('select public.allow_duty_on(%L)', e4), 'not_admin');
  perform t.expect_error(format('select public.revoke_duty_on(%L)', e4), 'not_admin');
  perform t.act_as(null);
  perform t.expect_error(format('select public.allow_duty_on(%L)', e4), 'permission denied');
  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform t.expect_error(format('select public.allow_duty_on(%L)', gen_random_uuid()), 'user_not_found');
  perform t.expect_error(format('select public.allow_duty_on(%L)', '00000000-0000-0000-0000-00000000000a'), 'user_not_found');

  if v_late then
    -- After 9:00 PM no permission can be given (L28) ...
    perform t.expect_error(format('select public.allow_duty_on(%L)', e4), 'too_late');
    -- ... and one given earlier can no longer start a duty.
    perform t.act_as_owner();
    insert into public.duty_permits (user_id, day) values (e4, private.ist_today());
    perform t.act_as(e4);
    perform t.expect_error($q$select public.duty_on('dev-e4-0001')$q$, 'duty_on_closed');
    perform t.act_as_owner();
    delete from public.duty_permits;
    return;
  end if;

  if v_closed then
    perform t.act_as(e4);
    perform t.expect_error($q$select public.duty_on('dev-e4-0001')$q$, 'duty_on_closed');
  end if;

  -- Allow, then take it back before it is used.
  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform public.allow_duty_on(e4, '  Late start  ');
  perform t.act_as(e4);
  perform t.eq((select count(*) from public.duty_permits), 1::bigint, 'the employee sees their permission');
  perform t.expect_error(format('insert into public.duty_permits (user_id, day) values (%L, current_date)', e4),
                         'permission denied');
  perform t.act_as('00000000-0000-0000-0000-000000000002');
  perform t.eq((select count(*) from public.duty_permits), 0::bigint, 'others do not see it');
  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform t.eq((select count(*) from public.duty_permits), 1::bigint, 'admin sees it');
  perform t.eq((select note from public.duty_permits), 'Late start', 'note trimmed');
  perform t.eq(public.revoke_duty_on(e4), true, 'taken back');
  perform t.eq(public.revoke_duty_on(e4), false, 'nothing left to take back');
  if v_closed then
    perform t.act_as(e4);
    perform t.expect_error($q$select public.duty_on('dev-e4-0001')$q$, 'duty_on_closed');
  end if;

  -- Allow again and use it: once.
  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform public.allow_duty_on(e4);
  perform t.act_as_owner();
  perform t.eq((select count(*) from public.notifications
                where user_id = e4 and kind = 'duty_on_allowed'), 2::bigint, 'the employee is told');
  perform t.eq((select count(*) from public.admin_log where action in ('allow_duty_on', 'revoke_duty_on')
                and target_user = e4), 3::bigint, 'allowed and revoked are logged');
  perform t.act_as(e4);
  perform t.eq(length(public.duty_on('dev-e4-0001')->>'upload_pass'), 64, 'duty on works with permission');
  -- A second press says "already on", not "closed" (L6).
  perform t.expect_error($q$select public.duty_on('dev-e4-0001')$q$, 'already_on_duty_today');
  perform t.act_as_owner();
  -- Used up whether duty on was inside the 5:00-8:30 window or not, so it
  -- never shows as "not used yet" after the duty started (L27).
  perform t.eq((select used_at is not null from public.duty_permits where user_id = e4), true, 'permission used');
  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform t.expect_error(format('select public.allow_duty_on(%L)', e4), 'day_already_recorded');

  -- A used permission does not give a second duty.
  perform t.act_as_owner();
  delete from public.duty_days where user_id = e4;
  if v_closed then
    perform t.act_as(e4);
    perform t.expect_error($q$select public.duty_on('dev-e4-0001')$q$, 'duty_on_closed');
  end if;
  perform t.act_as_owner();
  delete from public.duty_permits;
  delete from public.notifications where user_id = e4;
end;
$$;
select t.act_as_owner();
delete from public.profiles where id = '00000000-0000-0000-0000-000000000004';
delete from auth.users where id = '00000000-0000-0000-0000-000000000004';

\echo '--- a full day: points, a stop, a phone-off gap, duty off capped at 23:00'
do $$
declare
  v_day date := private.ist_today() - 1;
  v_id bigint;
  v_row public.duty_days;
  v_pass text;
  v_points jsonb := '[]';
  v_t timestamptz := private.ist_at(v_day, time '07:00');
  i integer;
begin
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values ('00000000-0000-0000-0000-000000000001', v_day, 'on_duty', v_t)
  returning * into v_row;
  v_id := v_row.id;
  v_pass := private.new_upload_pass(v_row, 'dev-e1-0001');
  -- 30 minutes driving north, 100 m a minute (3 km).
  for i in 0..30 loop
    v_points := v_points || jsonb_build_object('t', v_t + make_interval(mins => i),
      'la', 22500000 + i * 899, 'lo', 88300000, 'a', 8, 'b', 90);
  end loop;
  -- 40 minutes at a dealer, a point every 5 minutes with small jitter.
  for i in 1..8 loop
    v_points := v_points || jsonb_build_object('t', v_t + make_interval(mins => 30 + i * 5),
      'la', 22500000 + 30 * 899 + (i % 2) * 40, 'lo', 88300000, 'a', 12, 'b', 85);
  end loop;
  -- A bad fix far away is ignored, and a point with poor accuracy too.
  v_points := v_points || jsonb_build_object('t', v_t + interval '72 minutes',
    'la', 23500000, 'lo', 88300000, 'a', 10, 'b', 85);
  v_points := v_points || jsonb_build_object('t', v_t + interval '73 minutes',
    'la', 22600000, 'lo', 88300000, 'a', 400, 'b', 85);
  -- Phone off for an hour, then 10 minutes driving east (about 1 km).
  for i in 0..10 loop
    v_points := v_points || jsonb_build_object('t', v_t + make_interval(mins => 130 + i),
      'la', 22500000 + 30 * 899, 'lo', 88300000 + i * 973, 'a', 8, 'b', 60);
  end loop;
  -- Outside the duty: ignored.
  v_points := v_points || jsonb_build_object('t', v_t - interval '2 hours',
    'la', 22500000, 'lo', 88300000, 'a', 8, 'b', 90);

  -- The tracker has no session, only the day's pass.
  perform t.act_as(null);
  perform t.eq(public.upload_points_with_pass(v_id, v_pass, v_points), 52, 'points stored');
  perform t.eq(public.upload_points_with_pass(v_id, v_pass, v_points), 0, 'a retried upload adds nothing');
  perform t.expect_error(format($q$select public.upload_points_with_pass(%s, 'not-the-pass', '[]')$q$, v_id),
                         'invalid_upload_pass');

  -- Another employee cannot touch this duty.
  perform t.act_as('00000000-0000-0000-0000-000000000002');
  perform t.expect_error(format($q$select public.upload_points_with_pass(%s, 'not-the-pass', %L)$q$, v_id, v_points),
                         'invalid_upload_pass');
  perform t.expect_error(format('select public.duty_off(%s)', v_id), 'duty_not_found');
  perform t.eq((select count(*) from public.track_points), 0::bigint, 'others cannot read points');

  perform t.act_as('00000000-0000-0000-0000-000000000001');
  -- A time after 23:00 is capped to 23:00.
  perform public.duty_off(v_id, now());
  perform t.act_as_owner();

  perform t.eq((select status from public.duty_days where id = v_id), 'present'::public.day_status, 'long day is present');
  perform t.eq((select duty_off_at from public.duty_days where id = v_id), private.auto_off_at(v_day), 'duty off capped at 23:00');
  perform t.eq((select worked_minutes from public.duty_days where id = v_id), 16 * 60, 'worked minutes');
  perform t.eq((select jsonb_array_length(stops) from public.day_routes where duty_day_id = v_id), 1, 'one stop');
  perform t.eq((select jsonb_array_length(gaps) from public.day_routes where duty_day_id = v_id), 1, 'one phone-off gap');
  perform t.eq((select cardinality(segments) from public.day_routes where duty_day_id = v_id), 2, 'route split at the gap');
  if (select distance_m from public.duty_days where id = v_id) not between 3800 and 4200 then
    raise exception 'distance should be about 4 km, got %',
      (select distance_m from public.duty_days where id = v_id);
  end if;
  perform t.eq((select count(*) from public.requests where user_id = '00000000-0000-0000-0000-000000000001'),
               0::bigint, 'no review for a full day');
end;
$$;

\echo '--- a short day waits for the admin, who decides half day'
do $$
declare
  v_day date := private.ist_today() - 2;
  v_id bigint;
  v_req bigint;
  v_off timestamptz := private.ist_at(v_day, time '12:00');
begin
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values ('00000000-0000-0000-0000-000000000001', v_day, 'on_duty', private.ist_at(v_day, time '07:00'))
  returning id into v_id;
  perform t.act_as('00000000-0000-0000-0000-000000000001');
  perform public.duty_off(v_id, v_off);
  perform t.eq((select status from public.duty_days where id = v_id), 'pending'::public.day_status, 'short day pending');
  select id into v_req from public.requests where kind = 'short_duty' and day = v_day;
  perform t.eq(v_req is not null, true, 'short duty request created');
  perform t.expect_error(format('select public.cancel_request(%s)', v_req), 'request_not_cancellable');

  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform t.eq((select count(*) from public.notifications where kind = 'short_duty'), 1::bigint, 'admin notified');
  perform t.eq((select (data->>'request_id')::bigint from public.notifications where kind = 'short_duty'),
               (select id from public.requests where kind = 'short_duty' order by id desc limit 1),
               'the alert names its request');
  perform t.expect_error(format($q$select public.decide_request(%s, 'leave')$q$, v_req), 'invalid_decision');
  perform public.decide_request(v_req, 'half_day', 'Left early, approved');
  perform t.expect_error(format($q$select public.decide_request(%s, 'present')$q$, v_req), 'request_already_decided');

  perform t.act_as('00000000-0000-0000-0000-000000000001');
  perform t.eq((select status from public.duty_days where id = v_id), 'half_day'::public.day_status, 'half day after decision');
  perform t.eq((select status from public.requests where id = v_req), 'approved'::public.request_status, 'request approved');
  perform t.eq((select count(*) from public.notifications where kind = 'request_decided'), 1::bigint, 'employee notified');
  perform t.eq((select count(*) from public.notifications where kind = 'short_duty'), 0::bigint, 'employee cannot see admin alerts');
  perform t.eq(public.mark_notifications_read(), 1, 'mark read');
  perform t.act_as_owner();
  perform t.eq((select count(*) from public.admin_log where action = 'decide_request'), 1::bigint, 'decision logged');
  perform t.eq((select decided_by from public.duty_days where id = v_id),
               '00000000-0000-0000-0000-00000000000a'::uuid, 'who decided is kept');
end;
$$;

\echo '--- 11 PM automatic duty off and absent marking'
do $$
declare
  v_day date := private.ist_today() - 1;
  v_id bigint;
begin
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values ('00000000-0000-0000-0000-000000000002', v_day, 'on_duty', private.ist_at(v_day, time '08:30'))
  returning id into v_id;
  perform t.eq(private.auto_duty_off(), 1, 'one duty closed');
  perform t.eq(private.auto_duty_off(), 0, 'running again changes nothing');
  perform t.eq((select end_reason from public.duty_days where id = v_id), 'auto'::public.duty_end_reason, 'auto end');
  perform t.eq((select duty_off_at from public.duty_days where id = v_id), private.auto_off_at(v_day), 'closed at 23:00');
  perform t.eq((select status from public.duty_days where id = v_id), 'present'::public.day_status, '14.5 h is present');

  perform t.eq(private.mark_absent(v_day), 1, 'only the employee with nothing is absent');
  perform t.eq((select status from public.duty_days
                where user_id = '00000000-0000-0000-0000-000000000003' and day = v_day),
               'absent'::public.day_status, 'absent recorded');
end;
$$;

\echo '--- attendance requests'
do $$
declare
  v_today date := private.ist_today();
  v_req bigint;
  v_leave bigint;
begin
  perform t.act_as('00000000-0000-0000-0000-000000000003');
  -- Day 1 back was marked absent above; the request can still fix it.
  select id into v_req from public.request_attendance(v_today - 1, time '09:00', time '19:30', 'Forgot to duty on', 'req-11111111-2222-3333-4444-555555555555');
  perform t.expect_error(format($q$select public.request_attendance(%L, '09:00', '19:30', 'again', 'req-11111111-2222-3333-4444-555555555555')$q$, v_today - 1), 'already_requested');
  perform t.expect_error(format($q$select public.request_attendance(%L, '09:00', '19:30', 'old', 'req-11111111-2222-3333-4444-555555555555')$q$, v_today - 8), 'outside_request_window');
  perform t.expect_error(format($q$select public.request_attendance(%L, '19:00', '09:00', 'x', 'req-11111111-2222-3333-4444-555555555555')$q$, v_today - 3), 'invalid_times');
  perform t.expect_error(format($q$select public.request_attendance(%L, '09:00', '18:00', 'x', null)$q$, v_today - 3), 'photo_required');
  perform t.expect_error(format($q$select public.request_attendance(%L, '09:00', '18:00', 'x', 'photo/abc')$q$, v_today - 3), 'photo_required');
  perform t.expect_error(format($q$select public.request_attendance(%L, '09:00', '18:00', '  ', 'req-11111111-2222-3333-4444-555555555555')$q$, v_today - 3), 'message_required');
  -- Leave for a day with an attendance request waiting is refused (L18).
  perform t.expect_error(format($q$select public.request_leave('sick', array[%L::date, %L::date], 'x')$q$, v_today - 1, v_today), 'already_requested');
  -- ... and attendance for a day with leave waiting (L18).
  select id into v_leave from public.request_leave('casual', array[v_today - 4], 'Wedding');
  perform t.expect_error(format($q$select public.request_attendance(%L, '09:00', '18:00', 'x', 'req-11111111-2222-3333-4444-555555555555')$q$, v_today - 4), 'already_requested');
  perform public.cancel_request(v_leave);
  perform t.act_as('00000000-0000-0000-0000-000000000001');
  perform t.expect_error(format($q$select public.request_attendance(%L, '09:00', '19:30', 'x', 'req-11111111-2222-3333-4444-555555555555')$q$, v_today - 1), 'already_has_duty');

  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform public.decide_request(v_req, 'present');
  perform t.act_as_owner();
  perform t.eq((select status from public.duty_days
                where user_id = '00000000-0000-0000-0000-000000000003' and day = v_today - 1),
               'present'::public.day_status, 'approved attendance is present');
  perform t.eq((select worked_minutes from public.duty_days
                where user_id = '00000000-0000-0000-0000-000000000003' and day = v_today - 1),
               630, 'requested hours count');
end;
$$;

\echo '--- leave requests'
do $$
declare
  v_today date := private.ist_today();
  v_req public.requests;
begin
  perform t.act_as('00000000-0000-0000-0000-000000000002');
  v_req := public.request_leave('casual', array[v_today + 2, v_today + 1, v_today + 2], 'Family function');
  perform t.eq(v_req.dates, array[v_today + 1, v_today + 2], 'dates sorted and unique');
  perform public.cancel_request(v_req.id);
  perform t.expect_error(format('select public.cancel_request(%s)', v_req.id), 'request_not_cancellable');
  perform t.expect_error(format($q$select public.request_leave('sick', array[%L::date], 'x', 'proof/1')$q$, v_today + 1), 'invalid_photo');
  perform t.expect_error(format($q$select public.request_leave('sick', array[%L::date], 'x')$q$, v_today + 120), 'invalid_dates');
  perform t.expect_error(format($q$select public.request_leave('sick', array[%L::date, null], 'x')$q$, v_today + 1), 'invalid_dates');
  v_req := public.request_leave('sick', array[v_today - 1, v_today + 1], 'Fever', 'req-aaaaaaaa-2222-3333-4444-555555555555');

  perform t.expect_error(format($q$select public.request_leave('casual', array[%L::date], 'overlap')$q$, v_today + 1), 'already_requested');
  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform public.decide_request(v_req.id, 'leave');
  perform t.act_as_owner();
  perform t.eq((select status from public.duty_days
                where user_id = '00000000-0000-0000-0000-000000000002' and day = v_today + 1),
               'leave'::public.day_status, 'leave day recorded');
  perform t.eq((select leave_type from public.duty_days
                where user_id = '00000000-0000-0000-0000-000000000002' and day = v_today + 1),
               'sick'::public.leave_type, 'leave type kept');
  -- Yesterday was worked, so it keeps its duty.
  perform t.eq((select status from public.duty_days
                where user_id = '00000000-0000-0000-0000-000000000002' and day = v_today - 1),
               'present'::public.day_status, 'a worked day is not overwritten by leave');
end;
$$;

\echo '--- admin override is logged and can be undone'
do $$
declare
  v_day date := private.ist_today() - 1;
begin
  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform public.set_day_status('00000000-0000-0000-0000-000000000001', v_day, 'absent', null, 'Was not in the field');
  perform t.expect_error(format($q$select public.set_day_status('00000000-0000-0000-0000-000000000001', %L, 'present')$q$,
                                v_day + 2), 'future_day');
  perform t.expect_error(format($q$select public.set_day_status('00000000-0000-0000-0000-000000000001', %L, 'leave')$q$, v_day),
                         'invalid_decision');
  perform public.set_day_status('00000000-0000-0000-0000-000000000001', v_day, 'present');
  perform t.act_as_owner();
  perform t.eq((select details->>'from' from public.admin_log where action = 'set_day_status' order by id limit 1),
               'present', 'previous status logged');
  perform t.eq((select status from public.duty_days
                where user_id = '00000000-0000-0000-0000-000000000001' and day = v_day),
               'present'::public.day_status, 'undo works');
end;
$$;

\echo '--- visits need an open duty, a store name and their own photo; gallery photos carry no GPS'
select t.act_as('00000000-0000-0000-0000-000000000001');
select t.expect_error($$select public.add_visit('aaaaaaaa-0000-0000-0000-000000000001', 'Shop', null, false,
  22500000, 88300000, 'visit-aaaaaaaa-0000-0000-0000-000000000001', now())$$, 'not_on_duty');
select t.act_as_owner();
do $$
declare
  v_id uuid := 'aaaaaaaa-0000-0000-0000-000000000002';
  v_cam uuid := 'aaaaaaaa-0000-0000-0000-000000000003';
  v public.visits;
begin
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values ('00000000-0000-0000-0000-000000000001', private.ist_today(), 'on_duty', now() - interval '1 hour');
  perform t.act_as('00000000-0000-0000-0000-000000000001');
  perform t.expect_error(format('select public.add_visit(%L, %L, null, true, null, null, %L, now())',
    v_id, '  ', 'visit-' || v_id), 'store_name_required');
  perform t.expect_error(format('select public.add_visit(%L, %L, null, true, null, null, %L, now())',
    v_id, 'Shop', 'req-' || v_id), 'photo_required');
  perform t.expect_error(format('select public.add_visit(%L, %L, null, true, null, null, %L, now())',
    v_id, 'Shop', 'visit-' || v_cam), 'photo_required');
  perform t.expect_error(format('select public.add_visit(%L, %L, null, false, null, null, %L, now())',
    v_cam, 'Shop', 'visit-' || v_cam), 'location_required');
  perform t.expect_error(format('select public.add_visit(%L, %L, %L, true, null, null, %L, now())',
    v_id, 'Shop', repeat('x', 301), 'visit-' || v_id), 'note_too_long');

  v := public.add_visit(v_id, ' Krishi Kendra ', 'Order taken', true, 22500000, 88300000, 'visit-' || v_id, now());
  perform t.eq(v.lat_e6, null::integer, 'gallery photo has no GPS');
  perform t.eq(v.store_name, 'Krishi Kendra', 'store name trimmed');
  v := public.add_visit(v_id, 'Krishi Kendra', 'Order taken', true, null, null, 'visit-' || v_id, now());
  perform t.eq(v.accuracy_m, null::integer, 'gallery photo has no accuracy');
  v := public.add_visit(v_cam, 'Agro Store', null, false, 22500000, 88300000, 'visit-' || v_cam,
                        now() - interval '70 minutes', false, 35);
  perform t.eq(v.lat_e6, 22500000, 'camera photo keeps GPS');
  perform t.eq(v.accuracy_m, 35, 'camera photo keeps its accuracy (L59)');
  perform t.eq(v.captured_at >= now() - interval '1 hour', true, 'time not before duty on');
  perform t.expect_error($q$insert into public.visits (id, user_id, duty_day_id, from_gallery, captured_at)
    values (gen_random_uuid(), '00000000-0000-0000-0000-000000000001', 1, true, now())$q$, 'permission denied');
  perform t.act_as_owner();
  perform t.eq((select count(*) from public.visits), 2::bigint, 'a retried visit is not duplicated');

  -- Someone else cannot take over the id, or see the visit.
  perform t.act_as('00000000-0000-0000-0000-000000000002');
  perform t.eq((select count(*) from public.visits), 0::bigint, 'others see no visits');
  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform t.eq((select count(*) from public.visits), 2::bigint, 'admin sees visits');
  perform t.act_as_owner();
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values ('00000000-0000-0000-0000-000000000003', private.ist_today(), 'on_duty', now() - interval '1 hour');
  perform t.act_as('00000000-0000-0000-0000-000000000003');
  perform t.expect_error(format('select public.add_visit(%L, %L, null, true, null, null, %L, now())',
    v_id, 'Shop', 'visit-' || v_id), 'invalid_visit');
  perform t.act_as_owner();
  delete from public.duty_days where user_id = '00000000-0000-0000-0000-000000000003';
end;
$$;

\echo '--- a visit kept on the phone without internet goes into its own duty, even after duty off (M10)'
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000014', 'e14@test');
insert into public.profiles (id, user_code, full_name, role, created_at, active_device_id)
values ('00000000-0000-0000-0000-000000000014', 'DA-014', 'Employee Fourteen', 'employee',
        now() - interval '30 days', 'dev-e14-0001');
do $$
declare
  e1 uuid := '00000000-0000-0000-0000-000000000014';
  v_old public.duty_days;
  v_late uuid := 'aaaaaaaa-0000-0000-0000-000000000010';
  v_stale uuid := 'aaaaaaaa-0000-0000-0000-000000000011';
  v public.visits;
  t1130 timestamptz := private.ist_at(private.ist_today() - 2, time '11:30');
  t2000 timestamptz := private.ist_at(private.ist_today() - 2, time '20:00');
  t3d timestamptz := private.ist_at(private.ist_today() - 3, time '11:30');
begin
  -- Two days ago: duty 07:00 to 18:00, already closed.
  insert into public.duty_days (user_id, day, status, duty_on_at, duty_off_at)
  values (e1, private.ist_today() - 2, 'present',
          private.ist_at(private.ist_today() - 2, time '07:00'),
          private.ist_at(private.ist_today() - 2, time '18:00'))
  returning * into v_old;
  perform t.act_as(e1);
  v := public.add_visit(v_late, 'Late Shop', null, false, 22500000, 88300000, 'visit-' || v_late,
                        t1130);
  perform t.eq(v.duty_day_id, v_old.id, 'late visit goes into the duty it was taken in');
  perform t.eq(v.captured_at, t1130, 'its own time kept');
  -- A time outside every duty (that evening, after duty off) is refused.
  perform t.expect_error(format('select public.add_visit(%L, %L, null, true, null, null, %L, %L)',
    v_stale, 'Shop', 'visit-' || v_stale, t2000),
    'not_on_duty');
  -- So is a duty more than 2 days back.
  perform t.act_as_owner();
  update public.duty_days set day = day - 1,
    duty_on_at = duty_on_at - interval '1 day', duty_off_at = duty_off_at - interval '1 day'
  where id = v_old.id;
  perform t.act_as(e1);
  perform t.expect_error(format('select public.add_visit(%L, %L, null, true, null, null, %L, %L)',
    v_stale, 'Shop', 'visit-' || v_stale, t3d),
    'not_on_duty');
  perform t.act_as_owner();
  delete from public.visits where id = v_late;
  delete from public.duty_days where id = v_old.id;
end;
$$;
delete from public.profiles where id = '00000000-0000-0000-0000-000000000014';
delete from auth.users where id = '00000000-0000-0000-0000-000000000014';

\echo '--- cleanup removes old raw points'
do $$
begin
  update public.track_points set recorded_at = recorded_at - interval '8 days';
  perform private.cleanup();
  perform t.eq((select count(*) from public.track_points), 0::bigint, 'old points removed');
  perform t.eq((select count(*) from public.day_routes) > 0, true, 'routes kept');
end;
$$;

\echo '--- one phone at a time'
do $$
begin
  perform t.act_as('00000000-0000-0000-0000-000000000002');
  perform public.claim_device('dev-e2-0001');  -- same phone: fine
  perform t.expect_error($q$select public.claim_device('second-phone')$q$, 'signed_in_elsewhere');
  perform t.expect_error($q$select public.claim_device('x')$q$, 'invalid_device');
  perform public.release_device('second-phone');  -- the wrong phone cannot release
  perform t.expect_error($q$select public.claim_device('second-phone')$q$, 'signed_in_elsewhere');
  perform public.release_device('dev-e2-0001');
  perform public.claim_device('second-phone');
  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform public.claim_device('admin-phone-1');
  perform public.claim_device('admin-phone-2');  -- admins are not limited
  perform t.expect_error($q$select public.svc_revoke_sessions('00000000-0000-0000-0000-000000000002')$q$, 'permission denied');
  perform t.act_as_owner();

  insert into auth.sessions (user_id) values ('00000000-0000-0000-0000-000000000002');
  perform set_config('role', 'service_role', false);
  perform public.svc_revoke_sessions('00000000-0000-0000-0000-000000000002');
  perform t.act_as_owner();
  perform t.eq((select count(*) from auth.sessions where user_id = '00000000-0000-0000-0000-000000000002'),
               0::bigint, 'sessions revoked');
  perform t.eq((select active_device_id from public.profiles where user_code = 'DA-002'),
               null::text, 'device released on revoke');
end;
$$;

\echo '--- the tracker uploads with a pass instead of a session'
do $$
declare
  e1 uuid := '00000000-0000-0000-0000-000000000001';
  e3 uuid := '00000000-0000-0000-0000-000000000003';
  v_today public.duty_days;
  v_day public.duty_days;
  v_t timestamptz;
  v_pass text;
  v_pts jsonb;
  r jsonb;
  v_before_11 boolean;
begin
  -- Resume: e1's duty from the visits test is still on today.
  select * into v_today from public.duty_days where user_id = e1 and day = private.ist_today();
  v_before_11 := now() < private.auto_off_at(v_today.day);
  perform t.act_as(e1);
  perform t.expect_error($q$select public.duty_resume('other-phone-1')$q$, 'signed_in_elsewhere');
  if v_before_11 then
    r := public.duty_resume('dev-e1-0001');
    perform t.eq((r->'day'->>'id')::bigint, v_today.id, 'resume returns today''s duty');
    perform t.eq(length(r->>'upload_pass'), 64, 'resume gives a new pass');
  else
    perform t.expect_error($q$select public.duty_resume('dev-e1-0001')$q$, 'not_on_duty');
  end if;
  perform t.act_as(e3);
  perform t.expect_error($q$select public.duty_resume('dev-e3-0001')$q$, 'not_on_duty');
  perform t.act_as_owner();

  -- A duty day for e3, five days ago, still on (the tracker is uploading).
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (e3, private.ist_today() - 5, 'on_duty', private.ist_at(private.ist_today() - 5, time '07:00'))
  returning * into v_day;
  v_t := v_day.duty_on_at;
  v_pass := private.new_upload_pass(v_day, 'dev-e3-0001');
  v_pts := jsonb_build_array(
    jsonb_build_object('t', v_t + interval '1 minute', 'la', 22500000, 'lo', 88300000, 'a', 8, 'b', 50),
    jsonb_build_object('t', v_t + interval '4 minutes', 'la', 22501000, 'lo', 88300000, 'a', 8, 'b', 49));

  -- A pass ends 2 days after the day's 11 PM, so this old one has expired.
  perform t.act_as(null);
  perform t.expect_error(format($q$select public.upload_points_with_pass(%s, %L, '[]')$q$, v_day.id, v_pass),
                         'invalid_upload_pass');
  perform t.act_as_owner();
  update private.upload_passes set expires_at = now() + interval '1 day' where duty_day_id = v_day.id;

  -- No session at all (the publishable key only).
  perform t.act_as(null);
  perform t.eq(public.upload_points_with_pass(v_day.id, v_pass, v_pts), 2, 'upload with a pass');
  perform t.eq(public.upload_points_with_pass(v_day.id, v_pass, v_pts), 0, 'retry adds nothing');
  perform t.expect_error(format($q$select public.upload_points_with_pass(%s, 'nope', '[]')$q$, v_day.id),
                         'invalid_upload_pass');
  perform t.expect_error(format($q$select public.upload_points_with_pass(%s, null, '[]')$q$, v_day.id),
                         'invalid_upload_pass');
  -- The pass belongs to one day only.
  perform t.expect_error(format($q$select public.upload_points_with_pass(%s, %L, '[]')$q$, v_today.id, v_pass),
                         'invalid_upload_pass');
  perform t.expect_error($q$select count(*) from public.duty_breaks$q$, 'permission denied');
  perform t.expect_error($q$select count(*) from private.upload_passes$q$, 'permission denied');

  -- Phone-off times, clipped to the duty; repeats and blips are ignored.
  perform t.eq(public.report_break_with_pass(v_day.id, v_pass, v_t + interval '10 minutes',
               v_t + interval '50 minutes', 'phone_off'), true, 'break stored');
  perform t.eq(public.report_break_with_pass(v_day.id, v_pass, v_t + interval '10 minutes',
               v_t + interval '50 minutes', 'phone_off'), false, 'repeat ignored');
  perform t.eq(public.report_break_with_pass(v_day.id, v_pass, v_t + interval '60 minutes',
               v_t + interval '60 minutes 30 seconds', 'tracking_stopped'), false, 'blip ignored');
  perform t.eq(public.report_break_with_pass(v_day.id, v_pass, v_t - interval '1 hour',
               v_t + interval '5 minutes', 'tracking_stopped'), true, 'break before duty on clipped');
  perform t.act_as_owner();
  perform t.eq((select min(started_at) from public.duty_breaks where duty_day_id = v_day.id),
               v_t, 'clipped to duty on');
  perform t.eq((select recorded_at from public.live_positions where user_id = e3),
               v_t + interval '4 minutes', 'live position from the pass upload');

  -- Only the owner and admins see breaks.
  perform t.act_as(e3);
  perform t.eq((select count(*) from public.duty_breaks), 2::bigint, 'own breaks visible');
  perform t.act_as(e1);
  perform t.eq((select count(*) from public.duty_breaks), 0::bigint, 'others'' breaks hidden');
  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform t.eq((select count(*) from public.duty_breaks), 2::bigint, 'admin sees breaks');

  -- Points that arrive after duty off still count, and the route is rebuilt.
  perform t.act_as(e3);
  perform public.duty_off(v_day.id, v_t + interval '30 minutes');
  perform t.act_as(null);
  perform t.eq(public.upload_points_with_pass(v_day.id, v_pass, jsonb_build_array(
    jsonb_build_object('t', v_t + interval '20 minutes', 'la', 22510000, 'lo', 88300000, 'a', 8, 'b', 45),
    jsonb_build_object('t', v_t + interval '40 minutes', 'la', 22520000, 'lo', 88300000, 'a', 8, 'b', 44))),
    1, 'late points inside the duty kept, after duty off dropped');
  perform t.act_as_owner();
  perform t.eq((select point_count from public.day_routes where duty_day_id = v_day.id), 3,
               'route rebuilt with late points');

  -- Duty off pressed offline arrives later through the tracker.
  perform t.act_as_owner();
  update public.duty_days set status = 'on_duty', duty_off_at = null, end_reason = null,
    worked_minutes = null where id = v_day.id;
  delete from public.requests where user_id = e3 and kind = 'short_duty';
  perform private.auto_duty_off();
  perform t.eq((select end_reason from public.duty_days where id = v_day.id),
               'auto'::public.duty_end_reason, '11 PM closed it first');
  perform t.act_as(null);
  perform t.eq(public.duty_off_with_pass(v_day.id, v_pass, v_t + interval '3 hours'),
               'pending'::public.day_status, 'late duty off corrects the day');
  perform t.eq(public.duty_off_with_pass(v_day.id, v_pass, v_t + interval '2 hours'),
               'pending'::public.day_status, 'a repeat changes nothing');
  perform t.act_as_owner();
  perform t.eq((select duty_off_at from public.duty_days where id = v_day.id),
               v_t + interval '3 hours', 'real duty off time kept');
  perform t.eq((select end_reason from public.duty_days where id = v_day.id),
               'manual'::public.duty_end_reason, 'ended by hand');
  perform t.eq((select count(*) from public.requests where user_id = e3 and kind = 'short_duty'),
               1::bigint, 'one review request');

  -- The pass stops working when it expires, the phone changes, or on reset.
  update private.upload_passes set expires_at = now() - interval '1 second' where duty_day_id = v_day.id;
  perform t.act_as(null);
  perform t.expect_error(format($q$select public.upload_points_with_pass(%s, %L, '[]')$q$, v_day.id, v_pass),
                         'invalid_upload_pass');
  perform t.act_as_owner();
  update private.upload_passes set expires_at = now() + interval '1 day' where duty_day_id = v_day.id;
  update public.profiles set active_device_id = 'new-phone-01' where id = e3;
  perform t.act_as(null);
  perform t.expect_error(format($q$select public.upload_points_with_pass(%s, %L, '[]')$q$, v_day.id, v_pass),
                         'invalid_upload_pass');
  perform t.act_as_owner();
  update public.profiles set active_device_id = 'dev-e3-0001' where id = e3;
  perform t.act_as(null);
  perform public.upload_points_with_pass(v_day.id, v_pass, '[]');
  perform t.act_as_owner();
  perform set_config('role', 'service_role', false);
  perform public.svc_revoke_sessions(e3);
  perform t.act_as_owner();
  -- A reset keeps the pass (L13): refused while no phone is signed in, and
  -- working again once the same phone signs in.
  perform t.eq((select count(*) from private.upload_passes where user_id = e3), 1::bigint, 'reset keeps the pass');
  perform t.act_as(null);
  perform t.expect_error(format($q$select public.upload_points_with_pass(%s, %L, '[]')$q$, v_day.id, v_pass),
                         'invalid_upload_pass');
  perform t.act_as_owner();
  update public.profiles set active_device_id = 'dev-e3-0001' where id = e3;
  perform t.act_as(null);
  perform public.upload_points_with_pass(v_day.id, v_pass, '[]');
  perform t.act_as_owner();
end;
$$;

\echo '--- maps: today''s route while on duty, stop addresses'
do $$
declare
  e2 uuid := '00000000-0000-0000-0000-000000000002';
  e1 uuid := '00000000-0000-0000-0000-000000000001';
  v_day public.duty_days;
  v_t timestamptz;
  v_pts jsonb := '[]';
  v_pass text;
  r record;
  n integer := 0;
  i integer;
begin
  update public.profiles set active_device_id = 'dev-e2-0001' where id = e2;
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (e2, private.ist_today() - 6, 'on_duty', private.ist_at(private.ist_today() - 6, time '07:00'))
  returning * into v_day;
  v_t := v_day.duty_on_at;
  -- 20 minutes at a dealer.
  for i in 0..20 loop
    v_pts := v_pts || jsonb_build_object('t', v_t + make_interval(mins => i),
      'la', 22700000 + (i % 2) * 30, 'lo', 88400000, 'a', 8, 'b', 70);
  end loop;
  v_pass := private.new_upload_pass(v_day, 'dev-e2-0001');
  -- (An old day's pass has expired; this one stands in for a duty still running.)
  update private.upload_passes set expires_at = now() + interval '1 day' where duty_day_id = v_day.id;
  perform t.act_as(null);
  perform public.upload_points_with_pass(v_day.id, v_pass, v_pts);
  perform t.act_as_owner();
  perform t.eq((select jsonb_array_length(stops) from public.day_routes where duty_day_id = v_day.id),
               1, 'route built while on duty');

  -- Only the owner or an admin may ask for addresses.
  perform set_config('role', 'service_role', false);
  perform t.expect_error(format('select * from public.svc_missing_places(%s, %L)', v_day.id, e1),
                         'not_allowed');
  for r in select * from public.svc_missing_places(v_day.id, e2) loop
    n := n + 1;
    perform t.eq(r.cell_lat, 22700, 'cell of the stop');
  end loop;
  perform t.eq(n, 1, 'one place to look up');
  perform public.svc_save_places(v_day.id,
    jsonb_build_array(jsonb_build_object('cell_lat', 22700, 'cell_lng', 88400,
                                         'address', 'Krishi Kendra Rd, Barasat')));
  perform t.eq((select count(*)::integer from public.svc_missing_places(v_day.id, '00000000-0000-0000-0000-00000000000a')),
               0, 'nothing left; admins may ask too');
  perform t.act_as_owner();
  perform t.eq((select stops->0->>'address' from public.day_routes where duty_day_id = v_day.id),
               'Krishi Kendra Rd, Barasat', 'address on the stop');

  -- A rebuild keeps the address (it comes from the saved places).
  perform private.build_route(v_day.id);
  perform t.eq((select stops->0->>'address' from public.day_routes where duty_day_id = v_day.id),
               'Krishi Kendra Rd, Barasat', 'address kept after rebuild');

  -- A build saves the route once, addresses included (L14).
  create table t.route_writes (n integer);
  create function t.count_route_write() returns trigger language plpgsql as $f$
  begin
    insert into t.route_writes values (1);
    return null;
  end;
  $f$;
  create trigger count_route_write after insert or update on public.day_routes
    for each row execute function t.count_route_write();
  perform private.build_route(v_day.id);
  perform t.eq((select count(*)::integer from t.route_writes), 1, 'one write per route build');
  perform t.eq((select stops->0->>'address' from public.day_routes where duty_day_id = v_day.id),
               'Krishi Kendra Rd, Barasat', 'address saved with the route');
  drop trigger count_route_write on public.day_routes;
  drop function t.count_route_write();
  drop table t.route_writes;

  -- A stop with no address is saved as "no address" and not asked again (L15).
  update public.day_routes
  set stops = stops || jsonb_build_array(jsonb_build_object('lat', 22.8, 'lng', 88.5))
  where duty_day_id = v_day.id;
  perform set_config('role', 'service_role', false);
  perform t.eq((select count(*)::integer from public.svc_missing_places(v_day.id, e2)),
               1, 'the field is looked up once');
  perform public.svc_save_places(v_day.id,
    jsonb_build_array(jsonb_build_object('cell_lat', 22800, 'cell_lng', 88500, 'address', '')));
  perform t.eq((select count(*)::integer from public.svc_missing_places(v_day.id, e2)),
               0, 'a place with no address is not looked up again');
  perform t.act_as_owner();
  perform t.eq((select stops->1 ? 'address' from public.day_routes where duty_day_id = v_day.id),
               false, 'no empty address on the stop');
  perform t.eq((select stops->0->>'address' from public.day_routes where duty_day_id = v_day.id),
               'Krishi Kendra Rd, Barasat', 'real addresses unchanged');

  -- Route builds of a day wait for each other, and today's refresh skips a
  -- route another batch just rebuilt (L17).
  update public.day_routes set built_at = now() - interval '1 minute', point_count = -1
  where duty_day_id = v_day.id;
  perform private.build_route_if_stale(v_day.id);
  perform t.eq((select point_count from public.day_routes where duty_day_id = v_day.id),
               -1, 'a fresh route is not rebuilt again');
  update public.day_routes set built_at = now() - interval '6 minutes'
  where duty_day_id = v_day.id;
  perform private.build_route_if_stale(v_day.id);
  perform t.eq((select point_count from public.day_routes where duty_day_id = v_day.id) > 0,
               true, 'an old route is rebuilt');

  perform t.act_as(e2);
  perform t.expect_error($q$select public.svc_save_places(1, '[]')$q$, 'permission denied');
  perform t.expect_error($q$select count(*) from private.place_names$q$, 'permission denied');
  perform t.act_as_owner();
end;
$$;

do $$
begin
  -- (Its own transaction, so no earlier build holds the lock already.)
  perform t.eq((select count(*)::integer from pg_locks
                where locktype = 'advisory' and pid = pg_backend_pid()), 0, 'no lock yet');
  perform private.build_route((select min(id) from public.duty_days));
  perform t.eq((select count(*)::integer from pg_locks
                where locktype = 'advisory' and pid = pg_backend_pid()), 1,
               'a route build holds the day''s lock (L17)');
end;
$$;

\echo '--- push tokens and sending'
create table t.pushed (url text, body jsonb);
create schema if not exists net;
create function net.http_post(url text, body jsonb, params jsonb default '{}',
  headers jsonb default '{}', timeout_milliseconds int default 5000) returns bigint
language sql as $$ insert into t.pushed values (url, body); select 1::bigint; $$;
grant usage on schema net to anon, authenticated, service_role;
grant all on t.pushed to anon, authenticated, service_role;
do $$
declare
  v_tok text := repeat('a', 30);
  v_id bigint;
  v_claim jsonb;
begin
  -- Without push_url nothing is sent.
  perform t.act_as_owner();
  perform private.notify('00000000-0000-0000-0000-000000000001', 'test', 'No url', null);
  perform t.eq((select count(*) from t.pushed), 0::bigint, 'no push without push_url');
  insert into private.app_settings values ('push_url', 'https://x.test/functions/v1/push');

  perform t.act_as('00000000-0000-0000-0000-000000000001');
  perform public.set_push_token('dev-e1-0001', v_tok);
  perform public.set_push_token('dev-e1-0001', repeat('b', 30));  -- refreshed token replaces it
  perform t.expect_error($q$select public.set_push_token('dev-e1-0001', 'short')$q$, 'invalid_token');
  perform t.expect_error($q$select * from private.push_tokens$q$, 'permission denied');
  perform t.expect_error($q$select public.svc_claim_push(1)$q$, 'permission denied');
  perform t.act_as(null);
  perform t.expect_error($q$select public.set_push_token('dev-e1-0001', repeat('c', 30))$q$, 'permission denied');

  perform t.act_as_owner();
  perform t.eq((select array_agg(token) from private.push_tokens
                where user_id = '00000000-0000-0000-0000-000000000001'),
               array[repeat('b', 30)], 'one token per phone');
  -- A token from a phone that no longer holds the account is not used.
  insert into private.push_tokens values (repeat('d', 30), '00000000-0000-0000-0000-000000000001', 'dev-old-0001', now());

  perform private.notify('00000000-0000-0000-0000-000000000001', 'test', 'Hello', 'Body',
                         '{"request_id": 5}');
  select id into v_id from public.notifications where title = 'Hello';
  perform t.eq((select body from t.pushed order by ctid desc limit 1), jsonb_build_object('id', v_id), 'insert asks for a push');
  set local role service_role;
  v_claim := public.svc_claim_push(v_id);
  perform t.eq(v_claim->>'title', 'Hello', 'claim has the text');
  perform t.eq(v_claim->'tokens', jsonb_build_array(repeat('b', 30)), 'only the account phone');
  perform t.eq((v_claim->'data'->>'request_id')::int, 5, 'data kept');
  perform t.eq(public.svc_claim_push(v_id), null::jsonb, 'claimed once');
  perform public.svc_drop_push_tokens(array[repeat('b', 30)]);
  perform t.act_as_owner();
  perform t.eq((select count(*) from private.push_tokens where token = repeat('b', 30)), 0::bigint, 'dropped');

  -- Logout clears the phone's token.
  perform t.act_as('00000000-0000-0000-0000-000000000001');
  perform public.set_push_token('dev-e1-0001', v_tok);
  perform public.clear_push_token(v_tok);
  perform t.act_as_owner();
  perform t.eq((select count(*) from private.push_tokens where token = v_tok), 0::bigint, 'logout clears');

  -- An admin's request photo check.
  select id into v_id from public.requests where kind = 'attendance' limit 1;
  set local role service_role;
  perform t.eq(public.svc_request_photo(v_id, '00000000-0000-0000-0000-00000000000a'),
               'req-11111111-2222-3333-4444-555555555555', 'admin sees the photo id');
  perform t.expect_error(format('select public.svc_request_photo(%s, %L)',
                 v_id, '00000000-0000-0000-0000-000000000002'), 'not_allowed');
  perform t.act_as_owner();
  delete from private.app_settings;
end;
$$;

\echo '--- visit photos: who sees them, deleted after 90 days'
do $$
declare
  v_id uuid := 'aaaaaaaa-0000-0000-0000-000000000002';
  v_req bigint;
begin
  set local role service_role;
  perform t.eq(public.svc_visit_photo(v_id, '00000000-0000-0000-0000-000000000001'),
               'visit-' || v_id, 'owner sees the visit photo');
  perform t.eq(public.svc_visit_photo(v_id, '00000000-0000-0000-0000-00000000000a'),
               'visit-' || v_id, 'admin sees the visit photo');
  perform t.expect_error(format('select public.svc_visit_photo(%L, %L)',
                 v_id, '00000000-0000-0000-0000-000000000002'), 'not_allowed');
  perform t.expect_error(format('select public.svc_visit_photo(%L, %L)',
                 gen_random_uuid(), '00000000-0000-0000-0000-00000000000a'), 'not_allowed');
  perform t.eq((select count(*) from public.svc_photos_to_purge()), 0::bigint, 'nothing young purged');

  perform t.act_as('00000000-0000-0000-0000-000000000001');
  perform t.expect_error($q$select * from public.svc_photos_to_purge()$q$, 'permission denied');
  perform t.expect_error($q$select public.svc_photos_removed(array['x'])$q$, 'permission denied');
  perform t.expect_error($q$select private.purge_photos()$q$, 'permission denied');

  -- 91 days later.
  perform t.act_as_owner();
  update public.visits set created_at = created_at - interval '91 days' where id = v_id;
  select id into v_req from public.requests where kind = 'attendance' limit 1;
  update public.requests set created_at = created_at - interval '91 days' where id = v_req;
  -- The request photo is the older one, so it goes first (L26).
  update public.requests set created_at = now() - interval '200 days' where id = v_req;
  delete from t.pushed;
  perform private.purge_photos();
  perform t.eq((select count(*) from t.pushed), 0::bigint, 'no purge call without photos_url');
  insert into private.app_settings values ('photos_url', 'https://x.test/functions/v1/photos');
  perform private.purge_photos();
  perform t.eq((select body from t.pushed), '{"action": "purge"}'::jsonb, 'asks the photos function');

  set local role service_role;
  perform t.eq((select array_agg(kind || ':' || photo_id order by kind) from public.svc_photos_to_purge()),
               array['request:req-11111111-2222-3333-4444-555555555555', 'visit:visit-' || v_id],
               'old photos listed');
  perform t.eq((select kind from public.svc_photos_to_purge(1)), 'request', 'oldest photo first');
  perform t.eq(public.svc_photos_removed(array['visit-' || v_id, 'req-11111111-2222-3333-4444-555555555555']),
               2, 'marked removed');
  perform t.eq((select count(*) from public.svc_photos_to_purge()), 0::bigint, 'purged once');
  perform t.eq(public.svc_visit_photo(v_id, '00000000-0000-0000-0000-000000000001'), null::text,
               'removed visit photo not shown');
  perform t.eq(public.svc_request_photo(v_req, '00000000-0000-0000-0000-00000000000a'), null::text,
               'removed request photo not shown');
  perform t.act_as_owner();
  perform t.eq((select count(*) from public.visits where id = v_id), 1::bigint, 'the visit stays');
  delete from t.pushed;
  perform private.purge_photos();
  perform t.eq((select count(*) from t.pushed), 0::bigint, 'no call when nothing is left');
  delete from private.app_settings;
end;
$$;

\echo '--- password reset codes'
do $$
declare
  u uuid := '00000000-0000-0000-0000-000000000003';
begin
  perform t.act_as('00000000-0000-0000-0000-000000000003');
  perform t.expect_error($q$select public.svc_store_reset_code('00000000-0000-0000-0000-000000000003', '123456')$q$, 'permission denied');
  perform t.expect_error($q$select count(*) from private.password_reset_codes$q$, 'permission denied');
  perform set_config('role', 'service_role', false);
  perform t.eq(public.svc_store_reset_code(u, '123456'), true, 'code stored');
  perform t.eq(public.svc_store_reset_code(u, '654321'), false, 'no second email within a minute');
  perform t.eq(public.svc_use_reset_code(u, '000000'), false, 'wrong code');
  perform t.eq(public.svc_use_reset_code(u, '123456'), true, 'right code');
  perform t.eq(public.svc_use_reset_code(u, '123456'), false, 'a code works once');
  perform t.act_as_owner();
  update private.password_reset_codes set created_at = now() - interval '2 minutes' where user_id = u;
  perform set_config('role', 'service_role', false);
  perform public.svc_store_reset_code(u, '111111');
  perform public.svc_use_reset_code(u, '1'); perform public.svc_use_reset_code(u, '2');
  perform public.svc_use_reset_code(u, '3'); perform public.svc_use_reset_code(u, '4');
  perform public.svc_use_reset_code(u, '5');
  perform t.eq(public.svc_use_reset_code(u, '111111'), false, 'locked after 5 wrong tries');
  perform t.act_as_owner();
end;
$$;

\echo '--- nightly cleanup keeps and removes the right rows'
-- One check per line of private.cleanup(), so a rewrite that drops a line
-- fails here (review finding H1: two lines were lost that way).
do $$
declare
  u      uuid := '00000000-0000-0000-0000-000000000003';
  u2     uuid := '00000000-0000-0000-0000-000000000002';
  today  date := private.ist_today();
  d_old  bigint;  -- 100 days ago: past the 90-day limit
  d_new  bigint;  -- 10 days ago: kept
begin
  perform t.act_as_owner();
  delete from public.duty_days where user_id = u and day in (today - 100, today - 10);
  insert into public.duty_days (user_id, day, status) values (u, today - 100, 'absent')
    returning id into d_old;
  insert into public.duty_days (user_id, day, status) values (u, today - 10, 'absent')
    returning id into d_new;

  -- routes and phone-off notes (90 days)
  insert into public.day_routes (duty_day_id, day) values (d_old, today - 100), (d_new, today - 10);
  insert into public.duty_breaks (duty_day_id, started_at, ended_at, kind) values
    (d_old, now() - interval '100 days', now() - interval '100 days' + interval '1 hour', 'phone_off'),
    (d_new, now() - interval '10 days', now() - interval '10 days' + interval '1 hour', 'tracking_stopped');
  -- upload passes: one expired, one still valid
  insert into private.upload_passes (duty_day_id, user_id, device_id, pass_hash, expires_at) values
    (d_old, u, 'dev-cleanup-1', '\x00', now() - interval '1 minute'),
    (d_new, u, 'dev-cleanup-1', '\x01', now() + interval '1 hour');
  -- notifications (60 days)
  delete from public.notifications where kind = 'cleanup_test';
  insert into public.notifications (user_id, kind, title, created_at) values
    (u, 'cleanup_test', 'old', now() - interval '61 days'),
    (u, 'cleanup_test', 'new', now() - interval '59 days');
  -- push tokens (60 days)
  insert into private.push_tokens (token, user_id, device_id, updated_at) values
    ('cleanup-test-token-old-0001', u, 'dev-cleanup-1', now() - interval '61 days'),
    ('cleanup-test-token-new-0001', u, 'dev-cleanup-1', now() - interval '59 days')
  on conflict (token) do update set updated_at = excluded.updated_at;
  -- duty-on permissions (30 days)
  delete from public.duty_permits where user_id = u and day in (today - 31, today - 29);
  insert into public.duty_permits (user_id, day) values (u, today - 31), (u, today - 29);
  -- reset codes: u's expired over a day ago, u2's expired only an hour ago
  insert into private.password_reset_codes (user_id, code_hash, expires_at) values
    (u, 'x', now() - interval '25 hours'), (u2, 'x', now() - interval '1 hour')
  on conflict (user_id) do update set expires_at = excluded.expires_at;
  -- live position of an ended duty, last updated 2 days ago
  insert into public.live_positions (user_id, duty_day_id, lat_e6, lng_e6, recorded_at, updated_at)
  values (u, d_new, 22000000, 88000000, now() - interval '2 days', now() - interval '2 days')
  on conflict (user_id) do update set duty_day_id = excluded.duty_day_id,
    updated_at = excluded.updated_at;

  perform private.cleanup();

  perform t.eq((select count(*) from public.day_routes where duty_day_id = d_old), 0::bigint, 'route older than 90 days removed');
  perform t.eq((select count(*) from public.day_routes where duty_day_id = d_new), 1::bigint, 'recent route kept');
  perform t.eq((select count(*) from public.duty_breaks where duty_day_id = d_old), 0::bigint, 'phone-off note older than 90 days removed');
  perform t.eq((select count(*) from public.duty_breaks where duty_day_id = d_new), 1::bigint, 'recent phone-off note kept');
  perform t.eq((select count(*) from private.upload_passes where duty_day_id = d_old), 0::bigint, 'expired upload pass removed');
  perform t.eq((select count(*) from private.upload_passes where duty_day_id = d_new), 1::bigint, 'valid upload pass kept');
  perform t.eq((select string_agg(title, ',') from public.notifications where kind = 'cleanup_test'), 'new', 'notification older than 60 days removed, newer kept');
  perform t.eq((select string_agg(token, ',') from private.push_tokens where token like 'cleanup-test-token-%'), 'cleanup-test-token-new-0001', 'push token older than 60 days removed, newer kept');
  perform t.eq((select string_agg((today - day)::text, ',') from public.duty_permits where user_id = u and day in (today - 31, today - 29)), '29', 'permission older than 30 days removed, newer kept');
  perform t.eq((select count(*) from private.password_reset_codes where user_id = u), 0::bigint, 'reset code expired over a day ago removed');
  perform t.eq((select count(*) from private.password_reset_codes where user_id = u2), 1::bigint, 'recently expired reset code kept');
  perform t.eq((select count(*) from public.live_positions where user_id = u), 0::bigint, 'live position of an ended duty removed');
  perform t.eq((select count(*) from public.duty_days where id in (d_old, d_new)), 2::bigint, 'attendance days are never removed');

  -- tidy up
  delete from public.notifications where kind = 'cleanup_test';
  delete from private.push_tokens where token like 'cleanup-test-token-%';
  delete from public.duty_permits where user_id = u and day in (today - 31, today - 29);
  delete from private.password_reset_codes where user_id in (u, u2);
  delete from public.duty_days where id in (d_old, d_new);
end;
$$;

\echo '--- leftovers are gone: public.places and the signed-in upload_points'
do $$
begin
  perform t.eq(to_regclass('public.places') is null, true, 'public.places is gone');
  perform t.eq(to_regprocedure('public.upload_points(bigint,jsonb,text)') is null, true,
               'signed-in upload_points is gone');
  perform t.eq(to_regclass('private.place_names') is not null, true, 'the real address cache stays');
  perform t.eq(to_regprocedure('public.upload_points_with_pass(bigint,text,jsonb)') is not null, true,
               'the tracker upload stays');
end;
$$;

\echo '--- an admin day decision settles the short-duty review (no overwrite later)'
do $$
declare
  e1 uuid := '00000000-0000-0000-0000-000000000001';
  adm uuid := '00000000-0000-0000-0000-00000000000a';
  d1 date := private.ist_today() - 20;
  d2 date := private.ist_today() - 21;
  v_id1 bigint; v_id2 bigint; v_req1 bigint; v_req2 bigint;
  v_off1 timestamptz := private.ist_at(d1, time '12:00');
  v_off2 timestamptz := private.ist_at(d2, time '12:00');
begin
  perform t.act_as_owner();
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (e1, d1, 'on_duty', private.ist_at(d1, time '07:00')) returning id into v_id1;
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (e1, d2, 'on_duty', private.ist_at(d2, time '07:00')) returning id into v_id2;
  perform t.act_as(e1);
  perform public.duty_off(v_id1, v_off1);
  perform public.duty_off(v_id2, v_off2);
  select id into v_req1 from public.requests where kind = 'short_duty' and day = d1 and user_id = e1;
  select id into v_req2 from public.requests where kind = 'short_duty' and day = d2 and user_id = e1;
  perform t.eq(v_req1 is not null and v_req2 is not null, true, 'both short days wait for the admin');

  -- The admin sets the first day to absent from the day screen.
  perform t.act_as(adm);
  perform public.set_day_status(e1, d1, 'absent', null, 'Not in the field');
  perform t.expect_error(format($q$select public.decide_request(%s, 'present')$q$, v_req1), 'request_already_decided');
  perform t.act_as_owner();
  perform t.eq((select status from public.requests where id = v_req1), 'rejected'::public.request_status, 'absent closes it as rejected');
  perform t.eq((select decision from public.requests where id = v_req1), 'absent'::public.day_status, 'decision kept');
  perform t.eq((select decided_by from public.requests where id = v_req1), adm, 'who decided is kept');
  perform t.eq((select status from public.duty_days where id = v_id1), 'absent'::public.day_status, 'the admin choice stands');
  perform t.eq((select (details->>'closed_request')::bigint from public.admin_log
                where action = 'set_day_status' and (details->>'day')::date = d1), v_req1, 'log names the closed request');

  -- Present closes the second one as approved.
  perform t.act_as(adm);
  perform public.set_day_status(e1, d2, 'present');
  perform t.act_as_owner();
  perform t.eq((select status from public.requests where id = v_req2), 'approved'::public.request_status, 'present closes it as approved');
  perform t.eq((select status from public.duty_days where id = v_id2), 'present'::public.day_status, 'present stands');

  -- A day with no open review still works, and nothing else is closed.
  perform t.act_as(adm);
  perform public.set_day_status(e1, d2, 'half_day');
  perform t.act_as_owner();
  perform t.eq((select status from public.duty_days where id = v_id2), 'half_day'::public.day_status, 'a later change still works');
  perform t.eq((select details->>'closed_request' from public.admin_log
                where action = 'set_day_status' and (details->>'day')::date = d2 order by id desc limit 1), null,
               'nothing to close the second time');

  delete from public.requests where id in (v_req1, v_req2);
  delete from public.duty_days where id in (v_id1, v_id2);
end;
$$;

\echo '--- fake GPS is flagged and not counted; indoor fixes keep the phone alive; a bad first fix adds no km'
select t.act_as_owner();
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000009', 'e9@test');
insert into public.profiles (id, user_code, full_name, role, created_at, active_device_id)
values ('00000000-0000-0000-0000-000000000009', 'DA-009', 'Employee Nine', 'employee',
        now() - interval '30 days', 'dev-e9-0001');
do $$
declare
  e9 uuid := '00000000-0000-0000-0000-000000000009';
  v_day public.duty_days;
  v_drive public.duty_days;
  v_today public.duty_days;
  v_t timestamptz;
  v_pts jsonb := '[]';
  v_pass text;
  v public.visits;
  i integer;
begin
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (e9, private.ist_today() - 20, 'on_duty', private.ist_at(private.ist_today() - 20, time '07:00'))
  returning * into v_day;
  v_t := v_day.duty_on_at;
  -- The first fix is 2 km off; the phone then settles at the godown.
  v_pts := v_pts || jsonb_build_object('t', v_t, 'la', 22518000, 'lo', 88300000, 'a', 10);
  for i in 1..10 loop
    v_pts := v_pts || jsonb_build_object('t', v_t + make_interval(mins => i),
      'la', 22500000 + (i % 2) * 20, 'lo', 88300000, 'a', 8);
  end loop;
  -- 30 minutes inside a dealer: only weak fixes (100 m).
  for i in 0..10 loop
    v_pts := v_pts || jsonb_build_object('t', v_t + make_interval(mins => 11 + i * 3),
      'la', 22500000, 'lo', 88300000, 'a', 100);
  end loop;
  -- 10 minutes driving east, 100 m a minute (1 km).
  for i in 0..10 loop
    v_pts := v_pts || jsonb_build_object('t', v_t + make_interval(mins => 44 + i),
      'la', 22500000, 'lo', 88300000 + i * 973, 'a', 8);
  end loop;
  -- A fake-location app "drives" on at a believable speed (another 500 m).
  for i in 1..5 loop
    v_pts := v_pts || jsonb_build_object('t', v_t + make_interval(mins => 54 + i),
      'la', 22500000, 'lo', 88300000 + (10 + i) * 973, 'a', 5, 'm', true);
  end loop;
  v_pass := private.new_upload_pass(v_day, 'dev-e9-0001');
  update private.upload_passes set expires_at = now() + interval '1 day' where duty_day_id = v_day.id;
  perform t.act_as(null);
  perform t.eq(public.upload_points_with_pass(v_day.id, v_pass, v_pts), 38, 'all points stored');
  perform t.act_as_owner();
  perform private.build_route(v_day.id);

  perform t.eq((select count(*) from public.track_points where duty_day_id = v_day.id and mocked),
               5::bigint, 'fake points are marked');
  perform t.eq((select mocked_points from public.day_routes where duty_day_id = v_day.id), 5,
               'the route counts the fake points');
  perform t.eq((select mocked from public.live_positions where user_id = e9), true,
               'the live position says fake');
  perform t.eq((select jsonb_array_length(gaps) from public.day_routes where duty_day_id = v_day.id), 0,
               'weak indoor fixes leave no gap');
  if (select distance_m from public.day_routes where duty_day_id = v_day.id) not between 900 and 1100 then
    raise exception 'distance should be about 1 km (no bad first fix, no fake km), got %',
      (select distance_m from public.day_routes where duty_day_id = v_day.id);
  end if;

  -- Real driving from the first point is counted in full.
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (e9, private.ist_today() - 21, 'on_duty', private.ist_at(private.ist_today() - 21, time '07:00'))
  returning * into v_drive;
  v_pts := '[]';
  for i in 0..10 loop
    v_pts := v_pts || jsonb_build_object('t', v_drive.duty_on_at + make_interval(secs => i * 30),
      'la', 22500000, 'lo', 88300000 + i * 4865, 'a', 8);
  end loop;
  v_pass := private.new_upload_pass(v_drive, 'dev-e9-0001');
  update private.upload_passes set expires_at = now() + interval '1 day' where duty_day_id = v_drive.id;
  perform t.act_as(null);
  perform public.upload_points_with_pass(v_drive.id, v_pass, v_pts);
  perform t.act_as_owner();
  perform private.build_route(v_drive.id);
  if (select distance_m from public.day_routes where duty_day_id = v_drive.id) not between 4900 and 5100 then
    raise exception 'driving from the start should count about 5 km, got %',
      (select distance_m from public.day_routes where duty_day_id = v_drive.id);
  end if;
  perform t.eq((select mocked_points from public.day_routes where duty_day_id = v_drive.id), 0,
               'no fake points, no warning');

  -- Visits carry the mark of a camera location; a gallery photo has none.
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (e9, private.ist_today(), 'on_duty', now() - interval '1 hour')
  returning * into v_today;
  perform t.act_as(e9);
  v := public.add_visit('bbbbbbbb-0000-0000-0000-000000000001', 'Agro Store', null, false,
                        22500000, 88300000, 'visit-bbbbbbbb-0000-0000-0000-000000000001', now(), true);
  perform t.eq(v.mocked, true, 'a fake camera location is marked');
  v := public.add_visit('bbbbbbbb-0000-0000-0000-000000000002', 'Agro Store', null, true,
                        null, null, 'visit-bbbbbbbb-0000-0000-0000-000000000002', now(), true);
  perform t.eq(v.mocked, false, 'a gallery photo has no location to fake');
  -- The current app sends no mark.
  v := public.add_visit('bbbbbbbb-0000-0000-0000-000000000003', 'Agro Store', null, false,
                        22500000, 88300000, 'visit-bbbbbbbb-0000-0000-0000-000000000003', now());
  perform t.eq(v.mocked, false, 'no mark means not fake');
  perform t.act_as_owner();

  delete from public.duty_days where user_id = e9;
  delete from public.live_positions where user_id = e9;
end;
$$;
delete from public.profiles where id = '00000000-0000-0000-0000-000000000009';
delete from auth.users where id = '00000000-0000-0000-0000-000000000009';

\echo '--- km driven while the phone is off are not counted (decided: L2)'
do $$
declare
  e1 uuid := '00000000-0000-0000-0000-000000000001';
  v_day public.duty_days;
  v_t timestamptz;
  v_pts jsonb := '[]';
  v_pass text;
  i integer;
begin
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (e1, private.ist_today() - 22, 'on_duty', private.ist_at(private.ist_today() - 22, time '07:00'))
  returning * into v_day;
  v_t := v_day.duty_on_at;
  -- 10 minutes driving north (1 km), phone off for an hour, then the phone
  -- comes back 10 km further north and drives another 1 km.
  for i in 0..10 loop
    v_pts := v_pts || jsonb_build_object('t', v_t + make_interval(mins => i),
      'la', 22500000 + i * 899, 'lo', 88300000, 'a', 8);
  end loop;
  for i in 0..10 loop
    v_pts := v_pts || jsonb_build_object('t', v_t + make_interval(mins => 70 + i),
      'la', 22599000 + i * 899, 'lo', 88300000, 'a', 8);
  end loop;
  v_pass := private.new_upload_pass(v_day, 'dev-e1-0001');
  update private.upload_passes set expires_at = now() + interval '1 day' where duty_day_id = v_day.id;
  perform t.act_as(null);
  perform public.upload_points_with_pass(v_day.id, v_pass, v_pts);
  perform t.act_as_owner();
  perform private.build_route(v_day.id);
  perform t.eq((select jsonb_array_length(gaps) from public.day_routes where duty_day_id = v_day.id), 1,
               'the phone-off hour is a gap');
  if (select distance_m from public.day_routes where duty_day_id = v_day.id) not between 1900 and 2100 then
    raise exception 'only the 2 km the phone saw count, not the 10 km while it was off; got %',
      (select distance_m from public.day_routes where duty_day_id = v_day.id);
  end if;
  delete from public.duty_days where id = v_day.id;
end;
$$;

\echo '--- approving attendance never overwrites a real duty; a leave day counts no time; long notes say so'
select t.act_as_owner();
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000008', 'e8@test');
insert into public.profiles (id, user_code, full_name, role, created_at, active_device_id)
values ('00000000-0000-0000-0000-000000000008', 'DA-008', 'Employee Eight', 'employee',
        now() - interval '30 days', 'dev-e8-0001');
do $$
declare
  e8 uuid := '00000000-0000-0000-0000-000000000008';
  adm uuid := '00000000-0000-0000-0000-00000000000a';
  d1 date := private.ist_today() - 3;
  d2 date := private.ist_today() - 4;
  v_req1 bigint;
  v_req2 bigint;
  v_on timestamptz := private.ist_at(private.ist_today() - 3, time '07:00');
  v_off timestamptz := private.ist_at(private.ist_today() - 3, time '18:00');
begin
  -- Two attendance requests, sent before any duty existed on those days.
  perform t.act_as(e8);
  select id into v_req1 from public.request_attendance(d1, time '09:00', time '19:30', 'Forgot',
    'req-11111111-2222-3333-4444-555555555555');
  select id into v_req2 from public.request_attendance(d2, time '09:00', time '19:30', 'Forgot',
    'req-11111111-2222-3333-4444-555555555555');
  perform t.act_as_owner();
  -- Then a real duty was recorded on the first day (11 hours).
  insert into public.duty_days (user_id, day, status, duty_on_at, duty_off_at, worked_minutes)
  values (e8, d1, 'present', v_on, v_off, 660);

  perform t.act_as(adm);
  perform t.expect_error(format($q$select public.decide_request(%s, 'present')$q$, v_req1), 'day_has_duty');
  perform t.expect_error(format($q$select public.decide_request(%s, 'half_day', %L)$q$, v_req2, repeat('x', 301)),
                         'note_too_long');
  -- Rejecting closes the request and leaves the real duty alone.
  perform public.decide_request(v_req1, 'absent', 'You worked that day');
  perform t.act_as_owner();
  perform t.eq((select status from public.requests where id = v_req1), 'rejected'::public.request_status,
               'the request is rejected');
  perform t.eq((select status from public.duty_days where user_id = e8 and day = d1), 'present'::public.day_status,
               'the real duty keeps its status');
  perform t.eq((select duty_on_at from public.duty_days where user_id = e8 and day = d1), v_on,
               'the real duty keeps its times');

  -- A day without a duty is still approved as before.
  perform t.act_as(adm);
  perform public.decide_request(v_req2, 'present');
  perform t.act_as_owner();
  perform t.eq((select status from public.duty_days where user_id = e8 and day = d2), 'present'::public.day_status,
               'a day with no duty is approved');

  -- Leave counts no worked time, and going back brings it back.
  perform t.act_as(adm);
  perform public.set_day_status(e8, d1, 'leave', 'casual');
  perform t.act_as_owner();
  perform t.eq((select worked_minutes from public.duty_days where user_id = e8 and day = d1), null::integer,
               'a leave day counts no worked time');
  perform t.eq((select duty_on_at from public.duty_days where user_id = e8 and day = d1), v_on,
               'the duty times stay saved');
  perform t.act_as(adm);
  perform public.set_day_status(e8, d1, 'present');
  perform t.expect_error(format($q$select public.set_day_status(%L, %L, 'absent', null, %L)$q$, e8, d1, repeat('x', 301)),
                         'note_too_long');
  perform t.act_as_owner();
  perform t.eq((select worked_minutes from public.duty_days where user_id = e8 and day = d1), 660,
               'back to present brings the minutes back');

  delete from public.notifications where user_id = e8;
  delete from public.requests where user_id = e8;
  delete from public.duty_days where user_id = e8;
end;
$$;
delete from public.profiles where id = '00000000-0000-0000-0000-000000000008';
delete from auth.users where id = '00000000-0000-0000-0000-000000000008';

\echo '--- two duty on presses at the same moment: the second says already on (L6)'
select t.act_as_owner();
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000009', 'e9@test');
insert into public.profiles (id, user_code, full_name, role, created_at, active_device_id)
values ('00000000-0000-0000-0000-000000000009', 'DA-009', 'Employee Nine', 'employee',
        now() - interval '30 days', 'dev-e9-0001');
-- Test-only stand-ins for the other press: each one starts the same duty
-- exactly in the gap between this press's check and its insert.
create function t.other_press_insert() returns trigger
language plpgsql as $$
begin
  if pg_trigger_depth() = 1 then
    insert into public.duty_days (user_id, day, status, duty_on_at)
    values (new.user_id, new.day, 'on_duty', now());
  end if;
  return new;
end;
$$;
create function t.other_press_permit() returns trigger
language plpgsql as $$
begin
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (new.user_id, new.day, 'on_duty', now());
  return null;  -- the other press used the permission, so ours finds none
end;
$$;
do $$
declare
  v_time time := (now() at time zone 'Asia/Kolkata')::time;
  v_closed boolean := v_time < time '05:00' or v_time >= time '08:31';
  e9 constant uuid := '00000000-0000-0000-0000-000000000009';
begin
  if v_time >= time '21:00' then
    return;  -- no permission can be given this late (L28)
  end if;

  -- The other press inserts the duty just before ours.
  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform public.allow_duty_on(e9);
  perform t.act_as_owner();
  create trigger other_press before insert on public.duty_days
    for each row execute function t.other_press_insert();
  perform t.act_as(e9);
  perform t.expect_error($q$select public.duty_on('dev-e9-0001')$q$, 'already_on_duty_today');
  perform t.act_as_owner();
  drop trigger other_press on public.duty_days;
  -- (The refused call is rolled back, the other press's row with it.)
  delete from public.duty_days where user_id = e9;
  delete from public.duty_permits where user_id = e9;

  -- Outside the window: the other press used the permission and started duty.
  if v_closed then
    perform t.act_as('00000000-0000-0000-0000-00000000000a');
    perform public.allow_duty_on(e9);
    perform t.act_as_owner();
    create trigger other_press before update on public.duty_permits
      for each row execute function t.other_press_permit();
    perform t.act_as(e9);
    perform t.expect_error($q$select public.duty_on('dev-e9-0001')$q$, 'already_on_duty_today');
    perform t.act_as_owner();
    drop trigger other_press on public.duty_permits;
  end if;
end;
$$;
select t.act_as_owner();
drop function t.other_press_insert();
drop function t.other_press_permit();
delete from public.profiles where id = '00000000-0000-0000-0000-000000000009';
delete from auth.users where id = '00000000-0000-0000-0000-000000000009';

\echo '--- one signed-in phone: every action checks it; the admin can release a lost phone (M5, M6)'
select t.act_as_owner();
-- Signed in as p_uid with sign-in (session) p_session, as a real token carries it.
create function t.act_as_session(p_uid uuid, p_session uuid) returns void language plpgsql as $$
begin
  perform t.act_as(p_uid);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'session_id', p_session)::text, false);
end;
$$;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000010', 'e10@test');
insert into public.profiles (id, user_code, full_name, role, created_at)
values ('00000000-0000-0000-0000-000000000010', 'DA-010', 'Employee Ten', 'employee',
        now() - interval '30 days');
do $$
declare
  e10 constant uuid := '00000000-0000-0000-0000-000000000010';
  sa constant uuid := 'aaaaaaaa-0000-0000-0000-000000000001';  -- phone A's sign-in
  sb constant uuid := 'bbbbbbbb-0000-0000-0000-000000000002';  -- phone B's sign-in
  sc constant uuid := 'cccccccc-0000-0000-0000-000000000003';  -- phone C's sign-in
  v_leave text := $q$select public.request_leave('casual', array[(now() at time zone 'Asia/Kolkata')::date + %s], 'trip')$q$;
begin
  -- Phone A signs in and holds the account.
  perform t.act_as_session(e10, sa);
  perform public.claim_device('phone-a-0001');
  perform public.request_leave('casual', array[(now() at time zone 'Asia/Kolkata')::date + 1], 'trip');

  -- Phone B is refused at sign-in, and for every action (before: only duty
  -- on and route uploads checked the phone).
  perform t.act_as_session(e10, sb);
  perform t.expect_error($q$select public.claim_device('phone-b-0001')$q$, 'signed_in_elsewhere');
  perform t.expect_error(format(v_leave, 2), 'signed_in_elsewhere');
  perform t.expect_error($q$select public.request_attendance((now() at time zone 'Asia/Kolkata')::date - 1, '09:00', '18:00', 'forgot', null)$q$,
                         'signed_in_elsewhere');
  perform t.expect_error($q$select public.duty_off(1, now())$q$, 'signed_in_elsewhere');
  perform t.expect_error(
    $q$select public.add_visit(gen_random_uuid(), 'Shop', null, true, null, null, 'x', now())$q$,
    'signed_in_elsewhere');
  perform t.expect_error(format('select public.cancel_request(%s)',
    (select id from public.requests where user_id = e10 limit 1)), 'signed_in_elsewhere');

  -- A logs out: A's sign-in stops working, and B can sign in and do the work.
  perform t.act_as_session(e10, sa);
  perform public.release_device('phone-a-0001');
  perform t.expect_error(format(v_leave, 3), 'signed_in_elsewhere');
  perform t.act_as_session(e10, sb);
  perform public.claim_device('phone-b-0001');
  perform public.request_leave('casual', array[(now() at time zone 'Asia/Kolkata')::date + 4], 'trip');
  perform t.act_as_session(e10, sa);
  perform t.expect_error(format(v_leave, 5), 'signed_in_elsewhere');
  perform t.expect_error($q$select public.claim_device('phone-a-0001')$q$, 'signed_in_elsewhere');

  -- Phone B is lost. Only an admin can release it.
  perform t.act_as_owner();
  insert into auth.sessions (user_id) values (e10);
  insert into private.push_tokens (token, user_id, device_id)
  values (repeat('t', 30), e10, 'phone-b-0001');
  perform t.act_as_session(e10, sb);
  perform t.expect_error(format('select public.release_phone(%L)', e10), 'not_admin');
  perform t.act_as(null);
  perform t.expect_error(format('select public.release_phone(%L)', e10), 'permission denied');
  perform t.act_as('00000000-0000-0000-0000-00000000000a');
  perform t.expect_error(format('select public.release_phone(%L)', gen_random_uuid()), 'user_not_found');
  perform t.expect_error(format('select public.release_phone(%L)', '00000000-0000-0000-0000-00000000000a'),
                         'user_not_found');
  perform t.eq(public.release_phone(e10), true, 'phone released');
  perform t.eq(public.release_phone(e10), false, 'nothing left to release');
  perform t.act_as_owner();
  perform t.eq((select active_device_id from public.profiles where id = e10), null::text, 'account free');
  perform t.eq((select active_session_id from public.profiles where id = e10), null::uuid, 'sign-in forgotten');
  perform t.eq((select count(*) from auth.sessions where user_id = e10), 0::bigint, 'lost phone signed out');
  perform t.eq((select count(*) from private.push_tokens where user_id = e10), 0::bigint, 'no pushes to the lost phone');
  perform t.eq((select count(*) from public.admin_log where action = 'release_phone' and target_user = e10),
               2::bigint, 'release is logged');
  perform t.act_as_session(e10, sb);
  perform t.expect_error(format(v_leave, 6), 'signed_in_elsewhere');
  perform t.act_as_session(e10, sc);
  perform public.claim_device('phone-c-0001');
  perform public.request_leave('casual', array[(now() at time zone 'Asia/Kolkata')::date + 7], 'trip');

  -- A phone signed in before this change (no sign-in remembered) keeps
  -- working, and is remembered at its next duty on or resume.
  perform t.act_as_owner();
  update public.profiles set active_session_id = null where id = e10;
  perform t.act_as_session(e10, sb);
  perform public.request_leave('casual', array[(now() at time zone 'Asia/Kolkata')::date + 8], 'trip');
  perform t.act_as_owner();
  perform t.act_as_session(e10, sc);
  perform t.expect_error($q$select public.duty_resume('phone-c-0001')$q$, 'not_on_duty');
  perform t.act_as_owner();
  perform set_config('request.jwt.claims', json_build_object('session_id', sc)::text, false);
  perform private.require_device(e10, 'phone-c-0001');
  perform set_config('request.jwt.claims', '', false);
  perform t.eq((select active_session_id from public.profiles where id = e10), sc, 'remembered');
  perform t.act_as_session(e10, sb);
  perform t.expect_error(format(v_leave, 9), 'signed_in_elsewhere');
end;
$$;
select t.act_as_owner();
select set_config('request.jwt.claims', '', false);
delete from public.profiles where id = '00000000-0000-0000-0000-000000000010';
delete from auth.users where id = '00000000-0000-0000-0000-000000000010';

\echo '--- reset emails: 5 per user a day, 90 a day in total (M7); a reset stops the old phone at once (L7)'
do $$
declare
  e1 constant uuid := '00000000-0000-0000-0000-000000000001';
  e2 constant uuid := '00000000-0000-0000-0000-000000000002';
  e3 constant uuid := '00000000-0000-0000-0000-000000000003';
  v_today date := (now() at time zone 'Asia/Kolkata')::date;
begin
  delete from private.reset_email_counts;
  delete from private.password_reset_codes;
  insert into private.reset_email_counts (day, user_id, sent) values (v_today - 3, e1, 4);
  for i in 1..5 loop
    update private.password_reset_codes set created_at = now() - interval '2 minutes';
    perform set_config('role', 'service_role', false);
    perform t.eq(public.svc_store_reset_code(e2, '12345' || i), true, 'code ' || i || ' of today sent');
    perform t.act_as_owner();
  end loop;
  update private.password_reset_codes set created_at = now() - interval '2 minutes';
  perform set_config('role', 'service_role', false);
  perform t.eq(public.svc_store_reset_code(e2, '999999'), false, 'no 6th email today');
  perform t.eq(public.svc_use_reset_code(e2, '999999'), false, 'the 6th code was not stored');
  perform t.act_as_owner();
  perform t.eq((select count(*) from private.reset_email_counts where day < v_today - 1), 0::bigint,
               'old counts cleaned up');

  -- Today's total reaches 90: the next email anyone asks for is refused.
  insert into private.reset_email_counts (day, user_id, sent) values (v_today, e1, 85);
  perform set_config('role', 'service_role', false);
  perform t.expect_error(format('select public.svc_store_reset_code(%L, %L)', e3, '424242'), 'daily_email_limit');
  perform t.act_as_owner();
  perform t.eq((select count(*) from private.password_reset_codes where user_id = e3), 0::bigint,
               'no code stored over the daily total');
  -- Yesterday's emails do not count today.
  update private.reset_email_counts set day = v_today - 1;
  perform set_config('role', 'service_role', false);
  perform t.eq(public.svc_store_reset_code(e3, '424242'), true, 'a new day starts again');
  perform t.act_as_owner();
  delete from private.reset_email_counts;
  delete from private.password_reset_codes;
end;
$$;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000011', 'e11@test');
insert into public.profiles (id, user_code, full_name, role, created_at)
values ('00000000-0000-0000-0000-000000000011', 'DA-011', 'Employee Eleven', 'employee',
        now() - interval '30 days');
do $$
declare
  e11 constant uuid := '00000000-0000-0000-0000-000000000011';
  s1 constant uuid := 'dddddddd-0000-0000-0000-000000000001';
begin
  perform t.act_as_session(e11, s1);
  perform public.claim_device('phone-11-0001');
  perform public.request_leave('casual', array[(now() at time zone 'Asia/Kolkata')::date + 1], 'trip');
  perform t.act_as_owner();
  perform set_config('role', 'service_role', false);
  perform public.svc_revoke_sessions(e11);  -- what a password reset does
  perform t.act_as_session(e11, s1);
  perform t.expect_error(
    $q$select public.request_leave('casual', array[(now() at time zone 'Asia/Kolkata')::date + 2], 'trip')$q$,
    'signed_in_elsewhere');
end;
$$;
select t.act_as_owner();
select set_config('request.jwt.claims', '', false);
delete from public.profiles where id = '00000000-0000-0000-0000-000000000011';
delete from auth.users where id = '00000000-0000-0000-0000-000000000011';

\echo '--- offline duty off on a short day corrects it (M9); one bad point does not fail the upload (L10)'
select t.act_as_owner();
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000012', 'e12@test');
insert into public.profiles (id, user_code, full_name, role, created_at, active_device_id)
values ('00000000-0000-0000-0000-000000000012', 'DA-012', 'Employee Twelve', 'employee',
        now() - interval '30 days', 'dev-12-0001');
do $$
declare
  e12 constant uuid := '00000000-0000-0000-0000-000000000012';
  v_day public.duty_days;
  v_pass text;
  v_on timestamptz;
  v_off timestamptz;
  v_req bigint;
begin
  -- Yesterday: a late start at 5 PM (the admin allowed it), so 11 PM makes
  -- it a 6-hour "pending" day with a short-duty review.
  v_off := private.auto_off_at(private.ist_today() - 1);
  v_on := v_off - interval '6 hours';
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (e12, private.ist_today() - 1, 'on_duty', v_on) returning * into v_day;
  v_pass := private.new_upload_pass(v_day, 'dev-12-0001');
  perform private.close_duty(v_day.id, v_off, 'auto');
  select id into v_req from public.requests where user_id = e12 and kind = 'short_duty';
  perform t.eq((select count(*) from public.notifications
                where kind = 'short_duty' and data->>'request_id' = v_req::text) > 0, true,
               'admins told about the 11 PM hours');

  -- The duty off pressed offline at 9 PM arrives the next day.
  perform t.act_as(null);
  perform t.eq(public.duty_off_with_pass(v_day.id, v_pass, v_on + interval '4 hours'),
               'pending'::public.day_status, 'still short');
  perform t.act_as_owner();
  perform t.eq((select duty_off_at from public.duty_days where id = v_day.id),
               v_on + interval '4 hours', 'the real duty off time is used');
  perform t.eq((select worked_minutes from public.duty_days where id = v_day.id), 240, 'real hours');
  perform t.eq((select end_reason from public.duty_days where id = v_day.id),
               'manual'::public.duty_end_reason, 'ended by hand');
  perform t.eq((select count(*) from public.requests where user_id = e12 and kind = 'short_duty'),
               1::bigint, 'one review, not two');
  perform t.eq((select count(*) from public.requests where id = v_req), 0::bigint, 'old review replaced');
  perform t.eq((select count(*) from public.notifications
                where kind = 'short_duty' and data->>'request_id' = v_req::text), 0::bigint,
               'old notice removed');
  perform t.eq((select body like '%4 h 0 min' from public.notifications
                where kind = 'short_duty' and data->>'user_id' = e12::text limit 1), true,
               'new notice has the real hours');

  -- A day the admin already decided is never changed.
  update public.duty_days set status = 'pending', duty_off_at = v_off, end_reason = 'auto',
    worked_minutes = 360, status_source = 'admin' where id = v_day.id;
  perform t.act_as(null);
  perform t.eq(public.duty_off_with_pass(v_day.id, v_pass, v_on + interval '1 hour'),
               'pending'::public.day_status, 'decided day answers its status');
  perform t.act_as_owner();
  perform t.eq((select duty_off_at from public.duty_days where id = v_day.id), v_off, 'decided day kept');

  -- L10: bad values skip only their own point.
  update public.duty_days set status = 'on_duty', duty_off_at = null, end_reason = null,
    worked_minutes = null, status_source = 'auto' where id = v_day.id;
  perform t.act_as(null);
  perform t.eq(public.upload_points_with_pass(v_day.id, v_pass, jsonb_build_array(
    jsonb_build_object('t', v_on + interval '1 minute', 'la', 22510000, 'lo', 88300000, 'a', 8, 'b', 45),
    jsonb_build_object('t', 'not a time', 'la', 22510000, 'lo', 88300000),
    jsonb_build_object('t', v_on + interval '2 minutes', 'la', 99999999999, 'lo', 88300000),
    jsonb_build_object('t', v_on + interval '3 minutes', 'la', 22510000, 'lo', 88300000, 'b', 99999),
    jsonb_build_object('t', v_on + interval '4 minutes', 'la', 22510000, 'lo', 88300000, 'a', -99999),
    jsonb_build_object('t', v_on + interval '5 minutes', 'la', 'x', 'lo', 88300000),
    '"just text"'::jsonb,
    jsonb_build_object('t', v_on + interval '6 minutes', 'la', 22520000, 'lo', 88300000, 'a', 9, 'b', 44))),
    2, 'the two good points kept, the bad ones skipped');
  perform t.act_as_owner();
end;
$$;
select t.act_as_owner();
delete from public.profiles where id = '00000000-0000-0000-0000-000000000012';
delete from auth.users where id = '00000000-0000-0000-0000-000000000012';

\echo '--- one break note per time span: phone off wins over tracking stopped (L11)'
select t.act_as_owner();
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000013', 'e13@test');
insert into public.profiles (id, user_code, full_name, role, created_at, active_device_id)
values ('00000000-0000-0000-0000-000000000013', 'DA-013', 'Employee Thirteen', 'employee',
        now() - interval '30 days', 'dev-13-0001');
do $$
declare
  e13 constant uuid := '00000000-0000-0000-0000-000000000013';
  v_day public.duty_days;
  v_pass text;
  v_on timestamptz := private.auto_off_at(private.ist_today() - 1) - interval '12 hours';
begin
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (e13, private.ist_today() - 1, 'on_duty', v_on) returning * into v_day;
  v_pass := private.new_upload_pass(v_day, 'dev-13-0001');
  perform t.act_as(null);
  -- 2:00-2:40 tracking stopped, then the phone says it was off 2:10-2:30.
  perform t.eq(public.report_break_with_pass(v_day.id, v_pass, v_on + interval '2 hours',
               v_on + interval '2 hours 40 minutes', 'tracking_stopped'), true, 'first break');
  perform t.eq(public.report_break_with_pass(v_day.id, v_pass, v_on + interval '2 hours 10 minutes',
               v_on + interval '2 hours 30 minutes', 'phone_off'), true, 'phone off replaces it');
  -- A tracking-stopped break over the phone-off time is not added.
  perform t.eq(public.report_break_with_pass(v_day.id, v_pass, v_on + interval '2 hours 20 minutes',
               v_on + interval '3 hours', 'tracking_stopped'), false, 'overlap ignored');
  -- Nor a second phone-off over it.
  perform t.eq(public.report_break_with_pass(v_day.id, v_pass, v_on + interval '2 hours 5 minutes',
               v_on + interval '2 hours 15 minutes', 'phone_off'), false, 'second phone off ignored');
  -- A break at another time is kept.
  perform t.eq(public.report_break_with_pass(v_day.id, v_pass, v_on + interval '5 hours',
               v_on + interval '5 hours 30 minutes', 'tracking_stopped'), true, 'separate break kept');
  perform t.act_as_owner();
  perform t.eq((select count(*) from public.duty_breaks where duty_day_id = v_day.id), 2::bigint, 'two notes');
  perform t.eq((select kind from public.duty_breaks where duty_day_id = v_day.id
                and started_at = v_on + interval '2 hours 10 minutes'),
               'phone_off'::public.duty_break_kind, 'phone off kept');
  perform t.eq((select count(*) from public.duty_breaks a join public.duty_breaks b
                on a.duty_day_id = b.duty_day_id and a.started_at < b.started_at
                and b.started_at < a.ended_at
                where a.duty_day_id = v_day.id), 0::bigint, 'no overlaps');
end;
$$;
select t.act_as_owner();
delete from public.profiles where id = '00000000-0000-0000-0000-000000000013';
delete from auth.users where id = '00000000-0000-0000-0000-000000000013';


\echo '--- photo uploads: at most 60 a day per person (L62)'
do $$
declare
  u uuid := '00000000-0000-0000-0000-000000000003';
  v_today date;
  i integer;
begin
  perform t.act_as(u);
  perform t.expect_error($q$select public.svc_count_photo_upload('00000000-0000-0000-0000-000000000003')$q$, 'permission denied');
  perform t.expect_error($q$select count(*) from private.photo_upload_counts$q$, 'permission denied');
  perform t.act_as_owner();
  v_today := private.ist_today();
  insert into private.photo_upload_counts (day, user_id, signed) values (v_today - 3, u, 9);
  perform set_config('role', 'service_role', false);
  for i in 1..60 loop
    perform t.eq(public.svc_count_photo_upload(u), true, 'photo ' || i || ' allowed');
  end loop;
  perform t.eq(public.svc_count_photo_upload(u), false, 'photo 61 refused');
  perform t.eq(public.svc_count_photo_upload(u), false, 'photo 62 refused');
  perform t.eq(public.svc_count_photo_upload('00000000-0000-0000-0000-000000000001'), true,
               'another person is not affected');
  perform t.act_as_owner();
  perform t.eq((select signed from private.photo_upload_counts where day = v_today and user_id = u),
               60::smallint, 'refused ones are not counted');
  perform t.eq((select count(*) from private.photo_upload_counts where day < v_today - 1), 0::bigint,
               'old days cleaned up');
  delete from private.photo_upload_counts;
end;
$$;

\echo '--- unused photos are deleted after 4 days (L56)'
do $$
declare
  v_used text;
  v_orphan text := 'visit-' || gen_random_uuid();
  v_young text := 'req-' || gen_random_uuid();
begin
  select photo_id into v_used from public.visits where photo_id is not null limit 1;
  perform t.act_as('00000000-0000-0000-0000-000000000001');
  perform t.expect_error(format('select public.svc_note_signed_photo(%L)', v_orphan), 'permission denied');
  perform t.expect_error($q$select count(*) from private.signed_photos$q$, 'permission denied');
  perform set_config('role', 'service_role', false);
  perform public.svc_note_signed_photo(v_used);
  perform public.svc_note_signed_photo(v_orphan);
  perform public.svc_note_signed_photo(v_orphan);
  perform t.eq((select count(*) from public.svc_photos_to_purge() where kind = 'orphan'), 0::bigint,
               'a new photo is not an orphan yet');
  perform t.act_as_owner();
  update private.signed_photos set signed_at = now() - interval '5 days';
  perform set_config('role', 'service_role', false);
  perform public.svc_note_signed_photo(v_young);
  perform t.eq((select array_agg(photo_id) from public.svc_photos_to_purge() where kind = 'orphan'),
               array[v_orphan], 'only the old unused photo is listed');
  perform t.act_as_owner();
  perform t.eq((select count(*) from private.signed_photos where photo_id = v_used), 0::bigint,
               'an old used photo is forgotten');
  perform t.eq((select count(*) from private.signed_photos), 2::bigint, 'young and orphan kept');
  perform set_config('role', 'service_role', false);
  perform t.eq(public.svc_photos_removed(array[v_orphan]), 1, 'orphan removed');
  perform t.eq((select count(*) from public.svc_photos_to_purge() where kind = 'orphan'), 0::bigint,
               'orphan deleted once');
  perform t.act_as_owner();
  insert into private.app_settings values ('photos_url', 'https://x.test/functions/v1/photos');
  update private.signed_photos set signed_at = now() - interval '5 days';
  delete from t.pushed;
  perform private.purge_photos();
  perform t.eq((select body from t.pushed), '{"action": "purge"}'::jsonb, 'an orphan starts the purge');
  delete from private.app_settings;
  delete from private.signed_photos;
end;
$$;

\echo 'ALL TESTS PASSED'
