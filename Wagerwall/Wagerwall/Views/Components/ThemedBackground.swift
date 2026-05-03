import SwiftUI

/// Applies the WagerWall dark-purple background + wave decoration behind any view.
///
/// Use this on views that get pushed into a `NavigationStack` (e.g. lessons, quizzes,
/// module detail). The root tab views already have this layout via `MainTabView.tabPage`,
/// but pushed views replace the visible content and lose the underlying background —
/// applying this modifier restores it.
struct ThemedBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()
            WaveDecoration()
                .allowsHitTesting(false)
            content
                .scrollContentBackground(.hidden)
        }
    }
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }
}
