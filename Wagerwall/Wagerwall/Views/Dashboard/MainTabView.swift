import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    init() {
        // Force all nav bar states (large title, compact, scrolled) to be transparent
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = appearance

        // Tab bar — transparent so waves show through the glass
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    var body: some View {
        ZStack {
            // Global background behind the entire TabView (including tab bar area)
            Theme.background.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                tabPage { DashboardView() }
                    .tabItem { Label("Home", systemImage: "house") }
                    .tag(0)

                tabPage { CBTModulesView() }
                    .tabItem { Label("Learn", systemImage: "calendar") }
                    .tag(1)

                tabPage { ProgressTabView() }
                    .tabItem { Label("Progress", systemImage: "chart.bar") }
                    .tag(2)

                tabPage { ProfileView() }
                    .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                    .tag(3)
            }
            .tint(Theme.tabActive)
            .toolbarBackground(.hidden, for: .tabBar)
        }
        .preferredColorScheme(.dark)
    }

    private func tabPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 1. Background — fills entire screen including behind nav bar
                Theme.background.ignoresSafeArea()

                // 2. Wave decoration — behind content, at bottom
                WaveDecoration()
                    .allowsHitTesting(false)

                // 3. Content — on top of everything
                content()
                    .scrollContentBackground(.hidden)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
