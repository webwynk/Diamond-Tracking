-- L50: remove the unused public.server_now() function.
--
-- It was made for a planned clock check, but the app reads the server time
-- from the Date header of the sign-in service instead (supabase_time_source).
-- Nothing calls it, so it is dropped to keep the list of callable functions
-- short.

drop function if exists public.server_now();
