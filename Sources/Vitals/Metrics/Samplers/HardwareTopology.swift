import Foundation
import IOKit

/// Registry logical CPU IDs identify the corresponding Mach load counters.
/// Never infer CPU ordering from perflevel ordering: it is not an API guarantee.
enum HardwareTopology {
    struct Core { let id: Int; let type: String }

    static func readCores() -> [Core] {
        let root = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/cpus")
        guard root != 0 else { return [] }
        defer { IOObjectRelease(root) }
        var iterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(root, kIODeviceTreePlane, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var cores: [Core] = []
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            defer { IOObjectRelease(entry); entry = IOIteratorNext(iterator) }
            func property(_ key: String) -> Any? {
                IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            }
            guard let id = property("logical-cpu-id") as? NSNumber,
                  let data = property("cluster-type") as? Data,
                  let type = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) else { continue }
            cores.append(Core(id: id.intValue, type: type))
        }
        return cores.sorted { $0.id < $1.id }
    }

    static func groups(cores: [Core], levels: [(name: String, count: Int)], count: Int) -> [CPUCluster] {
        guard cores.count == count, Set(cores.map(\.id)) == Set(0..<count) else { return [] }
        let hasSuper = levels.contains { $0.name.lowercased() == "super" }
        func name(_ type: String) -> String? {
            switch type {
            case "E": return "Efficiency"
            case "M": return "Performance"
            case "P": return hasSuper ? "Super" : "Performance"
            default: return nil
            }
        }
        var result: [CPUCluster] = []
        for level in levels {
            let ids = cores.filter { name($0.type)?.lowercased() == level.name.lowercased() }.map(\.id)
            guard ids.count == level.count, !ids.isEmpty else { return [] }
            result.append(CPUCluster(name: level.name, coreCount: ids.count, usage: 0, firstCore: ids[0], coreIDs: ids))
        }
        guard result.flatMap(\.indices).count == count else { return [] }
        return result
    }
}
