# Repositories

The data-access layer. Each is a **protocol + a `Supabase`-backed struct**. ViewModels and Views talk to the protocol via `@Environment`; Supabase is hidden below this line.

> **Rule**: this is the only layer that calls `supabase.from(…)`. If you find Supabase queries in a view or VM, refactor them down here.

---

## Files (10 repositories)

| File | Protocol | Supabase table | What it does |
|---|---|---|---|
| `UserProfileRepository.swift` | `UserProfileRepository` | `user_profiles` | fetch / update profile, delete account |
| `StreakRepository.swift` | `StreakRepository` | `user_streaks` | fetch streak, record check-in (server-calculated streak via `daily-streak-update`) |
| `CBTRepository.swift` | `CBTRepository` | `user_lesson_progress` (+ bundled `AppContent`) | reads modules/lessons/questions from `Content/AppContent.swift`; reads/writes per-user progress to Supabase |
| `UrgeLogRepository.swift` | `UrgeLogRepository` | `urge_logs` | fetch (limit 50), create |
| `MoodLogRepository.swift` | `MoodLogRepository` | `mood_logs` | fetch (limit 30), today's log, create |
| `HeartbeatRepository.swift` | `HeartbeatRepository` | `device_heartbeats` | fetch, upsert, send heartbeat |
| `AccountabilityPartnerRepository.swift` | `AccountabilityPartnerRepository` | `accountability_partners` | fetch, invite, soft-delete (status = "removed") |
| `BlockedAttemptRepository.swift` | `BlockedAttemptRepository` | `blocked_attempts` | fetch (limit 50), count, log |
| `DisableRequestRepository.swift` | `DisableRequestRepository` | `disable_requests` | fetch active, create, cancel |
| `PushTokenRepository.swift` | `PushTokenRepository` | `push_tokens` | upsert token, remove token |

---

## Pattern

Every repository file follows the same shape:

```swift
import Foundation
import Supabase     // required due to SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES

protocol UrgeLogRepository: Sendable {
    func fetchLogs(userId: UUID) async throws -> [UrgeLog]
    func createLog(_ insert: UrgeLogInsert) async throws -> UrgeLog
}

struct SupabaseUrgeLogRepository: UrgeLogRepository {
    func fetchLogs(userId: UUID) async throws -> [UrgeLog] {
        try await supabase
            .from("urge_logs")
            .select()
            .eq("user_id", value: userId)
            .order("logged_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    func createLog(_ insert: UrgeLogInsert) async throws -> UrgeLog {
        try await supabase
            .from("urge_logs")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }
}
```

The protocol exists so SwiftUI Previews and tests can inject mocks. The concrete `Supabase…Repository` is registered in `WagerwallApp.swift` and pulled via `@Environment(\.urgeLogRepository) var repo`.

---

## `CBTRepository` — the hybrid one

CBT content is bundled in the app (`Content/*.swift`); progress is per-user in Supabase. This repo straddles both.

```swift
protocol CBTRepository: Sendable {
    // Content (no network — cannot fail)
    func fetchModules() -> [Module]
    func fetchLessons() -> [Lesson]
    func fetchLesson(id: LessonID) -> Lesson?

    // Progress (Supabase — may throw)
    func fetchProgress(userId: UUID) async throws -> [UserLessonProgress]
    func fetchLessonProgress(userId: UUID, lessonId: LessonID) async throws -> UserLessonProgress?
    func upsertProgress(_ progress: UserLessonProgressInsert) async throws -> UserLessonProgress
    func updateProgress(_ update: UserLessonProgressUpdate, id: UUID) async throws -> UserLessonProgress
}
```

After migration `004_decouple_content.sql`, `user_lesson_progress.lesson_id` is `TEXT` (not UUID). The slug must match an entry in `AppContent.lessons`; otherwise the row is orphaned and the app skips it.

See `Content/Content.md` for how lessons/questions are authored.

---

## Soft-delete tables

Two tables never hard-delete; they flip a status column instead:

- `accountability_partners` — `status` goes `"invited"` → `"active"` → `"removed"`.
- `disable_requests` — `status` goes `"pending"` → `"approved"` / `"cancelled"` / `"expired"`.

This preserves audit trails. RLS still hides removed/cancelled rows where appropriate, but the rows stick around.

---

## Adding a new repository

1. Define the model + Insert/Update structs in `Models/`.
2. Create `MyThingRepository.swift` here:
   - `protocol MyThingRepository: Sendable { … }`
   - `struct SupabaseMyThingRepository: MyThingRepository { … }`
3. Add an `EnvironmentKey` and accessor in `Core/Dependencies.swift`.
4. Inject the concrete impl in `WagerwallApp.swift`'s `.environment(\.myThingRepository, …)` chain.
5. Pull from VMs via `@Environment(\.myThingRepository)`.

If the table needs RLS (it should), add the policy to a new migration in `supabase/migrations/`.

---

## What does NOT belong here

- **Caching, retry logic, error recovery** — none of the repos do this today. Add it in a new layer or extend specific VMs that need it; don't bake it into every repo.
- **Domain logic** — repos translate between Swift types and Postgres rows. Computing streak messages, scoring quizzes, deriving "money saved" — that's `ViewModels/` work.
- **Side effects beyond Supabase** — analytics, notifications, navigation. Repos are pure data; effects belong in services or VMs.
- **`import SwiftUI`** — never. Repos compile and test without UIKit/SwiftUI.

---

## Testing notes

There are no tests today. When tests come in: each protocol is small, so an in-memory mock is trivial:

```swift
struct InMemoryUrgeLogRepository: UrgeLogRepository {
    var logs: [UrgeLog] = []
    func fetchLogs(userId: UUID) async throws -> [UrgeLog] { logs }
    func createLog(_ insert: UrgeLogInsert) async throws -> UrgeLog {
        let log = UrgeLog(/* construct from insert */)
        // record in mutable storage
        return log
    }
}
```

Inject via `.environment(\.urgeLogRepository, InMemoryUrgeLogRepository())` in tests/previews.
