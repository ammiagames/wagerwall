import SwiftUI

/// Renders a `Question.Payload.fillInBlank` in either `freeType` (inline
/// `TextField` blanks) or `wordBank` (tap chips into blanks). Blanks are
/// marked in the template with three underscores: `"The ___ fallacy"`.
///
/// Validation is case-insensitive and trims whitespace. A blank is correct
/// if the user's answer matches any string in `acceptedAnswers[blankIndex]`.
/// The question is correct only if every blank is correct.
struct FillInBlankView: View {
    let question: Question
    let isShowingFeedback: Bool
    let onAnswer: (Bool) -> Void

    @State private var freeAnswers: [String] = []
    @State private var bankFills: [String?] = []        // word placed into each blank
    @State private var bankUsedIndices: Set<Int> = []   // which words from the bank are placed
    @State private var hasChecked = false

    var body: some View {
        guard case .fillInBlank(let template, let acceptedAnswers, let mode) = question.payload else {
            return AnyView(
                Text("Unsupported payload for FillInBlankView")
                    .foregroundStyle(.secondary)
            )
        }
        return AnyView(content(template: template, acceptedAnswers: acceptedAnswers, mode: mode))
    }

    private func content(template: String, acceptedAnswers: [[String]], mode: FillInBlankMode) -> some View {
        let tokens = Self.tokenize(template: template)
        let blankCount = max(0, template.components(separatedBy: "___").count - 1)
        let allCorrect = isAllCorrect(acceptedAnswers: acceptedAnswers, mode: mode)
        let canCheck = canSubmit(blankCount: blankCount, mode: mode)

        return VStack(spacing: 18) {
            QuestionPromptHeader(prompt: question.prompt)

            QuizFlowLayout(horizontalSpacing: 4, verticalSpacing: 10) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                    tokenView(token: token, mode: mode, acceptedAnswers: acceptedAnswers)
                }
            }
            .padding(.horizontal, 4)

            if case .wordBank(let words) = mode {
                wordBankView(words: words)
            }

            if !hasChecked {
                QuizActionButton(
                    title: "Check",
                    state: canCheck ? .ready : .disabled
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
        .onAppear {
            if freeAnswers.count != blankCount {
                freeAnswers = Array(repeating: "", count: blankCount)
            }
            if bankFills.count != blankCount {
                bankFills = Array(repeating: nil, count: blankCount)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: bankFills)
        .animation(.easeInOut(duration: 0.3), value: hasChecked)
        .animation(.easeInOut(duration: 0.3), value: isShowingFeedback)
    }

    // MARK: - Token rendering

    @ViewBuilder
    private func tokenView(token: Token, mode: FillInBlankMode, acceptedAnswers: [[String]]) -> some View {
        switch token {
        case .text(let word):
            Text(word)
                .font(.body)
                .foregroundStyle(.primary)
        case .blank(let blankIndex):
            switch mode {
            case .freeType:
                freeBlank(blankIndex: blankIndex, acceptedAnswers: acceptedAnswers)
            case .wordBank:
                wordBankBlank(blankIndex: blankIndex, acceptedAnswers: acceptedAnswers)
            }
        }
    }

    private func freeBlank(blankIndex: Int, acceptedAnswers: [[String]]) -> some View {
        let state = freeBlankState(blankIndex: blankIndex, acceptedAnswers: acceptedAnswers)
        let binding = Binding<String>(
            get: { freeAnswers.indices.contains(blankIndex) ? freeAnswers[blankIndex] : "" },
            set: { newValue in
                guard freeAnswers.indices.contains(blankIndex) else { return }
                freeAnswers[blankIndex] = newValue
            }
        )

        return TextField("", text: binding)
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .autocorrectionDisabled()
            .foregroundStyle(textColor(state: state))
            .frame(minWidth: 90, maxWidth: 220)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(backgroundColor(state: state))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor(state: state), lineWidth: borderWidth(state: state))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(hasChecked)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func wordBankBlank(blankIndex: Int, acceptedAnswers: [[String]]) -> some View {
        let state = wordBankBlankState(blankIndex: blankIndex, acceptedAnswers: acceptedAnswers)
        let filled = bankFills.indices.contains(blankIndex) ? bankFills[blankIndex] : nil

        return Button {
            guard !hasChecked, let word = filled else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            ejectWord(word: word, fromBlank: blankIndex)
        } label: {
            wordBankBlankLabel(filled: filled, state: state)
        }
        .buttonStyle(.plain)
        .disabled(hasChecked || filled == nil)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func wordBankBlankLabel(filled: String?, state: BlankState) -> some View {
        let isEmpty = filled == nil
        let bg: Color = isEmpty ? QuizPalette.idleBg : backgroundColor(state: state)
        let stroke: Color = isEmpty ? QuizPalette.idleBorder : borderColor(state: state)
        let style: StrokeStyle = isEmpty
            ? StrokeStyle(lineWidth: 1.5, dash: [4, 3])
            : StrokeStyle(lineWidth: borderWidth(state: state))
        let fg: Color = isEmpty ? Color.secondary : textColor(state: state)

        return Text(filled ?? "____")
            .font(.body.weight(.semibold))
            .foregroundStyle(fg)
            .frame(minWidth: 84)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bg)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(stroke, style: style)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Word bank pool

    private func wordBankView(words: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tap a word to fill the next blank")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            QuizFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(Array(words.enumerated()), id: \.offset) { idx, word in
                    wordBankChip(word: word, bankIndex: idx)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func wordBankChip(word: String, bankIndex: Int) -> some View {
        let isUsed = bankUsedIndices.contains(bankIndex)

        return Button {
            guard !hasChecked, !isUsed else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            placeWord(word: word, bankIndex: bankIndex)
        } label: {
            chipLabel(word: word, isUsed: isUsed)
        }
        .buttonStyle(.plain)
        .disabled(hasChecked || isUsed)
    }

    private func chipLabel(word: String, isUsed: Bool) -> some View {
        let fg: Color = isUsed ? Color.secondary : QuizPalette.idleText
        let bg: Color = isUsed ? Color.secondary.opacity(0.08) : QuizPalette.idleBg
        let strokeColor: Color = isUsed ? Color.clear : QuizPalette.idleBorder

        return Text(word)
            .font(.body.weight(.semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bg)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(strokeColor, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(isUsed ? 0.45 : 1)
    }

    // MARK: - Mutations

    private func placeWord(word: String, bankIndex: Int) {
        guard let emptyIdx = bankFills.firstIndex(where: { $0 == nil }) else { return }
        bankFills[emptyIdx] = word
        bankUsedIndices.insert(bankIndex)
    }

    private func ejectWord(word: String, fromBlank blankIdx: Int) {
        guard bankFills.indices.contains(blankIdx) else { return }
        bankFills[blankIdx] = nil

        // Free the first matching bank slot containing this word.
        guard case .fillInBlank(_, _, .wordBank(let words)) = question.payload else { return }
        for idx in words.indices where bankUsedIndices.contains(idx) && words[idx] == word {
            bankUsedIndices.remove(idx)
            return
        }
    }

    // MARK: - Validation

    private func isAllCorrect(acceptedAnswers: [[String]], mode: FillInBlankMode) -> Bool {
        guard !acceptedAnswers.isEmpty else { return false }

        for i in 0..<acceptedAnswers.count {
            let userAnswer = answer(forBlank: i, mode: mode)
            let normalized = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let accepted = acceptedAnswers[i].map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            if !accepted.contains(normalized) { return false }
        }
        return true
    }

    private func canSubmit(blankCount: Int, mode: FillInBlankMode) -> Bool {
        switch mode {
        case .freeType:
            return freeAnswers.count == blankCount
                && freeAnswers.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        case .wordBank:
            return bankFills.count == blankCount && bankFills.allSatisfy { $0 != nil }
        }
    }

    private func answer(forBlank index: Int, mode: FillInBlankMode) -> String {
        switch mode {
        case .freeType:
            return freeAnswers.indices.contains(index) ? freeAnswers[index] : ""
        case .wordBank:
            return (bankFills.indices.contains(index) ? bankFills[index] : nil) ?? ""
        }
    }

    // MARK: - Cell state

    private enum BlankState { case idle, selected, correct, wrong }

    private func freeBlankState(blankIndex: Int, acceptedAnswers: [[String]]) -> BlankState {
        if !hasChecked {
            let text = freeAnswers.indices.contains(blankIndex) ? freeAnswers[blankIndex] : ""
            return text.isEmpty ? .idle : .selected
        }
        return blankIsCorrect(blankIndex: blankIndex, acceptedAnswers: acceptedAnswers, mode: .freeType)
            ? .correct : .wrong
    }

    private func wordBankBlankState(blankIndex: Int, acceptedAnswers: [[String]]) -> BlankState {
        if !hasChecked {
            let filled = bankFills.indices.contains(blankIndex) ? bankFills[blankIndex] : nil
            return filled == nil ? .idle : .selected
        }
        let mode: FillInBlankMode = {
            if case .fillInBlank(_, _, let m) = question.payload { return m }
            return .freeType
        }()
        return blankIsCorrect(blankIndex: blankIndex, acceptedAnswers: acceptedAnswers, mode: mode)
            ? .correct : .wrong
    }

    private func blankIsCorrect(blankIndex: Int, acceptedAnswers: [[String]], mode: FillInBlankMode) -> Bool {
        guard acceptedAnswers.indices.contains(blankIndex) else { return false }
        let userAnswer = answer(forBlank: blankIndex, mode: mode)
        let normalized = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let accepted = acceptedAnswers[blankIndex].map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        return accepted.contains(normalized)
    }

    // MARK: - Style helpers

    private func backgroundColor(state: BlankState) -> Color {
        switch state {
        case .idle: return QuizPalette.idleBg
        case .selected: return QuizPalette.selectedBg
        case .correct: return QuizPalette.correctBg
        case .wrong: return QuizPalette.wrongBg
        }
    }

    private func textColor(state: BlankState) -> Color {
        switch state {
        case .idle: return QuizPalette.idleText
        case .selected: return QuizPalette.selectedText
        case .correct: return QuizPalette.correctText
        case .wrong: return QuizPalette.wrongText
        }
    }

    private func borderColor(state: BlankState) -> Color {
        switch state {
        case .idle: return QuizPalette.idleBorder
        case .selected: return QuizPalette.selectedBorder
        case .correct: return QuizPalette.correctBorder
        case .wrong: return QuizPalette.wrongBorder
        }
    }

    private func borderWidth(state: BlankState) -> CGFloat {
        switch state {
        case .idle: return 1.5
        case .selected, .correct, .wrong: return 2.5
        }
    }

    private func triggerHaptic(allCorrect: Bool) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(allCorrect ? .success : .error)
    }

    // MARK: - Tokenization

    fileprivate enum Token {
        case text(String)
        case blank(Int)
    }

    fileprivate static func tokenize(template: String) -> [Token] {
        let segments = template.components(separatedBy: "___")
        var tokens: [Token] = []
        for (i, seg) in segments.enumerated() {
            // Splitting into words lets the flow layout wrap mid-line.
            let words = seg.split(separator: " ", omittingEmptySubsequences: true)
            for word in words {
                tokens.append(.text(String(word)))
            }
            if i < segments.count - 1 {
                tokens.append(.blank(i))
            }
        }
        return tokens
    }
}
