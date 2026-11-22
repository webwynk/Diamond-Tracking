-- Delete a user and all their data (admin-users "delete").
--
-- Deleting the sign-in account (auth.users) removes everything: the profile
-- goes with it (on delete cascade), and every table that holds a person's
-- data cascades from the profile (duty days and with them points, routes,
-- breaks and upload passes; live position, requests, visits, notifications,
-- duty permits, push tokens, reset codes, counters, app errors). Columns that
-- only name an admin (decided_by, granted_by, created_by, admin_log) are set
-- to null, so other people's records stay.
--
-- Photos are not in the database but in Cloudinary. The same transaction
-- notes each of the person's photos as an orphan old enough for the next
-- nightly purge (02:30 to 04:15 IST) to delete it. Both steps are in one
-- transaction so the photo clean-up in svc_note_signed_photo, which forgets
-- orphans that are still in use, can never see the photos queued while the
-- visits and requests still exist.
--
-- Called only by the admin-users function (service key), which checks that
-- the caller is an admin, is not deleting themselves, and typed the user ID.

create function public.svc_delete_user(p_user uuid) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  n integer;
begin
  if not exists (select 1 from public.profiles where id = p_user) then
    raise exception 'user_not_found';
  end if;

  insert into private.signed_photos (photo_id, signed_at)
  select ph.id, now() - interval '5 days'
  from (
    select v.photo_id as id from public.visits v
    where v.user_id = p_user and v.photo_id is not null and v.photo_removed_at is null
    union
    select x.id from public.requests r
    cross join lateral unnest(private.request_photo_ids(r.photo_id, r.extra_photo_ids)) x (id)
    where r.user_id = p_user and r.photo_id is not null and r.photo_removed_at is null
  ) ph
  on conflict (photo_id) do update set signed_at = excluded.signed_at;
  get diagnostics n = row_count;

  delete from auth.users where id = p_user;
  return n;
end;
$$;

revoke all on function public.svc_delete_user(uuid) from public, anon, authenticated;
grant execute on function public.svc_delete_user(uuid) to service_role;
