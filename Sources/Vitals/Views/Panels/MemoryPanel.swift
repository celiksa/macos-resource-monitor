import SwiftUI

struct MemoryPanel: View {
    @EnvironmentObject var engine: MetricsEngine
    private let accent = Metric.memory.accent

    var body: some View {
        let m = engine.snapshot.memory
        let usedFrac = m.total > 0 ? Double(m.used) / Double(m.total) : 0
        PanelScroll {
                MetricCard(title: "Memory", accent: accent) {
                    HStack(alignment: .top) {
                        Headline(value: Format.bytes(m.used), caption: "Used of \(Format.bytes(m.total))", accent: accent, size: 46)
                        Spacer()
                        RingGauge(value: usedFrac, accent: accent, label: "In Use", size: 84)
                    }
                    HistoryChart(values: engine.history.memory.values, accent: accent)
                }

                MetricCard(title: "Composition", accent: accent) {
                    CompositionBar(
                        segments: [
                            .init(label: "App", value: Double(m.appMemory), color: accent.start),
                            .init(label: "Wired", value: Double(m.wired), color: Metric.gpu.accent.end),
                            .init(label: "Compressed", value: Double(m.compressed), color: Metric.thermal.accent.start),
                            .init(label: "Cached", value: Double(m.cached), color: Color.white.opacity(0.25)),
                        ],
                        total: Double(m.total)
                    )
                }

                MetricCard(title: "Details", accent: accent) {
                    StatGrid(stats: [
                        Stat(label: "App Memory", value: Format.bytes(m.appMemory)),
                        Stat(label: "Wired", value: Format.bytes(m.wired)),
                        Stat(label: "Compressed", value: Format.bytes(m.compressed)),
                        Stat(label: "Cached Files", value: Format.bytes(m.cached)),
                        Stat(label: "Free", value: Format.bytes(m.free)),
                        Stat(label: "Pressure", value: m.pressureLevel, accent: Color.heat(m.pressure)),
                        Stat(label: "Swap Used", value: Format.bytes(m.swapUsed)),
                        Stat(label: "Swap Total", value: Format.bytes(m.swapTotal)),
                    ], columns: 4)
                }
        }
    }
}
