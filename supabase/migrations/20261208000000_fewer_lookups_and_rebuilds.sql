-- L15: a stop with no address (a field, a river) was sent to Google again
-- every time the route was opened. The stop-addresses function now saves it
-- as '' ("no address here"); such a square is not looked up again and shows
-- no address.
--
-- L17: two point batches arriving together could both rebuild the route.
-- Route builds of one day now take a lock, so they run one after the other,
-- and today's 5-minute refresh skips a rebuild that another batch just did.
-- (An offline batch for an older day still rebuilds after the other one, so
-- its points are never left out of the route.)
--
-- store_points is the same as in 20261204000000_short_day_offline_off.sql
-- except that the 5-minute refresh calls private.build_route_if_stale.

-- L15 ----------------------------------------------------------------------

create or replace function private.stops_with_addresses(p_stops jsonb) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(
           case when nullif(pn.address, '') is null then s.stop - 'address'
                else s.stop || jsonb_build_object('address', pn.address) end
           order by s.n), '[]')
  from jsonb_array_elements(coalesce(p_stops, '[]')) with ordinality as s(stop, n)
  left join private.place_names pn
    on pn.cell_lat = private.place_cell((s.stop->>'lat')::double precision)
   and pn.cell_lng = private.place_cell((s.stop->>'lng')::double precision);
$$;

-- Stops of a day that still need an address: not saved yet, and not saved as
-- "no address" either. p_caller must own the day or be an admin.
create or replace function public.svc_missing_places(p_day_id bigint, p_caller uuid)
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
    where r.duty_day_id = p_day_id and not (s.stop ? 'address')
      and not exists (
        select 1 from private.place_names pn
        where pn.cell_lat = c.cell_lat and pn.cell_lng = c.cell_lng);
end;
$$;

-- Saves looked-up addresses ([{cell_lat, cell_lng, address}], '' = no address
-- here) and puts them on the day's stops.
create or replace function public.svc_save_places(p_day_id bigint, p_places jsonb)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  insert into private.place_names (cell_lat, cell_lng, address)
  select (e->>'cell_lat')::integer, (e->>'cell_lng')::integer,
         left(btrim(e->>'address'), 200)
  from jsonb_array_elements(p_places) e
  where jsonb_typeof(e->'address') = 'string'
  on conflict do nothing;
  perform private.attach_addresses(p_day_id);
end;
$$;

-- L17 ----------------------------------------------------------------------

-- One route build per day at a time; a second one waits for the first.
create or replace function private.build_route(p_day_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('day_route:' || p_day_id, 0));
  perform private.build_route_points(p_day_id);
end;
$$;

-- Today's refresh: rebuild unless another batch rebuilt it in the last
-- 5 minutes (checked again after waiting for that build).
create function private.build_route_if_stale(p_day_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('day_route:' || p_day_id, 0));
  if not exists (
    select 1 from public.day_routes
    where duty_day_id = p_day_id and built_at > now() - interval '5 minutes'
  ) then
    perform private.build_route_points(p_day_id);
  end if;
end;
$$;
revoke all on function private.build_route_if_stale(bigint) from public, anon, authenticated;

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
      perform private.build_route_if_stale(p_day_id);
    end if;
  elsif v_inserted > 0 then
    perform private.build_route(p_day_id);
  end if;

  return v_inserted;
end;
$$;
