import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var engine: MetricsEngine
    @State private var selection: Metric = .overview

    var body: some View {
        DashboardShell(selection: $selection)
            .frame(minWidth: 1020, minHeight: 740)
            .preferredColorScheme(.dark)
            .onAppear { if !engine.isRunning { engine.start() } }
    }
}

struct DashboardShell: View {
    @Environment(\.snapshotMode) private var snapshotMode
    @EnvironmentObject var engine: MetricsEngine
    @Binding var selection: Metric

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection).background(Theme.bgElevated)
            Rectangle().fill(Theme.hair).frame(width: 1)
            VStack(spacing: 0) {
                header.fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(Theme.hair).frame(height: 1)
                detail.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).clipped()
            }.background(Theme.bg)
        }.background(Theme.bg).foregroundStyle(Theme.text)
            .alert("Couldn’t export", isPresented: Binding(get: { engine.exportError != nil }, set: { if !$0 { engine.exportError = nil } })) {
                Button("OK") { engine.exportError = nil }
            } message: { Text(engine.exportError ?? "") }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 9) {
                    Text(selection.title).font(Theme.number(25, weight: .bold))
                    Text(engine.isRunning ? "LIVE" : "PAUSED")
                        .font(Theme.mono(8, weight: .bold)).tracking(1)
                        .foregroundStyle(engine.isRunning ? Metric.memory.accent.start : Color.orange)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background((engine.isRunning ? Metric.memory.accent.end : Color.orange).opacity(0.1), in: Capsule())
                }
                Text(subtitle).font(Theme.label(11)).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 4)
            HStack(spacing: 3) {
                ForEach([60.0, 120.0, 600.0], id: \.self) { duration in
                    Button { engine.historySeconds = duration } label: {
                        Text("\(Int(duration / 60))m").font(Theme.mono(11))
                            .foregroundStyle(engine.historySeconds == duration ? Theme.text : Theme.textTertiary)
                            .frame(width: 36, height: 28)
                            .background(engine.historySeconds == duration ? Color.white.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(.plain).help("Show \(Int(duration / 60)) minutes of history")
                        .accessibilityLabel("\(Int(duration / 60)) minute history")
                        .accessibilityAddTraits(engine.historySeconds == duration ? .isSelected : [])
                }
            }.padding(3).background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
            Button { engine.isRunning ? engine.stop() : engine.start() } label: {
                Image(systemName: engine.isRunning ? "pause.fill" : "play.fill").frame(width: 24, height: 24)
            }.buttonStyle(.plain).help(engine.isRunning ? "Pause monitoring" : "Resume monitoring")
                .accessibilityLabel(engine.isRunning ? "Pause monitoring" : "Resume monitoring")
                .keyboardShortcut("p", modifiers: [.command, .shift])
            if snapshotMode {
                Image(systemName: "square.and.arrow.up").frame(width: 24, height: 24)
            } else {
            Menu {
                Button("Export snapshot as JSON…") { engine.exportSnapshot() }
                Button("Export history as CSV…") { engine.exportHistory() }
                Divider()
                Button("Clear history") { engine.clearHistory() }
            } label: { Image(systemName: "square.and.arrow.up").frame(width: 24, height: 24) }
                .menuStyle(.borderlessButton).fixedSize().help("Export and history actions")
                .accessibilityLabel("Export and history actions")
            }
        }.padding(.horizontal, 26).padding(.top, 28).padding(.bottom, 22)
    }

    private var subtitle: String {
        switch selection {
        case .overview: return "A clear view of everything happening on your Mac."
        case .cpu: return "Processor activity, core groups, and individual core histories."
        case .gpu: return "Graphics activity and the engines behind it."
        case .memory: return "Unified memory, compression, and system pressure."
        case .thermal: return "Temperature sensors, cooling, and system power."
        case .network: return "Network throughput and interface activity."
        case .disk: return "Storage capacity and read / write activity."
        case .battery: return "Charge, battery health, and power source."
        case .processes: return "Find the processes using your CPU and memory."
        }
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .overview: OverviewPanel(selection: $selection)
        case .cpu: CPUPanel()
        case .gpu: GPUPanel()
        case .memory: MemoryPanel()
        case .thermal: ThermalPanel()
        case .network: NetworkPanel()
        case .disk: DiskPanel()
        case .battery: BatteryPanel()
        case .processes: ProcessesPanel()
        }
    }
}
