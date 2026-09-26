import SwiftUI

/// A label/value pair, Task-Manager style.
struct Stat: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var accent: Color? = nil
}

/// A responsive grid of `Stat` pairs.
struct StatGrid: View {
    let stats: [Stat]
    var columns: Int = 2

    private var grid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 24, alignment: .leading), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: grid, alignment: .leading, spacing: 14) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 3) {
                    Text(stat.label)
                        .font(Theme.label(11))
                        .foregroundStyle(Theme.textTertiary)
                        .textCase(.uppercase)
                        .kerning(0.4)
                    Text(stat.value)
                        .font(Theme.number(19, weight: .semibold))
                        .foregroundStyle(stat.accent ?? Theme.text)
                        .contentTransition(.numericText())
                }
            }
        }
    }
}

/// A segmented horizontal bar showing composition (e.g. memory breakdown).
struct CompositionBar: View {
    struct Segment: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
    }
    let segments: [Segment]
    let total: Double
    var height: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(segments) { seg in
                        let sum = segments.reduce(0) { $0 + max(0, $1.value) }
                        let denominator = max(total, sum)
                        let frac = denominator > 0 ? max(0, seg.value) / denominator : 0
                        seg.color
                            .frame(width: max(0, geo.size.width * CGFloat(frac)))
                    }
                    Spacer(minLength: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.05))
            )

            // Legend
            FlowLegend(segments: segments)
        }
    }
}

private struct FlowLegend: View {
    let segments: [CompositionBar.Segment]
    var body: some View {
        HStack(spacing: 16) {
            ForEach(segments) { seg in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(seg.color).frame(width: 9, height: 9)
                    Text(seg.label)
                        .font(Theme.label(11))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
