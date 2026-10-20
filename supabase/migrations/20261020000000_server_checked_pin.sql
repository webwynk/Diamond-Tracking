-- =============================================================================
-- Migration: 20261020000000_server_checked_pin.sql
-- Description: Employee PINs are checked by the server, with a lockout
--              (audit Step 6b: findings F1 login lockout, E3 and M4 PIN rules).
--
-- Why
--   Until now an employee's 6-digit PIN was their Supabase Auth password, and the
--   app signed in to Supabase Auth directly. Supabase Free has no hook that can
--   count failed passwords (the Password Verification hook is Teams-only), so
--   nothing limited guessing a PIN beyond a per-IP rate limit, and the PIN rules
--   were checked only inside the app. `profiles.failed_login_attempts` and
--   `locked_until` existed but nothing wrote them. PRD F1 asks for a lockout:
--   5 failed tries lock the account for 15 minutes and notify the admins.
--
-- How
--   * The PIN is kept as a bcrypt hash in private.employee_pins (a schema the
--     API cannot reach).
--   * The employee's real Supabase Auth password becomes a long secret derived
--     from their user id and a secret kept in the vault (login_secret). Nobody
--     knows it, so Supabase Auth cannot be guessed against directly: the only way
--     to a session is the `employee-login` Edge Function, which first asks
--     public.employee_login_check(). That function does the whole check in one
--     locked step: unknown code, blocked, locked, wrong PIN (count it, lock on
--     the 5th) or right PIN (reset the count).
--   * One rule for PINs lives here (private.pin_problem): exactly 6 digits, not
--     one repeated digit, not a run up or down that may wrap round (so 890123 is
--     refused). The app and the Edge Functions follow it.
--   * public.set_employee_pin() sets a PIN (new employee, forced first change);
--     public.admin_reset_pin() does it for an admin's reset together with the
--     audit row. Only the server key can call these functions.
--   * public.complete_pin_change() is removed: it let a signed-in employee clear
--     "must change PIN" without changing it.
--   * New notification type `account_locked` for the admins.
--
-- Existing employees
--   They have no PIN hash yet, so employee_login_check refuses them until an
--   admin resets their PIN (the "Reset PIN" action added with this change).
--   Their old Supabase password stops being used at the same moment.
--
-- Backward compatible? NO, on purpose: an app version older than this change
--   signs in to Supabase Auth directly with the PIN and will be refused. Employees
--   must install the new version.
--
-- Rollback
--   Restore complete_pin_change() (see 20261015000000), drop the functions below
--   and private.employee_pins, put the old notifications_type_check back, and set
--   each employee's Auth password again (the old PINs are not recoverable, so a
--   rollback means resetting every PIN by hand).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Where PIN hashes live, and the secret the Auth passwords are derived from
-- -----------------------------------------------------------------------------
create table if not exists private.employee_pins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  pin_hash   text not null,
  changed_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from vault.secrets where name = 'login_secret') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'login_secret',
      'Derives the Supabase Auth password of every employee. Never change or delete it: every employee would be locked out.'
    );
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 2. The PIN rule, written once
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
  v_i    int;
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

-- -----------------------------------------------------------------------------
-- 3. The Auth password derived for a person (never leaves the server)
-- -----------------------------------------------------------------------------
create or replace function private.login_password(p_user uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'login_secret';
  if v_secret is null then
    raise exception 'login_secret_missing' using errcode = 'P0001';
  end if;
  return translate(
    encode(
      extensions.hmac(convert_to(p_user::text, 'utf8'), convert_to(v_secret, 'utf8'), 'sha256'),
      'base64'),
    '+/=', '-_');
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Setting a PIN (new employee, forced change, admin reset)
-- -----------------------------------------------------------------------------
create or replace function public.set_employee_pin(
  p_user         uuid,
  p_pin          text,
  p_must_change  boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_problem text;
begin
  v_problem := private.pin_problem(p_pin);
  if v_problem is not null then
    raise exception 'pin_invalid' using errcode = 'P0001', detail = v_problem;
  end if;

  if not exists (select 1 from public.profiles where id = p_user and role = 'employee') then
    raise exception 'employee_not_found' using errcode = 'P0001';
  end if;

  insert into private.employee_pins (user_id, pin_hash)
  values (p_user, extensions.crypt(p_pin, extensions.gen_salt('bf', 10)))
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, changed_at = now();

  -- The password Supabase Auth itself holds: derived, not the PIN.
  update auth.users
     set encrypted_password = extensions.crypt(private.login_password(p_user), extensions.gen_salt('bf', 10)),
         updated_at = now()
   where id = p_user;

  update public.profiles
     set must_change_pin = coalesce(p_must_change, true),
         failed_login_attempts = 0,
         locked_until = null
   where id = p_user;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4b. An admin resets someone's PIN: the new PIN and the audit row, in one step
-- -----------------------------------------------------------------------------
create or replace function public.admin_reset_pin(
  p_actor uuid,
  p_user  uuid,
  p_pin   text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.profiles where id = p_actor and role = 'admin' and status = 'active'
  ) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  perform public.set_employee_pin(p_user, p_pin, true);

  insert into public.audit_log (actor_id, action, target_id, details)
  values (p_actor, 'employee_pin_reset', p_user,
          jsonb_build_object('employee_code',
            (select employee_code from public.profiles where id = p_user)));
end;
$$;

-- -----------------------------------------------------------------------------
-- 5. The login check: one locked step, so two tries at once cannot beat the count
-- -----------------------------------------------------------------------------
create or replace function public.employee_login_check(p_code text, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_max_tries constant int := 5;
  c_lock      constant interval := interval '15 minutes';
  v_code      text := upper(btrim(coalesce(p_code, '')));
  v_p         public.profiles%rowtype;
  v_hash      text;
  v_failed    int;
begin
  select * into v_p
  from public.profiles
  where role = 'employee' and upper(employee_code) = v_code
  for update;

  if not found then
    -- Spend the same time as a real check, and say nothing about the code.
    perform extensions.crypt(coalesce(p_pin, ''), extensions.gen_salt('bf', 10));
    return jsonb_build_object('result', 'invalid');
  end if;

  if v_p.status = 'blocked' then
    return jsonb_build_object('result', 'blocked');
  end if;

  if v_p.locked_until is not null and v_p.locked_until > now() then
    return jsonb_build_object(
      'result', 'locked',
      'retry_after_seconds', ceil(extract(epoch from (v_p.locked_until - now())))::int);
  end if;

  select pin_hash into v_hash from private.employee_pins where user_id = v_p.id;

  if v_hash is not null and extensions.crypt(coalesce(p_pin, ''), v_hash) = v_hash then
    update public.profiles
       set failed_login_attempts = 0, locked_until = null
     where id = v_p.id
       and (failed_login_attempts <> 0 or locked_until is not null);
    return jsonb_build_object(
      'result', 'ok',
      'user_id', v_p.id,
      'email', v_p.email,
      'login_password', private.login_password(v_p.id),
      'must_change_pin', v_p.must_change_pin);
  end if;

  -- Wrong PIN, or no PIN set yet (nobody gets in without one).
  if v_hash is null then
    perform extensions.crypt(coalesce(p_pin, ''), extensions.gen_salt('bf', 10));
  end if;

  v_failed := coalesce(v_p.failed_login_attempts, 0) + 1;
  if v_failed >= c_max_tries then
    update public.profiles
       set failed_login_attempts = 0, locked_until = now() + c_lock
     where id = v_p.id;
    perform private.notify(
      'account_locked', v_p.id, null,
      'account_locked:' || v_p.id::text || ':' || floor(extract(epoch from now()))::bigint::text,
      jsonb_build_object('employee_code', v_p.employee_code, 'locked_minutes', 15));
    return jsonb_build_object(
      'result', 'locked',
      'retry_after_seconds', extract(epoch from c_lock)::int);
  end if;

  update public.profiles set failed_login_attempts = v_failed where id = v_p.id;
  return jsonb_build_object('result', 'invalid');
end;
$$;

-- -----------------------------------------------------------------------------
-- 6. Who may call what: the server key only
-- -----------------------------------------------------------------------------
revoke all on function private.pin_problem(text)                      from public, anon, authenticated;
revoke all on function private.login_password(uuid)                   from public, anon, authenticated;
revoke all on function public.set_employee_pin(uuid, text, boolean)   from public, anon, authenticated;
revoke all on function public.employee_login_check(text, text)        from public, anon, authenticated;
revoke all on function public.admin_reset_pin(uuid, uuid, text)       from public, anon, authenticated;
grant execute on function public.admin_reset_pin(uuid, uuid, text)     to service_role;
grant execute on function public.set_employee_pin(uuid, text, boolean) to service_role;
grant execute on function public.employee_login_check(text, text)      to service_role;

-- -----------------------------------------------------------------------------
-- 7. The old, unsafe way to clear "must change PIN"
-- -----------------------------------------------------------------------------
drop function if exists public.complete_pin_change();

-- -----------------------------------------------------------------------------
-- 8. A new kind of notification for the admins
-- -----------------------------------------------------------------------------
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type = any (array[
    'duty_on', 'duty_off', 'duty_auto_ended', 'mock_gps',
    'battery_low', 'no_signal', 'account_locked'
  ]));
