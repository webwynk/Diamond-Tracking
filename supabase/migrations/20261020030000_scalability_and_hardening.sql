-- Migration: Scalability & Hardening (Phase 6.1)
-- Description:
--   1. Clean Supabase linter warning in private.pin_problem (unused/shadowed loop variable).
--   2. Add covering indexes for foreign keys (notifications.session_id, notification_reads.admin_id, audit_log.actor_id)
--      to eliminate unindexed FK warnings and improve query performance at scale.

-- -----------------------------------------------------------------------------
-- 1. Clean private.pin_problem
-- -----------------------------------------------------------------------------
create or replace function private.pin_problem(p_pin text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_up   boolean := true;
  v_down boolean := true;
  v_a    int;
  v_b    int;
begin
  if p_pin is null or p_pin !~ '^[0-9]{6}$' then
    return 'PIN must be exactly 6 digits';
  end if;
  if p_pin ~ '^(.)\1{5}$' then
    return 'PIN cannot be one repeated digit';
  end if;
  for v_i in 1..5 loop
    v_a := substr(p_pin, v_i, 1)::int;
    v_b := substr(p_pin, v_i + 1, 1)::int;
    if v_b <> (v_a + 1) % 10 then v_up := false; end if;
    if v_b <> (v_a + 9) % 10 then v_down := false; end if;
  end loop;
  if v_up or v_down then
    return 'PIN cannot be a simple sequence like 123456';
  end if;
  return null;
end;
$$;

revoke all on function private.pin_problem(text) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Foreign Key Covering Indexes for High-Scale Workloads
-- -----------------------------------------------------------------------------
create index if not exists idx_notifications_session_id
  on public.notifications (session_id)
  where session_id is not null;

create index if not exists idx_notification_reads_admin_id
  on public.notification_reads (admin_id);

create index if not exists idx_audit_log_actor_id
  on public.audit_log (actor_id)
  where actor_id is not null;
