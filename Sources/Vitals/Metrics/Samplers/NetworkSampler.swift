import Foundation
import Darwin

/// 64-bit route-interface counters avoid getifaddrs' 32-bit byte counter rollover.
/// Delta per interface avoids spikes when an interface appears or disappears.
final class NetworkSampler: Sampler {
    struct Counter { var input: UInt64; var output: UInt64 }
    private var previous: [String: Counter] = [:]
    private var lastTime: Double?

    func sample() -> NetworkSample {
        let current = Self.readCounters()
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = lastTime.map { now - $0 } ?? 0
        var out = NetworkSample()
        for (name, value) in current.sorted(by: { $0.key < $1.key }) {
            let old = previous[name]
            let down = Self.rate(value.input, old?.input, elapsed)
            let up = Self.rate(value.output, old?.output, elapsed)
            // Wired / Wi-Fi interfaces. Excludes VPN tunnels, peer-to-peer and bridges
            // from totals so the same packets are not counted at multiple layers.
            let physical = name.hasPrefix("en")
            out.interfaces.append(NetworkInterface(name: name, download: down, upload: up, totalIn: value.input, totalOut: value.output, includedInTotal: physical))
            if physical {
                out.downloadBytesPerSec += down; out.uploadBytesPerSec += up
                out.totalDownloaded &+= value.input; out.totalUploaded &+= value.output
            }
        }
        out.primaryInterface = out.interfaces.filter(\.includedInTotal).max {
            let lhs = $0.download + $0.upload, rhs = $1.download + $1.upload
            return lhs == rhs ? ($0.totalIn &+ $0.totalOut) < ($1.totalIn &+ $1.totalOut) : lhs < rhs
        }?.name
        previous = current
        lastTime = now
        return out
    }

    static func rate(_ current: UInt64, _ previous: UInt64?, _ elapsed: Double) -> Double {
        guard let previous, elapsed > 0, current >= previous else { return 0 }
        return Double(current - previous) / elapsed
    }

    private static func readCounters() -> [String: Counter] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return [:] }
        var bytes = [UInt8](repeating: 0, count: size)
        let result = bytes.withUnsafeMutableBytes { sysctl(&mib, UInt32(mib.count), $0.baseAddress, &size, nil, 0) }
        guard result == 0 else { return [:] }
        return Self.decode(Array(bytes.prefix(size)))
    }

    static func interfaceName(_ index: UInt32) -> String? {
        var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
        guard if_indextoname(index, &name) != nil else { return nil }
        return String(cString: name)
    }

    static func decode(_ bytes: [UInt8], nameForIndex: (UInt32) -> String? = interfaceName) -> [String: Counter] {
        let size = bytes.count
        return bytes.withUnsafeBytes { raw in
            var offset = 0
            var counters: [String: Counter] = [:]
            while offset + 4 <= size {
                let length = Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                let type = raw[offset + 3]
                guard length >= 4, offset + length <= size else { break }
                defer { offset += length }
                guard type == RTM_IFINFO2, length >= MemoryLayout<if_msghdr2>.size else { continue }
                let info = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                guard info.ifm_flags & IFF_UP != 0, info.ifm_flags & IFF_LOOPBACK == 0 else { continue }
                guard let name = nameForIndex(UInt32(info.ifm_index)) else { continue }
                counters[name] = Counter(input: info.ifm_data.ifi_ibytes, output: info.ifm_data.ifi_obytes)
            }
            return counters
        }
    }
}
