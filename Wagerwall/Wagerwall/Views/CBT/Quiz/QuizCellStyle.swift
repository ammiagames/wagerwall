import SwiftUI

/// Shared visual language for the in-lesson and quiz-session question
/// renderers. Picks up the pastel pink/lavender palette established in
/// `MatchingView` so the seven question types feel like one family.
enum QuizPalette {
    // Idle (interactive but unselected)
    static let idleBg = Color(red: 0.96, green: 0.91, blue: 0.96)
    static let idleText = Color(red: 0.25, green: 0.10, blue: 0.30)
    static let idleBorder = Color(red: 0.88, green: 0.82, blue: 0.90)

    // Selected (user picked it; result not yet revealed)
    static let selectedBg = Color(red: 0.92, green: 0.85, blue: 0.96)
    static let selectedText = Color(red: 0.45, green: 0.20, blue: 0.60)
    static let selectedBorder = Color(red: 0.55, green: 0.30, blue: 0.70)

    // Correct (revealed)
    static let correctBg = Color(red: 0.80, green: 0.95, blue: 0.82)
    static let correctText = Color(red: 0.15, green: 0.50, blue: 0.25)
    static let correctBorder = Color(red: 0.30, green: 0.70, blue: 0.40)

    // Wrong (revealed)
    static let wrongBg = Color(red: 1.00, green: 0.85, blue: 0.85)
    static let wrongText = Color(red: 0.65, green: 0.15, blue: 0.20)
    static let wrongBorder = Color(red: 0.85, green: 0.35, blue: 0.40)

    // Missed correct — outlined green, not filled
    static let missedBg = Color(red: 0.93, green: 0.98, blue: 0.93)
    static let missedText = correctText
    static let missedBorder = correctBorder
}

/// The standard "this is the question" header used at the top of every
/// renderer. Pulls the eye and gives the question a consistent shape.
struct QuestionPromptHeader: View {
    let prompt: String

    var body: some View {
        Text(prompt)
            .font(.body.weight(.medium))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.purple.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// The "Nice!" / "Not quite" feedback card with the question's explanation.
/// Slides up below the answer area once the user submits.
struct QuestionFeedbackCard: View {
    let isCorrect: Bool
    let explanation: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.title3)
                .foregroundStyle(isCorrect ? .green : .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(isCorrect ? "Nice!" : "Not quite")
                    .font(.subheadline.bold())
                    .foregroundStyle(isCorrect ? .green : .orange)

                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isCorrect ? Color.green : Color.orange).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// "Check" / "Continue" pill at the bottom of a renderer. Color encodes the
/// answer state — neutral while building, green if correct, red if wrong.
struct QuizActionButton: View {
    enum State {
        case disabled
        case ready              // can submit
        case correct
        case wrong
    }

    let title: String
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(state == .disabled)
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    private var background: Color {
        switch state {
        case .disabled: return Color.blue.opacity(0.4)
        case .ready: return .blue
        case .correct: return .green
        case .wrong: return .red
        }
    }
}
