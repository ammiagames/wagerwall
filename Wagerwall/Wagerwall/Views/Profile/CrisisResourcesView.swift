import SwiftUI

struct CrisisResourcesView: View {
    var body: some View {
        List {
            Section {
                Text("If you or someone you know is struggling with a gambling problem, these resources can help. You are not alone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Helplines") {
                CrisisRow(
                    name: "National Council on Problem Gambling",
                    description: "24/7 confidential helpline",
                    phone: "1-800-522-4700",
                    icon: "phone.fill",
                    color: .green
                )

                CrisisRow(
                    name: "Crisis Text Line",
                    description: "Text GAMBLE to 741741",
                    phone: nil,
                    icon: "message.fill",
                    color: .blue
                )

                CrisisRow(
                    name: "Gamblers Anonymous",
                    description: "Find a meeting near you",
                    phone: "1-626-960-3500",
                    icon: "person.3.fill",
                    color: .purple
                )
            }

            Section("Online Resources") {
                ResourceLink(
                    name: "National Council on Problem Gambling",
                    description: "ncpgambling.org"
                )

                ResourceLink(
                    name: "Gamblers Anonymous",
                    description: "gamblersanonymous.org"
                )

                ResourceLink(
                    name: "SAMHSA National Helpline",
                    description: "1-800-662-4357 (free referrals)"
                )
            }

            Section("Emergency") {
                CrisisRow(
                    name: "National Suicide Prevention Lifeline",
                    description: "24/7 crisis support",
                    phone: "988",
                    icon: "heart.fill",
                    color: .red
                )

                CrisisRow(
                    name: "Emergency Services",
                    description: "Call if in immediate danger",
                    phone: "911",
                    icon: "staroflife.fill",
                    color: .red
                )
            }
        }
        .navigationTitle("Crisis Resources")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Crisis Row

private struct CrisisRow: View {
    let name: String
    let description: String
    let phone: String?
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let phone {
                Button {
                    let cleaned = phone.replacingOccurrences(of: "-", with: "")
                    if let url = URL(string: "tel://\(cleaned)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "phone.arrow.up.right")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .padding(8)
                        .background(.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Resource Link

private struct ResourceLink: View {
    let name: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.subheadline.weight(.medium))
            Text(description)
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 2)
    }
}
