# Content Architecture

How lesson and question content is stored, structured, and authored in WagerWall, and the reasoning behind each decision.

Last reviewed: 2026-04-28.

---

## TL;DR

- Lesson + question content is **bundled in the app as Swift code**. User-generated data stays in Supabase.
- Questions are **top-level**, peer to lessons. Lessons reference questions by ID, not by ownership.
- Files live under `Wagerwall/Wagerwall/Content/`: one Swift file per module + one aggregator.
- A `Question` is a struct of shared metadata (`id`, `tags`, `difficulty`, `prompt`, `explanation`) plus a `Payload` enum carrying type-specific data. Adding a new question type = adding an enum case.
- IDs are human-readable slugs (`q-fallacy-roulette`), not UUIDs.

---

## Where data lives

**Rule:** if you wrote it, it ships with the app. If the user wrote it, it lives in the database.

| Data | Location | Why |
|---|---|---|
| Modules, lessons, questions | App binary (Swift) | Authored once, identical across users, no sync needed |
| Lesson progress, question attempts, mastery state | Supabase | Per-user, mutable, syncs across devices |
| Mood logs, urge logs, streaks, profile | Supabase | Per-user, mutable |

### Why bundled, not DB

- **Offline.** Recovery moments happen at 2am, on a plane, in a parking lot. A lesson must open without network.
- **Zero latency.** No spinner, no skeleton, no failure mode at the most engagement-sensitive moment.
- **Content is code.** Lives in git, reviewed in PRs, readable diffs, `git revert` rollback.
- **Free hosting.** Scales to N users at zero marginal cost (no Supabase egress, no read quotas).

### Why Swift, not JSON

- **Compile-time validation** of question payload shapes. With JSON, a malformed question becomes a runtime decode error a real user sees.
- **No loader step.** Content is just Swift values; no startup parsing, no failure path.
- **Refactor-safe.** Renaming a field updates every reference automatically.
- **Forced UI completeness.** Adding a new question type fails the build until every renderer handles it.

JSON would win when non-engineer authoring or hot-reload becomes a real need. Both are hypothetical futures. Swift → JSON is a one-time codegen later; JSON → Swift later means having tolerated runtime failures the whole time.

---

## Top-level vs embedded

Questions are not nested inside lesson objects. They live in their own collection. Lesson sections reference them by ID:

```swift
// Lesson knows only the ID
Lesson(
    id: "lesson-gamblers-fallacy",
    sections: [
        .text(title: "What is it?", body: "..."),
        .question("q-fallacy-roulette"),    // reference, not embed
        .journal(prompt: "Write about a time you felt a 'lucky streak.'")
    ]
)

// Questions live separately
let questions: [Question] = [
    Question(id: "q-fallacy-roulette", ...),
    Question(id: "q-fallacy-streaks", ...),
]
```

A question is **tagged with** concepts, not **owned by** a lesson:

- The same question can be asked in-lesson (first teaching) AND in a 5-day review session AND in a topic-based practice quiz.
- A review-only question that belongs to no single lesson is natural in this model.
- Moving a question from one lesson to another = changing one ID, not cutting/pasting blobs.

---

## File layout

```
Wagerwall/Wagerwall/
├── Models/
│   ├── Module.swift          ← struct definition
│   ├── Lesson.swift          ← struct definition + Section enum
│   └── Question.swift        ← struct definition + Payload enum (rewrites the existing flat struct)
└── Content/
    ├── AppContent.swift              ← aggregator: flattens all modules / lessons / questions
    ├── ModuleUnderstanding.swift     ← module 1: its lessons + its questions
    ├── ModuleCognitive.swift         ← module 2
    ├── ModuleBehavioral.swift        ← module 3
    └── ...                           (one file per module, up to 8)
```

### Why one file per module

- ~80% of authoring is within one module ("today I'm finishing module 3"). One file = one workflow unit.
- Cross-cutting changes (e.g., reviewing every question tagged `difficulty:1`) are handled by IDE search.
- 8 modules × ~5 lessons + their questions ≈ 2-5KB per file. Tractable in Xcode.

### `AppContent.swift` is the consumer-facing surface

```swift
enum AppContent {
    static let modules: [Module]        // sorted by sortOrder
    static let lessons: [Lesson]        // flattened from all module files
    static let questions: [Question]    // flattened from all module files

    static func module(id: ModuleID) -> Module?
    static func lesson(id: LessonID) -> Lesson?
    static func question(id: QuestionID) -> Question?
    static func lessons(in moduleId: ModuleID) -> [Lesson]
    static func questions(taggedAny: Set<String>) -> [Question]
}
```

The rest of the app talks only to `AppContent`. Per-module files are an authoring detail.

---

## IDs

Human-readable slugs, lowercase with hyphens. Globally unique within their kind.

| Kind | Convention | Example |
|---|---|---|
| Module | `module-{topic}` | `module-understanding` |
| Lesson | `lesson-{topic}` | `lesson-gamblers-fallacy` |
| Question | `q-{topic}-{detail}` | `q-fallacy-roulette` |

**Rules:**
- Once shipped to users, an ID is permanent. Never reuse an ID for different content — it will silently corrupt user progress and review history.
- Orphaned IDs (a shipped build removed a question someone had progress on) are skipped on read.
- Slugs > UUIDs because they're readable in PR diffs, stack traces, and DB rows.

---

## Type definitions

```swift
typealias ModuleID = String
typealias LessonID = String
typealias QuestionID = String

struct Module: Identifiable, Sendable {
    let id: ModuleID
    let title: String
    let description: String
    let sortOrder: Int
    let estimatedMinutes: Int
    let iconName: String        // SF Symbol
}

struct Lesson: Identifiable, Sendable {
    let id: LessonID
    let moduleId: ModuleID
    let title: String
    let description: String
    let sortOrder: Int
    let estimatedMinutes: Int
    let sections: [Section]
}

enum Section: Sendable {
    case text(title: String?, body: String)
    case callout(style: CalloutStyle, body: String)
    case question(QuestionID)               // by-reference into AppContent.questions
    case journal(prompt: String)            // free-form reflection, no right answer
}

enum CalloutStyle: Sendable {
    case tip, warning, example, reflection
}

struct Question: Identifiable, Sendable {
    let id: QuestionID
    let tags: [String]                      // concepts this question tests
    let difficulty: Int                     // 1...5
    let prompt: String                      // the question text
    let explanation: String                 // shown after the user answers
    let payload: Payload

    enum Payload: Sendable {
        case multipleChoice(options: [String], correctIndex: Int)
        case multipleSelect(options: [String], correctIndices: Set<Int>)
        case trueFalse(answer: Bool)
        case fillInBlank(
            template: String,                   // e.g., "The ___ fallacy says ___"
            acceptedAnswers: [[String]],        // one inner array per blank, all valid spellings
            mode: FillInBlankMode
        )
        case matching(pairs: [Pair])
        case sortOrder(items: [String])         // canonical order; shown shuffled
        case swipeCategorize(
            leftLabel: String,                  // e.g., "Distortion"
            rightLabel: String,                 // e.g., "Healthy thought"
            cards: [SwipeCard]
        )
    }

    struct Pair: Sendable, Hashable {
        let left: String
        let right: String
    }

    struct SwipeCard: Sendable {
        let text: String
        let correctSide: SwipeSide
    }

    enum SwipeSide: Sendable { case left, right }
}

enum FillInBlankMode: Sendable {
    case freeType                            // user types into blanks
    case wordBank(words: [String])           // user picks from a tap-bank with distractors
}
```

**Why split shared metadata from `Payload`?** Avoids duplicating `id / tags / difficulty / prompt / explanation` across every type. Lets review/analytics code work on `Question` without unwrapping the payload.

**Why nested types under `Question` (Pair, SwipeCard, etc.)?** Namespacing — `Question.Pair` is unambiguous; a global `Pair` would collide with anything else.

---

## Question types

Seven supported, ordered by complexity:

| # | Type | Description |
|---|---|---|
| 1 | `multipleChoice` | Pick one of N options |
| 2 | `multipleSelect` | Pick all that apply |
| 3 | `trueFalse` | Degenerate MC; given its own case for cleaner UI |
| 4 | `fillInBlank` | Type into one or more blanks (free-type or word-bank mode) |
| 5 | `matching` | Match left column to right column |
| 6 | `sortOrder` | Reorder a list into the correct sequence |
| 7 | `swipeCategorize` | Swipe each card left/right based on which label fits |

**Adding an 8th type:** add a case to `Question.Payload`, add a renderer in the quiz UI. Compiler will fail until the renderer exists. That's the extensibility.

---

## Authoring example

A complete module file (`Content/ModuleUnderstanding.swift`):

```swift
enum ModuleUnderstanding {
    static let module = Module(
        id: "module-understanding",
        title: "Understanding Gambling",
        description: "Learn what problem gambling is and why it grips us.",
        sortOrder: 1,
        estimatedMinutes: 30,
        iconName: "brain.head.profile"
    )

    static let lessons: [Lesson] = [
        Lesson(
            id: "lesson-gamblers-fallacy",
            moduleId: "module-understanding",
            title: "The Gambler's Fallacy",
            description: "Past outcomes don't predict future ones.",
            sortOrder: 2,
            estimatedMinutes: 10,
            sections: [
                .text(title: "What is it?",
                      body: "The Gambler's Fallacy is the belief that past random events affect future ones..."),
                .callout(style: .example,
                         body: "\"I've lost 8 hands in a row at blackjack. I'm due for a win!\""),
                .question("q-fallacy-roulette"),
                .text(title: "The House Edge",
                      body: "Every casino game is mathematically designed so the house wins over time..."),
                .question("q-fallacy-streaks"),
                .journal(prompt: "Write about a time you felt a 'lucky streak.' What happened next?")
            ]
        ),
        // ... more lessons
    ]

    static let questions: [Question] = [
        Question(
            id: "q-fallacy-roulette",
            tags: ["gamblers-fallacy", "probability"],
            difficulty: 1,
            prompt: "A roulette wheel has landed red 6 times in a row. What's the probability the next spin is black?",
            explanation: "Each spin is independent. The wheel has no memory.",
            payload: .multipleChoice(
                options: [
                    "Much higher — black is overdue",
                    "Slightly higher than normal",
                    "About 47.4%, the same as always",
                    "Lower — red is on a hot streak"
                ],
                correctIndex: 2
            )
        ),
        Question(
            id: "q-fallacy-streaks",
            tags: ["gamblers-fallacy", "thinking-traps"],
            difficulty: 2,
            prompt: "Which of these reflect the Gambler's Fallacy? Select all that apply.",
            explanation: "Both options describe believing past random outcomes affect future ones.",
            payload: .multipleSelect(
                options: [
                    "I've been losing all night, so I'm due for a win",
                    "The casino has the math advantage in the long run",
                    "Heads has come up 7 times — tails must be coming",
                    "I'd rather walk than drive in this weather"
                ],
                correctIndices: [0, 2]
            )
        )
    ]
}
```

---

## Database implications

The current schema (`001_initial_schema.sql`) has `cbt_modules` and `cbt_lessons` tables, and `user_lesson_progress.lesson_id` is a `UUID REFERENCES cbt_lessons(id)`. Moving content to Swift requires:

- **Drop** `cbt_modules` and `cbt_lessons` tables (and their RLS policies).
- **Migrate** `user_lesson_progress.lesson_id` from `UUID REFERENCES cbt_lessons(id)` to plain `TEXT` (no FK).
- **Stop seeding** content via `002_cbt_content.sql` (delete or no-op).
- **Add** (in a follow-up migration) `question_attempts` and `user_question_state` tables. Both use `question_id TEXT`, no FK.

`question_attempts` shape (sketch — finalize when implementing):

```sql
CREATE TABLE question_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    question_id TEXT NOT NULL,
    was_correct BOOLEAN NOT NULL,
    answer_data JSONB,                       -- what the user actually picked
    context TEXT CHECK (context IN ('lesson', 'review')),
    attempted_at TIMESTAMPTZ DEFAULT NOW()
);
```

`user_question_state` shape (sketch):

```sql
CREATE TABLE user_question_state (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    question_id TEXT NOT NULL,
    mastery_level INT NOT NULL DEFAULT 0,    -- 0..5
    next_review_at TIMESTAMPTZ,
    last_seen_at TIMESTAMPTZ,
    PRIMARY KEY (user_id, question_id)
);
```

---

## Spaced repetition

The bank serves two consumers:

1. **In-lesson** — questions referenced from lesson sections, asked in order with the surrounding teaching.
2. **Review mode** — pulled at random by tag, mixed across modules, asked standalone.

Review uses a **Leitner-box scheduler** stored in `user_question_state`:

- `mastery_level: 0..5`
- `next_review_at: timestamp`
- Wrong → drop one level, due tomorrow
- Right → +1 level, double the interval (1d → 2d → 4d → 8d → 16d → 32d → mastered)
- Two wrongs in a row → reset to 0

Implementation deferred until lesson + question content is solid. Schema is forward-compatible; can swap in formal SM-2 later without changes.

---

## Migration plan from current state

1. Define types in `Models/Module.swift`, `Models/Lesson.swift`, `Models/Question.swift` (rewriting the existing flat `Question` struct).
2. Create `Content/AppContent.swift` aggregator.
3. Port the 9 lessons currently in `002_cbt_content.sql` into per-module Swift files. Extract embedded `quiz` blocks into top-level `questions` arrays with slug IDs.
4. Update `CBTContentService` (or equivalent repo) to read from `AppContent` instead of Supabase.
5. Write migration `004_decouple_content.sql` — drops content tables, changes progress columns to `TEXT`, removes content RLS policies.
6. Delete `Resources/QuestionBank.json` once Swift content is in place.
7. (Later) Migration `005_question_bank.sql` — adds `question_attempts` and `user_question_state` tables for review/SRS.
