-- =============================================================================
-- Migration: 20261017090000_log_report_export.sql
-- Description: Let an admin record that they exported a report (PRD F13).
-- Nothing here is applied until the owner approves it.
--
-- Why
--   Reports carry personal data (names, hours, distances). docs/05 requires
--   every export to be traceable to the admin who made it. The reports are built
--   on the admin's phone, so the database never sees the file; this records the
--   fact of the export. The app writes it BEFORE it hands the file over, and
--   hands nothing over if this call fails ("no audit, no export").
--
-- Why a function and not an INSERT policy
--   audit_log has no insert policy on purpose: the app can never write to it
--   directly, or an admin could invent entries. This function is the only way
--   in, it takes the admin from the signed-in session (never from a parameter),
--   and it validates every input.
--
-- Who may call it
--   Signed-in, active admins only. An employee, a blocked admin and a signed-out
--   visitor are refused, and nothing is written for them.
--
-- Backward compatible and idempotent. Rollback:
--   drop function if exists public.log_report_export(text, date, date, text, uuid);
-- =============================================================================

create or replace function public.log_report_export(
  p_type     text,
  p_from     date,
  p_to       date,
  p_format   text,
  p_employee uuid default null
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if p_type is null or p_type not in ('daily_detail', 'employee_summary', 'team_summary') then
    raise exception 'invalid_report' using errcode = '22023', detail = 'type';
  end if;
  if p_format is null or p_format not in ('pdf', 'excel') then
    raise exception 'invalid_report' using errcode = '22023', detail = 'format';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'invalid_report' using errcode = '22023', detail = 'period';
  end if;
  -- A longer range is not something the app offers (31 days team, 62 employee).
  if p_to - p_from > 91 then
    raise exception 'invalid_report' using errcode = '22023', detail = 'period_too_long';
  end if;
  if p_type = 'daily_detail' and p_to <> p_from then
    raise exception 'invalid_report' using errcode = '22023', detail = 'period';
  end if;

  if p_type = 'employee_summary' then
    select employee_code into v_code
      from public.profiles
     where id = p_employee and role = 'employee';
    if not found then
      raise exception 'invalid_report' using errcode = '22023', detail = 'employee';
    end if;
  elsif p_employee is not null then
    raise exception 'invalid_report' using errcode = '22023', detail = 'employee';
  end if;

  insert into public.audit_log (actor_id, action, target_id, details)
  values (
    auth.uid(),
    'report_exported',
    p_employee,
    jsonb_strip_nulls(jsonb_build_object(
      'type', p_type,
      'format', p_format,
      'from', p_from,
      'to', p_to,
      'employee_code', v_code
    ))
  );
end;
$$;

revoke all on function public.log_report_export(text, date, date, text, uuid) from public, anon;
grant execute on function public.log_report_export(text, date, date, text, uuid) to authenticated;
