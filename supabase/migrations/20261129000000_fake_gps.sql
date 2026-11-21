-- Fake GPS warning, and two route fixes from the code review (L1, M13).
--
-- 1. Fake GPS. Android marks a location that came from a fake-location
--    ("mock location") app. The app now sends that mark with each point
--    ("m": true) and with a visit's location. Nothing is blocked: the points
--    are stored with mocked = true, left out of the route, the km and the
--    stops, and counted in day_routes.mocked_points so the admin sees a
--    warning. The live position carries the mark of its latest point. Old app
--    versions send no mark, which means "not fake".
--
-- 2. M13: indoors (at a dealer) fixes are often 50-150 m accurate. The route
--    builder ignored them completely, so a working phone showed "No location"
--    after 15 minutes. They now count as "the phone was alive" (no gap), but
--    still not for the line, the km or the stops. 150 m is the phone's own
--    limit; worse points are still ignored.
--
-- 3. L1: the first fix after the GPS starts can be far off. It was always
--    accepted, so the jump to the real position became fake km, and if the
--    jump looked impossibly fast, every real point of the next 15 minutes was
--    skipped as a "teleport" and a fake gap appeared. Now the first point of
--    each stretch is dropped when it is more than 250 m from the next point
--    (within 5 minutes) while the next two points agree with each other.
--    Real driving keeps moving, so it is not affected.
--
-- No data is changed. Routes are rebuilt as before (new points, duty off).

-- ---------------------------------------------------------------------------
-- Columns (adding a column with a constant default does not rewrite a table)
-- ---------------------------------------------------------------------------

alter table public.track_points add column mocked boolean not null default false;
alter table public.live_positions add column mocked boolean not null default false;
alter table public.visits add column mocked boolean not null default false;
alter table public.day_routes add column mocked_points integer not null default 0;

-- ---------------------------------------------------------------------------
-- Storing points: read the fake mark
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
           (e->>'b')::smallint as b,
           coalesce(e->>'m' in ('true', '1'), false) as m
    from jsonb_array_elements(p_points) e
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

-- ---------------------------------------------------------------------------
-- Building the route (private.build_route calls this, then adds addresses)
-- ---------------------------------------------------------------------------

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
    (p_day_id, v_day, v_segments, v_stops, v_gaps, v_count, round(v_distance),
     v_mocked, now())
  on conflict (duty_day_id) do update set
    segments = excluded.segments, stops = excluded.stops, gaps = excluded.gaps,
    point_count = excluded.point_count, distance_m = excluded.distance_m,
    mocked_points = excluded.mocked_points, built_at = excluded.built_at;

  update public.duty_days set distance_m = round(v_distance) where id = p_day_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Adding a visit: the fake mark of its location. Same as 20261125000000_visits
-- plus p_mocked (default false, so the current app keeps working).
-- ---------------------------------------------------------------------------

drop function public.add_visit(uuid, text, text, boolean, integer, integer, text, timestamptz);
create function public.add_visit(
  p_id uuid, p_store_name text, p_note text, p_from_gallery boolean,
  p_lat_e6 integer, p_lng_e6 integer, p_photo_id text, p_captured_at timestamptz,
  p_mocked boolean default false
) returns public.visits
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_employee();
  v_day public.duty_days;
  v_row public.visits;
begin
  -- A retry of a visit already saved returns it, even after duty off.
  select * into v_row from public.visits where id = p_id and user_id = v_uid;
  if found then
    return v_row;
  end if;
  select * into v_day from public.duty_days
  where user_id = v_uid and day = private.ist_today() and status = 'on_duty';
  if not found then
    raise exception 'not_on_duty' using errcode = 'P0001';
  end if;
  if nullif(trim(p_store_name), '') is null or char_length(trim(p_store_name)) > 80 then
    raise exception 'store_name_required' using errcode = '22023';
  end if;
  if char_length(trim(coalesce(p_note, ''))) > 300 then
    raise exception 'note_too_long' using errcode = '22023';
  end if;
  if p_photo_id is distinct from 'visit-' || p_id::text then
    raise exception 'photo_required' using errcode = '22023';
  end if;
  if not p_from_gallery and (
       p_lat_e6 is null or p_lng_e6 is null
       or p_lat_e6 not between -90000000 and 90000000
       or p_lng_e6 not between -180000000 and 180000000) then
    raise exception 'location_required' using errcode = '22023';
  end if;

  insert into public.visits (id, user_id, duty_day_id, store_name, note, from_gallery,
                             lat_e6, lng_e6, photo_id, captured_at, mocked)
  values (p_id, v_uid, v_day.id, trim(p_store_name), nullif(trim(p_note), ''),
          p_from_gallery,
          case when p_from_gallery then null else p_lat_e6 end,
          case when p_from_gallery then null else p_lng_e6 end,
          p_photo_id,
          least(greatest(coalesce(p_captured_at, now()), v_day.duty_on_at), now()),
          not p_from_gallery and coalesce(p_mocked, false))
  on conflict (id) do nothing;
  select * into v_row from public.visits where id = p_id;
  if v_row.user_id is distinct from v_uid then
    -- The id belongs to someone else's visit.
    raise exception 'invalid_visit' using errcode = '22023';
  end if;
  return v_row;
end;
$$;

revoke all on function
  public.add_visit(uuid, text, text, boolean, integer, integer, text, timestamptz, boolean)
from public, anon;
grant execute on function
  public.add_visit(uuid, text, text, boolean, integer, integer, text, timestamptz, boolean)
to authenticated, service_role;
