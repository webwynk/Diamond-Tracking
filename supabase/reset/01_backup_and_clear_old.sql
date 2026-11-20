-- STEP 1 of 3. Run once in the Supabase SQL editor, AFTER downloading a
-- backup (see supabase/reset/STEPS.txt).
--
-- Copies the user list to a safe place, then removes every table, function,
-- trigger and schedule of the old app. Sign-in accounts (auth.users) are NOT
-- touched. Runs in one transaction: if anything fails, nothing changes.

begin;

-- 1. Keep the users.
create schema if not exists reset_backup;
drop table if exists reset_backup.profiles;
create table reset_backup.profiles as select * from public.profiles;
revoke all on schema reset_backup from public, anon, authenticated;

-- 2. Old schedules.
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.unschedule(jobname) from cron.job
    where jobname in ('auto-end-duty-curfew', 'auto-end-duty-sweep',
                      'purge-old-location-points', 'purge-old-notifications',
                      'purge-visit-photos', 'raise-no-signal-alerts');
  end if;
end;
$$;

-- 3. Old trigger on the sign-in table.
drop trigger if exists on_auth_user_created on auth.users;

-- 4. Old tables and functions.
drop schema if exists private cascade;
drop table if exists
  public.audit_log, public.duty_sessions, public.live_locations,
  public.location_points, public.notification_reads, public.notifications,
  public.visits, public.profiles
cascade;
do $$
declare
  f record;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in (
      'admin_clear_device', 'admin_reset_pin', 'admin_session_distance',
      'bind_my_device', 'complete_pin_change', 'employee_login_check',
      'handle_new_user', 'ingest_location_points', 'is_admin',
      'list_notifications', 'log_report_export', 'mark_all_notifications_read',
      'mark_notifications_read', 'report_gps_status', 'server_time',
      'set_employee_pin', 'unread_notification_count', 'update_updated_at_column')
  loop
    execute 'drop function ' || f.sig || ' cascade';
  end loop;
end;
$$;

-- 5. Forget the old migration history, so the Supabase CLI does not expect
--    the old files.
do $$
begin
  if to_regclass('supabase_migrations.schema_migrations') is not null then
    delete from supabase_migrations.schema_migrations where version < '20261120000000';
  end if;
end;
$$;

commit;
