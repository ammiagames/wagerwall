import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.rootScreen {
        case .loading:
            ProgressView()
        case .signIn:
            SignInView()
        case .onboarding:
            OnboardingContainerView()
        case .main:
            MainTabView()
        }
    }
}
