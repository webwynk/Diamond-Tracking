-- =============================================================================
-- Migration: 20261019175510_duty_session_text_limits.sql
-- Description: Limit the two free-text columns of duty_sessions that an
--              employee can write (audit Step 3, finding M5).
--
-- Why
--   An employee may update their own open session to end it, and the update
--   policy lets them set end_reason and notes. Nothing limited either column:
--   a modified client could store any text of any length, and end_reason is
--   shown to admins (it is copied into the duty-off notification). The trigger
--   already protects owner, start time, counts, distance and status.
--
-- What
--   end_reason  must be NULL or one of the three values the system writes:
--                 'normal'       an employee ended duty
--                 'auto_curfew'  the 23:00 IST auto-end
--                 'blocked'      closed because the account was blocked
--   notes       must be NULL or at most 200 characters. The longest text the
--                 app or the database writes today is 38 characters.
--
-- Safe to apply
--   Every existing row passes (checked on 2026-10-19: 4 'normal', 1
--   'auto_curfew', longest note 24 characters). The app sends only 'normal' and
--   'auto_curfew'. Idempotent: re-running changes nothing.
--
-- Rollback
--   alter table public.duty_sessions
--     drop constraint if exists duty_sessions_end_reason_check,
--     drop constraint if exists duty_sessions_notes_length_check;
-- =============================================================================

alter table public.duty_sessions
  drop constraint if exists duty_sessions_end_reason_check,
  drop constraint if exists duty_sessions_notes_length_check;

alter table public.duty_sessions
  add constraint duty_sessions_end_reason_check
    check (end_reason is null
           or end_reason in ('normal', 'auto_curfew', 'blocked')),
  add constraint duty_sessions_notes_length_check
    check (notes is null or char_length(notes) <= 200);
