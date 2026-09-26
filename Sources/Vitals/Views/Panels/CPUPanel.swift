import SwiftUI

struct CPUPanel: View {
    @EnvironmentObject var engine: MetricsEngine

    var body: some View {
        let cpu = engine.snapshot.cpu
        PanelScroll {
            MetricCard(title: cpu.chipName.isEmpty ? "Processor" : cpu.chipName, accent: Metric.cpu.accent) {
                HStack(alignment: .center) {
                    Headline(value: Format.percent(cpu.totalUsage), caption: "Total CPU utilization", accent: Metric.cpu.accent, size: 50)
                    Spacer()
                    StatGrid(stats: [
                        Stat(label: "User", value: Format.percent(cpu.user)),
                        Stat(label: "System", value: Format.percent(cpu.system)),
                        Stat(label: "Idle", value: Format.percent(cpu.idle))
                    ], columns: 3).frame(maxWidth: 330)
                }
                HistoryChart(values: engine.history.cpu.values, accent: Metric.cpu.accent)
            }

            HStack(spacing: 14) {
                ForEach(cpu.clusters) { cluster in
                    MetricCard(title: cluster.name + " cores", accent: cluster.accent) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(Format.percent(cluster.usage)).font(Theme.number(29)).foregroundStyle(cluster.accent.start)
                            Spacer()
                            Text("\(cluster.coreCount) cores").font(Theme.mono(10)).foregroundStyle(Theme.textTertiary)
                        }
                        Sparkline(values: engine.history.clusters[cluster.name]?.values ?? [], accent: cluster.accent, timestamps: engine.history.timestamps).frame(height: 42)
                    }
                }
            }

            MetricCard(title: "Individual cores", accent: Metric.cpu.accent) {
                if cpu.perCore.isEmpty {
                    Text("Collecting the first CPU sample…").font(Theme.label(12)).foregroundStyle(Theme.textSecondary)
                }
                ForEach(cpu.clusters) { cluster in
                    HStack(spacing: 7) {
                        Circle().fill(cluster.accent.start).frame(width: 5, height: 5)
                        Text(cluster.name.uppercased()).font(Theme.mono(9, weight: .semibold)).tracking(1)
                        Text("· \(cluster.coreCount) CORES").font(Theme.mono(9)).foregroundStyle(Theme.textTertiary)
                        Spacer()
                    }.foregroundStyle(cluster.accent.start)
                    CoreHeatmap(perCore: cpu.perCore, clusters: [cluster], accent: cluster.accent)
                }
                if !cpu.topologyVerified {
                    Text("Core type mapping is unavailable on this Mac. Logical CPU IDs are shown without inferred type labels.")
                        .font(Theme.label(10)).foregroundStyle(Theme.textTertiary)
                }
            }

            MetricCard(title: "Scheduling", accent: Metric.cpu.accent) {
                StatGrid(stats: [
                    Stat(label: "1 min load", value: load(0)), Stat(label: "5 min load", value: load(1)),
                    Stat(label: "15 min load", value: load(2)), Stat(label: "Logical cores", value: "\(cpu.coreCount)")
                ], columns: 4)
                Text("Load average counts runnable and waiting tasks; it is not a utilization percentage.")
                    .font(Theme.label(10)).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func load(_ i: Int) -> String {
        let loads = engine.snapshot.cpu.loadAverage
        return loads.indices.contains(i) ? String(format: "%.2f", loads[i]) : "—"
    }
}
