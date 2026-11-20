-- Phase 6: requests and notifications.
--
-- The request functions exist since the baseline. This adds:
--   * Photo ids are checked: only ids the photos function hands out
--     ("req-<uuid>") are accepted, so no other Cloudinary path can be named.
--   * Phone push: each phone registers its Firebase token. Every new
--     notification row asks the push function to send it, once.
--   * Notifications are sent live to the app (realtime), for the badge.

-- ---------------------------------------------------------------------------
-- Settings the database needs to know (set per project, not in migrations)
-- ---------------------------------------------------------------------------

create table private.app_settings (
  key   text primary key,
  value text not null
);
-- push_url: the push function's address, for example
--   https://<project>.supabase.co/functions/v1/push
-- With no push_url, notifications only show inside the app.

-- ---------------------------------------------------------------------------
-- Photo ids
-- ---------------------------------------------------------------------------

create function private.valid_photo_id(p_id text) returns boolean
language sql immutable set search_path = '' as $$
  select p_id ~ '^req-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
$$;

create or replace function public.request_attendance(
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
  if nullif(trim(p_message), '') is null then
    raise exception 'message_required' using errcode = '22023';
  end if;
  if p_photo_id is null or not private.valid_photo_id(p_photo_id) then
    raise exception 'photo_required' using errcode = '22023';
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
          private.ist_at(p_day, p_duty_off), trim(p_message), p_photo_id)
  returning * into v_row;

  perform private.notify_admins(
    'attendance_request', 'Attendance request',
    (select full_name from public.profiles where id = v_uid)
      || ' asked for attendance on ' || to_char(p_day, 'DD Mon YYYY'),
    jsonb_build_object('request_id', v_row.id));
  return v_row;
end;
$$;

create or replace function public.request_leave(
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
  if v_dates[cardinality(v_dates)] > private.ist_today() + 90 then
    raise exception 'invalid_dates' using errcode = '22023';
  end if;
  if nullif(trim(p_message), '') is null then
    raise exception 'message_required' using errcode = '22023';
  end if;
  if nullif(trim(p_proof_id), '') is not null and not private.valid_photo_id(p_proof_id) then
    raise exception 'invalid_photo' using errcode = '22023';
  end if;
  -- Overlapping a leave request still waiting would make two decisions for a day.
  if exists (select 1 from public.requests where user_id = v_uid and kind = 'leave'
             and status = 'pending' and dates && v_dates) then
    raise exception 'already_requested' using errcode = 'P0001';
  end if;

  insert into public.requests (user_id, kind, leave_type, dates, message, photo_id)
  values (v_uid, 'leave', p_type, v_dates, trim(p_message), nullif(trim(p_proof_id), ''))
  returning * into v_row;

  perform private.notify_admins(
    'leave_request', 'Leave request',
    (select full_name from public.profiles where id = v_uid) || ' asked for '
      || cardinality(v_dates) || ' day(s) of ' || p_type || ' leave from '
      || to_char(v_dates[1], 'DD Mon'),
    jsonb_build_object('request_id', v_row.id));
  return v_row;
end;
$$;

-- The photos function asks whose photo a request has before showing it.
create function public.svc_request_photo(p_request_id bigint, p_caller uuid)
returns text
language plpgsql stable security definer set search_path = '' as $$
declare
  v_req public.requests;
begin
  select * into v_req from public.requests where id = p_request_id;
  if not found then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if v_req.user_id <> p_caller and not exists (
    select 1 from public.profiles where id = p_caller and role = 'admin' and is_active
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  return v_req.photo_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- The short-duty alert names its request, so a tap opens it.
-- ---------------------------------------------------------------------------

create or replace function private.close_duty(
  p_day_id bigint, p_off_at timestamptz, p_reason public.duty_end_reason
) returns public.duty_days
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.duty_days;
  v_minutes integer;
  v_request bigint;
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
    values (v_row.user_id, 'short_duty', v_row.day)
    returning id into v_request;
    perform private.notify_admins(
      'short_duty', 'Short duty to review',
      (select full_name from public.profiles where id = v_row.user_id)
        || ' ended duty after ' || (v_minutes / 60) || ' h ' || (v_minutes % 60) || ' min',
      jsonb_build_object('user_id', v_row.user_id, 'day', v_row.day, 'request_id', v_request));
  end if;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- Push tokens
-- ---------------------------------------------------------------------------

create table private.push_tokens (
  token      text primary key check (char_length(token) between 20 and 4096),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  device_id  text not null check (char_length(device_id) between 8 and 100),
  updated_at timestamptz not null default now()
);
create index push_tokens_user_idx on private.push_tokens (user_id);

-- The app calls this after sign-in and whenever Firebase gives a new token.
-- A token belongs to one phone; signing in as someone else moves it.
create function public.set_push_token(p_device_id text, p_token text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or not exists (
    select 1 from public.profiles where id = v_uid and is_active
  ) then
    raise exception 'account_inactive' using errcode = '42501';
  end if;
  if p_token is null or char_length(p_token) not between 20 and 4096
     or p_device_id is null or char_length(p_device_id) not between 8 and 100 then
    raise exception 'invalid_token' using errcode = '22023';
  end if;
  -- One token per phone and user: an old token of this phone goes.
  delete from private.push_tokens
  where user_id = v_uid and device_id = p_device_id and token <> p_token;
  insert into private.push_tokens (token, user_id, device_id)
  values (p_token, v_uid, p_device_id)
  on conflict (token) do update set
    user_id = excluded.user_id, device_id = excluded.device_id, updated_at = now();
end;
$$;

-- On logout, before the session ends.
create function public.clear_push_token(p_token text) returns void
language sql security definer set search_path = '' as $$
  delete from private.push_tokens where token = p_token and user_id = (select auth.uid());
$$;

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------

alter table public.notifications add column pushed_at timestamptz;

-- The push function claims a notification once: the first call gets its text
-- and the phones to send to, every later call gets nothing. So the function
-- needs no secret: a caller can only cause a push that was going to happen.
-- An employee's push goes only to the phone that holds the account.
create function public.svc_claim_push(p_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_n public.notifications;
  v_tokens text[];
begin
  update public.notifications set pushed_at = now()
  where id = p_id and pushed_at is null and created_at > now() - interval '1 hour'
  returning * into v_n;
  if not found then
    return null;
  end if;
  select coalesce(array_agg(t.token), '{}') into v_tokens
  from private.push_tokens t
  join public.profiles p on p.id = t.user_id
  where t.user_id = v_n.user_id and p.is_active
    and (p.role = 'admin' or t.device_id = p.active_device_id);
  return jsonb_build_object(
    'title', v_n.title, 'body', v_n.body, 'kind', v_n.kind,
    'data', v_n.data || jsonb_build_object('notification_id', v_n.id),
    'tokens', to_jsonb(v_tokens));
end;
$$;

-- Firebase said these tokens are gone (app removed, data cleared).
create function public.svc_drop_push_tokens(p_tokens text[]) returns void
language sql security definer set search_path = '' as $$
  delete from private.push_tokens where token = any (p_tokens);
$$;

-- Each new notification asks the push function to send it. pg_net sends the
-- request after the transaction commits and never blocks or fails the insert.
create function private.push_notification() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_url text;
begin
  select value into v_url from private.app_settings where key = 'push_url';
  if v_url is null or to_regnamespace('net') is null then
    return null;
  end if;
  perform net.http_post(
    url := v_url,
    body := jsonb_build_object('id', new.id),
    headers := jsonb_build_object('content-type', 'application/json'),
    timeout_milliseconds := 10000);
  return null;
exception when others then
  -- A push is a courtesy; the notification itself must always be saved.
  return null;
end;
$$;

create trigger push_notification
  after insert on public.notifications
  for each row execute function private.push_notification();

-- Old push tokens (a phone not opened in 60 days) go in the nightly cleanup.
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
  delete from private.push_tokens where updated_at < now() - interval '60 days';
end;
$$;

-- ---------------------------------------------------------------------------
-- Realtime: the app's notification badge listens to its own rows.
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and schemaname = 'public'
                       and tablename = 'notifications') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on private.app_settings, private.push_tokens from public, anon, authenticated;
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
  public.release_device(text),
  public.set_push_token(text, text),
  public.clear_push_token(text)
to authenticated;
grant execute on function private.is_admin() to authenticated;

grant execute on function
  public.upload_points_with_pass(bigint, text, jsonb),
  public.duty_off_with_pass(bigint, text, timestamptz),
  public.report_break_with_pass(bigint, text, timestamptz, timestamptz, public.duty_break_kind)
to anon, authenticated;

grant execute on all functions in schema public to service_role;
grant execute on all functions in schema private to service_role;
