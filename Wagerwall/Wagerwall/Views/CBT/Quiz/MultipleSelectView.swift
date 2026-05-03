import SwiftUI

/// Renders a `Question.Payload.multipleSelect`. User taps cards to toggle them
/// (each independent), then taps "Check" once. After check, the cards reveal:
/// green = correct pick, red = wrong pick, dashed-green outline = missed
/// correct answer. Score is binary: only an exact set match counts as right.
struct MultipleSelectView: View {
    let question: Question
    let isShowingFeedback: Bool
    let onAnswer: (Bool) -> Void

    @State private var selected: Set<Int> = []
    @State private var hasChecked = false

    var body: some View {
        guard case .multipleSelect(let options, let correctIndices) = question.payload else {
            return AnyView(
                Text("Unsupported payload for MultipleSelectView")
                    .foregroundStyle(.secondary)
            )
        }
        return AnyView(content(options: options, correctIndices: correctIndices))
    }

    private func content(options: [String], correctIndices: Set<Int>) -> some View {
        let allCorrect = selected == correctIndices

        return VStack(spacing: 18) {
            QuestionPromptHeader(prompt: question.prompt)

            Text("Select all that apply")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    optionCell(
                        index: index,
                        option: option,
                        correctIndices: correctIndices
                    )
                }
            }

            if !hasChecked {
                QuizActionButton(
                    title: "Check",
                    state: selected.isEmpty ? .disabled : .ready
                ) {
                    triggerHaptic(allCorrect: allCorrect)
                    hasChecked = true
                    onAnswer(allCorrect)
                }
            }

            if isShowingFeedback {
                QuestionFeedbackCard(
                    isCorrect: allCorrect,
                    explanation: question.explanation
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selected)
        .animation(.easeInOut(duration: 0.3), value: hasChecked)
        .animation(.easeInOut(duration: 0.3), value: isShowingFeedback)
    }

    @ViewBuilder
    private func optionCell(index: Int, option: String, correctIndices: Set<Int>) -> some View {
        let state = cellState(index: index, correctIndices: correctIndices)

        Button {
            guard !hasChecked else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if selected.contains(index) {
                selected.remove(index)
            } else {
                selected.insert(index)
            }
        } label: {
            HStack(spacing: 14) {
                checkboxView(state: state)

                Text(option)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(textColor(state: state))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor(state: state))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor(state: state), style: borderStyle(state: state))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(hasChecked)
    }

    @ViewBuilder
    private func checkboxView(state: CellState) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor(state: state), lineWidth: 2)
                .frame(width: 26, height: 26)

            switch state {
            case .selected, .correctPicked:
                RoundedRectangle(cornerRadius: 6)
                    .fill(borderColor(state: state))
                    .frame(width: 26, height: 26)
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            case .wrongPicked:
                RoundedRectangle(cornerRadius: 6)
                    .fill(QuizPalette.wrongBorder)
                    .frame(width: 26, height: 26)
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            case .missedCorrect, .idle:
                EmptyView()
            }
        }
    }

    // MARK: - Cell state

    private enum CellState {
        case idle
        case selected
        case correctPicked      // user picked, correct answer
        case wrongPicked        // user picked, wrong answer
        case missedCorrect      // user didn't pick, was correct
    }

    private func cellState(index: Int, correctIndices: Set<Int>) -> CellState {
        let isSelected = selected.contains(index)
        let isCorrect = correctIndices.contains(index)

        if !hasChecked {
            return isSelected ? .selected : .idle
        }

        switch (isSelected, isCorrect) {
        case (true, true):  return .correctPicked
        case (true, false): return .wrongPicked
        case (false, true): return .missedCorrect
        case (false, false): return .idle
        }
    }

    private func backgroundColor(state: CellState) -> Color {
        switch state {
        case .idle: return QuizPalette.idleBg
        case .selected: return QuizPalette.selectedBg
        case .correctPicked: return QuizPalette.correctBg
        case .wrongPicked: return QuizPalette.wrongBg
        case .missedCorrect: return QuizPalette.missedBg
        }
    }

    private func textColor(state: CellState) -> Color {
        switch state {
        case .idle: return QuizPalette.idleText
        case .selected: return QuizPalette.selectedText
        case .correctPicked: return QuizPalette.correctText
        case .wrongPicked: return QuizPalette.wrongText
        case .missedCorrect: return QuizPalette.missedText
        }
    }

    private func borderColor(state: CellState) -> Color {
        switch state {
        case .idle: return QuizPalette.idleBorder
        case .selected: return QuizPalette.selectedBorder
        case .correctPicked: return QuizPalette.correctBorder
        case .wrongPicked: return QuizPalette.wrongBorder
        case .missedCorrect: return QuizPalette.missedBorder
        }
    }

    private func borderStyle(state: CellState) -> StrokeStyle {
        switch state {
        case .missedCorrect:
            return StrokeStyle(lineWidth: 2, dash: [5, 4])
        case .selected, .correctPicked, .wrongPicked:
            return StrokeStyle(lineWidth: 2.5)
        case .idle:
            return StrokeStyle(lineWidth: 1)
        }
    }

    private func triggerHaptic(allCorrect: Bool) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(allCorrect ? .success : .error)
    }
}
