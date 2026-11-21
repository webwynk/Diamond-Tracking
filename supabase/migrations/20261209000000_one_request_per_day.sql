-- L18: an attendance request and a leave request could both be waiting for
-- the same day, so the admin could approve both. Now a request is refused
-- while a request of either kind is waiting for one of its days.
-- L19: a leave request with an empty (null) date is refused; it could never
-- be approved.
--
-- L21 (docs only): phone push needs the pg_net extension on as well as the
-- push_url setting; supabase/reset/STEPS.txt now says so.
--
-- Both functions are the same as in 20261124000000_requests_push.sql apart
-- from those checks.

create or replace function public.request_attendance(
  p_day date, p_duty_on time, p_duty_off time, p_message text, p_photo_id text
) returns public.requests
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_today date := private.ist_today();
  v_row public.requests;
begin
  if p_day > v_today or p_day < v_today - 7 then
    raise exception 'outside_request_window' using errcode = 'P0001';
  end if;
  if p_duty_off <= p_duty_on then
    raise exception 'invalid_times' using errcode = '22023';
  end if;
  if private.ist_at(p_day, p_duty_off) > now() then
    raise exception 'invalid_times' using errcode = '22023';
  end if;
  if nullif(trim(p_message), '') is null then
    raise exception 'message_required' using errcode = '22023';
  end if;
  if p_photo_id is null or not private.valid_photo_id(p_photo_id) then
    raise exception 'photo_required' using errcode = '22023';
  end if;
  if exists (select 1 from public.duty_days
             where user_id = v_uid and day = p_day and duty_on_at is not null) then
    raise exception 'already_has_duty' using errcode = 'P0001';
  end if;
  -- One waiting request per day, of either kind (L18).
  if exists (select 1 from public.requests where user_id = v_uid and status = 'pending'
             and ((kind = 'attendance' and day = p_day)
                  or (kind = 'leave' and p_day = any (dates)))) then
    raise exception 'already_requested' using errcode = 'P0001';
  end if;

  insert into public.requests (user_id, kind, day, duty_on_at, duty_off_at, message, photo_id)
  values (v_uid, 'attendance', p_day, private.ist_at(p_day, p_duty_on),
          private.ist_at(p_day, p_duty_off), trim(p_message), p_photo_id)
  returning * into v_row;

  perform private.notify_admins(
    'attendance_request', 'Attendance request',
    (select full_name from public.profiles where id = v_uid)
      || ' asked for attendance on ' || to_char(p_day, 'DD Mon YYYY'),
    jsonb_build_object('request_id', v_row.id));
  return v_row;
end;
$$;

create or replace function public.request_leave(
  p_type public.leave_type, p_dates date[], p_message text, p_proof_id text default null
) returns public.requests
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_dates date[];
  v_row public.requests;
begin
  select array_agg(distinct d order by d) into v_dates from unnest(p_dates) d;
  -- An empty date could never be approved (L19).
  if v_dates is null or cardinality(v_dates) > 31 or array_position(v_dates, null) is not null then
    raise exception 'invalid_dates' using errcode = '22023';
  end if;
  if v_dates[1] < private.ist_today() - 7 then
    raise exception 'outside_request_window' using errcode = 'P0001';
  end if;
  if v_dates[cardinality(v_dates)] > private.ist_today() + 90 then
    raise exception 'invalid_dates' using errcode = '22023';
  end if;
  if nullif(trim(p_message), '') is null then
    raise exception 'message_required' using errcode = '22023';
  end if;
  if nullif(trim(p_proof_id), '') is not null and not private.valid_photo_id(p_proof_id) then
    raise exception 'invalid_photo' using errcode = '22023';
  end if;
  -- Overlapping a leave request still waiting would make two decisions for a day.
  -- ... and so would an attendance request still waiting for one of the days (L18).
  if exists (select 1 from public.requests where user_id = v_uid and status = 'pending'
             and ((kind = 'leave' and dates && v_dates)
                  or (kind = 'attendance' and day = any (v_dates)))) then
    raise exception 'already_requested' using errcode = 'P0001';
  end if;

  insert into public.requests (user_id, kind, leave_type, dates, message, photo_id)
  values (v_uid, 'leave', p_type, v_dates, trim(p_message), nullif(trim(p_proof_id), ''))
  returning * into v_row;

  perform private.notify_admins(
    'leave_request', 'Leave request',
    (select full_name from public.profiles where id = v_uid) || ' asked for '
      || cardinality(v_dates) || ' day(s) of ' || p_type || ' leave from '
      || to_char(v_dates[1], 'DD Mon'),
    jsonb_build_object('request_id', v_row.id));
  return v_row;
end;
$$;
