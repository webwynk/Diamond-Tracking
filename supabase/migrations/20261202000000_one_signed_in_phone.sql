-- One signed-in phone per employee, checked on every action (M5), and an
-- admin "Release phone" button for a lost or broken phone (M6, decided:
-- admin button only, no automatic release).
--
-- The rule itself is unchanged: the first phone to sign in holds the account
-- (claim_device), a second phone is refused until the first logs out
-- (release_device), or the admin releases it or resets the password.
--
-- New:
--   * The account remembers which sign-in holds it (the session id inside
--     the sign-in token). Duty off, requests, visits and cancelling a request
--     now refuse any other sign-in with "signed_in_elsewhere", like duty on
--     and route uploads already did. This needs no app change: the token is
--     sent with every call.
--   * Phones signed in before this change have no remembered sign-in yet.
--     They keep working, and are remembered at their next duty on, resume
--     or sign-in.
--   * release_phone(user): admin only. Signs that employee out of their phone
--     and frees the account, without changing the password.

alter table public.profiles add column active_session_id uuid;

-- The sign-in (session) id of the current request, or null.
create function private.jwt_session() returns uuid
language sql stable set search_path = '' as $$
  select nullif(auth.jwt() ->> 'session_id', '')::uuid
$$;

-- Employees only, and only from the sign-in that holds the account.
create or replace function private.require_employee() returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare
  v_device text;
  v_session uuid;
begin
  select active_device_id, active_session_id into v_device, v_session
  from public.profiles
  where id = (select auth.uid()) and role = 'employee' and is_active;
  if not found then
    raise exception 'not_active_employee' using errcode = '42501';
  end if;
  if v_device is null
     or (v_session is not null and v_session is distinct from private.jwt_session()) then
    raise exception 'signed_in_elsewhere' using errcode = 'P0001';
  end if;
  return auth.uid();
end;
$$;

-- Duty on and resume: the phone must hold the account. A phone signed in
-- before this change is remembered here.
create or replace function private.require_device(p_uid uuid, p_device_id text) returns void
language plpgsql volatile security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.profiles
                 where id = p_uid and active_device_id = p_device_id) then
    raise exception 'signed_in_elsewhere' using errcode = 'P0001';
  end if;
  update public.profiles set active_session_id = private.jwt_session()
  where id = p_uid and active_session_id is null and private.jwt_session() is not null;
end;
$$;

-- Called right after sign-in with the phone's install id.
create or replace function public.claim_device(p_device_id text) returns void
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
  -- Same phone signing in again: the new sign-in takes over.
  update public.profiles
  set active_device_id = p_device_id, active_session_id = private.jwt_session()
  where id = v_uid;
end;
$$;

-- Called on logout from the phone that holds the account.
create or replace function public.release_device(p_device_id text) returns void
language sql security definer set search_path = '' as $$
  update public.profiles set active_device_id = null, active_session_id = null
  where id = (select auth.uid()) and active_device_id = p_device_id;
$$;

-- Signs a user out of every phone (password reset, Release phone): sign-ins
-- and route upload passes end, the account is free, and the old phone stops
-- getting pushes. The new phone gets a fresh pass when it resumes the duty.
create or replace function private.revoke_sessions(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from auth.sessions where user_id = p_user;
  delete from private.upload_passes where user_id = p_user;
  update public.profiles set active_device_id = null, active_session_id = null
  where id = p_user;
  delete from private.push_tokens where user_id = p_user;
end;
$$;

-- Admin: frees an employee's account from a lost, broken or reset phone,
-- without changing the password. Returns false if no phone held it.
-- A running duty carries on when they sign in on the new phone (or turns
-- off at 11 PM as usual).
create function public.release_phone(p_user uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_device text;
begin
  if not private.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  select active_device_id into v_device from public.profiles
  where id = p_user and role = 'employee';
  if not found then
    raise exception 'user_not_found' using errcode = 'P0001';
  end if;
  perform private.revoke_sessions(p_user);
  perform private.log_admin('release_phone', p_user,
                            jsonb_build_object('had_phone', v_device is not null));
  return v_device is not null;
end;
$$;

revoke all on function public.release_phone(uuid) from public, anon;
grant execute on function public.release_phone(uuid) to authenticated, service_role;
revoke all on function private.jwt_session() from public, anon, authenticated;
grant execute on function private.jwt_session() to service_role;
