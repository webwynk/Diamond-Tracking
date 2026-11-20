-- Diamond Agritech rewrite: baseline schema.
--
-- One migration for the whole new database. Rules that matter (duty window,
-- 10-hour minimum, who may see what) are enforced here, not only in the app.
--
-- Conventions
--   * Times are timestamptz, stamped by the database (now()), never trusted
--     from the phone. Business days are India dates (Asia/Kolkata).
--   * Coordinates are stored as integers in millionths of a degree (lat_e6),
--     about 11 cm precision in 4 bytes instead of 8.
--   * Every write goes through a function in this file. Tables are read-only
--     for app users, and row-level security limits what each user can read.
--   * Functions that bypass row-level security live in the `private` schema,
--     which the API does not expose, or check the caller themselves.
--   * Errors are raised with a short code as the message (for example
--     'duty_on_closed'); the app turns codes into friendly text.

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

create type public.app_role as enum ('employee', 'admin');

-- on_duty: duty running. pending: waiting for an admin decision.
create type public.day_status as enum
  ('on_duty', 'present', 'half_day', 'absent', 'leave', 'pending');

create type public.leave_type as enum ('sick', 'casual');
create type public.request_kind as enum ('attendance', 'leave', 'short_duty');
create type public.request_status as enum
  ('pending', 'approved', 'rejected', 'cancelled');
create type public.duty_end_reason as enum ('manual', 'auto');

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

create function private.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Today's date in India.
create function private.ist_today() returns date
language sql stable set search_path = '' as $$
  select (now() at time zone 'Asia/Kolkata')::date;
$$;

-- The instant of an India wall-clock time on a given day.
create function private.ist_at(p_day date, p_time time) returns timestamptz
language sql immutable set search_path = '' as $$
  select (p_day + p_time) at time zone 'Asia/Kolkata';
$$;

-- Automatic duty off: 23:00 India time on the duty day.
create function private.auto_off_at(p_day date) returns timestamptz
language sql immutable set search_path = '' as $$
  select private.ist_at(p_day, time '23:00');
$$;

-- Distance in metres between two points given in millionths of a degree.
create function private.dist_m(
  lat1 integer, lng1 integer, lat2 integer, lng2 integer
) returns double precision
language sql immutable set search_path = '' as $$
  select 2 * 6371008.8 * asin(sqrt(
    power(sin(radians((lat2 - lat1) / 1e6) / 2), 2)
    + cos(radians(lat1 / 1e6)) * cos(radians(lat2 / 1e6))
      * power(sin(radians((lng2 - lng1) / 1e6) / 2), 2)
  ));
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

-- One row per login. Created by the admin's Edge Function (service key).
create table public.profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  user_code        text not null
                   check (user_code ~ '^[A-Za-z0-9][A-Za-z0-9_-]{1,19}$'),
  full_name        text not null check (char_length(full_name) between 1 and 80),
  phone            text check (phone is null or phone ~ '^\+?[0-9]{7,15}$'),
  contact_email    text check (contact_email is null or char_length(contact_email) <= 120),
  role             public.app_role not null default 'employee',
  is_active        boolean not null default true,
  -- One phone at a time: the device that is signed in now, or null.
  active_device_id text check (active_device_id is null or char_length(active_device_id) <= 100),
  created_by       uuid references public.profiles (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create unique index profiles_user_code_key on public.profiles (lower(user_code));
create index profiles_created_by_idx on public.profiles (created_by);
create trigger profiles_updated_at before update on public.profiles
  for each row execute function private.set_updated_at();

-- One row per employee per India day: the attendance record. Kept forever
-- (about 50 users x 365 days = 18k small rows a year).
create table public.duty_days (
  id             bigint generated always as identity primary key,
  user_id        uuid not null references public.profiles (id) on delete cascade,
  day            date not null,
  status         public.day_status not null,
  leave_type     public.leave_type,
  duty_on_at     timestamptz,
  duty_off_at    timestamptz,
  end_reason     public.duty_end_reason,
  worked_minutes integer check (worked_minutes is null or worked_minutes >= 0),
  distance_m     integer check (distance_m is null or distance_m >= 0),
  -- Where the status came from: auto (the rules), request, admin.
  status_source  text not null default 'auto'
                 check (status_source in ('auto', 'request', 'admin')),
  decided_by     uuid references public.profiles (id) on delete set null,
  decided_at     timestamptz,
  note           text check (note is null or char_length(note) <= 300),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (user_id, day),
  check (duty_off_at is null or duty_on_at is not null),
  check (duty_off_at is null or duty_off_at >= duty_on_at),
  check ((status = 'leave') = (leave_type is not null)),
  check (status <> 'on_duty' or (duty_on_at is not null and duty_off_at is null))
);
create index duty_days_day_idx on public.duty_days (day);
create index duty_days_open_idx on public.duty_days (day) where status = 'on_duty';
create index duty_days_decided_by_idx on public.duty_days (decided_by);
create trigger duty_days_updated_at before update on public.duty_days
  for each row execute function private.set_updated_at();

-- Raw GPS points. Kept 7 days only: the daily route is built from them into
-- day_routes. The primary key also removes duplicates from upload retries.
create table public.track_points (
  duty_day_id bigint not null references public.duty_days (id) on delete cascade,
  recorded_at timestamptz not null,
  lat_e6      integer not null check (lat_e6 between -90000000 and 90000000),
  lng_e6      integer not null check (lng_e6 between -180000000 and 180000000),
  accuracy_m  smallint check (accuracy_m is null or accuracy_m >= 0),
  battery     smallint check (battery is null or battery between 0 and 100),
  primary key (duty_day_id, recorded_at)
);
create index track_points_recorded_at_idx on public.track_points (recorded_at);

-- The day's route in compact form, built when duty ends. Kept 90 days.
-- segments: encoded polylines (Google format, 5 decimals), one per stretch
-- between phone-off gaps. stops: [{lat, lng, start, end}] for stays of
-- 15 minutes or more within 200 m. gaps: [{from, to}] when no point arrived
-- for more than 15 minutes (phone off).
create table public.day_routes (
  duty_day_id bigint primary key references public.duty_days (id) on delete cascade,
  day         date not null,
  segments    text[] not null default '{}',
  stops       jsonb not null default '[]',
  gaps        jsonb not null default '[]',
  point_count integer not null default 0,
  distance_m  integer not null default 0,
  built_at    timestamptz not null default now()
);
create index day_routes_day_idx on public.day_routes (day);

-- Latest position per user for the live map. One row per user, overwritten,
-- so it never grows.
create table public.live_positions (
  user_id     uuid primary key references public.profiles (id) on delete cascade,
  duty_day_id bigint references public.duty_days (id) on delete set null,
  lat_e6      integer not null,
  lng_e6      integer not null,
  accuracy_m  smallint,
  battery     smallint,
  recorded_at timestamptz not null,
  updated_at  timestamptz not null default now()
);
create index live_positions_duty_day_idx on public.live_positions (duty_day_id);

-- Attendance requests, leave requests and short-duty reviews.
create table public.requests (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  kind          public.request_kind not null,
  status        public.request_status not null default 'pending',
  -- attendance and short_duty: the day concerned.
  day           date,
  -- attendance: the times the user says they worked.
  duty_on_at    timestamptz,
  duty_off_at   timestamptz,
  -- leave: the type and the dates.
  leave_type    public.leave_type,
  dates         date[],
  message       text check (message is null or char_length(message) between 1 and 500),
  -- Cloudinary public ids. attendance: photo (required). leave: proof (optional).
  photo_id      text check (photo_id is null or char_length(photo_id) <= 200),
  -- The admin's decision.
  decision      public.day_status,
  decision_note text check (decision_note is null or char_length(decision_note) <= 300),
  decided_by    uuid references public.profiles (id) on delete set null,
  decided_at    timestamptz,
  created_at    timestamptz not null default now(),
  check (kind <> 'attendance' or (day is not null and duty_on_at is not null
         and duty_off_at > duty_on_at and message is not null and photo_id is not null)),
  check (kind <> 'leave' or (leave_type is not null and cardinality(dates) between 1 and 31
         and message is not null)),
  check (kind <> 'short_duty' or day is not null),
  check (decision is null or decision in ('present', 'half_day', 'absent', 'leave'))
);
create index requests_user_idx on public.requests (user_id, created_at desc);
create index requests_pending_idx on public.requests (created_at) where status = 'pending';
create index requests_decided_by_idx on public.requests (decided_by);
-- At most one pending request per user, kind and day.
create unique index requests_one_pending_per_day
  on public.requests (user_id, kind, day) where status = 'pending' and day is not null;

-- Visits (dealer photos). The id comes from the phone so a retried upload
-- does not create a second visit.
create table public.visits (
  id           uuid primary key,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  duty_day_id  bigint not null references public.duty_days (id) on delete cascade,
  store_name   text check (store_name is null or char_length(store_name) between 1 and 80),
  note         text check (note is null or char_length(note) between 1 and 300),
  from_gallery boolean not null,
  lat_e6       integer,
  lng_e6       integer,
  photo_id     text check (photo_id is null or char_length(photo_id) <= 200),
  photo_removed_at timestamptz,
  captured_at  timestamptz not null,
  created_at   timestamptz not null default now(),
  -- A camera photo has GPS; a gallery photo has none.
  check (from_gallery = (lat_e6 is null)),
  check ((lat_e6 is null) = (lng_e6 is null))
);
create index visits_user_idx on public.visits (user_id, captured_at desc);
create index visits_duty_day_idx on public.visits (duty_day_id);

-- Stop addresses, looked up from Google once per ~100 m cell and reused.
create table public.places (
  cell_lat   integer not null,
  cell_lng   integer not null,
  address    text not null check (char_length(address) <= 200),
  created_at timestamptz not null default now(),
  primary key (cell_lat, cell_lng)
);

create table public.notifications (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null check (char_length(kind) <= 40),
  title      text not null check (char_length(title) <= 120),
  body       text check (body is null or char_length(body) <= 300),
  data       jsonb not null default '{}',
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);
create index notifications_created_idx on public.notifications (created_at);

-- Every admin action, with who did it.
create table public.admin_log (
  id          bigint generated always as identity primary key,
  admin_id    uuid references public.profiles (id) on delete set null,
  action      text not null check (char_length(action) <= 60),
  target_user uuid references public.profiles (id) on delete set null,
  details     jsonb not null default '{}',
  created_at  timestamptz not null default now()
);
create index admin_log_created_idx on public.admin_log (created_at desc);
create index admin_log_admin_idx on public.admin_log (admin_id);
create index admin_log_target_idx on public.admin_log (target_user);

-- ---------------------------------------------------------------------------
-- Caller checks
-- ---------------------------------------------------------------------------

-- True when the caller is an active admin. Read from the table, not the
-- token, so deactivating an admin takes effect at once.
create function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin' and is_active
  );
$$;

create function private.require_admin() returns uuid
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  return auth.uid();
end;
$$;

create function private.require_employee() returns uuid
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'employee' and is_active
  ) then
    raise exception 'not_active_employee' using errcode = '42501';
  end if;
  return auth.uid();
end;
$$;

-- ---------------------------------------------------------------------------
-- Notifications and admin log
-- ---------------------------------------------------------------------------

create function private.notify(
  p_user uuid, p_kind text, p_title text, p_body text, p_data jsonb default '{}'
) returns void
language sql security definer set search_path = '' as $$
  insert into public.notifications (user_id, kind, title, body, data)
  values (p_user, p_kind, p_title, p_body, coalesce(p_data, '{}'));
$$;

create function private.notify_admins(
  p_kind text, p_title text, p_body text, p_data jsonb default '{}'
) returns void
language sql security definer set search_path = '' as $$
  insert into public.notifications (user_id, kind, title, body, data)
  select id, p_kind, p_title, p_body, coalesce(p_data, '{}')
  from public.profiles where role = 'admin' and is_active;
$$;

create function private.log_admin(
  p_action text, p_target uuid, p_details jsonb default '{}'
) returns void
language sql security definer set search_path = '' as $$
  insert into public.admin_log (admin_id, action, target_user, details)
  values (auth.uid(), p_action, p_target, coalesce(p_details, '{}'));
$$;

-- ---------------------------------------------------------------------------
-- Route building
-- ---------------------------------------------------------------------------

-- Google encoded polyline for one signed value delta (in 1e-5 degrees).
create function private.polyline_chunk(p_delta bigint) returns text
language plpgsql immutable set search_path = '' as $$
declare
  v bigint := p_delta << 1;
  out text := '';
begin
  if p_delta < 0 then
    v := ~v;
  end if;
  while v >= 32 loop
    out := out || chr(((32 | (v & 31)) + 63)::int);
    v := v >> 5;
  end loop;
  return out || chr((v + 63)::int);
end;
$$;

-- Builds the route of one duty day from its points: distance, stops, gaps
-- and encoded segments. Safe to run again (late offline uploads rebuild it).
create function private.build_route(p_day_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare
  c_max_accuracy constant integer := 50;     -- metres; worse points are ignored
  c_max_speed    constant double precision := 55;  -- m/s (~200 km/h): a jump
  c_min_move     constant double precision := 30;  -- metres; less is GPS jitter
  c_gap          constant interval := interval '15 minutes';
  c_stop_radius  constant double precision := 200;
  c_stop_min     constant interval := interval '15 minutes';

  p record;
  v_day date;
  v_count integer := 0;
  v_distance double precision := 0;

  -- previous accepted point
  v_prev_t timestamptz;
  v_prev_lat integer;
  v_prev_lng integer;
  -- anchor: last point that counted as movement
  v_anc_lat integer;
  v_anc_lng integer;

  -- polyline state for the current segment
  v_segments text[] := '{}';
  v_seg text := '';
  v_last_lat5 bigint;
  v_last_lng5 bigint;
  v_lat5 bigint;
  v_lng5 bigint;

  -- stop detection: the cluster being built
  v_cl_lat integer;
  v_cl_lng integer;
  v_cl_start timestamptz;
  v_cl_end timestamptz;
  v_cl_sum_lat bigint;
  v_cl_sum_lng bigint;
  v_cl_n integer;
  v_stops jsonb := '[]';
  v_gaps jsonb := '[]';
  d double precision;
begin
  select day into v_day from public.duty_days where id = p_day_id;
  if v_day is null then
    return;
  end if;

  for p in
    select recorded_at, lat_e6, lng_e6
    from public.track_points
    where duty_day_id = p_day_id
      and (accuracy_m is null or accuracy_m <= c_max_accuracy)
    order by recorded_at
  loop
    if v_prev_t is not null then
      d := private.dist_m(v_prev_lat, v_prev_lng, p.lat_e6, p.lng_e6);
      -- An impossible jump is a bad fix: skip the point.
      if p.recorded_at > v_prev_t
         and d / extract(epoch from p.recorded_at - v_prev_t) > c_max_speed
         and p.recorded_at - v_prev_t <= c_gap then
        continue;
      end if;

      if p.recorded_at - v_prev_t > c_gap then
        -- Phone off (or tracking stopped): close the stretch.
        v_gaps := v_gaps || jsonb_build_object('from', v_prev_t, 'to', p.recorded_at);
        if v_seg <> '' then
          v_segments := v_segments || v_seg;
        end if;
        v_seg := '';
        v_last_lat5 := null;
        v_anc_lat := null;
        -- A gap also ends the cluster.
        if v_cl_start is not null and v_cl_end - v_cl_start >= c_stop_min then
          v_stops := v_stops || jsonb_build_object(
            'lat', round(v_cl_sum_lat::numeric / v_cl_n) / 1e6,
            'lng', round(v_cl_sum_lng::numeric / v_cl_n) / 1e6,
            'start', v_cl_start, 'end', v_cl_end);
        end if;
        v_cl_start := null;
      end if;
    end if;

    v_count := v_count + 1;

    -- Distance: only real movement away from the last anchor counts.
    if v_anc_lat is null then
      v_anc_lat := p.lat_e6;
      v_anc_lng := p.lng_e6;
    else
      d := private.dist_m(v_anc_lat, v_anc_lng, p.lat_e6, p.lng_e6);
      if d >= c_min_move then
        v_distance := v_distance + d;
        v_anc_lat := p.lat_e6;
        v_anc_lng := p.lng_e6;
      end if;
    end if;

    -- Polyline: add the point if it moved at least 1e-5 degrees.
    v_lat5 := round(p.lat_e6 / 10.0);
    v_lng5 := round(p.lng_e6 / 10.0);
    if v_last_lat5 is null then
      v_seg := private.polyline_chunk(v_lat5) || private.polyline_chunk(v_lng5);
      v_last_lat5 := v_lat5;
      v_last_lng5 := v_lng5;
    elsif v_lat5 <> v_last_lat5 or v_lng5 <> v_last_lng5 then
      v_seg := v_seg || private.polyline_chunk(v_lat5 - v_last_lat5)
                     || private.polyline_chunk(v_lng5 - v_last_lng5);
      v_last_lat5 := v_lat5;
      v_last_lng5 := v_lng5;
    end if;

    -- Stops: grow the cluster while within 200 m of its first point.
    if v_cl_start is not null
       and private.dist_m(v_cl_lat, v_cl_lng, p.lat_e6, p.lng_e6) <= c_stop_radius then
      v_cl_end := p.recorded_at;
      v_cl_sum_lat := v_cl_sum_lat + p.lat_e6;
      v_cl_sum_lng := v_cl_sum_lng + p.lng_e6;
      v_cl_n := v_cl_n + 1;
    else
      if v_cl_start is not null and v_cl_end - v_cl_start >= c_stop_min then
        v_stops := v_stops || jsonb_build_object(
          'lat', round(v_cl_sum_lat::numeric / v_cl_n) / 1e6,
          'lng', round(v_cl_sum_lng::numeric / v_cl_n) / 1e6,
          'start', v_cl_start, 'end', v_cl_end);
      end if;
      v_cl_lat := p.lat_e6;
      v_cl_lng := p.lng_e6;
      v_cl_start := p.recorded_at;
      v_cl_end := p.recorded_at;
      v_cl_sum_lat := p.lat_e6;
      v_cl_sum_lng := p.lng_e6;
      v_cl_n := 1;
    end if;

    v_prev_t := p.recorded_at;
    v_prev_lat := p.lat_e6;
    v_prev_lng := p.lng_e6;
  end loop;

  if v_cl_start is not null and v_cl_end - v_cl_start >= c_stop_min then
    v_stops := v_stops || jsonb_build_object(
      'lat', round(v_cl_sum_lat::numeric / v_cl_n) / 1e6,
      'lng', round(v_cl_sum_lng::numeric / v_cl_n) / 1e6,
      'start', v_cl_start, 'end', v_cl_end);
  end if;
  if v_seg <> '' then
    v_segments := v_segments || v_seg;
  end if;

  insert into public.day_routes as r
    (duty_day_id, day, segments, stops, gaps, point_count, distance_m, built_at)
  values
    (p_day_id, v_day, v_segments, v_stops, v_gaps, v_count, round(v_distance), now())
  on conflict (duty_day_id) do update set
    segments = excluded.segments, stops = excluded.stops, gaps = excluded.gaps,
    point_count = excluded.point_count, distance_m = excluded.distance_m,
    built_at = excluded.built_at;

  update public.duty_days set distance_m = round(v_distance) where id = p_day_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Duty
-- ---------------------------------------------------------------------------

create function public.server_now() returns timestamptz
language sql stable set search_path = '' as $$
  select now();
$$;

-- Starts today's duty. Allowed 05:00 to 08:30 India time, once a day, not on
-- an approved leave day.
create function public.duty_on() returns public.duty_days
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_local timestamp := now() at time zone 'Asia/Kolkata';
  v_day date := v_local::date;
  v_row public.duty_days;
begin
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

-- Ends a duty: sets the time, builds the route, decides the status.
create function private.close_duty(
  p_day_id bigint, p_off_at timestamptz, p_reason public.duty_end_reason
) returns public.duty_days
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.duty_days;
  v_minutes integer;
begin
  select * into v_row from public.duty_days where id = p_day_id for update;
  if not found or v_row.status <> 'on_duty' then
    return v_row;
  end if;

  v_minutes := floor(extract(epoch from p_off_at - v_row.duty_on_at) / 60);
  perform private.build_route(p_day_id);

  update public.duty_days set
    duty_off_at = p_off_at,
    end_reason = p_reason,
    worked_minutes = v_minutes,
    status = case when v_minutes >= 600 then 'present' else 'pending' end::public.day_status
  where id = p_day_id
  returning * into v_row;

  if v_row.status = 'pending' then
    insert into public.requests (user_id, kind, day)
    values (v_row.user_id, 'short_duty', v_row.day);
    perform private.notify_admins(
      'short_duty', 'Short duty to review',
      (select full_name from public.profiles where id = v_row.user_id)
        || ' ended duty after ' || (v_minutes / 60) || ' h ' || (v_minutes % 60) || ' min',
      jsonb_build_object('user_id', v_row.user_id, 'day', v_row.day));
  end if;
  return v_row;
end;
$$;

-- Manual duty off. p_off_at is the app's server-clock time when the user
-- pressed duty off while offline; it is accepted only between duty on and
-- the earlier of now and 23:00. Without it, now is used.
create function public.duty_off(p_day_id bigint, p_off_at timestamptz default null)
returns public.duty_days
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_row public.duty_days;
  v_cap timestamptz;
begin
  select * into v_row from public.duty_days
  where id = p_day_id and user_id = v_uid;
  if not found then
    raise exception 'duty_not_found' using errcode = 'P0002';
  end if;
  if v_row.status <> 'on_duty' then
    raise exception 'duty_already_ended' using errcode = 'P0001';
  end if;

  v_cap := least(now(), private.auto_off_at(v_row.day));
  return private.close_duty(
    p_day_id,
    greatest(v_row.duty_on_at, least(coalesce(p_off_at, v_cap), v_cap)),
    'manual');
end;
$$;

-- Uploads a batch of points: [{"t": iso time, "la": lat_e6, "lo": lng_e6,
-- "a": accuracy m, "b": battery %}], at most 500 per call. Points outside the
-- duty, or in the future, are dropped. Duplicates are ignored. Returns the
-- number of points stored.
create function public.upload_points(p_day_id bigint, p_points jsonb)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_row public.duty_days;
  v_from timestamptz;
  v_to timestamptz;
  v_inserted integer;
  v_last record;
begin
  if jsonb_typeof(p_points) <> 'array' or jsonb_array_length(p_points) > 500 then
    raise exception 'invalid_points' using errcode = '22023';
  end if;
  select * into v_row from public.duty_days where id = p_day_id and user_id = v_uid;
  if not found or v_row.duty_on_at is null then
    raise exception 'duty_not_found' using errcode = 'P0002';
  end if;

  v_from := v_row.duty_on_at - interval '1 minute';
  v_to := least(coalesce(v_row.duty_off_at, private.auto_off_at(v_row.day)),
                now() + interval '2 minutes');

  with incoming as (
    select (e->>'t')::timestamptz as t,
           (e->>'la')::integer as la, (e->>'lo')::integer as lo,
           least((e->>'a')::numeric, 32767)::smallint as a,
           (e->>'b')::smallint as b
    from jsonb_array_elements(p_points) e
  ), ins as (
    insert into public.track_points (duty_day_id, recorded_at, lat_e6, lng_e6, accuracy_m, battery)
    select p_day_id, t, la, lo, a, b from incoming
    where t between v_from and v_to
      and la between -90000000 and 90000000
      and lo between -180000000 and 180000000
      and (b is null or b between 0 and 100)
      and (a is null or a >= 0)
    on conflict do nothing
    returning recorded_at, lat_e6, lng_e6, accuracy_m, battery
  )
  select count(*) into v_inserted from ins;

  if v_row.status = 'on_duty' then
    select recorded_at, lat_e6, lng_e6, accuracy_m, battery into v_last
    from public.track_points where duty_day_id = p_day_id
    order by recorded_at desc limit 1;
    if found then
      insert into public.live_positions as lp
        (user_id, duty_day_id, lat_e6, lng_e6, accuracy_m, battery, recorded_at, updated_at)
      values (v_uid, p_day_id, v_last.lat_e6, v_last.lng_e6, v_last.accuracy_m,
              v_last.battery, v_last.recorded_at, now())
      on conflict (user_id) do update set
        duty_day_id = excluded.duty_day_id, lat_e6 = excluded.lat_e6,
        lng_e6 = excluded.lng_e6, accuracy_m = excluded.accuracy_m,
        battery = excluded.battery, recorded_at = excluded.recorded_at,
        updated_at = now()
      where lp.recorded_at <= excluded.recorded_at;
    end if;
  elsif v_inserted > 0 then
    -- Offline points that arrived after duty ended: rebuild the route.
    perform private.build_route(p_day_id);
  end if;

  return v_inserted;
end;
$$;

-- ---------------------------------------------------------------------------
-- Requests
-- ---------------------------------------------------------------------------

-- Forgot to duty on: ask for attendance on a day (today or up to 7 days
-- back) with the times worked, a message and a photo.
create function public.request_attendance(
  p_day date, p_duty_on time, p_duty_off time, p_message text, p_photo_id text
) returns public.requests
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_today date := private.ist_today();
  v_row public.requests;
begin
  if p_day > v_today or p_day < v_today - 7 then
    raise exception 'outside_request_window' using errcode = 'P0001';
  end if;
  if p_duty_off <= p_duty_on then
    raise exception 'invalid_times' using errcode = '22023';
  end if;
  if private.ist_at(p_day, p_duty_off) > now() then
    raise exception 'invalid_times' using errcode = '22023';
  end if;
  if exists (select 1 from public.duty_days
             where user_id = v_uid and day = p_day and duty_on_at is not null) then
    raise exception 'already_has_duty' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.requests where user_id = v_uid and kind = 'attendance'
             and day = p_day and status = 'pending') then
    raise exception 'already_requested' using errcode = 'P0001';
  end if;

  insert into public.requests (user_id, kind, day, duty_on_at, duty_off_at, message, photo_id)
  values (v_uid, 'attendance', p_day, private.ist_at(p_day, p_duty_on),
          private.ist_at(p_day, p_duty_off), nullif(trim(p_message), ''),
          nullif(trim(p_photo_id), ''))
  returning * into v_row;

  perform private.notify_admins(
    'attendance_request', 'Attendance request',
    (select full_name from public.profiles where id = v_uid)
      || ' asked for attendance on ' || to_char(p_day, 'DD Mon YYYY'),
    jsonb_build_object('request_id', v_row.id));
  return v_row;
end;
$$;

create function public.request_leave(
  p_type public.leave_type, p_dates date[], p_message text, p_proof_id text default null
) returns public.requests
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_dates date[];
  v_row public.requests;
begin
  select array_agg(distinct d order by d) into v_dates from unnest(p_dates) d;
  if v_dates is null or cardinality(v_dates) > 31 then
    raise exception 'invalid_dates' using errcode = '22023';
  end if;
  if v_dates[1] < private.ist_today() - 7 then
    raise exception 'outside_request_window' using errcode = 'P0001';
  end if;

  insert into public.requests (user_id, kind, leave_type, dates, message, photo_id)
  values (v_uid, 'leave', p_type, v_dates, nullif(trim(p_message), ''),
          nullif(trim(p_proof_id), ''))
  returning * into v_row;

  perform private.notify_admins(
    'leave_request', 'Leave request',
    (select full_name from public.profiles where id = v_uid) || ' asked for '
      || cardinality(v_dates) || ' day(s) of ' || p_type || ' leave',
    jsonb_build_object('request_id', v_row.id));
  return v_row;
end;
$$;

create function public.cancel_request(p_request_id bigint) returns public.requests
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_row public.requests;
begin
  update public.requests set status = 'cancelled'
  where id = p_request_id and user_id = v_uid and status = 'pending'
    and kind in ('attendance', 'leave')
  returning * into v_row;
  if not found then
    raise exception 'request_not_cancellable' using errcode = 'P0001';
  end if;
  return v_row;
end;
$$;

-- Writes a day's status as an admin decision.
create function private.put_day(
  p_user uuid, p_day date, p_status public.day_status, p_source text,
  p_leave public.leave_type default null, p_note text default null,
  p_on timestamptz default null, p_off timestamptz default null
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.duty_days as dd
    (user_id, day, status, leave_type, status_source, decided_by, decided_at, note,
     duty_on_at, duty_off_at, worked_minutes)
  values
    (p_user, p_day, p_status, p_leave, p_source, auth.uid(), now(), p_note,
     p_on, p_off,
     case when p_on is not null then floor(extract(epoch from p_off - p_on) / 60) end)
  on conflict (user_id, day) do update set
    status = excluded.status,
    leave_type = excluded.leave_type,
    status_source = excluded.status_source,
    decided_by = excluded.decided_by,
    decided_at = excluded.decided_at,
    note = coalesce(excluded.note, dd.note),
    duty_on_at = coalesce(excluded.duty_on_at, dd.duty_on_at),
    duty_off_at = coalesce(excluded.duty_off_at, dd.duty_off_at),
    worked_minutes = coalesce(excluded.worked_minutes, dd.worked_minutes);
end;
$$;

-- The admin decides a request.
--   attendance: p_decision present or half_day approves, absent rejects.
--   leave:      p_decision leave approves, absent rejects (days are unchanged).
--   short_duty: p_decision present, half_day or absent.
create function public.decide_request(
  p_request_id bigint, p_decision public.day_status, p_note text default null
) returns public.requests
language plpgsql security definer set search_path = '' as $$
declare
  v_admin uuid := private.require_admin();
  v_req public.requests;
  v_approved boolean;
  v_day date;
  v_title text;
begin
  select * into v_req from public.requests where id = p_request_id for update;
  if not found then
    raise exception 'request_not_found' using errcode = 'P0002';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'request_already_decided' using errcode = 'P0001';
  end if;

  if v_req.kind = 'attendance' then
    if p_decision not in ('present', 'half_day', 'absent') then
      raise exception 'invalid_decision' using errcode = '22023';
    end if;
    v_approved := p_decision <> 'absent';
    if v_approved then
      perform private.put_day(v_req.user_id, v_req.day, p_decision, 'request',
                              null, p_note, v_req.duty_on_at, v_req.duty_off_at);
    else
      perform private.put_day(v_req.user_id, v_req.day, 'absent', 'request', null, p_note);
    end if;
    v_title := case when v_approved then 'Attendance approved' else 'Attendance rejected' end;

  elsif v_req.kind = 'leave' then
    if p_decision not in ('leave', 'absent') then
      raise exception 'invalid_decision' using errcode = '22023';
    end if;
    v_approved := p_decision = 'leave';
    if v_approved then
      foreach v_day in array v_req.dates loop
        -- A day already worked keeps its duty.
        if not exists (select 1 from public.duty_days where user_id = v_req.user_id
                       and day = v_day and duty_on_at is not null) then
          perform private.put_day(v_req.user_id, v_day, 'leave', 'request',
                                  v_req.leave_type, p_note);
        end if;
      end loop;
    end if;
    v_title := case when v_approved then 'Leave approved' else 'Leave rejected' end;

  else -- short_duty
    if p_decision not in ('present', 'half_day', 'absent') then
      raise exception 'invalid_decision' using errcode = '22023';
    end if;
    v_approved := p_decision <> 'absent';
    update public.duty_days set status = p_decision, status_source = 'admin',
      decided_by = v_admin, decided_at = now(), note = coalesce(p_note, note)
    where user_id = v_req.user_id and day = v_req.day;
    v_title := 'Short duty marked ' || replace(p_decision::text, '_', ' ');
  end if;

  update public.requests set
    status = case when v_approved then 'approved' else 'rejected' end::public.request_status,
    decision = p_decision, decision_note = p_note,
    decided_by = v_admin, decided_at = now()
  where id = p_request_id
  returning * into v_req;

  perform private.notify(v_req.user_id, 'request_decided', v_title, p_note,
                         jsonb_build_object('request_id', v_req.id));
  perform private.log_admin('decide_request', v_req.user_id,
    jsonb_build_object('request_id', v_req.id, 'kind', v_req.kind, 'decision', p_decision));
  return v_req;
end;
$$;

-- Admin override of any day's status (for example mark absent). Logged with
-- the previous status, so it can be undone by setting it back.
create function public.set_day_status(
  p_user uuid, p_day date, p_status public.day_status,
  p_leave public.leave_type default null, p_note text default null
) returns public.duty_days
language plpgsql security definer set search_path = '' as $$
declare
  v_admin uuid := private.require_admin();
  v_before public.day_status;
  v_row public.duty_days;
begin
  if p_status in ('on_duty', 'pending') then
    raise exception 'invalid_decision' using errcode = '22023';
  end if;
  if (p_status = 'leave') <> (p_leave is not null) then
    raise exception 'invalid_decision' using errcode = '22023';
  end if;
  if not exists (select 1 from public.profiles where id = p_user and role = 'employee') then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
  if p_day > private.ist_today() then
    raise exception 'future_day' using errcode = 'P0001';
  end if;
  select status into v_before from public.duty_days where user_id = p_user and day = p_day;
  if v_before = 'on_duty' then
    raise exception 'duty_running' using errcode = 'P0001';
  end if;

  perform private.put_day(p_user, p_day, p_status, 'admin', p_leave, p_note);
  select * into v_row from public.duty_days where user_id = p_user and day = p_day;
  perform private.log_admin('set_day_status', p_user, jsonb_build_object(
    'day', p_day, 'from', v_before, 'to', p_status, 'note', p_note));
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- Visits and notifications
-- ---------------------------------------------------------------------------

create function public.add_visit(
  p_id uuid, p_store_name text, p_note text, p_from_gallery boolean,
  p_lat_e6 integer, p_lng_e6 integer, p_photo_id text, p_captured_at timestamptz
) returns public.visits
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_day public.duty_days;
  v_row public.visits;
begin
  select * into v_day from public.duty_days
  where user_id = v_uid and day = private.ist_today() and status = 'on_duty';
  if not found then
    raise exception 'not_on_duty' using errcode = 'P0001';
  end if;
  insert into public.visits (id, user_id, duty_day_id, store_name, note, from_gallery,
                             lat_e6, lng_e6, photo_id, captured_at)
  values (p_id, v_uid, v_day.id, nullif(trim(p_store_name), ''), nullif(trim(p_note), ''),
          p_from_gallery,
          case when p_from_gallery then null else p_lat_e6 end,
          case when p_from_gallery then null else p_lng_e6 end,
          nullif(trim(p_photo_id), ''),
          least(greatest(p_captured_at, v_day.duty_on_at), now()))
  on conflict (id) do nothing;
  select * into v_row from public.visits where id = p_id and user_id = v_uid;
  return v_row;
end;
$$;

create function public.mark_notifications_read(p_ids bigint[] default null)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_count integer;
begin
  update public.notifications set read_at = now()
  where user_id = (select auth.uid()) and read_at is null
    and (p_ids is null or id = any (p_ids));
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Scheduled jobs (run by pg_cron, see the end of this file)
-- ---------------------------------------------------------------------------

-- 23:00 India time: close every open duty at 23:00 of its day.
create function private.auto_duty_off() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  n integer := 0;
begin
  for r in
    select id, day from public.duty_days
    where status = 'on_duty' and private.auto_off_at(day) <= now()
  loop
    perform private.close_duty(r.id, private.auto_off_at(r.day), 'auto');
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- After 23:00: every active employee with nothing recorded for the day is
-- absent. Pending attendance requests can still turn it into present.
create function private.mark_absent(p_day date default null) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_day date := coalesce(p_day, private.ist_today());
  n integer;
begin
  insert into public.duty_days (user_id, day, status, status_source)
  select p.id, v_day, 'absent', 'auto'
  from public.profiles p
  where p.role = 'employee' and p.is_active
    and (p.created_at at time zone 'Asia/Kolkata')::date <= v_day
  on conflict (user_id, day) do nothing;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- Nightly: drop raw points after 7 days, routes after 90, notifications after
-- 60, and finished live positions. Visit photos are deleted from Cloudinary by
-- an Edge Function (phase 7), which then sets photo_removed_at.
create function private.cleanup() returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.track_points where recorded_at < now() - interval '7 days';
  delete from public.day_routes where day < private.ist_today() - 90;
  delete from public.notifications where created_at < now() - interval '60 days';
  delete from public.live_positions lp
  where not exists (select 1 from public.duty_days d
                    where d.id = lp.duty_day_id and d.status = 'on_duty')
    and lp.updated_at < now() - interval '1 day';
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.duty_days enable row level security;
alter table public.track_points enable row level security;
alter table public.day_routes enable row level security;
alter table public.live_positions enable row level security;
alter table public.requests enable row level security;
alter table public.visits enable row level security;
alter table public.places enable row level security;
alter table public.notifications enable row level security;
alter table public.admin_log enable row level security;

-- Reads: each user sees their own rows, admins see everything.
create policy own_or_admin on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select private.is_admin()));
create policy own_or_admin on public.duty_days for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));
create policy own_or_admin on public.track_points for select to authenticated
  using ((select private.is_admin()) or exists (
    select 1 from public.duty_days d
    where d.id = duty_day_id and d.user_id = (select auth.uid())));
create policy own_or_admin on public.day_routes for select to authenticated
  using ((select private.is_admin()) or exists (
    select 1 from public.duty_days d
    where d.id = duty_day_id and d.user_id = (select auth.uid())));
create policy own_or_admin on public.live_positions for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));
create policy own_or_admin on public.requests for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));
create policy own_or_admin on public.visits for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));
create policy signed_in on public.places for select to authenticated
  using (true);
create policy own on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));
create policy admin_only on public.admin_log for select to authenticated
  using ((select private.is_admin()));

-- Grants: read-only tables for signed-in users, nothing for anonymous
-- visitors. Supabase grants everything on new tables by default; take it back.
revoke all on all tables in schema public from anon, authenticated;
grant select on all tables in schema public to authenticated;
revoke all on all sequences in schema public from anon, authenticated;

revoke all on all functions in schema public from public, anon, authenticated;
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function
  public.server_now(),
  public.duty_on(),
  public.duty_off(bigint, timestamptz),
  public.upload_points(bigint, jsonb),
  public.request_attendance(date, time, time, text, text),
  public.request_leave(public.leave_type, date[], text, text),
  public.cancel_request(bigint),
  public.decide_request(bigint, public.day_status, text),
  public.set_day_status(uuid, date, public.day_status, public.leave_type, text),
  public.add_visit(uuid, text, text, boolean, integer, integer, text, timestamptz),
  public.mark_notifications_read(bigint[])
to authenticated;
-- Policies call this one.
grant execute on function private.is_admin() to authenticated;
grant execute on all functions in schema private to service_role;
grant execute on all functions in schema public to service_role;

-- New functions must be granted on purpose.
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
alter default privileges in schema private revoke execute on functions from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Realtime: the admin's live map listens to live_positions (row-level
-- security still applies to what each listener receives).
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.live_positions;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Schedules (UTC; India is UTC+05:30)
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    -- Every 10 minutes from 22:30 to 00:20 IST. Only duties already past
    -- 23:00 are closed, so the early runs do nothing and the later ones are a
    -- safety net if a run is missed.
    perform cron.schedule('auto-duty-off', '*/10 17-18 * * *',
      'select private.auto_duty_off()');
    -- 23:15 IST.
    perform cron.schedule('mark-absent', '45 17 * * *',
      'select private.mark_absent()');
    -- 02:30 IST.
    perform cron.schedule('nightly-cleanup', '0 21 * * *',
      'select private.cleanup()');
  end if;
end;
$$;
