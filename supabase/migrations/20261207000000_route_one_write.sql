-- L14: each route build wrote the day's route twice: first the route, then
-- again to put the known addresses on its stops. The builder now adds the
-- addresses before it saves, so a build is one write. Saving looked-up
-- addresses (svc_save_places) still updates the stops on their own, through
-- the same helper.
--
-- build_route_points is the same as in 20261129000000_fake_gps.sql except
-- for the stops it saves.

-- Known addresses added to a list of stops (an address no longer known is
-- taken off, as before).
create function private.stops_with_addresses(p_stops jsonb) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(
           case when pn.address is null then s.stop - 'address'
                else s.stop || jsonb_build_object('address', pn.address) end
           order by s.n), '[]')
  from jsonb_array_elements(coalesce(p_stops, '[]')) with ordinality as s(stop, n)
  left join private.place_names pn
    on pn.cell_lat = private.place_cell((s.stop->>'lat')::double precision)
   and pn.cell_lng = private.place_cell((s.stop->>'lng')::double precision);
$$;
revoke all on function private.stops_with_addresses(jsonb) from public, anon, authenticated;

create or replace function private.attach_addresses(p_day_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.day_routes r set stops = private.stops_with_addresses(r.stops)
  where r.duty_day_id = p_day_id and jsonb_array_length(r.stops) > 0;
end;
$$;

create or replace function private.build_route_points(p_day_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare
  c_max_accuracy  constant integer := 50;    -- metres; route, km and stops
  c_alive_accuracy constant integer := 150;  -- metres; only "phone was alive"
  c_max_speed     constant double precision := 55;  -- m/s (~200 km/h): a jump
  c_min_move      constant double precision := 30;  -- metres; less is GPS jitter
  c_gap           constant interval := interval '15 minutes';
  c_stop_radius   constant double precision := 200;
  c_stop_min      constant interval := interval '15 minutes';
  c_first_jump    constant double precision := 250;  -- metres
  c_first_window  constant interval := interval '5 minutes';

  p record;
  v_day date;
  v_count integer := 0;
  v_mocked integer := 0;
  v_distance double precision := 0;

  -- last point of any kind (good, weak or skipped): the phone was alive then
  v_alive_t timestamptz;
  -- previous accepted point
  v_prev_t timestamptz;
  v_prev_lat integer;
  v_prev_lng integer;
  -- anchor: last point that counted as movement (null at a stretch start)
  v_anc_lat integer;
  v_anc_lng integer;

  -- polyline state for the current segment
  v_segments text[] := '{}';
  v_seg text := '';
  v_last_lat5 bigint;
  v_last_lng5 bigint;
  v_lat5 bigint;
  v_lng5 bigint;

  -- stop detection: the cluster being built
  v_cl_lat integer;
  v_cl_lng integer;
  v_cl_start timestamptz;
  v_cl_end timestamptz;
  v_cl_sum_lat bigint;
  v_cl_sum_lng bigint;
  v_cl_n integer;
  v_stops jsonb := '[]';
  v_gaps jsonb := '[]';
  d double precision;
  d2 double precision;
begin
  select day into v_day from public.duty_days where id = p_day_id;
  if v_day is null then
    return;
  end if;

  select count(*) into v_mocked
  from public.track_points where duty_day_id = p_day_id and mocked;

  for p in
    with good as (
      select recorded_at, lat_e6, lng_e6, true as good,
             lead(recorded_at) over w as n1_t,
             lead(lat_e6) over w as n1_lat, lead(lng_e6) over w as n1_lng,
             lead(lat_e6, 2) over w as n2_lat, lead(lng_e6, 2) over w as n2_lng
      from public.track_points
      where duty_day_id = p_day_id and not mocked
        and (accuracy_m is null or accuracy_m <= c_max_accuracy)
      window w as (order by recorded_at)
    ), weak as (
      select recorded_at, lat_e6, lng_e6, false as good,
             null::timestamptz as n1_t, null::integer as n1_lat, null::integer as n1_lng,
             null::integer as n2_lat, null::integer as n2_lng
      from public.track_points
      where duty_day_id = p_day_id and not mocked
        and accuracy_m > c_max_accuracy and accuracy_m <= c_alive_accuracy
    )
    select * from good
    union all
    select * from weak
    order by recorded_at
  loop
    -- No point of any kind for more than 15 minutes: phone off (or tracking
    -- stopped). Close the stretch.
    if v_alive_t is not null and p.recorded_at - v_alive_t > c_gap then
      v_gaps := v_gaps || jsonb_build_object('from', v_alive_t, 'to', p.recorded_at);
      if v_seg <> '' then
        v_segments := v_segments || v_seg;
      end if;
      v_seg := '';
      v_last_lat5 := null;
      v_anc_lat := null;
      -- A gap also ends the cluster.
      if v_cl_start is not null and v_cl_end - v_cl_start >= c_stop_min then
        v_stops := v_stops || jsonb_build_object(
          'lat', round(v_cl_sum_lat::numeric / v_cl_n) / 1e6,
          'lng', round(v_cl_sum_lng::numeric / v_cl_n) / 1e6,
          'start', v_cl_start, 'end', v_cl_end);
      end if;
      v_cl_start := null;
    end if;
    v_alive_t := p.recorded_at;

    -- A weak fix only shows that the phone was alive.
    if not p.good then
      continue;
    end if;

    -- An impossible jump from the previous point is a bad fix: skip it.
    if v_prev_t is not null and p.recorded_at > v_prev_t
       and p.recorded_at - v_prev_t <= c_gap then
      d := private.dist_m(v_prev_lat, v_prev_lng, p.lat_e6, p.lng_e6);
      if d / extract(epoch from p.recorded_at - v_prev_t) > c_max_speed then
        continue;
      end if;
    end if;

    -- The first point of a stretch that the next points disagree with is a
    -- bad first fix: skip it (L1).
    if v_anc_lat is null and p.n1_t is not null and p.n2_lat is not null
       and p.n1_t - p.recorded_at <= c_first_window then
      d := private.dist_m(p.lat_e6, p.lng_e6, p.n1_lat, p.n1_lng);
      d2 := private.dist_m(p.n1_lat, p.n1_lng, p.n2_lat, p.n2_lng);
      if d > c_first_jump and d2 < d / 4 then
        continue;
      end if;
    end if;

    v_count := v_count + 1;

    -- Distance: only real movement away from the last anchor counts.
    if v_anc_lat is null then
      v_anc_lat := p.lat_e6;
      v_anc_lng := p.lng_e6;
    else
      d := private.dist_m(v_anc_lat, v_anc_lng, p.lat_e6, p.lng_e6);
      if d >= c_min_move then
        v_distance := v_distance + d;
        v_anc_lat := p.lat_e6;
        v_anc_lng := p.lng_e6;
      end if;
    end if;

    -- Polyline: add the point if it moved at least 1e-5 degrees.
    v_lat5 := round(p.lat_e6 / 10.0);
    v_lng5 := round(p.lng_e6 / 10.0);
    if v_last_lat5 is null then
      v_seg := private.polyline_chunk(v_lat5) || private.polyline_chunk(v_lng5);
      v_last_lat5 := v_lat5;
      v_last_lng5 := v_lng5;
    elsif v_lat5 <> v_last_lat5 or v_lng5 <> v_last_lng5 then
      v_seg := v_seg || private.polyline_chunk(v_lat5 - v_last_lat5)
                     || private.polyline_chunk(v_lng5 - v_last_lng5);
      v_last_lat5 := v_lat5;
      v_last_lng5 := v_lng5;
    end if;

    -- Stops: grow the cluster while within 200 m of its first point.
    if v_cl_start is not null
       and private.dist_m(v_cl_lat, v_cl_lng, p.lat_e6, p.lng_e6) <= c_stop_radius then
      v_cl_end := p.recorded_at;
      v_cl_sum_lat := v_cl_sum_lat + p.lat_e6;
      v_cl_sum_lng := v_cl_sum_lng + p.lng_e6;
      v_cl_n := v_cl_n + 1;
    else
      if v_cl_start is not null and v_cl_end - v_cl_start >= c_stop_min then
        v_stops := v_stops || jsonb_build_object(
          'lat', round(v_cl_sum_lat::numeric / v_cl_n) / 1e6,
          'lng', round(v_cl_sum_lng::numeric / v_cl_n) / 1e6,
          'start', v_cl_start, 'end', v_cl_end);
      end if;
      v_cl_lat := p.lat_e6;
      v_cl_lng := p.lng_e6;
      v_cl_start := p.recorded_at;
      v_cl_end := p.recorded_at;
      v_cl_sum_lat := p.lat_e6;
      v_cl_sum_lng := p.lng_e6;
      v_cl_n := 1;
    end if;

    v_prev_t := p.recorded_at;
    v_prev_lat := p.lat_e6;
    v_prev_lng := p.lng_e6;
  end loop;

  if v_cl_start is not null and v_cl_end - v_cl_start >= c_stop_min then
    v_stops := v_stops || jsonb_build_object(
      'lat', round(v_cl_sum_lat::numeric / v_cl_n) / 1e6,
      'lng', round(v_cl_sum_lng::numeric / v_cl_n) / 1e6,
      'start', v_cl_start, 'end', v_cl_end);
  end if;
  if v_seg <> '' then
    v_segments := v_segments || v_seg;
  end if;

  insert into public.day_routes as r
    (duty_day_id, day, segments, stops, gaps, point_count, distance_m,
     mocked_points, built_at)
  values
    (p_day_id, v_day, v_segments, private.stops_with_addresses(v_stops), v_gaps, v_count, round(v_distance),
     v_mocked, now())
  on conflict (duty_day_id) do update set
    segments = excluded.segments, stops = excluded.stops, gaps = excluded.gaps,
    point_count = excluded.point_count, distance_m = excluded.distance_m,
    mocked_points = excluded.mocked_points, built_at = excluded.built_at;

  update public.duty_days set distance_m = round(v_distance) where id = p_day_id;
end;
$$;

-- The addresses now come with the route itself.
create or replace function private.build_route(p_day_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.build_route_points(p_day_id);
end;
$$;
