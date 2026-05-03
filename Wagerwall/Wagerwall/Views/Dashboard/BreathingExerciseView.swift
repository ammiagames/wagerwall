import SwiftUI

struct BreathingExerciseView: View {
    let onComplete: () -> Void

    @State private var phase: BreathPhase = .inhale
    @State private var cycleCount: Int = 0
    @State private var circleScale: CGFloat = 0.4
    @State private var isAnimating = false

    private let totalCycles = 3

    enum BreathPhase: String {
        case inhale = "Breathe In"
        case hold = "Hold"
        case exhale = "Breathe Out"

        var duration: Double {
            switch self {
            case .inhale: 4.0
            case .hold: 7.0
            case .exhale: 8.0
            }
        }

        var targetScale: CGFloat {
            switch self {
            case .inhale: 1.0
            case .hold: 1.0
            case .exhale: 0.4
            }
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("4-7-8 Breathing")
                .font(.title2.bold())

            Text("Focus on the circle and follow the rhythm")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Breathing circle
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 240, height: 240)

                Circle()
                    .fill(.blue.opacity(0.25))
                    .frame(width: 240 * circleScale, height: 240 * circleScale)

                VStack(spacing: 4) {
                    Text(phase.rawValue)
                        .font(.title3.bold())
                        .foregroundStyle(.blue)

                    Text("\(Int(phase.duration))s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Cycle indicator
            HStack(spacing: 8) {
                ForEach(0..<totalCycles, id: \.self) { index in
                    Circle()
                        .fill(index < cycleCount ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }

            Text("Cycle \(min(cycleCount + 1, totalCycles)) of \(totalCycles)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if cycleCount >= totalCycles {
                WagerWallButton(title: "Continue") {
                    onComplete()
                }
                .padding(.bottom, 16)
            } else if !isAnimating {
                WagerWallButton(title: "Start Breathing") {
                    startBreathingCycle()
                }
                .padding(.bottom, 16)
            } else {
                // Placeholder to keep layout stable
                Color.clear
                    .frame(height: 82)
            }
        }
        .navigationTitle("Breathing Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startBreathingCycle() {
        isAnimating = true
        runPhase(.inhale)
    }

    private func runPhase(_ currentPhase: BreathPhase) {
        phase = currentPhase

        withAnimation(.easeInOut(duration: currentPhase.duration)) {
            circleScale = currentPhase.targetScale
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + currentPhase.duration) {
            switch currentPhase {
            case .inhale:
                runPhase(.hold)
            case .hold:
                runPhase(.exhale)
            case .exhale:
                cycleCount += 1
                if cycleCount < totalCycles {
                    runPhase(.inhale)
                } else {
                    isAnimating = false
                }
            }
        }
    }
}
