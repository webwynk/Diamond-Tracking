-- The admin can let one employee do duty on outside the 5:00 to 8:30 AM
-- window, for today only (for example a late start, or testing).
--
--   * allow_duty_on(user, note): admin only. Valid until 11:00 PM today, once.
--   * revoke_duty_on(user): admin takes back a permission not used yet.
--   * duty_on: outside the window it needs an unused permission for today.
--     Everything else is unchanged: one duty a day, not on a leave day.
--   * The employee is told by a notification; the app then shows Duty on.

create table public.duty_permits (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  day        date not null,
  granted_by uuid references public.profiles (id) on delete set null,
  note       text check (note is null or char_length(note) <= 300),
  created_at timestamptz not null default now(),
  used_at    timestamptz,
  primary key (user_id, day)
);
create index duty_permits_granted_by_idx on public.duty_permits (granted_by);

alter table public.duty_permits enable row level security;
create policy own_or_admin on public.duty_permits for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));
revoke all on public.duty_permits from anon, authenticated;
grant select on public.duty_permits to authenticated;

create function public.allow_duty_on(p_user uuid, p_note text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_admin uuid := private.require_admin();
  v_day date := private.ist_today();
  v_note text := nullif(trim(p_note), '');
begin
  if not exists (select 1 from public.profiles
                 where id = p_user and role = 'employee' and is_active) then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
  if now() >= private.auto_off_at(v_day) then
    raise exception 'too_late' using errcode = 'P0001';
  end if;
  if char_length(coalesce(v_note, '')) > 300 then
    raise exception 'note_too_long' using errcode = '22023';
  end if;
  -- Any record for today (a duty, leave, or an admin's absent) means duty on
  -- would be refused anyway.
  if exists (select 1 from public.duty_days where user_id = p_user and day = v_day) then
    raise exception 'day_already_recorded' using errcode = 'P0001';
  end if;

  insert into public.duty_permits (user_id, day, granted_by, note)
  values (p_user, v_day, v_admin, v_note)
  on conflict (user_id, day) do update
    set granted_by = excluded.granted_by, note = excluded.note,
        created_at = now(), used_at = null;
  perform private.notify(
    p_user, 'duty_on_allowed', 'Duty on allowed',
    'The admin allowed you to do duty on today. Open the app to start.');
  perform private.log_admin('allow_duty_on', p_user,
    jsonb_build_object('day', v_day, 'note', v_note));
end;
$$;

-- Returns true if a permission was waiting and is now taken back.
create function public.revoke_duty_on(p_user uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_day date := private.ist_today();
  n integer;
begin
  perform private.require_admin();
  delete from public.duty_permits
  where user_id = p_user and day = v_day and used_at is null;
  get diagnostics n = row_count;
  if n > 0 then
    perform private.log_admin('revoke_duty_on', p_user, jsonb_build_object('day', v_day));
  end if;
  return n > 0;
end;
$$;

create or replace function public.duty_on(p_device_id text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_local timestamp := now() at time zone 'Asia/Kolkata';
  v_day date := v_local::date;
  v_row public.duty_days;
begin
  perform private.require_device(v_uid, p_device_id);
  if v_local::time < time '05:00' or v_local::time >= time '08:31' then
    -- Outside the window only with the admin's permission for today.
    update public.duty_permits set used_at = now()
    where user_id = v_uid and day = v_day and used_at is null
      and now() < private.auto_off_at(v_day);
    if not found then
      raise exception 'duty_on_closed' using errcode = 'P0001';
    end if;
  end if;
  select * into v_row from public.duty_days where user_id = v_uid and day = v_day;
  if found then
    if v_row.status = 'leave' then
      raise exception 'on_leave_today' using errcode = 'P0001';
    end if;
    raise exception 'already_on_duty_today' using errcode = 'P0001';
  end if;
  insert into public.duty_days (user_id, day, status, duty_on_at)
  values (v_uid, v_day, 'on_duty', now())
  returning * into v_row;
  return jsonb_build_object('day', to_jsonb(v_row),
                            'upload_pass', private.new_upload_pass(v_row, p_device_id));
end;
$$;

-- Old permissions are of no use; the nightly cleanup drops them after 30 days.
create or replace function private.cleanup() returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.track_points where recorded_at < now() - interval '7 days';
  delete from public.day_routes where day < private.ist_today() - 90;
  delete from public.notifications where created_at < now() - interval '60 days';
  delete from public.live_positions lp
  where not exists (select 1 from public.duty_days d
                    where d.id = lp.duty_day_id and d.status = 'on_duty')
    and lp.updated_at < now() - interval '1 day';
  delete from private.password_reset_codes where expires_at < now() - interval '1 day';
  delete from private.push_tokens where updated_at < now() - interval '60 days';
  delete from public.duty_permits where day < private.ist_today() - 30;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on all functions in schema public from public, anon, authenticated;
revoke all on all functions in schema private from public, anon, authenticated;

grant execute on function
  public.server_now(),
  public.duty_on(text),
  public.duty_resume(text),
  public.duty_off(bigint, timestamptz),
  public.upload_points(bigint, jsonb, text),
  public.request_attendance(date, time, time, text, text),
  public.request_leave(public.leave_type, date[], text, text),
  public.cancel_request(bigint),
  public.decide_request(bigint, public.day_status, text),
  public.set_day_status(uuid, date, public.day_status, public.leave_type, text),
  public.add_visit(uuid, text, text, boolean, integer, integer, text, timestamptz),
  public.mark_notifications_read(bigint[]),
  public.claim_device(text),
  public.release_device(text),
  public.set_push_token(text, text),
  public.clear_push_token(text),
  public.allow_duty_on(uuid, text),
  public.revoke_duty_on(uuid)
to authenticated;
grant execute on function private.is_admin() to authenticated;

grant execute on function
  public.upload_points_with_pass(bigint, text, jsonb),
  public.duty_off_with_pass(bigint, text, timestamptz),
  public.report_break_with_pass(bigint, text, timestamptz, timestamptz, public.duty_break_kind)
to anon, authenticated;

grant execute on all functions in schema public to service_role;
grant execute on all functions in schema private to service_role;
