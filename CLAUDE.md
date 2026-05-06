# WagerWall - Project Guide

This is the LLM implementation guide. See `PROJECT.md` for the full specification and `BLOCKING_ARCHITECTURE.md` for the implementation-grade design of the Screen Time + DNS proxy + bloom filter blocking layer (Phase 12).

## Quick Reference

- **Platform**: iOS 17+ (SwiftUI, Xcode 26 beta / Swift 6)
- **Architecture**: MVVM with Repository pattern
- **Backend**: Supabase (PostgreSQL, Auth, Edge Functions, Realtime)
- **Auth**: Google OAuth via Supabase Auth (GCP OAuth 2.0 client)
- **Bundle ID**: `com.wagerwall.app`
- **Key Frameworks**: FamilyControls, ManagedSettings, DeviceActivity, NetworkExtension

## Project Structure

```
wagerwall/
├── .gitignore
├── README.md                       # Repo onboarding doc — start here
├── CLAUDE.md                       # This file — LLM guide
├── PROJECT.md                      # Full product specification
├── TECH_SPEC.md                    # Architecture & feasibility
├── BLOCKING_ARCHITECTURE.md        # Phase 12 design (not implemented)
├── CONTENT_ARCHITECTURE.md         # CBT content design (Swift-bundled)
│
├── Wagerwall/                      # Xcode project root
│   ├── Wagerwall.xcodeproj/        # 3 targets: Wagerwall + WagerwallTests + WagerwallUITests
│   ├── Info.plist                  # $(VAR) refs to Secrets.xcconfig; BGTask IDs; UIBackgroundModes
│   ├── Secrets.xcconfig            # Credentials (GITIGNORED)
│   ├── Secrets.xcconfig.example    # Template
│   ├── Wagerwall/                  # Main app target — see Wagerwall/README.md
│   │   ├── WagerwallApp.swift      # @main; wires services + repos via @Environment
│   │   ├── ContentView.swift       # Switch on AppState.rootScreen
│   │   ├── README.md               # iOS app overview
│   │   ├── Core/                   # AppState, Config, Dependencies (DI), Theme — see Core/Core.md
│   │   ├── Models/                 # 15 Codable structs (10 DB-backed + 4 in-app + 1 enum) — see Models/Models.md
│   │   ├── Services/               # SupabaseService, AuthService, NotificationService, HeartbeatService — see Services/Services.md
│   │   ├── Repositories/           # 10 protocol+Supabase repos — see Repositories/Repositories.md
│   │   ├── ViewModels/             # 9 @Observable VMs — see ViewModels/ViewModels.md
│   │   ├── Views/                  # SwiftUI by feature — see Views/Views.md
│   │   │   ├── Auth/               # SignInView
│   │   │   ├── Onboarding/         # OnboardingContainerView, WelcomeStepView, ScreenTimeAuthStepView
│   │   │   ├── Dashboard/          # MainTabView, DashboardView, LogMoodView, LogUrgeView, PanicButtonView, BreathingExerciseView, MotivationalCardView, ProgressTabView
│   │   │   ├── CBT/                # CBTModulesView, CBTModuleDetailView, LessonView, LessonCompleteView
│   │   │   │   └── Quiz/           # 7 question renderers + helpers
│   │   │   ├── Profile/            # ProfileView, EditProfileView, AssessmentView, AccountabilityPartnersView, InvitePartnerView, DisableProtectionView, DisableRequestStatusView, CrisisResourcesView, SettingsView
│   │   │   ├── Components/         # CardView, WaveDecoration, WagerWallButton, ProgressStepIndicator, StatCard, ThemedBackground
│   │   │   └── Blocking/           # (empty — Phase 12 placeholder)
│   │   ├── Content/                # Bundled CBT modules — see Content/Content.md
│   │   │   ├── AppContent.swift    # Aggregator (modules, lessons, questions + lookups)
│   │   │   ├── ModuleUnderstanding.swift   # Module 1
│   │   │   ├── ModuleCognitive.swift       # Module 2
│   │   │   └── ModuleBehavioral.swift      # Module 3 (modules 4–8 not authored)
│   │   └── Resources/              # Assessment.json (PGSI questionnaire)
│   ├── WagerwallTests/             # Default Xcode stub
│   └── WagerwallUITests/           # Default Xcode stubs
│
├── supabase/                       # Backend — see supabase/README.md
│   ├── config.toml                 # Local-dev ports + flags
│   ├── migrations/                 # 4 SQL files — see supabase/migrations/README.md
│   │   ├── 001_initial_schema.sql       # 14 tables + RLS + signup trigger
│   │   ├── 002_cbt_content.sql          # NO-OP (content moved to app binary)
│   │   ├── 003_cron_jobs.sql            # All commented out (Pro plan)
│   │   └── 004_decouple_content.sql     # Drops cbt_modules/cbt_lessons; lesson_id → TEXT
│   └── functions/                  # 5 edge functions — see supabase/functions/README.md
│       ├── send-push/              # STUB — no APNs JWT, no HTTP/2
│       ├── notify-partner/         # Push works, email logs only
│       ├── check-heartbeats/       # Production-ready
│       ├── process-disable-request/# Production-ready
│       └── daily-streak-update/    # Production-ready (does NOT auto-increment streak)
│
└── (future) fastlane/, .github/workflows/  # CI/CD not configured
```

## Credentials

Secrets are externalized into `Wagerwall/Secrets.xcconfig` (gitignored). To set up:

1. Copy `Wagerwall/Secrets.xcconfig.example` to `Wagerwall/Secrets.xcconfig`
2. Fill in your Supabase and Google OAuth credentials
3. The xcconfig is wired as a base configuration in the Xcode project
4. Values flow: `Secrets.xcconfig` → `Info.plist` via `$(VARIABLE)` → `Config.swift` reads from `Bundle.main.infoDictionary`

## Conventions

- Use SwiftUI for all views; no UIKit unless absolutely necessary
- Prefer `async/await` over Combine for async work
- All Supabase calls go through Repository classes, never directly from ViewModels
- Name files after the primary type they contain (e.g., `CBTLessonView.swift`)
- Keep views small; extract subviews into the `Components/` folder
- Use SwiftUI environment for dependency injection of services
- Edge functions use TypeScript (Deno runtime)
- SQL migrations are numbered: `001_initial_schema.sql`, `002_cbt_content.sql`, etc.

## Commands

```bash
# Supabase local dev
supabase start          # Start local Supabase
supabase db reset       # Reset DB and rerun migrations
supabase functions serve # Run edge functions locally

# iOS (requires DEVELOPER_DIR because xcode-select points to CommandLineTools)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Wagerwall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build -project Wagerwall/Wagerwall.xcodeproj
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Wagerwall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -project Wagerwall/Wagerwall.xcodeproj
```

## Implementation Progress

Last verified: 2026-05-04 via subagent audit of source tree (90 Swift files, 4 migrations, 5 edge functions, 3 Xcode targets).

- [x] **Phase 0**: Project hygiene — deployment target (17.0), bundle ID (com.wagerwall.app), credentials externalized, directory structure, .gitignore. SPM: supabase-swift 2.41.1, GoogleSignIn-iOS 9.1.0.
- [x] **Phase 1**: Data models — 15 model files (UserProfile, UserStreak, AccountabilityPartner, DeviceHeartbeat, UserLessonProgress, UrgeLog, MoodLog, BlockedAttempt, DisableRequest, PushToken + Module, Lesson, Question, Assessment value types) with Insert/Update DTOs.
- [x] **Phase 2**: Repository layer — 10 protocol+Supabase repos in `Repositories/`, `Core/Dependencies.swift` defines an `EnvironmentKey` per repo, all wired in `WagerwallApp.swift`, no stub returns.
- [~] **Phase 3**: Navigation architecture — `AppState`, `MainTabView`, `ContentView` routing exist BUT `Core/AppState.swift:30` hardcodes `rootScreen = .main` with `// TODO: Re-enable auth flow when sign-in is ready` (line 28) — auth/onboarding routing is currently bypassed
- [~] **Phase 4**: Onboarding flow — `OnboardingViewModel` only declares `.welcome` and `.screenTime` cases; PGSI `AssessmentView` lives standalone in Profile, not in onboarding; quit date / spend / completion summary steps missing; `ScreenTimeAuthStepView` is a placeholder (no `FamilyControls` calls)
- [x] **Phase 5**: Dashboard — streak, mood, urge cards wired to real repos; `LogUrgeView`, `LogMoodView`, `BreathingExerciseView` functional
- [x] **Phase 6**: CBT module system — `CBTModulesView`, `CBTModuleDetailView`, `LessonView`, `LessonCompleteView`, full `Views/CBT/Quiz/` subsystem (MCQ, MultipleSelect, TrueFalse, FillInBlank, Matching, SortOrder, SwipeCategorize), journal sections via `LessonSection.journal`
- [x] **Phase 7**: Profile and settings — `ProfileView`, `EditProfileView`, `SettingsView`, `AssessmentView`, `CrisisResourcesView` wired
- [x] **Phase 8**: Panic button — `PanicButtonView`, `BreathingExerciseView`, `MotivationalCardView`, `PanicButtonViewModel` (intensity hardcoded to 8 in `logAndComplete`)
- [~] **Phase 9**: Heartbeat + push notifications — iOS side complete (`HeartbeatService` with 5-min foreground timer + `BGAppRefreshTask` for `com.wagerwall.app.heartbeat`, `NotificationService` with APNs token registration to `PushTokenRepository`); backend `send-push` is a stub (no JWT signing, no APNs HTTP/2 call — `index.ts:68-69, 101-102`)
- [~] **Phase 10**: Supabase Edge Functions — 4/5 production-ready (`check-heartbeats`, `notify-partner` push path, `process-disable-request`, `daily-streak-update`); `send-push` requires APNs JWT signing; `notify-partner` email path is `console.log`-only (`index.ts:74-82`); `daily-streak-update/index.ts:45-47` does NOT auto-increment streak (both branches return current value — streak ticks on user check-in only); `003_cron_jobs.sql` jobs are commented out (Pro plan required)
- [~] **Phase 11**: Accountability partners — UI complete (`AccountabilityPartnersView`, `InvitePartnerView`, `DisableProtectionView`, `DisableRequestStatusView`); `AccountabilityPartnerViewModel` handles partner CRUD + disable-request lifecycle; end-to-end notification delivery limited until `send-push` is finished
- [ ] **Phase 12**: App & website blocking — **NOT STARTED**. Zero references to `FamilyControls`, `ManagedSettings`, `DeviceActivity`, `NetworkExtension` in source. No `ShieldConfiguration`/`ShieldAction`/`DeviceActivityMonitor` extension targets in pbxproj (only 3 targets: Wagerwall + 2 test targets). No `.entitlements` file. No App Group identifiers. `Views/Blocking/` folder exists but is empty. Blocked on Apple entitlement application.
- [ ] **Phase 13**: Polish & testing — `WagerwallTests` (1 stub test) and `WagerwallUITests` (3 stub tests + screenshot capture) are still default Xcode stubs; zero `accessibilityLabel`/`accessibilityHint` annotations across all views; no `.strings`/`.xcstrings` localization; no `PrivacyInfo.xcprivacy` manifest; no CI/CD (`.github/workflows`, `fastlane/`); no shared Xcode scheme (only user-local); no analytics/Sentry

Legend: `[x]` complete · `[~]` partial (see notes) · `[ ]` not started

### Content architecture migration (completed 2026-05)

CBT content was moved from the database to the app binary. See [`CONTENT_ARCHITECTURE.md`](CONTENT_ARCHITECTURE.md) for the design.

- **Migration `004_decouple_content.sql`** drops `cbt_modules` and `cbt_lessons`, converts `user_lesson_progress.lesson_id` from UUID to TEXT (slug like `"lesson-gamblers-fallacy"`).
- **Migration `002_cbt_content.sql`** is now a no-op (kept for reproducibility; was previously seeding modules 1–3).
- **`Wagerwall/Wagerwall/Content/`** holds the bundled content: `AppContent.swift` (aggregator) + `ModuleUnderstanding.swift` + `ModuleCognitive.swift` + `ModuleBehavioral.swift`. Modules 4–8 still need authoring (Urge Surfing, Alternative Activities, Financial Recovery, Relapse Prevention, Support Network).
- **`CBTRepository`** is now hybrid — content from `AppContent`, progress from Supabase.

### Cross-cutting gaps not tied to a phase

- **Apple Sign-In**: not implemented (only Google OAuth via `Services/AuthService.swift`). Required by App Store guideline 4.8 whenever third-party sign-in is offered.
- **Modules 4–8**: not authored yet (see Content section above).
- **Email delivery**: `notify-partner` logs `console.log` instead of sending email — needs SendGrid/Resend.
- **Seed data**: `supabase/config.toml:65` references `seed.sql` which doesn't exist. No demo data for local dev.
- **APNs secrets**: `APNS_KEY`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID` not configured. Even after JWT signing lands, push won't deliver until secrets are set via `supabase secrets set`.
- **No shared Xcode scheme**: only `xcuserdata/.../xcschemes/` exists. Move to `xcshareddata/xcschemes/` before setting up CI.
