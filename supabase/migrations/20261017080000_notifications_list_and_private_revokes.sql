-- =============================================================================
-- Migration: 20261017080000_notifications_list_and_private_revokes.sql
-- Description: (1) one paged, filtered read of notifications for the admin app;
-- (2) take EXECUTE away from every function in the private schema, again.
-- Nothing here is applied until the owner approves it.
--
-- Why (1)
--   The first version of the admin app read the newest 50 notifications and
--   counted "unread" among them, so the bell badge was wrong as soon as more
--   than 50 were waiting, older ones could never be reached, and the Unread /
--   Duty / Alerts filters only saw those 50. This function returns one page,
--   newest first, with whether THIS admin has read each one, and applies the
--   filters (unread only, types, employees) BEFORE the page is cut, so paging is
--   correct under every filter. SECURITY INVOKER: the row-level rules decide, so
--   an employee, a signed-out visitor and a blocked admin get nothing.
--
-- Why (2)
--   The notification trigger functions created in 20261017070000 were left with
--   the default EXECUTE privilege for public/anon/authenticated. They cannot be
--   reached (the private schema is closed to the API roles) but the project rule
--   (docs/06 section 3) is that nothing in private is executable by the API
--   roles. Trigger functions run with the trigger's owner and do not need the
--   caller to hold EXECUTE, so tracking is unaffected.
--
-- Backward compatible and idempotent. Rollback:
--   drop function if exists public.list_notifications(bigint, int, boolean, text[], uuid[]);
--   (the revokes need no rollback)
-- =============================================================================

create or replace function public.list_notifications(
  p_before      bigint  default null,
  p_limit       int     default 30,
  p_unread_only boolean default false,
  p_types       text[]  default null,
  p_employees   uuid[]  default null
)
returns table (
  id          bigint,
  type        text,
  employee_id uuid,
  session_id  uuid,
  details     jsonb,
  created_at  timestamptz,
  is_read     boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
  select n.id, n.type, n.employee_id, n.session_id, n.details, n.created_at,
         exists (
           select 1 from public.notification_reads r
           where r.notification_id = n.id and r.admin_id = (select auth.uid())
         ) as is_read
  from public.notifications n
  where (p_before is null or n.id < p_before)
    and (p_types is null or n.type = any (p_types))
    and (p_employees is null or n.employee_id = any (p_employees))
    and (
      not p_unread_only
      or not exists (
        select 1 from public.notification_reads r
        where r.notification_id = n.id and r.admin_id = (select auth.uid())
      )
    )
  order by n.id desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;

revoke all on function public.list_notifications(bigint, int, boolean, text[], uuid[])
  from public, anon;
grant execute on function public.list_notifications(bigint, int, boolean, text[], uuid[])
  to authenticated;

revoke execute on all functions in schema private from public, anon, authenticated;
