-- =============================================================================
-- Migration: 20261017070000_notifications.sql
-- Description: The admin notification centre (PRD F12): events, per-admin read
-- state, and the "no data for 10 minutes" tracking-broken alert.
-- Nothing here is applied until the owner approves it.
--
-- What it adds
--   public.notifications        one row per event, written ONLY by the database
--   public.notification_reads   one row per admin per notification they read
--   triggers                    duty started / ended (incl. automatic end and
--                               block), first mock-GPS point of a duty, battery
--                               under 15%
--   a once-a-minute job         no data reached the server for 10 minutes while
--                               a duty is open (also: a duty that never sent a
--                               first point)
--   a weekly job                deletes notifications older than 6 months (PRD)
--   unread_notification_count() / mark_notifications_read(ids) /
--   mark_all_notifications_read()   invoker functions for the admin app
--
-- Rules it keeps
--   * Writing a notification can NEVER stop a duty from starting or ending or a
--     point from being stored: every write is wrapped, a failure only raises a
--     warning in the database log.
--   * No repeats: every notification has a unique key (for example
--     'no_signal:<duty>:<last data time>'), so a repeat is ignored and a NEW
--     silence after data resumed is a new alert.
--   * Silence is judged on the SERVER's clock (when data last arrived), never
--     the phone's.
--   * Only active admins can read notifications. Nobody can write them through
--     the API. Read state is per admin: admin A reading leaves it unread for B.
--
-- Backward compatible: only adds objects. Delete job: nothing is older than 6
-- months yet.
--
-- Rollback (manual):
--   select cron.unschedule('raise-no-signal-alerts');
--   select cron.unschedule('purge-old-notifications');
--   drop trigger if exists trg_duty_sessions_notify_start on public.duty_sessions;
--   drop trigger if exists trg_duty_sessions_notify_end on public.duty_sessions;
--   drop trigger if exists trg_location_points_notify_mock on public.location_points;
--   drop trigger if exists trg_location_points_notify_battery on public.location_points;
--   drop function if exists private.duty_sessions_notify_start(), private.duty_sessions_notify_end(),
--     private.location_points_notify_mock(), private.location_points_notify_battery(),
--     private.raise_no_signal_alerts(), private.purge_old_notifications(),
--     private.notify(text, uuid, uuid, text, jsonb),
--     public.unread_notification_count(), public.mark_notifications_read(bigint[]),
--     public.mark_all_notifications_read();
--   drop table if exists public.notification_reads, public.notifications;
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tables
-- -----------------------------------------------------------------------------
create table if not exists public.notifications (
  id          bigint generated always as identity primary key,
  type        text not null check (type in (
                'duty_on', 'duty_off', 'duty_auto_ended',
                'mock_gps', 'battery_low', 'no_signal')),
  employee_id uuid not null references public.profiles(id) on delete cascade,
  session_id  uuid references public.duty_sessions(id) on delete cascade,
  details     jsonb not null default '{}'::jsonb,
  dedupe_key  text not null,
  created_at  timestamptz not null default now()
);

create unique index if not exists idx_notifications_dedupe
  on public.notifications (dedupe_key);
create index if not exists idx_notifications_created
  on public.notifications (created_at desc, id desc);
create index if not exists idx_notifications_employee_created
  on public.notifications (employee_id, created_at desc);

create table if not exists public.notification_reads (
  notification_id bigint not null references public.notifications(id) on delete cascade,
  admin_id        uuid   not null references public.profiles(id) on delete cascade,
  read_at         timestamptz not null default now(),
  primary key (notification_id, admin_id)
);

-- -----------------------------------------------------------------------------
-- 2. Privileges and row-level security (docs/06 section 3: grant exactly what
--    the app uses, nothing to anon)
-- -----------------------------------------------------------------------------
alter table public.notifications enable row level security;
alter table public.notification_reads enable row level security;

revoke all on public.notifications from anon, authenticated;
revoke all on public.notification_reads from anon, authenticated;
grant select on public.notifications to authenticated;
grant select, insert on public.notification_reads to authenticated;

drop policy if exists "Admins can view notifications" on public.notifications;
create policy "Admins can view notifications"
on public.notifications for select to authenticated
using ((select public.is_admin()));

drop policy if exists "Admins can view their own reads" on public.notification_reads;
create policy "Admins can view their own reads"
on public.notification_reads for select to authenticated
using (admin_id = (select auth.uid()) and (select public.is_admin()));

drop policy if exists "Admins can mark notifications read for themselves" on public.notification_reads;
create policy "Admins can mark notifications read for themselves"
on public.notification_reads for insert to authenticated
with check (admin_id = (select auth.uid()) and (select public.is_admin()));

-- -----------------------------------------------------------------------------
-- 3. The one place that writes a notification. It never raises: a failure here
--    must not stop a duty from starting or a point from being stored.
-- -----------------------------------------------------------------------------
create or replace function private.notify(
  p_type text,
  p_employee uuid,
  p_session uuid,
  p_key text,
  p_details jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notifications (type, employee_id, session_id, dedupe_key, details)
  values (p_type, p_employee, p_session, p_key, coalesce(p_details, '{}'::jsonb))
  on conflict (dedupe_key) do nothing;
exception when others then
  raise warning 'notification % not written: % (%)', p_type, sqlerrm, sqlstate;
end;
$$;

revoke all on function private.notify(text, uuid, uuid, text, jsonb)
  from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. Duty started and ended
-- -----------------------------------------------------------------------------
create or replace function private.duty_sessions_notify_start()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.notify(
    'duty_on', new.employee_id, new.id, 'duty_on:' || new.id,
    jsonb_build_object('started_at', new.started_at)
  );
  return null;
end;
$$;

drop trigger if exists trg_duty_sessions_notify_start on public.duty_sessions;
create trigger trg_duty_sessions_notify_start
after insert on public.duty_sessions
for each row execute function private.duty_sessions_notify_start();

create or replace function private.duty_sessions_notify_end()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.notify(
    case when new.status = 'auto_curfew' then 'duty_auto_ended' else 'duty_off' end,
    new.employee_id, new.id, 'duty_end:' || new.id,
    jsonb_build_object(
      'ended_at', new.ended_at,
      'status', new.status,
      'end_reason', new.end_reason
    )
  );
  return null;
end;
$$;

drop trigger if exists trg_duty_sessions_notify_end on public.duty_sessions;
create trigger trg_duty_sessions_notify_end
after update on public.duty_sessions
for each row
when (old.ended_at is null and new.ended_at is not null)
execute function private.duty_sessions_notify_end();

-- -----------------------------------------------------------------------------
-- 5. First mock-GPS point of a duty; battery under 15%
--    The WHEN clauses mean an ordinary point costs nothing extra.
-- -----------------------------------------------------------------------------
create or replace function private.location_points_notify_mock()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.notify(
    'mock_gps', new.employee_id, new.session_id, 'mock_gps:' || new.session_id,
    jsonb_build_object('recorded_at', new.recorded_at)
  );
  return null;
end;
$$;

drop trigger if exists trg_location_points_notify_mock on public.location_points;
create trigger trg_location_points_notify_mock
after insert on public.location_points
for each row
when (new.is_mock)
execute function private.location_points_notify_mock();

-- Only a recent reading: a low battery reported by a point that sat in the
-- phone's offline queue for hours is not news.
create or replace function private.location_points_notify_battery()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.notify(
    'battery_low', new.employee_id, new.session_id, 'battery_low:' || new.session_id,
    jsonb_build_object('battery_level', new.battery_level, 'recorded_at', new.recorded_at)
  );
  return null;
end;
$$;

drop trigger if exists trg_location_points_notify_battery on public.location_points;
create trigger trg_location_points_notify_battery
after insert on public.location_points
for each row
when (new.battery_level is not null
      and new.battery_level < 15
      and new.recorded_at > now() - interval '10 minutes')
execute function private.location_points_notify_battery();

-- -----------------------------------------------------------------------------
-- 6. Tracking broken: no data reached the server for 10 minutes during a duty
--    A phone records a point at least every 3 minutes even when still, so ten
--    minutes of silence is a real failure (killed app, dead battery, no signal,
--    GPS off). It also catches a duty that never sent its first point.
-- -----------------------------------------------------------------------------
create or replace function private.raise_no_signal_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row   record;
  v_count integer := 0;
begin
  for v_row in
    select s.id as session_id,
           s.employee_id,
           coalesce(l.updated_at, s.started_at) as last_seen,
           (l.employee_id is null) as never_sent
    from public.duty_sessions s
    left join public.live_locations l
           on l.employee_id = s.employee_id and l.session_id = s.id
    where s.ended_at is null
      and coalesce(l.updated_at, s.started_at) < now() - interval '10 minutes'
  loop
    begin
      insert into public.notifications (type, employee_id, session_id, dedupe_key, details)
      values (
        'no_signal', v_row.employee_id, v_row.session_id,
        'no_signal:' || v_row.session_id || ':' || (extract(epoch from v_row.last_seen))::bigint,
        jsonb_build_object('last_seen', v_row.last_seen, 'never_sent', v_row.never_sent)
      )
      on conflict (dedupe_key) do nothing;
      if found then
        v_count := v_count + 1;
      end if;
    exception when others then
      raise warning 'no-signal alert not written: % (%)', sqlerrm, sqlstate;
    end;
  end loop;
  return v_count;
end;
$$;

revoke all on function private.raise_no_signal_alerts() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 7. Keep notifications 6 months (PRD section 5), in bounded batches
-- -----------------------------------------------------------------------------
create or replace function private.purge_old_notifications()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_batch       constant int := 20000;
  c_max_batches constant int := 10;
  v_deleted int := 0;
  v_n       int;
  v_batches int := 0;
begin
  loop
    delete from public.notifications
    where id in (
      select id from public.notifications
      where created_at < now() - interval '6 months'
      limit c_batch
    );
    get diagnostics v_n = row_count;
    v_deleted := v_deleted + v_n;
    v_batches := v_batches + 1;
    exit when v_n < c_batch or v_batches >= c_max_batches;
  end loop;

  if v_deleted > 0 then
    insert into public.audit_log (actor_id, action, details)
    values (null, 'notifications_purged', jsonb_build_object('deleted', v_deleted));
  end if;
  return v_deleted;
end;
$$;

revoke all on function private.purge_old_notifications() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 8. What the admin app calls. SECURITY INVOKER: the row-level rules above
--    decide, so an employee gets 0 and can mark nothing.
-- -----------------------------------------------------------------------------
create or replace function public.unread_notification_count()
returns integer
language sql
stable
security invoker
set search_path = ''
as $$
  select count(*)::int
  from public.notifications n
  where n.created_at > now() - interval '30 days'
    and not exists (
      select 1 from public.notification_reads r
      where r.notification_id = n.id and r.admin_id = (select auth.uid())
    );
$$;

create or replace function public.mark_notifications_read(p_ids bigint[])
returns integer
language sql
security invoker
set search_path = ''
as $$
  with marked as (
    insert into public.notification_reads (notification_id, admin_id)
    select n.id, (select auth.uid())
    from public.notifications n
    where n.id = any (p_ids)
    on conflict do nothing
    returning 1
  )
  select count(*)::int from marked;
$$;

create or replace function public.mark_all_notifications_read()
returns integer
language sql
security invoker
set search_path = ''
as $$
  with marked as (
    insert into public.notification_reads (notification_id, admin_id)
    select n.id, (select auth.uid())
    from public.notifications n
    where not exists (
      select 1 from public.notification_reads r
      where r.notification_id = n.id and r.admin_id = (select auth.uid())
    )
    on conflict do nothing
    returning 1
  )
  select count(*)::int from marked;
$$;

revoke all on function public.unread_notification_count() from public, anon;
revoke all on function public.mark_notifications_read(bigint[]) from public, anon;
revoke all on function public.mark_all_notifications_read() from public, anon;
grant execute on function public.unread_notification_count() to authenticated;
grant execute on function public.mark_notifications_read(bigint[]) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;

-- -----------------------------------------------------------------------------
-- 9. Live: new notifications reach admins over Realtime (row-level rules apply)
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'notifications'
     ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 10. Jobs (UTC): the silence check every minute; the 6-month delete weekly on
--     Sunday 22:00 UTC (03:30 IST Monday)
-- -----------------------------------------------------------------------------
create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'raise-no-signal-alerts',
  '* * * * *',
  $job$select private.raise_no_signal_alerts()$job$
);
select cron.schedule(
  'purge-old-notifications',
  '0 22 * * 0',
  $job$select private.purge_old_notifications()$job$
);
