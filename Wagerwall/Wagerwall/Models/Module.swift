import Foundation

typealias ModuleID = String
typealias LessonID = String
typealias QuestionID = String

struct Module: Identifiable, Sendable, Hashable {
    let id: ModuleID
    let title: String
    let description: String
    let sortOrder: Int
    let estimatedMinutes: Int
    let iconName: String        // SF Symbol
}
