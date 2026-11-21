-- File 16 of the 2026-11-20 review, L94: the database tests can set the
-- clock, so every run checks duty on inside and outside 5:00-8:30 AM, the
-- admin's permission before and after 9:00 PM, and getting back on duty
-- before and after 11 PM, whatever time the run starts.
--
-- private.now() is the real time, unless a test has put a time in
-- private.test_clock. Nobody but the database owner can write that table
-- (it is in the private schema, with no grants), so on the live project it
-- stays empty and private.now() is always now(). Today's date, duty on, the
-- permission and duty resume use it; their rules are unchanged.

create table private.test_clock (
  id boolean primary key default true check (id),
  at timestamptz not null
);
revoke all on private.test_clock from public, anon, authenticated;

create function private.now() returns timestamptz
language sql stable set search_path = '' as $$
  select coalesce((select c.at from private.test_clock c), now());
$$;
revoke all on function private.now() from public, anon, authenticated;
grant execute on function private.now() to service_role;

create or replace function private.ist_today() returns date
language sql stable set search_path = '' as $$
  select (private.now() at time zone 'Asia/Kolkata')::date;
$$;

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
  if private.now() >= private.permit_cutoff_at(v_day) then
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
        created_at = private.now(), used_at = null;
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
  v_local timestamp := private.now() at time zone 'Asia/Kolkata';
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
    update public.duty_permits set used_at = private.now()
    where user_id = v_uid and day = v_day and used_at is null
      and private.now() < private.permit_cutoff_at(v_day);
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
    update public.duty_permits set used_at = private.now()
    where user_id = v_uid and day = v_day and used_at is null;
  end if;

  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (v_uid, v_day, 'on_duty', private.now())
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

create or replace function public.duty_resume(p_device_id text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_row public.duty_days;
begin
  perform private.require_device(v_uid, p_device_id);
  select * into v_row from public.duty_days
  where user_id = v_uid and day = private.ist_today() and status = 'on_duty';
  if not found or private.now() >= private.auto_off_at(v_row.day) then
    raise exception 'not_on_duty' using errcode = 'P0001';
  end if;
  return jsonb_build_object('day', to_jsonb(v_row),
                            'upload_pass', private.new_upload_pass(v_row, p_device_id));
end;
$$;
