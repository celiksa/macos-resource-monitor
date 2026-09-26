import SwiftUI

struct DiskPanel: View {
    @EnvironmentObject var engine: MetricsEngine
    private let accent = Metric.disk.accent
    private let writeAccent = Accent(start: Color(hex: 0x6BE3FF), end: Color(hex: 0x2E9BFF))

    var body: some View {
        let d = engine.snapshot.disk
        let read = engine.history.diskRead.values
        let write = engine.history.diskWrite.values
        let scale = max(read.filter(\.isFinite).max() ?? 0, write.filter(\.isFinite).max() ?? 0, 1024 * 1024)
        let usedFrac = d.volumeTotal > 0 ? Double(d.volumeTotal - d.volumeFree) / Double(d.volumeTotal) : 0
        PanelScroll {
                MetricCard(title: "Disk Activity", accent: accent) {
                    HStack(alignment: .top, spacing: 30) {
                        Headline(value: Format.rate(d.readBytesPerSec), caption: "Read", accent: accent, size: 40)
                        Headline(value: Format.rate(d.writeBytesPerSec), caption: "Write", accent: writeAccent, size: 40)
                        Spacer()
                    }
                    ChartScale(label: "THROUGHPUT", maximum: Format.rate(scale))
                    ZStack {
                        Sparkline(values: read, accent: accent, maxValue: scale, timestamps: engine.history.timestamps)
                        Sparkline(values: write, accent: writeAccent, maxValue: scale, showFill: false, showGrid: false, timestamps: engine.history.timestamps)
                    }
                    .frame(height: 160)
                    ChartTimeline()
                }

                MetricCard(title: "Boot Volume", accent: accent) {
                    CompositionBar(
                        segments: [
                            .init(label: "Used \(Format.bytes(d.volumeTotal - d.volumeFree))", value: Double(d.volumeTotal - d.volumeFree), color: accent.end),
                            .init(label: "Free \(Format.bytes(d.volumeFree))", value: Double(d.volumeFree), color: Color.white.opacity(0.18)),
                        ],
                        total: Double(d.volumeTotal)
                    )
                    StatGrid(stats: [
                        Stat(label: "Capacity", value: Format.bytes(d.volumeTotal)),
                        Stat(label: "Used", value: Format.percent(usedFrac)),
                        Stat(label: "Total Read", value: Format.bytes(d.totalRead)),
                        Stat(label: "Total Written", value: Format.bytes(d.totalWritten)),
                    ], columns: 4)
                }
        }
    }
}
