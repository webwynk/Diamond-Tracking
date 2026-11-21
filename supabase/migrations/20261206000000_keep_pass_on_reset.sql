-- L13: a password reset after 11 PM no longer loses the day's last points.
--
-- A reset (or the admin's Release phone) used to delete the phone's upload
-- passes. During the day the app gets a new pass by resuming the duty, but
-- after 11 PM the duty is closed and cannot be resumed, so points still
-- waiting on the phone were thrown away.
-- Now the pass is kept. It stays safe: a pass only works while the phone it
-- was given to is the one signed in (check_upload_pass), so it is refused
-- until that same phone signs in again, and for good once another phone
-- does. The app keeps refused points for up to 2 days (how long a pass
-- lives) and sends them once the phone is signed in again.

create or replace function private.revoke_sessions(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from auth.sessions where user_id = p_user;
  update public.profiles set active_device_id = null, active_session_id = null
  where id = p_user;
  delete from private.push_tokens where user_id = p_user;
end;
$$;
