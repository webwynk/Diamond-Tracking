-- Housekeeping after the real-phone tests passed (2026-11-22).
--
-- 1. The scheduled-job log (cron.job_run_details) is trimmed in the nightly
--    cleanup: only the last 30 days are kept. The old design wrote about 1,500
--    rows a day, so the log held 52,738 rows (8.9 MB) with nothing reading it.
--    The statement only runs where pg_cron is installed (Supabase), so the
--    database tests on plain Postgres are not affected.
--
-- 2. reset_backup.old_location_points is dropped: a copy of the pre-rewrite
--    GPS points (2,370 rows, 448 kB) that nothing reads. The rest of the
--    reset_backup schema (old profiles, duty sessions, visits, notifications,
--    audit log) is NOT touched; drop it separately when you are ready.
--
-- private.cleanup() is copied from 20261127000000_cleanup_fix.sql (the live
-- version, checked) with one line added at the end. Keep every line when this
-- function is rewritten again; the "nightly cleanup" tests check each one.

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
  -- Scheduled-job log: 30 days (only where pg_cron is installed).
  if to_regclass('cron.job_run_details') is not null then
    delete from cron.job_run_details where start_time < now() - interval '30 days';
  end if;
end;
$$;

drop table if exists reset_backup.old_location_points;
