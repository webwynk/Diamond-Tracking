-- M7: a daily cap on password reset emails.
--
-- Before, the only limit was one code per user per minute, so anyone could
-- use up the email service's free 100 emails a day.
-- Now (days in India time):
--   * at most 5 codes per user per day; more requests send no email (the
--     answer stays the same, so user IDs are not revealed);
--   * at most 90 reset emails per day in total, then "daily_email_limit".
-- The counts keep only today and yesterday, and clean themselves up.

create table private.reset_email_counts (
  day     date not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  sent    smallint not null default 0,
  primary key (day, user_id)
);
create index reset_email_counts_user_idx on private.reset_email_counts (user_id);
revoke all on private.reset_email_counts from public, anon, authenticated;

-- Stores a new code for a user (replacing any earlier one). Returns false if
-- no email should go out (a code less than a minute ago, or 5 today). Raises
-- daily_email_limit when today's 90 emails are used up.
create or replace function private.store_reset_code(p_user uuid, p_code text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_day date := private.ist_today();
begin
  delete from private.reset_email_counts where day < v_day - 1;
  if exists (select 1 from private.password_reset_codes
             where user_id = p_user and created_at > now() - interval '1 minute') then
    return false;
  end if;
  if coalesce((select sent from private.reset_email_counts
               where day = v_day and user_id = p_user), 0) >= 5 then
    return false;
  end if;
  if coalesce((select sum(sent) from private.reset_email_counts where day = v_day), 0) >= 90 then
    raise exception 'daily_email_limit' using errcode = 'P0001';
  end if;
  insert into private.password_reset_codes (user_id, code_hash, expires_at)
  values (p_user, extensions.crypt(p_code, extensions.gen_salt('bf')), now() + interval '15 minutes')
  on conflict (user_id) do update set
    code_hash = excluded.code_hash, expires_at = excluded.expires_at,
    attempts = 0, created_at = now();
  insert into private.reset_email_counts (day, user_id, sent) values (v_day, p_user, 1)
  on conflict (day, user_id) do update set sent = private.reset_email_counts.sent + 1;
  return true;
end;
$$;
