-- STEP 3 of 3. Run once in the Supabase SQL editor, after step 2 (the new
-- schema, supabase/migrations/20261120000000_rewrite_baseline.sql).
--
-- Brings the kept users into the new profiles table and marks every employee
-- to set a new password: their old PIN logins cannot work with the new
-- sign-in, so the admin gives each one a temporary PIN in phase 3.

begin;

insert into public.profiles (id, user_code, full_name, phone, contact_email, role, is_active, created_at)
select
  b.id,
  -- The old employee code is the new user ID. Admins had none: use the part of
  -- their email before the @, cleaned to the allowed characters.
  coalesce(
    nullif(regexp_replace(b.employee_code, '[^A-Za-z0-9_-]', '', 'g'), ''),
    nullif(left(regexp_replace(lower(split_part(b.email, '@', 1)), '[^a-z0-9_-]', '', 'g'), 20), ''),
    'user' || left(replace(b.id::text, '-', ''), 8)),
  left(b.full_name, 80),
  case when b.phone ~ '^\+?[0-9]{7,15}$' then b.phone end,
  b.contact_email,
  b.role::public.app_role,
  b.status = 'active',
  b.created_at
from reset_backup.profiles b
join auth.users u on u.id = b.id
order by b.created_at;

update auth.users u set raw_app_meta_data =
  coalesce(u.raw_app_meta_data, '{}'::jsonb)
  || jsonb_build_object('role', p.role::text, 'must_change_password', p.role = 'employee')
from public.profiles p
where p.id = u.id;

do $$
begin
  if to_regclass('supabase_migrations.schema_migrations') is not null then
    insert into supabase_migrations.schema_migrations (version, name)
    values ('20261120000000', 'rewrite_baseline')
    on conflict do nothing;
  end if;
end;
$$;

commit;

-- Check: every kept user is listed once.
select user_code, full_name, role, is_active from public.profiles order by role, user_code;
