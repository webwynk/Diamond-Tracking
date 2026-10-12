# 06 — Supabase Best Practices

Rules for schema, RLS, migrations, Realtime, Edge Functions, and Storage on this project.

**Supabase changes often. Never work from memory.** Before implementing a Supabase feature, check the changelog for breaking changes and look up the current docs. A function signature or config option you remember may no longer exist.

---

## 1. Before you write any SQL

1. **Read the live schema.** List the actual tables and columns. Do not trust an older doc or your memory.
2. **Confirm nullability, types, and defaults** for every column you touch.
3. **Confirm which RLS policies apply** to the role doing the work.
4. **Confirm the table is exposed to the Data API** if the app needs to reach it. Exposure and RLS are two different things; a table can have perfect policies and still be unreachable, or be reachable when you thought it was private.
5. **Search for existing objects** before creating anything. A second `get_employee_stats` function is worse than no function.

---

## 2. Schema conventions

- `snake_case` for tables and columns. Plural table names.
- Primary keys are `uuid` with a default, except the very-high-volume `location_points`, which uses `bigint identity` because 8 bytes beats 16 bytes fifteen million times over.
- **Every timestamp is `timestamptz`. Never `timestamp`.** A tracking app spanning a curfew boundary cannot afford an ambiguous time.
- Every table has `created_at timestamptz not null default now()`.
- Mutable tables also have `updated_at`, maintained by a trigger rather than by the client.
- Money and distance use `numeric`, never `float`. `total_km numeric(10,3)`.
- Use enum-like `text` with a `check` constraint rather than a Postgres `enum`, because adding a value to an enum is painful and this project will add statuses.
- Foreign keys always declare explicit `on delete` behaviour. Decide it deliberately: history tables use `restrict` so an employee cannot be deleted out from under their records.
- Constrain at the database level. `check (radius_m between 50 and 5000)` is worth more than a validation in Dart.

### The constraint that matters most

One open duty session per employee is a core business rule, so it is enforced by the database, not by application logic:

> A unique partial index on `duty_sessions (employee_id) where ended_at is null`.

Application-level checks lose this race under rapid toggling. The index cannot.

---

## 3. Row-level security

The full access matrix and the non-negotiable rules live in [05-SECURITY.md](05-SECURITY.md). The database-side essentials:

- **Enable RLS in the same migration that creates the table.**
- Always name the role: `to authenticated`, never `auth.role() = 'authenticated'`.
- Always add an ownership or role predicate. `to authenticated` on its own grants everyone everything.
- `update` policies need both `using` and `with check`, and a `select` policy to go with them.
- Wrap `auth.uid()` as `(select auth.uid())` in policies. It lets Postgres evaluate it once per query instead of once per row, which matters a great deal on `location_points`.
- **Index every column used in an RLS predicate.** An unindexed `employee_id` turns every policy check into a sequential scan over millions of rows.
- Keep the role lookup cheap. Checking "is this user an admin" on every row of a large query is a performance trap; prefer a claim or a cached lookup over a correlated subquery per row.
- Views are created `with (security_invoker = true)`.

---

## 4. Indexing for this workload

The access patterns are known, so index for them deliberately rather than reactively.

| Table | Index | Why |
|---|---|---|
| `location_points` | `(session_id, captured_at)` | Route view reads one session in time order |
| `location_points` | `(employee_id, captured_at desc)` | Per-employee history and keyset pagination |
| `duty_sessions` | `(employee_id) where ended_at is null` — **unique** | Enforces one open session |
| `duty_sessions` | `(employee_id, started_at desc)` | History list, keyset pagination |
| `live_locations` | Primary key on `employee_id` | One row per employee; the admin map's source |
| `geofence_events` | `(place_id, occurred_at desc)` and `(employee_id, occurred_at desc)` | Both query directions are used |
| `visits` | `(employee_id, created_at desc)` | Visit list |
| `notifications` | `(created_at desc)` | Notification centre |
| `notification_reads` | `(admin_id, notification_id)` — **unique** | Per-admin read state and unread counts |
| `daily_summaries` | `(employee_id, date)` — **unique** | Reports, and idempotent aggregation |
| `audit_log` | `(created_at desc)` and `(actor_id, created_at desc)` | Review |

### Rules
- **Verify with a query plan that an index is actually used.** An unused index is pure write cost.
- Do not over-index `location_points`. It is insert-heavy, and every index slows every insert.
- Consider a geospatial index only once geofence evaluation is measurably slow. With 150 employees and a handful of places, plain arithmetic is likely faster than the machinery around it. **Measure before adding PostGIS.**
- Revisit indexes after the Phase 5 load test with real data volume.

---

## 5. Migrations

- Decide the project's workflow once — declarative schema files or imperative migrations — and record it. Then never mix the two.
- **Iterate with direct SQL execution, then generate the migration when the shape is settled.** Writing a migration entry on every experimental attempt leaves a history you cannot clean up.
- Never invent a migration filename. Use the CLI to create it.
- Every migration is reviewed before it is applied to production, and has a stated rollback plan.
- Migrations are **forward-only in production.** Never edit an applied migration; add a new one.
- Additive changes first. To rename a column: add the new one, backfill, migrate the code, then drop the old one in a later release. A rename in one shot breaks every app version already installed on a phone.
- **Remember that old app versions stay installed on employees' phones for weeks.** Every schema change must be compatible with the previous app version, or the release is coordinated deliberately.
- Run the advisors after every schema change and fix what they report.
- Discover CLI commands with `--help`. Do not guess flags; they change between versions.

---

## 6. Querying from the app

- **Select only the columns you need.** Never `select *` on `location_points`.
- Never fetch a whole table and filter on the device. Filter, sort, and paginate in the query.
- **Keyset pagination, not offset.** Offset gets slower as it goes deeper, and on live data it skips and duplicates rows as new records arrive mid-scroll. Keyset asks for "rows before this `(created_at, id)`", which is stable and uses the index.
- Always order by a **tie-broken** key, such as `(created_at desc, id desc)`. Ordering by a timestamp alone is non-deterministic when two rows share a millisecond, and pagination then drops or repeats rows.
- Wrap multi-step writes in a database function so they are atomic. Blocking an employee must close their session in the **same transaction**; two separate calls can leave a blocked employee still tracking.
- Set explicit timeouts and handle them. A hung request must reach an error state.
- Batch the point uploads. One request per GPS point would be a battery and quota disaster.
- **Make writes idempotent.** The offline queue will retry, and a timeout does not mean the write failed. Give each point a client-generated identifier and let the server ignore duplicates.

---

## 7. Realtime

- **Only admins subscribe.** Employees use plain inserts. This keeps concurrent connections in single digits instead of 150.
- **Subscribe to `live_locations`, never to `location_points`.** One is 150 rows; the other is fifteen million. Subscribing to the wrong one would push millions of messages a month to every admin.
- Realtime respects RLS, so verify an employee cannot subscribe to another employee's data.
- Handle the full lifecycle: subscribed, disconnected, reconnecting, error. A dropped stream must show the connection indicator from [03-DESIGN-SYSTEM.md](03-DESIGN-SYSTEM.md).
- **On reconnect, refetch.** Messages sent while disconnected are gone; the UI must backfill rather than silently showing stale positions.
- Always unsubscribe on dispose. A leaked channel per screen visit will exhaust the connection limit.
- Debounce UI updates. 150 markers updating independently must not cause 150 rebuilds per second.
- Check the current connection and message-rate limits for the plan in use, rather than assuming headroom.

---

## 8. Edge Functions

Used for anything privileged or trust-sensitive: employee creation, PIN reset, duty start and stop, point ingestion with validation, geofence evaluation, report generation.

- **Validate every input.** These are public endpoints; assume a hostile caller.
- Verify the caller's identity and role **inside the function**. Never infer privilege from the fact that the function was called.
- Secrets come from function secrets, never from the request.
- Return structured, specific errors. `{"error": "duty_outside_window", "next_allowed_at": "..."}` lets the client show the right message; a bare 500 does not.
- Keep functions small and single-purpose.
- Log enough to debug, but **never log location data or personal data.**
- Make them idempotent, since clients retry.
- Watch cold-start latency on anything the user waits for, such as the duty toggle. Measure it against the 2-second target.

---

## 9. Scheduled jobs

| Job | Schedule | Notes |
|---|---|---|
| Auto-end duty at curfew | Every minute between 22:55 and 23:05 IST | **Must be idempotent.** Running twice must not corrupt a session. |
| Nightly summary aggregation | After midnight IST | Recomputes the previous day; safe to re-run, keyed on `(employee_id, date)` |
| Delete points older than 30 days | Daily | **Only after confirming the summary exists.** Deleting unsummarised data is unrecoverable. |
| Delete notifications older than 6 months | Weekly | — |
| Photo retention cleanup | Monthly | Per PRD Q4 |
| Stale-location alerts | Every 5 minutes | Raises the orange-status notifications |

### Rules
- Every job is **idempotent and re-runnable.** Jobs fail and get retried.
- Every job is **timezone-explicit.** A job that thinks in UTC will end duty at the wrong hour. The curfew is 23:00 `Asia/Kolkata`.
- Every job logs its outcome, and a failure raises a visible alert rather than failing quietly.
- Deletion jobs operate in **bounded batches.** A single statement deleting millions of rows will lock the table and time out.
- **Verify the retention job cannot delete unsummarised data.** Test it with a deliberately missing summary. This is the one job that can destroy the product's value.

---

## 10. Storage

**Supabase Storage is not used in this project.** Visit photos go to Cloudinary, because Supabase Free allows only 1 GB of file storage and this app generates roughly 1.1 GB of photos per month. See [10-CLOUDINARY-BEST-PRACTICES.md](10-CLOUDINARY-BEST-PRACTICES.md).

What Supabase still owns:

- The `visits` row, which stores the Cloudinary `public_id` — never the full URL, which is signed and short-lived.
- The **Edge Function that issues upload signatures**, holding the Cloudinary API key and secret as function secrets.
- The **Edge Function that issues signed read URLs**, which is where the "an employee sees only their own photos" rule is enforced. Cloudinary has no row-level security, so that check exists only here. Get it wrong and any employee can request any photo.
- The **deletion and reconciliation jobs** that keep Postgres rows and Cloudinary assets in step.

If the project ever moves to Supabase Pro, revisit this: Pro includes 100 GB of storage and image transformations, which would make Cloudinary redundant.

---

## 11. Operational

### Running on the Free plan

**Decision: launch on Supabase Free**, at 50 employees with 30-day point retention. This is viable but has no slack, so it has to be managed rather than assumed.

- **500 MB database limit.** Estimated use is 220–360 MB. The budget for `location_points` is **400 MB**, leaving headroom for every other table plus index bloat and WAL.
- **The ceiling is roughly 65–90 employees** at 30-day retention, depending on the measured movement ratio. Past that, either retention shortens or the plan changes.
- **Inactivity pausing is not a practical risk** — 50 employees use the app daily, and pausing needs about a week of inactivity.
- **There are no reliable backups on Free. This is the real risk**, because this database holds the attendance record wages are paid from. A **scheduled weekly export of `duty_sessions`, `daily_summaries`, `visits`, and `audit_log`** to a file the company keeps is therefore mandatory before go-live. Those tables are small and permanent; raw GPS points are expendable.
- **Rehearse the restore from that export before launch.** An untested export is a hope, not a plan.
- **Confirm in Phase 0 whether Free → Pro is an in-place plan change** rather than a migration. It is widely assumed to be, but it has not been verified, and the whole fallback plan rests on it.

### Monitoring, monthly

Check against the trigger table in section 7 of [01-PRD.md](01-PRD.md). The important ones here: database size at 400 MB, employee count at 65, egress at 4 GB.

- **Measure the real points-per-day figure in Phase 2** from actual tracked shifts, then set the retention window from the measurement. The 900–1,500 estimate in the PRD is a planning figure, not a fact, and everything about plan viability depends on it.
- If growth outruns the estimate, revisit the stationary ping interval and the retention window **before** paying for more storage.
- Check the advisors regularly, not only after schema changes.
- When something behaves unexpectedly — an empty result, a surprise RLS block, a timeout — **read the logs before theorising.** The answer is not always there, but it is often there.
- Keep `app_settings` server-side so the duty window, intervals, and thresholds can change **without an app release.** Employees will not all update their app promptly.

---

## 12. Common traps on this project

| Trap | Consequence | Avoidance |
|---|---|---|
| Subscribing to `location_points` | Millions of Realtime messages | Subscribe to `live_locations` only |
| `select *` on `location_points` | Huge payloads, slow route view | Name the columns |
| Offset pagination on a live list | Rows skipped and duplicated while scrolling | Keyset pagination |
| Ordering by timestamp alone | Pagination drops or repeats rows | Always tie-break on the id |
| Business rules in the client | The core fraud defence is bypassable | Server-side only |
| `to authenticated` with no predicate | Every employee reads everyone's location | Always add an ownership check |
| Missing `select` policy on an updatable table | Silent zero-row update, no error | Pair the policies |
| `security definer` used to fix a permission error | Access control silently removed | Fix the real cause |
| Unindexed RLS predicate column | Sequential scans over millions of rows | Index it |
| Timezone-naive scheduled job | Duty ends at the wrong hour | `Asia/Kolkata`, explicitly |
| Non-idempotent retried write | Duplicate points inflate distance | Client-generated ids |
| Retention job running before aggregation | **Permanent data loss** | Confirm the summary first; test the failure case |
