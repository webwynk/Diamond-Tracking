-- File 14 of the 2026-11-20 review, L88: errors and crashes the app catches
-- are kept here, so a problem on an employee's phone can be seen without
-- the phone. Admins read them in the Table Editor (app_errors). The app
-- sends only where it failed and a short message with long numbers and
-- emails taken out; never locations, PINs or photos.

create table public.app_errors (
  id          bigint generated always as identity primary key,
  user_id     uuid references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  happened_at timestamptz not null default now(),
  location    text not null,
  message     text not null,
  app_version text
);

create index app_errors_created_at_idx on public.app_errors (created_at);
create index app_errors_user_day_idx on public.app_errors (user_id, created_at);

alter table public.app_errors enable row level security;

-- Admins read; nobody writes directly (only through report_app_error).
create policy app_errors_admin_read on public.app_errors
  for select to authenticated using ((select private.is_admin()));

revoke all on public.app_errors from public, anon, authenticated;
grant select on public.app_errors to authenticated;
grant all on public.app_errors to service_role;

-- Saves one error from the signed-in person's phone. At most 200 a person a
-- day are kept (the rest are dropped quietly, so a phone stuck in a loop
-- cannot fill the database), and errors older than 30 days are removed.
create function public.report_app_error(
  p_where text, p_message text, p_app_version text default null,
  p_happened_at timestamptz default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_today_start timestamptz := private.ist_at(private.ist_today(), '00:00');
begin
  if v_user is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  if coalesce(btrim(p_where), '') = '' or coalesce(btrim(p_message), '') = '' then
    raise exception 'validation_failed' using errcode = '22023';
  end if;
  if (select count(*) from public.app_errors
      where user_id = v_user and created_at >= v_today_start) >= 200 then
    return;
  end if;
  delete from public.app_errors where created_at < now() - interval '30 days';
  insert into public.app_errors (user_id, happened_at, location, message, app_version)
  values (
    v_user,
    -- A phone clock that is far off is not trusted.
    case when p_happened_at between now() - interval '2 days' and now() + interval '5 minutes'
         then p_happened_at else now() end,
    left(btrim(p_where), 100),
    left(btrim(p_message), 500),
    left(nullif(btrim(p_app_version), ''), 30));
end;
$$;

revoke all on function public.report_app_error(text, text, text, timestamptz) from public, anon;
grant execute on function public.report_app_error(text, text, text, timestamptz)
  to authenticated, service_role;
