# Models

Codable, Sendable structs that map 1:1 to Supabase tables, plus a few value types that exist only in-app (CBT content, assessments). All snake_case in the DB; CamelCase in Swift. Snake-case conversion happens in `Services/SupabaseService.swift`.

> **No business logic here.** These are pure data carriers. Logic lives in ViewModels or Repositories.

---

## Files

### Maps to Supabase tables

| File | Struct | Table | Notes |
|---|---|---|---|
| `UserProfile.swift` | `UserProfile`, `UserProfileUpdate`, `GamblingSeverity` enum | `user_profiles` | Severity enum: `low`, `moderate`, `high`, `severe` |
| `UserStreak.swift` | `UserStreak` | `user_streaks` | Server-calculated; client only writes `last_check_in` |
| `AccountabilityPartner.swift` | `AccountabilityPartner`, `AccountabilityPartnerInsert`, `PartnerStatus` enum | `accountability_partners` | Soft-delete via `status = "removed"` |
| `DeviceHeartbeat.swift` | `DeviceHeartbeat`, `DeviceHeartbeatUpsert` | `device_heartbeats` | Composite unique on `(user_id, device_id)` |
| `UserLessonProgress.swift` | `UserLessonProgress`, `…Insert`, `…Update`, `ExerciseData` | `user_lesson_progress` | `lesson_id` is `TEXT` after migration `004_decouple_content.sql` (was UUID) |
| `UrgeLog.swift` | `UrgeLog`, `UrgeLogInsert`, `UrgeOutcome` enum | `urge_logs` | Outcome: `resisted`, `gave_in`, `used_panic_button` |
| `MoodLog.swift` | `MoodLog`, `MoodLogInsert` | `mood_logs` | `mood_score`: 1–5 |
| `BlockedAttempt.swift` | `BlockedAttempt`, `BlockedAttemptInsert`, `BlockedItemType` enum | `blocked_attempts` | Type: `app` or `website` |
| `DisableRequest.swift` | `DisableRequest`, `DisableRequestInsert`, `DisableRequestStatus` enum | `disable_requests` | Status: `pending`, `approved`, `expired`, `cancelled` |
| `PushToken.swift` | `PushToken`, `PushTokenInsert` | `push_tokens` | APNs only (`platform = "ios"`) |

### In-app content types (no DB table)

| File | Struct | Used by |
|---|---|---|
| `Module.swift` | `Module` (id, title, description, sortOrder, estimatedMinutes, iconName) | `Content/AppContent.swift` |
| `Lesson.swift` | `Lesson`, `LessonSection` enum, `CalloutStyle` enum | `Content/AppContent.swift`, `LessonViewModel` |
| `Question.swift` | `Question`, nested `Payload` enum (7 variants), `Pair`, `SwipeCard`, `FillInBlankMode` | `Content/AppContent.swift`, `Views/CBT/Quiz/*` |
| `Assessment.swift` | `Assessment`, `AssessmentQuestion`, `AssessmentOption`, `AssessmentScoring`, `SeverityRange` + bundled-JSON loader + scorer | `Views/Profile/AssessmentView` |

---

## Insert vs read structs

DB tables have server-generated IDs and timestamps. Reads use the full struct (`UrgeLog`); writes use a separate `*Insert` struct without those fields. This avoids accidentally sending nil/zero IDs back to the server.

```swift
struct UrgeLog: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let intensity: Int
    // ...
    let loggedAt: Date
}

struct UrgeLogInsert: Codable, Sendable {
    let userId: UUID
    let intensity: Int
    // no id, no loggedAt — server fills both
}
```

`Update` variants are sparse — only fields the caller wants to change (e.g., `UserProfileUpdate` is all-optional so you can `PATCH` a single column).

---

## `Lesson.LessonSection` — the rich lesson format

```swift
enum LessonSection: Sendable, Hashable {
    case text(title: String?, body: String)
    case callout(style: CalloutStyle, body: String)   // tip | warning | example | reflection
    case question(QuestionID)                         // by-reference into AppContent.questions
    case journal(prompt: String)                      // free-form; saved to user_lesson_progress.exercise_data
}
```

A lesson is just an ordered list of sections. `LessonViewModel` walks it; `LessonView` renders each section type. Adding a new section type = adding a case here + handling it in the renderer (compiler-enforced).

---

## `Question.Payload` — 7 quiz variants

```swift
enum Payload: Sendable {
    case multipleChoice(options: [String], correctIndex: Int)
    case multipleSelect(options: [String], correctIndices: Set<Int>)
    case trueFalse(answer: Bool)
    case fillInBlank(template: String, acceptedAnswers: [[String]], mode: FillInBlankMode)
    case matching(pairs: [Pair])
    case sortOrder(items: [String])
    case swipeCategorize(leftLabel: String, rightLabel: String, cards: [SwipeCard])
}
```

Each variant has a renderer in `Views/CBT/Quiz/`. To add an 8th type, add a case here and a corresponding view; the compiler will fail every place that switches on `Payload` until you handle it.

See [`CONTENT_ARCHITECTURE.md`](../../../CONTENT_ARCHITECTURE.md) for the design rationale.

---

## `Assessment` — bundled PGSI questionnaire

`Assessment.swift` defines Codable types and a static loader that reads `Resources/Assessment.json` at app launch. Returns the assessment + a `score(for:)` helper that maps the user's total to a `GamblingSeverity` via the `ranges` array in the JSON.

Used only by `Views/Profile/AssessmentView.swift`. Currently lives in Profile, not in onboarding — `OnboardingViewModel` has `.welcome` and `.screenTime` steps only; the PGSI step is a TODO.

---

## Conventions

- **Codable**: every struct conforms. JSON encoder/decoder are configured in `Services/SupabaseService.swift` with snake-case key conversion + ISO8601 with fractional seconds.
- **Sendable**: every struct + enum is Sendable so they cross actor boundaries cleanly under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- **No methods beyond `Codable`**: keep models pure. The sole exceptions are `Assessment` (loader + scorer) and small computed properties for derived values (e.g., `UserStreak.streakMessage`).
- **Optional vs non-optional**: match the DB. If a column is `NOT NULL`, the Swift property is non-optional. If the DB allows null, the Swift property is `Optional`.
- **Date format**: `Date` (Codable handles via `SupabaseService`'s decoder). `last_check_in` is a `String` because Postgres returns `DATE` (not `TIMESTAMPTZ`) and we don't need the time component.

---

## Cross-references

- Inserts/updates flow through `Repositories/` — never write to Supabase directly from a model.
- `UserProfile` is read on app launch by `AppState.resolveRoute()` to decide onboarding vs main routing (currently bypassed).
- `Question` IDs in `Lesson` sections must match an entry in `AppContent.questions` — there's no compile-time check, but `AppContent.question(id:)` returns nil and the section is skipped at render time. Keep IDs in sync.
- After migration `004_decouple_content.sql`, `UserLessonProgress.lessonId` is a slug like `"lesson-gamblers-fallacy"`, not a UUID.
