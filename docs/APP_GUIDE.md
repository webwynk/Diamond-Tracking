# Diamond Agritech Tracking App: the complete guide

This guide explains **every feature** of the app in plain words, for someone
who does not write code. Each feature has three parts:

- **What it does**: a short explanation.
- **Example**: a real day, with our employee **Rahul** (user ID `DA-1002`) and
  the admin.
- **The code**: the piece of code that does it, and the file it lives in, so a
  developer can find it quickly. You can skip the code boxes if you like; the
  words above them say everything the code does.

All times in this guide are **India time (IST)**. The app always uses India
time, even if a phone is set to another time zone.

---

## Contents

**Part 0. The big picture**
- [0.1 The pieces of the system](#01-the-pieces-of-the-system)
- [0.2 The app trusts the server's clock, not the phone's](#02-the-app-trusts-the-servers-clock-not-the-phones)
- [0.3 Where every rule lives](#03-where-every-rule-lives)

**Part A. Employee side**
- [A1 Opening the app](#a1-opening-the-app)
- [A2 Logging in with a user ID](#a2-logging-in-with-a-user-id)
- [A3 First login: temporary PIN, then your own password](#a3-first-login-temporary-pin-then-your-own-password)
- [A4 One phone at a time](#a4-one-phone-at-a-time)
- [A5 Forgot password (code by email)](#a5-forgot-password-code-by-email)
- [A6 Profile: change password and log out](#a6-profile-change-password-and-log-out)
- [A7 Phone setup before the first duty on](#a7-phone-setup-before-the-first-duty-on)
- [A8 The Home screen and its states](#a8-the-home-screen-and-its-states)
- [A9 Duty on (5:00 to 8:30 AM)](#a9-duty-on-500-to-830-am)
- [A10 Duty on later, with the admin's permission (until 9:00 PM)](#a10-duty-on-later-with-the-admins-permission-until-900-pm)
- [A11 Background GPS tracking](#a11-background-gps-tracking)
- [A12 The offline queue (no internet)](#a12-the-offline-queue-no-internet)
- [A13 Phone off and "tracking stopped" notes](#a13-phone-off-and-tracking-stopped-notes)
- [A14 Low battery warnings](#a14-low-battery-warnings)
- [A15 Fake GPS detection](#a15-fake-gps-detection)
- [A16 Duty off, and the 10-hour rule](#a16-duty-off-and-the-10-hour-rule)
- [A17 Automatic duty off at 11:00 PM](#a17-automatic-duty-off-at-1100-pm)
- [A18 Getting back on track after a reinstall or cleared data](#a18-getting-back-on-track-after-a-reinstall-or-cleared-data)
- [A19 Dealer visits with photos](#a19-dealer-visits-with-photos)
- [A20 The 60 photos a day limit](#a20-the-60-photos-a-day-limit)
- [A21 Attendance request (forgot duty on)](#a21-attendance-request-forgot-duty-on)
- [A22 Leave request](#a22-leave-request)
- [A23 My requests, and cancelling one](#a23-my-requests-and-cancelling-one)
- [A24 Notifications (bell and phone alerts)](#a24-notifications-bell-and-phone-alerts)
- [A25 Map tab, History tab and a day's route](#a25-map-tab-history-tab-and-a-days-route)

**Part B. Admin side**
- [B1 Admin login and the five tabs](#b1-admin-login-and-the-five-tabs)
- [B2 Dashboard](#b2-dashboard)
- [B3 Live map](#b3-live-map)
- [B4 Users: add a user](#b4-users-add-a-user)
- [B5 Users: edit, turn an account off, change role](#b5-users-edit-turn-an-account-off-change-role)
- [B6 Reset password (new temporary PIN)](#b6-reset-password-new-temporary-pin)
- [B7 Release phone](#b7-release-phone)
- [B8 Allow duty on today](#b8-allow-duty-on-today)
- [B9 Requests: deciding attendance, leave and short duty](#b9-requests-deciding-attendance-leave-and-short-duty)
- [B10 An employee's history and routes](#b10-an-employees-history-and-routes)
- [B11 Reports and PDF](#b11-reports-and-pdf)
- [B12 App errors list](#b12-app-errors-list)
- [B13 Admin log (who did what)](#b13-admin-log-who-did-what)
- [B14 Ready on the server, no screen yet](#b14-ready-on-the-server-no-screen-yet)

**Part C. Server functions**
- [C1 admin-users](#c1-admin-users)
- [C2 account](#c2-account)
- [C3 password-reset](#c3-password-reset)
- [C4 photos](#c4-photos)
- [C5 push](#c5-push)
- [C6 stop-addresses](#c6-stop-addresses)

**Part D. Nightly database jobs**
- [D1 auto-duty-off (around 11:00 PM)](#d1-auto-duty-off-around-1100-pm)
- [D2 mark-absent (11:15 PM)](#d2-mark-absent-1115-pm)
- [D3 nightly-cleanup (2:30 AM)](#d3-nightly-cleanup-230-am)
- [D4 purge-photos (2:30 to 4:15 AM)](#d4-purge-photos-230-to-415-am)

**Part E. How the route and km are worked out**
- [E1 Building the day's route](#e1-building-the-days-route)

**Part F. Safety behind the scenes**
- [F1 Who can see what](#f1-who-can-see-what)
- [F2 The upload pass](#f2-the-upload-pass)
- [F3 Errors are reported without personal details](#f3-errors-are-reported-without-personal-details)
- [F4 Automatic checks and deployment](#f4-automatic-checks-and-deployment)

**Part G. Quick reference**
- [G1 All the numbers in one table](#g1-all-the-numbers-in-one-table)
- [G2 Owner decisions this app follows](#g2-owner-decisions-this-app-follows)
- [G3 How long data is kept](#g3-how-long-data-is-kept)

---

# Part 0. The big picture

## 0.1 The pieces of the system

**What it does:** The system has these parts:

| Part | What it is | Where the code is |
|---|---|---|
| The phone app | The Android app employees and the admin use. Built with Flutter. | `lib/` |
| The database | Supabase (Postgres). Stores users, duty days, GPS points, visits, requests, notifications. Most rules are checked here, so nobody can cheat by changing the app. | `supabase/migrations/` |
| Server functions | Six small programs on Supabase for jobs the database cannot do alone: making accounts, emails, photos, push alerts, addresses. | `supabase/functions/` |
| Nightly jobs | Timers inside the database: 11 PM duty off, marking absent, clean-up, deleting old photos. | `supabase/migrations/20261120000000_rewrite_baseline.sql` (end of file) |
| Cloudinary | Stores the photos (visits, attendance and leave proof). | `supabase/functions/photos/` |
| Firebase | Sends phone alerts (push notifications). Off until the Firebase settings are added. | `supabase/functions/push/` |
| Google Maps | Draws the maps; Google also turns stop locations into short addresses. | `lib/features/routes/`, `supabase/functions/stop-addresses/` |

**Example:** Rahul presses Duty on. The app asks the **database** to start his
day. While he drives, the **app** records GPS points and sends them to the
database. When he adds a dealer visit, the photo goes to **Cloudinary**. When
he asks for leave, the database writes a notification for the admin and the
**push** function sends it to the admin's phone.

## 0.2 The app trusts the server's clock, not the phone's

**What it does:** A phone's clock can be changed by anyone. So the app reads
the real time from the server once, then counts forward with a timer that does
not change when someone moves the phone's clock. Duty on always needs a fresh
server time first.

**Example:** Rahul wakes up late at 9:10 AM and sets his phone clock back to
8:15 AM to press Duty on. The app still knows it is 9:10 AM (server time), so
Duty on stays closed. Even if he tried, the database checks its own clock too.

**The code:** `lib/core/time/server_clock.dart`

```dart
/// The app's clock: the server's time, carried forward by a monotonic timer.
///
/// Why: the phone's clock can be changed by the user. After one successful
/// [sync], [now] is "server time at sync + time elapsed since then", measured
/// with a monotonic stopwatch that does not move when the phone's clock is
/// changed. Duty off while offline therefore still gets a correct time.
```

The server time itself comes from the date stamp on a tiny request to Supabase:
`lib/core/supabase/supabase_time_source.dart`

```dart
final Uri uri = Uri.parse(supabaseUrl).replace(path: '/auth/v1/health');
...
final String? date = response.headers.value(HttpHeaders.dateHeader);
return HttpDate.parse(date);
```

## 0.3 Where every rule lives

**What it does:** The business rules (5:00 to 8:30 AM, 11 PM, 10 hours, 9 PM
permission, 7 days back, battery levels) are written once in the app, so the
app can show the right button. The database checks the **same** rules again,
so the rules hold even if someone uses a modified app.

**The code:** `lib/core/rules/duty_rules.dart`

```dart
/// Duty on is allowed from 05:00 ...
static const int dutyOnStartMinute = 5 * 60;
/// ... up to and including 08:30 IST.
static const int dutyOnEndMinute = 8 * 60 + 30;
/// Open duties are closed automatically at 23:00 IST.
static const int autoDutyOffMinute = 23 * 60;
/// The admin's "Allow duty on today" can be given and used until 21:00 IST.
static const int dutyPermitEndMinute = 21 * 60;
/// A day shorter than this needs an admin decision.
static const Duration minimumDuty = Duration(hours: 10);
/// Attendance can be requested for today and the 7 days before it.
static const int attendanceRequestDaysBack = 7;
/// Low-battery warnings, highest first. Each fires once per duty day.
static const List<int> batteryWarningLevels = <int>[20, 15, 10];
```

---

# Part A. Employee side

The employee app has four tabs at the bottom: **Home**, **Map**, **History**
and **Profile** (`lib/app/router.dart`).

## A1 Opening the app

**What it does:** A short splash screen shows while the app checks whether
someone is already signed in. Then it sends the person to the right place:
the login screen, the "choose your password" screen, the employee Home, or the
admin Dashboard. An employee can never open admin screens and the other way
round.

**Example:** Rahul opens the app in the morning. He logged in yesterday, so the
splash disappears and he lands straight on Home.

**The code:** `lib/app/routes.dart`

```dart
String? resolveRedirect(AuthStatus status, String path) {
  switch (status) {
    case AuthLoading():
      return path == Routes.splash ? null : Routes.splash;
    case SignedOut():
      return Routes.isPublicPath(path) ? null : Routes.login;
    case SignedIn(mustChangePassword: true):
      return path == Routes.setPassword ? null : Routes.setPassword;
    case SignedIn(role: AppRole.admin):
      return Routes.isAdminPath(path) ? null : Routes.adminDashboard;
    case SignedIn(role: AppRole.employee):
      return Routes.isUserPath(path) ? null : Routes.userHome;
  }
}
```

## A2 Logging in with a user ID

**What it does:** Employees log in with their **user ID** (for example
`DA-1002`) and password, not with an email. Behind the scenes the app turns the
user ID into a private sign-in name (`da-1002@staff.diamondagritech.internal`)
that never receives mail. Right after the password is accepted, the app
"claims" the phone (see A4). If the claim is refused, the app signs out again
at once and shows the reason.

**Example:** Rahul types `DA-1002` and his password. The app signs him in and
registers this phone as his phone.

**The code:** `lib/features/auth/data/auth_repository.dart`

```dart
await _client.auth.signInWithPassword(
  email: loginEmailFor(loginId),
  password: password,
);
try {
  await _client.rpc<void>(
    'claim_device',
    params: <String, Object?>{'p_device_id': await _deviceIds.get()},
  );
} on Object {
  // Never stay signed in on a phone the account may not use.
  await _client.auth.signOut(scope: SignOutScope.local);
  rethrow;
}
```

The user ID rule (2 to 20 letters, digits, `-` or `_`) and the sign-in name:
`supabase/functions/_shared/rules.ts`

```ts
export const LOGIN_EMAIL_DOMAIN = 'staff.diamondagritech.internal';
export function loginEmailFor(userCode: string): string {
  return `${userCode.toLowerCase()}@${LOGIN_EMAIL_DOMAIN}`;
}
```

## A3 First login: temporary PIN, then your own password

**What it does:** When the admin makes an account (or resets one), the person
gets a **6-digit temporary PIN**. The first time they log in with it, the app
only shows the "choose your password" screen. Nothing else works until they
choose a password: 8 to 72 characters, at least one letter and one digit, and
it must not contain their user ID. The database also refuses all employee and
admin actions while the account is still on a temporary PIN.

**Example:** The admin creates Rahul's account with PIN `482913`. Rahul logs in
with `DA-1002` and `482913`. The app asks for a new password. He tries
`da-1002abc` and the app says "Do not use your user ID in the password". He
chooses `Paddy2026` and goes to Home.

**The code:** password rules, `supabase/functions/_shared/rules.ts` (the app
has the same rules in `lib/features/auth/domain/credentials.dart`)

```ts
export function passwordProblem(password: string, userCode: string): string | null {
  if (password.length < 8 || password.length > 72) return 'Use 8 to 72 characters';
  if (new TextEncoder().encode(password).length > 72) return PASSWORD_TOO_LONG;
  if (!/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) {
    return 'Use at least one letter and one digit';
  }
  if (userCode !== '' && password.toLowerCase().includes(userCode.toLowerCase())) {
    return 'Do not use your user ID in the password';
  }
  return null;
}
```

Saving the first password goes through the `account` server function (see
C2). The database block while on a PIN:
`supabase/migrations/20261219000000_pin_lock_and_safe_claims.sql`

```sql
if private.on_temporary_pin(auth.uid()) then
  raise exception 'must_change_password' using errcode = '42501';
end if;
```

## A4 One phone at a time

**What it does:** An employee account can be signed in on **one phone only**.
Each app install has its own random ID kept in encrypted storage. At login, the
database remembers that ID as "this person's phone". A login from a second
phone is refused with "Already logged in on another phone. Log out there
first, or ask your admin to release the phone." Every duty action also checks
the phone. Admins may use more than one phone.

**Example:** Rahul's phone breaks and he borrows his brother's phone. The login
is refused. He calls the admin, who presses **Release phone** (B7). Now Rahul
can log in on the new phone.

**The code:** `supabase/migrations/20261202000000_one_signed_in_phone.sql`

```sql
if v_role = 'admin' then
  return;  -- admins may use more than one phone
end if;
if v_current is not null and v_current <> p_device_id then
  raise exception 'signed_in_elsewhere' using errcode = 'P0001';
end if;
-- Same phone signing in again: the new sign-in takes over.
update public.profiles
set active_device_id = p_device_id, active_session_id = private.jwt_session()
where id = v_uid;
```

The phone's ID: `lib/core/supabase/device_id.dart`

```dart
/// A random id for this app install, used for the one-phone-at-a-time rule.
/// It is created once and kept in encrypted storage. Uninstalling the app
/// removes it, so after a reinstall the admin resets the user's password,
/// which frees the account for the new install.
```

## A5 Forgot password (code by email)

**What it does:** On the login screen, "Forgot password" asks for the user ID.
If the account has a contact email, a **6-digit code** is emailed. The code
works for **15 minutes** and allows **5 tries**. Limits: one email a minute,
5 a day per person, 90 a day in total. The screen gives the same answer
whether the user ID exists or not, so nobody can guess user IDs. A successful
reset signs the person out of every phone. If the project has no email
service set up, the person is told to ask the admin.

**Example:** Rahul forgets his password. He enters `DA-1002`, gets the code
`305118` at his Gmail, types it with a new password, and logs in again.

**The code:** `supabase/functions/password-reset/handler.ts`

```ts
// Codes: 6 digits, stored hashed, 15 minutes, 5 tries, one email a minute,
// 5 a day per user (more send nothing) and 90 a day in total.
// A successful reset signs the user out of every phone.
...
await mail.send(
  profile.contact_email,
  'Diamond Agritech password reset code',
  `Your password reset code is ${value}.\n\n` +
    'It works for 15 minutes. If you did not ask for it, ignore this email.',
);
```

## A6 Profile: change password and log out

**What it does:** The **Profile** tab shows the person's details, a
**Change password** button (it asks for the current password first) and
**Log out**. Log out is blocked while work is still on the phone: a duty still
running, GPS points not yet sent, or visits not yet sent. This stops data from
being lost. Logging out also frees the phone (A4) and stops phone alerts for
this account.

**Example:** Rahul tries to log out at 7 PM while still on duty. The app says
"Not yet: Do duty off first. If you already did, your route is still being
sent: connect to the internet and try again in a minute."

**The code:** `lib/features/users/presentation/account_page.dart`

```dart
content: const Text(
  'Do duty off first. If you already did, your route is still being '
  'sent: connect to the internet and try again in a minute.',
),
...
content: const Text(
  'Some visits are still on this phone. Connect to the internet and '
  'open Home to send them, then try again.',
),
```

Freeing the phone on log out: `lib/features/auth/data/auth_repository.dart`

```dart
await _client.rpc<void>('release_device',
    params: <String, Object?>{'p_device_id': await _deviceIds.get()});
...
await _client.auth.signOut(scope: SignOutScope.local);
```

## A7 Phone setup before the first duty on

**What it does:** Before duty on, the app checks that the phone allows what
tracking needs, and shows a sheet asking for anything missing:

1. Location (GPS) switched on. *Required.*
2. Location permission. *Required.*
3. "Allow all the time" location, so tracking restarts after a phone restart. *Required.*
4. Notifications, for the "on duty" notice and battery warnings. *Required.*
5. No battery limits for the app, so the phone does not stop tracking.
   *Asked, but duty on works without it.* Asked at most once a week.

**Example:** On his first morning Rahul presses Duty on. A sheet appears:
"Allow location all the time". He taps it, chooses "Allow all the time", then
allows notifications. Duty on starts.

**The code:** `lib/features/tracking/application/tracker_control.dart`

```dart
enum TrackerRequirement {
  locationService(required: true),
  locationPermission(required: true),
  backgroundLocation(required: true),
  notifications(required: true),
  batteryOptimization(required: false);
```

Once a week for the battery question: `lib/features/duty/data/battery_prompt_store.dart`.

## A8 The Home screen and its states

**What it does:** Home shows one big card for today, plus **Requests** and
**Visits today** below. The card has one of these states:

| State | When | What Rahul sees |
|---|---|---|
| Too early | Before 5:00 AM | Duty on not open yet |
| Duty on open | 5:00 to 8:30 AM | Green **Duty on** button |
| Allowed by admin | Outside the window, admin allowed today | **Duty on** button with a note |
| Closed | After 8:30 AM, no duty | "Duty on is closed for today" |
| On duty | Duty running | Timer and red **Duty off** button |
| Duty off saved | Duty off pressed without internet | "Duty off saved", sent by itself later |
| Finished | Day done | Present, Waiting for admin, Half day, Absent or Leave |

If the server cannot be reached within a few seconds, Home shows what the
phone knows with a "No internet" banner.

**Example:** At 8:45 AM Rahul opens the app without having done duty on. The
card says duty on is closed for today, so he uses "Request attendance" (A21)
or calls the admin (B8).

**The code:** `lib/features/duty/domain/duty_home.dart`

```dart
/// Before 5:00 AM, nothing recorded yet.
/// 5:00 to 8:30 AM: the duty on button.
/// Outside 5:00 to 8:30 AM, but the admin allowed duty on today.
/// After 8:30 AM with no duty: duty on is closed for today.
/// Duty off was pressed without internet; the phone sends it later.
/// The day is finished (present, waiting for admin, half day, absent).
```

## A9 Duty on (5:00 to 8:30 AM)

**What it does:** Duty on is allowed from **5:00 AM up to and including
8:30 AM**. It needs the internet (to read the true time and tell the server).
Only **one duty a day**, and none on a day of approved leave. A double press
sends only one request. When the server says yes, it hands the phone an
"upload pass" (F2) and the phone starts background tracking (A11).

**Sundays are normal workdays:** there is no weekly off, so duty on works the
same on Sunday.

**Example:** Rahul presses Duty on at 7:52 AM on Sunday. The day starts at
7:52 AM (the server's time). If he presses again, the app says he is already on
duty today.

**The code:** the database check, `supabase/migrations/20261217000000_test_clock.sql`

```sql
-- One duty a day, and none on a leave day.
select d.status into v_status from public.duty_days d
where d.user_id = v_uid and d.day = v_day;
if found then
  if v_status = 'leave' then
    raise exception 'on_leave_today' using errcode = 'P0001';
  end if;
  raise exception 'already_on_duty_today' using errcode = 'P0001';
end if;

if v_local::time < time '05:00' or v_local::time >= time '08:31' then
  -- Outside the window only with the admin's permission, until 9:00 PM.
  ...
end if;

insert into public.duty_days (user_id, day, status, duty_on_at)
values (v_uid, v_day, 'on_duty', private.now())
```

The app side: `lib/features/duty/application/duty_providers.dart`

```dart
/// A second call while one is running joins it, so a double press sends
/// one request and both callers get the same result.
Future<void> dutyOn() =>
    _dutyOnRun ??= _dutyOnOnce().whenComplete(() => _dutyOnRun = null);

Future<void> _dutyOnOnce() async {
  if (!await _clock.sync()) {
    throw const DutyException(DutyFailure.noInternet);
  }
  final DateTime now = _clock.now();
  if (!DutyRules.canDutyOn(now) &&
      !((state.value?.dutyOnAllowed ?? false) &&
          DutyRules.canUsePermitAt(now))) {
    throw const DutyException(DutyFailure.closed);
  }
  ...
```

## A10 Duty on later, with the admin's permission (until 9:00 PM)

**What it does:** If the admin presses **Allow duty on today** for someone
(B8), that person can press Duty on outside 5:00 to 8:30 AM, **once, today,
until 9:00 PM**. The person gets a notification "Duty on allowed". After
9:00 PM the permission no longer works, because a duty would last under two
hours before the 11 PM automatic off.

**Example:** Rahul's bike broke down and he reaches the area at 10:30 AM. The
admin allows duty on for him. Rahul's phone shows "Duty on allowed", he
presses Duty on at 10:35 AM, and the permission is used up.

**The code:** `supabase/migrations/20261217000000_test_clock.sql`

```sql
update public.duty_permits set used_at = private.now()
where user_id = v_uid and day = v_day and used_at is null
  and private.now() < private.permit_cutoff_at(v_day);
if not found then
  ...
  raise exception 'duty_on_closed' using errcode = 'P0001';
end if;
```

The 9:00 PM time: `supabase/migrations/20261211000000_duty_permit_hours.sql`

```sql
create function private.permit_cutoff_at(p_day date) returns timestamptz
language sql immutable set search_path = '' as $$
  select private.ist_at(p_day, time '21:00');
$$;
```

## A11 Background GPS tracking

**What it does:** While on duty, a small service runs in the background (with
a permanent "Duty tracking" notification), even when the app is closed or the
screen is off. It:

- asks for a GPS location **every 30 seconds**,
- keeps a location only if Rahul moved at least **20 metres** (and more than
  the GPS error), or if **3 minutes** passed since the last kept one,
- throws away very poor locations (more than **150 m** error, indoor guesses),
- stamps every point with the trusted server time,
- once a minute: uploads waiting points, checks the battery, writes a
  "still alive" mark, and checks for the 11 PM end,
- restarts by itself after a phone restart, an app update, or if Android
  kills it.

**Example:** Rahul rides from Burdwan to a dealer in Memari. The phone keeps a
point every 20 m or so on the road. At the dealer he sits for 40 minutes; the
phone keeps one point every 3 minutes, so the map shows he was there, without
wasting data.

**The code:** the service settings, `lib/features/tracking/service/tracker_service_config.dart`

```dart
/// The service's heartbeat: uploads, battery check, 11:00 PM check.
static const Duration tickInterval = Duration(minutes: 1);
/// How often to ask for a GPS fix. The point filter decides what to keep.
static const Duration gpsInterval = Duration(seconds: 30);
...
// Start again after a phone restart, and after an app update, unless
// the service was stopped on purpose (duty over).
autoRunOnBoot: true,
autoRunOnMyPackageReplaced: true,
// Restart the service if Android kills it.
allowAutoRestart: true,
// Keeps the minute timer running with the screen off.
allowWakeLock: true,
```

Which points are kept: `lib/features/tracking/domain/point_filter.dart`

```dart
PointFilter({
  this.minDistanceM = 20,
  this.maxSilence = const Duration(minutes: 3),
  this.maxAccuracyM = 150,
});

bool accept(TrackFix fix) {
  if (!fix.accuracyM.isFinite || fix.accuracyM > maxAccuracyM) return false;
  ...
  final double needed = math.max(minDistanceM, math.min(fix.accuracyM, 50));
  if (!silentTooLong && moved < needed) return false;
```

The tracker's brain (no Android parts, so it is fully tested):
`lib/features/tracking/engine/tracker_engine.dart`. Each point is stamped
with the trusted clock:

```dart
// Fixes arrive live, so each one is stamped with the trusted clock when it
// arrives (L43).
final DateTime at = now();
```

## A12 The offline queue (no internet)

**What it does:** Every kept point is first written to a file on the phone.
Only after the server confirms it got the points are they deleted from the
phone. So nothing is lost when there is no signal, the app is closed, or the
phone restarts. Sending the same points twice is harmless; the server skips
duplicates. Points go up in groups of 400.

**Example:** Rahul spends 2 hours in a village with no signal. The phone keeps
about 150 points in its file. When he reaches the main road and the signal
comes back, the next minute's upload sends all of them, and his route on the
admin's map fills in.

**The code:** `lib/features/tracking/data/point_queue.dart`

```dart
/// The offline queue: points and breaks wait here until they are uploaded.
///
/// Plain files in the app's private folder, so nothing is lost when the
/// phone has no signal, the app is closed, or the phone restarts.
/// ...
/// - A batch file is deleted only after the server accepted all of it.
///   Uploads are idempotent (the server skips duplicates), so sending a batch
///   twice after a crash is harmless.
class PointQueue {
  /// The server takes at most 500 points per call.
  static const int chunkSize = 400;
```

The server only accepts points that fall inside the duty's own time:
`supabase/migrations/20261208000000_fewer_lookups_and_rebuilds.sql`

```sql
v_from := v_row.duty_on_at - interval '1 minute';
v_to := least(coalesce(v_row.duty_off_at, private.auto_off_at(v_row.day)),
              now() + interval '2 minutes');
...
where t between v_from and v_to
...
on conflict do nothing
```

## A13 Phone off and "tracking stopped" notes

**What it does:** The tracker writes a "still alive" mark every minute. When
it starts again after a pause, it compares:

- If the **phone restarted**, it records a **"Phone off"** note from the last
  mark until the phone switched on again.
- If the phone stayed on but the tracker was stopped (for example by a
  battery saver), it records **"Tracking stopped"**.
- Pauses under 5 minutes are ignored.

These notes show on the day's route so the admin knows *why* there is a hole.
A hole of 15+ minutes with no note shows as **"No location"**.

**Km while the phone was off are not counted** (owner's decision): the route
is broken at the hole, and no straight line is drawn or counted across it.

**Example:** Rahul's phone battery dies at 1:10 PM and he charges it at a tea
stall until 2:00 PM. His route shows "Phone off 1:10 PM to 2:00 PM". The
distance between where it died and where it came back is not added to his km.

**The code:** `lib/features/tracking/domain/phone_off.dart`

```dart
final bool rebooted = (bootId != null && last.bootId != null)
    ? bootId != last.bootId
    : uptime < last.uptime;
...
if (rebooted) {
  result = TrackBreak(from: last.at, to: bootAt, kind: TrackBreakKind.phoneOff);
} else {
  result = TrackBreak(from: last.at, to: now, kind: TrackBreakKind.trackingStopped);
}
return result.length >= minimum ? result : null;   // minimum = 5 minutes
```

The server keeps one note per time span ("Phone off" wins over "Tracking
stopped"): `supabase/migrations/20261205000000_one_break_note.sql`

```sql
-- A "phone off" break replaces the "tracking stopped" ones it overlaps.
if p_kind = 'phone_off' then
  delete from public.duty_breaks
  where duty_day_id = p_day_id and kind = 'tracking_stopped'
    and started_at < v_to and ended_at > v_from;
end if;
```

## A14 Low battery warnings

**What it does:** While on duty, the phone warns at **20%, 15% and 10%**
battery, each **once per duty day**. The warning appears as a phone alert (even
when the app is closed) and as a popup inside the app. If the battery drops
past several levels at once (25% to 9%), only the lowest warning shows.

**Example:** At 4:30 PM Rahul's battery reaches 20%: "Charge your phone soon so
your route keeps being recorded." At 10%: "Charge your phone now. If it
switches off, your route stops being recorded."

**The code:** `lib/features/tracking/service/battery_alerts.dart`

```dart
String batteryMessage(int level) => level <= 10
    ? 'Charge your phone now. If it switches off, your route stops being '
          'recorded.'
    : 'Charge your phone soon so your route keeps being recorded.';
```

and the "once a day, lowest only" rule, `lib/core/rules/duty_rules.dart`:

```dart
static int? batteryWarningFor(int level, Set<int> alreadyShown) {
  for (final int threshold in batteryWarningLevels.reversed) {
    if (level <= threshold) {
      return alreadyShown.contains(threshold) ? null : threshold;
    }
  }
  return null;
}
```

## A15 Fake GPS detection

**What it does:** Android tells the app when a location comes from a
"fake location" app. Such points are marked. They are **not** used for the
route line, the km or the stops, and the day's page shows a warning with how
many fake points there were. The admin's live map also marks a person whose
latest point is fake. Visit photos taken with a fake location are marked too.

**Example:** Someone installs a fake GPS app to look like they are in Memari
while at home. The points arrive marked as fake, the route does not move, the
km stay 0, and the admin sees "points from a fake-location app" on that day.

**The code:** the phone sends the mark only when true,
`lib/features/tracking/engine/tracker_engine.dart`

```dart
// Only sent when true: the server reads a missing mark as "not fake".
if (fix.mocked) 'm': true,
```

The route builder skips them, `supabase/migrations/20261207000000_route_one_write.sql`

```sql
select count(*) into v_mocked
from public.track_points where duty_day_id = p_day_id and mocked;
...
where duty_day_id = p_day_id and not mocked
```

## A16 Duty off, and the 10-hour rule

**What it does:** Pressing **Duty off** asks "Duty off? You have worked 9 h
40 min today." Then:

- **10 hours or more:** the day is **Present**.
- **Less than 10 hours:** the day becomes **Waiting for admin**. The app says
  "Not eligible for attendance ... less than 10 hours". The database creates a
  **short duty** request for the admin automatically (B9), who marks it
  Present, Half day or Absent.
- **No internet:** duty off still works. The phone saves the exact time and
  sends it as soon as the internet is back. The server uses the saved time,
  not the time it arrived.

The server never lets a duty off time be later than now or later than 11 PM.
The day's route is built at duty off.

**Example 1:** Rahul does duty on at 7:30 AM and duty off at 6:15 PM: 10 h
45 min, **Present**.

**Example 2:** On Saturday he duty offs at 3:00 PM after duty on at 7:30 AM:
7 h 30 min. The day shows "Waiting for admin" and the admin gets "Short duty to
review: Rahul ended duty after 7 h 30 min".

**Example 3:** He presses duty off at 6:15 PM in a village with no signal. Home
shows "No internet. Duty off is saved and will be sent by itself." At 7:05 PM he reaches town;
the phone sends it, and the server records **6:15 PM**.

**The code:** `supabase/migrations/20261124000000_requests_push.sql`

```sql
v_minutes := floor(extract(epoch from p_off_at - v_row.duty_on_at) / 60);
perform private.build_route(p_day_id);

update public.duty_days set
  duty_off_at = p_off_at,
  end_reason = p_reason,
  worked_minutes = v_minutes,
  status = case when v_minutes >= 600 then 'present' else 'pending' end::public.day_status
where id = p_day_id
returning * into v_row;

if v_row.status = 'pending' then
  insert into public.requests (user_id, kind, day)
  values (v_row.user_id, 'short_duty', v_row.day)
  returning id into v_request;
  perform private.notify_admins(
    'short_duty', 'Short duty to review',
    (select full_name from public.profiles where id = v_row.user_id)
      || ' ended duty after ' || (v_minutes / 60) || ' h ' || (v_minutes % 60) || ' min', ...);
end if;
```

Offline duty off in the app: `lib/features/duty/application/duty_providers.dart`

```dart
/// Duty off. Works offline: the time is saved and sent later.
Future<DutyOffOutcome> dutyOff() async {
  ...
  final DateTime offAt = _clock.now();
  try {
    ended = await _repo.dutyOff(day.id, offAt);
  } on Object catch (e) {
    final DutyFailure failure = mapDutyError(e);
    if (failure == DutyFailure.noInternet) {
      offline = true;
```

The late-arriving offline duty off on the server, including when 11 PM closed
the day first: `supabase/migrations/20261204000000_short_day_offline_off.sql`

```sql
-- 11 PM closed it first, and nobody has decided the day: the real (earlier)
-- duty off time wins.
if v_row.status in ('present', 'pending') and v_row.end_reason = 'auto'
   and v_row.status_source = 'auto' and p_off_at < v_row.duty_off_at then
```

## A17 Automatic duty off at 11:00 PM

**What it does:** If someone forgets duty off, the duty is closed automatically
at **11:00 PM** that night. Hours are counted up to 11:00 PM, and the 10-hour
rule applies as usual. The employee gets a notification "Duty turned off at
11 PM" so the next morning they know why the day ended. On the phone, the
tracker also stops recording at 11 PM by itself, even with no internet.

**Example:** Rahul forgets duty off and goes to sleep. At 11:00 PM his duty
ends automatically. Duty on was 7:40 AM, so he worked 15 h 20 min and the day is
Present. In the morning he sees "Your duty on 21 Nov ended by itself at
11:00 PM."

If his phone had pressed duty off offline at 6:30 PM but only reached the
internet after 11 PM, the real 6:30 PM time replaces the 11 PM one (see A16).

**The code:** see D1 for the nightly job. The time:
`supabase/migrations/20261120000000_rewrite_baseline.sql`

```sql
create function private.auto_off_at(p_day date) returns timestamptz
language sql immutable set search_path = '' as $$
  select private.ist_at(p_day, time '23:00');
$$;
```

## A18 Getting back on track after a reinstall or cleared data

**What it does:** If the app's data is cleared during a running duty, the phone
loses its upload pass. When Rahul opens the app again (same phone, still on
duty, before 11 PM), the app asks the server for a fresh pass and tracking
continues.

**Example:** At noon Rahul clears the app's storage by mistake and logs in
again. Home shows he is still on duty, and tracking carries on.

**The code:** `supabase/migrations/20261217000000_test_clock.sql`

```sql
create or replace function public.duty_resume(p_device_id text) returns jsonb
...
  perform private.require_device(v_uid, p_device_id);
  select * into v_row from public.duty_days
  where user_id = v_uid and day = private.ist_today() and status = 'on_duty';
  if not found or private.now() >= private.auto_off_at(v_row.day) then
    raise exception 'not_on_duty' using errcode = 'P0001';
  end if;
  return jsonb_build_object('day', to_jsonb(v_row),
                            'upload_pass', private.new_upload_pass(v_row, p_device_id));
```

## A19 Dealer visits with photos

**What it does:** On duty, **Add visit** saves a dealer visit: **store name**
(required, up to 80 letters), **note** (optional, up to 300), and a **photo**
(required).

- A **camera** photo saves **where it was taken**. If the GPS is slow indoors,
  a location from the last 2 minutes is used. If the location may be more than
  100 m off, it shows as "approximate, ±300 m".
- A **gallery** photo saves **no location** ("Gallery photo, no location").
- Photos are shrunk to at most 1280 px (about 150 to 250 KB) before upload, to
  save mobile data.
- **No internet?** The visit is kept on the phone and sent automatically
  later, into the duty the photo was taken in, up to **2 days** later. The
  same visit is never saved twice.
- Visits show under **Visits today** on Home, and on the day's route.
- Photos are deleted after **90 days**; the visit record stays.

**Example:** At 11:20 AM Rahul visits "Maa Tara Krishi Kendra", takes a photo of
the shop board and writes "Ordered 20 bags urea". The visit shows "Camera photo
at 23.12345, 88.12345". At his next shop there is no signal: the visit shows as
"waiting to send" and goes up by itself when the signal returns.

**The code:** the screen, `lib/features/visits/presentation/add_visit_page.dart`

```dart
/// Add a dealer visit while on duty: store name, note and a photo. A camera
/// photo saves where it was taken; a gallery photo saves no place. With no
/// internet the visit is kept on the phone and sent later.
```

Sending visits kept on the phone: `lib/features/visits/application/visit_sender.dart`

```dart
Future<VisitFailure?> send(PendingVisit visit) async {
  PendingVisit v = visit;
  try {
    if (v.photoId == null) {
      v = v.withPhotoId(await _repo.uploadPhoto(await _outbox.photo(v)));
      await _outbox.update(v);
    }
    await _repo.add(photoId: v.photoId!, storeName: v.storeName, ...);
    await _outbox.remove(v);
    return null;
```

The database check (right duty, store name, photo, location):
`supabase/migrations/20261214000000_visit_photos.sql`

```sql
-- A retry of a visit already saved returns it, even after duty off.
select * into v_row from public.visits where id = p_id and user_id = v_uid;
if found then
  return v_row;
end if;
-- The duty the photo was taken in: the running one, or one of the last
-- 2 days that has ended since (a visit the phone kept while it had no
-- internet, M10).
...
if nullif(trim(p_store_name), '') is null or char_length(trim(p_store_name)) > 80 then
  raise exception 'store_name_required' using errcode = '22023';
end if;
...
if not p_from_gallery and (p_lat_e6 is null or p_lng_e6 is null ...) then
  raise exception 'location_required' using errcode = '22023';
end if;
```

The 2-minute "last known location" and the 100 m "approximate" limit:
`lib/features/visits/data/current_location.dart` and
`lib/features/visits/domain/visit.dart`

```dart
const Duration lastKnownMaxAge = Duration(minutes: 2);
...
/// Beyond this, a visit's location is shown as approximate (L59).
const int approximateOverM = 100;
```

## A20 The 60 photos a day limit

**What it does:** Each person can upload at most **60 photos a day** (visits
and request photos together). This protects the photo storage bill if a phone
goes wrong or someone misuses it. The 61st photo is refused with a clear
message.

**Example:** Rahul visits 25 dealers on a busy day: 25 photos, well under the
limit. A faulty phone stuck in a loop would stop at 60.

**The code:** `supabase/migrations/20261212000000_photo_daily_limit.sql`

```sql
insert into private.photo_upload_counts as c (day, user_id, signed) values (v_day, p_user, 1)
on conflict (day, user_id) do update set signed = c.signed + 1
  where c.signed < 60
returning signed into v_signed;
return v_signed is not null;
```

and in the photos function, `supabase/functions/photos/handler.ts`:

```ts
//        429 photo_limit after 60 photos today for this person (L62).
```

## A21 Attendance request (forgot duty on)

**What it does:** If Rahul worked but forgot duty on, he opens **Home >
Requests > Request attendance** and fills in: the **date** (today or up to
**7 days back**), the **duty on and duty off times** he worked, a **message**
and a **photo** (required, as proof). The admin gets a notification and
decides Present, Half day or Absent (B9).

Rules checked by the database:
- not a future date, not more than 7 days back,
- duty off later than duty on, and not in the future,
- not a day that already has a recorded duty,
- only one waiting request per day (attendance or leave).

**Example:** On Tuesday Rahul realises he forgot duty on last Friday. He asks
for attendance for Friday, 7:30 AM to 6:00 PM, writes "Forgot to press duty on,
was at Kalna dealers all day", and adds a photo of the dealer's order slip.

**The code:** `supabase/migrations/20261218000000_request_photos_auto_off_alerts.sql`

```sql
if p_day > v_today or p_day < v_today - 7 then
  raise exception 'outside_request_window' using errcode = 'P0001';
end if;
if p_duty_off <= p_duty_on then
  raise exception 'invalid_times' using errcode = '22023';
end if;
...
if p_photo_id is null or not private.valid_photo_id(p_photo_id) then
  raise exception 'photo_required' using errcode = '22023';
end if;
if exists (select 1 from public.duty_days
           where user_id = v_uid and day = p_day and duty_on_at is not null) then
  raise exception 'already_has_duty' using errcode = 'P0001';
end if;
-- One waiting request per day, of either kind (L18).
...
perform private.notify_admins(
  'attendance_request', 'Attendance request',
  (select full_name from public.profiles where id = v_uid)
    || ' asked for attendance on ' || to_char(p_day, 'DD Mon YYYY'), ...);
```

The screen: `lib/features/requests/presentation/attendance_request_page.dart`.

## A22 Leave request

**What it does:** **Home > Requests > Leave request**: choose **Sick** or
**Casual** leave, pick **one or more dates** (up to 31, from 7 days back to 90
days ahead), write a **message**, and optionally add a **proof photo** (for
example a doctor's note). The admin approves or rejects (B9). Approved days
become **Leave** (a day already worked keeps its duty). On a leave day duty on
is not possible.

**Example:** Rahul has fever. He asks for 2 days of sick leave, 24 and 25 Nov,
writes "Fever, doctor said rest", and adds the doctor's slip. The admin
approves. On 24 Nov his Home shows "Leave".

**The code:** `supabase/migrations/20261218000000_request_photos_auto_off_alerts.sql`

```sql
if v_dates is null or cardinality(v_dates) > 31 or array_position(v_dates, null) is not null then
  raise exception 'invalid_dates' using errcode = '22023';
end if;
if v_dates[1] < private.ist_today() - 7 then
  raise exception 'outside_request_window' using errcode = 'P0001';
end if;
if v_dates[cardinality(v_dates)] > private.ist_today() + 90 then
  raise exception 'invalid_dates' using errcode = '22023';
end if;
...
perform private.notify_admins(
  'leave_request', 'Leave request',
  (select full_name from public.profiles where id = v_uid) || ' asked for '
    || cardinality(v_dates) || ' day(s) of ' || p_type || ' leave from ' ...
```

The screen: `lib/features/requests/presentation/leave_request_page.dart`.

## A23 My requests, and cancelling one

**What it does:** **My requests** lists all of the employee's requests, newest
first, with their status (Waiting, Approved, Rejected, Cancelled) and the
admin's decision and note. A request still **waiting** can be **cancelled** by
the employee. Short duty reviews (made by the system) cannot be cancelled.
Lists load 100 at a time with "Show more".

**Example:** Rahul asked for casual leave on 28 Nov, but his plans changed. He
opens the request and taps Cancel. It shows "Cancelled" and the admin no
longer needs to decide it.

**The code:** `supabase/migrations/20261120000000_rewrite_baseline.sql`

```sql
update public.requests set status = 'cancelled'
where id = p_request_id and user_id = v_uid and status = 'pending'
  and kind in ('attendance', 'leave')
returning * into v_row;
if not found then
  raise exception 'request_not_cancellable' using errcode = 'P0001';
end if;
```

## A24 Notifications (bell and phone alerts)

**What it does:** The **bell** at the top shows the number of unread
notifications. Notifications are saved in the database and update live.
Tapping one opens what it is about (for example the request). When Firebase is
set up, each notification is also sent as a **phone alert**, even when the app
is closed (C5). Without Firebase they show inside the app only.

What creates a notification:

| Event | Who gets it |
|---|---|
| New attendance request | Admins |
| New leave request | Admins |
| Short duty (under 10 h) | Admins |
| Request decided | The employee |
| Admin allowed duty on today | The employee |
| Duty turned off at 11 PM | The employee |

Notifications are kept 60 days. The app shows the latest 50.

**Example:** The admin approves Rahul's leave. Rahul's phone buzzes "Leave
approved". He taps it and the request opens.

**The code:** saving a notification, `supabase/migrations/20261120000000_rewrite_baseline.sql`

```sql
create function private.notify(
  p_user uuid, p_kind text, p_title text, p_body text, p_data jsonb default '{}'
) returns void
...
  insert into public.notifications (user_id, kind, title, body, data)
  values (p_user, p_kind, p_title, p_body, coalesce(p_data, '{}'));
```

Every new notification calls the push function, and a push failure never loses
the notification: `supabase/migrations/20261124000000_requests_push.sql`

```sql
perform net.http_post(url := v_url, body := jsonb_build_object('id', new.id), ...);
return null;
exception when others then
  -- A push is a courtesy; the notification itself must always be saved.
  return null;
```

The app side: `lib/features/notifications/` (bell:
`presentation/notification_bell.dart`, phone alerts:
`application/push_service.dart`).

## A25 Map tab, History tab and a day's route

**What it does:**

- **Map** tab: today's route on a Google map, while on duty.
- **History** tab: the last **90 days** of duty days, newest first. Tap a day
  to open its route.
- **A day's route** page shows: the map with the route line, duty on and off
  times, hours worked, **km**, **stops** (places where the person stayed
  within 200 m for 15 minutes or more, with a short address), **notes** for
  holes (Phone off, Tracking stopped, No location), the fake GPS warning if
  any, and the day's **visits**. While the duty is running it refreshes every
  2 minutes.

**Example:** Rahul opens History, taps Friday, and sees: 7:30 AM to 6:15 PM,
10 h 45 min, 62.4 km, 4 stops (one at "Memari Bazar, Purba Bardhaman"), and a
note "Phone off 1:10 to 2:00 PM".

**The code:** `lib/features/routes/application/route_providers.dart`

```dart
/// History goes back this far (routes are kept 90 days).
const int historyDays = 90;
```

`lib/features/routes/presentation/day_route_view.dart`

```dart
/// A day's route: the map on top, the day's summary, stops and notes below.
/// While the duty is on it refreshes every 2 minutes.
```

`lib/features/routes/domain/day_route.dart`

```dart
/// A place where the employee stayed within 200 m for 15 minutes or more.
...
/// The phone was switched off.
/// The phone was on, but the phone stopped the tracker.
/// No location for 15+ minutes, cause unknown (indoors, GPS off).
```

How the route and km are worked out is in Part E.

---

# Part B. Admin side

## B1 Admin login and the five tabs

**What it does:** The admin uses the **same app and the same login screen**.
The first admin signs in with the email `admin@diamondagritech.com`; admins
made in the app sign in with their user ID. After login the app shows the admin
side with five tabs: **Dashboard**, **Live**, **Requests**, **Users**,
**Reports**. The admin's own account (change password, log out) is under the
person icon at the top. Admins may be signed in on more than one phone.

**The code:** `lib/app/router.dart`

```dart
NavTab(label: 'Dashboard', icon: Icons.dashboard_rounded),
NavTab(label: 'Live', icon: Icons.location_on_rounded),
NavTab(label: 'Requests', icon: Icons.inbox_rounded),
NavTab(label: 'Users', icon: Icons.group_rounded),
NavTab(label: 'Reports', icon: Icons.picture_as_pdf_rounded),
```

## B2 Dashboard

**What it does:** Today at a glance: how many are **On duty**, **Finished**,
**On leave**, and how many **Waiting requests**, with the waiting requests
listed below. It reloads by itself **every 2 minutes**, and you can pull down
to reload.

**Example:** At 9:00 AM the admin sees On duty 14, Finished 0, On leave 1,
Waiting requests 2 (Rahul's attendance request and someone's leave).

**The code:** `lib/features/admin/presentation/admin_dashboard_page.dart`

```dart
/// How often the dashboard reloads by itself (L85).
const Duration dashboardRefreshEvery = Duration(minutes: 2);

/// Today at a glance: who is on duty and what is waiting for a decision.
```

## B3 Live map

**What it does:** Shows everyone who did duty on today, on a map, at their
latest position. Positions update live as phones upload. A person with no
fresh position for **5 minutes** is shown as stale (no signal, or phone
stopped). A person whose latest point is fake GPS is marked. A pin's colour shows active, stale, suspect (fake GPS) or off duty, and
the battery level shows for people on duty. Tap a person to
see their details and open their route for today. The list reloads every
minute so new duty ons appear.

**Example:** The admin opens Live at 11:00 AM and sees Rahul's pin near Memari,
updated 1 minute ago, battery 64%. Another employee's pin shows as stale: last seen 25
minutes ago.

**The code:** `lib/features/routes/presentation/live_map_page.dart`

```dart
/// The admin's live map: everyone with a duty today, where they last were.
```

`lib/features/routes/domain/live_position.dart`

```dart
/// No fresh position for 5 minutes (no signal, or the phone stopped).
... now.difference(recordedAt) > const Duration(minutes: 5);
```

The latest position is saved whenever points arrive:
`supabase/migrations/20261208000000_fewer_lookups_and_rebuilds.sql`

```sql
insert into public.live_positions as lp
  (user_id, duty_day_id, lat_e6, lng_e6, accuracy_m, battery, mocked, recorded_at, updated_at)
values (...)
on conflict (user_id) do update set ...
where lp.recorded_at <= excluded.recorded_at;
```

## B4 Users: add a user

**What it does:** **Users > Add user**: enter **user ID**, **full name**,
**phone** (optional), **contact email** (optional, only for forgot-password
codes), and **role** (Employee or Admin). The app makes a random **6-digit
temporary PIN** (not all the same digit). After saving, the user ID and PIN are
shown **once** for the admin to pass on. If the admin copies the PIN, the
clipboard is cleared after **1 minute**. Every action is written to the admin
log; PINs and passwords are never logged.

**Example:** A new employee, Sumit, joins. The admin adds user ID `DA-1010`,
name "Sumit Ghosh", phone `9876543210`, email `sumit@gmail.com`. The app shows
"DA-1010 / PIN 615204". The admin sends it to Sumit on WhatsApp. Sumit logs in
and chooses his own password (A3).

**The code:** the server function, `supabase/functions/admin-users/handler.ts`

```ts
// admin-users: the admin creates and edits users and resets temporary PINs.
//
//   POST { action: "create", user_code, full_name, phone?, contact_email?,
//          role?: "employee" | "admin", temp_pin }                -> 201 { profile }
```

PIN rule, `supabase/functions/_shared/rules.ts`

```ts
/** Temporary PIN chosen by the admin: exactly 6 digits, not all the same. */
export function pinProblem(pin: string): string | null {
  if (!/^[0-9]{6}$/.test(pin)) return 'The temporary PIN must be 6 digits';
  if (/^(\d)\1{5}$/.test(pin)) return 'Do not use the same digit 6 times';
  return null;
}
```

Clipboard clearing, `lib/features/users/presentation/pin_dialog.dart`

```dart
/// How long a copied PIN stays on the clipboard (L78).
const Duration pinClipboardTime = Duration(minutes: 1);
```

## B5 Users: edit, turn an account off, change role

**What it does:** Tap a user to edit name, phone, email, role, and the
**Account on** switch. Only what really changed is saved and logged
("from ... to ...").

- **Account off:** the person is signed out at once and cannot log in. Their
  old records stay. Turned-off employees are not marked absent.
- **Role change** (Employee to Admin or back): the person is signed out so the
  next login opens the right side of the app.
- An admin **cannot turn off or demote themselves**, so nobody gets locked out.

**Example:** An employee leaves the company. The admin switches **Account on**
off. His phone is signed out; his past attendance stays in Reports.

**The code:** `supabase/functions/admin-users/handler.ts`

```ts
// Only what really changes is saved and logged (the app sends every field).
...
// An admin cannot lock themselves out.
if (id === admin.id && (changes.is_active === false || changes.role === 'employee')) {
  return reply(409, { error: 'cannot_change_own_access' });
}
...
if (changes.is_active === false && !changes.role) {
  await b.revokeSessions(id);
}
await b.logAdmin(admin.id, 'update_user', id, { changes: diff });
```

## B6 Reset password (new temporary PIN)

**What it does:** On a user's page, **Reset password** gives them a new
6-digit temporary PIN. It also **signs them out of every phone and frees the
phone lock**. They log in with the PIN and must choose a new password (A3).
Use it when someone forgets their password and has no email, or loses their
phone.

**Example:** Rahul forgot his password and has no email set. The admin taps
Reset password and gets PIN `730418`. Rahul logs in with it and picks a new
password.

**The code:** `supabase/functions/admin-users/handler.ts`

```ts
// "Must change password" goes on first, so the PIN never works without it.
await b.setPassword(id, pin, true);
await b.logAdmin(admin.id, 'reset_pin', id, {});
// Signs the user out everywhere and frees the phone lock (a lost or
// replaced phone is handled this way). If only this fails, the new PIN
// already works; pressing Reset again finishes it.
try {
  await b.revokeSessions(id);
```

## B7 Release phone

**What it does:** On an employee's page, **Release phone** signs them out of
their current phone and frees the account for another phone, **without
changing the password**. Use it when someone changes phones.

**Example:** Rahul buys a new phone. The admin taps "Release Rahul's phone?"
> Release. Rahul logs in on the new phone with his usual password.

**The code:** `supabase/migrations/20261202000000_one_signed_in_phone.sql`

```sql
create function public.release_phone(p_user uuid) returns boolean
...
  if not private.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  ...
  perform private.revoke_sessions(p_user);
  perform private.log_admin('release_phone', p_user,
                            jsonb_build_object('had_phone', v_device is not null));
```

## B8 Allow duty on today

**What it does:** On an employee's page, **Allow duty on today** lets that
person do duty on **once today**, outside 5:00 to 8:30 AM, **until 9:00 PM**.
The admin can add an optional note (up to 300 letters). The employee gets a
notification. A permission not yet used can be **taken back**. It cannot be
given:
- after 9:00 PM,
- if the person already has a record today (a duty, leave, or absent),
- to a turned-off account.

**Example:** At 9:15 AM Rahul calls: his bike had a puncture and he could not
press duty on in time. The admin opens Users > Rahul > Allow duty on today,
note "Bike puncture". Rahul's phone says "The admin allowed you to do duty on
today, until 9:00 PM." He presses Duty on at 9:20 AM.

**The code:** `supabase/migrations/20261217000000_test_clock.sql`

```sql
if private.now() >= private.permit_cutoff_at(v_day) then
  raise exception 'too_late' using errcode = 'P0001';
end if;
...
-- Any record for today (a duty, leave, or an admin's absent) means duty on
-- would be refused anyway.
if exists (select 1 from public.duty_days where user_id = p_user and day = v_day) then
  raise exception 'day_already_recorded' using errcode = 'P0001';
end if;
insert into public.duty_permits (user_id, day, granted_by, note) ...
perform private.notify(
  p_user, 'duty_on_allowed', 'Duty on allowed',
  'The admin allowed you to do duty on today, until 9:00 PM. Open the app to start.');
```

Taking it back: `supabase/migrations/20261126000000_duty_on_permit.sql`
(`public.revoke_duty_on`). The card on screen:
`lib/features/users/presentation/duty_on_permission_card.dart`.

## B9 Requests: deciding attendance, leave and short duty

**What it does:** The **Requests** tab shows **waiting** requests first
(oldest first), then all recent ones. Open a request to see the person, the
dates or times, the message and photo, then decide. The admin can add a note
(up to 300 letters). The employee is notified of the decision.

| Request | Buttons | What happens |
|---|---|---|
| Attendance | Present / Half day / Reject | Present or Half day: the day is saved with the typed times. Reject: the day is Absent. A day that already has a real tracked duty cannot be overwritten. |
| Leave | Approve / Reject | Approved: every requested date becomes Leave (sick or casual). A date already worked keeps its duty. |
| Short duty | Present / Half day / Absent | The day's status is set to the choice. |

A request can be decided only once.

**Example:** The admin opens Rahul's short duty "7 h 30 min on Saturday",
writes "Left early for a dealer meeting, OK" and taps **Half day**. Rahul gets
"Short duty marked half day".

**The code:** `supabase/migrations/20261130000000_request_safety.sql`

```sql
if v_req.status <> 'pending' then
  raise exception 'request_already_decided' using errcode = 'P0001';
end if;

if v_req.kind = 'attendance' then
  ...
  -- A day with a real recorded duty keeps it (L3)
  if v_approved and v_has_duty then
    raise exception 'day_has_duty' using errcode = 'P0001';
  end if;
elsif v_req.kind = 'leave' then
  ...
  foreach v_day in array v_req.dates loop
    -- A day already worked keeps its duty.
    ...
else -- short_duty
  update public.duty_days set status = p_decision, status_source = 'admin', ...
end if;
...
perform private.notify(v_req.user_id, 'request_decided', v_title, p_note, ...);
perform private.log_admin('decide_request', ...);
```

The screens: `lib/features/requests/presentation/admin_requests_page.dart`
and `request_detail_page.dart`.

## B10 An employee's history and routes

**What it does:** From a user's page the admin can open that person's
**duty history** (90 days) and any **day's route**, with the same details the
employee sees (A25): times, km, stops with addresses, notes, fake GPS warning,
visits and photos.

**Example:** The admin wants to check Rahul's Thursday. Users > Rahul > History
> Thursday shows his route through Kalna with 5 dealer visits and their photos.

**The code:** `lib/features/routes/presentation/history_page.dart`

```dart
/// A list of duty days, newest first. The employee's History tab shows their
/// own; the admin opens it for any user.
```

## B11 Reports and PDF

**What it does:** **Reports** shows, for a date range (default: this month,
longest **92 days**), for **everyone or one person**:

- Present days, Half days, Absent, Sick leave, Casual leave, Waiting,
- **Attendance days** (Present counts 1, Half day counts 0.5),
- total hours worked, total **km**, total **visits**.

The day list can be narrowed to All, Present, Half day, Absent, Leave or
Waiting. **PDF** makes a report file with a summary row per person (and,
optionally, every day), which opens the phone's share sheet (save, WhatsApp,
print). Each PDF export is written to the admin log.

**Example:** On 1 Dec the admin picks November, everyone, and taps PDF. Rahul's
row reads: Present 22, Half day 2, Absent 1, Sick 2, Attendance 23, 248 h,
1,410 km, 186 visits. The admin sends the file to the accountant on WhatsApp.

**The code:** `lib/features/reports/domain/report.dart`

```dart
/// The longest range one report covers.
const int maxReportDays = 92;
...
/// Present counts 1, half day counts 0.5.
double get attendance => present + halfDays / 2;
```

PDF: `lib/features/reports/data/report_pdf.dart`

```dart
/// Hands a finished PDF to the phone's share sheet (save, WhatsApp, print).
/// "attendance-2026-11-01-to-2026-11-30.pdf".
```

Export log: `supabase/migrations/20261215000000_report_export_log.sql`

```sql
insert into public.admin_log (admin_id, action, target_user, details)
values (v_admin, 'export_report', null, jsonb_build_object(
  'from', p_from, 'to', p_to, 'detail', coalesce(p_detail, false), ...));
```

## B12 App errors list

**What it does:** When something goes wrong in the app on anyone's phone, the
app sends a short error report to the database table **app_errors**: where it
failed, a short message, the app version and when. Personal details (phone
numbers, coordinates, PINs, emails, links) are removed first. At most 20 per
app run and 200 per person a day; reports are kept 30 days. **There is no screen
for this in the app**: the admin (or a developer) reads it in Supabase >
Table Editor > `app_errors`.

**Example:** Rahul says "the visit screen gave an error yesterday". Without
taking his phone, the developer opens `app_errors`, filters by Rahul, and sees
the exact error and time.

**The code:** `supabase/migrations/20261216000000_app_errors.sql`

```sql
if (select count(*) from public.app_errors
    where user_id = v_user and created_at >= v_today_start) >= 200 then
  return;
end if;
delete from public.app_errors where created_at < now() - interval '30 days';
insert into public.app_errors (user_id, happened_at, location, message, app_version) ...
```

The app side: `lib/core/logging/error_reporter.dart` (see F3).

## B13 Admin log (who did what)

**What it does:** Every admin action is recorded in the table **admin_log**:
creating and editing users (with what changed), resetting a PIN, releasing a
phone, allowing or taking back duty on, deciding requests, changing a day,
exporting a PDF. Like app errors, it is read in Supabase (no app screen).

**Example:** Someone asks "who approved this leave?". The admin log shows the
admin, the time, and the decision.

**The code:** used everywhere as `private.log_admin(...)`, for example in
`public.release_phone` (B7) and `public.decide_request` (B9).

## B14 Ready on the server, no screen yet

These work in the database already, but the current app has no button for them
yet:

- **Change a day directly** (`public.set_day_status`): the admin could mark any
  past day Present, Half day, Absent or Leave without a request (for example a
  correction). It also closes that day's waiting short duty review. It refuses
  a running duty and future days.
  File: `supabase/migrations/20261130000000_request_safety.sql`.
- **Turn off phone alerts for new requests** (`public.set_request_alerts`):
  each admin could stop the phone buzzing for new requests; they still show in
  the app. File: `supabase/migrations/20261218000000_request_photos_auto_off_alerts.sql`.
- **Up to 3 photos on a request**: the database and the photos function accept
  2 extra photos; today's app sends one.

---

# Part C. Server functions

Six small programs run on Supabase (`supabase/functions/`). They are deployed
automatically when a change is merged (F4). Browser access (CORS) is **open on
purpose**, kept for a future admin web dashboard (owner's decision); every call
still needs a valid sign-in where it matters.

`supabase/functions/_shared/http.ts`

```ts
// Browser access (CORS) is open on purpose: kept for the admin web dashboard
// (Phase 2). Decided by the owner on 2026-11-21 (review L33). Every call still
// needs a valid sign-in. When the dashboard is built, allow only its address.
const CORS = { 'access-control-allow-origin': '*', ... };
```

## C1 admin-users

**What it does:** Only for admins. Creates users (B4), edits users (B5), and
resets PINs (B6). Checks every field, logs every change, never logs PINs. If
making an account fails halfway, it removes the half-made account.

**Example:** The admin adds Sumit. The app calls `admin-users` with
`action: "create"`; the function makes his sign-in account and profile, and
returns his profile.

**The code:** `supabase/functions/admin-users/handler.ts`

```ts
//   POST { action: "create", user_code, full_name, phone?, contact_email?,
//          role?: "employee" | "admin", temp_pin }                -> 201 { profile }
//   POST { action: "update", id, full_name?, phone?, contact_email?,
//          role?, is_active? }                                    -> 200 { profile }
//   POST { action: "reset_pin", id, temp_pin }                    -> 200 { ok }
```

## C2 account

**What it does:** Saves a person's **first password** after a temporary PIN
(A3). It only works while the account is on a temporary PIN. Later password
changes happen directly in the app.

**Example:** Rahul chooses `Paddy2026` after logging in with his PIN; this
function saves it and clears "must change password".

**The code:** `supabase/functions/account/handler.ts`

```ts
if (body.action !== 'set_password') return reply(400, { error: 'unknown_action' });
if (caller.appMetadata.must_change_password !== true) {
  return reply(403, { error: 'not_required' });
}
const problem = passwordProblem(password, caller.profile.user_code);
...
await b.setPassword(caller.profile.id, password, false);
```

## C3 password-reset

**What it does:** "Forgot password" by email code (A5): `request` emails a
code, `confirm` checks the code and sets the new password, then signs the
person out everywhere. Uses Resend to send email; without it, it answers
"email not configured".

**The code:** `supabase/functions/password-reset/handler.ts` (shown in A5).

## C4 photos

**What it does:** Everything about photos:

- **sign**: gives the phone permission to upload one photo straight to
  Cloudinary (after checking the 60 a day limit). Visit photos get the id
  `visit-<visit id>`; request photos `req-<id>`.
- **view** (GET): sends a photo only to its **owner or an admin**. A small
  version for lists is available.
- **purge**: deletes photos older than 90 days. Called by the nightly job
  (D4). Only the database decides which photos, so calling it early does
  nothing.

**Example:** Rahul takes a visit photo. The app asks `photos` to sign; uploads
it to Cloudinary; then saves the visit with the photo id. When the admin opens
the visit, the photo is loaded through `photos`, which checks the admin is
allowed.

**The code:** `supabase/functions/photos/handler.ts`

```ts
//   POST { action: "sign" }                  any signed-in user
//   POST { action: "sign", kind: "visit" }   any signed-in user
//        ... Cloudinary shrinks anything over 1280 px on arrival.
//        429 photo_limit after 60 photos today for this person (L62).
//   GET  ?request_id=N | ?visit_id=<uuid>    the owner or an admin
//        200 the image bytes. Add &size=small for the small list version
//   POST { action: "purge" }                 no sign-in (the nightly job)
//        Deletes photos older than 90 days. Only the database decides which,
//        so calling it early does nothing.
```

## C5 push

**What it does:** Called by the database for every new notification (A24). It
sends the phone alert through Firebase to that person's phone (for employees,
only the phone they are signed in on). Each notification is pushed only once,
and only within an hour. Phones that no longer exist are removed. An admin who
turned off request alerts (B14) is skipped for new-request alerts. Without
Firebase settings, it does nothing and notifications stay in-app.

**Example:** Rahul sends a leave request. The database saves "Leave request"
for each admin and calls `push`; the admin's phone buzzes.

**The code:** `supabase/functions/push/handler.ts`

```ts
// Without Firebase set up, leave the notification unclaimed (in-app only).
if (!sender) return reply(200, { sent: 0, dropped: 0 });

const job = await b.claimPush(id);
...
// Each phone on its own: a network error for one phone must not lose the
// push for the others, nor skip dropping dead tokens (L64).
const results = await Promise.all(job.tokens.map(async (t) => { ... }));
const gone = job.tokens.filter((_, i) => results[i] === 'gone');
if (gone.length > 0) await b.dropPushTokens(gone);
```

## C6 stop-addresses

**What it does:** Turns the stops on a route into short addresses using Google.
Each address is saved for a ~100 m square, so a place is looked up **once
ever**. A place with no address (a field, a river) is saved as empty so Google
is not asked again. At most **10 lookups** per call keeps the cost low; the app
asks again next time the route opens.

**Example:** The admin opens Rahul's Friday. Two of his 4 stops have no address
yet; the app calls `stop-addresses`, Google returns "Memari Bazar" and "Kalna
Road", and the route reloads with them. Next week, a stop in the same place
needs no new lookup.

**The code:** `supabase/functions/stop-addresses/handler.ts`

```ts
// Addresses are saved per ~100 m square, so a place is looked up once ever.
// A place with no address (a field, a river) is saved as '' so that Google
// is not asked again for it (L15).
// At most 10 lookups per call keeps the cost bounded; the app asks again
// when it opens the route next time.
export const MAX_LOOKUPS = 10;
```

---

# Part D. Nightly database jobs

Four timers run inside the database (pg_cron). Their times are written in UTC
in the code; India is UTC + 5:30.

`supabase/migrations/20261120000000_rewrite_baseline.sql` (end of file)

```sql
-- Every 10 minutes from 22:30 to 00:20 IST. Only duties already past
-- 23:00 are closed, so the early runs do nothing and the later ones are a
-- safety net if a run is missed.
perform cron.schedule('auto-duty-off', '*/10 17-18 * * *',
  'select private.auto_duty_off()');
-- 23:15 IST.
perform cron.schedule('mark-absent', '45 17 * * *',
  'select private.mark_absent()');
-- 02:30 IST.
perform cron.schedule('nightly-cleanup', '0 21 * * *',
  'select private.cleanup()');
```

and `supabase/migrations/20261125000000_visits.sql`

```sql
perform cron.schedule('purge-photos', '*/15 21-22 * * *',
  'select private.purge_photos()');
```

## D1 auto-duty-off (around 11:00 PM)

**What it does:** Every 10 minutes from 10:30 PM to 12:20 AM, closes every duty
that is still on after 11:00 PM, at exactly 11:00 PM, and notifies the person
(A17). The runs before 11 PM do nothing; the later ones are a safety net.

**Example:** At 11:00 PM Rahul and two others are still "on duty". All three
are closed at 11:00 PM and each gets "Duty turned off at 11 PM".

**The code:** `supabase/migrations/20261218000000_request_photos_auto_off_alerts.sql`

```sql
for r in
  select id, user_id, day from public.duty_days
  where status = 'on_duty' and private.auto_off_at(day) <= now()
loop
  perform private.close_duty(r.id, private.auto_off_at(r.day), 'auto');
  perform private.notify(
    r.user_id, 'duty_auto_off', 'Duty turned off at 11 PM',
    'Your duty on ' || to_char(r.day, 'DD Mon') || ' ended by itself at 11:00 PM.', ...);
```

## D2 mark-absent (11:15 PM)

**What it does:** At 11:15 PM, every **active employee** with **no record at
all** for today (no duty, no leave) is marked **Absent** automatically. This
runs **every day including Sunday** (no weekly off). People whose account was
made after that day are skipped. A waiting attendance request can still turn
the day into Present later.

**Example:** Sumit did not do duty on and asked for nothing. At 11:15 PM his
day becomes Absent. On Monday he sends an attendance request for that day; if
the admin approves it, the day becomes Present.

**The code:** `supabase/migrations/20261120000000_rewrite_baseline.sql`

```sql
insert into public.duty_days (user_id, day, status, status_source)
select p.id, v_day, 'absent', 'auto'
from public.profiles p
where p.role = 'employee' and p.is_active
  and (p.created_at at time zone 'Asia/Kolkata')::date <= v_day
on conflict (user_id, day) do nothing;
```

## D3 nightly-cleanup (2:30 AM)

**What it does:** Deletes old data so the free database stays small:

| What | Kept for |
|---|---|
| Raw GPS points | 7 days (the route is built from them first) |
| Day routes and their notes | 90 days |
| Notifications | 60 days |
| Live map positions of ended duties | 1 day |
| Password reset codes | 1 day after they expire |
| Upload passes | until they expire |
| Phone alert registrations | 60 days after the app was last opened |
| "Allow duty on" permissions | 30 days |

Duty days, visits (without photos after 90 days), requests and attendance are
**not** deleted, so Reports keep working.

**The code:** `supabase/migrations/20261127000000_cleanup_fix.sql`

```sql
-- Raw GPS points: 7 days (the day's route is built from them first).
delete from public.track_points where recorded_at < now() - interval '7 days';
-- Routes and their phone-off notes: 90 days.
delete from public.day_routes where day < private.ist_today() - 90;
...
-- Notifications: 60 days.
delete from public.notifications where created_at < now() - interval '60 days';
...
-- "Allow duty on today" permissions after 30 days.
delete from public.duty_permits where day < private.ist_today() - 30;
```

## D4 purge-photos (2:30 to 4:15 AM)

**What it does:** Every 15 minutes between 2:30 and 4:15 AM, if any photo is
older than 90 days, it calls the `photos` function to delete a batch from
Cloudinary (C4). The visit or request stays, with the note "Photo removed after 90 days".

**The code:** `supabase/migrations/20261125000000_visits.sql`

```sql
if not exists (select 1 from public.svc_photos_to_purge(1)) then
  return;
end if;
perform net.http_post(
  url := v_url,
  body := jsonb_build_object('action', 'purge'), ...);
```

---

# Part E. How the route and km are worked out

## E1 Building the day's route

**What it does:** The database turns the raw GPS points into the day's route
(line, km, stops, holes). It does this at duty off, after late points arrive,
and every 5 minutes during the day for the maps. The rules:

1. **Fake GPS points are ignored** completely (A15).
2. Points with more than **50 m** error are not used for the line or km; up to
   150 m they only show the phone was alive.
3. A jump faster than about **200 km/h** is a bad GPS reading and is skipped.
4. A wrong first reading after a gap (far from the next ones) is skipped.
5. **Km**: only real movement counts. Moves under **30 m** are GPS wobble and
   are not added.
6. **Holes**: no point at all for **15+ minutes** breaks the route. **No km is
   counted across a hole** (owner's decision: km while the phone is off are
   not counted). The hole gets a note from the phone (Phone off / Tracking
   stopped) or shows "No location".
7. **Stops**: staying within **200 m** for **15 minutes or more**.

**Example:** Rahul's phone sends 900 points on Friday. 30 are poor indoor
readings, 1 is a wild jump to Kolkata, and his phone was off for 50 minutes at
lunch. The route uses the good points, skips the jump, breaks at lunch without
a straight line across, and adds up 62.4 km of real movement, with 4 stops.

**The code:** `supabase/migrations/20261207000000_route_one_write.sql`
(`private.build_route_points`)

```sql
c_max_accuracy  constant integer := 50;    -- metres; route, km and stops
c_alive_accuracy constant integer := 150;  -- metres; only "phone was alive"
c_max_speed     constant double precision := 55;  -- m/s (~200 km/h): a jump
c_min_move      constant double precision := 30;  -- metres; less is GPS jitter
c_gap           constant interval := interval '15 minutes';
c_stop_radius   constant double precision := 200;
c_stop_min      constant interval := interval '15 minutes';
...
-- No point of any kind for more than 15 minutes: phone off (or tracking
-- stopped). Close the stretch.
if v_alive_t is not null and p.recorded_at - v_alive_t > c_gap then
  ...
  v_anc_lat := null;      -- the next point starts fresh: no km across the hole
...
-- Distance: only real movement away from the last anchor counts.
d := private.dist_m(v_anc_lat, v_anc_lng, p.lat_e6, p.lng_e6);
if d >= c_min_move then
  v_distance := v_distance + d;
```

---

# Part F. Safety behind the scenes

## F1 Who can see what

**What it does:** The database itself decides who can read what
("row-level security"). An employee can only read **their own** days, routes,
visits, requests and notifications. Admins can read everything. All changes go
through checked database functions, never by writing tables directly. Even a
modified app cannot see or change someone else's data.

**Example:** If someone tried to read Rahul's route from another employee's
account, the database would return nothing.

**The code:** `lib/features/routes/data/route_repository.dart`

```dart
/// Routes, history and live positions. Row-level security decides what each
/// user may read (own rows, or everything for admins).
```

Each employee function starts with this check (account active, own phone, not
on a temporary PIN): `supabase/migrations/20261219000000_pin_lock_and_safe_claims.sql`
(`private.require_employee`).

## F2 The upload pass

**What it does:** At duty on, the server gives the phone a secret **upload
pass** for that duty. The background tracker uses it to send points, phone-off
notes and an offline duty off, without needing the normal login (which could
expire while the phone is in a pocket). The pass only works for that duty, only
from the phone that is signed in, and only until 2 days after that day's 11 PM.
A password reset or Release phone makes it stop working.

**Example:** Rahul's login refreshes in the app while the tracker uploads in
the background; they never get in each other's way, because the tracker only
uses the pass.

**The code:** `supabase/migrations/20261122000000_duty_tracking.sql`

```sql
where u.duty_day_id = p_day_id
  and u.pass_hash = extensions.digest(coalesce(p_pass, ''), 'sha256')
  and u.expires_at > now()
  and p.is_active
  and p.active_device_id = u.device_id;
if v_uid is null then
  raise exception 'invalid_upload_pass' using errcode = '42501';
end if;
```

## F3 Errors are reported without personal details

**What it does:** See B12. Before sending an error, the app removes long
numbers (phone numbers, coordinates, PINs), emails, links and tokens, and cuts
the message to 300 letters.

**The code:** `lib/core/logging/error_reporter.dart`

```dart
/// Only where it failed and a short message go up, with long numbers (phone
/// numbers, coordinates, PINs), emails, links and tokens taken out. At most
/// [maxPerRun] errors a run, each different one once; the server keeps at
/// most 200 a person a day.
static const int maxPerRun = 20;
static const int maxMessageLength = 300;
```

## F4 Automatic checks and deployment

**What it does:** Every pull request runs the app tests, the server function
tests, the database tests and an APK build on GitHub. When a change is merged,
the server functions are deployed to Supabase automatically. Database changes
are still run by hand as SQL files (the `live-switch` folder).

**The code:** `.github/workflows/ci.yml` and `.github/workflows/deploy-functions.yml`.

---

# Part G. Quick reference

## G1 All the numbers in one table

| Rule | Value | Where |
|---|---|---|
| Duty on window | 5:00 to 8:30 AM | `duty_rules.dart`, `duty_on` |
| Admin's "Allow duty on" works until | 9:00 PM | `permit_cutoff_at` |
| Automatic duty off | 11:00 PM | `auto_off_at` |
| Marked absent | 11:15 PM | `mark-absent` job |
| Full day | 10 hours | `close_duty` (600 minutes) |
| Attendance request | today and 7 days back | `request_attendance` |
| Leave request | 7 days back to 90 days ahead, up to 31 dates | `request_leave` |
| GPS asked every | 30 seconds | `tracker_service_config.dart` |
| Point kept when moved | 20 m, or every 3 minutes | `point_filter.dart` |
| Point dropped when error over | 150 m (phone), 50 m (route/km) | `point_filter.dart`, `build_route_points` |
| Hole in the route | 15 minutes with no point | `build_route_points` |
| Stop | within 200 m for 15 minutes | `build_route_points` |
| Smallest move counted in km | 30 m | `build_route_points` |
| Battery warnings | 20%, 15%, 10% (once a day each) | `duty_rules.dart` |
| Photos per person per day | 60 | `count_photo_upload` |
| Photo size | up to 1280 px | `photo_picker.dart`, Cloudinary |
| Visit sent late (offline) | up to 2 days | `add_visit` |
| Live map "stale" after | 5 minutes | `live_position.dart` |
| Dashboard reload | every 2 minutes | `admin_dashboard_page.dart` |
| Report range | up to 92 days | `report.dart` |
| Temporary PIN | 6 digits, not all the same | `rules.ts` |
| Password | 8 to 72 characters, a letter and a digit, not the user ID | `rules.ts` |
| Reset code | 6 digits, 15 minutes, 5 tries | `password-reset` |
| Copied PIN cleared from clipboard | 1 minute | `pin_dialog.dart` |
| Stop addresses per call | 10 | `stop-addresses` |

## G2 Owner decisions this app follows

- **Km while the phone is off are not counted.** The route breaks at the hole.
- **Sundays are normal workdays.** No weekly off or holidays; absent marking
  runs every day.
- **One signed-in phone per employee.** The admin uses Release phone or Reset
  password to move an account to a new phone.
- **"Allow duty on today" cut-off is 9:00 PM.**
- **60 photos a day per person.**
- **Browser access (CORS) to the server functions stays open**, for a future
  admin web dashboard.

## G3 How long data is kept

| Data | Kept |
|---|---|
| Duty days, attendance, requests, visits (records) | Always |
| Visit and request photos | 90 days |
| Day routes (map line, stops, notes) | 90 days |
| Raw GPS points | 7 days |
| Notifications | 60 days |
| App error reports | 30 days |
| "Allow duty on" permissions | 30 days |
| Admin log | Always |
