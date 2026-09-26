import Foundation
import Darwin

/// Per-core and aggregate CPU utilization from `host_processor_info`.
/// Utilization is the delta of busy ticks between two consecutive samples,
/// so the first call establishes a baseline and reports 0.
final class CPUSampler: Sampler {
    private struct Ticks { var user: Double; var system: Double; var idle: Double; var nice: Double }
    private var previous: [Ticks] = []

    private struct Level { let name: String; let count: Int }

    private let chip: String
    /// Performance-level names and counts, highest tier first. Registry logical
    /// CPU IDs supply the mapping; perflevel order never determines CPU IDs.
    private let levels: [Level]
    private let topology = HardwareTopology.readCores()

    init() {
        chip = Self.sysctlString("machdep.cpu.brand_string") ?? "Apple Silicon"
        let n = Self.sysctlInt("hw.nperflevels") ?? 1
        var infos: [Level] = []
        for i in 0..<max(n, 1) {
            let name = Self.sysctlString("hw.perflevel\(i).name") ?? "Cluster \(i)"
            let count = Self.sysctlInt("hw.perflevel\(i).logicalcpu") ?? 0
            if count > 0 { infos.append(Level(name: name, count: count)) }
        }
        levels = infos
    }

    func sample() -> CPUSample {
        var out = CPUSample()
        out.chipName = chip
        out.loadAverage = Self.loadAverage()

        var cpuCount: natural_t = 0
        var infoPtr: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(mach_host_self(),
                                     PROCESSOR_CPU_LOAD_INFO,
                                     &cpuCount, &infoPtr, &infoCount)
        guard kr == KERN_SUCCESS, let infoPtr else { return out }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: infoPtr),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        let cores = Int(cpuCount)
        out.coreCount = cores
        var current: [Ticks] = []
        current.reserveCapacity(cores)

        infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) { ptr in
            for i in 0..<cores {
                let base = i * Int(CPU_STATE_MAX)
                let user = Double(UInt32(bitPattern: ptr[base + Int(CPU_STATE_USER)]))
                let sys  = Double(UInt32(bitPattern: ptr[base + Int(CPU_STATE_SYSTEM)]))
                let idle = Double(UInt32(bitPattern: ptr[base + Int(CPU_STATE_IDLE)]))
                let nice = Double(UInt32(bitPattern: ptr[base + Int(CPU_STATE_NICE)]))
                current.append(Ticks(user: user, system: sys, idle: idle, nice: nice))
            }
        }

        defer { previous = current }
        guard previous.count == cores else { return out }  // baseline call

        var perCore: [Double] = []
        perCore.reserveCapacity(cores)
        var sumUser = 0.0, sumSys = 0.0, sumIdle = 0.0, sumNice = 0.0

        for i in 0..<cores {
            let dUser = Self.delta(current[i].user, previous[i].user)
            let dSys  = Self.delta(current[i].system, previous[i].system)
            let dIdle = Self.delta(current[i].idle, previous[i].idle)
            let dNice = Self.delta(current[i].nice, previous[i].nice)
            let busy = dUser + dSys + dNice
            let total = busy + dIdle
            perCore.append(total > 0 ? (busy / total).clamped(0, 1) : 0)
            sumUser += dUser; sumSys += dSys; sumIdle += dIdle; sumNice += dNice
        }

        out.perCore = perCore
        let grandTotal = sumUser + sumSys + sumIdle + sumNice
        if grandTotal > 0 {
            out.user = sumUser / grandTotal
            out.system = sumSys / grandTotal
            out.nice = sumNice / grandTotal
            out.idle = sumIdle / grandTotal
            out.totalUsage = ((sumUser + sumSys + sumNice) / grandTotal).clamped(0, 1)
        }

        var clusters = HardwareTopology.groups(cores: topology, levels: levels.map { ($0.name, $0.count) }, count: cores)
        out.topologyVerified = !clusters.isEmpty
        if clusters.isEmpty {
            clusters = [CPUCluster(name: "CPU", coreCount: cores, usage: 0, firstCore: 0)]
        }
        for i in clusters.indices { clusters[i].usage = average(clusters[i].indices.map { perCore[$0] }) }
        out.clusters = clusters

        return out
    }

    static func delta(_ current: Double, _ previous: Double) -> Double {
        Double(UInt32(current) &- UInt32(previous))
    }

    private func average<S: Sequence>(_ xs: S) -> Double where S.Element == Double {
        var sum = 0.0, n = 0
        for x in xs { sum += x; n += 1 }
        return n > 0 ? sum / Double(n) : 0
    }

    // MARK: sysctl helpers

    private static func loadAverage() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        var l = [Double](repeating: 0, count: 3)
        if getloadavg(&l, 3) == 3 { loads = l }
        return loads
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return nil }
        return String(cString: buf)
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int = 0
        var size = MemoryLayout<Int>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}
