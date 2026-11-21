-- M9: an offline duty off on a short day is no longer ignored.
-- L10: one impossible GPS value no longer fails a whole upload.
--
-- M9. A duty that 11 PM closes before the phone's offline duty off arrives
-- was corrected only when 11 PM made it a full day ("present"). On a short
-- day (for example a late start the admin allowed) 11 PM makes it "pending"
-- with a short-duty review, and the real duty off time that arrived later
-- was ignored: the admin reviewed the wrong hours (until 11 PM).
-- Now the late duty off corrects a pending day too, as long as nobody has
-- decided it yet. The old short-duty review (and its notice to the admins)
-- is replaced by one with the real hours.
--
-- L10. A point with a value that cannot be read (bad time, a number too big)
-- made the whole batch fail, and the phone retried it forever. Now only that
-- point is skipped.

-- One uploaded point, or all nulls when a value cannot be read.
create function private.parse_point(
  e jsonb,
  out t timestamptz, out la integer, out lo integer,
  out a smallint, out b smallint, out m boolean
)
language plpgsql stable set search_path = '' as $$
begin
  t := (e->>'t')::timestamptz;
  la := (e->>'la')::integer;
  lo := (e->>'lo')::integer;
  a := least((e->>'a')::numeric, 32767)::smallint;
  b := (e->>'b')::smallint;
  m := coalesce(e->>'m' in ('true', '1'), false);
exception when others then
  t := null; la := null; lo := null; a := null; b := null; m := null;
end;
$$;
revoke all on function private.parse_point(jsonb) from public, anon, authenticated;

create or replace function private.store_points(p_uid uuid, p_day_id bigint, p_points jsonb)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.duty_days;
  v_from timestamptz;
  v_to timestamptz;
  v_inserted integer;
  v_last record;
begin
  if p_points is null or jsonb_typeof(p_points) <> 'array'
     or jsonb_array_length(p_points) > 500 then
    raise exception 'invalid_points' using errcode = '22023';
  end if;
  select * into v_row from public.duty_days where id = p_day_id and user_id = p_uid;
  if not found or v_row.duty_on_at is null then
    raise exception 'duty_not_found' using errcode = 'P0002';
  end if;

  v_from := v_row.duty_on_at - interval '1 minute';
  v_to := least(coalesce(v_row.duty_off_at, private.auto_off_at(v_row.day)),
                now() + interval '2 minutes');

  with incoming as (
    select p.t, p.la, p.lo, p.a, p.b, p.m
    from jsonb_array_elements(p_points) e
    cross join lateral private.parse_point(e) p
  ), ins as (
    insert into public.track_points
      (duty_day_id, recorded_at, lat_e6, lng_e6, accuracy_m, battery, mocked)
    select p_day_id, t, la, lo, a, b, m from incoming
    where t between v_from and v_to
      and la between -90000000 and 90000000
      and lo between -180000000 and 180000000
      and (b is null or b between 0 and 100)
      and (a is null or a >= 0)
    on conflict do nothing
    returning recorded_at
  )
  select count(*) into v_inserted from ins;

  if v_row.status = 'on_duty' then
    select recorded_at, lat_e6, lng_e6, accuracy_m, battery, mocked into v_last
    from public.track_points where duty_day_id = p_day_id
    order by recorded_at desc limit 1;
    if found then
      insert into public.live_positions as lp
        (user_id, duty_day_id, lat_e6, lng_e6, accuracy_m, battery, mocked,
         recorded_at, updated_at)
      values (p_uid, p_day_id, v_last.lat_e6, v_last.lng_e6, v_last.accuracy_m,
              v_last.battery, v_last.mocked, v_last.recorded_at, now())
      on conflict (user_id) do update set
        duty_day_id = excluded.duty_day_id, lat_e6 = excluded.lat_e6,
        lng_e6 = excluded.lng_e6, accuracy_m = excluded.accuracy_m,
        battery = excluded.battery, mocked = excluded.mocked,
        recorded_at = excluded.recorded_at, updated_at = now()
      where lp.recorded_at <= excluded.recorded_at;
    end if;
    -- Keep today's route fresh for the maps, at most every 5 minutes.
    if v_inserted > 0 and not exists (
      select 1 from public.day_routes
      where duty_day_id = p_day_id and built_at > now() - interval '5 minutes'
    ) then
      perform private.build_route(p_day_id);
    end if;
  elsif v_inserted > 0 then
    perform private.build_route(p_day_id);
  end if;

  return v_inserted;
end;
$$;

-- Duty off that the phone saved offline and the tracker sends later.
create or replace function public.duty_off_with_pass(
  p_day_id bigint, p_pass text, p_off_at timestamptz
) returns public.day_status
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.check_upload_pass(p_day_id, p_pass);
  v_row public.duty_days;
  v_cap timestamptz;
  v_request bigint;
begin
  select * into v_row from public.duty_days
  where id = p_day_id and user_id = v_uid for update;
  v_cap := least(now(), private.auto_off_at(v_row.day));
  -- 11 PM closed it first, and nobody has decided the day: the real (earlier)
  -- duty off time wins.
  if v_row.status in ('present', 'pending') and v_row.end_reason = 'auto'
     and v_row.status_source = 'auto' and p_off_at < v_row.duty_off_at then
    if v_row.status = 'pending' then
      select id into v_request from public.requests
      where user_id = v_row.user_id and kind = 'short_duty' and day = v_row.day
        and status = 'pending';
      if v_request is not null then
        delete from public.notifications
        where kind = 'short_duty' and data->>'request_id' = v_request::text;
        delete from public.requests where id = v_request;
      end if;
    end if;
    update public.duty_days set
      status = 'on_duty', duty_off_at = null, end_reason = null, worked_minutes = null
    where id = p_day_id;
  elsif v_row.status <> 'on_duty' then
    return v_row.status;
  end if;
  v_row := private.close_duty(
    p_day_id, greatest(v_row.duty_on_at, least(coalesce(p_off_at, v_cap), v_cap)), 'manual');
  return v_row.status;
end;
$$;
