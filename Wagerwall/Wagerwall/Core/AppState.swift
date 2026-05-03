import Foundation
import Supabase

enum RootScreen {
    case loading
    case signIn
    case onboarding
    case main
}

@Observable
final class AppState {
    var rootScreen: RootScreen = .loading
    private var hasStarted = false

    private let auth: AuthService
    private let profileRepo: any UserProfileRepository

    init(auth: AuthService, profileRepo: any UserProfileRepository = SupabaseUserProfileRepository()) {
        self.auth = auth
        self.profileRepo = profileRepo
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        // TODO: Re-enable auth flow when sign-in is ready
        // Skip auth — go straight to main app
        rootScreen = .main
    }

    private func resolveRoute(userId: UUID) async {
        do {
            let profile = try await profileRepo.fetchProfile(userId: userId)
            rootScreen = (profile.onboardingCompleted == true) ? .main : .onboarding
        } catch {
            // Profile fetch failed (e.g. new user, profile not yet created by trigger) — go to onboarding
            rootScreen = .onboarding
        }
    }

    func completeOnboarding() {
        rootScreen = .main
    }

    func didSignOut() {
        rootScreen = .signIn
    }
}
