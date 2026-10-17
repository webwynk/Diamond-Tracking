-- =============================================================================
-- Checks for 20261018010000_visit_photo_purge_job.sql
--
-- Run AFTER the migration is applied AND supabase/manual/store_purge_token.sql
-- has been run, in the Supabase SQL editor, in its own tab.
--
-- It does NOT call the clean-up (that would really delete photos older than 90
-- days); it checks that everything is in place and closed to the outside.
-- The script ends with an intentional error whose text is the report.
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

create or replace function pg_temp.act_as_anon() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  perform set_config('role', 'anon', true);
end $$;

create or replace function pg_temp.act_as_server() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'postgres', true);
end $$;

do $$
declare
  v_n int;
  v_msg text;
begin
  perform pg_temp.act_as_server();

  perform pg_temp.check(
    exists (select 1 from pg_extension where extname = 'pg_net'),
    'plumbing: the pg_net extension is installed');

  perform pg_temp.check(
    exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'private' and p.proname = 'purge_visit_photos'),
    'plumbing: private.purge_visit_photos exists');

  perform pg_temp.check(
    (select count(*) from cron.job
      where jobname = 'purge-visit-photos' and schedule = '30 22 * * *' and active) = 1,
    'plumbing: the nightly job is scheduled once, at 22:30 UTC (04:00 IST)');

  perform pg_temp.check(
    (select command from cron.job where jobname = 'purge-visit-photos')
      = 'select private.purge_visit_photos()',
    'plumbing: the job runs only that function');

  select count(*) into v_n
    from vault.decrypted_secrets
   where name = 'purge_token' and decrypted_secret is not null and decrypted_secret <> '';
  perform pg_temp.check(v_n = 1,
    'vault: the purge_token secret is stored (once, not empty)');

  perform pg_temp.check(
    (select decrypted_secret from vault.decrypted_secrets where name = 'purge_token')
      <> 'PASTE-YOUR-PURGE-TOKEN-HERE',
    'vault: the stored token is not the placeholder from the template');

  select count(*) into v_n
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'private'
     and (has_function_privilege('anon', p.oid, 'EXECUTE')
          or has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  perform pg_temp.check(v_n = 0,
    format('access: no function in the private schema is open to the API roles (%s open)', v_n));

  -- A signed-in user and a visitor cannot run the clean-up or read the token.
  perform pg_temp.act_as(gen_random_uuid());
  begin
    perform private.purge_visit_photos();
    perform pg_temp.check(false, 'access: a signed-in user ran the photo clean-up');
  exception when others then
    perform pg_temp.check(true, format('access: a signed-in user cannot run it (%s)', sqlerrm));
  end;
  begin
    perform 1 from vault.decrypted_secrets;
    perform pg_temp.check(false, 'access: a signed-in user read the vault');
  exception when others then
    perform pg_temp.check(true, format('access: a signed-in user cannot read the vault (%s)', sqlerrm));
  end;

  perform pg_temp.act_as_anon();
  begin
    perform private.purge_visit_photos();
    perform pg_temp.check(false, 'access: a visitor ran the photo clean-up');
  exception when others then
    perform pg_temp.check(true, format('access: a visitor cannot run it (%s)', sqlerrm));
  end;
  begin
    perform 1 from vault.decrypted_secrets;
    perform pg_temp.check(false, 'access: a visitor read the vault');
  exception when others then
    perform pg_temp.check(true, format('access: a visitor cannot read the vault (%s)', sqlerrm));
  end;

  perform pg_temp.act_as_server();
  raise exception E'PHOTO PURGE JOB CHECK REPORT (intentional error: rolls everything back)\n%\n\nRESULT: % passed, % failed\n%',
    current_setting('attack.report', true),
    regexp_count(current_setting('attack.report', true), E'\nPASS  '),
    regexp_count(current_setting('attack.report', true), E'\nFAIL  '),
    case when regexp_count(current_setting('attack.report', true), E'\nFAIL  ') > 0
         then '>>> DO NOT RELY ON THIS MIGRATION <<<' else '>>> ALL CHECKS PASSED <<<' end;
end $$;

rollback;
