-- =============================================================================
-- Script: record_migrations_and_set_temp_pins.sql
-- Description:
--   1. Record migrations 20261019200000 and 20261020000000 in migration history
--   2. Set valid temporary PINs for existing employees (DA-100, DA-88, DA-99)
--      with must_change_pin = true so they are forced to change PIN on next login.
--
-- PIN Rules enforced by private.pin_problem():
--   - Exactly 6 digits
--   - Not a single repeated digit (e.g. 111111)
--   - Not an ascending or descending sequence (e.g. 123456, 654321, 890123)
--
-- Temporary PIN assignments:
--   DA-100 -> 482915
--   DA-88  -> 739204
--   DA-99  -> 852147
--
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Record the two migrations in schema history
-- -----------------------------------------------------------------------------
insert into supabase_migrations.schema_migrations (version, name) values
  ('20261019200000', 'block_revokes_sign_in'),
  ('20261020000000', 'server_checked_pin')
on conflict (version) do nothing;

-- -----------------------------------------------------------------------------
-- 2. Set temporary PINs (must_change_pin = true)
-- -----------------------------------------------------------------------------
select public.set_employee_pin(id, '482915', true)
from public.profiles
where upper(employee_code) = 'DA-100';

select public.set_employee_pin(id, '739204', true)
from public.profiles
where upper(employee_code) = 'DA-88';

select public.set_employee_pin(id, '852147', true)
from public.profiles
where upper(employee_code) = 'DA-99';

-- -----------------------------------------------------------------------------
-- 3. Verification checks (output returned in SQL editor)
-- -----------------------------------------------------------------------------
-- Check migrations recorded:
select version, name
from supabase_migrations.schema_migrations
where version in ('20261019200000', '20261020000000')
order by version asc;

-- Check employee profiles and pin hashes:
select
  p.employee_code,
  p.full_name,
  p.must_change_pin,
  p.failed_login_attempts,
  p.locked_until,
  (ep.pin_hash is not null) as has_pin_hash,
  ep.changed_at
from public.profiles p
left join private.employee_pins ep on ep.user_id = p.id
where upper(p.employee_code) in ('DA-100', 'DA-88', 'DA-99')
order by p.employee_code;
