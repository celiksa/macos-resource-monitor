import Foundation
import Combine

/// Owns every sampler and produces a full `SystemSnapshot` on demand.
/// Not main-actor isolated so it can run on a background task.
final class SamplerSet {
    let cpu = CPUSampler()
    let memory = MemorySampler()
    let gpu = GPUSampler()
    let thermal = ThermalSampler()
    let fanPower = FanPowerSampler()
    let network = NetworkSampler()
    let disk = DiskSampler()
    let battery = BatterySampler()
    let processes = ProcessSampler()
    private let lock = NSLock()

    /// Sample everything once and assemble a snapshot. Delta-based samplers
    /// (cpu, network, disk) return baseline/zero values on their first call.
    func sampleAll() -> SystemSnapshot {
        lock.lock()
        defer { lock.unlock() }
        var s = SystemSnapshot()
        s.timestamp = Date()
        s.cpu = cpu.sample()
        s.memory = memory.sample()
        s.gpu = gpu.sample()
        s.thermal = thermal.sample()
        let fp = fanPower.sample()
        s.fans = fp.fans
        s.power = fp.power
        s.network = network.sample()
        s.disk = disk.sample()
        s.battery = battery.sample()
        s.processes = processes.sample()
        s.uptime = ProcessInfo.processInfo.systemUptime
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: s.thermalState = "Nominal"
        case .fair: s.thermalState = "Fair"
        case .serious: s.thermalState = "Serious"
        case .critical: s.thermalState = "Critical"
        @unknown default: s.thermalState = "Unknown"
        }
        return s
    }
}

/// Drives sampling on a timer and publishes the latest snapshot + rolling history
/// to the SwiftUI views on the main actor.
@MainActor
final class MetricsEngine: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot()
    @Published private(set) var recordedHistory = MetricHistory()
    @Published var historySeconds: Double = 120 { didSet { refreshHistory() } }
    @Published private(set) var history = MetricHistory()
    private func refreshHistory() { history = recordedHistory.window(seconds: historySeconds, now: snapshot.timestamp) }
    @Published var exportError: String?
    private var generation = 0
    @Published private(set) var isRunning = false

    /// Sampling interval in seconds. Changes take effect on the next sampling cycle.
    @Published var interval: Double = 1.0 {
        didSet {
            guard Self.intervalOptions.contains(interval) else { interval = 1; return }
            UserDefaults.standard.set(interval, forKey: "samplingInterval")
        }
    }

    init() {
        let stored = UserDefaults.standard.double(forKey: "samplingInterval")
        if Self.intervalOptions.contains(stored) { interval = stored }
    }

    static let intervalOptions: [Double] = [0.5, 1.0, 2.0, 5.0]

    private let set = SamplerSet()
    private var loop: Task<Void, Never>?

    func start() {
        guard loop == nil else { return }
        isRunning = true
        generation += 1
        let token = generation
        let set = self.set
        loop = Task { [weak self] in
            var firstPublication = true
            // Prime delta-based samplers, then let a short beat pass so the first
            // displayed values are real rather than baseline zeros.
            _ = await Task.detached(priority: .utility) { set.sampleAll() }.value
            try? await Task.sleep(nanoseconds: 200_000_000)

            while !Task.isCancelled {
                let snap = await Task.detached(priority: .utility) { set.sampleAll() }.value
                guard let self, !Task.isCancelled, self.generation == token else { return }
                if firstPublication, let previous = self.recordedHistory.timestamps.last {
                    self.recordedHistory.recordGap(at: previous.addingTimeInterval(snap.timestamp.timeIntervalSince(previous) / 2))
                }
                firstPublication = false
                self.snapshot = snap
                self.recordedHistory.record(snap)
                self.refreshHistory()
                let seconds = self.interval
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
        }
    }

    func stop() {
        generation += 1
        loop?.cancel()
        loop = nil
        isRunning = false
    }

    /// Directly publish a snapshot (used by headless snapshot rendering).
    func ingest(_ snap: SystemSnapshot) {
        snapshot = snap
        recordedHistory.record(snap)
        refreshHistory()
    }

    /// Access to the underlying sampler set for synchronous, loop-free sampling.
    var samplers: SamplerSet { self.set }

    func clearHistory() { recordedHistory = MetricHistory(); refreshHistory() }

    var historySpan: String {
        guard let first = history.timestamps.first, let last = history.timestamps.last else { return "Waiting for samples" }
        let seconds = max(0, Int(last.timeIntervalSince(first)))
        return seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s of history" : "\(seconds)s of history"
    }

    func restart() {
        stop()
        start()
    }

    /// A compact string for the menu-bar label, e.g. "CPU 47%  GPU 25%  62°".
    var menuBarSummary: String {
        let cpu = Format.percent(snapshot.cpu.totalUsage)
        let gpu = Format.percent(snapshot.gpu.utilization)
        let temp = Format.temp(snapshot.thermal.cpuTemp ?? snapshot.thermal.gpuTemp)
        return "\(cpu) · \(gpu) · \(temp)"
    }
}
