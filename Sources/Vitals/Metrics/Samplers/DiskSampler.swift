import Foundation
import IOKit
import IOKit.storage

/// Aggregate disk throughput from `IOBlockStorageDriver` statistics, plus boot
/// volume capacity. Rates are deltas between consecutive samples.
final class DiskSampler: Sampler {
    private var lastRead: UInt64 = 0
    private var lastWrite: UInt64 = 0
    private var lastTime: TimeInterval = 0
    private var primed = false

    func sample() -> DiskSample {
        var out = DiskSample()
        let (read, write) = Self.readCounters()
        out.totalRead = read
        out.totalWritten = write

        let now = ProcessInfo.processInfo.systemUptime
        if primed, now > lastTime {
            let dt = now - lastTime
            out.readBytesPerSec = (read >= lastRead ? Double(read - lastRead) : 0) / dt
            out.writeBytesPerSec = (write >= lastWrite ? Double(write - lastWrite) : 0) / dt
        }
        lastRead = read
        lastWrite = write
        lastTime = now
        primed = true

        let capacity = Self.bootVolumeCapacity()
        out.volumeTotal = capacity.total
        out.volumeFree = capacity.free

        return out
    }

    private static func readCounters() -> (read: UInt64, write: UInt64) {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("IOBlockStorageDriver"),
                                           &iterator) == KERN_SUCCESS else { return (0, 0) }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any],
                  let stats = dict["Statistics"] as? [String: Any] else { continue }

            if let r = (stats["Bytes (Read)"] as? NSNumber)?.uint64Value { totalRead += r }
            if let w = (stats["Bytes (Write)"] as? NSNumber)?.uint64Value { totalWrite += w }
        }
        return (totalRead, totalWrite)
    }

    private static func bootVolumeCapacity() -> (total: UInt64, free: UInt64) {
        let url = URL(fileURLWithPath: "/")
        guard let vals = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey
        ]) else { return (0, 0) }
        let total = UInt64(vals.volumeTotalCapacity ?? 0)
        let free = min(total, UInt64(max(0, vals.volumeAvailableCapacityForImportantUsage ?? 0)))
        return (total, free)
    }
}
