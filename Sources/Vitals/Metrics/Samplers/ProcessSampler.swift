import Foundation
import Darwin

/// libproc CPU counters use Mach absolute time units. CPU 100% means one busy core.
/// Access to other users' processes may be denied; those rows are counted, not fabricated.
final class ProcessSampler: Sampler {
    private struct Previous { let start: UInt64; let cpu: UInt64; let time: Double }
    private let secondsPerTick: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(max(1, timebase.denom)) / 1_000_000_000
    }()
    private var previous: [Int32: Previous] = [:]
    private var cached = ProcessSample()
    private var lastSample = -Double.infinity

    func sample() -> ProcessSample {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSample >= 2 else { return cached }
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { cached = ProcessSample(); return cached }
        var pids = [Int32](repeating: 0, count: Int(count) + 256)
        let bytes = Int32(pids.count * MemoryLayout<Int32>.stride)
        let found = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, bytes) }
        guard found > 0 else { cached = ProcessSample(); return cached }
        var next: [Int32: Previous] = [:]
        var result = ProcessSample()
        result.timestamp = Date()
        for pid in pids.prefix(min(Int(found), pids.count)) where pid > 0 {
            var usage = rusage_info_v2()
            let status = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) }
            }
            guard status == 0 else { result.inaccessibleCount += 1; continue }
            let cpuTime = usage.ri_user_time &+ usage.ri_system_time
            var load: Double? = nil
            if let old = previous[pid], old.start == usage.ri_proc_start_abstime, cpuTime >= old.cpu, now > old.time {
                load = Double(cpuTime - old.cpu) * secondsPerTick / (now - old.time)
            }
            var buffer = [CChar](repeating: 0, count: 1024)
            let length = proc_name(pid, &buffer, UInt32(buffer.count))
            let name = length > 0 ? String(cString: buffer) : "Process \(pid)"
            result.entries.append(ProcessReading(pid: pid, startTime: usage.ri_proc_start_abstime, name: name, cpu: load, memory: usage.ri_phys_footprint))
            next[pid] = Previous(start: usage.ri_proc_start_abstime, cpu: cpuTime, time: now)
        }
        previous = next
        cached = result
        lastSample = now
        return result
    }
}
