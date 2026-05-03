import SwiftUI

struct DisableRequestStatusView: View {
    let request: DisableRequest
    let onCancel: () -> Void

    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Protection Disable Request")
                        .font(.subheadline.weight(.medium))

                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Countdown
            if timeRemaining > 0 {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Time remaining: \(formattedTimeRemaining)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            // Partner approval status
            HStack {
                Image(systemName: request.partnerApproved ? "checkmark.circle.fill" : "clock")
                    .font(.caption)
                    .foregroundStyle(request.partnerApproved ? .green : .orange)
                Text(request.partnerApproved ? "Partner approved" : "Waiting for partner approval")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Cancel button
            Button(role: .destructive) {
                onCancel()
            } label: {
                Text("Cancel Request")
                    .font(.caption.weight(.medium))
            }
            .padding(.top, 4)
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private var statusIcon: String {
        switch request.status {
        case .pending: "hourglass"
        case .approved: "checkmark.shield"
        case .expired: "clock.badge.xmark"
        case .cancelled: "xmark.circle"
        }
    }

    private var statusColor: Color {
        switch request.status {
        case .pending: .orange
        case .approved: .green
        case .expired: .secondary
        case .cancelled: .red
        }
    }

    private var statusLabel: String {
        switch request.status {
        case .pending: "Cooling-off period active"
        case .approved: "Approved — cooling off"
        case .expired: "Request expired"
        case .cancelled: "Request cancelled"
        }
    }

    private var formattedTimeRemaining: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func startTimer() {
        updateTimeRemaining()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateTimeRemaining()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateTimeRemaining() {
        let remaining = request.cooloffEndsAt.timeIntervalSince(Date())
        timeRemaining = max(0, remaining)
        if timeRemaining <= 0 {
            stopTimer()
        }
    }
}
