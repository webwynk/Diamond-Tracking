# Diamond Agritech Tracking App

Employee duty + GPS tracking app for Diamond Agritech. Flutter (Android first) + Supabase.
Admin manages employees and watches a live map; employees toggle duty on/off and are tracked while on duty.

---

## STOP — read this before you do anything

This project has binding rules. They are not suggestions.

**Before every task, read [docs/04-RULES.md](docs/04-RULES.md) in full.**

The short version of the rules, which does **not** replace reading them:

1. **Ask permission before every step.** Propose, wait for approval, then act.
2. **Propose an enterprise-grade solution before writing any code** for a new function.
3. **Never assume.** Cross-check against the live database, the existing code, and these docs.
4. **Double-check after implementing.** Re-read your own change and hunt for new bugs.
5. **Leave no dead or leftover code.** Check for it after every change.
6. **Search the web for any bug or error** instead of guessing a fix.
7. **Log every change in [CHANGELOG.md](CHANGELOG.md).** New function, bug found, bug fixed, code change — all of it.

---

## Document index

Read these in order when picking up the project. Treat them as the source of truth; if code and docs disagree, stop and raise it.

| # | Document | Read it when |
|---|---|---|
| 1 | [docs/01-PRD.md](docs/01-PRD.md) | Always. Scope, roles, rules, data model, acceptance criteria. |
| 2 | [docs/02-DEVELOPMENT-PLAN.md](docs/02-DEVELOPMENT-PLAN.md) | Picking the next task. Phases, order, exit criteria. |
| 3 | [docs/03-DESIGN-SYSTEM.md](docs/03-DESIGN-SYSTEM.md) | Building any screen or widget. Colours, type, spacing, loaders, skeletons, filters, pagination. |
| 4 | [docs/04-RULES.md](docs/04-RULES.md) | Always, before every task. The working protocol. |
| 5 | [docs/05-SECURITY.md](docs/05-SECURITY.md) | Touching auth, RLS, storage, location data, keys, or exports. |
| 6 | [docs/06-SUPABASE-BEST-PRACTICES.md](docs/06-SUPABASE-BEST-PRACTICES.md) | Any schema, RLS, migration, Realtime, or Edge Function work. |
| 7 | [docs/07-MAPLIBRE-BEST-PRACTICES.md](docs/07-MAPLIBRE-BEST-PRACTICES.md) | Any map, marker, route, or geofence UI work. |
| 8 | [docs/08-FLUTTER-SUPABASE-BEST-PRACTICES.md](docs/08-FLUTTER-SUPABASE-BEST-PRACTICES.md) | Any Flutter app code: state, background GPS, offline queue, errors. |
| 9 | [docs/09-SCREEN-DESIGN-PROMPTS.md](docs/09-SCREEN-DESIGN-PROMPTS.md) | AI prompts for generating each of the 30 screen designs. |
| 10 | [docs/10-CLOUDINARY-BEST-PRACTICES.md](docs/10-CLOUDINARY-BEST-PRACTICES.md) | Any work on visit photos: upload, delivery, signing, credits. |
| — | [CHANGELOG.md](CHANGELOG.md) | After every single change. Mandatory. |

**Designs** are generated from the prompts in doc 9 and saved to `designs/<number>-<name>.png`. A generated design is a reference, **not** the source of truth: where it conflicts with [docs/03-DESIGN-SYSTEM.md](docs/03-DESIGN-SYSTEM.md), raise the conflict before building rather than following the image.

---

## Locked decisions

Do not revisit these without asking. They are settled.

| Decision | Value |
|---|---|
| Company | Diamond Agritech |
| Brand colour | `#016893` |
| Font | DM Sans |
| Theme | **Light mode only.** No dark mode. The system dark setting is ignored. |
| Platform | Android first; iOS possible later from the same codebase |
| App framework | Flutter (3.44.4 stable, Dart 3.12.2 at setup) |
| **Package name** | **`com.diamondagritech.tracking`** — permanent once published to Play. Never change it. |
| **Minimum SDK** | **API 26 (Android 8.0)** — chosen for modern foreground-service APIs, which background GPS reliability depends on |
| **State management** | **Riverpod**, for the whole app. Never mix in another approach. |
| Backend | Supabase — Postgres, Auth, Realtime, Edge Functions. **Supabase Storage is not used.** |
| Supabase region | `ap-south-1` (Mumbai) |
| Supabase plan | **Free at launch.** Ceiling ~65–90 employees. No reliable backups, so a weekly attendance export is mandatory. |
| Visit photos | **Cloudinary**, free plan. Delivery type **`authenticated`** and **signed uploads** are mandatory — neither is the default, and both fail silently. |
| Point retention | **30 days** (not 60) — a consequence of the Free database limit. The route view covers 30 days. |
| Map provider | **MapLibre** (renderer) + **OpenFreeMap** (tiles). No account, no API key, no limits, **no terms restricting employee tracking.** No satellite view. |
| Live updates | Supabase Realtime. **Not** Socket.IO. |
| Route view | **Static route, not a replay.** No play/pause, no scrubber, no speed control, no animation. Shows the route line, total km, total hours, current location. |
| Notifications | In-app notification centre in the Admin app only. **No push, no FCM.** |
| Timezone | `Asia/Kolkata`, enforced using server time |
| Duty window | 08:00–23:00 IST. Toggle disabled outside it. |
| Auto-end | 23:00 IST, logged as "Duty ended automatically" |
| Employee login | Employee code (e.g. `DA-001`) + 6-digit PIN |
| Geofence radius | 500 m default |
| Visit photo | Auto-prompted on geofence entry; manual check-in also available; **skippable, and the skip is flagged** |
| Fake GPS | **Flag only.** Never auto-end duty on a mock-location flag. |
| Reports | PDF + Excel, **English only** |
| Scale | **Launching with 50. Architecture targets 150**, so growth needs no rework. Only the hosting plan is sized for 50. |
| Admin model | Several admins, all equal. Only admins create places. |
| Admin web dashboard | Phase 2. Not now. |

---

## Current state

**Phase 0, in progress. No application code has been written yet.**

Done:
- Supabase project **`bljroionzwxxsgmyituh`** ("Diamond Tracking App"), org `dedbrwbmiuramwkqffkz`, region **`ap-south-1`**, Postgres 17, **Free plan**. `public` schema empty, security advisors clean. Deliberately a separate Supabase account from any unrelated project.
- Cloudinary upload preset **`diamond`** — signing mode Signed, asset folder `diamond-images/visits`, overwrite-on-same-public-ID ON.
- Map stack decided: **MapLibre + OpenFreeMap**. No account or token needed, so `env.json` carries no map credential.
- `env.json` populated with all five client-side values; `.gitignore` created and verified against a test repo.
- `designs/` folder populated with all 30 reference images from `Design Reference/`.
- Brand logo mark added at `assets/image/logo.png` and registered in `pubspec.yaml`.

**Phase 0 Step 1 complete** (2026-10-13): Flutter scaffold, git initialised, build-time config wiring with loud startup failure, folder structure, strict lints, DM Sans bundled. Analyzer clean, 2 tests pass, debug APK builds, no secrets committed.

**Phase 0 Step 2 complete** (2026-10-13, visually verified on emulator 2026-10-15): design-system tokens in `lib/core/theme/` — colours, typography, dimensions, and one forced light `ThemeData`. 22 tests pass, including WCAG contrast computed from the real token values. Visual verification confirmed on Android emulator by the owner.

**Phase 0 Step 3 complete** (2026-10-15): global shared widget library in `lib/shared/widgets/` — `AppButton`, `AppIconButton`, `AppTextField`, `AppCard`, `AppStatCard`, `AppStatusPill`, `AppBadge`, `AppEmptyState`, `AppBanner`, `AppErrorView`, `AppShimmer`, `AppListSkeleton`, `AppStatRowSkeleton`, `AppPaginationLoader`, `AppMapPlaceholder`, and `AppSnackbar`. 38 tests pass, debug APK builds, 0 analyze issues. Showcased in `theme_preview_page.dart`.

**Phase 0 Exit Criteria fully met.**
Next: Phase 1 — Auth, roles, and the background tracking spike. **Step 1: Profiles schema & role model with Supabase Auth. Needs explicit approval before starting.**

---

## Open items needing a decision from the owner

Tracked here so they are not forgotten. See the "Open questions" section of [docs/01-PRD.md](docs/01-PRD.md) for detail.

- Google Play account type: Personal (needs a 12-tester, 14-day closed test) vs Organization (needs a D-U-N-S number).
- Whether to publish publicly or as a private/internal app.
- ⚠ **MapLibre clustering is unverified at 150 markers** (PRD Q6b). Must be proven by the mandatory spike early in Phase 2, **before any map screen is built.** The admin live map depends on it.
- **Database password rotation: deferred by the owner during development. This is a hard gate before any real employee data exists.** A connection string was exposed in chat on 2026-10-12.
- Confirmation of Cloudinary's credit behaviour, and that `authenticated` delivery is available on its Free plan.
- ~~Whether 30-day route history is acceptable~~ — **resolved: 30 days confirmed by the owner.**
- Who owns the monthly check of the upgrade triggers, and where the weekly attendance export is kept (PRD Q5b).

**Running on free tiers is a deliberate choice with a known expiry.** The triggers in section 7 of [docs/01-PRD.md](docs/01-PRD.md) are checked monthly. Hitting one is a decision point, not an emergency — but only if someone is actually looking.
