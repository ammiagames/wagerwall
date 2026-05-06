# Supabase Backend

Postgres schema, edge functions, and local-dev config for WagerWall. The iOS app talks to Supabase via:
- **Auth** — Google OAuth (Apple TBD)
- **PostgREST** — table reads/writes through `Repositories/` in the app
- **Edge Functions** — server-side glue (heartbeat checks, partner notifications, streak rollups, push delivery)

> **For LLMs ramping up**: read this file, then [`migrations/README.md`](migrations/README.md) for schema and [`functions/README.md`](functions/README.md) for server logic.

---

## Layout

```
supabase/
├── config.toml             Local-dev ports + feature flags
├── .gitignore              .branches, .temp, .env.* excluded
├── migrations/             Numbered SQL — single source of truth for schema
│   ├── 001_initial_schema.sql      14 tables, RLS, signup trigger
│   ├── 002_cbt_content.sql         no-op (content moved to app binary)
│   ├── 003_cron_jobs.sql           pg_cron schedules — all commented (Pro plan)
│   └── 004_decouple_content.sql    drops cbt_modules / cbt_lessons; lesson_id → TEXT
└── functions/              Deno + TypeScript edge functions
    ├── send-push/                  STUB — no APNs JWT, no HTTP/2 call
    ├── notify-partner/             push works, email is logging-only
    ├── check-heartbeats/           production-ready (cron, every 15 min)
    ├── process-disable-request/    production-ready (cron, every 5 min + manual)
    └── daily-streak-update/        production-ready (cron, midnight UTC)
```

---

## Status snapshot (verified 2026-05-04)

| Area | State | Notes |
|---|---|---|
| Schema | ✅ Stable | 12 tables active (after `004` drops 2 deprecated CBT tables) |
| RLS | ✅ Enabled on every table | All policies scope by `auth.uid()` |
| Auth | ✅ Google OAuth via Supabase | Apple Sign-In missing |
| Edge functions | 🟡 4/5 production-ready | `send-push` is a stub; blocks `notify-partner` end-to-end |
| Cron | ❌ Disabled | All `pg_cron` jobs commented out — Supabase Pro tier required |
| Email delivery | ❌ Logging-only | `notify-partner` has no SendGrid/Resend integration |
| Seed data | ❌ Absent | `config.toml` references `seed.sql`, file doesn't exist; CBT content lives in app binary now |

---

## Local development

Prerequisites: Docker Desktop, Supabase CLI.

```bash
brew install supabase/tap/supabase

# Inside the repo root:
supabase start          # boots Postgres, PostgREST, Studio, Inbucket, Edge Runtime
supabase db reset       # drops + re-runs every migration in order
supabase functions serve # runs edge functions on http://localhost:54321/functions/v1/*
```

### Local ports (from `config.toml`)

| Service | Port |
|---|---|
| API (PostgREST) | 54321 |
| Postgres | 54322 |
| Studio | 54323 |
| Inbucket (email testing) | 54324 |
| Analytics | 54327 |
| Edge Runtime / Inspector | 8083 |

### Project link

To connect the local CLI to a real Supabase project for migrations / function deploys:

```bash
supabase link --project-ref <project-id>
supabase db push                    # apply local migrations to remote
supabase functions deploy <name>    # deploy a specific edge function
supabase secrets set FOO=bar        # set runtime secrets for edge functions
```

---

## How the iOS app uses each piece

| Backend piece | iOS counterpart |
|---|---|
| `auth.users` | `Services/AuthService.swift` (Supabase session) |
| `user_profiles` | `Repositories/UserProfileRepository.swift` |
| `user_streaks` | `Repositories/StreakRepository.swift` |
| `user_lesson_progress` | `Repositories/CBTRepository.swift` (progress half) |
| `urge_logs` / `mood_logs` | `Repositories/UrgeLogRepository.swift`, `MoodLogRepository.swift` |
| `device_heartbeats` | `Repositories/HeartbeatRepository.swift` (foreground timer + `BGAppRefreshTask`) |
| `accountability_partners` | `Repositories/AccountabilityPartnerRepository.swift` |
| `disable_requests` | `Repositories/DisableRequestRepository.swift` |
| `blocked_attempts` | `Repositories/BlockedAttemptRepository.swift` (Phase 12 not started; table empty) |
| `push_tokens` | `Repositories/PushTokenRepository.swift` (registered on APNs callback) |

CBT content (modules, lessons, questions) is no longer in the database — it ships in the app binary under `Wagerwall/Wagerwall/Content/*.swift`. See migration `004_decouple_content.sql` for the cutover.

---

## Edge function call graph

```
            ┌─ send-push ──▶ APNs (currently stubbed)
            │
notify-partner ─▶ user_profiles (read partner info)
   ▲
   │
check-heartbeats (cron 15 min) ─▶ device_heartbeats
                                  accountability_partners

process-disable-request (cron 5 min + manual)
   ├─▶ send-push (notify user)
   └─▶ disable_requests (update status)

daily-streak-update (cron midnight)
   ├─▶ user_streaks (update money_saved, reset on inactivity)
   ├─▶ send-push (milestone)
   └─▶ notify-partner (milestone → partner)
```

`send-push` is the bottleneck: until it actually signs APNs JWTs and posts to `api.push.apple.com`, every notification path above degrades to a `console.log`.

---

## Known gaps & TODOs

1. **`send-push/index.ts`** — implement APNs JWT signing with the `.p8` private key and the HTTP/2 POST. Variables `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY` (the `.p8` contents), `APNS_BUNDLE_ID` need to be set as Supabase function secrets.
2. **`notify-partner/index.ts`** — replace the `console.log` email path with SendGrid or Resend.
3. **`003_cron_jobs.sql`** — uncomment after upgrading to Supabase Pro.
4. **`daily-streak-update/index.ts:45-47`** — both branches return the same value; the cron does not actually auto-increment streaks. Either accept "streak only ticks on user check-in" or compute the delta server-side.
5. **No seed data** — `config.toml:65` references `seed.sql` which doesn't exist. If we want demo accounts for local dev, add one.
6. **No buckets** — `storage.buckets` are commented out in `config.toml`. Add `cbt-content` and `user-avatars` buckets when needed.

---

## Conventions

- **Migrations are append-only.** Never edit a previously-released migration. Add a new numbered file.
- **Every table gets RLS** — without exception. Default policy: `auth.uid() = user_id`.
- **Client → PostgREST for CRUD; client → edge function for cross-table or external-service work.** If the iOS app needs to write to multiple tables atomically, do it in a function, not in three repository calls.
- **Service-role key is server-only.** Edge functions use it via `SUPABASE_SERVICE_ROLE_KEY`. Never embed it in the iOS bundle.
- **Soft deletes** for tables that need an audit trail (`accountability_partners`, `disable_requests`).
