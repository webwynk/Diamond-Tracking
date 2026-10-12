# Diamond Agritech Tracking

Employee duty and GPS tracking for Diamond Agritech field staff. Flutter (Android) + Supabase.

Employees toggle duty on and off; admins manage the team and watch a live map. Location is recorded **only while on duty**.

---

## Read this first

**This project has binding working rules. Read [CLAUDE.md](CLAUDE.md) before making any change**, then the document it points you to for the area you are touching.

| | |
|---|---|
| Project index and locked decisions | [CLAUDE.md](CLAUDE.md) |
| What we are building | [docs/01-PRD.md](docs/01-PRD.md) |
| What to build next | [docs/02-DEVELOPMENT-PLAN.md](docs/02-DEVELOPMENT-PLAN.md) |
| How we work | [docs/04-RULES.md](docs/04-RULES.md) |
| Change history | [CHANGELOG.md](CHANGELOG.md) |

---

## Running it

The app **will not start without build-time configuration.** That is deliberate: a silently misconfigured build would appear to work and then fail to record a duty session.

```bash
flutter pub get
flutter run --dart-define-from-file=env.json
```

`env.json` is gitignored and never committed. To create your own:

```bash
cp env.example.json env.json
```

Then fill in the four values. `env.example.json` documents the shape.

### What belongs in `env.json`

| Key | Secret? |
|---|---|
| `SUPABASE_URL` | No |
| `SUPABASE_PUBLISHABLE_KEY` | No — row-level security protects the data, not this key |
| `CLOUDINARY_CLOUD_NAME` | No |
| `CLOUDINARY_UPLOAD_PRESET` | No — uploads are signed server-side |

### What must never go in it

- The Supabase **database password**
- The Cloudinary **API key or secret** — those are Edge Function secrets
- Any map credential — **there is none.** MapLibre + OpenFreeMap need no account.

See [docs/05-SECURITY.md](docs/05-SECURITY.md).

---

## Checks

```bash
flutter analyze    # must be clean - it is a release gate
flutter test
```

---

## Stack

| | |
|---|---|
| App | Flutter, Android first, **light theme only** |
| State | Riverpod, throughout. Never mixed with another approach. |
| Backend | Supabase — Postgres, Auth, Realtime, Edge Functions |
| Maps | MapLibre + OpenFreeMap — no account, no key, no usage limits |
| Visit photos | Cloudinary — `authenticated` delivery, signed uploads |
| Notifications | In-app only. No push, no FCM. |
| Package | `com.diamondagritech.tracking` — **permanent once published** |
| Min SDK | API 26 (Android 8.0) |

---

## A note on Windows builds

`kotlin.incremental=false` is set in [android/gradle.properties](android/gradle.properties). This is required, not optional, when the project and the Dart pub cache sit on different drives — Kotlin's incremental compiler fails every build otherwise. The reasoning is documented in that file.
