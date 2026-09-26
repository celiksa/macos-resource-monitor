import SwiftUI

struct OverviewPanel: View {
    @EnvironmentObject var engine: MetricsEngine
    @Binding var selection: Metric

    var body: some View {
        let s = engine.snapshot
        PanelScroll {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15).fill(Metric.cpu.accent.end.opacity(0.12)).frame(width: 66, height: 66)
                    Image(systemName: "laptopcomputer").font(.system(size: 32)).foregroundStyle(Metric.cpu.accent.start)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(s.cpu.chipName.isEmpty ? "Your Mac" : s.cpu.chipName).font(Theme.number(21, weight: .semibold))
                    Text("\(s.cpu.coreCount)-core CPU  ·  \(s.gpu.coreCount.map { "\($0)-core GPU" } ?? "GPU")  ·  \(Format.bytes(s.memory.total)) memory")
                        .font(Theme.label(12)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Label(s.thermalState, systemImage: "checkmark.shield")
                        .font(Theme.label(12)).foregroundStyle(s.thermalState == "Nominal" ? Metric.memory.accent.start : .orange)
                    Text("Uptime \(Format.duration(s.uptime))").font(Theme.mono(10)).foregroundStyle(Theme.textTertiary)
                }
            }.padding(22).background(LinearGradient(colors: [Color(hex: 0x1A2940), Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                tile(.cpu, value: Format.percent(s.cpu.totalUsage), note: "\(s.cpu.coreCount) logical cores", values: engine.history.cpu.values)
                tile(.gpu, value: Format.percent(s.gpu.utilization), note: s.gpu.coreCount.map { "\($0) GPU cores" } ?? "Device utilization", values: engine.history.gpu.values)
                tile(.memory, value: Format.bytes(s.memory.used), note: "\(s.memory.pressureLevel) pressure", values: engine.history.memory.values)
                tile(.thermal, value: Format.temp(s.thermal.cpuTemp ?? s.thermal.gpuTemp), note: "\(s.thermal.sensors.count) temperature sensors", values: engine.history.temperature.values, max: 110)
                tile(.network, value: Format.rate(s.network.downloadBytesPerSec), note: "↑ \(Format.rate(s.network.uploadBytesPerSec))", values: engine.history.networkDown.values, max: nil)
                tile(.disk, value: Format.rate(s.disk.readBytesPerSec), note: "\(Format.bytes(s.disk.volumeFree)) available", values: engine.history.diskRead.values, max: nil)
            }
            HStack(alignment: .top, spacing: 14) {
                MetricCard(title: "Core groups", accent: Metric.cpu.accent) {
                    ForEach(s.cpu.clusters) { cluster in
                        HStack(spacing: 12) {
                            Text(cluster.name).font(Theme.label(12)).frame(width: 90, alignment: .leading)
                            LoadBar(value: cluster.usage, color: cluster.accent.start)
                            Text(Format.percent(cluster.usage)).font(Theme.mono(12)).frame(width: 40, alignment: .trailing)
                        }
                        Text("\(cluster.coreCount) cores").font(Theme.mono(9)).foregroundStyle(Theme.textTertiary)
                    }
                    Button("Explore CPU cores →") { selection = .cpu }.buttonStyle(.plain).font(Theme.label(11)).foregroundStyle(Metric.cpu.accent.start).padding(.top, 4)
                }
                MetricCard(title: "System status", accent: Metric.memory.accent) {
                    status("Memory pressure", s.memory.pressureLevel, "memorychip")
                    status("Power source", s.battery.isPresent ? s.battery.status : "Desktop power", "bolt")
                    status("Battery", s.battery.isPresent ? Format.percent(s.battery.level) : "Not installed", "battery.75percent")
                    status("System power", Format.watts(s.power.total), "waveform.path")
                }
            }
            if s.memory.pressureLevel == "Warning" || s.memory.pressureLevel == "Critical" || s.thermalState == "Serious" || s.thermalState == "Critical" {
                Label("Your Mac is under resource pressure. Check Processes for heavy workloads.", systemImage: "exclamationmark.triangle")
                    .font(Theme.label(12)).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func tile(_ metric: Metric, value: String, note: String, values: [Double], max: Double? = 1) -> some View {
        Button { selection = metric } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: metric.symbol).foregroundStyle(metric.accent.start)
                    Text(metric.title).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(Theme.textTertiary)
                }.font(Theme.label(12, weight: .semibold))
                Text(value).font(Theme.number(30, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.7)
                Text(note).font(Theme.label(10)).foregroundStyle(Theme.textTertiary)
                Sparkline(values: values, accent: metric.accent, maxValue: max, showGrid: false, timestamps: engine.history.timestamps).frame(height: 39)
            }.padding(18).background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardStroke))
        }.buttonStyle(.plain).help("Open \(metric.title)")
    }

    private func status(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 16).foregroundStyle(Theme.textTertiary)
            Text(label).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.text)
        }.font(Theme.label(11)).padding(.vertical, 3)
    }
}
