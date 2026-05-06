# WagerWall

iOS app to help users quit gambling. CBT-based learning, app/website blocking, accountability partners, deletion resistance.

> **For LLMs ramping up**: start with [`CLAUDE.md`](CLAUDE.md) for the implementation checklist, then read the per-folder docs listed below.

---

## What this repo contains

```
wagerwall/
├── Wagerwall/                    iOS app (Xcode project, Swift 6, SwiftUI, iOS 17+)
│   ├── Wagerwall.xcodeproj/      Project, schemes, SPM dependencies
│   ├── Secrets.xcconfig.example  Template for credentials
│   ├── Info.plist                Background modes, BGTask IDs, $(VAR) substitutions
│   ├── Wagerwall/                App source (see Wagerwall/Wagerwall/README.md)
│   ├── WagerwallTests/           Unit tests (default Xcode stubs)
│   └── WagerwallUITests/         UI tests (default Xcode stubs)
├── supabase/                     Backend: Postgres schema, edge functions, local config
│   ├── migrations/               Numbered SQL migrations
│   ├── functions/                Deno edge functions (TypeScript)
│   └── config.toml               Local-dev ports & feature flags
├── CLAUDE.md                     Implementation checklist + LLM guidance
├── PROJECT.md                    Full product spec
├── TECH_SPEC.md                  Architecture & feasibility
├── BLOCKING_ARCHITECTURE.md      Phase 12 (Screen Time + DNS proxy + bloom filter)
└── CONTENT_ARCHITECTURE.md       How CBT lessons & questions are stored
```

## Documentation map

**Root-level specs**
- [`CLAUDE.md`](CLAUDE.md) — implementation checklist, conventions, build commands
- [`PROJECT.md`](PROJECT.md) — product overview, features, DB schema, phases
- [`TECH_SPEC.md`](TECH_SPEC.md) — architecture, feasibility, Apple frameworks
- [`BLOCKING_ARCHITECTURE.md`](BLOCKING_ARCHITECTURE.md) — Phase 12 design (not implemented)
- [`CONTENT_ARCHITECTURE.md`](CONTENT_ARCHITECTURE.md) — bundled CBT content design

**Per-folder ramp-up docs** (created by audit, kept fresh as code changes)
- [`Wagerwall/Wagerwall/README.md`](Wagerwall/Wagerwall/README.md) — iOS app overview
  - [`Core/Core.md`](Wagerwall/Wagerwall/Core/Core.md) — app state, DI, theme, config
  - [`Models/Models.md`](Wagerwall/Wagerwall/Models/Models.md) — Codable types mapped to DB
  - [`Services/Services.md`](Wagerwall/Wagerwall/Services/Services.md) — auth, supabase, notifications, heartbeat
  - [`Repositories/Repositories.md`](Wagerwall/Wagerwall/Repositories/Repositories.md) — data access (10 repos)
  - [`ViewModels/ViewModels.md`](Wagerwall/Wagerwall/ViewModels/ViewModels.md) — Observable VMs
  - [`Views/Views.md`](Wagerwall/Wagerwall/Views/Views.md) — SwiftUI screens by feature
  - [`Content/Content.md`](Wagerwall/Wagerwall/Content/Content.md) — bundled CBT modules/lessons/questions
- [`supabase/README.md`](supabase/README.md) — backend overview
  - [`migrations/README.md`](supabase/migrations/README.md) — schema history
  - [`functions/README.md`](supabase/functions/README.md) — edge function status

---

## Quick setup

1. **Clone & install Xcode 26** (Swift 6, iOS 17+ deployment target).
2. **Set up secrets**:
   ```bash
   cp Wagerwall/Secrets.xcconfig.example Wagerwall/Secrets.xcconfig
   # Fill in Supabase URL/anon key, Google iOS/Web client IDs, GOOGLE_REVERSED_CLIENT_ID
   ```
3. **Open the project**:
   ```bash
   open Wagerwall/Wagerwall.xcodeproj
   ```
4. **Optional — local Supabase**:
   ```bash
   brew install supabase/tap/supabase
   supabase start          # requires Docker
   supabase db reset       # applies migrations
   ```

Build from CLI (note the `DEVELOPER_DIR` — `xcode-select` may point at CommandLineTools):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -scheme Wagerwall \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -project Wagerwall/Wagerwall.xcodeproj \
  build
```

---

## Status (verified 2026-05-04)

See [`CLAUDE.md`](CLAUDE.md) for the canonical per-feature checklist. High-level summary:

- **Phases 0–11** (foundation, CBT, accountability, dashboard, panic button): mostly complete; UI wired to live Supabase repos.
- **Phase 12** (app/website blocking via Screen Time + Network Extension): not started — blocked on Apple entitlement.
- **Phase 13** (polish: tests, accessibility, localization, CI/CD, analytics): not started.
- **Auth routing currently bypassed**: `Core/AppState.swift:30` hardcodes `rootScreen = .main`. Re-enable before Phase 1 closure.
- **Push delivery stubbed**: `supabase/functions/send-push/index.ts` lacks JWT signing and the APNs HTTP/2 call.

---

## Architecture at a glance

```
SwiftUI Views ──▶ @Observable ViewModels ──▶ Repository protocols ──▶ Supabase SDK / bundled content
                                          ╰──▶ AppContent (Swift)        Postgres + Auth + Functions
```

- **Backend**: Supabase (Postgres + Auth + Edge Functions + Storage). RLS on every table; `auth.uid()` scoping.
- **Auth**: Google OAuth via Supabase Auth (Apple Sign-In still TBD; required by App Store guidelines).
- **Content**: CBT lessons & quiz questions bundled in `Wagerwall/Content/*.swift` (offline-first); user progress lives in Supabase (`user_lesson_progress`).
- **Blocking** (Phase 12, not built): designed as Screen Time API for app-level + `NEDNSProxyProvider` for cross-browser DNS filtering. See `BLOCKING_ARCHITECTURE.md`.

---

## Conventions

- SwiftUI everywhere; UIKit only for `UINavigationBarAppearance`/`UITabBarAppearance` (iOS 26 liquid glass quirk).
- `async/await`, no Combine.
- ViewModels are `@Observable`; never call Supabase directly from a view — go through a Repository.
- File names match the primary type (`CBTLessonView.swift` contains `CBTLessonView`).
- Migrations: numbered (`001_*`, `002_*`, ...). Edge functions: one folder per function with `index.ts`.
