-- =============================================================================
-- Migration: 20261016000000_complete_app_schema.sql
-- Description: Complete schema for Diamond Agritech Tracking App
-- Includes: profiles, duty_sessions, location_points, RLS policies, helper RPCs,
-- and bootstrap admin user creation.
-- =============================================================================

-- Enable pgcrypto for password hashing & uuid generation
create extension if not exists "pgcrypto";

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

  constraint chk_employee_mandatory_fields check (
    role != 'employee' or (employee_code is not null and phone is not null)
  )
);

create index if not exists idx_profiles_role on public.profiles(role);
create index if not exists idx_profiles_employee_code on public.profiles(lower(employee_code));
create index if not exists idx_profiles_phone on public.profiles(phone);

drop trigger if exists trigger_profiles_updated_at on public.profiles;
create trigger trigger_profiles_updated_at
before update on public.profiles
for each row
execute function public.update_updated_at_column();

-- 3. Helper function: is_admin()
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

-- 4. Row-Level Security on profiles
alter table public.profiles enable row level security;

drop policy if exists "Admins can view all profiles" on public.profiles;
create policy "Admins can view all profiles"
on public.profiles
for select
to authenticated
using (public.is_admin());

drop policy if exists "Employees can view own profile" on public.profiles;
create policy "Employees can view own profile"
on public.profiles
for select
to authenticated
using (id = (select auth.uid()));

drop policy if exists "Admins can insert profiles" on public.profiles;
create policy "Admins can insert profiles"
on public.profiles
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "Admins can update profiles" on public.profiles;
create policy "Admins can update profiles"
on public.profiles
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- 5. Device binding function for employees (BR-13)
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

-- 6. Complete first PIN change function for employees
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

-- 7. Trigger to auto-create profile on new user in auth.users
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

-- 8. Duty Sessions table (PRD BR-1, BR-2, BR-4)
create table if not exists public.duty_sessions (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'open' check (status in ('open', 'completed', 'auto_curfew', 'blocked')),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  total_distance_km numeric(10,3) not null default 0.0,
  visits_count integer not null default 0,
  mock_points_count integer not null default 0,
  end_reason text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Crucial constraint: Exactly one open session per employee (PRD BR-4)
create unique index if not exists idx_duty_sessions_one_open 
on public.duty_sessions (employee_id) 
where ended_at is null;

create index if not exists idx_duty_sessions_employee_started 
on public.duty_sessions (employee_id, started_at desc);

drop trigger if exists trigger_duty_sessions_updated_at on public.duty_sessions;
create trigger trigger_duty_sessions_updated_at
before update on public.duty_sessions
for each row
execute function public.update_updated_at_column();

alter table public.duty_sessions enable row level security;

drop policy if exists "Admins can view all duty sessions" on public.duty_sessions;
create policy "Admins can view all duty sessions"
on public.duty_sessions for select to authenticated
using (public.is_admin());

drop policy if exists "Employees can view own duty sessions" on public.duty_sessions;
create policy "Employees can view own duty sessions"
on public.duty_sessions for select to authenticated
using (employee_id = (select auth.uid()));

drop policy if exists "Employees can insert own duty sessions" on public.duty_sessions;
create policy "Employees can insert own duty sessions"
on public.duty_sessions for insert to authenticated
with check (employee_id = (select auth.uid()));

drop policy if exists "Employees can update own duty sessions" on public.duty_sessions;
create policy "Employees can update own duty sessions"
on public.duty_sessions for update to authenticated
using (employee_id = (select auth.uid()));

-- 9. Location Points table (PRD BR-7, BR-8, BR-9, BR-10)
create table if not exists public.location_points (
  id text primary key,
  session_id uuid references public.duty_sessions(id) on delete cascade,
  employee_id uuid references public.profiles(id) on delete restrict,
  latitude double precision not null,
  longitude double precision not null,
  accuracy double precision,
  speed double precision,
  heading double precision,
  altitude double precision,
  battery_level integer,
  is_mock boolean not null default false,
  recorded_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_location_points_session 
on public.location_points (session_id, recorded_at);

alter table public.location_points enable row level security;

drop policy if exists "Admins can view all location points" on public.location_points;
create policy "Admins can view all location points"
on public.location_points for select to authenticated
using (public.is_admin());

drop policy if exists "Employees can view own location points" on public.location_points;
create policy "Employees can view own location points"
on public.location_points for select to authenticated
using (employee_id = (select auth.uid()));

drop policy if exists "Employees can insert own location points" on public.location_points;
create policy "Employees can insert own location points"
on public.location_points for insert to authenticated
with check (employee_id = (select auth.uid()) or employee_id is null);

-- 10. Bootstrap initial Admin User
do $$
declare
  new_admin_id uuid := gen_random_uuid();
  admin_email text := 'admin@diamondagritech.com';
  admin_pass text := 'Admin@2026!';
begin
  if not exists (select 1 from auth.users where email = admin_email) then
    insert into auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      role,
      aud
    ) values (
      new_admin_id,
      '00000000-0000-0000-0000-000000000000',
      admin_email,
      crypt(admin_pass, gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"],"role":"admin"}'::jsonb,
      '{"full_name":"Operations Admin","role":"admin"}'::jsonb,
      now(),
      now(),
      'authenticated',
      'authenticated'
    );
  end if;

  insert into public.profiles (
    id,
    email,
    role,
    status,
    full_name,
    must_change_pin,
    created_at,
    updated_at
  )
  select 
    id, 
    email, 
    'admin', 
    'active', 
    'Operations Admin', 
    false, 
    now(), 
    now()
  from auth.users 
  where email = admin_email
  on conflict (id) do update set 
    role = 'admin',
    status = 'active',
    must_change_pin = false;
end $$;
