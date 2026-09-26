import Testing
import Foundation
import Darwin
@testable import Vitals

struct MetricsTests {
    @Test func m5TopologyUsesLogicalIDs() {
        let cores = (0..<18).map { HardwareTopology.Core(id: $0, type: $0 < 12 ? "M" : "P") }
        let clusters = HardwareTopology.groups(cores: cores.reversed(), levels: [("Super", 6), ("Performance", 12)], count: 18)
        #expect(clusters.count == 2)
        #expect(Set(clusters[0].indices) == Set(12..<18))
        #expect(Set(clusters[1].indices) == Set(0..<12))
    }

    @Test func earlierAppleSiliconAndNoncontiguousIDs() {
        let cores = [HardwareTopology.Core(id: 0, type: "E"), .init(id: 1, type: "P"), .init(id: 2, type: "E"), .init(id: 3, type: "P")]
        let clusters = HardwareTopology.groups(cores: cores, levels: [("Performance", 2), ("Efficiency", 2)], count: 4)
        #expect(clusters.map(\.indices) == [[1, 3], [0, 2]])
    }

    @Test func unknownOrMismatchedTopologyNeverGetsInventedLabels() {
        #expect(HardwareTopology.groups(cores: [.init(id: 0, type: "X")], levels: [("Performance", 1)], count: 1).isEmpty)
        #expect(HardwareTopology.groups(cores: [.init(id: 0, type: "P")], levels: [("Performance", 2)], count: 2).isEmpty)
        #expect(HardwareTopology.groups(cores: [.init(id: 1, type: "P")], levels: [("Performance", 1)], count: 1).isEmpty)
    }

    @Test func cpuTickRollover() {
        #expect(CPUSampler.delta(4, Double(UInt32.max - 3)) == 8)
        #expect(CPUSampler.delta(20, 10) == 10)
    }

    @Test func networkResetAndNewInterfaceDoNotSpike() {
        #expect(NetworkSampler.rate(8_000_000_000, nil, 1) == 0)
        #expect(NetworkSampler.rate(12, 8_000_000_000, 1) == 0)
        #expect(NetworkSampler.rate(5_000_000_000, 4_000_000_000, 2) == 500_000_000)
        #expect(NetworkSampler.rate(100, 1, 0) == 0)
    }

    @Test func routeParserSkipsShortAddressMessages() {
        var short = [UInt8](repeating: 0, count: 60)
        short[0] = 60; short[3] = UInt8(RTM_NEWADDR)
        var info = if_msghdr2()
        info.ifm_msglen = UInt16(MemoryLayout<if_msghdr2>.size)
        info.ifm_type = UInt8(RTM_IFINFO2)
        info.ifm_flags = IFF_UP
        info.ifm_index = 4
        info.ifm_data.ifi_ibytes = 6_000_000_000
        info.ifm_data.ifi_obytes = 9_000_000_000
        let bytes = short + withUnsafeBytes(of: info) { Array($0) }
        let parsed = NetworkSampler.decode(bytes, nameForIndex: { _ in "en0" })
        #expect(parsed["en0"]?.input == 6_000_000_000)
        #expect(parsed["en0"]?.output == 9_000_000_000)
        #expect(NetworkSampler.decode([0, 0, 0, 0]).isEmpty)
    }

    @Test func historyWindowUsesTimestampsAndKeepsMissingGPUGaps() {
        var history = MetricHistory()
        let start = Date(timeIntervalSince1970: 1_000)
        for i in 0..<5 {
            var s = SystemSnapshot()
            s.timestamp = start.addingTimeInterval(Double(i) * 30)
            s.cpu.perCore = [Double(i) / 10]
            s.gpu.utilization = i == 3 ? nil : 0.5
            history.record(s)
        }
        let window = history.window(seconds: 60, now: start.addingTimeInterval(120))
        #expect(window.timestamps.count == 3)
        #expect(window.cpu.values.count == 3)
        #expect(window.cores[0].values == [0.2, 0.3, 0.4])
        #expect(window.gpu.values[1].isNaN)
        #expect(window.gpu.max == 0.5)
    }

    @Test func pauseGapKeepsAllSeriesAligned() {
        var history = MetricHistory()
        var sample = SystemSnapshot()
        sample.cpu.perCore = [0.5]
        sample.cpu.clusters = [.init(name: "CPU", coreCount: 1, usage: 0.5, firstCore: 0)]
        history.record(sample)
        history.recordGap(at: sample.timestamp.addingTimeInterval(30))
        sample.timestamp = sample.timestamp.addingTimeInterval(60)
        history.record(sample)
        #expect(history.timestamps.count == 3)
        #expect(history.cpu.values[1].isNaN)
        #expect(history.memory.values[1].isNaN)
        #expect(history.cores[0].values[1].isNaN)
        #expect(history.clusters["CPU"]?.values[1].isNaN == true)
    }

    @Test func historyIsBounded() {
        var s = Series(capacity: 3)
        for i in 0..<10 { s.append(Double(i)) }
        #expect(s.values == [7, 8, 9])
        var history = MetricHistory()
        for _ in 0..<1210 { history.record(SystemSnapshot()) }
        #expect(history.timestamps.count == 1200)
        #expect(history.cpu.values.count == 1200)
    }

    @Test func unavailableGPUIsNotZeroAndJSONEncodes() throws {
        let snapshot = SystemSnapshot()
        #expect(snapshot.gpu.utilization == nil)
        #expect(Format.percent(snapshot.gpu.utilization) == "—")
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SystemSnapshot.self, from: data)
        #expect(decoded.gpu.utilization == nil)
    }

    @Test func processCPUIsOneCoreNormalized() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/yes")
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        try child.run()
        defer { child.terminate(); child.waitUntilExit() }
        let sampler = ProcessSampler()
        _ = sampler.sample()
        Thread.sleep(forTimeInterval: 2.2)
        let sample = sampler.sample()
        let row = try #require(sample.entries.first { $0.pid == child.processIdentifier })
        let cpu = try #require(row.cpu)
        #expect(cpu > 0.3 && cpu < 1.3)
        #expect(row.memory > 0)
    }

    @Test @MainActor func historySelectionAndClear() {
        let engine = MetricsEngine()
        var s = SystemSnapshot()
        s.timestamp = Date(timeIntervalSince1970: 1000)
        engine.ingest(s)
        s.timestamp = s.timestamp.addingTimeInterval(90)
        engine.ingest(s)
        engine.historySeconds = 60
        #expect(engine.history.timestamps.count == 1)
        engine.historySeconds = 120
        #expect(engine.history.timestamps.count == 2)
        engine.clearHistory()
        #expect(engine.history.timestamps.isEmpty)
        #expect(engine.snapshot.timestamp == s.timestamp)
    }
}
