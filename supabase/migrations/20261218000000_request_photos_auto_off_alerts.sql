-- Redesign, server part (PR A). Three changes the new screens need:
--
-- 1. Attendance and leave requests take up to 3 photos (owner's decision,
--    2026-11-21). The first stays in photo_id, so everything built around
--    it keeps working unchanged: today's app, the photo viewer, the 90-day
--    clean-up and the orphan clean-up. Photos 2 and 3 go in the new
--    extra_photo_ids. The request functions take them as an optional last
--    argument, so today's app, which never sends it, works as before.
--    The photos function asks for photo 2 or 3 with &n=1 or &n=2.
--
-- 2. The 11 PM automatic duty off also sends the employee a notification,
--    "Duty turned off at 11 PM", so the next morning they know why the day
--    ended (owner's decision, 2026-11-21).
--
-- 3. Each admin can turn off phone alerts for new requests
--    (owner's decision, 2026-11-21). The notification is still saved, so it
--    shows in the app as before; only the phone push is skipped.

-- ---------------------------------------------------------------------------
-- 1. Up to 3 photos on a request
-- ---------------------------------------------------------------------------

alter table public.requests add column extra_photo_ids text[]
  check (extra_photo_ids is null
         or (cardinality(extra_photo_ids) between 1 and 2
             and array_position(extra_photo_ids, null) is null));

-- Photos 2 and 3 are only allowed beside a first photo, must be ids the
-- photos function hands out, and must all differ.
create function private.valid_extra_photos(p_first text, p_extra text[]) returns boolean
language sql immutable set search_path = '' as $$
  select p_extra is null
      or (p_first is not null
          and cardinality(p_extra) between 1 and 2
          and array_position(p_extra, null) is null
          and not exists (select 1 from unnest(p_extra) e where not private.valid_photo_id(e))
          and not (p_first = any (p_extra))
          and (select count(distinct e) from unnest(p_extra) e) = cardinality(p_extra));
$$;

-- An empty list means "no extra photos".
create function private.extra_photos_or_null(p_extra text[]) returns text[]
language sql immutable set search_path = '' as $$
  select case when cardinality(p_extra) > 0 then p_extra end;
$$;

-- The same as in 20261209000000_one_request_per_day.sql, plus the photos.
drop function public.request_attendance(date, time, time, text, text);
create function public.request_attendance(
  p_day date, p_duty_on time, p_duty_off time, p_message text, p_photo_id text,
  p_extra_photo_ids text[] default null
) returns public.requests
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_today date := private.ist_today();
  v_extra text[] := private.extra_photos_or_null(p_extra_photo_ids);
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
  if not private.valid_extra_photos(p_photo_id, v_extra) then
    raise exception 'invalid_photo' using errcode = '22023';
  end if;
  if exists (select 1 from public.duty_days
             where user_id = v_uid and day = p_day and duty_on_at is not null) then
    raise exception 'already_has_duty' using errcode = 'P0001';
  end if;
  -- One waiting request per day, of either kind (L18).
  if exists (select 1 from public.requests where user_id = v_uid and status = 'pending'
             and ((kind = 'attendance' and day = p_day)
                  or (kind = 'leave' and p_day = any (dates)))) then
    raise exception 'already_requested' using errcode = 'P0001';
  end if;

  insert into public.requests (user_id, kind, day, duty_on_at, duty_off_at, message,
                               photo_id, extra_photo_ids)
  values (v_uid, 'attendance', p_day, private.ist_at(p_day, p_duty_on),
          private.ist_at(p_day, p_duty_off), trim(p_message), p_photo_id, v_extra)
  returning * into v_row;

  perform private.notify_admins(
    'attendance_request', 'Attendance request',
    (select full_name from public.profiles where id = v_uid)
      || ' asked for attendance on ' || to_char(p_day, 'DD Mon YYYY'),
    jsonb_build_object('request_id', v_row.id));
  return v_row;
end;
$$;

drop function public.request_leave(public.leave_type, date[], text, text);
create function public.request_leave(
  p_type public.leave_type, p_dates date[], p_message text, p_proof_id text default null,
  p_extra_photo_ids text[] default null
) returns public.requests
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_proof text := nullif(trim(p_proof_id), '');
  v_extra text[] := private.extra_photos_or_null(p_extra_photo_ids);
  v_dates date[];
  v_row public.requests;
begin
  select array_agg(distinct d order by d) into v_dates from unnest(p_dates) d;
  -- An empty date could never be approved (L19).
  if v_dates is null or cardinality(v_dates) > 31 or array_position(v_dates, null) is not null then
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
  if v_proof is not null and not private.valid_photo_id(v_proof) then
    raise exception 'invalid_photo' using errcode = '22023';
  end if;
  if not private.valid_extra_photos(v_proof, v_extra) then
    raise exception 'invalid_photo' using errcode = '22023';
  end if;
  -- Overlapping a leave request still waiting would make two decisions for a day.
  -- ... and so would an attendance request still waiting for one of the days (L18).
  if exists (select 1 from public.requests where user_id = v_uid and status = 'pending'
             and ((kind = 'leave' and dates && v_dates)
                  or (kind = 'attendance' and day = any (v_dates)))) then
    raise exception 'already_requested' using errcode = 'P0001';
  end if;

  insert into public.requests (user_id, kind, leave_type, dates, message, photo_id,
                               extra_photo_ids)
  values (v_uid, 'leave', p_type, v_dates, trim(p_message), v_proof, v_extra)
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

-- Photo number p_index of a request: 0 is the first (photo_id), 1 and 2 are
-- the extra photos. The same checks as before: the owner or an active admin.
drop function public.svc_request_photo(bigint, uuid);
create function public.svc_request_photo(
  p_request_id bigint, p_caller uuid, p_index integer default 0
) returns text
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
  if v_req.photo_removed_at is not null then
    return null;
  end if;
  if coalesce(p_index, 0) = 0 then
    return v_req.photo_id;
  end if;
  return v_req.extra_photo_ids[p_index];
end;
$$;

-- All photos still on Cloudinary for a request: the first and the extras.
create function private.request_photo_ids(p_first text, p_extra text[]) returns text[]
language sql immutable set search_path = '' as $$
  select array_remove(array[p_first] || coalesce(p_extra, '{}'), null);
$$;

-- The same as in 20261214000000_visit_photos.sql, with every photo of a
-- request listed (not only the first), and extra photos never taken for
-- unused ones.
create or replace function public.svc_photos_to_purge(p_limit integer default 200)
returns table (kind text, id text, photo_id text)
language sql stable security definer set search_path = '' as $$
  select p.kind, p.id, p.photo_id from (
    select 'visit'::text as kind, v.id::text as id, v.photo_id, v.created_at
    from public.visits v
    where v.photo_id is not null and v.photo_removed_at is null
      and v.created_at < now() - interval '90 days'
    union all
    select 'request'::text, r.id::text, ph.id, r.created_at
    from public.requests r
    cross join lateral unnest(private.request_photo_ids(r.photo_id, r.extra_photo_ids)) ph (id)
    where r.photo_id is not null and r.photo_removed_at is null
      and r.created_at < now() - interval '90 days'
    union all
    select 'orphan'::text, s.photo_id, s.photo_id, s.signed_at
    from private.signed_photos s
    where s.signed_at < now() - interval '4 days'
      and not exists (select 1 from public.visits v where v.photo_id = s.photo_id)
      and not exists (select 1 from public.requests r where r.photo_id = s.photo_id)
      and not exists (select 1 from public.requests r where s.photo_id = any (r.extra_photo_ids))
  ) p
  order by p.created_at, p.photo_id
  limit least(greatest(coalesce(p_limit, 200), 1), 500);
$$;

-- The same as in 20261214000000_visit_photos.sql, except that a request is
-- marked only when all its photos are deleted. If a night's batch ends
-- between a request's photos, the next night lists them all again;
-- deleting a photo that is already gone counts as done.
create or replace function public.svc_photos_removed(p_photo_ids text[])
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  n integer;
  m integer;
  o integer;
begin
  update public.visits set photo_removed_at = now()
  where photo_id = any (p_photo_ids) and photo_removed_at is null;
  get diagnostics n = row_count;
  update public.requests set photo_removed_at = now()
  where photo_id = any (p_photo_ids) and photo_removed_at is null
    and private.request_photo_ids(photo_id, extra_photo_ids) <@ p_photo_ids;
  get diagnostics m = row_count;
  delete from private.signed_photos where photo_id = any (p_photo_ids);
  get diagnostics o = row_count;
  return n + m + o;
end;
$$;

-- The same as in 20261214000000_visit_photos.sql: an extra photo in use is
-- forgotten like a first photo in use.
create or replace function public.svc_note_signed_photo(p_photo_id text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from private.signed_photos s
  where s.signed_at < now() - interval '4 days'
    and (exists (select 1 from public.visits v where v.photo_id = s.photo_id)
         or exists (select 1 from public.requests r where r.photo_id = s.photo_id)
         or exists (select 1 from public.requests r where s.photo_id = any (r.extra_photo_ids)));
  insert into private.signed_photos (photo_id) values (p_photo_id)
  on conflict (photo_id) do nothing;
end;
$$;

-- For the "is this photo in use" lookups above.
create index requests_extra_photo_ids_idx on public.requests using gin (extra_photo_ids)
  where extra_photo_ids is not null;

-- ---------------------------------------------------------------------------
-- 2. A notification for the 11 PM automatic duty off
-- ---------------------------------------------------------------------------

-- The same as in 20261120000000_rewrite_baseline.sql, plus the notification.
create or replace function private.auto_duty_off() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  n integer := 0;
begin
  for r in
    select id, user_id, day from public.duty_days
    where status = 'on_duty' and private.auto_off_at(day) <= now()
  loop
    perform private.close_duty(r.id, private.auto_off_at(r.day), 'auto');
    perform private.notify(
      r.user_id, 'duty_auto_off', 'Duty turned off at 11 PM',
      'Your duty on ' || to_char(r.day, 'DD Mon') || ' ended by itself at 11:00 PM.',
      jsonb_build_object('duty_day_id', r.id, 'day', r.day));
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Phone alerts for new requests, per admin
-- ---------------------------------------------------------------------------

-- Only used for admins. On by default, so nothing changes until an admin
-- turns it off.
alter table public.profiles add column request_alerts boolean not null default true;

-- The signed-in admin turns their own request alerts on or off.
create function public.set_request_alerts(p_on boolean) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_admin uuid := private.require_admin();
begin
  if p_on is null then
    raise exception 'validation_failed' using errcode = '22023';
  end if;
  update public.profiles set request_alerts = p_on, updated_at = now() where id = v_admin;
  return p_on;
end;
$$;

-- The same as in 20261124000000_requests_push.sql, except that an admin who
-- turned off request alerts gets no phone push for a new request. The
-- notification is still claimed, so it is not sent later either.
create or replace function public.svc_claim_push(p_id bigint) returns jsonb
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
    and (p.role = 'admin' or t.device_id = p.active_device_id)
    and not (p.role = 'admin' and not p.request_alerts
             and v_n.kind in ('attendance_request', 'leave_request', 'short_duty'));
  return jsonb_build_object(
    'title', v_n.title, 'body', v_n.body, 'kind', v_n.kind,
    'data', v_n.data || jsonb_build_object('notification_id', v_n.id),
    'tokens', to_jsonb(v_tokens));
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on function
  private.valid_extra_photos(text, text[]),
  private.extra_photos_or_null(text[]),
  private.request_photo_ids(text, text[]),
  public.request_attendance(date, time, time, text, text, text[]),
  public.request_leave(public.leave_type, date[], text, text, text[]),
  public.svc_request_photo(bigint, uuid, integer),
  public.set_request_alerts(boolean)
from public, anon, authenticated;

grant execute on function
  public.request_attendance(date, time, time, text, text, text[]),
  public.request_leave(public.leave_type, date[], text, text, text[]),
  public.set_request_alerts(boolean)
to authenticated;

grant execute on function
  private.valid_extra_photos(text, text[]),
  private.extra_photos_or_null(text[]),
  private.request_photo_ids(text, text[]),
  public.request_attendance(date, time, time, text, text, text[]),
  public.request_leave(public.leave_type, date[], text, text, text[]),
  public.svc_request_photo(bigint, uuid, integer),
  public.set_request_alerts(boolean)
to service_role;
