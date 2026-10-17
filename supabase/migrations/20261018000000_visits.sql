-- =============================================================================
-- Migration: 20261018000000_visits.sql
-- Description: The visits table (PRD F10, as changed 2026-10-18).
-- Nothing here is applied until the owner approves it.
--
-- What a visit is
--   An employee on duty adds a visit by hand: an optional store name (80
--   characters), an optional note (200), the GPS position, and an optional photo.
--   There are no places and no geofences. The photo itself lives in Cloudinary;
--   this table only stores its public_id. Photos are deleted after 90 days (by a
--   server function, a later step) and the row stays, so attendance and report
--   visit counts remain correct.
--
-- Who can do what
--   Employee : add a visit for their OWN open duty (or a late one for their own
--              duty, inside its time span); read their own visits.
--              They cannot choose the owner, the photo columns or the server time,
--              cannot edit and cannot delete.
--   Admin    : read every visit. Nobody edits or deletes through the app.
--   Server   : the Edge Functions (service role) attach and remove the photo.
--
-- Rules enforced by the database (not by the app)
--   * The owner is always the signed-in user; the session must be theirs.
--   * An active employee account only.
--   * The visit time is the phone's time, never in the future, and must fall
--     inside the duty session (so a late upload from a phone that was offline is
--     fine, but a made-up time is not).
--   * At most 100 visits per duty.
--   * Sending the same visit twice (same id) is harmless: it is ignored.
--   * duty_sessions.visits_count is recomputed by a trigger, so attendance,
--     route and reports show real numbers.
--
-- Backward compatible and idempotent. Rollback:
--   drop table if exists public.visits;
--   drop function if exists private.visits_before_insert();
--   drop function if exists private.visits_after_insert();
--   (then re-run: update public.duty_sessions set visits_count = 0;)
-- =============================================================================

create table if not exists public.visits (
  -- Made on the phone, so a retried upload is recognised as a duplicate.
  id                uuid primary key,
  employee_id       uuid not null references public.profiles (id) on delete cascade,
  session_id        uuid not null references public.duty_sessions (id) on delete cascade,
  store_name        text check (store_name is null or char_length(store_name) between 1 and 80),
  note              text check (note is null or char_length(note) between 1 and 200),
  latitude          double precision not null check (latitude between -90 and 90),
  longitude         double precision not null check (longitude between -180 and 180),
  accuracy          double precision check (accuracy is null or accuracy >= 0),
  -- When it happened (the phone's time, held inside the duty session).
  captured_at       timestamptz not null,
  -- When the server received it.
  created_at        timestamptz not null default now(),
  -- Cloudinary public_id; null means no photo. Written only by the server.
  photo_public_id   text,
  photo_attached_at timestamptz,
  photo_removed_at  timestamptz,
  constraint visits_photo_state check (photo_public_id is null or photo_removed_at is null)
);

-- The admin's list for one employee, newest first (keyset on captured_at, id).
create index if not exists idx_visits_employee_captured
  on public.visits (employee_id, captured_at desc, id desc);
-- Counting visits per duty, and the foreign key.
create index if not exists idx_visits_session on public.visits (session_id);
-- The 90-day photo clean-up only looks at rows that still have a photo.
create index if not exists idx_visits_photo_due
  on public.visits (created_at) where photo_public_id is not null;

alter table public.visits enable row level security;

drop policy if exists "Employees can view own visits" on public.visits;
create policy "Employees can view own visits"
  on public.visits for select to authenticated
  using (employee_id = (select auth.uid()));

drop policy if exists "Admins can view all visits" on public.visits;
create policy "Admins can view all visits"
  on public.visits for select to authenticated
  using ((select public.is_admin()));

drop policy if exists "Employees can add own visits" on public.visits;
create policy "Employees can add own visits"
  on public.visits for insert to authenticated
  with check (employee_id = (select auth.uid()));
-- No update or delete policy for anyone: visits are history (BR-15).

-- Column-level grants: an employee can send only these columns. The owner, the
-- server time and every photo column are out of their reach (and the trigger
-- below overwrites them as well, as a second lock).
revoke all on public.visits from anon, authenticated;
grant select on public.visits to authenticated;
grant insert (id, session_id, store_name, note, latitude, longitude, accuracy, captured_at)
  on public.visits to authenticated;

-- -----------------------------------------------------------------------------
-- Before insert: ownership, time and limits
-- -----------------------------------------------------------------------------
create or replace function private.visits_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status  text;
  v_owner   uuid;
  v_started timestamptz;
  v_ended   timestamptz;
  v_count   int;
begin
  -- Empty text is no text.
  new.store_name := nullif(btrim(new.store_name), '');
  new.note := nullif(btrim(new.note), '');

  -- Server jobs (no JWT) are trusted.
  if auth.uid() is null then
    return new;
  end if;

  new.employee_id := auth.uid();

  select status into v_status
    from public.profiles
   where id = auth.uid() and role = 'employee';
  if v_status is distinct from 'active' then
    raise exception 'account_not_active' using errcode = 'P0001';
  end if;

  select employee_id, started_at, ended_at
    into v_owner, v_started, v_ended
    from public.duty_sessions
   where id = new.session_id;
  if v_owner is null or v_owner <> auth.uid() then
    raise exception 'session_not_found' using errcode = 'P0001';
  end if;

  -- The phone's time is believed only inside the duty session, never ahead of
  -- the server.
  new.captured_at := least(new.captured_at, now());
  if new.captured_at < v_started - interval '1 minute'
     or new.captured_at > coalesce(v_ended, now()) + interval '5 minutes' then
    raise exception 'visit_outside_session' using errcode = 'P0001';
  end if;

  select count(*) into v_count from public.visits where session_id = new.session_id;
  if v_count >= 100 then
    raise exception 'visit_limit' using errcode = 'P0001';
  end if;

  new.created_at := now();
  new.photo_public_id := null;
  new.photo_attached_at := null;
  new.photo_removed_at := null;
  return new;
end;
$$;

drop trigger if exists trg_visits_before_insert on public.visits;
create trigger trg_visits_before_insert
before insert on public.visits
for each row execute function private.visits_before_insert();

-- -----------------------------------------------------------------------------
-- After insert: keep duty_sessions.visits_count true
-- -----------------------------------------------------------------------------
-- Recomputed rather than incremented, so it can never drift. A visit added late
-- to a closed duty updates that duty's count too; the duty trigger allows it
-- when app.system_write is on (the same switch private.close_session uses).
create or replace function private.visits_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('app.system_write', 'on', true);
  update public.duty_sessions
     set visits_count = (
       select count(*)::int from public.visits where session_id = new.session_id
     )
   where id = new.session_id;
  perform set_config('app.system_write', 'off', true);
  return null;
end;
$$;

drop trigger if exists trg_visits_after_insert on public.visits;
create trigger trg_visits_after_insert
after insert on public.visits
for each row execute function private.visits_after_insert();

-- New functions in `private` get the default EXECUTE privilege; close it again
-- (docs/06: nothing in `private` is reachable by the API roles).
revoke execute on all functions in schema private from public, anon, authenticated;
