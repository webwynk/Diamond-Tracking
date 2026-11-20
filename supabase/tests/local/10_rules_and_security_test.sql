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
  else
    perform t.expect_error($q$select public.duty_on('dev-e3-0001')$q$, 'duty_on_closed');
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
  perform t.eq(public.upload_points(v_id, v_points, 'dev-e1-0001'), 52, 'points stored');
  perform t.eq(public.upload_points(v_id, v_points, 'dev-e1-0001'), 0, 'a retried upload adds nothing');
  perform t.expect_error(format($q$select public.upload_points(%s, '[]', 'other-phone-1')$q$, v_id), 'signed_in_elsewhere');

  -- Another employee cannot touch this duty.
  perform t.act_as('00000000-0000-0000-0000-000000000002');
  perform t.expect_error(format($q$select public.upload_points(%s, %L, 'dev-e2-0001')$q$, v_id, v_points), 'duty_not_found');
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
  v := public.add_visit(v_cam, 'Agro Store', null, false, 22500000, 88300000, 'visit-' || v_cam,
                        now() - interval '1 day');
  perform t.eq(v.lat_e6, 22500000, 'camera photo keeps GPS');
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
  perform t.eq((select count(*) from private.upload_passes where user_id = e3), 0::bigint, 'reset removes passes');
  update public.profiles set active_device_id = 'dev-e3-0001' where id = e3;
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
  perform t.act_as(e2);
  perform public.upload_points(v_day.id, v_pts, 'dev-e2-0001');
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

  perform t.act_as(e2);
  perform t.expect_error($q$select public.svc_save_places(1, '[]')$q$, 'permission denied');
  perform t.expect_error($q$select count(*) from private.place_names$q$, 'permission denied');
  perform t.act_as_owner();
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

\echo 'ALL TESTS PASSED'
