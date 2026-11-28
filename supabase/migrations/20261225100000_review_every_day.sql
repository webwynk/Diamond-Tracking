-- Every duty day is reviewed by an admin (owner, 2026-11-28).
--
-- Before: at duty off, 10 hours or more made the day Present by itself, and
-- only a shorter day waited for an admin (a "short_duty" review).
-- Now: every duty off (by the employee, sent later from an offline phone, or
-- the 11 PM automatic duty off) leaves the day waiting ("pending") with a
-- review for the admins, who decide present, half day or absent.
--
-- The request kind keeps its name "short_duty" so installed apps and
-- existing rows keep working; the app now calls it "Duty review".
-- Days already decided are not touched.
--
-- close_duty: always pending + review; the admins' alert gives the hours,
-- the km, and says when 11 PM ended it.
-- decide_request: the same as in 20261130000000_request_safety.sql apart
-- from the employee's message, "Your day was marked Present".

create or replace function private.close_duty(
  p_day_id bigint, p_off_at timestamptz, p_reason public.duty_end_reason
) returns public.duty_days
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.duty_days;
  v_minutes integer;
  v_request bigint;
begin
  select * into v_row from public.duty_days where id = p_day_id for update;
  if not found or v_row.status <> 'on_duty' then
    return v_row;
  end if;

  v_minutes := floor(extract(epoch from p_off_at - v_row.duty_on_at) / 60);
  perform private.build_route(p_day_id);

  update public.duty_days set
    duty_off_at = p_off_at,
    end_reason = p_reason,
    worked_minutes = v_minutes,
    status = 'pending'
  where id = p_day_id
  returning * into v_row;

  -- One waiting review per day (requests_one_pending_per_day): reuse one
  -- that is somehow still open instead of failing the duty off.
  insert into public.requests (user_id, kind, day)
  values (v_row.user_id, 'short_duty', v_row.day)
  on conflict (user_id, kind, day) where status = 'pending' and day is not null do nothing
  returning id into v_request;
  if v_request is null then
    select id into v_request from public.requests
    where user_id = v_row.user_id and kind = 'short_duty' and day = v_row.day
      and status = 'pending';
  end if;
  perform private.notify_admins(
    'short_duty', 'Duty to review',
    (select full_name from public.profiles where id = v_row.user_id)
      || ' worked ' || (v_minutes / 60) || ' h ' || (v_minutes % 60) || ' min · '
      || to_char(coalesce(v_row.distance_m, 0) / 1000.0, 'FM9990.0') || ' km'
      || case when p_reason = 'auto' then ' · ended at 11 PM' else '' end,
    jsonb_build_object('user_id', v_row.user_id, 'day', v_row.day, 'request_id', v_request));
  return v_row;
end;
$$;

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
    v_title := 'Your day was marked '
      || upper(left(p_decision::text, 1)) || replace(substr(p_decision::text, 2), '_', ' ');
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
