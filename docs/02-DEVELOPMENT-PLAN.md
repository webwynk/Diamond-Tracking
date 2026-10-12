# 02 — Development Plan

Phase-by-phase build order. Each phase has a goal, tasks, exit criteria, and risks.

**Every phase and every task inside it needs explicit approval before starting.** See Rule 1 in [04-RULES.md](04-RULES.md).

Phases are ordered so that the **riskiest thing is proven earliest**. Background GPS on cheap Android phones is the single biggest threat to this product, so it is validated in Phase 1 rather than discovered in Phase 6.

**No time estimates are given.** They would be guesses. Progress is measured by exit criteria.

---

## Phase 0 — Foundation and accounts

**Goal:** a running, themed, empty app connected to a real backend.

### Tasks
1. Create the Supabase project in `ap-south-1` on the **Free plan**. Record the project ref; never commit keys.
2. **Confirm whether Free → Pro is an in-place plan change** rather than a migration. The entire fallback plan depends on this, and it is currently unverified.
3. ~~Create a map-provider account~~ — **not required.** MapLibre + OpenFreeMap need no account, token or usage cap.
4. Create the Cloudinary account. Create a **signed** upload preset with delivery type **`authenticated`**. Keep the API secret out of the repo entirely. **Q9 must be answered first.**
5. Initialise the Flutter project. Package name, app name, minimum SDK, target SDK.
6. Initialise git. Add a `.gitignore` that excludes every secret, keystore, and env file — **including `env.json`, before the first commit.**
7. Wire configuration through build-time environment values. **No key is ever hardcoded.**
8. Add the folder structure, dependencies, linting, and formatting.
9. Build the theme from [03-DESIGN-SYSTEM.md](03-DESIGN-SYSTEM.md): DM Sans, the colour tokens, the type scale, the component defaults. **Light theme only, forced — the system dark-mode setting is ignored.**
10. Build the shared widget library: buttons, inputs, cards, empty state, error state, loader, skeletons, snackbars, badges.

### Exit criteria
- The app runs on a device, shows a themed placeholder, and connects to Supabase.
- Every colour and text style comes from a token. No literal hex or font size anywhere in widget code.
- The analyzer is clean.
- No secret is present in git history. **Verified by searching the history, not by assuming.**
- The Cloudinary preset is confirmed as signed with `authenticated` delivery, before any photo exists.

### Risks
Getting the theme wrong here means repainting every screen later. Build the widget library before any feature screen.

---

## Phase 1 — Auth, roles, and the background tracking spike

**Goal:** people can log in, and **background GPS is proven to work on real cheap phones.**

This phase deliberately mixes auth with a technical spike. Do not postpone the spike.

### Tasks
1. Design the `profiles` schema and the admin/employee role model. Enable RLS. Expose only what is needed.
2. Create the first admin manually in the Supabase dashboard.
3. Build the employee-code plus PIN login flow, mapped onto Supabase Auth.
4. Build the admin email and password login.
5. Forced PIN change on first login; PIN rules; failed-attempt lockout.
6. Device binding: capture `device_id` at first login, refuse a second device, notify admins.
7. Role-based routing, so an employee can never reach an admin route.
8. **Tracking spike:** foreground service, persistent notification, background location permission flow, adaptive interval, local queue.
9. **Battery-optimisation onboarding**, with manufacturer-specific guidance for Xiaomi, Oppo, Vivo, Realme, and Samsung.
10. **Test on at least three real devices, one of them a budget phone**, for an unattended 8-hour run.

### Exit criteria
- Both login flows work; blocked and wrong-credential paths show correct errors.
- A second device is refused.
- RLS verified: an employee's token cannot read another employee's row. Attempted and failed.
- **The 8-hour background run completed on a budget phone with no unexplained gap.** If it did not, stop and solve it before Phase 2.
- Battery drain over the run is measured and recorded in the changelog.

### Risks
This is the highest-risk phase. If background tracking cannot be made reliable here, the product design has to change, and it is far cheaper to learn that now.

---

## Phase 2 — Duty sessions, tracking pipeline, and the employee map

**Goal:** an employee can work a full day and have it recorded accurately.

### Task 0 — MapLibre spike. Do this FIRST.

Roughly half a day, **before any map screen is built on this stack.** Tracked as PRD **Q6b**.

- [ ] A map renders using OpenFreeMap tiles on a real Android device
- [ ] **150 markers cluster correctly**, and clusters expand on zoom
- [ ] Pan and zoom hold a usable frame rate **on a budget phone**, not a flagship
- [ ] A line layer draws a 3,000-point route after simplification
- [ ] A circle renders in real ground metres, for the 500 m geofence preview
- [ ] Attribution renders correctly

**If clustering fails, stop and report before continuing.** The admin live map depends on it, and the answer would be a product decision, not a workaround. Full detail in section 0 of [07-MAPLIBRE-BEST-PRACTICES.md](07-MAPLIBRE-BEST-PRACTICES.md).

### Tasks
1. Schema: `duty_sessions`, `location_points`, `live_locations`, `app_settings`. Indexes planned deliberately.
2. Unique partial index guaranteeing one open session per employee.
3. Server-side duty-start check against the 08:00–23:00 window, using **server time**. Depends on PRD Q7.
4. Duty toggle UI, with the disabled state and the reason shown.
5. Batch point upload endpoint with the BR-10 validation rules.
6. Server-side distance calculation, with outliers excluded.
7. `live_locations` updated on each accepted batch.
8. Offline queue that survives restarts, with a visible queued-points indicator.
9. Heartbeat reporting permission and location-service state.
10. Employee map: own position, re-centre, today's route, live hours and km cards, warning banners.
11. Duty-off summary screen.

### Exit criteria
- A real tracked shift produces correct hours and a plausible km total.
- An hour in aeroplane mode loses nothing; all points arrive with original timestamps.
- Rapid toggling never creates two open sessions. Attempted deliberately.
- Fake and out-of-range points are rejected or flagged and do not inflate distance.
- The map renders inside the 3-second target.
- Closing the map screen does not stop tracking.

---

## Phase 3 — Admin: live map, notifications, history, route view

**Goal:** admins can see and reconstruct everything.

### Tasks
1. Schema: `notifications`, `notification_reads`, `audit_log`.
2. Employee management: create (server-side), edit, block with reason, unblock, PIN reset, clear device.
3. Blocking closes an open session in the same transaction.
4. Employee list: search, status and duty filters, pagination.
5. Employee profile and stats.
6. Live map: clustering, status colours, filters, marker detail card, list-view alternative.
7. Realtime subscription with reconnect handling and a connection-lost indicator.
8. Notification centre: badge, list, per-admin read state, filters, pagination, live arrival.
9. Duty history and monthly attendance, for admin and employee.
10. **Auto-end at 23:00** scheduled job, plus the 22:45 employee reminder.
11. **Route view (not a replay):** the route drawn as a highlighted line, total km, total hours, current location, start/end/visit markers, and route simplification for drawing. **No play, pause, scrubber, speed control or animation** — cut from scope 2026-10-13.
12. Audit logging on every admin action.

### Exit criteria
- A duty-on event reaches an open admin app within about 5 seconds.
- Read state is genuinely per admin. Verified with two admin accounts.
- Auto-end fires at 23:00 IST and labels the session "Duty ended automatically". Verified against a real session, not just a unit test.
- Blocking an on-duty employee closes the session within 10 seconds and the marker turns black.
- 150 seeded employees: map and lists meet their performance targets. Measured, not assumed.
- A 3,000-point day's route view loads inside 5 seconds.
- Totals reconcile with the session rows.

---

## Phase 4 — Places, geofencing, visits, and fake-GPS flagging

**Goal:** visits are proven, and suspicious data is visible.

### Tasks
1. Schema: `places`, `geofence_events`, `visits`. The `visits` row stores the Cloudinary `public_id`, never a full URL.
2. Place management: create, edit, deactivate, with map picking and a 500 m default radius. List with filters and pagination.
3. Server-side geofence evaluation on each accepted point, including the hysteresis and cooldown rules.
4. Enter and exit events, dwell time, admin notifications.
5. Visit auto-prompt on geofence entry.
6. Manual check-in anywhere while on duty.
7. **Camera-only capture.** The gallery must be unreachable.
8. Client-side compression to 1280 px and roughly 200 KB.
9. **Edge Function issuing Cloudinary upload signatures.** The API secret stays server-side.
10. **Edge Function issuing short-lived signed read URLs**, batched for list views. This is the only place the "an employee sees only their own photos" rule exists, because Cloudinary has no row-level security.
11. Photo upload through the offline queue, surviving restart, with a **deterministic `public_id`** so a retry overwrites instead of creating a duplicate.
12. Thumbnail derivatives for the visit list, from a small fixed set of named transformations.
13. Skip flow with a reason, recorded as `photo_skipped`.
14. **Deletion path covering both systems**, so removing a visit or an employee clears the Cloudinary asset too.
15. See [10-CLOUDINARY-BEST-PRACTICES.md](10-CLOUDINARY-BEST-PRACTICES.md) for the full checklist.
16. Fake-GPS flagging: OS mock flag, physics check, mock-app presence. **Flag only.**
17. Flag surfacing on map, route view, lists, reports, and a first-flag notification.
18. **Admin guidance documenting false positives**, so flags are interpreted rather than trusted blindly.

### Exit criteria
- Entering a 500 m radius raises exactly one enter event despite GPS jitter. Tested on foot.
- Deactivating a place stops new events and preserves history.
- Visits created offline upload intact, photo included.
- The gallery cannot be reached from the visit flow. Attempted.
- **A photo URL opened while signed out is refused.** Attempted.
- **A thumbnail URL opened while signed out is refused.** Attempted separately — this is the `private` delivery-type trap.
- **An upload without a server-issued signature is refused.** Attempted.
- **A retried upload produces one asset, not two.** Verified in Cloudinary, not inferred from the app.
- Deleting a visit removes the Cloudinary asset as well as the row.
- A mock-location app raises a flag within one upload cycle, and **duty does not end.**
- Flagged points are excluded from distance but retained.

---

## Phase 5 — Reports, summaries, and retention

**Goal:** the data becomes something the business can use and afford.

### Tasks
1. Schema: `daily_summaries`.
2. Nightly aggregation job writing the summaries.
3. The five report types from PRD F13.
4. Server-side generation for large ranges, asynchronous, with progress and a signed download link.
5. PDF layout: branded header, period, generation timestamp, generating admin.
6. Excel export with proper typed columns.
7. Share-sheet integration.
8. Report filters: employee, team, date range, type.
9. **Retention jobs:** delete points older than **30 days**, but only after confirming summaries are written. Delete old notifications. Photo retention per PRD Q4, clearing Cloudinary and Postgres together.
10. Export events written to the audit log.
11. **Weekly attendance backup export** of `duty_sessions`, `daily_summaries`, `visits`, and `audit_log` to a file the company keeps. **Mandatory, because Supabase Free has no reliable backups** and these are the records wages are paid from.
12. **Measure the real points-per-day figure** from the Phase 2 shifts and set the retention window from the measurement, replacing the PRD's 900–1,500 estimate.
13. Reconciliation job: find `visits` rows with a missing Cloudinary asset, and Cloudinary assets with no row.

### Exit criteria
- A 150-employee month generates without freezing or running out of memory.
- Report figures reconcile exactly with the attendance screens.
- An empty period produces a valid report, not an error.
- The retention job is proven **not** to delete points whose summaries are missing. Tested with a deliberately missing summary.
- Database size after a simulated month is measured against the estimate, and against the **400 MB trigger**.
- The weekly attendance export runs, and **a restore from it has been rehearsed successfully.**
- Cloudinary credit usage is measured against the 20-of-25 trigger.

---

## Phase 6 — Hardening

**Goal:** make it survive the real world.

### Tasks
1. Full pass over loading, empty, and error states on every screen.
2. Offline behaviour review across the whole app.
3. Crash and error reporting, with **no location data or PII in the reports.**
4. Performance pass: cold start, map, lists, route view. Measured against the PRD targets.
5. Battery pass on each test device.
6. Security review against [05-SECURITY.md](05-SECURITY.md), including a deliberate RLS attack attempt.
7. Supabase advisors clean, or every exception documented.
8. Dead-code sweep across the codebase and the database.
9. Accessibility: touch targets, contrast, text scaling up to 150%, screen-reader labels.
10. Multi-device test matrix, including a budget phone and an aggressive-battery manufacturer.
11. Backup and restore rehearsal from the **weekly attendance export**, since Supabase Free provides no reliable backup of its own. **Verify a restore actually works**, rather than assuming the export is good.
12. Confirm every monitored upgrade trigger from PRD section 7 has a named owner and a monthly check.

### Exit criteria
- Every PRD performance target met and measured.
- No analyzer warnings, no dead code, no unused dependency.
- A cross-employee data access attempt fails.
- A restore rehearsal succeeded.

---

## Phase 7 — Play Store release

**Goal:** shipped, legally and safely.

Depends on PRD Q1 and Q2 being answered.

### Tasks
1. Create the Play Console account. $25 fee. Confirm Personal vs Organization.
2. Privacy policy published at a public URL, covering location and photo collection honestly.
3. In-app prominent disclosure before the location permission prompt.
4. In-app consent capture, retained.
5. **Background location permission declaration**, with the demo video showing the in-app disclosure, the foreground notification, and why background location is necessary.
6. Data Safety form, declared truthfully.
7. Release signing: generate the keystore, **back it up securely.** Losing it means never updating the app again.
8. Store listing: icon, screenshots, description, and the brand colour.
9. Internal testing track, then closed testing if a Personal account requires it.
10. Target API level check against Google's current requirement.
11. Submit, respond to review feedback, release.

### Exit criteria
- The release build is installed and verified from the Play track, not just from a local build.
- The permission declaration is approved.
- The keystore is backed up in at least two safe places.
- A rollback plan exists.

---

## Phase 8 — Post-launch and deferred work

Not started until v1 is stable in production.

Deferred, in rough value order:
1. Admin web dashboard
2. Task assignment and visit planning
3. Travel allowance from km × rate
4. SOS button
5. Leave requests and announcements
6. Team-scoped admin roles
7. Performance scoring
8. Multi-language
9. iOS release

---

## Cross-phase standing rules

These apply inside every phase, not at the end.

1. Each task: propose, get approval, implement, verify, changelog. Per [04-RULES.md](04-RULES.md).
2. Every list is paginated from the first version. Never build an unpaginated list intending to fix it later.
3. Every async surface gets loading, empty, and error states in the same task that creates it.
4. Every new table gets RLS in the same migration that creates it. Never "add security later".
5. Test the unhappy path in the same task as the happy path.
6. Run the dead-code sweep after every task, not only in Phase 6.
7. Test on a real budget device at every phase boundary.
8. Re-read the live database schema before writing any query.
