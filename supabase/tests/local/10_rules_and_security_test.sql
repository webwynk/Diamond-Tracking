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
create function t.expect_error(p_sql text, p_expected text) returns void
language plpgsql as $$
begin
  execute p_sql;
  raise exception 'expected error "%" but it succeeded: %', p_expected, p_sql;
exception when others then
  if sqlerrm not like '%' || p_expected || '%' then
    raise exception 'expected error "%" but got "%" for: %', p_expected, sqlerrm, p_sql;
  end if;
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

grant usage on schema t to anon, authenticated;
grant execute on all functions in schema t to anon, authenticated;

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
select t.expect_error('select public.duty_on()', 'permission denied');
select t.expect_error('select public.server_now()', 'permission denied');
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
select t.expect_error('select public.duty_on()', 'not_active_employee');
select t.act_as_owner();

\echo '--- duty on follows the 05:00 to 08:30 IST window'
select t.act_as('00000000-0000-0000-0000-000000000003');
do $$
declare
  v_time time := (now() at time zone 'Asia/Kolkata')::time;
begin
  if v_time >= time '05:00' and v_time < time '08:31' then
    perform public.duty_on();
    perform t.expect_error('select public.duty_on()', 'already_on_duty_today');
  else
    perform t.expect_error('select public.duty_on()', 'duty_on_closed');
  end if;
end;
$$;
select t.act_as_owner();

\echo '--- a full day: points, a stop, a phone-off gap, duty off capped at 23:00'
do $$
declare
  v_day date := private.ist_today() - 1;
  v_id bigint;
  v_points jsonb := '[]';
  v_t timestamptz := private.ist_at(v_day, time '07:00');
  i integer;
begin
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values ('00000000-0000-0000-0000-000000000001', v_day, 'on_duty', v_t)
  returning id into v_id;
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

  perform t.act_as('00000000-0000-0000-0000-000000000001');
  perform t.eq(public.upload_points(v_id, v_points), 52, 'points stored');
  perform t.eq(public.upload_points(v_id, v_points), 0, 'a retried upload adds nothing');

  -- Another employee cannot touch this duty.
  perform t.act_as('00000000-0000-0000-0000-000000000002');
  perform t.expect_error(format('select public.upload_points(%s, %L)', v_id, v_points), 'duty_not_found');
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
begin
  perform t.act_as('00000000-0000-0000-0000-000000000003');
  -- Day 1 back was marked absent above; the request can still fix it.
  select id into v_req from public.request_attendance(v_today - 1, time '09:00', time '19:30', 'Forgot to duty on', 'photo/abc');
  perform t.expect_error(format($q$select public.request_attendance(%L, '09:00', '19:30', 'again', 'p')$q$, v_today - 1), 'already_requested');
  perform t.expect_error(format($q$select public.request_attendance(%L, '09:00', '19:30', 'old', 'p')$q$, v_today - 8), 'outside_request_window');
  perform t.expect_error(format($q$select public.request_attendance(%L, '19:00', '09:00', 'x', 'p')$q$, v_today - 3), 'invalid_times');
  perform t.expect_error(format($q$select public.request_attendance(%L, '09:00', '18:00', 'x', null)$q$, v_today - 3), 'check constraint');
  perform t.act_as('00000000-0000-0000-0000-000000000001');
  perform t.expect_error(format($q$select public.request_attendance(%L, '09:00', '19:30', 'x', 'p')$q$, v_today - 1), 'already_has_duty');

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
  v_req := public.request_leave('sick', array[v_today - 1, v_today + 1], 'Fever', 'proof/1');

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

\echo '--- visits need an open duty; gallery photos carry no GPS'
select t.act_as('00000000-0000-0000-0000-000000000001');
select t.expect_error($$select public.add_visit(gen_random_uuid(), 'Shop', null, false,
  22500000, 88300000, 'p/1', now())$$, 'not_on_duty');
select t.act_as_owner();
do $$
declare
  v_id uuid := gen_random_uuid();
  v public.visits;
begin
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values ('00000000-0000-0000-0000-000000000001', private.ist_today(), 'on_duty', now() - interval '1 hour');
  perform t.act_as('00000000-0000-0000-0000-000000000001');
  v := public.add_visit(v_id, 'Krishi Kendra', 'Order taken', true, 22500000, 88300000, 'p/2', now());
  perform t.eq(v.lat_e6, null::integer, 'gallery photo has no GPS');
  v := public.add_visit(v_id, 'Krishi Kendra', 'Order taken', true, null, null, 'p/2', now());
  perform t.act_as_owner();
  perform t.eq((select count(*) from public.visits), 1::bigint, 'a retried visit is not duplicated');
end;
$$;

\echo '--- cleanup removes old raw points'
do $$
begin
  update public.track_points set recorded_at = recorded_at - interval '8 days';
  perform private.cleanup();
  perform t.eq((select count(*) from public.track_points), 0::bigint, 'old points removed');
  perform t.eq((select count(*) from public.day_routes) > 0, true, 'routes kept');
end;
$$;

\echo 'ALL TESTS PASSED'
