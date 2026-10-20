-- =============================================================================
-- Migration: 20261020010000_admin_clear_device.sql
-- Description: Admin "Clear device binding", audited (PRD F2, BR-13).
--
-- Why
--   An employee account is bound to one phone: bind_my_device() records the first
--   phone that signs in and refuses any other. When an employee legitimately
--   changes phone there was no way to clear that, and PRD F2 says the action must
--   be logged ("Every create, edit, block, unblock, PIN reset, and device clear
--   appears in the audit log").
--
--   A second problem found while checking (2026-10-20): the signed-in role had a
--   table-wide UPDATE grant on public.profiles, so an admin could already set
--   device_id to null straight through the API, with NO audit entry (the audit
--   trigger deliberately ignores that column). The same grant covered
--   failed_login_attempts, locked_until and must_change_pin, which the server
--   functions of migration 20261020000000 now own.
--
-- What
--   1. public.admin_clear_device(p_employee): active admins only. In one locked
--      step it checks the target is an employee, clears device_id, deletes the
--      employee's Supabase sessions (a lost or old phone stops working and must
--      sign in again; the next phone to sign in becomes the registered one) and
--      writes the audit row `device_binding_cleared`. Returns true when a phone
--      was registered and is now cleared, false when none was registered (nothing
--      is written, so a double tap or two admins at once leave one audit row).
--      The employee's open duty session is not touched; the server still ends it
--      at 23:00 IST.
--   2. Least privilege: the signed-in role may now update only the columns the
--      app really writes (full_name, phone, contact_email, status,
--      blocked_reason). Everything else, device_id included, changes only
--      through a server function, so "no audit, no change" holds.
--
-- Backward compatible
--   Yes. Searched lib/ on 2026-10-20: the app updates profiles only for the
--   five columns above (edit employee, block, unblock). bind_my_device and the
--   other functions are security definer and are not affected by a column grant.
--
-- Rollback
--   drop function if exists public.admin_clear_device(uuid);
--   grant update on public.profiles to authenticated;
-- =============================================================================

create or replace function public.admin_clear_device(p_employee uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code   text;
  v_device text;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select employee_code, device_id into v_code, v_device
  from public.profiles
  where id = p_employee and role = 'employee'
  for update;

  if not found then
    raise exception 'employee_not_found' using errcode = 'P0001';
  end if;

  if v_device is null then
    return false;
  end if;

  update public.profiles
     set device_id = null, updated_at = now()
   where id = p_employee;

  -- The old (or lost) phone is signed out; refresh tokens go with the sessions.
  delete from auth.sessions where user_id = p_employee;

  insert into public.audit_log (actor_id, action, target_id, details)
  values (auth.uid(), 'device_binding_cleared', p_employee,
          jsonb_build_object('employee_code', v_code));

  return true;
end;
$$;

revoke all on function public.admin_clear_device(uuid) from public, anon;
grant execute on function public.admin_clear_device(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- Least privilege on public.profiles
-- -----------------------------------------------------------------------------
revoke update on public.profiles from authenticated;
grant update (full_name, phone, contact_email, status, blocked_reason)
  on public.profiles to authenticated;
