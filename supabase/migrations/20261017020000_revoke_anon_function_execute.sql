-- =============================================================================
-- Migration: 20261017020000_revoke_anon_function_execute.sql
-- Description: Close the Supabase security-advisor findings about SECURITY
-- DEFINER functions that signed-out visitors could call through /rest/v1/rpc.
--
--   * update_updated_at_column() is a trigger function. Nobody should call it
--     through the API; triggers keep working without EXECUTE for API roles.
--   * is_admin(), bind_my_device(), complete_pin_change() are only meant for
--     signed-in users. No policy that applies to anon or public uses them.
--
-- Forward-only, idempotent.
-- =============================================================================

revoke execute on function public.update_updated_at_column() from public, anon, authenticated;

revoke execute on function public.is_admin() from public, anon;
revoke execute on function public.bind_my_device(text) from public, anon;
revoke execute on function public.complete_pin_change() from public, anon;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.bind_my_device(text) to authenticated;
grant execute on function public.complete_pin_change() to authenticated;
