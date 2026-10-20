-- =============================================================================
-- Migration: 20261020020000_security_and_operational_alerts.sql
-- Description: Security and operational alerts for Admin Notification Centre (PRD F12).
--
-- Why
--   PRD F12 defines remaining alert types for admin supervision:
--   1. new_device_login: login attempt with an unrecognized phone device ID.
--   2. failed_login: repeated incorrect PIN attempts (threshold 3 before lockout).
--   3. gps_disabled: location service turned off on an on-duty phone.
--
-- What
--   1. Expand notifications_type_check to allow 'new_device_login',
--      'failed_login', and 'gps_disabled'.
--   2. Update public.bind_my_device(p_device_id): when device_id mismatches,
--      emit a 'new_device_login' notification before returning false.
--   3. Update public.employee_login_check(p_code, p_pin): when failed attempts
--      reach 3, emit a 'failed_login' notification (hourly deduplicated).
--   4. Create public.report_gps_status(p_enabled boolean): allows on-duty employee
--      to report immediate GPS shutdown, writing 'gps_disabled' notification.
--
-- Rollback
--   drop function if exists public.report_gps_status(boolean);
--   -- restore previous bind_my_device and employee_login_check;
--   -- restore previous notifications_type_check constraint;
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Expand notifications_type_check constraint
-- -----------------------------------------------------------------------------
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type = any (array[
    'duty_on', 'duty_off', 'duty_auto_ended', 'mock_gps',
    'battery_low', 'no_signal', 'account_locked',
    'new_device_login', 'failed_login', 'gps_disabled'
  ]));

-- -----------------------------------------------------------------------------
-- 2. Device binding: notify admins when an unauthorized device attempts login
-- -----------------------------------------------------------------------------
create or replace function public.bind_my_device(p_device_id text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_device text;
  v_status text;
  v_code text;
begin
  select device_id, status, employee_code into v_current_device, v_status, v_code
  from public.profiles
  where id = auth.uid();

  if v_status is null or v_status != 'active' then
    raise exception 'Account is not active or not found';
  end if;

  if v_current_device is null then
    update public.profiles
    set device_id = p_device_id,
        updated_at = now()
    where id = auth.uid();
    return true;
  elsif v_current_device = p_device_id then
    return true;
  else
    -- Mismatch: Someone entered valid code/PIN from an unregistered phone
    perform private.notify(
      'new_device_login',
      auth.uid(),
      null,
      'new_device_login:' || auth.uid()::text || ':' || floor(extract(epoch from now()))::bigint::text,
      jsonb_build_object(
        'employee_code', v_code,
        'attempted_device_id', coalesce(p_device_id, 'unknown')
      )
    );
    return false;
  end if;
end;
$$;

revoke all on function public.bind_my_device(text) from public, anon;
grant execute on function public.bind_my_device(text) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Login check: notify on repeated failed attempts (threshold 3)
-- -----------------------------------------------------------------------------
create or replace function public.employee_login_check(p_code text, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_max_tries constant int := 5;
  c_lock      constant interval := interval '15 minutes';
  v_code      text := upper(btrim(coalesce(p_code, '')));
  v_p         public.profiles%rowtype;
  v_hash      text;
  v_failed    int;
begin
  select * into v_p
  from public.profiles
  where role = 'employee' and upper(employee_code) = v_code
  for update;

  if not found then
    -- Constant-time check so timing does not leak whether code exists
    perform extensions.crypt(coalesce(p_pin, ''), extensions.gen_salt('bf', 10));
    return jsonb_build_object('result', 'invalid');
  end if;

  if v_p.status = 'blocked' then
    return jsonb_build_object('result', 'blocked');
  end if;

  if v_p.locked_until is not null and v_p.locked_until > now() then
    return jsonb_build_object(
      'result', 'locked',
      'retry_after_seconds', ceil(extract(epoch from (v_p.locked_until - now())))::int);
  end if;

  select pin_hash into v_hash from private.employee_pins where user_id = v_p.id;

  if v_hash is not null and extensions.crypt(coalesce(p_pin, ''), v_hash) = v_hash then
    update public.profiles
       set failed_login_attempts = 0, locked_until = null
     where id = v_p.id
       and (failed_login_attempts <> 0 or locked_until is not null);
    return jsonb_build_object(
      'result', 'ok',
      'user_id', v_p.id,
      'email', v_p.email,
      'login_password', private.login_password(v_p.id),
      'must_change_pin', v_p.must_change_pin);
  end if;

  -- Wrong PIN or uninitialized PIN
  if v_hash is null then
    perform extensions.crypt(coalesce(p_pin, ''), extensions.gen_salt('bf', 10));
  end if;

  v_failed := coalesce(v_p.failed_login_attempts, 0) + 1;
  if v_failed >= c_max_tries then
    update public.profiles
       set failed_login_attempts = 0, locked_until = now() + c_lock
     where id = v_p.id;
    perform private.notify(
      'account_locked', v_p.id, null,
      'account_locked:' || v_p.id::text || ':' || floor(extract(epoch from now()))::bigint::text,
      jsonb_build_object('employee_code', v_p.employee_code, 'locked_minutes', 15));
    return jsonb_build_object(
      'result', 'locked',
      'retry_after_seconds', extract(epoch from c_lock)::int);
  end if;

  -- Alert admin at 3 failed attempts (hourly deduplication)
  if v_failed = 3 then
    perform private.notify(
      'failed_login', v_p.id, null,
      'failed_login:' || v_p.id::text || ':' || floor(extract(epoch from now()) / 3600)::bigint::text,
      jsonb_build_object('employee_code', v_p.employee_code, 'attempts', 3));
  end if;

  update public.profiles set failed_login_attempts = v_failed where id = v_p.id;
  return jsonb_build_object('result', 'invalid');
end;
$$;

revoke all on function public.employee_login_check(text, text) from public, anon, authenticated;
grant execute on function public.employee_login_check(text, text) to service_role;

-- -----------------------------------------------------------------------------
-- 4. Immediate GPS status reporting during duty
-- -----------------------------------------------------------------------------
create or replace function public.report_gps_status(p_enabled boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session_id uuid;
  v_code       text;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  -- Only act if employee has an open duty session
  select id into v_session_id
  from public.duty_sessions
  where employee_id = auth.uid() and ended_at is null
  order by started_at desc
  limit 1;

  if v_session_id is null then
    return false;
  end if;

  if not p_enabled then
    select employee_code into v_code
    from public.profiles
    where id = auth.uid();

    -- Deduplicate within 5-minute intervals per session
    perform private.notify(
      'gps_disabled',
      auth.uid(),
      v_session_id,
      'gps_disabled:' || v_session_id::text || ':' || floor(extract(epoch from now()) / 300)::bigint::text,
      jsonb_build_object(
        'employee_code', v_code,
        'reported_at', now()
      )
    );
  end if;

  return true;
end;
$$;

revoke all on function public.report_gps_status(boolean) from public, anon;
grant execute on function public.report_gps_status(boolean) to authenticated;
