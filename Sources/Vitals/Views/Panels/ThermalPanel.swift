import SwiftUI

struct ThermalPanel: View {
    @EnvironmentObject var engine: MetricsEngine
    private let accent = Metric.thermal.accent

    var body: some View {
        let t = engine.snapshot.thermal
        let fans = engine.snapshot.fans
        let power = engine.snapshot.power
        let headline = t.cpuTemp ?? t.gpuTemp
        PanelScroll {
                MetricCard(title: "Thermals", accent: accent) {
                    HStack(alignment: .top, spacing: 24) {
                        Headline(value: Format.temp(headline), caption: t.cpuTemp != nil ? "CPU / SoC Temperature" : "GPU Temperature", accent: accent, size: 52)
                        Spacer()
                        HStack(spacing: 20) {
                            gaugeIfPresent(t.cpuTemp, "CPU")
                            gaugeIfPresent(t.gpuTemp, "GPU")
                        }
                    }
                    ChartScale(label: "TEMPERATURE", maximum: "110°C")
                    Sparkline(values: engine.history.temperature.values, accent: accent, maxValue: 110, timestamps: engine.history.timestamps)
                        .frame(height: 150)
                    ChartTimeline()
                }

                // Fans + power summary
                MetricCard(title: "Fans & Power · \(engine.snapshot.thermalState)", accent: accent) {
                    HStack(alignment: .top, spacing: 30) {
                        if fans.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Fans").font(Theme.label(11)).foregroundStyle(Theme.textTertiary).textCase(.uppercase)
                                Text("—").font(Theme.number(19)).foregroundStyle(Theme.textSecondary)
                            }
                        } else {
                            ForEach(fans) { fan in
                                let frac = fanFraction(fan)
                                RingGauge(value: frac, accent: accent, label: fan.name + " · RPM",
                                          centerText: "\(Int(fan.rpm))", size: 78)
                            }
                        }
                        Spacer()
                        StatGrid(stats: [
                            Stat(label: "Total Power", value: Format.watts(power.total)),
                            Stat(label: "CPU Power", value: Format.watts(power.cpu)),
                            Stat(label: "GPU Power", value: Format.watts(power.gpu)),
                        ], columns: 1)
                        .frame(maxWidth: 180)
                    }
                }

                // All sensors
                MetricCard(title: "Sensors (\(t.sensors.count))", accent: accent) {
                    if t.sensors.isEmpty {
                        Text("No temperature sensors reported.")
                            .font(Theme.label(12)).foregroundStyle(Theme.textTertiary)
                    } else {
                        let cols = [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 10)]
                        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
                            ForEach(Array(t.sensors.enumerated()), id: \.offset) { _, s in
                                HStack {
                                    Circle().fill(Color.heat((s.celsius - 25) / 75)).frame(width: 7, height: 7)
                                    Text(s.name).font(Theme.label(11)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                                    Spacer(minLength: 6)
                                    Text(String(format: "%.1f°", s.celsius))
                                        .font(Theme.mono(11, weight: .semibold)).foregroundStyle(Theme.text)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
                            }
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func gaugeIfPresent(_ temp: Double?, _ label: String) -> some View {
        if let temp {
            RingGauge(value: ((temp - 25) / 75).clamped(0, 1), accent: accent, label: label,
                      centerText: String(format: "%.0f°", temp), size: 78)
        }
    }

    private func fanFraction(_ fan: FanReading) -> Double {
        guard let mn = fan.minRPM, let mx = fan.maxRPM, mx > mn else { return fan.rpm > 0 ? 0.5 : 0 }
        return ((fan.rpm - mn) / (mx - mn)).clamped(0, 1)
    }
}
