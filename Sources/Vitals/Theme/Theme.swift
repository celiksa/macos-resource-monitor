import SwiftUI

/// Central design tokens: palette, per-metric accent gradients, typography, spacing.
/// The app is dark-first with translucent surfaces and glowing gradient graphs.
enum Theme {
    // MARK: Surfaces
    static let bg = Color(hex: 0x0C1018)
    static let bgElevated = Color(hex: 0x111722)
    static let card = Color(hex: 0x151C28)
    static let cardStroke = Color.white.opacity(0.08)
    static let hair = Color.white.opacity(0.06)

    // MARK: Text
    static let text = Color.white.opacity(0.95)
    static let textSecondary = Color(hex: 0xA6B2C5)
    static let textTertiary = Color(hex: 0x8391A7)

    // MARK: Spacing / shape
    static let corner: CGFloat = 18
    static let cardPadding: CGFloat = 20
    static let gap: CGFloat = 16

    // MARK: Typography
    static func number(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func label(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

/// A metric's accent: a start/end color used for gradients, glows, and the sidebar dot.
struct Accent {
    let start: Color
    let end: Color

    var gradient: LinearGradient {
        LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    var horizontal: LinearGradient {
        LinearGradient(colors: [start, end], startPoint: .leading, endPoint: .trailing)
    }
    var solid: Color { end }
    /// Soft glow color for shadows under graphs.
    var glow: Color { end.opacity(0.55) }
}

extension Metric {
    var accent: Accent {
        switch self {
        case .overview: return Accent(start: Color(hex: 0x9DCAFF), end: Color(hex: 0x73A9FF))
        case .battery: return Accent(start: Color(hex: 0xA0EAA7), end: Color(hex: 0x5CD69B))
        case .processes: return Accent(start: Color(hex: 0xAEBFFD), end: Color(hex: 0x8B9DEC))
        case .cpu:     return Accent(start: Color(hex: 0x3AC6FF), end: Color(hex: 0x2E7BFF)) // cyan → blue
        case .gpu:     return Accent(start: Color(hex: 0xBFADFF), end: Color(hex: 0x9A80FF)) // purple → magenta
        case .memory:  return Accent(start: Color(hex: 0x6EEBC1), end: Color(hex: 0x43CCA1)) // mint → green
        case .thermal: return Accent(start: Color(hex: 0xFFC24B), end: Color(hex: 0xFF5A3C)) // amber → red
        case .network: return Accent(start: Color(hex: 0x36F0E0), end: Color(hex: 0x1FA9C6)) // teal
        case .disk:    return Accent(start: Color(hex: 0xFFD34E), end: Color(hex: 0xFF9E2C)) // gold
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// Blend from green→amber→red for temperature/utilization heat coloring.
    static func heat(_ t: Double) -> Color {
        let x = t.clamped(0, 1)
        if x < 0.5 {
            // green → amber
            let k = x / 0.5
            return Color(red: 0.2 + 0.8 * k, green: 0.8, blue: 0.3 * (1 - k))
        } else {
            // amber → red
            let k = (x - 0.5) / 0.5
            return Color(red: 1.0, green: 0.8 - 0.7 * k, blue: 0.05)
        }
    }
}

extension CPUCluster {
    var accent: Accent {
        switch name.lowercased() {
        case "super": return Metric.gpu.accent
        case "efficiency": return Metric.memory.accent
        default: return Metric.cpu.accent
        }
    }
}
