import SwiftUI

struct CoreHeatmap: View {
    @EnvironmentObject var engine: MetricsEngine
    let perCore: [Double]
    let clusters: [CPUCluster]
    let accent: Accent

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
            ForEach(clusters.flatMap(\.indices), id: \.self) { index in
                if perCore.indices.contains(index) { cell(index, load: perCore[index]) }
            }
        }
    }

    private func cell(_ index: Int, load: Double) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("CPU \(index)").font(Theme.mono(9)).foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 1)
                Text(Format.percent(load)).font(Theme.mono(10, weight: .semibold)).foregroundStyle(Theme.text)
            }
            Sparkline(values: engine.history.cores.indices.contains(index) ? engine.history.cores[index].values : [], accent: accent, lineWidth: 1.3, showGrid: false, timestamps: engine.history.timestamps)
                .frame(height: 24)
            GeometryReader { geo in
                Capsule().fill(accent.end.opacity(0.1))
                Capsule().fill(accent.horizontal).frame(width: geo.size.width * load.clamped(0, 1))
            }.frame(height: 3)
        }.padding(9).background(accent.end.opacity(0.035 + load * 0.13), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(accent.end.opacity(0.12)))
            .accessibilityElement(children: .combine)
            .help("Logical CPU \(index): \(Format.percent(load, decimals: 1)) utilization")
    }
}
