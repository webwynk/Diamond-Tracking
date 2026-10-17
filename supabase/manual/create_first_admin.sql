-- =============================================================================
-- One-off: make the FIRST admin. Run once in the Supabase SQL editor.
--
-- 1. Dashboard > Authentication > Users > "Add user" > "Create new user"
--    Use your real admin email and a strong password that only you know.
--    (Tick "Auto Confirm User".) Do NOT reuse any password from this repo.
-- 2. Replace the email below with that email, then run this script.
--
-- It gives that login an admin profile and marks it admin in app_metadata
-- (which users cannot edit). Later admins are created the same way.
-- =============================================================================
do $$
declare
  v_email text := 'CHANGE-ME@yourcompany.com';   -- <<< your admin email
  v_name  text := 'Operations Admin';             -- <<< display name
  v_id    uuid;
begin
  select id into v_id from auth.users where email = v_email;
  if v_id is null then
    raise exception 'No auth user with email %. Create it in the dashboard first.', v_email;
  end if;

  update auth.users
     set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
   where id = v_id;

  insert into public.profiles (id, email, role, status, full_name, must_change_pin)
  values (v_id, v_email, 'admin', 'active', v_name, false)
  on conflict (id) do update
    set role = 'admin', status = 'active', must_change_pin = false;

  raise notice 'Admin ready: % (%)', v_email, v_id;
end $$;
