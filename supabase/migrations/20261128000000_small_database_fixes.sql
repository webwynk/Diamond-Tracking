-- Review fixes M1, M8 and M2. Three small, separate clean-ups.

-- ---------------------------------------------------------------------------
-- M1: public.places is a leftover.
--
-- The first version of the maps work kept stop addresses in public.places.
-- 20261123000000_maps made the real cache, private.place_names, which only the
-- server can open, and nothing writes or reads public.places any more. It was
-- also readable by every signed-in user. It holds nothing (no code ever
-- filled it), and the guard below stops the migration if someone put rows in
-- by hand, so nothing is lost silently.
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from public.places) then
    raise exception 'public.places is not empty: look at it before dropping it';
  end if;
end;
$$;

drop table public.places;

-- ---------------------------------------------------------------------------
-- M8: public.upload_points (the signed-in version) is not used.
--
-- The tracker uploads with a day pass (upload_points_with_pass); the app
-- never calls the signed-in version. Two ways into the same data is one more
-- than needed. The tests now use the pass version.
-- ---------------------------------------------------------------------------

drop function public.upload_points(bigint, jsonb, text);

-- ---------------------------------------------------------------------------
-- M2: an admin's day decision also settles the short-duty review.
--
-- A short day is "pending" and waits in the admin's Requests list as a
-- short_duty request. If the admin set that day's status from the day screen
-- instead, the request stayed open, and deciding it later silently replaced the
-- admin's choice. Now set_day_status closes the day's open short-duty request
-- with the same decision (approved for present, half day or leave; rejected
-- for absent). The employee is not sent a second notification: set_day_status
-- never sent one. The admin log keeps the closed request's id.
-- ---------------------------------------------------------------------------

create or replace function public.set_day_status(
  p_user uuid, p_day date, p_status public.day_status,
  p_leave public.leave_type default null, p_note text default null
) returns public.duty_days
language plpgsql security definer set search_path = '' as $$
declare
  v_admin uuid := private.require_admin();
  v_before public.day_status;
  v_closed bigint;
  v_row public.duty_days;
begin
  if p_status in ('on_duty', 'pending') then
    raise exception 'invalid_decision' using errcode = '22023';
  end if;
  if (p_status = 'leave') <> (p_leave is not null) then
    raise exception 'invalid_decision' using errcode = '22023';
  end if;
  if not exists (select 1 from public.profiles where id = p_user and role = 'employee') then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
  if p_day > private.ist_today() then
    raise exception 'future_day' using errcode = 'P0001';
  end if;
  select status into v_before from public.duty_days where user_id = p_user and day = p_day;
  if v_before = 'on_duty' then
    raise exception 'duty_running' using errcode = 'P0001';
  end if;

  perform private.put_day(p_user, p_day, p_status, 'admin', p_leave, p_note);

  -- The day's open short-duty review is settled by this decision.
  update public.requests set
    status = case when p_status = 'absent' then 'rejected' else 'approved' end::public.request_status,
    decision = p_status, decision_note = p_note,
    decided_by = v_admin, decided_at = now()
  where user_id = p_user and kind = 'short_duty' and day = p_day and status = 'pending'
  returning id into v_closed;

  select * into v_row from public.duty_days where user_id = p_user and day = p_day;
  perform private.log_admin('set_day_status', p_user, jsonb_build_object(
    'day', p_day, 'from', v_before, 'to', p_status, 'note', p_note,
    'closed_request', v_closed));
  return v_row;
end;
$$;
