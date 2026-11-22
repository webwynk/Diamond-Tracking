-- Sick leave only, from today on (owner, 2026-11-23).
--
-- 1. Casual leave is gone everywhere: the employee's form, the admin's
--    "Change day status" and the reports. A check on both tables that hold a
--    leave type is the one guard for every way a leave day is written
--    (request_leave, decide_request, set_day_status, put_day), old app
--    versions included. The 'casual' value stays in the leave_type enum:
--    removing an enum value is not safe in Postgres, and no row uses it
--    (checked on live before this migration: no leave request or leave day
--    existed yet).
-- 2. request_leave takes days from today up to 90 days ahead (was 7 days
--    back). The same as in 20261218000000_request_photos_auto_off_alerts.sql
--    otherwise; create or replace keeps its grants.

alter table public.requests add constraint requests_sick_leave_only
  check (leave_type is null or leave_type = 'sick');
alter table public.duty_days add constraint duty_days_sick_leave_only
  check (leave_type is null or leave_type = 'sick');

create or replace function public.request_leave(
  p_type public.leave_type, p_dates date[], p_message text, p_proof_id text default null,
  p_extra_photo_ids text[] default null
) returns public.requests
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_proof text := nullif(trim(p_proof_id), '');
  v_extra text[] := private.extra_photos_or_null(p_extra_photo_ids);
  v_dates date[];
  v_row public.requests;
begin
  if p_type is distinct from 'sick' then
    raise exception 'sick_leave_only' using errcode = '22023';
  end if;
  select array_agg(distinct d order by d) into v_dates from unnest(p_dates) d;
  -- An empty date could never be approved (L19).
  if v_dates is null or cardinality(v_dates) > 31 or array_position(v_dates, null) is not null then
    raise exception 'invalid_dates' using errcode = '22023';
  end if;
  if v_dates[1] < private.ist_today() then
    raise exception 'leave_from_today' using errcode = 'P0001';
  end if;
  if v_dates[cardinality(v_dates)] > private.ist_today() + 90 then
    raise exception 'invalid_dates' using errcode = '22023';
  end if;
  if nullif(trim(p_message), '') is null then
    raise exception 'message_required' using errcode = '22023';
  end if;
  if v_proof is not null and not private.valid_photo_id(v_proof) then
    raise exception 'invalid_photo' using errcode = '22023';
  end if;
  if not private.valid_extra_photos(v_proof, v_extra) then
    raise exception 'invalid_photo' using errcode = '22023';
  end if;
  -- Overlapping a leave request still waiting would make two decisions for a day.
  -- ... and so would an attendance request still waiting for one of the days (L18).
  if exists (select 1 from public.requests where user_id = v_uid and status = 'pending'
             and ((kind = 'leave' and dates && v_dates)
                  or (kind = 'attendance' and day = any (v_dates)))) then
    raise exception 'already_requested' using errcode = 'P0001';
  end if;

  insert into public.requests (user_id, kind, leave_type, dates, message, photo_id,
                               extra_photo_ids)
  values (v_uid, 'leave', p_type, v_dates, trim(p_message), v_proof, v_extra)
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
