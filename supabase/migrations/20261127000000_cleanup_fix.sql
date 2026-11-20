-- Review fix H1: the nightly cleanup lost two lines.
--
-- private.cleanup() has been rewritten in four migrations. Each rewrite
-- replaces the whole function, and the ones in 20261124000000_requests_push
-- and 20261126000000_duty_on_permit were copied from an older version, so two
-- deletes added in 20261122000000_duty_tracking were lost:
--   * phone-off / tracking-stopped notes (duty_breaks) of days older than 90
--     days. They are only shown with a route, and routes go after 90 days, so
--     after that they are never seen again but were kept forever.
--   * expired upload passes. The server already refuses them; they were just
--     never removed (one row per employee per duty day).
--
-- This is the complete list again, in one place. When a later migration adds
-- a line, copy THIS version (or the newest one) and keep every line; the
-- "nightly cleanup keeps and removes the right rows" database test checks each
-- of them, so a lost line now fails CI.
--
-- Nothing else changes: same name, same schedule (nightly-cleanup, 21:00 UTC
-- = 2:30 AM India time), same owner and grants.

create or replace function private.cleanup() returns void
language plpgsql security definer set search_path = '' as $$
begin
  -- Raw GPS points: 7 days (the day's route is built from them first).
  delete from public.track_points where recorded_at < now() - interval '7 days';
  -- Routes and their phone-off notes: 90 days.
  delete from public.day_routes where day < private.ist_today() - 90;
  delete from public.duty_breaks b using public.duty_days d
  where d.id = b.duty_day_id and d.day < private.ist_today() - 90;
  -- Notifications: 60 days.
  delete from public.notifications where created_at < now() - interval '60 days';
  -- Live map positions of duties that have ended.
  delete from public.live_positions lp
  where not exists (select 1 from public.duty_days d
                    where d.id = lp.duty_day_id and d.status = 'on_duty')
    and lp.updated_at < now() - interval '1 day';
  -- Password reset codes, one day after they expire.
  delete from private.password_reset_codes where expires_at < now() - interval '1 day';
  -- Upload passes once expired (they no longer work).
  delete from private.upload_passes where expires_at < now();
  -- Push tokens of phones not opened in 60 days.
  delete from private.push_tokens where updated_at < now() - interval '60 days';
  -- "Allow duty on today" permissions after 30 days.
  delete from public.duty_permits where day < private.ist_today() - 30;
end;
$$;
