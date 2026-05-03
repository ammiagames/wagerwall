import SwiftUI

struct WelcomeStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                Text("Welcome to WagerWall")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Block gambling apps and take control of your recovery")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Spacer()
                .frame(height: 40)

            VStack(spacing: 16) {
                FeatureRow(icon: "nosign", title: "Block Gambling Apps", description: "Block gambling apps and websites on your device")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Track Progress", description: "Streaks, mood, and urge logging")
                FeatureRow(icon: "brain.head.profile", title: "Recovery Tools", description: "CBT lessons, journals, and crisis support")
            }
            .padding(.horizontal, 24)

            Spacer()

            WagerWallButton(title: "Get Started", action: onContinue)
                .padding(.bottom, 32)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}
