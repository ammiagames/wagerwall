import SwiftUI

struct ScreenTimeAuthStepView: View {
    var isCompleting: Bool = false
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "hourglass.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)

                Text("Screen Time Access")
                    .font(.title2.bold())

                Text("WagerWall uses Screen Time to block gambling apps on your device.\n\nThis feature requires a special Apple entitlement that is currently pending approval.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                CardView {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("App blocking will be enabled in a future update. You can continue setting up your account now.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            WagerWallButton(
                title: isCompleting ? "Setting up..." : "Start My Journey",
                isLoading: isCompleting,
                action: onContinue
            )
            .padding(.bottom, 32)
        }
    }
}
