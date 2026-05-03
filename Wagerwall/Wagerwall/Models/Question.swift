import Foundation

struct Question: Identifiable, Sendable, Hashable {
    let id: QuestionID
    let moduleId: ModuleID?       // nil for review-only questions not tied to a module
    let tags: [String]            // concepts this question tests
    let difficulty: Int           // 1...5
    let prompt: String
    let explanation: String
    let payload: Payload

    enum Payload: Sendable, Hashable {
        case multipleChoice(options: [String], correctIndex: Int)
        case multipleSelect(options: [String], correctIndices: Set<Int>)
        case trueFalse(answer: Bool)
        case fillInBlank(template: String, acceptedAnswers: [[String]], mode: FillInBlankMode)
        case matching(pairs: [Pair])
        case sortOrder(items: [String])      // canonical order; shown shuffled
        case swipeCategorize(leftLabel: String, rightLabel: String, cards: [SwipeCard])
    }

    struct Pair: Sendable, Hashable {
        let left: String
        let right: String

        init(_ left: String, _ right: String) {
            self.left = left
            self.right = right
        }
    }

    struct SwipeCard: Sendable, Hashable {
        let text: String
        let correctSide: SwipeSide
    }

    enum SwipeSide: Sendable, Hashable {
        case left, right
    }
}

enum FillInBlankMode: Sendable, Hashable {
    case freeType
    case wordBank(words: [String])
}
