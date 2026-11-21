-- File 12 of the 2026-11-20 review (visits).
--
-- L59: a visit's location now keeps its accuracy in metres, so the app can
-- say "approximate location" when it is poor. add_visit takes p_accuracy_m;
-- it is otherwise the same as in 20261210000000_late_visits.sql.
--
-- L56: photos uploaded but never used (the visit was refused, or the answer
-- was lost) stayed on Cloudinary forever, because the cleanup only knew
-- photos with a visit or request. The photos function now notes every photo
-- id it signs; the nightly cleanup deletes a noted photo that is more than
-- 4 days old and has no visit or request (a visit kept on the phone can
-- arrive up to about 3 days later).

-- L59 -----------------------------------------------------------------------

alter table public.visits add column if not exists accuracy_m integer
  check (accuracy_m is null or accuracy_m between 0 and 30000);

drop function public.add_visit(uuid, text, text, boolean, integer, integer, text, timestamptz, boolean);
create function public.add_visit(
  p_id uuid, p_store_name text, p_note text, p_from_gallery boolean,
  p_lat_e6 integer, p_lng_e6 integer, p_photo_id text, p_captured_at timestamptz,
  p_mocked boolean default false, p_accuracy_m integer default null
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
                             lat_e6, lng_e6, accuracy_m, photo_id, captured_at, mocked)
  values (p_id, v_uid, v_day.id, trim(p_store_name), nullif(trim(p_note), ''),
          p_from_gallery,
          case when p_from_gallery then null else p_lat_e6 end,
          case when p_from_gallery then null else p_lng_e6 end,
          case when p_from_gallery or p_accuracy_m is null then null
               else least(greatest(p_accuracy_m, 0), 30000) end,
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

revoke all on function
  public.add_visit(uuid, text, text, boolean, integer, integer, text, timestamptz, boolean, integer)
from public, anon;
grant execute on function
  public.add_visit(uuid, text, text, boolean, integer, integer, text, timestamptz, boolean, integer)
to authenticated, service_role;

-- L56 -----------------------------------------------------------------------

create table private.signed_photos (
  photo_id  text primary key,
  signed_at timestamptz not null default now()
);
create index signed_photos_signed_at_idx on private.signed_photos (signed_at);
revoke all on private.signed_photos from public, anon, authenticated;

-- Notes a photo id the photos function signed. Also forgets noted photos
-- that are older than 4 days and in use, so the table stays small.
create function public.svc_note_signed_photo(p_photo_id text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from private.signed_photos s
  where s.signed_at < now() - interval '4 days'
    and (exists (select 1 from public.visits v where v.photo_id = s.photo_id)
         or exists (select 1 from public.requests r where r.photo_id = s.photo_id));
  insert into private.signed_photos (photo_id) values (p_photo_id)
  on conflict (photo_id) do nothing;
end;
$$;

-- The photos to delete, oldest first: photos past 90 days that are still on
-- Cloudinary (as in 20261210000000_late_visits.sql), and noted photos more
-- than 4 days old that no visit or request uses ("orphan").
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
    union all
    select 'orphan'::text, s.photo_id, s.photo_id, s.signed_at
    from private.signed_photos s
    where s.signed_at < now() - interval '4 days'
      and not exists (select 1 from public.visits v where v.photo_id = s.photo_id)
      and not exists (select 1 from public.requests r where r.photo_id = s.photo_id)
  ) p
  order by p.created_at, p.photo_id
  limit least(greatest(coalesce(p_limit, 200), 1), 500);
$$;

-- Marks photos as deleted from Cloudinary, and forgets deleted orphans.
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
  where photo_id = any (p_photo_ids) and photo_removed_at is null;
  get diagnostics m = row_count;
  delete from private.signed_photos where photo_id = any (p_photo_ids);
  get diagnostics o = row_count;
  return n + m + o;
end;
$$;

revoke all on function public.svc_note_signed_photo(text) from public, anon, authenticated;
grant execute on function public.svc_note_signed_photo(text) to service_role;
