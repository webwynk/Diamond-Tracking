-- Phase 4: duty and tracking.
--
-- The phone's tracker runs in an Android foreground service, in its own
-- Flutter engine. If it refreshed the sign-in session itself, the app and the
-- tracker would both rotate the same refresh token and Supabase would revoke
-- the session. So the tracker never uses the session: at duty on the phone
-- gets an upload pass for that one duty day, and uploads points with it.
--
-- The pass is 32 random bytes, stored only as a SHA-256 hash, tied to one
-- duty day and the phone that started it. It can only add points to that day
-- (and record phone-off times), and it stops working 2 days after the day's
-- 11 PM or when the admin resets the password.

-- ---------------------------------------------------------------------------
-- Upload passes
-- ---------------------------------------------------------------------------

create table private.upload_passes (
  duty_day_id bigint primary key references public.duty_days (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  device_id   text not null,
  pass_hash   bytea not null,
  expires_at  timestamptz not null,
  created_at  timestamptz not null default now()
);
create index upload_passes_user_idx on private.upload_passes (user_id);

-- Makes a new pass for a duty day (replacing any earlier one) and returns it.
create function private.new_upload_pass(p_day public.duty_days, p_device_id text)
returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_pass text := encode(extensions.gen_random_bytes(32), 'hex');
begin
  insert into private.upload_passes (duty_day_id, user_id, device_id, pass_hash, expires_at)
  values (p_day.id, p_day.user_id, p_device_id,
          extensions.digest(v_pass, 'sha256'),
          private.auto_off_at(p_day.day) + interval '2 days')
  on conflict (duty_day_id) do update set
    device_id = excluded.device_id, pass_hash = excluded.pass_hash,
    expires_at = excluded.expires_at, created_at = now();
  return v_pass;
end;
$$;

-- The user behind a valid pass for a duty day, or an error.
create function private.check_upload_pass(p_day_id bigint, p_pass text) returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid;
begin
  select u.user_id into v_uid
  from private.upload_passes u
  join public.profiles p on p.id = u.user_id
  where u.duty_day_id = p_day_id
    and u.pass_hash = extensions.digest(coalesce(p_pass, ''), 'sha256')
    and u.expires_at > now()
    and p.is_active
    and p.active_device_id = u.device_id;
  if v_uid is null then
    raise exception 'invalid_upload_pass' using errcode = '42501';
  end if;
  return v_uid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Duty on / resume: both return {"day": duty_days row, "upload_pass": text}
-- ---------------------------------------------------------------------------

drop function public.duty_on(text);
create function public.duty_on(p_device_id text) returns jsonb
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
  return jsonb_build_object('day', to_jsonb(v_row),
                            'upload_pass', private.new_upload_pass(v_row, p_device_id));
end;
$$;

-- Today's duty is on but this phone has no pass (app data cleared, or the
-- app was reinstalled and the admin reset the password): a new pass for the
-- phone that holds the account. Before 11 PM only.
create function public.duty_resume(p_device_id text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_row public.duty_days;
begin
  perform private.require_device(v_uid, p_device_id);
  select * into v_row from public.duty_days
  where user_id = v_uid and day = private.ist_today() and status = 'on_duty';
  if not found or now() >= private.auto_off_at(v_row.day) then
    raise exception 'not_on_duty' using errcode = 'P0001';
  end if;
  return jsonb_build_object('day', to_jsonb(v_row),
                            'upload_pass', private.new_upload_pass(v_row, p_device_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- Points
-- ---------------------------------------------------------------------------

-- Stores a batch of points for a user's duty day: [{"t": iso time,
-- "la": lat_e6, "lo": lng_e6, "a": accuracy m, "b": battery %}], at most 500.
-- Points outside the duty, or in the future, are dropped; duplicates are
-- ignored. Updates the live position while on duty, or rebuilds the route
-- when late points arrive after duty ended. Returns the number stored.
create function private.store_points(p_uid uuid, p_day_id bigint, p_points jsonb)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.duty_days;
  v_from timestamptz;
  v_to timestamptz;
  v_inserted integer;
  v_last record;
begin
  if p_points is null or jsonb_typeof(p_points) <> 'array'
     or jsonb_array_length(p_points) > 500 then
    raise exception 'invalid_points' using errcode = '22023';
  end if;
  select * into v_row from public.duty_days where id = p_day_id and user_id = p_uid;
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
    returning recorded_at
  )
  select count(*) into v_inserted from ins;

  if v_row.status = 'on_duty' then
    select recorded_at, lat_e6, lng_e6, accuracy_m, battery into v_last
    from public.track_points where duty_day_id = p_day_id
    order by recorded_at desc limit 1;
    if found then
      insert into public.live_positions as lp
        (user_id, duty_day_id, lat_e6, lng_e6, accuracy_m, battery, recorded_at, updated_at)
      values (p_uid, p_day_id, v_last.lat_e6, v_last.lng_e6, v_last.accuracy_m,
              v_last.battery, v_last.recorded_at, now())
      on conflict (user_id) do update set
        duty_day_id = excluded.duty_day_id, lat_e6 = excluded.lat_e6,
        lng_e6 = excluded.lng_e6, accuracy_m = excluded.accuracy_m,
        battery = excluded.battery, recorded_at = excluded.recorded_at,
        updated_at = now()
      where lp.recorded_at <= excluded.recorded_at;
    end if;
  elsif v_inserted > 0 then
    perform private.build_route(p_day_id);
  end if;

  return v_inserted;
end;
$$;

-- Signed-in upload (from the app screen), from the phone holding the account.
drop function public.upload_points(bigint, jsonb, text);
drop function private.upload_points_unchecked(bigint, jsonb);
create function public.upload_points(p_day_id bigint, p_points jsonb, p_device_id text)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
begin
  perform private.require_device(v_uid, p_device_id);
  return private.store_points(v_uid, p_day_id, p_points);
end;
$$;

-- The tracker's upload, with the day's pass instead of a session.
create function public.upload_points_with_pass(
  p_day_id bigint, p_pass text, p_points jsonb
) returns integer
language plpgsql security definer set search_path = '' as $$
begin
  return private.store_points(private.check_upload_pass(p_day_id, p_pass), p_day_id, p_points);
end;
$$;

-- ---------------------------------------------------------------------------
-- Tracking breaks: the phone was switched off, or the tracker was stopped by
-- the phone (battery saver). The route view shows them on the gap.
-- ---------------------------------------------------------------------------

create type public.duty_break_kind as enum ('phone_off', 'tracking_stopped');

create table public.duty_breaks (
  duty_day_id bigint not null references public.duty_days (id) on delete cascade,
  started_at  timestamptz not null,
  ended_at    timestamptz not null,
  kind        public.duty_break_kind not null,
  primary key (duty_day_id, started_at),
  check (ended_at > started_at)
);

alter table public.duty_breaks enable row level security;
create policy own_or_admin on public.duty_breaks for select to authenticated
  using ((select private.is_admin()) or exists (
    select 1 from public.duty_days d
    where d.id = duty_day_id and d.user_id = (select auth.uid())));

-- Records a break, clipped to the duty. Repeats are ignored.
create function public.report_break_with_pass(
  p_day_id bigint, p_pass text, p_from timestamptz, p_to timestamptz,
  p_kind public.duty_break_kind
) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.check_upload_pass(p_day_id, p_pass);
  v_row public.duty_days;
  v_from timestamptz;
  v_to timestamptz;
begin
  select * into v_row from public.duty_days where id = p_day_id and user_id = v_uid;
  v_from := greatest(p_from, v_row.duty_on_at);
  v_to := least(p_to, coalesce(v_row.duty_off_at, private.auto_off_at(v_row.day)),
                now() + interval '2 minutes');
  if v_from is null or v_to is null or v_to - v_from < interval '1 minute' then
    return false;
  end if;
  insert into public.duty_breaks (duty_day_id, started_at, ended_at, kind)
  values (p_day_id, v_from, v_to, p_kind)
  on conflict do nothing;
  return found;
end;
$$;

-- ---------------------------------------------------------------------------
-- Duty off pressed while offline: the tracker sends it when the internet is
-- back, with the time the button was pressed.
-- ---------------------------------------------------------------------------

-- If the 11 PM automatic duty off got there first, the day is corrected to
-- the real duty-off time (an automatic close is always a full day, so no
-- review request exists yet). A day already ended by hand, or already
-- decided by the admin, is left as it is.
create function public.duty_off_with_pass(
  p_day_id bigint, p_pass text, p_off_at timestamptz
) returns public.day_status
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.check_upload_pass(p_day_id, p_pass);
  v_row public.duty_days;
  v_cap timestamptz;
begin
  select * into v_row from public.duty_days
  where id = p_day_id and user_id = v_uid for update;
  v_cap := least(now(), private.auto_off_at(v_row.day));
  if v_row.status = 'present' and v_row.end_reason = 'auto'
     and v_row.status_source = 'auto' and p_off_at < v_row.duty_off_at then
    update public.duty_days set
      status = 'on_duty', duty_off_at = null, end_reason = null, worked_minutes = null
    where id = p_day_id;
  elsif v_row.status <> 'on_duty' then
    return v_row.status;
  end if;
  v_row := private.close_duty(
    p_day_id, greatest(v_row.duty_on_at, least(coalesce(p_off_at, v_cap), v_cap)), 'manual');
  return v_row.status;
end;
$$;

-- ---------------------------------------------------------------------------
-- Password reset and cleanup also end upload passes
-- ---------------------------------------------------------------------------

create or replace function private.revoke_sessions(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from auth.sessions where user_id = p_user;
  delete from private.upload_passes where user_id = p_user;
  update public.profiles set active_device_id = null where id = p_user;
end;
$$;

create or replace function private.cleanup() returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.track_points where recorded_at < now() - interval '7 days';
  delete from public.day_routes where day < private.ist_today() - 90;
  delete from public.duty_breaks b using public.duty_days d
  where d.id = b.duty_day_id and d.day < private.ist_today() - 90;
  delete from public.notifications where created_at < now() - interval '60 days';
  delete from public.live_positions lp
  where not exists (select 1 from public.duty_days d
                    where d.id = lp.duty_day_id and d.status = 'on_duty')
    and lp.updated_at < now() - interval '1 day';
  delete from private.password_reset_codes where expires_at < now() - interval '1 day';
  delete from private.upload_passes where expires_at < now();
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on private.upload_passes from public, anon, authenticated;
revoke all on public.duty_breaks from public, anon, authenticated;
grant select on public.duty_breaks to authenticated;

revoke all on all functions in schema public from public, anon, authenticated;
revoke all on all functions in schema private from public, anon, authenticated;

grant execute on function
  public.server_now(),
  public.duty_on(text),
  public.duty_resume(text),
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

-- The tracker has no session: these check the pass themselves.
grant execute on function
  public.upload_points_with_pass(bigint, text, jsonb),
  public.duty_off_with_pass(bigint, text, timestamptz),
  public.report_break_with_pass(bigint, text, timestamptz, timestamptz, public.duty_break_kind)
to anon, authenticated;

grant execute on all functions in schema public to service_role;
grant execute on all functions in schema private to service_role;
