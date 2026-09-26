import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var engine: MetricsEngine
    @Binding var selection: Metric

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Metric.cpu.accent.start)
                    .frame(width: 40, height: 40)
                    .background(Metric.cpu.accent.end.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vitals").font(Theme.number(23, weight: .bold)).foregroundStyle(Theme.text)
                    Text("YOUR MAC, IN FOCUS").font(Theme.mono(8)).tracking(1.4).foregroundStyle(Theme.textTertiary)
                }
            }.padding(.horizontal, 10).padding(.top, 28).padding(.bottom, 23)
            row(.overview)
            Text("HARDWARE").font(Theme.mono(9)).tracking(1.5).foregroundStyle(Theme.textTertiary)
                .padding(.leading, 12).padding(.top, 18).padding(.bottom, 4)
            ForEach([Metric.cpu, .gpu, .memory, .thermal, .network, .disk, .battery]) { row($0) }
            Divider().overlay(Theme.hair).padding(.vertical, 10)
            row(.processes)
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Circle().fill(engine.isRunning ? Metric.memory.accent.end : Color.orange).frame(width: 6, height: 6)
                    Text(engine.isRunning ? "Monitoring live" : "Monitoring paused").font(Theme.label(11))
                }.foregroundStyle(Theme.textSecondary)
                Text(engine.snapshot.cpu.chipName.isEmpty ? "Detecting hardware…" : engine.snapshot.cpu.chipName)
                    .font(Theme.label(12, weight: .semibold)).foregroundStyle(Theme.text)
                Text("\(Format.bytes(engine.snapshot.memory.total)) memory · \(engine.snapshot.cpu.coreCount) CPU cores")
                    .font(Theme.label(10)).foregroundStyle(Theme.textTertiary)
                HStack {
                    Text("Refresh").font(Theme.label(11)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Picker("Refresh interval", selection: $engine.interval) {
                        ForEach(MetricsEngine.intervalOptions, id: \.self) { Text($0 < 1 ? "0.5 sec" : "\(Int($0)) sec").tag($0) }
                    }.labelsHidden().frame(width: 85)
                }.padding(.top, 5)
            }.padding(13).background(Theme.card.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(14).frame(width: 232).frame(maxHeight: .infinity)
    }

    private func row(_ metric: Metric) -> some View {
        let selected = selection == metric
        return Button { selection = metric } label: {
            HStack(spacing: 11) {
                Image(systemName: metric.symbol).font(.system(size: 15, weight: .medium))
                    .foregroundStyle(selected ? metric.accent.start : Theme.textTertiary).frame(width: 22)
                Text(metric.title).font(Theme.label(12, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Theme.text : Theme.textSecondary)
                Spacer(minLength: 4)
                Text(value(metric)).font(Theme.mono(10)).foregroundStyle(selected ? metric.accent.start : Theme.textTertiary)
            }.padding(.horizontal, 12).frame(height: 39)
                .background(selected ? metric.accent.end.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? metric.accent.end.opacity(0.22) : .clear))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func value(_ metric: Metric) -> String {
        let s = engine.snapshot
        switch metric {
        case .overview: return ""
        case .cpu: return Format.percent(s.cpu.totalUsage)
        case .gpu: return Format.percent(s.gpu.utilization)
        case .memory: return Format.bytes(s.memory.used)
        case .thermal: return Format.temp(s.thermal.cpuTemp ?? s.thermal.gpuTemp)
        case .network: return Format.rate(s.network.downloadBytesPerSec)
        case .disk: return Format.rate(s.disk.readBytesPerSec)
        case .battery: return Format.percent(s.battery.level)
        case .processes: return String(s.processes.entries.count)
        }
    }
}
