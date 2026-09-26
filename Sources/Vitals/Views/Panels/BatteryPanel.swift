import SwiftUI

struct BatteryPanel: View {
    @EnvironmentObject var engine: MetricsEngine
    private let accent = Metric.battery.accent
    var body: some View {
        let b = engine.snapshot.battery
        PanelScroll {
            if b.isPresent {
                MetricCard(title: b.status, accent: accent) {
                    HStack {
                        Headline(value: Format.percent(b.level), caption: "Battery charge", accent: accent, size: 58)
                        Spacer()
                        Image(systemName: b.isCharging ? "battery.100percent.bolt" : "battery.75percent")
                            .font(.system(size: 64, weight: .light)).foregroundStyle(accent.start).padding(.trailing, 16)
                    }
                    HistoryChart(values: engine.history.battery.values, accent: accent, caption: "CHARGE LEVEL")
                }
                MetricCard(title: "Battery health", accent: accent) {
                    StatGrid(stats: [
                        Stat(label: "Capacity / design", value: Format.percent(b.health)),
                        Stat(label: "Cycle count", value: b.cycleCount.map(String.init) ?? "—"),
                        Stat(label: "Condition", value: b.condition),
                        Stat(label: "Battery power", value: Format.watts(b.watts)),
                        Stat(label: b.isCharging ? "Time until full" : "Time remaining", value: b.onAC && !b.isCharging ? "—" : (b.minutesRemaining.map { Format.duration(Double($0 * 60)) } ?? "Estimating…")),
                        Stat(label: "Power source", value: b.onAC ? "Power adapter" : "Battery")
                    ], columns: 3)
                }
                MetricCard(title: "About these readings", accent: accent) {
                    Text("Capacity is an estimate of full-charge capacity relative to the battery’s design capacity. Remaining time changes with your workload. Battery power measures charge or discharge at the battery, not total wall power.")
                        .font(Theme.label(12)).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ContentUnavailableView("No internal battery", systemImage: "powerplug", description: Text("Battery readings are available on Mac notebooks. This Mac may use external power, or battery information may be unavailable."))
                    .padding(.top, 90)
            }
        }
    }
}
