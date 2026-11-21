-- File 13 of the 2026-11-20 review, L84: PDF report exports go into the
-- admin log, as in the old app ("every export audited"). The app calls this
-- after it has made the PDF.

create function public.log_report_export(
  p_from date, p_to date, p_detail boolean, p_people integer
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_admin uuid := private.require_admin();
begin
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'validation_failed' using errcode = '22023';
  end if;
  insert into public.admin_log (admin_id, action, target_user, details)
  values (v_admin, 'export_report', null, jsonb_build_object(
    'from', p_from, 'to', p_to,
    'detail', coalesce(p_detail, false),
    'people', greatest(coalesce(p_people, 0), 0)));
end;
$$;

revoke all on function public.log_report_export(date, date, boolean, integer) from public, anon;
grant execute on function public.log_report_export(date, date, boolean, integer)
  to authenticated, service_role;
