-- Deleting a user also deletes the admins' notifications about them.
--
-- The 2026-11-23 audit found that svc_delete_user (20261222000000) removed
-- the person's own notifications (they cascade from the profile) but not the
-- ones sent to admins about them ("Short duty to review", "Leave request"),
-- which point at the person (user_id), their request (request_id) or their
-- duty day (duty_day_id). Opening one showed "Request not found".
--
-- 1. svc_delete_user now deletes those too, in the same transaction, before
--    the rows they point at are gone. The same match as close_duty uses when
--    a short-duty request is withdrawn (20261204000000).
-- 2. A one-time clean-up deletes the ones already left behind: notifications
--    whose person, request or duty day no longer exists.

create or replace function public.svc_delete_user(p_user uuid) returns integer
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

  -- Other people's notifications about this person (their own go with the
  -- profile).
  delete from public.notifications nt
  where nt.user_id <> p_user
    and (nt.data->>'user_id' = p_user::text
         or nt.data->>'request_id' in (select r.id::text from public.requests r
                                       where r.user_id = p_user)
         or nt.data->>'duty_day_id' in (select d.id::text from public.duty_days d
                                        where d.user_id = p_user));

  delete from auth.users where id = p_user;
  return n;
end;
$$;

revoke all on function public.svc_delete_user(uuid) from public, anon, authenticated;
grant execute on function public.svc_delete_user(uuid) to service_role;

-- One-time clean-up of notifications left by earlier deletes.
delete from public.notifications nt
where (nt.data ? 'user_id'
       and not exists (select 1 from public.profiles p where p.id::text = nt.data->>'user_id'))
   or (nt.data ? 'request_id'
       and not exists (select 1 from public.requests r where r.id::text = nt.data->>'request_id'))
   or (nt.data ? 'duty_day_id'
       and not exists (select 1 from public.duty_days d where d.id::text = nt.data->>'duty_day_id'));
