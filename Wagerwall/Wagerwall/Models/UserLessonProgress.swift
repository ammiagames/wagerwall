import Foundation

enum LessonProgressStatus: String, Codable, CaseIterable, Sendable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case completed
}

struct UserLessonProgress: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let lessonId: LessonID
    var status: LessonProgressStatus
    var startedAt: Date?
    var completedAt: Date?
    var exerciseData: ExerciseData?
}

struct ExerciseData: Codable, Sendable {
    var journalEntries: [String]?
    var quizScore: Int?
    var quizTotal: Int?
}

struct UserLessonProgressInsert: Codable, Sendable {
    let userId: UUID
    let lessonId: LessonID
    var status: LessonProgressStatus
    var startedAt: Date?
}

struct UserLessonProgressUpdate: Codable, Sendable {
    var status: LessonProgressStatus?
    var completedAt: Date?
    var exerciseData: ExerciseData?
}
