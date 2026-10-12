# 08 — Flutter + Supabase Best Practices

How the Flutter app is built and how it talks to Supabase. Read before writing any app code.

**Verify package APIs against current docs.** Flutter packages and `supabase_flutter` change between versions. Pin versions and commit the lockfile.

---

## 1. Architecture

Three layers, with dependencies pointing one way only: **UI → domain → data**. UI never reaches the Supabase client directly.

```
lib/
  core/        theme, tokens, constants, errors, extensions, utils
  data/        Supabase clients, repositories, local database, models (DTOs)
  domain/      entities, business rules the client needs, repository interfaces
  features/    one folder per feature: duty, tracking, live_map, employees,
               notifications, history, route_view, places, visits, reports, auth
  shared/      the reusable widget library from 03-DESIGN-SYSTEM.md
```

### Rules
- **Every Supabase call goes through a repository.** No `supabase.from(...)` inside a widget, ever. This is what makes it testable and what keeps queries findable when the schema changes.
- A repository returns domain entities, not raw maps. Map DTOs at the boundary.
- A repository never throws a raw Supabase exception upward. It maps to a typed app error.
- Feature folders do not import each other's internals. Share through `shared/` or `domain/`.
- One state-management approach for the whole app. Choose it in Phase 0 and never mix.

---

## 2. State management

- Keep state **as local as it can be.** Global state is for the session, the current user, and the duty state — not for a screen's scroll position.
- The duty state is the most important state in the app. It has exactly one owner, and it is **derived from the server**, not from what the user last tapped.
- Never put mutable business logic inside `build`. `build` can run many times per second.
- Scope rebuilds narrowly. A Realtime update must not rebuild a whole screen.
- **Dispose everything**: controllers, stream subscriptions, Realtime channels, timers, map controllers. A leaked Realtime channel per screen visit will exhaust the connection limit.
- Avoid passing `BuildContext` into async gaps. Check `mounted` before using it after an `await`.

---

## 3. Models and serialisation

- **Never hand-write `fromJson`.** Use code generation. A typo in a hand-written mapper produces a silent null, which in this app means a silently missing GPS point.
- Model nullability to match the database exactly. If the column is nullable, the field is nullable. Do not paper over it with a default.
- **Parse every timestamp as UTC, then convert for display.** Mixing local and UTC in a tracking app corrupts hours and curfew logic.
- Keep DTOs separate from domain entities. The database shape and the app's shape are allowed to differ.
- Use immutable models with value equality, so list diffing and rebuild-skipping work.

---

## 4. Time handling

Time is the most dangerous area of this app. A mistake here breaks the duty window, the curfew, hours, and payroll trust.

- **Business decisions use server time.** Never the device clock. The window check and the curfew are server-enforced; the client only displays them.
- **Store and transmit UTC. Display in `Asia/Kolkata`.**
- Fetch and cache a server-time offset at login and periodically, so the UI can show an accurate countdown even on a phone with a wrong clock.
- A GPS point records both the device timestamp **and** a server-received timestamp. The device value is data; the server value is truth.
- Reject a point whose device timestamp is in the future.
- Never compute elapsed duty time from `DateTime.now()` alone. Derive it from the server session start plus the offset.
- Be explicit about day boundaries. "Today" means the current date in `Asia/Kolkata`, not in UTC, or the attendance of a late-evening shift lands on the wrong day.

---

## 5. Background location

The hardest and highest-risk part of the app. Validated in Phase 1 for exactly that reason.

### Non-negotiable
- An Android **foreground service** with a persistent notification, for the entire duty session. There is no invisible tracking.
- **Tracking is independent of any screen.** Closing the map, backgrounding the app, or locking the phone must not stop it. Verify this every release.
- Adaptive interval: about 30 seconds moving, about 3 minutes stationary.
- The service writes to a **local database first**, then uploads. Never upload-or-lose.
- The service must **survive being restarted by the OS** and resume the open session rather than starting a new one.
- A heartbeat reports permission and location-service state, so a broken tracker is distinguishable from a stationary employee.

### Permissions
Request in stages, with an explanation before each system prompt, never a cold prompt:
1. Explain, then request foreground location.
2. Explain why background is needed, then request background location.
3. Explain, then request notification permission for the foreground service.
4. Explain and deep-link to disable battery optimisation.

Handle "denied", "denied forever", and "revoked while running" as distinct cases. A revoked permission mid-session must raise an admin notification, not fail silently.

### Battery killers
Xiaomi, Oppo, Vivo, Realme, and Samsung kill background apps aggressively. This is the top risk in the PRD.
- Build **manufacturer-specific onboarding** with direct links to the right settings screen.
- Add an in-app diagnostic that verifies tracking is actually permitted and running, so an employee can self-check.
- Detect gaps and surface them, rather than pretending the day was continuous.
- **Test on a real budget device from one of these manufacturers.** An emulator and a Pixel will both pass while a Redmi fails.

---

## 6. Offline-first

Field staff will lose signal. The app must behave as though that is normal, because it is.

- A **local database is the source of truth for the device**: queued GPS points, queued visits, queued photos, and cached reference data.
- The queue **survives app restart, force-kill, and reboot.** An in-memory queue is not acceptable.
- Upload in batches with exponential backoff. Never a tight retry loop; it drains the battery.
- **Every queued write carries a client-generated id and is idempotent server-side.** A timeout does not mean the write failed, so retries must not duplicate points and inflate distance.
- Only clear a local item once the server **confirms** it.
- **Never block the employee on connectivity.** Duty on, duty off, and visit capture all work offline and sync later.
- Show queue state honestly: "12 points waiting to sync" builds trust; a silent queue does not.
- Cap the local queue and define what happens if it fills after days offline. Decide this deliberately rather than discovering it.
- Offline is an **info banner, not an error.** See [03-DESIGN-SYSTEM.md](03-DESIGN-SYSTEM.md).

---

## 7. Error handling

- One typed error hierarchy: network, auth, permission, validation, server, unknown.
- Repositories catch Supabase exceptions and map them to typed errors. No `PostgrestException` reaches the UI.
- **Every error message tells the user what to do.** Use the table in the design system. Never surface a raw exception or a bare code.
- Never swallow an error silently. If it is genuinely ignorable, say why in a comment.
- Log errors with enough context to debug, and **no location data or personal data.**
- Every async call has a timeout and a path to an error state. A spinner that can spin forever is a bug.
- Crash reporting is enabled in release, scrubbed of PII.

---

## 8. Lists, pagination, and performance

- **Every list is lazily built and paginated from the first version.** See the pagination section of the design system. An unpaginated list is a defect.
- Keyset pagination, ordered on a tie-broken key. Never offset.
- Debounce search at 300 ms, and **cancel the in-flight request** when a new keystroke arrives, or results will arrive out of order.
- Filter and sort on the server, inside the query. Never fetch everything and filter in Dart.
- `const` constructors wherever possible. Give list items stable keys.
- Cache and size images; never decode a photo larger than it is displayed.
- Keep heavy work — report assembly, large parsing, line simplification — **off the UI thread.**
- Profile in **release mode on a budget phone.** Debug-mode performance is meaningless.

---

## 9. Supabase client specifics

- One client instance for the app. Initialise once at startup.
- Rely on the SDK's token refresh, but handle the refresh-failure case: sign out cleanly and route to login rather than leaving the app in a half-authenticated state.
- Listen to auth state changes centrally and route from there. Do not scatter session checks.
- Store the session in **secure storage**, not in plain preferences.
- On sign-out, clear the local database of everything personal, close Realtime channels, and stop the tracking service.
- Handle the "blocked while using the app" case: the next request fails, and the app must sign out with a clear message rather than retrying forever.
- Realtime subscriptions live in a repository, are exposed as streams, and are always cancelled on dispose. **Admins only** — see [06-SUPABASE-BEST-PRACTICES.md](06-SUPABASE-BEST-PRACTICES.md).

---

## 10. Testing

Proportionate, aimed at where the risk actually is.

| Layer | What to test |
|---|---|
| **Unit** | Distance calculation, outlier and mock rules, duty-window logic, time and timezone conversion, queue behaviour, geofence maths |
| **Repository** | Error mapping, pagination boundaries, idempotency of retried writes |
| **Widget** | The duty toggle in every state; loading, empty, and error states |
| **Integration** | Full duty session, offline then reconnect, RLS boundaries |
| **Manual, on real devices** | Background survival, battery drain, map performance, permission flows |

The highest-value tests here are **time logic, distance calculation, and the offline queue**, because a bug in any of them corrupts the data the business will rely on and may go unnoticed for weeks.

**No test replaces an 8-hour run on a real budget phone.**

---

## 11. Code quality

- Strict analysis options. Treat warnings as errors. A clean analyzer is a release gate.
- Formatter enforced. No debate about style.
- No `print` in committed code.
- No commented-out code. Git remembers it.
- Comment the **why**, never the what. Explain a non-obvious decision, such as why a point is rejected at 100 m accuracy.
- Match the surrounding code's naming and idiom. Consistency beats personal preference.
- **Run the dead-code sweep from [04-RULES.md](04-RULES.md) after every change**, not just in Phase 6.

---

## 12. Traps

| Trap | Consequence | Avoidance |
|---|---|---|
| Supabase calls inside widgets | Untestable, unfindable queries | Repository layer, always |
| `DateTime.now()` for business logic | Duty window bypassed by changing the phone clock | Server time only |
| Mixing local time and UTC | Wrong hours, wrong attendance day | Store UTC, display IST |
| Hand-written `fromJson` | A silent null becomes a lost GPS point | Code generation |
| In-memory upload queue | A day's work lost on force-kill | Local database, persisted |
| Non-idempotent retries | Duplicate points inflate distance | Client-generated ids |
| Tracking tied to a screen | Tracking stops when the map closes | Service independent of UI |
| Undisposed Realtime channel | Connection limit exhausted | Dispose everything |
| `context` used after `await` | Crash | Check `mounted` |
| Unpaginated list | Freezes as data grows | Paginate from day one |
| Search without cancellation | Stale results overwrite fresh ones | Debounce and cancel |
| Profiling in debug on a flagship | Every real performance problem hidden | Release mode, budget phone |
| Testing background tracking only on an emulator | Fails on the devices employees actually own | Real Xiaomi or Oppo device |
