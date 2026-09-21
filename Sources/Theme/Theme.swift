import SwiftUI

/// Exact values from budgets-bro's `src/theme/colors.ts` — this app's whole
/// point is zero UX diff, so the palette is copied, not approximated.
enum Theme {
    static let page = Color(hex: 0x0D0D0D)
    static let surface = Color(hex: 0x1C1C1E)
    static let text = Color(hex: 0xF5F5F5)
    static let textMuted = Color(hex: 0x9B9B9B)
    static let border = Color(hex: 0x2E2E30)
    static let tint = Color(hex: 0x123632)
    static let accent = Color(hex: 0x2DD4BF)
    static let positive = Color(hex: 0x4ADE80)
    static let positiveFaded = Color(hex: 0x4ADE80).opacity(0.2)
    static let positiveTint = Color(hex: 0x132B1C)
    static let negative = Color(hex: 0xF87171)
    static let negativeTint = Color(hex: 0x331616)
    static let amber = Color(hex: 0xFBBF24)
    static let amberTint = Color(hex: 0x332B0F)

    // Legacy alias — same value as `amber`, used where the native app added
    // its own "partial" status not present in the ported 4-state enum.
    static let partial = amber
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
