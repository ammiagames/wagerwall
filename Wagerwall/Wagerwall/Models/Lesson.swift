import Foundation

struct Lesson: Identifiable, Sendable, Hashable {
    let id: LessonID
    let moduleId: ModuleID
    let title: String
    let description: String
    let sortOrder: Int
    let estimatedMinutes: Int
    let sections: [LessonSection]
}

enum LessonSection: Sendable, Hashable {
    case text(title: String?, body: String)
    case callout(style: CalloutStyle, body: String)
    case question(QuestionID)            // by-reference into AppContent.questions
    case journal(prompt: String)         // free-form reflection, no right answer
}

enum CalloutStyle: Sendable, Hashable {
    case tip, warning, example, reflection
}
