import SwiftUI

struct GPUPanel: View {
    @EnvironmentObject var engine: MetricsEngine
    private let accent = Metric.gpu.accent

    var body: some View {
        let gpu = engine.snapshot.gpu
        PanelScroll {
            MetricCard(title: gpu.name.isEmpty ? "Graphics processor" : gpu.name, accent: accent) {
                HStack(alignment: .center) {
                    Headline(value: Format.percent(gpu.utilization), caption: "GPU device utilization", accent: accent, size: 50)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 7) {
                        Text(gpu.coreCount.map { "\($0)-core GPU" } ?? "GPU cores unavailable").font(Theme.number(20))
                        Text(gpu.unifiedMemory ? "Unified memory architecture" : "Graphics processor").font(Theme.label(11)).foregroundStyle(Theme.textSecondary)
                    }
                }
                HistoryChart(values: engine.history.gpu.values, accent: accent)
                if gpu.utilization == nil {
                    Text("GPU utilization is not reported by the graphics driver on this Mac.")
                        .font(Theme.label(11)).foregroundStyle(Theme.textSecondary)
                }
            }
            HStack(spacing: 14) {
                engineCard("Renderer", value: gpu.rendererUtilization, symbol: "cube.transparent", note: "Rendering engine activity")
                engineCard("Tiler", value: gpu.tilerUtilization, symbol: "square.grid.3x3", note: "Geometry and tiling activity")
            }
            MetricCard(title: "GPU hardware", accent: accent) {
                HStack(alignment: .top, spacing: 25) {
                    VStack(spacing: 10) {
                        Image(systemName: "cpu.fill").font(.system(size: 44)).foregroundStyle(accent.start)
                        Text(gpu.coreCount.map { "\($0) CORES" } ?? "GPU").font(Theme.mono(11, weight: .semibold)).tracking(1).foregroundStyle(accent.start)
                    }.frame(width: 100).padding(.vertical, 10)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Device-wide monitoring").font(Theme.number(17))
                        Text("macOS reports activity for the GPU and its engines. Individual GPU-core utilization is not exposed by this driver, so the core count describes hardware, not separate live readings.")
                            .font(Theme.label(12)).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                        Text("Renderer and tiler readings can overlap; they do not add up to the device total.")
                            .font(Theme.label(10)).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            MetricCard(title: "Memory & sensors", accent: accent) {
                StatGrid(stats: [
                    Stat(label: "GPU memory in use", value: gpu.inUseMemory.map { Format.bytes($0) } ?? "—"),
                    Stat(label: "Driver allocation", value: gpu.allocatedMemory.map { Format.bytes($0) } ?? "—"),
                    Stat(label: "GPU temperature", value: Format.temp(engine.snapshot.thermal.gpuTemp)),
                    Stat(label: "GPU power", value: Format.watts(engine.snapshot.power.gpu))
                ], columns: 4)
                Text("Unavailable sensors appear as —. On Apple Silicon, GPU allocations use shared system memory.")
                    .font(Theme.label(10)).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func engineCard(_ title: String, value: Double?, symbol: String, note: String) -> some View {
        MetricCard(title: title, accent: accent) {
            HStack {
                Image(systemName: symbol).font(.system(size: 26)).foregroundStyle(accent.start)
                Spacer()
                Text(Format.percent(value)).font(Theme.number(30)).foregroundStyle(Theme.text)
            }
            LoadBar(value: value ?? 0, color: accent.start).opacity(value == nil ? 0.3 : 1)
            Text(note).font(Theme.label(10)).foregroundStyle(Theme.textTertiary)
        }
    }
}
