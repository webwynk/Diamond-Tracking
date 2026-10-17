-- =============================================================================
-- Migration: 20261017040000_cleanup_signup_trigger_and_grants.sql
-- Description: Remove what the audit of 2026-10-17 found dead or too generous.
-- Nothing here is applied until the owner approves it.
--
-- Findings behind it
--   A. public.handle_new_user() and its trigger on auth.users are dead in the
--      real flow. The auth service writes app_metadata AFTER it inserts a user,
--      so the trigger never sees an employee's details (the first real attempt
--      proved it), and the first admin is made by supabase/manual/
--      create_first_admin.sql, which inserts the profile itself. Only test
--      fixtures reached it. Profiles are now created by exactly two things: the
--      create-employee function (service role) and that manual script.
--   B. Every table in public granted ALL privileges to anon and authenticated.
--      Row-level security was the only barrier, and TRUNCATE and TRIGGER are not
--      covered by it. The app needs far less (see the list below).
--   C. The admin INSERT policy on profiles is unused (see A).
--   D. The private helper and trigger functions granted EXECUTE to everyone.
--      They were already unreachable (the API roles have no access to the
--      private schema); this is a second layer.
--
-- What each role keeps after this migration
--   anon           nothing in public
--   authenticated  profiles          SELECT, UPDATE   (RLS: own row / admins)
--                  duty_sessions     SELECT, INSERT, UPDATE
--                  location_points   SELECT, INSERT   (append-only, BR-15)
--                  live_locations    SELECT           (written by triggers only)
--                  audit_log         SELECT           (admins; written by the
--                                                      server only)
--   service_role   unchanged
--
-- Forward-only and idempotent: safe to run twice.
--
-- Rollback (manual): grant the removed privileges back to anon/authenticated,
-- recreate public.handle_new_user() and trigger on_auth_user_created from
-- 20261017010000_profiles_contact_email.sql, recreate the policy
-- "Admins can insert profiles" (admin check on profiles) from
-- 20261016000000_complete_app_schema.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. The dead new-user trigger and function (finding A)
-- -----------------------------------------------------------------------------
-- After this, a login made any other way (the dashboard "Add user", a self
-- sign-up) simply has no profile, and therefore no access: the rule we want.
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 2. The unused profile INSERT policy (finding C)
-- -----------------------------------------------------------------------------
drop policy if exists "Admins can insert profiles" on public.profiles;

-- -----------------------------------------------------------------------------
-- 3. Privileges: only what the app uses (finding B)
-- -----------------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon, authenticated;

-- Nobody signed in deletes, truncates, adds triggers to or references anything.
revoke delete, truncate, trigger, references on all tables in schema public from authenticated;

-- Written by the server or by triggers, never directly by a signed-in user.
revoke insert, update on public.audit_log from authenticated;
revoke insert, update on public.live_locations from authenticated;
-- Profiles are created by the create-employee function and the manual admin
-- script, both outside the API roles.
revoke insert on public.profiles from authenticated;
-- History is append-only (BR-15): no UPDATE privilege on points either.
revoke update on public.location_points from authenticated;

-- -----------------------------------------------------------------------------
-- 4. Private functions: not executable by the API roles (finding D)
-- -----------------------------------------------------------------------------
revoke execute on all functions in schema private from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 5. Future tables start closed
-- -----------------------------------------------------------------------------
-- Objects created from now on by this role no longer grant anything to anon or
-- authenticated automatically: every new table must say who may touch it
-- (docs/06 section 3).
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
