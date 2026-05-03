import SwiftUI
import Supabase

struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthService.self) private var auth
    @Environment(\.userProfileRepository) private var profileRepo

    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar (hidden on welcome)
            if viewModel.currentStep != .welcome {
                HStack {
                    Button {
                        withAnimation { viewModel.goBack() }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.leading, 24)

                    ProgressStepIndicator(
                        currentStep: viewModel.currentStepIndex,
                        totalSteps: viewModel.totalSteps
                    )

                    // Spacer to balance the back button
                    Color.clear.frame(width: 40)
                }
                .padding(.top, 8)
            }

            // Step content
            Group {
                switch viewModel.currentStep {
                case .welcome:
                    WelcomeStepView {
                        withAnimation { viewModel.advance() }
                    }

                case .screenTime:
                    ScreenTimeAuthStepView(isCompleting: viewModel.isCompleting) {
                        Task {
                            guard let userId = auth.currentUserId else { return }
                            await viewModel.completeOnboarding(
                                userId: userId,
                                profileRepo: profileRepo,
                                appState: appState
                            )
                        }
                    }
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
    }
}
