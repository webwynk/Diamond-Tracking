-- =============================================================================
-- Migration: 20261019200000_block_revokes_sign_in.sql
-- Description: Blocking a person also ends their sign-in (audit Step 6a).
--
-- Why
--   Blocking already closed the open duty and removed the live marker
--   (private.profiles_after_block), but the person's Supabase sign-in stayed
--   valid: their phone kept a working session and could refresh it for ever.
--   docs/05 section 3 and BR-6 say a block must end the session too.
--
-- What
--   When a profile becomes 'blocked':
--     1. every sign-in session of that person is deleted. Their refresh tokens
--        go with them (ON DELETE CASCADE), so the phone cannot get a new access
--        token. The access token it already holds runs out within the hour.
--     2. the login is banned (auth.users.banned_until, set 100 years ahead; the
--        Auth service refuses a banned user at sign-in and at refresh with the
--        error `user_banned`). A far date is used, not 'infinity', because the
--        Auth service reads this column into a timestamp.
--   When a profile goes from 'blocked' back to 'active', the ban is lifted.
--
-- Safe to apply
--   Only changes what happens at the moment a status changes. Nobody is blocked
--   today (checked 2026-10-19: 1 admin and 3 employees, all active). Applies to
--   admins as well as employees.
--
-- Rollback
--   Restore the previous body of private.profiles_after_block from
--   20261017030000_m3_tracking_ingest_and_session_rules.sql, and clear any ban:
--     update auth.users set banned_until = null where banned_until is not null;
-- =============================================================================

create or replace function private.profiles_after_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session uuid;
begin
  if new.status = 'blocked' and old.status is distinct from 'blocked' then
    for v_session in
      select id from public.duty_sessions
      where employee_id = new.id and ended_at is null
    loop
      perform private.close_session(
        v_session, 'blocked', 'blocked', 'Closed because the account was blocked', now()
      );
    end loop;

    -- Whatever happened above, a blocked employee must not stay on the map.
    delete from public.live_locations where employee_id = new.id;

    -- End the sign-in: no session, no refresh, no new login.
    delete from auth.sessions where user_id = new.id;
    update auth.users
       set banned_until = now() + interval '100 years'
     where id = new.id;

  elsif old.status = 'blocked' and new.status is distinct from 'blocked' then
    update auth.users set banned_until = null where id = new.id;
  end if;
  return null;
end;
$$;
