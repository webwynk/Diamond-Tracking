# 01 — Product Requirements Document

**Product:** Diamond Agritech Tracking App
**Version:** 1.0 (draft)
**Date:** 2026-10-12
**Status:** Approved scope, not yet built
**Owner:** Diamond Agritech

---

## 1. Purpose

Diamond Agritech field staff travel daily to farms, dealers, and customers. Today there is no reliable record of who worked, where they went, how far they travelled, or whether a visit actually happened.

This app gives the company a trustworthy daily record of field work, and gives field staff a simple way to start and end their working day.

### Goals

| # | Goal | How it is measured |
|---|---|---|
| G1 | Know who is working right now and where they are | Admin sees every on-duty employee on a live map, with position no older than 1 minute while moving |
| G2 | Produce a defensible daily record of hours and distance | Each duty session stores start, end, total hours, total km; exportable as PDF or Excel |
| G3 | Prove that a visit happened | A visit record carries GPS, timestamp, and a photo; a skipped photo is visible to the admin |
| G4 | Make the data hard to fake | Server-side time rules, mock-location flagging, one-device binding, server-side distance calculation |
| G5 | Keep field staff onboard | One tap to start duty; the employee can see their own map, km, and hours |

### Non-goals for v1

Explicitly out of scope. Do not build these without a new decision.

- Push notifications of any kind. In-app only.
- An admin web dashboard. Phase 2.
- iOS release. The codebase stays iOS-capable, but Android ships first.
- Payroll, salary calculation, or accounting integration.
- Chat or messaging between admin and employee.
- Task assignment, leave requests, SOS, travel-allowance calculation, performance scoring, sales capture. All deferred.
- Multi-language. English only.
- Team-scoped admin roles. All admins are equal in v1.

---

## 2. Users and roles

### Admin
Office staff who manage the field team. Several admins, **all with equal permissions** in v1.

Can: create and edit employees, block and unblock them, view any employee's profile and stats, see the live map, view routes, create and edit places (geofences), view the notification centre, export reports.

Cannot: see another admin's password or PIN, delete historical duty or location records, or turn off tracking for an on-duty employee without ending their duty.

### Employee
Field staff. Created by an admin; **cannot self-register.**

Can: log in with their employee code and PIN, toggle duty on and off within the allowed window, see their own live position on a map, see their own route and totals for today, submit a visit with a photo and note, view their own duty history.

Cannot: see any other employee, see admin screens, change their own employee code, edit or delete a past duty session, or disable tracking while on duty.

---

## 3. Core business rules

These are the rules the whole product depends on. Each is enforced on the **server**, not the client. The client mirrors them for UI only.

| ID | Rule | Enforcement |
|---|---|---|
| BR-1 | Duty can only be turned on between **08:00 and 23:00 Asia/Kolkata** | Server checks its own clock on the duty-start call and rejects outside the window |
| BR-2 | At **23:00 IST** every open session is closed automatically, with end reason `auto_curfew` and the note "Duty ended automatically" | Scheduled server job, runs every minute near the boundary |
| BR-3 | An employee reminder appears at **22:45 IST** if still on duty | Client-side local reminder, plus a notification row |
| BR-4 | An employee may have **at most one open duty session** at any time | Unique partial index on the database; a second start returns the existing session |
| BR-5 | Turning duty on **notifies all admins**; turning it off also notifies them | Server inserts a notification row; admins receive it over Realtime |
| BR-6 | A **blocked** employee cannot log in, cannot start duty, and any open session is closed immediately with reason `blocked` | RLS plus the block action closing the session in the same transaction |
| BR-7 | Location is recorded **only while a duty session is open** | Server rejects points with no open session; the client stops the tracking service on duty off |
| BR-8 | Distance is calculated **on the server** from accepted GPS points. The client's number is advisory only | Server recomputes on every batch; the session total is authoritative |
| BR-9 | A **mock (fake) GPS** point is stored and flagged, never silently dropped, and **never auto-ends duty** | `is_mock` on the point, counter on the session, red status on the map, flag in reports |
| BR-10 | A GPS point is **rejected or marked an outlier** if accuracy is worse than 100 m, or it implies a speed over 150 km/h, or its timestamp is in the future | Server-side validation before it counts toward distance |
| BR-11 | Entering the radius of an active place raises a geofence **enter** event and prompts the employee for a photo; leaving raises an **exit** event | Server-side geofence evaluation on each accepted point |
| BR-12 | A visit photo **may be skipped**. The visit is still recorded, flagged `photo_skipped`, and the flag appears in reports | Nullable photo, explicit boolean flag |
| BR-13 | An employee account is bound to **one device**. A login from a different device is refused and notifies admins | `device_id` stored on the profile; checked at login |
| BR-14 | An employee can only ever read their **own** data | Row-level security on every table |
| BR-15 | Historical duty, location, visit, and geofence records are **append-only**. Nobody can edit or delete them from the app | No update or delete policy granted on those tables |

### Status colours on the live map

Evaluated in this order; the first match wins.

| Order | Condition | Status | Colour |
|---|---|---|---|
| 1 | Employee is blocked | `blocked` | Black |
| 2 | Last point was flagged mock, or the client reports location services/permission off | `suspect` | Red |
| 3 | No open duty session | `off_duty` | Grey |
| 4 | Open session, but the last point is older than 5 minutes | `stale` | Orange |
| 5 | Open session, last point within 5 minutes | `active` | Green |

Exact hex values live in [03-DESIGN-SYSTEM.md](03-DESIGN-SYSTEM.md). Never hardcode them elsewhere.

---

## 4. Features

### F1 — Authentication

- Employee logs in with **employee code** (e.g. `DA-001`) and a **6-digit PIN**.
- The employee code maps internally to a Supabase Auth identity. The code is never reused, even after an employee leaves.
- Admin sets the initial PIN at creation; the employee is forced to change it on first login.
- PIN rules: exactly 6 digits, not a repeated digit, not a simple sequence.
- Rate limiting: 5 failed attempts locks the account for 15 minutes and notifies admins.
- Admins log in with email and password, separate from the employee flow.
- **The first admin is created manually in the Supabase dashboard**, not through the app. There is no self-service admin signup.

**Acceptance**
- Correct code and PIN sign in. Wrong PIN shows a clear error without revealing whether the code exists.
- A blocked employee is refused with a message telling them to contact the office.
- A login from a second device is refused and an admin notification is raised.
- First login forces a PIN change before any other screen is reachable.

### F2 — Employee management (Admin)

- Create an employee: full name, phone, email, employee code, initial PIN. Code and phone must be unique.
- Edit name, phone, email. The employee code is immutable once created.
- Block with a required reason; unblock. Full block history is kept.
- Reset a PIN, which forces a change on next login.
- Clear the device binding, for when an employee legitimately changes phone. The action is logged.
- Employee list with search by name, code, or phone; filter by status and by current duty state; paginated.

**Acceptance**
- Creating an employee runs server-side; the admin app never holds a privileged key.
- A duplicate code or phone is rejected with a specific message.
- Blocking an on-duty employee closes their session within 10 seconds and their marker turns black.
- Every create, edit, block, unblock, PIN reset, and device clear appears in the audit log.

### F3 — Duty toggle (Employee)

- One large toggle as the primary action on the employee home screen.
- Outside 08:00–23:00 the toggle is disabled with the reason and the next available time shown.
- Turning on requires: location permission granted, location services on, background location granted, and battery optimisation disabled. Each missing item is explained with a direct link to the right settings screen.
- Turning on starts an Android **foreground service** with a persistent notification. The employee cannot be tracked without this visible notification.
- Turning off stops the service, closes the session, and shows a summary: hours, km, visits.
- The toggle reflects true server state. A failed call never leaves the UI showing the wrong state.

**Acceptance**
- The window is enforced by server time; changing the phone clock does not open the toggle.
- Duty survives the app being backgrounded, the screen locking, and the app being swiped away.
- If the service is killed by the OS, it restarts and the gap is visible in the session's point history.
- Toggling on and off rapidly never creates two open sessions.

### F4 — Location tracking (Employee, background)

- Adaptive interval: about every **30 seconds while moving**, dropping to about every **3 minutes while stationary**. Stationary is defined by a movement threshold, not by the accelerometer alone.
- Captured per point: timestamp, latitude, longitude, accuracy, speed, heading, altitude, battery percentage, and the OS mock-location flag.
- **Offline queue:** points are stored locally and uploaded in batches when the network returns. The queue survives app restarts, and nothing is lost on a day with no signal.
- Batch upload, not one request per point, to save battery and data.
- A heartbeat reports permission and location-service state so the admin can tell "stopped moving" apart from "tracking broken".

**Acceptance**
- With aeroplane mode on for an hour of driving, all points appear after reconnecting, with their original timestamps.
- Points are rejected or flagged per BR-10, and rejected points never inflate distance.
- Battery drain over an 8-hour shift is measured and recorded. Target is under 20% of a typical battery on top of normal use. **This is a target to validate, not a guarantee.**
- The persistent notification is visible for the entire session.

### F5 — Employee map and today's totals

- MapLibre map centred on the employee's own position, with a re-centre button.
- Today's route drawn as a line as they move.
- Live cards: **hours on duty** and **km driven** today.
- Banners when GPS is off, the network is down, or points are queued offline.
- The employee sees **only themselves**, never a colleague.

**Acceptance**
- The map renders within 3 seconds on a mid-range phone on 4G.
- Totals match the server's figures within a small, documented tolerance; the server's value is shown once synced.
- Closing the map screen does not stop tracking.

### F6 — Live map (Admin)

- All employees on one MapLibre map, coloured by the status table above.
- Marker clustering when zoomed out, so 150 markers remain usable.
- Filters: status, place, search by name or code.
- Tapping a marker opens a card: name, code, status, last update time, today's hours and km, battery, and buttons for profile and route view.
- Updates arrive over Supabase Realtime. A connection-lost indicator appears when the stream drops, and the map recovers on reconnect.
- A list view alternative to the map, for when the map is awkward.

**Acceptance**
- A position change reaches the admin map within about 5 seconds of being accepted by the server.
- With 150 employees on screen the map stays responsive, and this is measured on a mid-range phone.
- Killing the network and restoring it reconnects the stream without a restart, and the map backfills.

### F7 — Duty history and attendance (Admin + Employee)

- Per-employee list of sessions: date, start, end, end reason, hours, km, visit count, mock-flag count.
- Monthly attendance view: days worked, total hours, total km, days with an auto-end, days absent.
- Sessions ended automatically are clearly labelled **"Duty ended automatically"**.
- Filter by date range, end reason, and whether flags are present. Paginated.
- The employee sees the same data for themselves only.

**Acceptance**
- Totals reconcile exactly with the underlying session rows.
- A day with several sessions sums correctly.
- A session still open shows as in progress, never as zero hours.

### F8 — Route view (Admin)

**A picture, not a video.** Playback was deliberately cut from scope on 2026-10-13. An admin opens an employee and a date and sees the route drawn, with the totals. There is no animation to wait through.

**Explicitly not built:**
- ❌ Play / pause controls
- ❌ Timeline scrubber
- ❌ Speed controls
- ❌ A marker animating along the route

**What it shows:**
- The route drawn as a **highlighted line** on the map
- **Total kilometres**
- **Total hours on duty**
- **Current location**, when the date is today
- Start and end markers, visit pins, geofence entry points
- Flagged points: outliers and mock locations are visually distinct and **excluded from the drawn distance**

Long routes are simplified for drawing, so a 300 km day does not stall the map. The underlying data is never altered.

**Available for any day within the 30-day retention window.** Older dates still show hours, km and visits from `daily_summaries`, with an empty state explaining that the detailed route has expired.

**Acceptance**
- The drawn route matches the stored points, in time order.
- A day with no points shows a clear empty state, not a broken map.
- A 10-hour, 3,000-point day loads within 5 seconds.
- Totals shown here reconcile exactly with the attendance screen.

### F9 — Places and geofencing (Admin)

- Admin creates a place: name, type (farm, dealer, office, warehouse, other), position picked on the map or entered as coordinates, radius (**default 500 m**), optional address, active flag.
- Geofence evaluation is **server-side** on each accepted point, so the employee's phone carries no extra battery cost.
- Entering raises an `enter` event, notifies admins, and prompts the employee for a visit photo.
- Leaving raises an `exit` event and records the dwell time.
- Hysteresis prevents repeated enter/exit events when an employee sits on the boundary. A re-entry within a short cooldown does not raise a new event.
- Places list with search, type filter, and active filter. Paginated.

**Acceptance**
- Entering a 500 m radius raises exactly one enter event, even with jittery GPS.
- Deactivating a place stops new events but preserves all history.
- A place can be edited without corrupting past events; events store the radius that applied at the time.

### F10 — Visits with photo proof (Employee)

- **Auto-prompt:** on geofence entry, the employee is prompted to add a photo and an optional note.
- **Manual check-in:** available at any time while on duty, for a farm or dealer that is not a registered place.
- The photo is taken **in-app from the camera only.** Choosing from the gallery is not allowed, so an old photo cannot be passed off as today's.
- Stored with the visit: GPS at capture, server timestamp, place (if any), note, photo.
- Compressed on the device before upload: longest edge 1280 px, target about 200 KB. This protects the employee's mobile data as well as the storage budget.
- Photos upload through the offline queue and survive a restart.
- **Skippable.** Skipping asks for a short reason and records `photo_skipped = true`.

### Photos are hosted on Cloudinary, not Supabase Storage

Two configurations are **mandatory**, because neither is Cloudinary's default and getting either wrong is silent:

1. **Delivery type must be `authenticated`.** Cloudinary URLs are public by default. `authenticated` requires a signature for both the original and its derivatives. The `private` type is **not sufficient** — under `private`, derived versions remain publicly accessible, and derivatives are exactly what the thumbnails are.
2. **Uploads must be signed.** An unsigned upload needs only the cloud name and upload preset, both trivially extracted from a decompiled APK, which would let anyone fill the account. The app requests a signature from a Supabase Edge Function; **the Cloudinary API secret never ships in the app.**

Thumbnails are generated as Cloudinary derivatives so the admin's visit list loads small images rather than full photos.

Full detail in [10-CLOUDINARY-BEST-PRACTICES.md](10-CLOUDINARY-BEST-PRACTICES.md) and [05-SECURITY.md](05-SECURITY.md).

**Acceptance**
- The gallery cannot be reached from the visit flow.
- A visit created with no network uploads later, and the photo arrives intact.
- A skipped photo still produces a visit record, flagged in the list and in reports.
- **A photo URL opened while signed out is refused.** Attempted and verified, not assumed.
- **An upload attempted without a server-issued signature is refused.** Attempted and verified.
- Deleting an employee's data removes their photos from Cloudinary as well as their rows from Postgres. Two systems, one deletion path.

### F11 — Fake GPS detection (flag only)

Three independent signals, all **flagging only**. None of them ends duty, blocks the employee, or deletes data.

1. **OS mock flag** — Android reports that the location came from a mock provider.
2. **Physics check** — the implied speed between consecutive points exceeds 150 km/h, or the position jumps impossibly far.
3. **Mock app present** — a known mock-location app is installed, or developer options have a mock app selected. Informational only, and the weakest signal.

Flags surface as: a red marker on the live map, a flagged count on the session, distinct points in the route view, a flag column in reports, and an admin notification on the first flag of a session.

**Acceptance**
- A test with a mock-location app raises a flag within one upload cycle.
- A legitimate flight or train journey is flagged by the physics check but never auto-penalised. **This false-positive case must be documented for admins**, so they interpret flags rather than trust them blindly.
- Flagged points are excluded from distance but retained in the data.

### F12 — Notification centre (Admin, in-app only)

- A bell with an unread badge on the admin home screen.
- Notification types: duty on, duty off, auto-end at curfew, geofence enter, geofence exit, first mock-GPS flag of a session, GPS or location services turned off, no signal for over 10 minutes, battery under 15%, failed login, login from a new device, account locked after failed attempts.
- Each notification shows the employee, the event, the time, and opens the relevant screen.
- Read state is **per admin**, so one admin reading something does not clear it for the others.
- Filters: unread only, type, employee, date range. Paginated.
- New notifications arrive live over Realtime while the app is open.
- **No push notification.** With the app closed, notifications wait in the centre.

**Acceptance**
- A duty-on event appears for an admin with the app open within about 5 seconds.
- Marking read for admin A leaves it unread for admin B.
- Low-value repeats are grouped rather than flooding the list.

### F13 — Reports export (Admin)

- Report types: daily detail, employee range summary, team summary for a period, visit log, geofence visit log.
- Every report includes: date, employee name and code, duty in and out times, end reason, total hours, total km, visit count, photos attached, photos skipped, geofence visits, and flag counts.
- Formats: **PDF** for printing and sharing, **Excel** for analysis.
- **English only.**
- Branded header with the company name and the brand colour; period, generation timestamp, and the generating admin are printed on the report.
- Generated **server-side** for anything beyond a small range, so a 150-employee month does not have to be assembled on a phone. Generation is asynchronous, with progress shown and the finished file delivered through a signed link.
- Shareable through the Android share sheet.

**Acceptance**
- A month of 150 employees generates without the app freezing or running out of memory.
- Report figures reconcile exactly with the attendance screen.
- A period with no data produces a valid report that says so, not an error.
- Every export is written to the audit log, because exports remove personal data from the system.

---

## 5. Data model

Final column names are confirmed against the live database before any query is written. See Rule 3 in [04-RULES.md](04-RULES.md).

| Table | Purpose | Key points |
|---|---|---|
| `profiles` | One row per user, admin or employee | `employee_code` unique, `role`, `status`, block fields, `device_id`, `must_change_pin` |
| `duty_sessions` | One row per duty on→off | `started_at`, `ended_at`, `end_reason`, `total_km`, `total_seconds`, counters. One open session per employee, enforced by a unique partial index |
| `location_points` | Raw GPS history | `session_id`, `captured_at`, position, `accuracy_m`, `speed_mps`, `battery_pct`, `is_mock`, `is_outlier`. The highest-volume table; see retention |
| `live_locations` | Latest position, one row per employee | What the admin map subscribes to. Kept separate so Realtime carries 150 rows, not millions |
| `places` | Geofenced locations | Position, `radius_m` default 500, `type`, `is_active` |
| `geofence_events` | Enter and exit events | Stores the radius that applied at the time, plus dwell time on exit |
| `visits` | Visit proof | `place_id` nullable for manual check-ins, `cloudinary_public_id`, `photo_skipped`, `photo_skip_reason`, `note`, GPS, server timestamp. The photo itself lives in Cloudinary; Postgres stores only its identifier |
| `notifications` | In-app notification content | Type, severity, employee, links to the related record |
| `notification_reads` | Per-admin read state | `(notification_id, admin_id)`, so read state is per admin |
| `daily_summaries` | One row per employee per day | Pre-aggregated hours, km, visits, flags. Powers reports and survives raw-point deletion |
| `app_settings` | Server-side configuration | Duty window, timezone, intervals, thresholds. Changing a rule must not need an app release |
| `audit_log` | Who did what | Every admin action: create, edit, block, PIN reset, device clear, export |

### Retention

| Data | Kept | Then |
|---|---|---|
| `location_points` | **30 days** | Deleted after `daily_summaries` and session totals are confirmed written |
| `daily_summaries`, `duty_sessions` | Indefinitely | The permanent attendance record |
| `visits` records | Indefinitely | Small rows |
| Visit **photos** (Cloudinary) | **12 months**, to be confirmed | Deleted on a schedule; cost driven, see section 7 |
| `notifications` | 6 months | Deleted |
| `audit_log` | Indefinitely | Compliance record |

Deleting raw points after 30 days is what keeps this inside the Supabase Free database limit. **The route view is therefore available for the last 30 days only;** older days still show hours, km, visits, and flags from `daily_summaries`.

The 30-day window is a direct consequence of the decision to stay on Supabase Free. On the Pro plan it would extend to 60 days or more. Raised as Q3.

---

## 6. Scale and performance targets

**Launching with 50 employees. The architecture targets 150**, so growth needs no rework: clustering, pagination, indexing, and query design are all sized for 150. Only the hosting plan is sized for 50.

Based on a 15-hour window and about 22 working days a month.

| Metric | At 50 (launch) | At 150 (target) |
|---|---|---|
| GPS points per employee per day | 900–1,500 | 900–1,500 |
| Points per day, all employees | ~45,000–75,000 | ~135,000–225,000 |
| Points per month | ~1.0–1.65 million | ~3.0–5.0 million |
| Rolling **30-day** table size | ~1.35–2.25M rows, **~220–360 MB** | ~4.0–6.8M rows, ~0.7–1.1 GB |
| Visits per month | ~5,500 | ~16,500 |
| Photo volume per month | ~1.1 GB at 200 KB each | ~3.3 GB |
| Admin Realtime subscribers | Under 10 | Under 10 |

### The points-per-day figure is an estimate, and it drives everything

900–1,500 assumes roughly 6 hours moving at a 30-second interval plus 9 hours stationary at 3 minutes. **The real ratio is unknown until real shifts are tracked.** A team that drives more produces far more rows.

**This must be measured in Phase 2 from real tracked shifts, and the retention window set from the measurement rather than from this estimate.** Treat the table above as a planning figure, not a fact.

### Supabase Free database ceiling

Budgeting 400 MB for `location_points` (leaving headroom for every other table, plus index bloat and WAL) against the 500 MB Free limit:

> **The ceiling is roughly 65–90 employees at 30-day retention**, depending on the measured movement ratio.

Launching at 50 leaves real headroom. **Growing past about 65 employees requires either Supabase Pro or a shorter retention window.** This is a monitored trigger, not a surprise — see section 7.

### Targets

| Target | Value |
|---|---|
| App cold start | Under 3 seconds on a mid-range Android phone |
| Live map first paint | Under 3 seconds |
| Position to admin map | Under 5 seconds |
| Any list page load | Under 1 second |
| Route view, 3,000 points | Under 5 seconds |
| Duty toggle response | Under 2 seconds, with immediate optimistic feedback |
| Crash-free sessions | Over 99.5% |

---

## 7. Cost implications

**Decision: launch on Supabase Free with photos on Cloudinary.** Target cost at launch is **$0/month** plus the one-time $25 Play fee.

Figures to confirm before launch. Treat every number here as `VERIFY`.

| Item | Plan | Note |
|---|---|---|
| **Supabase** | **Free** | 500 MB database, 5 GB egress, no credit card. Viable at 50 employees with 30-day retention (~220–360 MB estimated). **Accepted trade-offs: no reliable backups, 30-day route history, and a hard ceiling around 65–90 employees.** Inactivity pausing is not a practical risk, since 50 employees use the app daily. |
| **Photos — Cloudinary** | **Free** | 25 credits/month, where credits are **summed** across storage, bandwidth and transformations — it is **not** 25 GB of storage. Storage is a running snapshot that accumulates monthly and never resets. Expect roughly **12–18 months free**, then a paid plan or shorter photo retention. On-the-fly thumbnails are the main benefit: the admin visit list loads small derivatives instead of full photos, which protects the bandwidth budget. |
| **Maps — MapLibre + OpenFreeMap** | **Free, permanently** | **No account, no API key, no request limits, no usage caps to monitor, and no terms restricting employee tracking.** There is no billing relationship to manage and nothing that can be exceeded. The trade-offs are no satellite imagery and no SLA, both accepted — see [07-MAPLIBRE-BEST-PRACTICES.md](07-MAPLIBRE-BEST-PRACTICES.md) section 0. |
| **Google Play** | — | $25 one-time registration. |
| **Distance and geocoding** | — | Zero. Distance is computed from our own points; no Directions or Geocoding API is used. |

### Monitored upgrade triggers

Free tiers fail quietly. Each of these is checked monthly, and hitting one is a decision point, not an emergency.

| Trigger | Threshold | Action |
|---|---|---|
| Supabase database size | **400 MB** | Shorten point retention, or upgrade to Pro ($25/mo) |
| Employee count | **65** | Re-measure points per day; likely upgrade to Pro |
| Supabase egress | **4 GB/month** | Investigate what is being over-fetched before paying |
| Cloudinary credits | **20 of 25** | Reduce photo retention, or move to a paid plan |
| Real payroll disputes relying on history | **the first one** | **Upgrade to Pro for backups.** See the risk below. |

### The accepted risk, stated plainly

**Supabase Free has no reliable backups.** This database holds the attendance record that wages are paid from. If it is lost, it cannot be reconstructed — photos on Cloudinary will not rebuild hours or distance.

Mitigations required before go-live, since the platform provides none:
- A **scheduled export of `duty_sessions`, `daily_summaries`, `visits`, and `audit_log`** to a file the company keeps, run at least weekly. These are the small, permanent tables; raw GPS points are expendable, but the attendance record is not.
- The restore path is tested before launch, per Phase 6.

Upgrading Free → Pro is expected to be a plan change on the same project rather than a migration, but **this is unverified and must be confirmed in Phase 0** before the plan is relied upon as an easy escape hatch.

---

## 8. Compliance and release

- **Background location** needs a Google Play permission declaration, a demo video, a privacy policy URL, and a prominent in-app disclosure shown before the permission prompt. Allow extra time for review.
- **Play account:** a Personal account created after November 2023 must run a closed test with roughly 12 testers for 14 consecutive days before production access. An Organization account avoids this but needs a D-U-N-S number. **Still an open decision.** Verify the current requirement on the Play Console help pages.
- **Consider a private or internal distribution**, since this is a company tool rather than a public app.
- **Employee consent** to location tracking must be captured in-app and retained. This is both a Play requirement and sound practice.
- A **Data Safety** declaration is required, and it must disclose location and photo collection truthfully.
- Target API level must meet Google's current requirement, which rises annually.

---

## 9. Key risks

| Risk | Impact | Mitigation |
|---|---|---|
| **Android battery killers** (Xiaomi, Oppo, Vivo, Realme, Samsung) stop background tracking | High. The core feature silently fails | Foreground service; guided battery-optimisation onboarding per manufacturer; "no signal for 10 minutes" alert so failures are visible; **test on real cheap devices in Phase 1, not at the end** |
| Play rejects the background location declaration | High. Blocks release | Prepare the disclosure, policy, and video early; consider private distribution |
| **Database loss on Supabase Free, which has no reliable backups** | **High. The attendance record wages are paid from is unrecoverable** | **Mandatory weekly export** of `duty_sessions`, `daily_summaries`, `visits`, `audit_log` to a company-held file; restore rehearsed in Phase 6; upgrade to Pro at the first real payroll dispute |
| Free-tier limits reached without anyone noticing | Medium to high. Writes start failing in production | The monitored triggers in section 7, checked monthly, with a named owner (Q5b). **A trigger nobody checks is not a mitigation.** |
| Storage cost grows faster than expected | Medium | 30-day point retention, photo compression, photo retention policy, monitor monthly |
| Cloudinary misconfigured, leaving photos public | **High. A privacy breach, not a bug** | `authenticated` delivery and signed uploads, both set before the first real photo; **thumbnail exposure tested separately** from the original, since `private` would leave derivatives public |
| Points-per-day estimate wrong, so the Free plan fails sooner | Medium | Measure the real figure from Phase 2 shifts and set retention from the measurement, not the estimate |
| Employees fake location | Medium | Flagging per F11, one-device binding, server-side distance; flags are reviewed by a human, never auto-punitive |
| Staff resist being tracked | Medium | Tracking only while on duty; visible persistent notification; the employee sees their own data; consent captured |
| ~~Mapbox terms may not permit employee tracking~~ | **Resolved 2026-10-13** | Switched to MapLibre + OpenFreeMap, which carry no use-case restriction. The risk is eliminated rather than mitigated. |
| **MapLibre clustering may not work at 150 markers** | **Medium.** The admin live map depends on it | Proven by the mandatory Phase 2 spike **before** any map screen is built. If it fails, stop and reconsider rather than work around it — see Q6b |
| **OpenFreeMap has no SLA** — one maintainer, donation funded | Medium. Maps stop rendering; **tracking itself is unaffected** | They publish weekly downloads, so the same tiles can be self-hosted. Fallback documented in [07-MAPLIBRE-BEST-PRACTICES.md](07-MAPLIBRE-BEST-PRACTICES.md) section 7. The map is never a hard dependency of duty, GPS recording, or visit capture |
| Realtime connection limits | Low | Only admins subscribe; employees use plain inserts |

---

## 10. Open questions

| # | Question | Needed by |
|---|---|---|
| Q1 | Play account: Personal or Organization? | Before Phase 6 |
| Q2 | Public listing or private/internal distribution? | Before Phase 6 |
| Q3 | ~~Is 30-day route history acceptable?~~ — **resolved 2026-10-13: yes, 30 days confirmed.** Admins can open any past day within the window. | Resolved |
| Q4 | Photo retention: is 12 months right? Drives when Cloudinary's free credits run out. | Before Phase 4 |
| Q5 | ~~Approval for Supabase Pro~~ — **resolved: launching on Supabase Free + Cloudinary.** Replaced by Q5b. | Resolved |
| Q5b | Who owns the monthly check of the upgrade triggers in section 7, and where is the weekly attendance export kept? | Before go-live |
| Q6 | ~~Does Mapbox permit employee tracking?~~ — **resolved by removing the question.** Switched to MapLibre + OpenFreeMap, which carry no use-case restriction. Replaced by Q6b. | Resolved |
| Q6b | **Does MapLibre clustering work with 150 markers on a budget phone?** No clustering API found documented in the Flutter plugin. Must be proven by the spike in section 0 of [07-MAPLIBRE-BEST-PRACTICES.md](07-MAPLIBRE-BEST-PRACTICES.md). | **Early Phase 2, before any map screen is built** |
| Q9 | Confirmed Cloudinary free-tier credit behaviour, and that `authenticated` delivery is available on the Free plan | Before Phase 4 |
| Q7 | Sunday and holiday handling: is the duty window the same every day? | Before Phase 1 |
| Q8 | Overtime: should an employee be able to request an extension past 23:00? | Before Phase 3 |

---

## 11. Definition of done, v1

- All of F1 to F13 pass their acceptance criteria.
- Verified on at least three real Android devices, including one budget phone from an aggressive-battery manufacturer.
- An 8-hour real-world shift tracked end to end with no data loss and no unexplained gap.
- Tested with 150 seeded employees for map and list performance.
- Every employee-facing and admin-facing screen has loading, empty, and error states, per [03-DESIGN-SYSTEM.md](03-DESIGN-SYSTEM.md).
- RLS verified by attempting cross-employee access and having it fail.
- Supabase advisors clean, or every exception documented.
- Reports reconcile with the attendance screens.
- [CHANGELOG.md](../CHANGELOG.md) complete, and all docs current.
