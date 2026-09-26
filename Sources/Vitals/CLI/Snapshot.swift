import SwiftUI
import AppKit

/// Headless renderer: builds a populated engine and renders each metric panel
/// (sidebar + detail) to a PNG using `ImageRenderer`. No screen-recording needed.
@MainActor
enum Snapshot {
    static func run(dir: String) {
        let engine = MetricsEngine()
        let set = engine.samplers

        // Populate history with a run of real samples so the sparklines are full.
        _ = set.sampleAll()
        for _ in 0..<30 {
            Thread.sleep(forTimeInterval: 0.08)
            engine.ingest(set.sampleAll())
        }

        let fm = FileManager.default
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

        for metric in Metric.allCases {
            let height: CGFloat
            switch metric {
            case .cpu: height = 1160
            case .thermal: height = 1040
            case .gpu: height = 1040
            default: height = 920
            }
            let view = SnapshotContainer(metric: metric)
                .environmentObject(engine)
                .environment(\.snapshotMode, true)
                .frame(width: 1220, height: height)

            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                FileHandle.standardError.write("Failed to render \(metric.rawValue)\n".data(using: .utf8)!)
                continue
            }
            let path = "\(dir)/vitals_\(metric.rawValue).png"
            try? png.write(to: URL(fileURLWithPath: path))
            print("Wrote \(path)")
        }
    }
}

private struct SnapshotContainer: View {
    let metric: Metric
    var body: some View {
        DashboardShell(selection: .constant(metric))
            .environment(\.colorScheme, .dark)
    }
}
