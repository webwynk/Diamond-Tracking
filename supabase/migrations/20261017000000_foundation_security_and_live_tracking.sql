-- =============================================================================
-- Migration: 20261017000000_foundation_security_and_live_tracking.sql
-- Description: Phase 1 foundation. Closes two security holes in the first
--   schema, enforces the duty rules on the SERVER, and adds the tables the
--   admin live map and the audit trail need.
--
-- Forward-only and idempotent: safe to run on a database that has the earlier
-- migrations applied, and safe to run twice.
--
-- What it does
--   1. handle_new_user: role now comes ONLY from app_metadata (user_metadata is
--      editable by the user, so it could make anyone an admin). Employees get a
--      profile only when the server supplies code + phone; otherwise no profile.
--   2. Invalidates the admin password that the first schema file wrote into git
--      (only if it is still that exact password).
--   3. Server-side duty rules (docs/05 section 5): the 08:00-23:00 IST window,
--      server-stamped times, close-only updates, append-only history, and a
--      server-computed distance (BR-8) that the client cannot forge.
--   4. Point ingestion guard: an employee can only write points for their own
--      session, inside that session's time span.
--   5. live_locations: one row per on-duty employee, kept current by a trigger,
--      published to Realtime. The admin map subscribes to this, never to
--      location_points (docs/06 section 7).
--   6. audit_log: admin-readable, written only by the server.
--
-- Rollback (manual, in this order): drop the triggers named below, drop
-- table public.live_locations and public.audit_log, drop schema private
-- cascade, then restore the previous handle_new_user from 20261016.
-- =============================================================================

create extension if not exists "pgcrypto";

-- Internal helpers live outside the API-exposed schema.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 1. Profile creation: never trust user_metadata for authorization
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role  text := new.raw_app_meta_data ->> 'role';
  v_code  text := nullif(trim(new.raw_app_meta_data ->> 'employee_code'), '');
  v_phone text := nullif(trim(new.raw_app_meta_data ->> 'phone'), '');
  v_name  text := coalesce(
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
      id, email, role, status, full_name, employee_code, phone, must_change_pin
    ) values (
      new.id, new.email, 'employee', 'active', v_name, upper(v_code), v_phone, true
    )
    on conflict (id) do nothing;
  end if;
  -- Anyone else gets an auth user but NO profile, and therefore no access.
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Neutralise the admin password that was committed in the first schema file
-- -----------------------------------------------------------------------------
do $$
begin
  update auth.users
  set encrypted_password = crypt(gen_random_uuid()::text || gen_random_uuid()::text, gen_salt('bf')),
      updated_at = now()
  where email = 'admin@diamondagritech.com'
    and encrypted_password = crypt('Admin@2026!', encrypted_password);
end $$;

-- -----------------------------------------------------------------------------
-- 3. Duty sessions: server-owned rules
-- -----------------------------------------------------------------------------

-- Distance (BR-8): haversine over the session's own points, excluding mock
-- points, poor-accuracy points (> 100 m) and impossible jumps (> 55 m/s).
create or replace function private.session_distance_km(p_session uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  with pts as (
    select latitude  as lat,
           longitude as lon,
           recorded_at,
           lag(latitude)    over w as plat,
           lag(longitude)   over w as plon,
           lag(recorded_at) over w as prev_at
    from public.location_points
    where session_id = p_session
      and not is_mock
      and (accuracy is null or accuracy <= 100)
    window w as (order by recorded_at, id)
  ),
  seg as (
    select 6371.0088 * 2 * asin(sqrt(least(1.0,
             power(sin(radians(lat - plat) / 2), 2)
             + cos(radians(plat)) * cos(radians(lat))
               * power(sin(radians(lon - plon) / 2), 2)))) as km,
           extract(epoch from (recorded_at - prev_at)) as secs
    from pts
    where plat is not null
  )
  select coalesce(
    round((sum(km) filter (where secs > 0 and km * 1000.0 / secs <= 55.0))::numeric, 3),
    0
  )
  from seg;
$$;

create or replace function private.duty_sessions_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hour   int;
  v_status text;
begin
  -- Server jobs (no JWT) are trusted; everything below is for app users.
  if auth.uid() is null then
    return new;
  end if;

  if new.employee_id is distinct from auth.uid() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select status into v_status
  from public.profiles
  where id = new.employee_id and role = 'employee';

  if v_status is distinct from 'active' then
    raise exception 'account_not_active' using errcode = 'P0001';
  end if;

  -- BR-1: 08:00 to 23:00 IST, judged on SERVER time.
  v_hour := extract(hour from (now() at time zone 'Asia/Kolkata'));
  if v_hour < 8 or v_hour >= 23 then
    raise exception 'duty_outside_window'
      using errcode = 'P0001',
            hint = 'Duty is allowed between 08:00 and 23:00 IST.';
  end if;

  -- The client may not choose any of these.
  new.started_at := now();
  new.status := 'open';
  new.ended_at := null;
  new.end_reason := null;
  new.total_distance_km := 0;
  new.visits_count := 0;
  new.mock_points_count := 0;
  return new;
end;
$$;

create or replace function private.duty_sessions_before_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  -- BR-15: a closed session is history and never changes.
  if old.ended_at is not null then
    raise exception 'session_already_closed' using errcode = 'P0001';
  end if;

  -- An employee update can only CLOSE their own open session.
  new.employee_id := old.employee_id;
  new.started_at := old.started_at;
  new.visits_count := old.visits_count;
  new.status := case when new.status = 'auto_curfew' then 'auto_curfew' else 'completed' end;
  new.ended_at := now();
  new.total_distance_km := private.session_distance_km(old.id);
  new.mock_points_count := (
    select count(*)::int
    from public.location_points
    where session_id = old.id and is_mock
  );
  return new;
end;
$$;

drop trigger if exists trg_duty_sessions_before_insert on public.duty_sessions;
create trigger trg_duty_sessions_before_insert
before insert on public.duty_sessions
for each row execute function private.duty_sessions_before_insert();

drop trigger if exists trg_duty_sessions_before_update on public.duty_sessions;
create trigger trg_duty_sessions_before_update
before update on public.duty_sessions
for each row execute function private.duty_sessions_before_update();

-- An update policy needs both USING and WITH CHECK (docs/05 section 4).
drop policy if exists "Employees can update own duty sessions" on public.duty_sessions;
create policy "Employees can update own duty sessions"
on public.duty_sessions for update to authenticated
using (employee_id = (select auth.uid()))
with check (employee_id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- 4. Location points: only your own open session, inside its time span
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'chk_location_points_lat') then
    alter table public.location_points
      add constraint chk_location_points_lat check (latitude between -90 and 90);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'chk_location_points_lon') then
    alter table public.location_points
      add constraint chk_location_points_lon check (longitude between -180 and 180);
  end if;
end $$;

create index if not exists idx_location_points_employee_recorded
  on public.location_points (employee_id, recorded_at);
create index if not exists idx_location_points_recorded
  on public.location_points (recorded_at);

create or replace function private.location_points_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner   uuid;
  v_started timestamptz;
  v_ended   timestamptz;
begin
  if new.recorded_at > now() + interval '5 minutes' then
    raise exception 'timestamp_in_future' using errcode = 'P0001';
  end if;

  if auth.uid() is null then
    return new;
  end if;

  select employee_id, started_at, ended_at
    into v_owner, v_started, v_ended
  from public.duty_sessions
  where id = new.session_id;

  if v_owner is null or v_owner <> auth.uid() then
    raise exception 'session_not_found' using errcode = 'P0001';
  end if;

  -- Late uploads are fine, but only for moments inside the session.
  if new.recorded_at < v_started - interval '1 minute'
     or new.recorded_at > coalesce(v_ended, now()) + interval '5 minutes' then
    raise exception 'point_outside_session' using errcode = 'P0001';
  end if;

  new.employee_id := auth.uid();
  return new;
end;
$$;

drop trigger if exists trg_location_points_before_insert on public.location_points;
create trigger trg_location_points_before_insert
before insert on public.location_points
for each row execute function private.location_points_before_insert();

-- Tighten the insert policy: the owner must be the caller, never null.
drop policy if exists "Employees can insert own location points" on public.location_points;
create policy "Employees can insert own location points"
on public.location_points for insert to authenticated
with check (employee_id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- 5. live_locations: what the admin map shows (one row per on-duty employee)
-- -----------------------------------------------------------------------------
create table if not exists public.live_locations (
  employee_id   uuid primary key references public.profiles(id) on delete cascade,
  session_id    uuid not null references public.duty_sessions(id) on delete cascade,
  latitude      double precision not null,
  longitude     double precision not null,
  accuracy      double precision,
  battery_level integer,
  is_mock       boolean not null default false,
  recorded_at   timestamptz not null,
  updated_at    timestamptz not null default now()
);

alter table public.live_locations enable row level security;

-- Reads only. There is deliberately NO insert, update or delete policy: the
-- trigger below is the only writer.
drop policy if exists "Admins can view all live locations" on public.live_locations;
create policy "Admins can view all live locations"
on public.live_locations for select to authenticated
using (public.is_admin());

drop policy if exists "Employees can view own live location" on public.live_locations;
create policy "Employees can view own live location"
on public.live_locations for select to authenticated
using (employee_id = (select auth.uid()));

create or replace function private.location_points_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.live_locations (
    employee_id, session_id, latitude, longitude, accuracy,
    battery_level, is_mock, recorded_at, updated_at
  ) values (
    new.employee_id, new.session_id, new.latitude, new.longitude, new.accuracy,
    new.battery_level, new.is_mock, new.recorded_at, now()
  )
  on conflict (employee_id) do update
    set session_id    = excluded.session_id,
        latitude      = excluded.latitude,
        longitude     = excluded.longitude,
        accuracy      = excluded.accuracy,
        battery_level = excluded.battery_level,
        is_mock       = excluded.is_mock,
        recorded_at   = excluded.recorded_at,
        updated_at    = now()
    -- A late-arriving old point must never move the marker backwards.
    where public.live_locations.recorded_at < excluded.recorded_at;
  return null;
end;
$$;

drop trigger if exists trg_location_points_after_insert on public.location_points;
create trigger trg_location_points_after_insert
after insert on public.location_points
for each row execute function private.location_points_after_insert();

-- Going off duty removes the employee from the live map.
create or replace function private.duty_sessions_after_close()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.ended_at is null and new.ended_at is not null then
    delete from public.live_locations
    where employee_id = new.employee_id and session_id = new.id;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_duty_sessions_after_close on public.duty_sessions;
create trigger trg_duty_sessions_after_close
after update on public.duty_sessions
for each row execute function private.duty_sessions_after_close();

-- Publish to Realtime (respects the RLS policies above).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'live_locations'
     ) then
    alter publication supabase_realtime add table public.live_locations;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 6. Audit log: admins read, nobody writes from the app
-- -----------------------------------------------------------------------------
create table if not exists public.audit_log (
  id         bigint generated always as identity primary key,
  actor_id   uuid references public.profiles(id) on delete set null,
  action     text not null,
  target_id  uuid,
  details    jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_audit_log_created on public.audit_log (created_at desc);

alter table public.audit_log enable row level security;

drop policy if exists "Admins can view audit log" on public.audit_log;
create policy "Admins can view audit log"
on public.audit_log for select to authenticated
using (public.is_admin());
-- No insert/update/delete policy: only the service role (Edge Functions) writes.
