-- Review fixes L30 and L39.
--
-- L30: the server functions changed an account's claims (role, "must change
-- password") by reading them, changing one key and writing them all back.
-- Two changes to one account at the same moment could each write back the
-- claims they read, so one undid the other: for example an admin's role
-- change and the user choosing a password. The merge now happens inside
-- one database update, so each change sees the one before it.
--
-- L39: "choose your own password first" was checked only by the app. An
-- account still on its temporary PIN could call the employee and admin
-- database functions directly. They now refuse it with
-- 'must_change_password'. Choosing the password (the account function) and
-- claiming the phone at sign-in still work, as they must.

-- ---------------------------------------------------------------------------
-- L30: merge claims in one update

-- Merges [p_values] into the account's server-only claims (app_metadata).
-- Server functions only. Raises if there is no such account.
create function public.svc_merge_app_metadata(p_user uuid, p_values jsonb) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_values is null or jsonb_typeof(p_values) <> 'object' then
    raise exception 'invalid_values' using errcode = '22023';
  end if;
  update auth.users
  set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || p_values
  where id = p_user;
  if not found then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- L39: no employee or admin work while on a temporary PIN

-- True while the account must still choose its own password. Read from the
-- account itself, not the sign-in token, so it ends the moment the password
-- is chosen.
create function private.on_temporary_pin(p_uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select raw_app_meta_data ->> 'must_change_password' = 'true'
     from auth.users where id = p_uid),
    false);
$$;

-- As in 20261202000000_one_signed_in_phone.sql, plus the temporary PIN check.
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
  if private.on_temporary_pin(auth.uid()) then
    raise exception 'must_change_password' using errcode = '42501';
  end if;
  if v_device is null
     or (v_session is not null and v_session is distinct from private.jwt_session()) then
    raise exception 'signed_in_elsewhere' using errcode = 'P0001';
  end if;
  return auth.uid();
end;
$$;

-- As in the baseline, plus the temporary PIN check.
create or replace function private.require_admin() returns uuid
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  if private.on_temporary_pin(auth.uid()) then
    raise exception 'must_change_password' using errcode = '42501';
  end if;
  return auth.uid();
end;
$$;

revoke all on function
  public.svc_merge_app_metadata(uuid, jsonb),
  private.on_temporary_pin(uuid)
from public, anon, authenticated;
grant execute on function
  public.svc_merge_app_metadata(uuid, jsonb),
  private.on_temporary_pin(uuid)
to service_role;
