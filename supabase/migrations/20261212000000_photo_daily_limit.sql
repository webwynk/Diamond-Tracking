-- L62: at most 60 photo uploads per person per day (days in India time).
--
-- Before, any signed-in account could ask the photos function for as many
-- upload signatures as it liked and fill Cloudinary's free storage.
-- Now the photos function counts each signature here and refuses the 61st
-- of the day with "photo_limit". 60 leaves room for a busy day of visits
-- plus retries (each retry asks for a new signature).
-- The counts keep only today and yesterday, and clean themselves up.

create table private.photo_upload_counts (
  day     date not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  signed  smallint not null default 0,
  primary key (day, user_id)
);
create index photo_upload_counts_user_idx on private.photo_upload_counts (user_id);
revoke all on private.photo_upload_counts from public, anon, authenticated;

-- Counts one photo upload for the user today. False (and nothing counted)
-- when today's 60 are used up.
create function private.count_photo_upload(p_user uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_day date := private.ist_today();
  v_signed integer;
begin
  delete from private.photo_upload_counts where day < v_day - 1;
  insert into private.photo_upload_counts as c (day, user_id, signed) values (v_day, p_user, 1)
  on conflict (day, user_id) do update set signed = c.signed + 1
    where c.signed < 60
  returning signed into v_signed;
  return v_signed is not null;
end;
$$;

create function public.svc_count_photo_upload(p_user uuid) returns boolean
language sql security definer set search_path = '' as $$
  select private.count_photo_upload(p_user);
$$;

revoke all on function private.count_photo_upload(uuid) from public, anon, authenticated;
revoke all on function public.svc_count_photo_upload(uuid) from public, anon, authenticated;
grant execute on function private.count_photo_upload(uuid) to service_role;
grant execute on function public.svc_count_photo_upload(uuid) to service_role;
