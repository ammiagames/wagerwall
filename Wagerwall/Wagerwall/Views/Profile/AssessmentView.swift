import SwiftUI
import Supabase

struct AssessmentView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.userProfileRepository) private var profileRepo
    @Environment(\.dismiss) private var dismiss

    let assessment = Assessment.load()

    @State private var answers: [Int: Int] = [:]
    @State private var isSaving = false
    @State private var showResult = false
    @State private var savedSeverity: GamblingSeverity?

    private var assessmentScore: Int {
        answers.values.reduce(0, +)
    }

    private var allAnswered: Bool {
        answers.count == assessment.questions.count
    }

    var body: some View {
        Group {
            if showResult, let severity = savedSeverity {
                resultView(severity: severity)
            } else {
                questionView
            }
        }
        .navigationTitle("Self-Assessment")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Questions

    @ViewBuilder
    private var questionView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(assessment.title)
                            .font(.title2.bold())

                        Text(assessment.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    ForEach(assessment.questions) { question in
                        questionCard(question)
                    }

                    HStack {
                        Text("\(answers.count) of \(assessment.questions.count) answered")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }
            }

            WagerWallButton(
                title: isSaving ? "Saving..." : "Submit",
                isLoading: isSaving,
                isDisabled: !allAnswered,
                action: { Task { await submit() } }
            )
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func questionCard(_ question: AssessmentQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(question.id). \(question.text)")
                .font(.subheadline.weight(.medium))

            VStack(spacing: 8) {
                ForEach(Array(assessment.options.enumerated()), id: \.offset) { _, option in
                    Button {
                        answers[question.id] = option.score
                    } label: {
                        HStack {
                            Text(option.label)
                                .font(.subheadline)
                            Spacer()
                            if answers[question.id] == option.score {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(answers[question.id] == option.score ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Result

    @ViewBuilder
    private func resultView(severity: GamblingSeverity) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("Assessment Complete")
                    .font(.title2.bold())

                VStack(spacing: 8) {
                    Text("Your Result")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(assessment.severityLabel(for: assessmentScore))
                        .font(.title3.weight(.semibold))

                    Text("Score: \(assessmentScore) / \(assessment.questions.count * (assessment.options.map(\.score).max() ?? 3))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
            }

            Spacer()

            WagerWallButton(title: "Done") {
                dismiss()
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Submit

    private func submit() async {
        guard let userId = auth.currentUserId else { return }
        isSaving = true

        let severity = assessment.severity(for: assessmentScore)
        let update = UserProfileUpdate(
            gamblingSeverity: severity,
            assessmentScore: assessmentScore
        )

        _ = try? await profileRepo.updateProfile(userId: userId, update: update)
        savedSeverity = severity
        isSaving = false
        withAnimation { showResult = true }
    }
}
