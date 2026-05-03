import SwiftUI

/// Three large overlapping circles at the bottom — extend behind the tab bar.
struct WaveDecoration: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let d = w * 0.80

            ZStack {
                // Left circle
                Circle()
                    .fill(Theme.waveLeft)
                    .frame(width: d, height: d)
                    .position(x: w * 0.15, y: h + d * 0.29)

                // Center circle — slightly larger
                Circle()
                    .fill(Theme.waveCenter)
                    .frame(width: d * 1.05, height: d * 1.05)
                    .position(x: w * 0.50, y: h + d * 0.32)

                // Right circle
                Circle()
                    .fill(Theme.waveRight)
                    .frame(width: d * 0.92, height: d * 0.92)
                    .position(x: w * 0.86, y: h + d * 0.27)
            }
        }
        .frame(height: 90)
        // No .clipped() — let circles render below the frame into the tab bar area
        .ignoresSafeArea(edges: .bottom)
    }
}
