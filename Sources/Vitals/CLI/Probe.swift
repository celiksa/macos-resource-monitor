import Foundation
import AppKit

/// Process entry point. Branches to a headless JSON probe (`--probe`) or PNG
/// snapshot renderer (`--snapshot [dir]`) for verification, otherwise launches
/// the GUI app.
@main
enum Vitals {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--probe") || args.contains("--json") {
            Probe.run(watch: args.contains("--watch"))
            return
        }
        if let i = args.firstIndex(of: "--snapshot") {
            let dir = (i + 1 < args.count && !args[i + 1].hasPrefix("-"))
                ? args[i + 1]
                : FileManager.default.currentDirectoryPath
            _ = NSApplication.shared
            NSApp.setActivationPolicy(.accessory)
            MainActor.assumeIsolated { Snapshot.run(dir: dir) }
            return
        }
        VitalsApp.main()
    }
}

/// Headless one-shot (or watching) dump of every metric as JSON.
enum Probe {
    static func run(watch: Bool) {
        let set = SamplerSet()
        // Prime delta-based samplers, wait a beat, then take a real reading.
        _ = set.sampleAll()
        Thread.sleep(forTimeInterval: 2.1)

        func emit() {
            let snap = set.sampleAll()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(snap), let s = String(data: data, encoding: .utf8) {
                print(s)
            }
        }

        if watch {
            while true {
                emit()
                print("---")
                Thread.sleep(forTimeInterval: 1.0)
            }
        } else {
            emit()
        }
    }
}
