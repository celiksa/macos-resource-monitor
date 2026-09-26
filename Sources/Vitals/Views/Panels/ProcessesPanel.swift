import SwiftUI

struct ProcessesPanel: View {
    @Environment(\.snapshotMode) private var snapshotMode
    @EnvironmentObject var engine: MetricsEngine
    @State private var query = ""
    @State private var sort = "CPU"
    @State private var ascending = false

    private var rows: [ProcessReading] {
        engine.snapshot.processes.entries.filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || String($0.pid).contains(query)
        }.sorted { a, b in
            switch sort {
            case "Memory": return ascending ? a.memory < b.memory : a.memory > b.memory
            case "Name": return ascending ? a.name.localizedStandardCompare(b.name) == .orderedAscending : a.name.localizedStandardCompare(b.name) == .orderedDescending
            default:
                let x = a.cpu ?? -1, y = b.cpu ?? -1
                if x == y { return a.pid < b.pid }
                return ascending ? x < y : x > y
            }
        }
    }

    var body: some View {
        PanelScroll {
            MetricCard {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.textTertiary)
                    if snapshotMode {
                        Text("Search processes or PID").foregroundStyle(Theme.textTertiary)
                        Spacer()
                        Text("Sort by CPU ↓").foregroundStyle(Theme.textSecondary)
                    } else {
                    TextField("Search processes or PID", text: $query).textFieldStyle(.plain).accessibilityLabel("Search processes or PID")
                    Picker("Sort by", selection: $sort) { Text("CPU").tag("CPU"); Text("Memory").tag("Memory"); Text("Name").tag("Name") }.frame(width: 150)
                    Button { ascending.toggle() } label: { Image(systemName: ascending ? "arrow.up" : "arrow.down") }.help("Reverse sort order").accessibilityLabel("Reverse sort order")
                    }
                }
            }
            Text("CPU 100% = one busy core · Memory = physical footprint · \(engine.snapshot.processes.inaccessibleCount) processes inaccessible")
                .font(Theme.label(10)).foregroundStyle(Theme.textTertiary).frame(maxWidth: .infinity, alignment: .leading)
            MetricCard(title: "\(rows.count) \(rows.count == 1 ? "process" : "processes")", accent: Metric.processes.accent) {
                HStack {
                    Text("PROCESS").frame(maxWidth: .infinity, alignment: .leading)
                    Text("PID").frame(width: 60, alignment: .trailing)
                    Text("CPU").frame(width: 90, alignment: .trailing)
                    Text("MEMORY").frame(width: 105, alignment: .trailing)
                }.font(Theme.mono(10)).foregroundStyle(Theme.textTertiary).padding(.bottom, 5)
                if rows.isEmpty {
                    Text(query.isEmpty ? "Waiting for accessible process counters…" : "No processes match “\(query)”.")
                        .font(Theme.label(13)).foregroundStyle(Theme.textSecondary).padding(.vertical, 30)
                }
                LazyVStack(spacing: 0) {
                    ForEach(snapshotMode ? Array(rows.prefix(14)) : rows) { process in
                        HStack(spacing: 12) {
                            Image(systemName: "app.dashed").foregroundStyle(Metric.processes.accent.start).frame(width: 22)
                            Text(process.name).font(Theme.label(12)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            Text(String(process.pid)).foregroundStyle(Theme.textTertiary).frame(width: 60, alignment: .trailing)
                            Text(process.cpu.map { String(format: "%.1f%%", $0 * 100) } ?? "—")
                                .foregroundStyle(Metric.cpu.accent.start).frame(width: 90, alignment: .trailing)
                            Text(Format.bytes(process.memory)).foregroundStyle(Theme.textSecondary).frame(width: 105, alignment: .trailing)
                        }.font(Theme.mono(11)).padding(.vertical, 11)
                        Rectangle().fill(Theme.hair).frame(height: 1)
                    }
                }
            }
            Text("CPU 100% = one fully used core; multi-core processes can exceed 100%. Memory shows physical footprint. Refreshes every 2 seconds or at the selected interval if slower. \(engine.snapshot.processes.inaccessibleCount) processes could not be read.")
                .font(Theme.label(11)).foregroundStyle(Theme.textTertiary).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
