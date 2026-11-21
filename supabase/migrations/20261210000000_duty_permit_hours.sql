-- Review fixes L27 and L28 for "Allow duty on today".
--
-- L28: a permission given late at night (for example 10:50 PM) started a
-- duty of a few minutes that ended at 11 PM, was always short and made a
-- request for the admin. Permissions can now be given, and used, only until
-- 9:00 PM India time (private.permit_cutoff_at). Later, allow_duty_on says
-- too_late, as it did after 11 PM before.
--
-- L27: a permission given before or inside 5:00-8:30 AM was never used when
-- the employee started inside the window, so it showed as "waiting" all
-- day. duty_on now marks today's waiting permission as used whenever a duty
-- starts, inside the window or not.
--
-- Everything else in duty_on is unchanged from duty_on_double_press (L6).

-- The last moment of day p_day when a permission can be given or used.
create function private.permit_cutoff_at(p_day date) returns timestamptz
language sql immutable set search_path = '' as $$
  select private.ist_at(p_day, time '21:00');
$$;
revoke all on function private.permit_cutoff_at(date) from public, anon, authenticated;

create or replace function public.allow_duty_on(p_user uuid, p_note text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_admin uuid := private.require_admin();
  v_day date := private.ist_today();
  v_note text := nullif(trim(p_note), '');
begin
  if not exists (select 1 from public.profiles
                 where id = p_user and role = 'employee' and is_active) then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
  if now() >= private.permit_cutoff_at(v_day) then
    raise exception 'too_late' using errcode = 'P0001';
  end if;
  if char_length(coalesce(v_note, '')) > 300 then
    raise exception 'note_too_long' using errcode = '22023';
  end if;
  -- Any record for today (a duty, leave, or an admin's absent) means duty on
  -- would be refused anyway.
  if exists (select 1 from public.duty_days where user_id = p_user and day = v_day) then
    raise exception 'day_already_recorded' using errcode = 'P0001';
  end if;

  insert into public.duty_permits (user_id, day, granted_by, note)
  values (p_user, v_day, v_admin, v_note)
  on conflict (user_id, day) do update
    set granted_by = excluded.granted_by, note = excluded.note,
        created_at = now(), used_at = null;
  perform private.notify(
    p_user, 'duty_on_allowed', 'Duty on allowed',
    'The admin allowed you to do duty on today, until 9:00 PM. Open the app to start.');
  perform private.log_admin('allow_duty_on', p_user,
    jsonb_build_object('day', v_day, 'note', v_note));
end;
$$;

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
    -- Outside the window only with the admin's permission, until 9:00 PM.
    update public.duty_permits set used_at = now()
    where user_id = v_uid and day = v_day and used_at is null
      and now() < private.permit_cutoff_at(v_day);
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
  else
    -- Inside the window no permission is needed. A waiting one is used up
    -- here so it does not show as "not used yet" for the rest of the day.
    update public.duty_permits set used_at = now()
    where user_id = v_uid and day = v_day and used_at is null;
  end if;

  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (v_uid, v_day, 'on_duty', now())
  on conflict (user_id, day) do nothing
  returning * into v_row;
  if not found then
    -- A press at the same moment got there first. Raising rolls back the
    -- permission update above as well.
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
