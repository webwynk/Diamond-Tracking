-- =============================================================================
-- Migration: 20261018010000_visit_photo_purge_job.sql
-- Description: The nightly call that deletes visit photos older than 90 days.
-- Nothing here is applied until the owner approves it.
--
-- What it does
--   Every night at 04:00 IST (22:30 UTC, after the location-point clean-up) the
--   database calls the `visit-photos` Edge Function with {"action":"purge"} and
--   a secret token. The function deletes the old photos from Cloudinary and
--   marks the visit rows (the rows stay). See PRD F10 and docs/10 section 4.
--
-- Before this runs
--   1. The `visit-photos` function is deployed, with the PURGE_TOKEN secret.
--   2. The SAME token is stored once in the Vault with
--      supabase/manual/store_purge_token.sql (paste it in the SQL editor; it is
--      never written to a file or to chat).
--   Without the Vault secret the job does nothing and only logs a warning.
--
-- The call is asynchronous (pg_net). Its answer is not read here: the function
-- writes its own audit entry (`visit_photos_purged`) whenever it deleted or
-- failed to delete something.
--
-- Backward compatible and idempotent. Rollback:
--   select cron.unschedule('purge-visit-photos');
--   drop function if exists private.purge_visit_photos();
-- =============================================================================

create extension if not exists pg_net with schema extensions;

create or replace function private.purge_visit_photos()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token text;
begin
  select decrypted_secret into v_token
    from vault.decrypted_secrets
   where name = 'purge_token';

  if v_token is null or v_token = '' then
    raise warning 'purge_visit_photos: the purge_token secret is not in the vault';
    return;
  end if;

  perform net.http_post(
    url := 'https://bljroionzwxxsgmyituh.supabase.co/functions/v1/visit-photos',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-purge-token', v_token
    ),
    body := jsonb_build_object('action', 'purge'),
    timeout_milliseconds := 30000
  );
end;
$$;

-- Same name replaces the job, so running this twice leaves one job.
select cron.schedule(
  'purge-visit-photos',
  '30 22 * * *',
  $job$select private.purge_visit_photos()$job$
);

-- New functions in `private` get the default EXECUTE privilege; close it again.
revoke execute on all functions in schema private from public, anon, authenticated;
