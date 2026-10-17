-- =============================================================================
-- Migration: 20261017050000_admin_session_distance.sql
-- Description: Let an admin read the server's running distance of a duty session.
-- Nothing here is applied until the owner approves it.
--
-- Why
--   A session's total_distance_km is written by the server only when the session
--   closes (and again when a late upload arrives). While an employee is still on
--   duty it is 0, so the admin's route view for today had no server figure to
--   show. The calculation already exists as private.session_distance_km() (it
--   leaves out mock points, readings worse than 100 m, and moves faster than
--   55 m/s). The private schema is deliberately unreachable from the API, so
--   this adds one narrow, admin-only wrapper instead of exposing the helper or
--   measuring distance on the phone (docs/05, docs/07 section 4: distance is
--   always the server's, from the full point set).
--
-- Who may call it
--   Signed-in, active admins only. An employee, a blocked admin and a signed-out
--   visitor are refused.
--
-- Backward compatible and idempotent. Rollback:
--   drop function if exists public.admin_session_distance(uuid);
-- =============================================================================

create or replace function public.admin_session_distance(p_session uuid)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return private.session_distance_km(p_session);
end;
$$;

revoke all on function public.admin_session_distance(uuid) from public, anon;
grant execute on function public.admin_session_distance(uuid) to authenticated;
