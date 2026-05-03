import SwiftUI
import Supabase

struct PanicButtonView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.urgeLogRepository) private var urgeRepo
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = PanicButtonViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.currentStep {
                case .breathing:
                    BreathingExerciseView {
                        withAnimation { viewModel.advance() }
                    }
                case .motivation:
                    MotivationalCardView {
                        withAnimation { viewModel.advance() }
                    }
                case .outcome:
                    outcomeView
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var outcomeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("How did it go?")
                .font(.title2.bold())

            VStack(spacing: 12) {
                OutcomeButton(
                    icon: "hand.thumbsup.fill",
                    label: "I resisted the urge",
                    color: .green,
                    isSelected: viewModel.outcome == .resisted
                ) {
                    viewModel.outcome = .resisted
                }

                OutcomeButton(
                    icon: "exclamationmark.triangle.fill",
                    label: "I gave in",
                    color: .red,
                    isSelected: viewModel.outcome == .gaveIn
                ) {
                    viewModel.outcome = .gaveIn
                }
            }
            .padding(.horizontal, 24)

            if viewModel.outcome == .resisted {
                Text("Amazing! You showed real strength.")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else if viewModel.outcome == .gaveIn {
                Text("It's okay. Recovery isn't linear. What matters is you're here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            WagerWallButton(
                title: "Done",
                isLoading: viewModel.isSaving
            ) {
                Task {
                    guard let userId = auth.currentUserId else { return }
                    await viewModel.logAndComplete(userId: userId, urgeRepo: urgeRepo)
                    if viewModel.isComplete {
                        dismiss()
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .navigationTitle("How Did It Go?")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Outcome Button

private struct OutcomeButton: View {
    let icon: String
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(label)
                    .font(.body.weight(.medium))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(16)
            .background(isSelected ? color.opacity(0.1) : Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
