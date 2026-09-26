import Foundation

// MARK: - Per-metric sample structs
//
// Every sampler returns a plain, Codable value type. `SystemSnapshot` bundles one
// reading of everything. Codable conformance powers the `--probe` JSON dump used
// for headless verification.

/// One CPU core cluster (a `hw.perflevel`), e.g. "Super" or "Performance" on M5.
/// Each group explicitly lists its logical CPU IDs; they need not be contiguous.
struct CPUCluster: Codable, Equatable, Identifiable {
    var name: String                    // perflevel name, e.g. "Super", "Performance", "Efficiency"
    var coreCount: Int
    var usage: Double                   // 0...1 average across the cluster
    var firstCore: Int                  // starting index into `perCore`
    var coreIDs: [Int] = []
    var id: String { name }
    var indices: [Int] { coreIDs.isEmpty ? Array(range) : coreIDs }
    var range: Range<Int> { firstCore..<(firstCore + coreCount) }
}

/// CPU utilization for one sampling interval. All usage values are 0...1 fractions.
struct CPUSample: Codable, Equatable {
    var totalUsage: Double = 0          // aggregate across all cores, 0...1
    var user: Double = 0
    var system: Double = 0
    var idle: Double = 1
    var nice: Double = 0
    var perCore: [Double] = []          // 0...1 per logical core
    var clusters: [CPUCluster] = []     // performance groups, highest tier first
    var coreCount: Int = 0
    var topologyVerified: Bool = false
    var loadAverage: [Double] = []      // [1m, 5m, 15m]
    var chipName: String = ""           // e.g. "Apple M5 Max"
}

/// Memory / swap breakdown. Byte counts are absolute; `pressure` is 0...1.
struct MemorySample: Codable, Equatable {
    var total: UInt64 = 0
    var used: UInt64 = 0                 // total - free-ish (app + wired + compressed)
    var wired: UInt64 = 0
    var active: UInt64 = 0
    var inactive: UInt64 = 0
    var compressed: UInt64 = 0
    var free: UInt64 = 0
    var appMemory: UInt64 = 0
    var cached: UInt64 = 0
    var pressureLevel: String = "Unavailable"
    var pressure: Double = 0             // categorical color index; see pressureLevel for status
    var swapTotal: UInt64 = 0
    var swapUsed: UInt64 = 0
}

/// Integrated GPU stats from IORegistry PerformanceStatistics. Utilization 0...1.
struct GPUSample: Codable, Equatable {
    var utilization: Double? = nil          // "Device Utilization %" / 100
    var rendererUtilization: Double? = nil
    var tilerUtilization: Double? = nil
    var inUseMemory: UInt64? = nil       // "In use system memory"
    var allocatedMemory: UInt64? = nil   // "Alloc system memory"
    var name: String = ""
    var coreCount: Int? = nil
    var unifiedMemory: Bool = false
}

/// A single named temperature sensor reading, in degrees Celsius.
struct TempReading: Codable, Equatable, Identifiable {
    var name: String
    var celsius: Double
    var id: String { name }
}

/// A single fan, with current RPM and known bounds.
struct FanReading: Codable, Equatable, Identifiable {
    var name: String
    var rpm: Double
    var minRPM: Double? = nil
    var maxRPM: Double? = nil
    var id: String { name }
}

/// Temperature sensors. `cpuTemp`/`gpuTemp` are the representative values for headline display.
struct ThermalSample: Codable, Equatable {
    var cpuTemp: Double? = nil
    var gpuTemp: Double? = nil
    var sensors: [TempReading] = []
}

/// Power draw in watts, where available from SMC.
struct PowerSample: Codable, Equatable {
    var total: Double? = nil             // system / package total
    var cpu: Double? = nil
    var gpu: Double? = nil
}

/// Network throughput, aggregated across active interfaces.
struct NetworkInterface: Codable, Equatable, Identifiable {
    var name: String
    var download: Double
    var upload: Double
    var totalIn: UInt64
    var totalOut: UInt64
    var includedInTotal: Bool
    var id: String { name }
}

struct NetworkSample: Codable, Equatable {
    var interfaces: [NetworkInterface] = []
    var uploadBytesPerSec: Double = 0
    var downloadBytesPerSec: Double = 0
    var totalUploaded: UInt64 = 0
    var totalDownloaded: UInt64 = 0
    var primaryInterface: String? = nil
}

/// Aggregate disk throughput across physical block devices.
struct DiskSample: Codable, Equatable {
    var readBytesPerSec: Double = 0
    var writeBytesPerSec: Double = 0
    var totalRead: UInt64 = 0
    var totalWritten: UInt64 = 0
    var volumeTotal: UInt64 = 0          // capacity of the boot volume
    var volumeFree: UInt64 = 0
}

/// One full reading of every metric at a point in time.
struct SystemSnapshot: Codable, Equatable {
    var battery = BatterySample()
    var processes = ProcessSample()
    var thermalState: String = "Nominal"
    var uptime: Double = 0
    var timestamp: Date = Date()
    var cpu = CPUSample()
    var memory = MemorySample()
    var gpu = GPUSample()
    var thermal = ThermalSample()
    var fans: [FanReading] = []
    var power = PowerSample()
    var network = NetworkSample()
    var disk = DiskSample()
}

// MARK: - History

/// Fixed-capacity rolling series of Doubles, used to feed the sparklines.
struct Series: Codable, Equatable {
    private(set) var values: [Double] = []
    let capacity: Int

    init(capacity: Int = 1200) { self.capacity = capacity }

    mutating func append(_ v: Double) {
        values.append(v)
        if values.count > capacity {
            values.removeFirst(values.count - capacity)
        }
    }

    mutating func retainLast(_ count: Int) { values = Array(values.suffix(count)) }
    var average: Double {
        let valid = values.filter(\.isFinite)
        return valid.isEmpty ? 0 : valid.reduce(0, +) / Double(valid.count)
    }
    var last: Double { values.last ?? 0 }
    var max: Double { values.filter(\.isFinite).max() ?? 0 }
    var min: Double { values.filter(\.isFinite).min() ?? 0 }
    var isEmpty: Bool { values.isEmpty }
}

/// The set of rolling series the UI graphs. Kept alongside the latest snapshot.
struct MetricHistory {
    var timestamps: [Date] = []
    var cores: [Series] = []
    var clusters: [String: Series] = [:]
    var battery = Series()
    var cpu = Series()
    var gpu = Series()
    var memory = Series()          // used fraction 0...1
    var temperature = Series()     // primary temp °C
    var power = Series()           // total watts
    var networkUp = Series()       // bytes/s
    var networkDown = Series()     // bytes/s
    var diskRead = Series()        // bytes/s
    var diskWrite = Series()       // bytes/s

    mutating func recordGap(at date: Date) {
        timestamps.append(date)
        if timestamps.count > 1200 { timestamps.removeFirst(timestamps.count - 1200) }
        for key in [\MetricHistory.cpu, \.gpu, \.memory, \.temperature, \.power, \.networkUp, \.networkDown, \.diskRead, \.diskWrite, \.battery] {
            self[keyPath: key].append(.nan)
        }
        for i in cores.indices { cores[i].append(.nan) }
        for key in clusters.keys { clusters[key]?.append(.nan) }
    }

    mutating func record(_ s: SystemSnapshot) {
        timestamps.append(s.timestamp)
        if timestamps.count > 1200 { timestamps.removeFirst(timestamps.count - 1200) }
        if cores.count != s.cpu.perCore.count { cores = s.cpu.perCore.map { _ in Series() } }
        for (i, load) in s.cpu.perCore.enumerated() { cores[i].append(load) }
        for cluster in s.cpu.clusters { clusters[cluster.name, default: Series()].append(cluster.usage) }
        battery.append(s.battery.level ?? .nan)
        cpu.append(s.cpu.totalUsage)
        gpu.append(s.gpu.utilization ?? .nan)
        memory.append(s.memory.total > 0 ? Double(s.memory.used) / Double(s.memory.total) : 0)
        temperature.append(s.thermal.cpuTemp ?? s.thermal.gpuTemp ?? .nan)
        power.append(s.power.total ?? s.power.cpu ?? .nan)
        networkUp.append(s.network.uploadBytesPerSec)
        networkDown.append(s.network.downloadBytesPerSec)
        diskRead.append(s.disk.readBytesPerSec)
        diskWrite.append(s.disk.writeBytesPerSec)
    }
}

extension MetricHistory {
    func window(seconds: Double, now: Date) -> MetricHistory {
        var copy = self
        let count = timestamps.filter { now.timeIntervalSince($0) <= seconds }.count
        copy.timestamps = Array(timestamps.suffix(count))
        for key in [\MetricHistory.cpu, \.gpu, \.memory, \.temperature, \.power, \.networkUp, \.networkDown, \.diskRead, \.diskWrite, \.battery] {
            copy[keyPath: key].retainLast(count)
        }
        for i in copy.cores.indices { copy.cores[i].retainLast(count) }
        for key in copy.clusters.keys { copy.clusters[key]?.retainLast(count) }
        return copy
    }
}

struct BatterySample: Codable, Equatable {
    var isPresent = false
    var level: Double?
    var isCharging = false
    var onAC = false
    var health: Double?
    var cycleCount: Int?
    var watts: Double?
    var minutesRemaining: Int?
    var condition: String = "Unavailable"
    var status: String { onAC ? (isCharging ? "Charging" : "Connected to power") : "On battery" }
}

struct ProcessReading: Codable, Equatable, Identifiable {
    var pid: Int32
    var startTime: UInt64
    var name: String
    var cpu: Double? // fraction of ONE core; can exceed 1
    var memory: UInt64
    var id: String { "\(pid)-\(startTime)" }
}

struct ProcessSample: Codable, Equatable {
    var entries: [ProcessReading] = []
    var inaccessibleCount = 0
    var timestamp: Date? = nil
}

// MARK: - Metric identity (sidebar)

/// The selectable metric categories shown in the sidebar.
enum Metric: String, CaseIterable, Identifiable {
    case overview, cpu, gpu, memory, thermal, network, disk, battery, processes
    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .battery: return "Battery"
        case .processes: return "Processes"
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .memory: return "Memory"
        case .thermal: return "Temperature"
        case .network: return "Network"
        case .disk: return "Disk"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .battery: return "battery.75percent"
        case .processes: return "list.bullet.rectangle"
        case .cpu: return "cpu"
        case .gpu: return "square.stack.3d.up"
        case .memory: return "memorychip"
        case .thermal: return "thermometer.medium"
        case .network: return "network"
        case .disk: return "internaldrive"
        }
    }
}
