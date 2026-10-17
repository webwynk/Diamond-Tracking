-- =============================================================================
-- Migration: 20261017010000_profiles_contact_email.sql
-- Description: Give employees a real contact email, and protect + audit profile
-- edits made by admins (PRD F2: code immutable, every admin action audited).
--
-- profiles.email is the LOGIN email for employees (a synthetic address built
-- from the employee code, so the employee signs in with code + PIN). The
-- "Add employee" form also collects a real contact email (PRD F2), which must
-- not collide with that, so it gets its own column.
--
-- Forward-only, additive, idempotent. Old app builds are unaffected (they never
-- read the new column).
-- =============================================================================

alter table public.profiles
  add column if not exists contact_email text;

-- Same trigger as before, now also carrying the optional contact email that the
-- create-employee function puts in app_metadata (server-only, not user-editable).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role    text := new.raw_app_meta_data ->> 'role';
  v_code    text := nullif(trim(new.raw_app_meta_data ->> 'employee_code'), '');
  v_phone   text := nullif(trim(new.raw_app_meta_data ->> 'phone'), '');
  v_contact text := nullif(trim(new.raw_app_meta_data ->> 'contact_email'), '');
  v_name    text := coalesce(
    nullif(trim(new.raw_app_meta_data ->> 'full_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    split_part(coalesce(new.email, ''), '@', 1)
  );
begin
  if v_role = 'admin' then
    insert into public.profiles (id, email, role, status, full_name, must_change_pin)
    values (new.id, new.email, 'admin', 'active', v_name, false)
    on conflict (id) do nothing;
  elsif v_role = 'employee' and v_code is not null and v_phone is not null then
    insert into public.profiles (
      id, email, contact_email, role, status, full_name, employee_code, phone, must_change_pin
    ) values (
      new.id, new.email, v_contact, 'employee', 'active', v_name, upper(v_code), v_phone, true
    )
    on conflict (id) do nothing;
  end if;
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Profile edits by admins: protect what must not change, audit what did
-- -----------------------------------------------------------------------------
create or replace function private.profiles_before_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Server jobs (no JWT) are trusted.
  if auth.uid() is null then
    return new;
  end if;

  -- The employee code and role never change after creation (PRD F2), and a
  -- login email is tied to the code. Nobody can edit these from the app.
  if new.id is distinct from old.id
     or new.role is distinct from old.role
     or new.employee_code is distinct from old.employee_code
     or new.email is distinct from old.email then
    raise exception 'immutable_field' using errcode = 'P0001';
  end if;

  if new.status is distinct from old.status then
    if new.status = 'blocked' then
      new.blocked_at := now();
      new.blocked_by := auth.uid();
    else
      new.blocked_at := null;
      new.blocked_by := null;
      new.blocked_reason := null;
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.profiles_audit_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action text;
begin
  if auth.uid() is null then
    return null;
  end if;

  if new.status is distinct from old.status then
    v_action := case when new.status = 'blocked' then 'employee_blocked' else 'employee_unblocked' end;
  elsif new.full_name is distinct from old.full_name
     or new.phone is distinct from old.phone
     or new.contact_email is distinct from old.contact_email then
    v_action := 'employee_updated';
  else
    return null;  -- device binding, PIN flag etc.: not an admin edit
  end if;

  insert into public.audit_log (actor_id, action, target_id, details)
  values (
    auth.uid(),
    v_action,
    new.id,
    jsonb_build_object('employee_code', new.employee_code, 'reason', new.blocked_reason)
  );
  return null;
end;
$$;

drop trigger if exists trg_profiles_before_update on public.profiles;
create trigger trg_profiles_before_update
before update on public.profiles
for each row execute function private.profiles_before_update();

drop trigger if exists trg_profiles_audit_update on public.profiles;
create trigger trg_profiles_audit_update
after update on public.profiles
for each row execute function private.profiles_audit_update();
