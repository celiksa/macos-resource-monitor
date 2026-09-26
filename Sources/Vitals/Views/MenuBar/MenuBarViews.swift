import SwiftUI

/// Compact live label shown in the system menu bar, e.g. "47% · 25% · 62°".
struct MenuBarLabel: View {
    @ObservedObject var engine: MetricsEngine

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "waveform.path.ecg").font(.system(size: 11, weight: .bold))
            Text(engine.menuBarSummary).font(.system(size: 11, weight: .medium, design: .rounded))
        }
    }
}

/// The dropdown panel from the menu-bar item: mini gauges + quick stats.
struct MenuBarPanel: View {
    @ObservedObject var engine: MetricsEngine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let s = engine.snapshot
        VStack(alignment: .leading, spacing: 16) {
            Text("Vitals").font(Theme.number(16, weight: .bold)).foregroundStyle(Theme.text)

            HStack(spacing: 18) {
                RingGauge(value: s.cpu.totalUsage, accent: Metric.cpu.accent, label: "CPU", size: 66)
                RingGauge(value: s.gpu.utilization ?? 0, accent: Metric.gpu.accent, label: "GPU", centerText: Format.percent(s.gpu.utilization), size: 66)
                RingGauge(value: s.memory.total > 0 ? Double(s.memory.used) / Double(s.memory.total) : 0,
                          accent: Metric.memory.accent, label: "MEM", size: 66)
                RingGauge(value: (((s.thermal.cpuTemp ?? 0) - 25) / 75).clamped(0, 1),
                          accent: Metric.thermal.accent, label: "TEMP",
                          centerText: Format.temp(s.thermal.cpuTemp ?? s.thermal.gpuTemp), size: 66)
            }

            HStack(spacing: 20) {
                miniStat("↓", Format.rate(s.network.downloadBytesPerSec), Metric.network.accent.end)
                miniStat("↑", Format.rate(s.network.uploadBytesPerSec), Metric.network.accent.start)
                miniStat("Disk R", Format.rate(s.disk.readBytesPerSec), Metric.disk.accent.end)
            }

            Divider().overlay(Theme.hair)

            HStack {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Open Dashboard", systemImage: "macwindow")
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .buttonStyle(.borderless)
            .font(Theme.label(12))
        }
        .padding(18)
        .frame(width: 360)
        .preferredColorScheme(.dark)
    }

    private func miniStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Theme.label(10)).foregroundStyle(Theme.textTertiary)
            Text(value).font(Theme.mono(12, weight: .semibold)).foregroundStyle(color)
        }
    }
}
