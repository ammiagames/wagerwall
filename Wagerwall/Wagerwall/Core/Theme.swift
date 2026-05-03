import SwiftUI

enum Theme {
    // App background
    static let background = Color(red: 0.09, green: 0.04, blue: 0.15)

    // Wave circle colors — very subtle, barely above background
    static let waveLeft = Color(red: 0.11, green: 0.07, blue: 0.22)
    static let waveCenter = Color(red: 0.13, green: 0.09, blue: 0.26)
    static let waveRight = Color(red: 0.15, green: 0.07, blue: 0.24)

    // Hero card gradient
    static let heroStart = Color(red: 0.22, green: 0.10, blue: 0.38)
    static let heroEnd = Color(red: 0.12, green: 0.06, blue: 0.22)

    // Standard card — near-black with a faint purple tint
    static let cardStart = Color(red: 0.11, green: 0.09, blue: 0.14)
    static let cardEnd = Color(red: 0.08, green: 0.06, blue: 0.11)

    // Tab bar tint (selected tab color)
    static let tabActive = Color(red: 0.75, green: 0.65, blue: 0.90)
}
