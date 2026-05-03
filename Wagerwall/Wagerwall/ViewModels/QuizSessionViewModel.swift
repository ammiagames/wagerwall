import Foundation

@Observable
final class QuizSessionViewModel {

    // MARK: - Configuration

    let questions: [Question]
    let title: String

    // MARK: - Session State

    var currentIndex: Int = 0
    var isShowingFeedback: Bool = false
    var isComplete: Bool = false
    var lastAnswerCorrect: Bool? = nil

    // MARK: - Scoring

    private(set) var answers: [String: Bool] = [:]   // questionId -> correct?
    private(set) var streak: Int = 0
    private(set) var bestStreak: Int = 0

    // MARK: - Init

    init(questions: [Question], title: String) {
        self.questions = questions.shuffled()
        self.title = title
    }

    // MARK: - Computed

    var currentQuestion: Question? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }

    var correctCount: Int {
        answers.values.filter { $0 }.count
    }

    var totalAnswered: Int {
        answers.count
    }

    var scorePercent: Int {
        guard !answers.isEmpty else { return 0 }
        return Int(round(Double(correctCount) / Double(answers.count) * 100))
    }

    var questionsRemaining: Int {
        questions.count - currentIndex
    }

    // MARK: - Actions

    func submitAnswer(isCorrect: Bool) {
        guard let question = currentQuestion else { return }
        answers[question.id] = isCorrect
        lastAnswerCorrect = isCorrect

        if isCorrect {
            streak += 1
            bestStreak = max(bestStreak, streak)
        } else {
            streak = 0
        }

        isShowingFeedback = true
    }

    func continueToNext() {
        isShowingFeedback = false
        lastAnswerCorrect = nil

        if currentIndex + 1 >= questions.count {
            isComplete = true
        } else {
            currentIndex += 1
        }
    }
}
