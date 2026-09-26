import SwiftUI

/// Missing samples form gaps. Linear segments preserve observed extrema.
struct Sparkline: View {
    let values: [Double]
    let accent: Accent
    var maxValue: Double? = 1.0
    var showFill = true
    var showGlow = false
    var lineWidth: CGFloat = 2
    var showGrid = true
    var timestamps: [Date] = []

    var body: some View {
        Canvas { context, size in
            let bound = maxValue ?? max((values.filter(\.isFinite).max() ?? 0) * 1.1, 1)
            let height = max(0, size.height - 6)
            if showGrid {
                var grid = Path()
                for i in 0...4 {
                    let y = 3 + height * CGFloat(i) / 4
                    grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(Theme.hair), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
            }
            var segments: [[CGPoint]] = [[]]
            for (i, v) in values.enumerated() {
                guard v.isFinite else { if !(segments.last?.isEmpty ?? true) { segments.append([]) }; continue }
                let fraction: Double
                if timestamps.count == values.count, let first = timestamps.first, let last = timestamps.last, last > first {
                    fraction = timestamps[i].timeIntervalSince(first) / last.timeIntervalSince(first)
                } else {
                    fraction = values.count > 1 ? Double(i) / Double(values.count - 1) : 1
                }
                let x: CGFloat = size.width * CGFloat(fraction)
                segments[segments.count - 1].append(CGPoint(x: x, y: 3 + height * (1 - CGFloat((v / max(bound, 0.001)).clamped(0, 1)))))
            }
            for points in segments where !points.isEmpty {
                var line = Path()
                line.addLines(points)
                if showFill, let first = points.first, let last = points.last {
                    var fill = line
                    fill.addLine(to: CGPoint(x: last.x, y: size.height))
                    fill.addLine(to: CGPoint(x: first.x, y: size.height)); fill.closeSubpath()
                    context.fill(fill, with: .linearGradient(Gradient(colors: [accent.end.opacity(0.24), accent.end.opacity(0.015)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                }
                context.stroke(line, with: .linearGradient(Gradient(colors: [accent.start, accent.end]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
            if values.last?.isFinite == true, let last = segments.last?.last {
                context.fill(Path(ellipseIn: CGRect(x: last.x - 2.5, y: last.y - 2.5, width: 5, height: 5)), with: .color(accent.start))
            }
        }
        .accessibilityLabel("Activity history")
        .accessibilityValue(values.last.flatMap { $0.isFinite ? (maxValue == 1 ? Format.percent($0) : String(format: "%.2f", $0)) : nil } ?? "Unavailable")
    }
}

struct HistoryChart: View {
    @EnvironmentObject var engine: MetricsEngine
    let values: [Double]
    let accent: Accent
    var ceiling: Double? = 1
    var ceilingLabel = "100%"
    var caption = "UTILIZATION"
    @State private var hoveredIndex: Int?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(hoveredIndex.flatMap { values.indices.contains($0) && values[$0].isFinite ? Format.percent(values[$0], decimals: 1) : nil } ?? caption)
                Spacer()
                Text(ceilingLabel)
            }.font(Theme.mono(10)).foregroundStyle(Theme.textTertiary)
            GeometryReader { geo in
                Sparkline(values: values, accent: accent, maxValue: ceiling, timestamps: engine.history.timestamps)
                    .overlay(alignment: .leading) {
                        if let i = hoveredIndex, values.count > 1 {
                            Rectangle().fill(Theme.textSecondary.opacity(0.5)).frame(width: 1)
                                .offset(x: geo.size.width * CGFloat(xFraction(i)))
                        }
                    }
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let fraction = location.x / max(geo.size.width, 1)
                            hoveredIndex = values.indices.min { abs(xFraction($0) - fraction) < abs(xFraction($1) - fraction) }
                        case .ended: hoveredIndex = nil
                        }
                    }
            }.frame(height: 130)
            HStack {
                Text(engine.historySpan)
                Spacer()
                Text(engine.isRunning ? "Now" : "Latest sample")
            }.font(Theme.mono(10)).foregroundStyle(Theme.textTertiary)
        }
    }
    private func xFraction(_ i: Int) -> Double {
        let times = engine.history.timestamps
        if times.count == values.count, let first = times.first, let last = times.last, last > first {
            return times[i].timeIntervalSince(first) / last.timeIntervalSince(first)
        }
        return values.count > 1 ? Double(i) / Double(values.count - 1) : 1
    }

}

struct LoadBar: View {
    let value: Double
    let color: Color
    var body: some View {
        GeometryReader { geo in
            Capsule().fill(color.opacity(0.13))
            Capsule().fill(color).frame(width: geo.size.width * value.clamped(0, 1))
        }.frame(height: 5)
    }
}

struct ChartScale: View {
    var label: String
    var maximum: String
    var body: some View {
        HStack { Text(label); Spacer(); Text(maximum) }
            .font(Theme.mono(10)).foregroundStyle(Theme.textTertiary)
    }
}

struct ChartTimeline: View {
    @EnvironmentObject var engine: MetricsEngine
    var body: some View {
        HStack { Text(engine.historySpan); Spacer(); Text(engine.isRunning ? "Now" : "Latest sample") }
            .font(Theme.mono(10)).foregroundStyle(Theme.textTertiary)
    }
}
