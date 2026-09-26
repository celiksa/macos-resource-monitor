import Foundation

/// A metric source. Implementations own any state needed for delta calculations
/// (previous counters) and must be safe to call once per sampling interval.
protocol Sampler {
    associatedtype Output
    /// Produce one reading. Called on a background queue at the sampling interval.
    func sample() -> Output
}

// MARK: - Formatting helpers shared across the UI

enum Format {
    /// Human-readable bytes, e.g. "18.4 GB".
    static func bytes(_ v: UInt64) -> String {
        bytes(Double(v))
    }

    static func bytes(_ v: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var value = v
        var i = 0
        while value >= 1024 && i < units.count - 1 {
            value /= 1024
            i += 1
        }
        return String(format: value >= 100 || i == 0 ? "%.0f %@" : "%.1f %@", value, units[i])
    }

    /// Throughput, e.g. "8.4 MB/s".
    static func rate(_ bytesPerSec: Double) -> String {
        bytes(bytesPerSec) + "/s"
    }

    /// Percent from a 0...1 fraction, e.g. "47%".
    static func percent(_ fraction: Double, decimals: Int = 0) -> String {
        String(format: "%.\(decimals)f%%", (fraction * 100).clamped(0, 100))
    }

    static func percent(_ fraction: Double?, decimals: Int = 0) -> String {
        fraction.map { percent($0, decimals: decimals) } ?? "—"
    }

    static func duration(_ seconds: Double) -> String {
        let minutes = max(0, Int(seconds / 60))
        return minutes >= 1440 ? "\(minutes / 1440)d \(minutes % 1440 / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }

    /// Temperature, e.g. "62°".
    static func temp(_ celsius: Double?) -> String {
        guard let c = celsius, c > 0 else { return "—" }
        return String(format: "%.0f°", c)
    }

    static func watts(_ w: Double?) -> String {
        guard let w = w else { return "—" }
        return String(format: "%.1f W", w)
    }

    static func rpm(_ r: Double) -> String {
        String(format: "%.0f RPM", r)
    }
}

extension Comparable {
    func clamped(_ lo: Self, _ hi: Self) -> Self {
        min(max(self, lo), hi)
    }
}
