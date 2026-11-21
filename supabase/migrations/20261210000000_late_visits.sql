-- File 6 of the 2026-11-20 review (visits).
--
-- M10: a visit saved on the phone with no internet was lost if it reached
-- the server after the duty ended ("not_on_duty"). The phone now keeps such
-- visits and sends them later; add_visit puts a visit into the duty its photo
-- was taken in (by captured_at), up to 2 days back, even after duty off. A
-- time up to an hour before today's duty on still goes into today's duty;
-- an older time that fits no duty is refused.
-- add_visit is otherwise the same as in 20261129000000_fake_gps.sql.
--
-- L25: marking photos as removed looked them up without an index.
-- L26: the nightly cleanup now deletes the oldest photos first.
-- L24 (docs only): photo deletion needs photos_url and pg_net; STEPS.txt says so.

create or replace function public.add_visit(
  p_id uuid, p_store_name text, p_note text, p_from_gallery boolean,
  p_lat_e6 integer, p_lng_e6 integer, p_photo_id text, p_captured_at timestamptz,
  p_mocked boolean default false
) returns public.visits
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_day public.duty_days;
  v_row public.visits;
  v_at timestamptz := coalesce(p_captured_at, now());
  v_end timestamptz;
begin
  -- A retry of a visit already saved returns it, even after duty off.
  select * into v_row from public.visits where id = p_id and user_id = v_uid;
  if found then
    return v_row;
  end if;
  -- The duty the photo was taken in: the running one, or one of the last
  -- 2 days that has ended since (a visit the phone kept while it had no
  -- internet, M10).
  select * into v_day from public.duty_days d
  where d.user_id = v_uid and d.duty_on_at is not null
    and d.day >= private.ist_today() - 2
    and v_at >= d.duty_on_at - interval '2 minutes'
    and v_at < coalesce(d.duty_off_at, private.auto_off_at(d.day)) + interval '2 minutes'
  order by d.duty_on_at desc
  limit 1;
  if not found then
    -- No time, or a time a little before today's duty on (a phone clock
    -- slightly off): today's running duty, as before.
    select * into v_day from public.duty_days
    where user_id = v_uid and day = private.ist_today() and status = 'on_duty'
      and (p_captured_at is null or v_at >= duty_on_at - interval '1 hour');
  end if;
  if not found then
    raise exception 'not_on_duty' using errcode = 'P0001';
  end if;
  v_end := coalesce(v_day.duty_off_at, private.auto_off_at(v_day.day));
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
                             lat_e6, lng_e6, photo_id, captured_at, mocked)
  values (p_id, v_uid, v_day.id, trim(p_store_name), nullif(trim(p_note), ''),
          p_from_gallery,
          case when p_from_gallery then null else p_lat_e6 end,
          case when p_from_gallery then null else p_lng_e6 end,
          p_photo_id,
          least(greatest(v_at, v_day.duty_on_at), v_end, now()),
          not p_from_gallery and coalesce(p_mocked, false))
  on conflict (id) do nothing;
  select * into v_row from public.visits where id = p_id;
  if v_row.user_id is distinct from v_uid then
    -- The id belongs to someone else's visit.
    raise exception 'invalid_visit' using errcode = '22023';
  end if;
  return v_row;
end;
$$;

-- L26 -----------------------------------------------------------------------

-- The oldest photos past 90 days that are still on Cloudinary, oldest first.
create or replace function public.svc_photos_to_purge(p_limit integer default 200)
returns table (kind text, id text, photo_id text)
language sql stable security definer set search_path = '' as $$
  select p.kind, p.id, p.photo_id from (
    select 'visit'::text as kind, v.id::text as id, v.photo_id, v.created_at
    from public.visits v
    where v.photo_id is not null and v.photo_removed_at is null
      and v.created_at < now() - interval '90 days'
    union all
    select 'request'::text, r.id::text, r.photo_id, r.created_at
    from public.requests r
    where r.photo_id is not null and r.photo_removed_at is null
      and r.created_at < now() - interval '90 days'
  ) p
  order by p.created_at, p.photo_id
  limit least(greatest(coalesce(p_limit, 200), 1), 500);
$$;

-- L25 -----------------------------------------------------------------------

create index if not exists visits_photo_id_idx on public.visits (photo_id)
  where photo_removed_at is null;
create index if not exists requests_photo_id_idx on public.requests (photo_id)
  where photo_removed_at is null;
