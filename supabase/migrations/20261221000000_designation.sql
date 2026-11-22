-- A designation for every person (Field Assistant, Sales Officer, ...).
--
-- The admin picks one from a list or types their own when creating or editing
-- a user (admin-users function). It is shown on the profile, in the users
-- list and in the PDF report. Employees can read their own, never change it:
-- the only writer is the admin-users function (service key), as for every
-- other profile column.
--
-- Optional in the database: the 5 existing accounts have none until an admin
-- sets it. The "required for a new employee" rule is in the function and the
-- form, not here, so an old account without one can still be saved.
-- 2 to 40 characters, no leading or trailing space; the exact characters
-- allowed are checked in the function (rules.ts) and the app (credentials.dart).

alter table public.profiles add column designation text;

alter table public.profiles add constraint profiles_designation_check
  check (designation is null
         or (designation = btrim(designation) and char_length(designation) between 2 and 40));
