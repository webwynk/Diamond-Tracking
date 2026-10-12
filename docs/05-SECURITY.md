# 05 — Security

This app continuously records where 150 real people are, and stores photographs of the places they visit. That makes it a **high-sensitivity personal data system**, not an ordinary CRUD app. Treat it accordingly.

Read this before touching auth, RLS, storage, location data, keys, or exports.

---

## 1. Threat model

Who we are defending against, in order of likelihood.

| # | Threat | What they want | Primary defence |
|---|---|---|---|
| T1 | **A curious or hostile employee** | See colleagues' locations; fake their own hours and distance | RLS, server-side time and distance, mock-GPS flagging, device binding |
| T2 | **An employee with a rooted phone or an intercepting proxy** | Call the API directly to forge points or sessions | Server-side validation of every rule; the client is never trusted |
| T3 | **A leaked API key or decompiled APK** | Read the whole database | Publishable key only in the app; RLS assumed to be the sole defence; **never a service-role key in the client** |
| T4 | **A lost or stolen employee phone** | Access the app and its data | PIN on login, short sessions, remote block, no sensitive data cached in plain text |
| T5 | **An insider admin** | Bulk-export staff location history | Audit log on every admin action and every export |
| T6 | **A third party** receiving an exported report | Personal data spreading beyond the company | Reports are marked confidential and every export is logged |

**Core assumption: the Android app is public. Anything shipped inside it is readable by anyone.** Security lives on the server.

---

## 2. Keys and secrets

### Rules
- The app ships **only** the Supabase URL, the **publishable (anon) key**, and the Cloudinary cloud name and signed upload preset name. **There is no map credential at all** — MapLibre + OpenFreeMap need no account or token.
- **The `service_role` / secret key never appears in the app, in git, in a log, or in a screenshot.** It lives only in Edge Function secrets and the Supabase dashboard.
- No key is hardcoded. Configuration comes in at build time.
- `.gitignore` excludes every env file, keystore, and generated config before the first commit.
- The Cloudinary cloud name and preset name are not secrets once uploads are signed, but they are still kept in configuration rather than hardcoded.
- Keys are rotatable. Know the rotation procedure before launch, not during an incident.
- If a key is ever exposed, **rotate it immediately** and log the incident in [CHANGELOG.md](../CHANGELOG.md).

### The release keystore
- Generate it once, back it up in **at least two separate safe places**, and record the passwords in a password manager.
- **Losing it means the app can never be updated again.** This is unrecoverable.
- It is never committed to git.

---

## 3. Authentication

- Employees authenticate with employee code plus a 6-digit PIN, mapped onto Supabase Auth. **There is no self-registration.** Accounts are created only by an admin, through a server-side function.
- PIN rules: exactly 6 digits, no repeated single digit, no trivial ascending or descending sequence. Forced change on first login.
- A PIN is a low-entropy secret, so **rate limiting is what makes it safe**: 5 failed attempts locks the account for 15 minutes and notifies admins.
- Login errors must not reveal whether an employee code exists.
- **Device binding:** the first successful login records a device identifier. A login from a different device is refused and raises an admin notification. Only an admin can clear the binding, and the action is audited.
- Admins use email and password, kept separate from the employee flow. Enable MFA for admins if the platform allows it.
- **Deleting or blocking a user does not invalidate their existing access token.** Blocking must also revoke the session, close any open duty session, and keep token lifetimes short.
- **Never make an authorization decision from `user_metadata`.** It is user-editable. Role and status belong in `app_metadata` or in the `profiles` table, read server-side.

---

## 4. Row-level security

**RLS is the only thing standing between an employee and everyone else's location history.** There is no second layer.

### Non-negotiable rules
1. **RLS is enabled on every table in an exposed schema, in the same migration that creates the table.** Never "add security later".
2. Every policy names its target role explicitly with `to authenticated`. **`auth.role()` is deprecated** and breaks silently if anonymous sign-ins are ever enabled.
3. **`to authenticated` alone is not authorization.** It only checks that someone is signed in. Every policy also needs an ownership or role predicate. Without it, any employee can read every row.
4. **An `update` policy needs both `using` and `with check`.** Without `with check`, a user can reassign a row to someone else.
5. **An `update` also requires a `select` policy**, because the row must be read before it is written. Missing it causes a silent zero-row update with no error — a confusing class of bug.
6. **Views bypass RLS by default.** Any view is created with `security_invoker = true`.
7. **`security definer` functions bypass RLS.** Never add `security definer` to make a permission error go away. Where it is genuinely needed, keep the function out of the exposed schema and check the caller's identity inside the function body.
8. A new function in `public` is executable by everyone by default. Grant execute deliberately.

### Intended access matrix

| Table | Employee | Admin |
|---|---|---|
| `profiles` | Read **own row only**. Update nothing but their own PIN state. | Read all. Insert and update via a server-side function. |
| `duty_sessions` | Read own. Insert and close **only through a server function** that enforces the window. | Read all. No direct edits. |
| `location_points` | Insert own, for an open session only. Read own. **No update, no delete.** | Read all. No edits. |
| `live_locations` | Read own. Written by the server only. | Read all. |
| `places` | Read active places. | Full management. |
| `geofence_events` | Read own. Server-written only. | Read all. |
| `visits` | Insert own, read own. No update, no delete. | Read all. |
| `notifications` | **No access at all.** | Read all. |
| `notification_reads` | No access. | Read and write own read state only. |
| `daily_summaries` | Read own. | Read all. |
| `app_settings` | Read only the non-sensitive values needed for UI. | Read. Write via a server function. |
| `audit_log` | No access. | **Read only. Nobody can write or alter it from the app.** |

### Verification is mandatory
Policies are not trusted until attacked. For every table:
1. Sign in as employee A and attempt to read employee B's rows. **It must return nothing.**
2. Attempt to insert a row attributed to another employee. It must fail.
3. Attempt to update or delete a historical record. It must fail.
4. Attempt to read `notifications` and `audit_log` as an employee. It must fail.
5. Run the Supabase advisors and resolve what they report.

Record the result of each attempt in the changelog. "RLS added" is not evidence; a failed attack is.

---

## 5. Server-side enforcement

Any rule the client could lie about is enforced on the server. Specifically:

| Rule | Why the client cannot be trusted |
|---|---|
| The 08:00–23:00 duty window | The phone clock can be changed in seconds |
| The 23:00 auto-end | The app may be killed, offline, or uninstalled |
| Total distance | A forged client number would be the whole fraud |
| Total hours | Derived from server-stamped session times |
| Point validation — accuracy, speed, future timestamps | The client is the attacker in T2 |
| Geofence entry and exit | Also keeps battery cost off the phone |
| Employee creation and PIN reset | Requires privilege the app must never hold |
| Block, with session closure | Must not be bypassable by staying offline |
| Mock-GPS flagging | Stored server-side so it cannot be edited away |

**Client timestamps are recorded, not trusted.** Every row also carries a server timestamp, and server time is what business logic uses.

---

## 6. Location data protection

Location history is the most sensitive data here.

- **Collect only while on duty.** Never outside an open session. This is both a privacy principle and a Play Store requirement.
- The **foreground service notification stays visible for the entire session**, so an employee is never tracked invisibly.
- **Data minimisation:** raw points are deleted after 30 days; only aggregated summaries persist. Less retained data means less to leak.
- An employee can see their own data, which builds trust and is good practice.
- **No location data in crash reports, analytics, or application logs.** Audit this explicitly in Phase 6.
- No third-party analytics or advertising SDK goes into this app.
- Data stays in the `ap-south-1` region.
- Export is an admin-only, fully audited action.

---

## 7. Visit photos

**Photos are hosted on Cloudinary, not Supabase Storage.** Full detail in [10-CLOUDINARY-BEST-PRACTICES.md](10-CLOUDINARY-BEST-PRACTICES.md). The security-critical points:

### Two settings that are not Cloudinary's defaults

Both fail **silently** if wrong. Nothing errors; the photos are simply public.

- **Delivery type must be `authenticated`.** Cloudinary URLs are public by default. `authenticated` requires a signature for the original **and** its derivatives.
- **`private` is not sufficient.** Under `private`, derived versions stay publicly accessible — and derivatives are exactly what the list thumbnails are. A public thumbnail of an employee's location is the same breach as the full photo.
- **Uploads must be signed.** An unsigned upload needs only the cloud name and preset, both recoverable from a decompiled APK. Without signing, anyone can fill the company's account, including with illegal content hosted under the company's name.
- **The Cloudinary API secret never ships in the app.** It lives only in Edge Function secrets. The app requests an upload signature from the server.

### Still required, as before

- Access is only ever through a **short-lived signed URL**, generated server-side per request.
- An employee can read **only their own** photos. Enforced in the Edge Function that issues URLs, since Cloudinary has no equivalent of row-level security.
- Validate on upload: content type is an image, size within a hard cap, and genuinely an image rather than something renamed.
- Strip EXIF on the device, except the coordinates deliberately recorded on the `visits` row. Never treat EXIF as the source of location truth; it is trivially editable.
- **Camera capture only.** The gallery is unreachable from the visit flow, so a stale photo cannot be submitted as today's proof.
- Photo retention is enforced by a scheduled job. See PRD Q4.
- **Never embed a signed photo URL in an exported report.** It would be a live link to employee location data inside a file that has left the company, and it would then break on expiry.

### New obligations from splitting storage from the database

- **Deletion must span both systems.** Removing an employee's data, or expiring photo retention, must clear the Postgres rows *and* the Cloudinary assets. Clearing one side leaves either orphaned photos exposed and billable, or rows pointing at nothing.
- **Cloudinary is covered by no Supabase backup**, and Supabase Free has no reliable backup either. See the accepted risk in section 7 of [01-PRD.md](01-PRD.md).
- **Two credential sets now need a documented rotation procedure.**

### Verification — attempted, not assumed

- [ ] A photo URL opened while signed out is **refused**.
- [ ] A **thumbnail** URL opened while signed out is **refused**. This is the `private` trap; test it separately.
- [ ] An upload sent without a server-issued signature is **refused**.
- [ ] The API secret is absent from the app, from git history, and from every log.

---

## 8. Audit logging

Written server-side, append-only, readable by admins, writable by nobody through the app.

Every one of these is logged with actor, target, timestamp, and before/after where relevant:
- Create, edit, block, unblock an employee
- PIN reset, device-binding clear
- Create, edit, deactivate a place
- Change an app setting
- **Every report export**, including the filters applied
- Every failed login and every account lockout
- Every login from an unrecognised device

The audit log is the only defence against T5, the insider admin. If it can be edited, it is worthless.

---

## 9. Application-level hardening

- **Validate every input** on the server. Length, type, range, format. Never trust a client-side check.
- Use parameterised queries throughout. No string-built SQL, ever.
- Sanitise anything that reaches a PDF or Excel export. A note field containing a formula must not execute when the spreadsheet is opened — **CSV and Excel formula injection is a real attack path** for an export built from employee-entered text.
- Enforce HTTPS only. No cleartext traffic.
- Consider certificate pinning for the API, weighed against the operational cost of rotating certificates.
- Do not log request or response bodies in release builds.
- Disable screenshots on screens showing bulk employee locations, if the business wants it. Note this is a weak control.
- Pin every dependency version and commit the lockfile. Review what each new package can access before adding it; a location app is an attractive supply-chain target.
- Obfuscate and minify the release build. This slows an attacker; it does not replace server-side enforcement.
- Keep the Android target SDK current.

---

## 10. Privacy and legal

- **Prominent in-app disclosure** before the location permission prompt, explaining what is collected, when, and why, in plain language.
- **Consent captured in-app and retained**, with a timestamp.
- A **published privacy policy** at a public URL, covering location and photo collection, retention periods, and who can see the data.
- An honest **Data Safety** declaration on Google Play.
- Employees are told in writing that tracking happens only during duty hours.
- Define the process for an employee asking what data is held about them.
- Define what happens to an employee's data when they leave the company.

**Consult someone qualified on Indian employment and data-protection obligations before launch.** Nothing in this document is legal advice.

---

## 11. Incident response

Write this down before it is needed, not during.

1. **Contain** — rotate the affected key, revoke sessions, block the account.
2. **Assess** — what data, whose data, how much, over what period. Use the audit log.
3. **Record** — a timestamped entry in [CHANGELOG.md](../CHANGELOG.md).
4. **Notify** — the business owner immediately; affected employees and any authority as obligations require.
5. **Fix** — root cause, not symptom.
6. **Verify** — prove the hole is closed by attempting the attack again.

---

## 12. Pre-launch security checklist

Nothing ships until every line is checked and the result recorded.

- [ ] No secret-key reference anywhere in the app or in git history
- [ ] Keystore generated and backed up in two places
- [ ] RLS enabled on every table, with the attack attempts in section 4 run and failed
- [ ] Supabase advisors clean, or every exception documented with a reason
- [ ] Every view uses `security_invoker`
- [ ] Every `security definer` function justified, outside the exposed schema, and identity-checked inside
- [ ] Duty window and auto-end verified against **server** time, with a deliberately wrong device clock
- [ ] Distance verified as server-calculated and not client-influenced
- [ ] Photo bucket verified private by attempting raw URL access while signed out
- [ ] Export formula-injection tested with a hostile note field
- [ ] No location data in crash reports, analytics, or logs
- [ ] Device binding verified by attempting a second-device login
- [ ] Rate limiting and lockout verified
- [ ] Blocking verified to end an open session and revoke the session
- [ ] Audit log verified append-only and complete
- [ ] All dependencies pinned, lockfile committed, each package reviewed
- [ ] Privacy policy published, disclosure and consent implemented
- [ ] Data Safety form matches what the app actually does
- [ ] Backup restore rehearsed successfully
