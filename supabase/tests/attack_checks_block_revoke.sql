-- =============================================================================
-- Attack checks for 20261019200000_block_revokes_sign_in.sql
--
-- Run AFTER the migration is applied, in the Supabase SQL editor, in its own tab.
-- Everything it creates is rolled back by the intentional error at the end.
--
-- HOW TO READ THE RESULT
--   The script ends with an intentional error whose text is the full report:
--   one PASS or FAIL line per check, then a RESULT line. Any FAIL means: do not
--   rely on the migration. (docs/05 section 4: "Policies are not trusted until
--   attacked.")
-- =============================================================================
begin;

create or replace function pg_temp.note(p_line text) returns void
language plpgsql as $$
begin
  perform set_config('attack.report',
    coalesce(current_setting('attack.report', true), '') || E'\n' || p_line, true);
end $$;

create or replace function pg_temp.check(p_ok boolean, p_label text) returns void
language plpgsql as $$
begin
  perform pg_temp.note(case when coalesce(p_ok, false) then 'PASS  ' else 'FAIL  ' end || p_label);
end $$;

create or replace function pg_temp.act_as(p_uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create or replace function pg_temp.act_as_server() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'postgres', true);
end $$;

do $$
declare
  v_admin uuid := gen_random_uuid();
  v_e1    uuid := gen_random_uuid();   -- will be blocked, has two sessions
  v_e2    uuid := gen_random_uuid();   -- bystander, must be untouched
  v_e3    uuid := gen_random_uuid();   -- blocked with no session at all
  v_ses1a uuid := gen_random_uuid();
  v_ses1b uuid := gen_random_uuid();
  v_ses2  uuid := gen_random_uuid();
  v_n     int;
  v_ban   timestamptz;
begin
  perform pg_temp.act_as_server();

  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                          created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'br-' || n || '@staff.test.invalid', 'x', now(),
         json_build_object('role', case when n = 1 then 'admin' else 'employee' end)::jsonb,
         '{}', now(), now()
  from unnest(array[v_admin, v_e1, v_e2, v_e3]) with ordinality as t(u, n);

  insert into public.profiles (id, email, role, status, full_name, must_change_pin)
  values (v_admin, 'br-1@staff.test.invalid', 'admin', 'active', 'BR Admin', false);
  insert into public.profiles (id, email, role, status, full_name, employee_code, phone, must_change_pin)
  values
    (v_e1, 'br-2@staff.test.invalid', 'employee', 'active', 'BR Test 2', 'BR-002', '+910000099002', false),
    (v_e2, 'br-3@staff.test.invalid', 'employee', 'active', 'BR Test 3', 'BR-003', '+910000099003', false),
    (v_e3, 'br-4@staff.test.invalid', 'employee', 'active', 'BR Test 4', 'BR-004', '+910000099004', false);

  insert into auth.sessions (id, user_id) values
    (v_ses1a, v_e1), (v_ses1b, v_e1), (v_ses2, v_e2);
  insert into auth.refresh_tokens (token, user_id, session_id, revoked) values
    ('br-tok-1a', v_e1::text, v_ses1a, false),
    ('br-tok-1b', v_e1::text, v_ses1b, false),
    ('br-tok-2',  v_e2::text, v_ses2,  false);

  perform pg_temp.check(
    (select count(*) from auth.sessions where user_id = v_e1) = 2
      and (select banned_until from auth.users where id = v_e1) is null,
    'setup: the person has two sessions and is not banned');

  -- 1. An admin blocks employee 1.
  perform pg_temp.act_as(v_admin);
  update public.profiles set status = 'blocked', blocked_reason = 'br attack test' where id = v_e1;
  perform pg_temp.act_as_server();

  select count(*) into v_n from auth.sessions where user_id = v_e1;
  perform pg_temp.check(v_n = 0, format('block: all of their sessions are deleted (%s left)', v_n));
  select count(*) into v_n from auth.refresh_tokens where user_id = v_e1::text;
  perform pg_temp.check(v_n = 0, format('block: their refresh tokens are gone, so no new access token (%s left)', v_n));
  select banned_until into v_ban from auth.users where id = v_e1;
  perform pg_temp.check(v_ban > now() + interval '50 years',
    format('block: the login is banned for the long term (%s)', v_ban));

  -- 2. A bystander is untouched.
  perform pg_temp.check(
    (select count(*) from auth.sessions where user_id = v_e2) = 1
      and (select count(*) from auth.refresh_tokens where user_id = v_e2::text) = 1
      and (select banned_until from auth.users where id = v_e2) is null,
    'bystander: another employee''s session, token and login are untouched');

  -- 3. Blocking someone with no session works and bans them.
  perform pg_temp.act_as(v_admin);
  update public.profiles set status = 'blocked', blocked_reason = 'br attack test' where id = v_e3;
  perform pg_temp.act_as_server();
  perform pg_temp.check(
    (select banned_until from auth.users where id = v_e3) > now() + interval '50 years',
    'block: someone with no session is still banned');

  -- 4. Saving the blocked profile again does not do anything new or fail.
  perform pg_temp.act_as(v_admin);
  update public.profiles set blocked_reason = 'br attack test again' where id = v_e1;
  perform pg_temp.act_as_server();
  perform pg_temp.check(
    (select banned_until from auth.users where id = v_e1) > now() + interval '50 years',
    'block: editing an already blocked profile keeps the ban');

  -- 5. Unblocking lifts the ban.
  perform pg_temp.act_as(v_admin);
  update public.profiles set status = 'active', blocked_reason = null where id = v_e1;
  perform pg_temp.act_as_server();
  perform pg_temp.check(
    (select banned_until from auth.users where id = v_e1) is null,
    'unblock: the ban is lifted');
  perform pg_temp.check(
    (select banned_until from auth.users where id = v_e3) > now() + interval '50 years',
    'unblock: only the unblocked person is freed');

  -- 6. An employee cannot block anyone (the existing rule still holds).
  perform pg_temp.act_as(v_e2);
  begin
    update public.profiles set status = 'blocked' where id = v_e1;
    get diagnostics v_n = row_count;
    perform pg_temp.check(v_n = 0, 'access: an employee''s attempt to block someone changed nothing');
  exception when others then
    perform pg_temp.check(true, format('access: an employee cannot block someone (%s)', sqlerrm));
  end;
  perform pg_temp.act_as_server();
  perform pg_temp.check(
    (select banned_until from auth.users where id = v_e1) is null,
    'access: and no ban was set by that attempt');

  perform pg_temp.act_as_server();
  raise exception E'BLOCK-REVOKE ATTACK CHECK REPORT (intentional error: rolls everything back)\n%\n\nRESULT: % passed, % failed\n%',
    current_setting('attack.report', true),
    regexp_count(current_setting('attack.report', true), E'\nPASS  '),
    regexp_count(current_setting('attack.report', true), E'\nFAIL  '),
    case when regexp_count(current_setting('attack.report', true), E'\nFAIL  ') > 0
         then '>>> DO NOT RELY ON THIS MIGRATION <<<' else '>>> ALL CHECKS PASSED <<<' end;
end $$;

rollback;
