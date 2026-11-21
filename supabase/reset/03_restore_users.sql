-- STEP 3 of 3. Run once in the Supabase SQL editor, after step 2 (the new
-- schema: every file in supabase/migrations, oldest first).
--
-- Brings the kept users into the new profiles table and marks every employee
-- to set a new password: their old PIN logins cannot work with the new
-- sign-in, so the admin gives each one a temporary PIN in phase 3.

begin;

with codes as (
  select
    b.*,
    -- The old employee code is the new user ID. Admins had none: use the part
    -- of their email before the @, cleaned to the allowed characters.
    coalesce(
      nullif(regexp_replace(b.employee_code, '[^A-Za-z0-9_-]', '', 'g'), ''),
      nullif(left(regexp_replace(lower(split_part(b.email, '@', 1)), '[^a-z0-9_-]', '', 'g'), 20), ''),
      'user' || left(replace(b.id::text, '-', ''), 8)) as code
  from reset_backup.profiles b
  join auth.users u on u.id = b.id
), numbered as (
  -- Two users with the same ID (hasan@a.com and hasan@b.com) would stop the
  -- whole restore: the second one becomes hasan-2, the third hasan-3 (L97).
  select c.*, row_number() over (partition by lower(c.code) order by c.created_at, c.id) as n
  from codes c
)
insert into public.profiles (id, user_code, full_name, phone, contact_email, role, is_active, created_at)
select
  b.id,
  case when b.n = 1 then b.code else left(b.code, 17) || '-' || b.n end,
  left(b.full_name, 80),
  case when b.phone ~ '^\+?[0-9]{7,15}$' then b.phone end,
  b.contact_email,
  b.role::public.app_role,
  b.status = 'active',
  b.created_at
from numbered b
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
    values ('20261120000000', 'rewrite_baseline'),
           ('20261121000000', 'login_and_devices'),
           ('20261122000000', 'duty_tracking'),
           ('20261123000000', 'maps'),
           ('20261124000000', 'requests_push'),
           ('20261125000000', 'visits'),
           ('20261126000000', 'duty_on_permit')
    on conflict do nothing;
  end if;
end;
$$;

-- Phone push: where the database sends each new notification.
insert into private.app_settings (key, value)
values ('push_url', 'https://bljroionzwxxsgmyituh.supabase.co/functions/v1/push')
on conflict (key) do update set value = excluded.value;

-- Old photos: where the nightly job asks for photos past 90 days to be deleted.
insert into private.app_settings (key, value)
values ('photos_url', 'https://bljroionzwxxsgmyituh.supabase.co/functions/v1/photos')
on conflict (key) do update set value = excluded.value;

commit;

-- Check: every kept user is listed once.
select user_code, full_name, role, is_active from public.profiles order by role, user_code;
