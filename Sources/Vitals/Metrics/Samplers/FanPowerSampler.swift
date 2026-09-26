import Foundation

/// Fan RPM and power draw, read from the SMC.
///
/// - **Fans**: `FNum` gives the count, then per-fan `F<i>Ac` (actual RPM),
///   `F<i>Mn`/`F<i>Mx` (min/max). Machines without fans (or with the keys absent)
///   simply report no fans.
/// - **Power**: known SMC rails only. Missing readings stay nil; unknown P-keys
///   are never guessed to be system power. These interfaces are undocumented.
/// All access is read-only; fan speeds and power settings are never changed.
final class FanPowerSampler: Sampler {

    private let smc = SMC()
    private var opened = false

    /// Cached power-key layout, discovered once on first successful sample so we
    /// don't re-enumerate every interval.
    private var powerKeysResolved = false
    private var totalKey: String?
    private var cpuKey: String?
    private var gpuKey: String?

    init() {
        opened = smc.open()
    }

    func sample() -> (fans: [FanReading], power: PowerSample) {
        // Attempt a (re)open if the first one failed — the SMC may have been busy.
        if !opened { opened = smc.open() }
        guard opened else { return ([], PowerSample()) }

        return (readFans(), readPower())
    }

    // MARK: - Fans

    private func readFans() -> [FanReading] {
        guard let count = smc.readDouble("FNum"), count > 0 else { return [] }
        let n = Int(count.clamped(0, 16))

        var fans: [FanReading] = []
        for i in 0..<n {
            guard let rpm = smc.readDouble("F\(i)Ac"), rpm.isFinite, rpm >= 0 else { continue }
            let minRPM = smc.readDouble("F\(i)Mn")
            let maxRPM = smc.readDouble("F\(i)Mx")
            fans.append(FanReading(name: n == 1 ? "Fan" : "Fan \(i + 1)",
                                   rpm: rpm.rounded(),
                                   minRPM: minRPM.map { $0.rounded() },
                                   maxRPM: maxRPM.map { $0.rounded() }))
        }
        return fans
    }

    // MARK: - Power

    // Well-known candidate keys, tried in order; the first that reads a plausible
    // wattage wins. These lists are intentionally non-overlapping so the same key
    // can't be reported as two different rails.
    //
    // On Apple Silicon laptops the only reliably present rail is the system total
    // (`PSTR`); the discrete CPU/GPU power keys used on Intel Macs are absent, so
    // `cpu`/`gpu` typically stay nil here — that is expected graceful degradation.
    private static let totalCandidates = ["PSTR"]
    private static let cpuCandidates   = ["PCPC", "PCPT", "PC0C", "PCPG", "PCPR"]
    private static let gpuCandidates   = ["PGPC", "PGPR", "PCGC", "PCGM", "PG0R"]

    /// Sanity bound permits desktop as well as notebook power readings.
    private static let maxSystemWatts = 2000.0

    private func readPower() -> PowerSample {
        resolvePowerKeysIfNeeded()

        var out = PowerSample()
        if let k = totalKey, let w = plausibleWatts(k, max: Self.maxSystemWatts) { out.total = w }
        if let k = cpuKey,   let w = plausibleWatts(k, max: Self.maxSystemWatts) { out.cpu = w }
        if let k = gpuKey,   let w = plausibleWatts(k, max: Self.maxSystemWatts) { out.gpu = w }
        return out
    }

    /// Resolve supported, known SMC rails once.
    private func resolvePowerKeysIfNeeded() {
        guard !powerKeysResolved else { return }
        powerKeysResolved = true

        totalKey = Self.totalCandidates.first { plausibleWatts($0, max: Self.maxSystemWatts) != nil }
        cpuKey   = Self.cpuCandidates.first   { plausibleWatts($0, max: Self.maxSystemWatts) != nil }
        gpuKey   = Self.gpuCandidates.first   { plausibleWatts($0, max: Self.maxSystemWatts) != nil }


    }

    /// Read a key and accept it only if it decodes to a physically plausible power
    /// value in watts (0 < w < `max`), only for the known rails above.
    private func plausibleWatts(_ key: String, max: Double) -> Double? {
        guard let value = smc.readDouble(key), value.isFinite, value > 0, value < max else {
            return nil
        }
        return value
    }
}
