import SwiftUI

struct NetworkPanel: View {
    @State private var showAllInterfaces = false
    @EnvironmentObject var engine: MetricsEngine
    private let accent = Metric.network.accent
    private let upAccent = Accent(start: Color(hex: 0xFF8A5B), end: Color(hex: 0xFF5E7E))

    var body: some View {
        let n = engine.snapshot.network
        let down = engine.history.networkDown.values
        let up = engine.history.networkUp.values
        let scale = max(down.filter(\.isFinite).max() ?? 0, up.filter(\.isFinite).max() ?? 0, 1024) // at least 1 KB/s for a sane axis
        PanelScroll {
                MetricCard(title: n.primaryInterface.map { "Network · \($0)" } ?? "Network", accent: accent) {
                    HStack(alignment: .top, spacing: 30) {
                        Headline(value: Format.rate(n.downloadBytesPerSec), caption: "↓ Download", accent: accent, size: 40)
                        Headline(value: Format.rate(n.uploadBytesPerSec), caption: "↑ Upload", accent: upAccent, size: 40)
                        Spacer()
                    }
                    ChartScale(label: "THROUGHPUT", maximum: Format.rate(scale))
                    ZStack {
                        Sparkline(values: down, accent: accent, maxValue: scale, showGrid: true, timestamps: engine.history.timestamps)
                        Sparkline(values: up, accent: upAccent, maxValue: scale, showFill: false, showGrid: false, timestamps: engine.history.timestamps)
                    }
                    .frame(height: 160)
                    ChartTimeline()
                }

                MetricCard(title: "Interface lifetime totals", accent: accent) {
                    StatGrid(stats: [
                        Stat(label: "Downloaded", value: Format.bytes(n.totalDownloaded)),
                        Stat(label: "Uploaded", value: Format.bytes(n.totalUploaded)),
                        Stat(label: "Busiest interface", value: n.primaryInterface ?? "—"),
                    ], columns: 3)
                }
                MetricCard(title: "Interfaces", accent: accent) {
                    HStack {
                        Text(showAllInterfaces ? "All available interfaces" : "Interfaces carrying traffic")
                            .font(Theme.label(11)).foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Button(showAllInterfaces ? "Show active" : "Show all \(n.interfaces.count)") { showAllInterfaces.toggle() }
                            .buttonStyle(.plain).font(Theme.label(11)).foregroundStyle(accent.start)
                    }
                    ForEach(n.interfaces.filter { showAllInterfaces || $0.download + $0.upload > 0 || $0.name == n.primaryInterface }.sorted {
                        if $0.includedInTotal != $1.includedInTotal { return $0.includedInTotal }
                        return $0.name < $1.name
                    }) { interface in
                        HStack {
                            Image(systemName: interface.includedInTotal ? "network" : "point.3.connected.trianglepath.dotted").foregroundStyle(accent.start).frame(width: 24)
                            Text(interface.name).font(Theme.mono(12)).frame(width: 65, alignment: .leading)
                            Text(interface.includedInTotal ? "Included in total" : "Other / virtual").font(Theme.label(10)).foregroundStyle(Theme.textTertiary)
                            Spacer()
                            Text("↓ \(Format.rate(interface.download))").frame(width: 115, alignment: .trailing)
                            Text("↑ \(Format.rate(interface.upload))").frame(width: 115, alignment: .trailing)
                        }.font(Theme.mono(11)).padding(.vertical, 5)
                    }
                    Text("Totals include active Ethernet / Wi-Fi interfaces (en*). Virtual interfaces are shown separately to avoid counting the same traffic twice. Counters reset when an interface resets.")
                        .font(Theme.label(11)).foregroundStyle(Theme.textTertiary).fixedSize(horizontal: false, vertical: true)
                }

        }
    }
}
