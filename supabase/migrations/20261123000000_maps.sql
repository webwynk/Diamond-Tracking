-- Phase 5: maps.
--
-- - Today's route is rebuilt while the duty is on (at most every 5 minutes),
--   so the employee and the admin see it during the day, not only after
--   duty off.
-- - Stops get a short address ("Krishi Kendra Rd, Barasat"). Addresses come
--   from Google's Geocoding API through the stop-addresses Edge Function,
--   only for routes someone opens, and are kept per ~100 m square, so the same
--   dealer is never looked up twice.

-- ---------------------------------------------------------------------------
-- Place names, per ~100 m square (latitude and longitude x 1000, rounded)
-- ---------------------------------------------------------------------------

create table private.place_names (
  cell_lat   integer not null,
  cell_lng   integer not null,
  address    text not null check (char_length(address) <= 200),
  created_at timestamptz not null default now(),
  primary key (cell_lat, cell_lng)
);
revoke all on private.place_names from public, anon, authenticated;

create function private.place_cell(p_deg double precision) returns integer
language sql immutable set search_path = '' as $$
  select round(p_deg * 1000)::integer;
$$;

-- Copies known addresses into a day's stops.
create function private.attach_addresses(p_day_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.day_routes r set stops = coalesce((
    select jsonb_agg(
      case when pn.address is null then s.stop - 'address'
           else s.stop || jsonb_build_object('address', pn.address) end
      order by s.n)
    from jsonb_array_elements(r.stops) with ordinality as s(stop, n)
    left join private.place_names pn
      on pn.cell_lat = private.place_cell((s.stop->>'lat')::double precision)
     and pn.cell_lng = private.place_cell((s.stop->>'lng')::double precision)
  ), '[]')
  where r.duty_day_id = p_day_id and jsonb_array_length(r.stops) > 0;
end;
$$;

-- The route builder now also fills in known addresses. Callers keep calling
-- private.build_route.
alter function private.build_route(bigint) rename to build_route_points;
create function private.build_route(p_day_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.build_route_points(p_day_id);
  perform private.attach_addresses(p_day_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Used by the stop-addresses Edge Function (secret key only)
-- ---------------------------------------------------------------------------

-- Stops of a day that still need an address, after using the saved ones.
-- p_caller must own the day or be an admin.
create function public.svc_missing_places(p_day_id bigint, p_caller uuid)
returns table (cell_lat integer, cell_lng integer, lat double precision, lng double precision)
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.duty_days d
    join public.profiles p on p.id = p_caller and p.is_active
    where d.id = p_day_id and (d.user_id = p_caller or p.role = 'admin')
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  perform private.attach_addresses(p_day_id);
  return query
    select distinct on (c.cell_lat, c.cell_lng) c.cell_lat, c.cell_lng, c.lat, c.lng
    from public.day_routes r,
         lateral jsonb_array_elements(r.stops) s(stop),
         lateral (select (s.stop->>'lat')::double precision as lat,
                         (s.stop->>'lng')::double precision as lng) ll,
         lateral (select private.place_cell(ll.lat) as cell_lat,
                         private.place_cell(ll.lng) as cell_lng, ll.lat, ll.lng) c
    where r.duty_day_id = p_day_id and not (s.stop ? 'address');
end;
$$;

-- Saves looked-up addresses ([{cell_lat, cell_lng, address}]) and puts them
-- on the day's stops.
create function public.svc_save_places(p_day_id bigint, p_places jsonb)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  insert into private.place_names (cell_lat, cell_lng, address)
  select (e->>'cell_lat')::integer, (e->>'cell_lng')::integer, left(e->>'address', 200)
  from jsonb_array_elements(p_places) e
  where coalesce(e->>'address', '') <> ''
  on conflict do nothing;
  perform private.attach_addresses(p_day_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Points: also refresh today's route
-- ---------------------------------------------------------------------------

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
    select (e->>'t')::timestamptz as t,
           (e->>'la')::integer as la, (e->>'lo')::integer as lo,
           least((e->>'a')::numeric, 32767)::smallint as a,
           (e->>'b')::smallint as b
    from jsonb_array_elements(p_points) e
  ), ins as (
    insert into public.track_points (duty_day_id, recorded_at, lat_e6, lng_e6, accuracy_m, battery)
    select p_day_id, t, la, lo, a, b from incoming
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
    select recorded_at, lat_e6, lng_e6, accuracy_m, battery into v_last
    from public.track_points where duty_day_id = p_day_id
    order by recorded_at desc limit 1;
    if found then
      insert into public.live_positions as lp
        (user_id, duty_day_id, lat_e6, lng_e6, accuracy_m, battery, recorded_at, updated_at)
      values (p_uid, p_day_id, v_last.lat_e6, v_last.lng_e6, v_last.accuracy_m,
              v_last.battery, v_last.recorded_at, now())
      on conflict (user_id) do update set
        duty_day_id = excluded.duty_day_id, lat_e6 = excluded.lat_e6,
        lng_e6 = excluded.lng_e6, accuracy_m = excluded.accuracy_m,
        battery = excluded.battery, recorded_at = excluded.recorded_at,
        updated_at = now()
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
  public.release_device(text)
to authenticated;
grant execute on function private.is_admin() to authenticated;

grant execute on function
  public.upload_points_with_pass(bigint, text, jsonb),
  public.duty_off_with_pass(bigint, text, timestamptz),
  public.report_break_with_pass(bigint, text, timestamptz, timestamptz, public.duty_break_kind)
to anon, authenticated;

grant execute on all functions in schema public to service_role;
grant execute on all functions in schema private to service_role;
