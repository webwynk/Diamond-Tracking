-- Phase 7: visits (dealer photos).
--
-- The visits table and add_visit exist since the baseline. This adds:
--   * A visit needs a store name and a photo. The photo id is tied to the
--     visit ("visit-<visit id>"), handed out by the photos function, so no
--     other Cloudinary path can be named and a photo belongs to one visit.
--   * The photos function shows a visit's photo to its owner or an admin.
--   * Photos (visits and requests) are deleted from Cloudinary after 90 days.
--     A nightly job asks the photos function to do it; the rows stay, marked
--     photo_removed_at, so the app shows "photo removed after 90 days".

-- ---------------------------------------------------------------------------
-- Adding a visit
-- ---------------------------------------------------------------------------

create or replace function public.add_visit(
  p_id uuid, p_store_name text, p_note text, p_from_gallery boolean,
  p_lat_e6 integer, p_lng_e6 integer, p_photo_id text, p_captured_at timestamptz
) returns public.visits
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_day public.duty_days;
  v_row public.visits;
begin
  -- A retry of a visit already saved returns it, even after duty off.
  select * into v_row from public.visits where id = p_id and user_id = v_uid;
  if found then
    return v_row;
  end if;
  select * into v_day from public.duty_days
  where user_id = v_uid and day = private.ist_today() and status = 'on_duty';
  if not found then
    raise exception 'not_on_duty' using errcode = 'P0001';
  end if;
  if nullif(trim(p_store_name), '') is null or char_length(trim(p_store_name)) > 80 then
    raise exception 'store_name_required' using errcode = '22023';
  end if;
  if char_length(trim(coalesce(p_note, ''))) > 300 then
    raise exception 'note_too_long' using errcode = '22023';
  end if;
  if p_photo_id is distinct from 'visit-' || p_id::text then
    raise exception 'photo_required' using errcode = '22023';
  end if;
  if not p_from_gallery and (
       p_lat_e6 is null or p_lng_e6 is null
       or p_lat_e6 not between -90000000 and 90000000
       or p_lng_e6 not between -180000000 and 180000000) then
    raise exception 'location_required' using errcode = '22023';
  end if;

  insert into public.visits (id, user_id, duty_day_id, store_name, note, from_gallery,
                             lat_e6, lng_e6, photo_id, captured_at)
  values (p_id, v_uid, v_day.id, trim(p_store_name), nullif(trim(p_note), ''),
          p_from_gallery,
          case when p_from_gallery then null else p_lat_e6 end,
          case when p_from_gallery then null else p_lng_e6 end,
          p_photo_id,
          least(greatest(coalesce(p_captured_at, now()), v_day.duty_on_at), now()))
  on conflict (id) do nothing;
  select * into v_row from public.visits where id = p_id;
  if v_row.user_id is distinct from v_uid then
    -- The id belongs to someone else's visit.
    raise exception 'invalid_visit' using errcode = '22023';
  end if;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- Showing a visit photo (the photos function, as service_role)
-- ---------------------------------------------------------------------------

create function public.svc_visit_photo(p_visit_id uuid, p_caller uuid)
returns text
language plpgsql stable security definer set search_path = '' as $$
declare
  v_visit public.visits;
begin
  select * into v_visit from public.visits where id = p_visit_id;
  if not found then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if v_visit.user_id <> p_caller and not exists (
    select 1 from public.profiles where id = p_caller and role = 'admin' and is_active
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if v_visit.photo_removed_at is not null then
    return null;
  end if;
  return v_visit.photo_id;
end;
$$;

-- A removed request photo is not shown either.
alter table public.requests add column photo_removed_at timestamptz;

create or replace function public.svc_request_photo(p_request_id bigint, p_caller uuid)
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
  if v_req.photo_removed_at is not null then
    return null;
  end if;
  return v_req.photo_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Deleting photos after 90 days
-- ---------------------------------------------------------------------------

-- The oldest photos past 90 days that are still on Cloudinary.
create function public.svc_photos_to_purge(p_limit integer default 200)
returns table (kind text, id text, photo_id text)
language sql stable security definer set search_path = '' as $$
  select * from (
    select 'visit'::text, v.id::text, v.photo_id from public.visits v
    where v.photo_id is not null and v.photo_removed_at is null
      and v.created_at < now() - interval '90 days'
    union all
    select 'request'::text, r.id::text, r.photo_id from public.requests r
    where r.photo_id is not null and r.photo_removed_at is null
      and r.created_at < now() - interval '90 days'
  ) p
  limit least(greatest(coalesce(p_limit, 200), 1), 500);
$$;

-- Marks photos as deleted from Cloudinary.
create function public.svc_photos_removed(p_photo_ids text[])
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  n integer;
  m integer;
begin
  update public.visits set photo_removed_at = now()
  where photo_id = any (p_photo_ids) and photo_removed_at is null;
  get diagnostics n = row_count;
  update public.requests set photo_removed_at = now()
  where photo_id = any (p_photo_ids) and photo_removed_at is null;
  get diagnostics m = row_count;
  return n + m;
end;
$$;

create index visits_photo_purge_idx on public.visits (created_at)
  where photo_id is not null and photo_removed_at is null;
create index requests_photo_purge_idx on public.requests (created_at)
  where photo_id is not null and photo_removed_at is null;

-- Asks the photos function to delete old photos. photos_url in app_settings:
--   https://<project>.supabase.co/functions/v1/photos
-- Without it nothing is deleted. Calling the function is harmless: it only
-- deletes what svc_photos_to_purge lists.
create function private.purge_photos() returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_url text;
begin
  select value into v_url from private.app_settings where key = 'photos_url';
  if v_url is null or to_regnamespace('net') is null then
    return;
  end if;
  if not exists (select 1 from public.svc_photos_to_purge(1)) then
    return;
  end if;
  perform net.http_post(
    url := v_url,
    body := jsonb_build_object('action', 'purge'),
    headers := jsonb_build_object('content-type', 'application/json'),
    timeout_milliseconds := 120000);
end;
$$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- Every 15 minutes from 02:30 to 04:15 IST; each run deletes up to 200.
    perform cron.schedule('purge-photos', '*/15 21-22 * * *',
      'select private.purge_photos()');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

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
