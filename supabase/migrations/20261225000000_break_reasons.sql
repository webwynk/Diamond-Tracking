-- Reasons for a hole in the route.
--
-- Until now the phone reported a hole only when the tracker started again
-- after the phone was off or the tracker was stopped. Everything else showed
-- "No location" with no reason. The tracker now also reports:
--   location_off    Location (GPS) was switched off on the phone.
--   permission_off  The app's location permission was taken away.
--   gps_silent      The tracker ran but the phone sent no position, even
--                   after the tracker restarted GPS (battery saving).
--
-- "Phone off" is the most exact reason, so it now replaces every other
-- reason it overlaps (before: only "tracking stopped"). Any other overlap:
-- the reason saved first stays.

alter type public.duty_break_kind add value if not exists 'location_off';
alter type public.duty_break_kind add value if not exists 'permission_off';
alter type public.duty_break_kind add value if not exists 'gps_silent';

create or replace function public.report_break_with_pass(
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
  select * into v_row from public.duty_days where id = p_day_id and user_id = v_uid for update;
  v_from := greatest(p_from, v_row.duty_on_at);
  v_to := least(p_to, coalesce(v_row.duty_off_at, private.auto_off_at(v_row.day)),
                now() + interval '2 minutes');
  if v_from is null or v_to is null or v_to - v_from < interval '1 minute' then
    return false;
  end if;
  -- A "phone off" break replaces the other reasons it overlaps.
  if p_kind = 'phone_off' then
    delete from public.duty_breaks
    where duty_day_id = p_day_id and kind <> 'phone_off'
      and started_at < v_to and ended_at > v_from;
  end if;
  -- Any other overlap: the break already saved stays.
  if exists (select 1 from public.duty_breaks
             where duty_day_id = p_day_id and started_at < v_to and ended_at > v_from) then
    return false;
  end if;
  insert into public.duty_breaks (duty_day_id, started_at, ended_at, kind)
  values (p_day_id, v_from, v_to, p_kind)
  on conflict do nothing;
  return found;
end;
$$;
