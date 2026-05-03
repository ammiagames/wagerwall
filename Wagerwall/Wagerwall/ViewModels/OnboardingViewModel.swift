import Foundation
import Supabase

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case screenTime
}

@Observable
final class OnboardingViewModel {
    // MARK: - Navigation
    var currentStep: OnboardingStep = .welcome
    var isCompleting = false

    var totalSteps: Int { OnboardingStep.allCases.count }
    var currentStepIndex: Int { currentStep.rawValue }

    func advance() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func goBack() {
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    // MARK: - Completion

    func completeOnboarding(
        userId: UUID,
        profileRepo: any UserProfileRepository,
        appState: AppState
    ) async {
        isCompleting = true
        let update = UserProfileUpdate(onboardingCompleted: true)
        _ = try? await profileRepo.updateProfile(userId: userId, update: update)
        isCompleting = false
        appState.completeOnboarding()
    }
}
