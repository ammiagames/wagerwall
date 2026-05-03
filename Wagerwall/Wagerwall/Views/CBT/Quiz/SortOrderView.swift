import SwiftUI

/// Renders a `Question.Payload.sortOrder`. Items are presented shuffled;
/// the user drags them into the canonical order (top = first), then taps
/// "Check". Per-row badges flip green/red on reveal so the user can see
/// which positions they got right or wrong.
struct SortOrderView: View {
    let question: Question
    let isShowingFeedback: Bool
    let onAnswer: (Bool) -> Void

    @State private var current: [String] = []
    @State private var canonical: [String] = []
    @State private var hasChecked = false
    @State private var draggingItem: String? = nil

    var body: some View {
        guard case .sortOrder(let items) = question.payload else {
            return AnyView(
                Text("Unsupported payload for SortOrderView")
                    .foregroundStyle(.secondary)
            )
        }
        return AnyView(content(items: items))
    }

    private func content(items: [String]) -> some View {
        let allCorrect = current == canonical

        return VStack(spacing: 18) {
            QuestionPromptHeader(prompt: question.prompt)

            Text("Drag the items into the right order")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                ForEach(Array(current.enumerated()), id: \.element) { index, item in
                    sortRow(item: item, index: index)
                }
            }

            if !hasChecked {
                QuizActionButton(title: "Check", state: .ready) {
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
        .onAppear {
            if canonical.isEmpty {
                canonical = items
                // Shuffle for the user, ensuring not already in correct order if possible.
                var shuffled = items.shuffled()
                if items.count > 1 {
                    var attempts = 0
                    while shuffled == items && attempts < 5 {
                        shuffled.shuffle()
                        attempts += 1
                    }
                }
                current = shuffled
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
        .animation(.easeInOut(duration: 0.3), value: hasChecked)
        .animation(.easeInOut(duration: 0.3), value: isShowingFeedback)
    }

    private func sortRow(item: String, index: Int) -> some View {
        let state = rowState(item: item, index: index)

        return HStack(spacing: 12) {
            badge(index: index + 1, state: state)

            Text(item)
                .font(.body.weight(.semibold))
                .foregroundStyle(textColor(state: state))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Image(systemName: "line.3.horizontal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .opacity(hasChecked ? 0.3 : 0.6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(backgroundColor(state: state))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor(state: state), lineWidth: borderWidth(state: state))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .opacity(draggingItem == item ? 0.6 : 1.0)
        .draggable(item) {
            // Drag preview
            Text(item)
                .font(.body.weight(.semibold))
                .foregroundStyle(QuizPalette.selectedText)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(QuizPalette.selectedBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .dropDestination(for: String.self) { droppedItems, _ in
            guard !hasChecked, let dropped = droppedItems.first else { return false }
            moveItem(dropped, before: item)
            return true
        } isTargeted: { targeting in
            draggingItem = targeting ? item : nil
        }
        .disabled(hasChecked)
    }

    private func badge(index: Int, state: RowState) -> some View {
        ZStack {
            Circle()
                .fill(badgeBackground(state: state))
                .frame(width: 28, height: 28)
            Text("\(index)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(badgeText(state: state))
        }
    }

    // MARK: - Mutations

    private func moveItem(_ item: String, before targetItem: String) {
        guard let from = current.firstIndex(of: item) else { return }
        guard let to = current.firstIndex(of: targetItem) else { return }
        if from == to { return }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        var copy = current
        let moving = copy.remove(at: from)
        let adjustedTo = (from < to) ? to - 1 : to
        copy.insert(moving, at: adjustedTo)
        current = copy
    }

    // MARK: - State

    private enum RowState { case idle, correct, wrong }

    private func rowState(item: String, index: Int) -> RowState {
        if !hasChecked { return .idle }
        guard canonical.indices.contains(index) else { return .wrong }
        return canonical[index] == item ? .correct : .wrong
    }

    private func backgroundColor(state: RowState) -> Color {
        switch state {
        case .idle: return QuizPalette.idleBg
        case .correct: return QuizPalette.correctBg
        case .wrong: return QuizPalette.wrongBg
        }
    }

    private func textColor(state: RowState) -> Color {
        switch state {
        case .idle: return QuizPalette.idleText
        case .correct: return QuizPalette.correctText
        case .wrong: return QuizPalette.wrongText
        }
    }

    private func borderColor(state: RowState) -> Color {
        switch state {
        case .idle: return QuizPalette.idleBorder
        case .correct: return QuizPalette.correctBorder
        case .wrong: return QuizPalette.wrongBorder
        }
    }

    private func borderWidth(state: RowState) -> CGFloat {
        switch state {
        case .idle: return 1
        case .correct, .wrong: return 2.5
        }
    }

    private func badgeBackground(state: RowState) -> Color {
        switch state {
        case .idle: return QuizPalette.selectedBorder
        case .correct: return QuizPalette.correctBorder
        case .wrong: return QuizPalette.wrongBorder
        }
    }

    private func badgeText(state: RowState) -> Color {
        switch state {
        case .idle, .correct, .wrong: return .white
        }
    }

    private func triggerHaptic(allCorrect: Bool) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(allCorrect ? .success : .error)
    }
}
