-- Phase 3: one phone at a time, password reset codes, session revocation.
--
-- Sign-in itself is Supabase Auth (email + password). The app turns a user
-- ID into the account's sign-in email (<id>@staff.diamondagritech.internal),
-- so no lookup function is needed and Supabase's own rate limits apply per
-- phone. Admin-only actions (create user, reset PIN) and the first-login
-- password change run in Edge Functions with the secret key.

-- ---------------------------------------------------------------------------
-- One phone at a time (employees)
-- ---------------------------------------------------------------------------

-- Called right after sign-in with the phone's install id. The first phone
-- claims the account; a second phone is refused until the first one logs out
-- or the admin resets the password.
create function public.claim_device(p_device_id text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_current text;
  v_role public.app_role;
begin
  if p_device_id is null or char_length(p_device_id) not between 8 and 100 then
    raise exception 'invalid_device' using errcode = '22023';
  end if;
  select active_device_id, role into v_current, v_role
  from public.profiles where id = v_uid and is_active for update;
  if not found then
    raise exception 'account_inactive' using errcode = '42501';
  end if;
  if v_role = 'admin' then
    return;  -- admins may use more than one phone
  end if;
  if v_current is not null and v_current <> p_device_id then
    raise exception 'signed_in_elsewhere' using errcode = 'P0001';
  end if;
  update public.profiles set active_device_id = p_device_id where id = v_uid;
end;
$$;

-- Called on logout from the phone that holds the account.
create function public.release_device(p_device_id text) returns void
language sql security definer set search_path = '' as $$
  update public.profiles set active_device_id = null
  where id = (select auth.uid()) and active_device_id = p_device_id;
$$;

-- Duty and uploads only work from the phone that holds the account.
create function private.require_device(p_uid uuid, p_device_id text) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.profiles
                 where id = p_uid and active_device_id = p_device_id) then
    raise exception 'signed_in_elsewhere' using errcode = 'P0001';
  end if;
end;
$$;

-- duty_on and upload_points now take the device id.
drop function public.duty_on();
create function public.duty_on(p_device_id text) returns public.duty_days
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_local timestamp := now() at time zone 'Asia/Kolkata';
  v_day date := v_local::date;
  v_row public.duty_days;
begin
  perform private.require_device(v_uid, p_device_id);
  if v_local::time < time '05:00' or v_local::time >= time '08:31' then
    raise exception 'duty_on_closed' using errcode = 'P0001';
  end if;
  select * into v_row from public.duty_days where user_id = v_uid and day = v_day;
  if found then
    if v_row.status = 'leave' then
      raise exception 'on_leave_today' using errcode = 'P0001';
    end if;
    raise exception 'already_on_duty_today' using errcode = 'P0001';
  end if;
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (v_uid, v_day, 'on_duty', now())
  returning * into v_row;
  return v_row;
end;
$$;

alter function public.upload_points(bigint, jsonb) rename to upload_points_unchecked;
alter function public.upload_points_unchecked(bigint, jsonb) set schema private;
create function public.upload_points(p_day_id bigint, p_points jsonb, p_device_id text)
returns integer
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_device(private.require_employee(), p_device_id);
  return private.upload_points_unchecked(p_day_id, p_points);
end;
$$;

-- ---------------------------------------------------------------------------
-- Used by the Edge Functions (secret key only)
-- ---------------------------------------------------------------------------

-- Signs a user out of every phone: refresh tokens stop working at once,
-- access tokens expire within the hour, and the device lock is released.
create function private.revoke_sessions(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from auth.sessions where user_id = p_user;
  update public.profiles set active_device_id = null where id = p_user;
end;
$$;

-- Emailed password reset codes. Only a hash is stored; 15 minutes, 5 tries.
create table private.password_reset_codes (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  code_hash  text not null,
  expires_at timestamptz not null,
  attempts   smallint not null default 0,
  created_at timestamptz not null default now()
);

-- Stores a new code for a user (replacing any earlier one). Returns false if
-- a code was sent less than a minute ago, so the email cannot be spammed.
create function private.store_reset_code(p_user uuid, p_code text) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from private.password_reset_codes
             where user_id = p_user and created_at > now() - interval '1 minute') then
    return false;
  end if;
  insert into private.password_reset_codes (user_id, code_hash, expires_at)
  values (p_user, extensions.crypt(p_code, extensions.gen_salt('bf')), now() + interval '15 minutes')
  on conflict (user_id) do update set
    code_hash = excluded.code_hash, expires_at = excluded.expires_at,
    attempts = 0, created_at = now();
  return true;
end;
$$;

-- Checks a code. A correct code is used up; a wrong one counts an attempt.
create function private.use_reset_code(p_user uuid, p_code text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  r private.password_reset_codes;
begin
  select * into r from private.password_reset_codes where user_id = p_user for update;
  if not found or r.expires_at < now() or r.attempts >= 5 then
    return false;
  end if;
  if r.code_hash = extensions.crypt(p_code, r.code_hash) then
    delete from private.password_reset_codes where user_id = p_user;
    return true;
  end if;
  update private.password_reset_codes set attempts = attempts + 1 where user_id = p_user;
  return false;
end;
$$;

-- Edge Functions call these through PostgREST, which only exposes public.
-- Thin wrappers, executable by the secret key only.
create function public.svc_revoke_sessions(p_user uuid) returns void
language sql security definer set search_path = '' as $$
  select private.revoke_sessions(p_user);
$$;
create function public.svc_store_reset_code(p_user uuid, p_code text) returns boolean
language sql security definer set search_path = '' as $$
  select private.store_reset_code(p_user, p_code);
$$;
create function public.svc_use_reset_code(p_user uuid, p_code text) returns boolean
language sql security definer set search_path = '' as $$
  select private.use_reset_code(p_user, p_code);
$$;
create function public.svc_log_admin(
  p_admin uuid, p_action text, p_target uuid, p_details jsonb
) returns void
language sql security definer set search_path = '' as $$
  insert into public.admin_log (admin_id, action, target_user, details)
  values (p_admin, p_action, p_target, coalesce(p_details, '{}'));
$$;

-- Expired codes go in the nightly cleanup.
create or replace function private.cleanup() returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.track_points where recorded_at < now() - interval '7 days';
  delete from public.day_routes where day < private.ist_today() - 90;
  delete from public.notifications where created_at < now() - interval '60 days';
  delete from public.live_positions lp
  where not exists (select 1 from public.duty_days d
                    where d.id = lp.duty_day_id and d.status = 'on_duty')
    and lp.updated_at < now() - interval '1 day';
  delete from private.password_reset_codes where expires_at < now() - interval '1 day';
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on all functions in schema public from public, anon, authenticated;
revoke all on all functions in schema private from public, anon, authenticated;
revoke all on private.password_reset_codes from public, anon, authenticated;

grant execute on function
  public.server_now(),
  public.duty_on(text),
  public.duty_off(bigint, timestamptz),
  public.upload_points(bigint, jsonb, text),
  public.request_attendance(date, time, time, text, text),
  public.request_leave(public.leave_type, date[], text, text),
  public.cancel_request(bigint),
  public.decide_request(bigint, public.day_status, text),
  public.set_day_status(uuid, date, public.day_status, public.leave_type, text),
  public.add_visit(uuid, text, text, boolean, integer, integer, text, timestamptz),
  public.mark_notifications_read(bigint[]),
  public.claim_device(text),
  public.release_device(text)
to authenticated;
grant execute on function private.is_admin() to authenticated;
grant execute on all functions in schema public to service_role;
grant execute on all functions in schema private to service_role;
