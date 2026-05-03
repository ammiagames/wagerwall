import SwiftUI

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    var iconColor: Color = .blue
    var subtitle: String? = nil

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(iconColor)

                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(value)
                    .font(.title.bold())

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
