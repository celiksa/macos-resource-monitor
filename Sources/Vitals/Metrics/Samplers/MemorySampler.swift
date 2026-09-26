import Foundation
import Darwin

/// Physical memory breakdown from `host_statistics64` plus swap from sysctl.
final class MemorySampler: Sampler {
    private let pageSize: UInt64
    private let totalRAM: UInt64

    init() {
        var size: vm_size_t = 0
        host_page_size(mach_host_self(), &size)
        pageSize = UInt64(size)
        totalRAM = ProcessInfo.processInfo.physicalMemory
    }

    func sample() -> MemorySample {
        var out = MemorySample()
        out.total = totalRAM

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return out }

        let wired = UInt64(stats.wire_count) * pageSize
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize
        let purgeable = UInt64(stats.purgeable_count) * pageSize
        let external = UInt64(stats.external_page_count) * pageSize   // file-backed / cached

        out.wired = wired
        out.active = active
        out.inactive = inactive
        out.compressed = compressed
        out.free = free
        out.cached = purgeable + external

        // "App memory" ≈ used memory that isn't wired, compressed, or file-cache.
        // Activity Monitor's Memory Used = app + wired + compressed.
        let appMemory = active + inactive > out.cached ? (active + inactive - out.cached) : 0
        out.appMemory = appMemory
        out.used = min(totalRAM, appMemory + wired + compressed)

        var pressure: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &size, nil, 0) == 0 {
            switch pressure {
            case 1: out.pressureLevel = "Normal"; out.pressure = 0
            case 2: out.pressureLevel = "Warning"; out.pressure = 0.5
            case 4: out.pressureLevel = "Critical"; out.pressure = 1
            default: break
            }
        }

        let swap = Self.swapUsage()
        out.swapTotal = swap.total
        out.swapUsed = swap.used

        return out
    }

    private static func swapUsage() -> (total: UInt64, used: UInt64) {
        var xsw = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &xsw, &size, nil, 0) == 0 else { return (0, 0) }
        return (xsw.xsu_total, xsw.xsu_used)
    }
}
