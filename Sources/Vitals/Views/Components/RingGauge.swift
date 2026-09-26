import SwiftUI

/// A circular progress gauge with a gradient arc, soft glow, and centered value.
struct RingGauge: View {
    let value: Double            // 0...1
    let accent: Accent
    var label: String? = nil
    var centerText: String? = nil
    var lineWidth: CGFloat = 10
    var size: CGFloat = 96

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: CGFloat(value.clamped(0, 1)))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [accent.start, accent.end]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accent.glow, radius: 6)
                    .animation(.easeOut(duration: 0.35), value: value)

                Text(centerText ?? Format.percent(value))
                    .font(Theme.number(size * 0.24, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            .frame(width: size, height: size)

            if let label {
                Text(label)
                    .font(Theme.label(11))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
