import SwiftUI

struct MatchingView: View {
    let question: Question
    let isShowingFeedback: Bool
    let onAnswer: (Bool) -> Void

    // MARK: - Selection

    private enum Side { case left, right }

    private struct Selection: Equatable {
        let side: Side
        let index: Int
    }

    // MARK: - State

    @State private var leftItems: [String] = []
    @State private var rightSlots: [String] = []
    @State private var matchedLefts: Set<Int> = []     // left indices that are matched
    @State private var matchedRights: Set<Int> = []    // right indices that are matched
    @State private var selection: Selection? = nil
    @State private var wrongAttemptCount = 0
    @State private var showErrorPopup = false
    @State private var hadMistake = false
    @State private var hasReported = false
    @State private var flashCorrectLeft: Int? = nil    // brief green flash
    @State private var flashCorrectRight: Int? = nil

    private let popupThreshold = 2

    private var pairs: [Question.Pair] {
        if case .matching(let pairs) = question.payload { return pairs }
        return []
    }

    private var pairMap: [String: String] {
        Dictionary(uniqueKeysWithValues: pairs.map { ($0.left, $0.right) })
    }

    private var allCorrect: Bool {
        let total = pairs.count
        return total > 0 && matchedLefts.count >= total
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 24) {
                // Prompt
                Text(question.prompt)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(.purple.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                // Matching rows
                VStack(spacing: 14) {
                    ForEach(Array(leftItems.enumerated()), id: \.offset) { i, left in
                        let right = i < rightSlots.count ? rightSlots[i] : ""

                        HStack(spacing: 12) {
                            MatchCell(
                                text: left,
                                state: leftState(row: i)
                            ) {
                                tapCell(side: .left, index: i)
                            }

                            MatchCell(
                                text: right,
                                state: rightState(row: i)
                            ) {
                                tapCell(side: .right, index: i)
                            }
                        }
                    }
                }

                // Inline error button (after popup threshold)
                if wrongAttemptCount > popupThreshold && !showErrorPopup && !allCorrect && !isShowingFeedback {
                    Button {
                        selection = nil
                    } label: {
                        Text("Not quite, let's keep trying")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.red.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }

                // Success feedback
                if isShowingFeedback && allCorrect {
                    successFeedback
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 0)
            }

            // Error popup overlay
            if showErrorPopup {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { showErrorPopup = false }

                errorPopup
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showErrorPopup)
        .animation(.easeInOut(duration: 0.3), value: matchedLefts.count)
        .animation(.easeInOut(duration: 0.2), value: selection)
        .animation(.easeInOut(duration: 0.3), value: isShowingFeedback)
        .onAppear(perform: setup)
    }

    // MARK: - Setup

    private func setup() {
        let activePairs = pairs
        leftItems = activePairs.map(\.left)

        // Shuffle right items; ensure none start in their correct position
        let correct = activePairs.map(\.right)
        var shuffled = correct.shuffled()
        if activePairs.count > 1 {
            while zip(correct, shuffled).contains(where: { $0 == $1 }) {
                shuffled.shuffle()
            }
        }
        rightSlots = shuffled
    }

    // MARK: - Cell States

    private func leftState(row: Int) -> MatchCellState {
        if flashCorrectLeft == row { return .flashCorrect }
        if matchedLefts.contains(row) { return .matched }
        if let sel = selection, sel.side == .left, sel.index == row { return .selected }
        return .idle
    }

    private func rightState(row: Int) -> MatchCellState {
        if flashCorrectRight == row { return .flashCorrect }
        if matchedRights.contains(row) { return .matched }
        if let sel = selection, sel.side == .right, sel.index == row { return .selected }
        return .idle
    }

    // MARK: - Tap Handler

    private func tapCell(side: Side, index: Int) {
        // Ignore matched cells and blocked state
        let isMatched = (side == .left) ? matchedLefts.contains(index) : matchedRights.contains(index)
        guard !isMatched, !showErrorPopup else { return }

        guard let current = selection else {
            selection = Selection(side: side, index: index)
            return
        }

        if current.side == side {
            // Same side — toggle or switch
            selection = (current.index == index) ? nil : Selection(side: side, index: index)
            return
        }

        // Opposite side — attempt match
        let leftIdx = (side == .left) ? index : current.index
        let rightIdx = (side == .right) ? index : current.index

        let left = leftItems[leftIdx]
        let right = rightSlots[rightIdx]

        if right == pairMap[left] {
            // Correct — flash green, then fade to matched
            selection = nil
            flashCorrectLeft = leftIdx
            flashCorrectRight = rightIdx

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    flashCorrectLeft = nil
                    flashCorrectRight = nil
                    matchedLefts.insert(leftIdx)
                    matchedRights.insert(rightIdx)
                }

                // Check completion
                let total = pairs.count
                if matchedLefts.count >= total && !hasReported {
                    hasReported = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        onAnswer(!hadMistake)
                    }
                }
            }
        } else {
            // Wrong
            hadMistake = true
            wrongAttemptCount += 1
            selection = nil

            if wrongAttemptCount <= popupThreshold {
                showErrorPopup = true
            }
        }
    }

    // MARK: - Error Popup

    private var errorPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Not quite right")
                .font(.headline)

            Text("That's not the correct match. Take another look at the concepts and try again. Learning happens through practice!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showErrorPopup = false
            } label: {
                Text("Keep Trying")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Success Feedback

    private var successFeedback: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: hadMistake ? "info.circle.fill" : "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(hadMistake ? .orange : .green)

            VStack(alignment: .leading, spacing: 4) {
                Text(hadMistake ? "All matched!" : "Perfect matching!")
                    .font(.subheadline.bold())
                    .foregroundStyle(hadMistake ? .orange : .green)

                Text(question.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((hadMistake ? Color.orange : Color.green).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Match Cell

private enum MatchCellState {
    case idle          // light pink, interactive
    case selected      // purple highlight
    case flashCorrect  // brief bright green flash
    case matched       // faded/dimmed, non-interactive
}

private struct MatchCell: View {
    let text: String
    let state: MatchCellState
    let onTap: () -> Void

    // Light pink/lavender cells
    private static let idleBg = Color(red: 0.96, green: 0.91, blue: 0.96)
    private static let idleText = Color(red: 0.25, green: 0.10, blue: 0.30)
    private static let idleBorder = Color(red: 0.88, green: 0.82, blue: 0.90)

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .foregroundStyle(foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, minHeight: 70)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(border, lineWidth: borderWidth)
                )
                .opacity(state == .matched ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(state == .matched || state == .flashCorrect)
    }

    private var foreground: Color {
        switch state {
        case .idle: Self.idleText
        case .selected: Color(red: 0.45, green: 0.20, blue: 0.60)
        case .flashCorrect: Color(red: 0.15, green: 0.50, blue: 0.25)
        case .matched: Self.idleText
        }
    }

    private var background: Color {
        switch state {
        case .idle: Self.idleBg
        case .selected: Color(red: 0.92, green: 0.85, blue: 0.96)
        case .flashCorrect: Color(red: 0.80, green: 0.95, blue: 0.82)
        case .matched: Self.idleBg
        }
    }

    private var border: Color {
        switch state {
        case .idle: Self.idleBorder
        case .selected: Color(red: 0.55, green: 0.30, blue: 0.70)
        case .flashCorrect: Color(red: 0.30, green: 0.70, blue: 0.40)
        case .matched: Self.idleBorder
        }
    }

    private var borderWidth: CGFloat {
        switch state {
        case .idle, .matched: 1
        case .selected, .flashCorrect: 2.5
        }
    }
}
