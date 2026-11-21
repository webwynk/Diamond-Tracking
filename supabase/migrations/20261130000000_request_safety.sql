-- Review fixes L3, L4 and L5: approving attendance never overwrites a real
-- duty, a leave day counts no worked time, and a long note says so.
--
-- L3: decide_request approved an attendance request by writing the typed-in
--     duty times over the day, even when the day already had a real tracked
--     duty (or one still running). Rejecting set such a day to Absent. Now an
--     approve on a day with a recorded duty is refused ('day_has_duty'), and a
--     reject only closes the request and leaves the day alone.
-- L4: changing a day to Leave kept its worked minutes, so the report added
--     them to the hours. A leave day now counts no worked time. The duty times
--     stay saved, and going back to Present or Half day brings the minutes
--     back.
-- L5: a note over 300 characters hit the column check and showed a generic
--     error. decide_request and set_day_status now say 'note_too_long'.
--
-- Same functions as before (private.put_day from the baseline,
-- decide_request from the baseline, set_day_status from
-- 20261128000000_small_database_fixes) with only these changes. No data is
-- changed; grants stay as they are (create or replace keeps them).

-- Writes a day's status as an admin decision.
create or replace function private.put_day(
  p_user uuid, p_day date, p_status public.day_status, p_source text,
  p_leave public.leave_type default null, p_note text default null,
  p_on timestamptz default null, p_off timestamptz default null
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.duty_days as dd
    (user_id, day, status, leave_type, status_source, decided_by, decided_at, note,
     duty_on_at, duty_off_at, worked_minutes)
  values
    (p_user, p_day, p_status, p_leave, p_source, auth.uid(), now(), p_note,
     p_on, p_off,
     case when p_on is not null and p_status <> 'leave'
          then floor(extract(epoch from p_off - p_on) / 60) end)
  on conflict (user_id, day) do update set
    status = excluded.status,
    leave_type = excluded.leave_type,
    status_source = excluded.status_source,
    decided_by = excluded.decided_by,
    decided_at = excluded.decided_at,
    note = coalesce(excluded.note, dd.note),
    duty_on_at = coalesce(excluded.duty_on_at, dd.duty_on_at),
    duty_off_at = coalesce(excluded.duty_off_at, dd.duty_off_at),
    -- A leave day counts no worked time (L4). The duty times stay, so going
    -- back to present brings the minutes back.
    worked_minutes = case
      when excluded.status = 'leave' then null
      else coalesce(excluded.worked_minutes, dd.worked_minutes,
                    floor(extract(epoch from dd.duty_off_at - dd.duty_on_at) / 60)::integer)
    end;
end;
$$;

-- The admin decides a request.
--   attendance: p_decision present or half_day approves, absent rejects.
--   leave:      p_decision leave approves, absent rejects (days are unchanged).
--   short_duty: p_decision present, half_day or absent.
create or replace function public.decide_request(
  p_request_id bigint, p_decision public.day_status, p_note text default null
) returns public.requests
language plpgsql security definer set search_path = '' as $$
declare
  v_admin uuid := private.require_admin();
  v_req public.requests;
  v_approved boolean;
  v_day date;
  v_title text;
  v_has_duty boolean;
begin
  select * into v_req from public.requests where id = p_request_id for update;
  if not found then
    raise exception 'request_not_found' using errcode = 'P0002';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'request_already_decided' using errcode = 'P0001';
  end if;
  if char_length(coalesce(p_note, '')) > 300 then
    raise exception 'note_too_long' using errcode = '22023';
  end if;

  if v_req.kind = 'attendance' then
    if p_decision not in ('present', 'half_day', 'absent') then
      raise exception 'invalid_decision' using errcode = '22023';
    end if;
    v_approved := p_decision <> 'absent';
    -- A day with a real recorded duty keeps it (L3): approving would replace
    -- the tracked times with the typed ones, so it is refused, and rejecting
    -- only closes the request.
    v_has_duty := exists (select 1 from public.duty_days where user_id = v_req.user_id
                          and day = v_req.day and duty_on_at is not null);
    if v_approved and v_has_duty then
      raise exception 'day_has_duty' using errcode = 'P0001';
    end if;
    if v_approved then
      perform private.put_day(v_req.user_id, v_req.day, p_decision, 'request',
                              null, p_note, v_req.duty_on_at, v_req.duty_off_at);
    elsif not v_has_duty then
      perform private.put_day(v_req.user_id, v_req.day, 'absent', 'request', null, p_note);
    end if;
    v_title := case when v_approved then 'Attendance approved' else 'Attendance rejected' end;

  elsif v_req.kind = 'leave' then
    if p_decision not in ('leave', 'absent') then
      raise exception 'invalid_decision' using errcode = '22023';
    end if;
    v_approved := p_decision = 'leave';
    if v_approved then
      foreach v_day in array v_req.dates loop
        -- A day already worked keeps its duty.
        if not exists (select 1 from public.duty_days where user_id = v_req.user_id
                       and day = v_day and duty_on_at is not null) then
          perform private.put_day(v_req.user_id, v_day, 'leave', 'request',
                                  v_req.leave_type, p_note);
        end if;
      end loop;
    end if;
    v_title := case when v_approved then 'Leave approved' else 'Leave rejected' end;

  else -- short_duty
    if p_decision not in ('present', 'half_day', 'absent') then
      raise exception 'invalid_decision' using errcode = '22023';
    end if;
    v_approved := p_decision <> 'absent';
    update public.duty_days set status = p_decision, status_source = 'admin',
      decided_by = v_admin, decided_at = now(), note = coalesce(p_note, note)
    where user_id = v_req.user_id and day = v_req.day;
    v_title := 'Short duty marked ' || replace(p_decision::text, '_', ' ');
  end if;

  update public.requests set
    status = case when v_approved then 'approved' else 'rejected' end::public.request_status,
    decision = p_decision, decision_note = p_note,
    decided_by = v_admin, decided_at = now()
  where id = p_request_id
  returning * into v_req;

  perform private.notify(v_req.user_id, 'request_decided', v_title, p_note,
                         jsonb_build_object('request_id', v_req.id));
  perform private.log_admin('decide_request', v_req.user_id,
    jsonb_build_object('request_id', v_req.id, 'kind', v_req.kind, 'decision', p_decision));
  return v_req;
end;
$$;

-- Admin override of any day's status (see 20261128000000_small_database_fixes).
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
  if char_length(coalesce(p_note, '')) > 300 then
    raise exception 'note_too_long' using errcode = '22023';
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
