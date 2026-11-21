-- L6: two Duty on presses at the same moment.
--
-- Before: both presses passed the "no duty yet" check, and the second one hit
-- the unique (user_id, day) rule with a raw "duplicate key" error. With the
-- admin's permission the second press said "duty on is closed", because the
-- first press had already used the permission.
--
-- Now: today's duty is checked before the permission is used, and again when
-- the permission is gone or the insert finds a row already there. The second
-- press always gets "already_on_duty_today" (or "on_leave_today").
-- Everything else is unchanged.

create or replace function public.duty_on(p_device_id text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_local timestamp := now() at time zone 'Asia/Kolkata';
  v_day date := v_local::date;
  v_row public.duty_days;
  v_status public.day_status;
begin
  perform private.require_device(v_uid, p_device_id);

  -- One duty a day, and none on a leave day. Checked first, so a second press
  -- never uses up (or is refused by) the admin's permission.
  select d.status into v_status from public.duty_days d
  where d.user_id = v_uid and d.day = v_day;
  if found then
    if v_status = 'leave' then
      raise exception 'on_leave_today' using errcode = 'P0001';
    end if;
    raise exception 'already_on_duty_today' using errcode = 'P0001';
  end if;

  if v_local::time < time '05:00' or v_local::time >= time '08:31' then
    -- Outside the window only with the admin's permission for today.
    update public.duty_permits set used_at = now()
    where user_id = v_uid and day = v_day and used_at is null
      and now() < private.auto_off_at(v_day);
    if not found then
      -- A press at the same moment may have used it and started the duty.
      select d.status into v_status from public.duty_days d
      where d.user_id = v_uid and d.day = v_day;
      if found then
        if v_status = 'leave' then
          raise exception 'on_leave_today' using errcode = 'P0001';
        end if;
        raise exception 'already_on_duty_today' using errcode = 'P0001';
      end if;
      raise exception 'duty_on_closed' using errcode = 'P0001';
    end if;
  end if;

  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (v_uid, v_day, 'on_duty', now())
  on conflict (user_id, day) do nothing
  returning * into v_row;
  if not found then
    -- A press at the same moment got there first.
    select d.status into v_status from public.duty_days d
    where d.user_id = v_uid and d.day = v_day;
    if v_status = 'leave' then
      raise exception 'on_leave_today' using errcode = 'P0001';
    end if;
    raise exception 'already_on_duty_today' using errcode = 'P0001';
  end if;
  return jsonb_build_object('day', to_jsonb(v_row),
                            'upload_pass', private.new_upload_pass(v_row, p_device_id));
end;
$$;
