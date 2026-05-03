import SwiftUI

/// Renders a "coming soon" card for question types that don't yet have a renderer.
/// Lets the quiz session continue (auto-marks correct so the flow doesn't get stuck).
/// Replace with real renderers as each type gets implemented.
struct UnsupportedQuestionPlaceholder: View {
    let question: Question
    let onAnswer: (Bool) -> Void

    @State private var hasContinued = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Coming Soon")
                    .font(.title3.bold())

                Text(typeName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(question.prompt)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                guard !hasContinued else { return }
                hasContinued = true
                onAnswer(true)
            } label: {
                Text("Skip")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(hasContinued)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var typeName: String {
        switch question.payload {
        case .multipleSelect: "Multiple Select"
        case .fillInBlank: "Fill in the Blank"
        case .sortOrder: "Sort / Reorder"
        case .swipeCategorize: "Swipe to Categorize"
        case .multipleChoice, .trueFalse, .matching: "Question"
        }
    }
}
