-- =============================================================================
-- Migration: 20261015000000_create_profiles_table.sql
-- Description: Create profiles table, roles, RLS policies, indexes, and triggers
-- Author: Diamond Agritech
-- =============================================================================

-- 1. Helper function: updated_at trigger
create or replace function public.update_updated_at_column()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- 2. Profiles table
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'employee')),
  status text not null default 'active' check (status in ('active', 'blocked')),
  employee_code text unique, -- Unique for employees, nullable for pure-email admins
  full_name text not null,
  phone text unique,
  email text unique,
  device_id text,
  must_change_pin boolean not null default true,
  failed_login_attempts integer not null default 0,
  locked_until timestamptz,
  blocked_at timestamptz,
  blocked_reason text,
  blocked_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Employees must have an employee_code and phone number
  constraint chk_employee_mandatory_fields check (
    role != 'employee' or (employee_code is not null and phone is not null)
  )
);

-- 3. Performance indexes
create index if not exists idx_profiles_role on public.profiles(role);
create index if not exists idx_profiles_employee_code on public.profiles(lower(employee_code));
create index if not exists idx_profiles_phone on public.profiles(phone);

-- 4. Trigger for updated_at
drop trigger if exists trigger_profiles_updated_at on public.profiles;
create trigger trigger_profiles_updated_at
before update on public.profiles
for each row
execute function public.update_updated_at_column();

-- 5. Helper function: is_admin()
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role = 'admin'
      and status = 'active'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- 6. Row-Level Security
alter table public.profiles enable row level security;

-- Drop existing policies if any to ensure clean idempotent migration
drop policy if exists "Admins can view all profiles" on public.profiles;
drop policy if exists "Employees can view own profile" on public.profiles;
drop policy if exists "Admins can insert profiles" on public.profiles;
drop policy if exists "Admins can update profiles" on public.profiles;

-- Select policies
create policy "Admins can view all profiles"
on public.profiles
for select
to authenticated
using (public.is_admin());

create policy "Employees can view own profile"
on public.profiles
for select
to authenticated
using (id = (select auth.uid()));

-- Insert policy (Admins only)
create policy "Admins can insert profiles"
on public.profiles
for insert
to authenticated
with check (public.is_admin());

-- Update policy (Admins only)
create policy "Admins can update profiles"
on public.profiles
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- 7. Device binding function for employees
create or replace function public.bind_my_device(p_device_id text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_device text;
  v_status text;
begin
  select device_id, status into v_current_device, v_status
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
    return false;
  end if;
end;
$$;

revoke all on function public.bind_my_device(text) from public;
grant execute on function public.bind_my_device(text) to authenticated;

-- 8. Complete first PIN change function for employees
create or replace function public.complete_pin_change()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
  set must_change_pin = false,
      updated_at = now()
  where id = auth.uid();
  return true;
end;
$$;

revoke all on function public.complete_pin_change() from public;
grant execute on function public.complete_pin_change() to authenticated;

-- 9. Trigger to create profile when user is created in auth.users
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (
    id,
    email,
    role,
    status,
    full_name,
    must_change_pin
  ) values (
    new.id,
    new.email,
    coalesce(new.raw_app_meta_data->>'role', new.raw_user_meta_data->>'role', 'employee'),
    'active',
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    case when coalesce(new.raw_app_meta_data->>'role', 'employee') = 'admin' then false else true end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();
