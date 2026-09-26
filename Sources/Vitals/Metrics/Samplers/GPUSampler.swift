import Foundation
import IOKit
import Metal

/// Integrated GPU utilization + memory from the IORegistry `IOAccelerator`
/// `PerformanceStatistics` dictionary. Verified on Apple Silicon (no sudo required).
final class GPUSampler: Sampler {
    func sample() -> GPUSample {
        var out = GPUSample()
        if let device = MTLCreateSystemDefaultDevice() {
            out.name = device.name
            out.unifiedMemory = device.hasUnifiedMemory
        }

        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("IOAccelerator"),
                                           &iterator) == KERN_SUCCESS else {
            return out
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any] else { continue }

            out.coreCount = (dict["gpu-core-count"] as? NSNumber)?.intValue
            out.name = Self.deviceName(dict) ?? out.name
            guard let stats = dict["PerformanceStatistics"] as? [String: Any] else { continue }

            func number(_ key: String) -> Double? { (stats[key] as? NSNumber)?.doubleValue }

            // Prefer the entry that actually reports utilization (the active GPU).
            if let util = number("Device Utilization %") {
                out.utilization = (util / 100).clamped(0, 1)
                out.rendererUtilization = number("Renderer Utilization %").map { ($0 / 100).clamped(0, 1) }
                out.tilerUtilization = number("Tiler Utilization %").map { ($0 / 100).clamped(0, 1) }
                if let inUse = number("In use system memory") { out.inUseMemory = UInt64(max(0, inUse)) }
                if let alloc = number("Alloc system memory") { out.allocatedMemory = UInt64(max(0, alloc)) }
                out.name = Self.deviceName(dict) ?? out.name
                break
            }
        }

        if out.name.isEmpty { out.name = Self.chipName() }
        return out
    }

    private static func deviceName(_ dict: [String: Any]) -> String? {
        if let data = dict["model"] as? Data, let s = String(data: data, encoding: .utf8) {
            return s.trimmingCharacters(in: .controlCharacters.union(.whitespaces))
        }
        if let s = dict["model"] as? String { return s }
        return nil
    }

    private static func chipName() -> String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else { return "GPU" }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0) == 0 else { return "GPU" }
        return String(cString: buf)
    }
}
