import Foundation
import IOKit

/// Temperature sensors for Apple Silicon.
///
/// The reliable source on Apple Silicon is the IOKit **HID thermal sensors**
/// exposed through `IOHIDEventSystemClient` — the same feed Apple's own tools use.
/// SMC temperature keys on M-series are sparse and inconsistently named, so HID is
/// the primary (and here, only) source. Uses undocumented sensor interfaces; availability varies by OS.
///
/// The relevant `IOHIDEventSystemClient`/`IOHIDServiceClient` symbols ship in the
/// IOKit framework but are absent from the Swift overlay, so we bind them at
/// runtime via `dlsym` (the most portable option — no fragile `@_silgen_name`).
final class ThermalSampler: Sampler {

    private let hid = HIDThermal()

    func sample() -> ThermalSample {
        var out = ThermalSample()

        // Read every HID temperature sensor, keeping only physically plausible ones.
        let raw = hid.readSensors().filter { $0.celsius >= 1 && $0.celsius <= 120 }

        // The HID feed exposes several services per logical sensor, so the same
        // Product name appears multiple times. Collapse duplicates by averaging —
        // this also guarantees unique names (TempReading.id == name), which the
        // SwiftUI list relies on.
        let readings = Self.deduplicate(raw)
        out.sensors = readings

        // Representative CPU / SoC temp: average of the die/core sensors.
        let cpu = readings.filter { Self.isCPU($0.name) }
        if !cpu.isEmpty {
            out.cpuTemp = cpu.map(\.celsius).reduce(0, +) / Double(cpu.count)
        }

        // Representative GPU temp: average of any GPU sensors.
        let gpu = readings.filter { Self.isGPU($0.name) }
        if !gpu.isEmpty {
            out.gpuTemp = gpu.map(\.celsius).reduce(0, +) / Double(gpu.count)
        }

        return out
    }

    /// Average sensors that share a name and return them sorted by name.
    private static func deduplicate(_ readings: [TempReading]) -> [TempReading] {
        var sums: [String: (total: Double, count: Int)] = [:]
        for r in readings {
            let acc = sums[r.name] ?? (0, 0)
            sums[r.name] = (acc.total + r.celsius, acc.count + 1)
        }
        return sums
            .map { TempReading(name: $0.key, celsius: $0.value.total / Double($0.value.count)) }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Sensor classification
    //
    // Sensor Product names vary by Mac model. On Apple Silicon they can be the
    // cluster names ("pACC MTR Temp Sensor", "eACC …", "SOC MTR …", "GPU MTR …")
    // or, as on the M-series laptops, per-die names like "PMU tdie3". We match
    // loosely on all of those hints.

    private static func isCPU(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("cpu") || n.contains("pacc") || n.contains("eacc")
            || n.contains("soc") || n.contains("acc ") || n.contains("die")
    }

    private static func isGPU(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("gpu")
    }
}

// MARK: - HID thermal sensor client

/// Thin wrapper over the undocumented `IOHIDEventSystemClient`
/// temperature API, bound lazily via `dlsym`. All calls are guarded; if a symbol is
/// missing (future OS change) the whole thing degrades to "no sensors".
private final class HIDThermal {

    // AppleVendor HID usage constants for thermal sensors.
    private let kHIDPage_AppleVendor: Int32 = 0xff00
    private let kHIDUsage_AppleVendor_TemperatureSensor: Int32 = 0x0005
    private let kIOHIDEventTypeTemperature: Int64 = 15

    // MARK: dlsym-bound function pointers

    private typealias CreateFn = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias SetMatchingFn = @convention(c) (AnyObject?, CFDictionary?) -> Void
    private typealias CopyServicesFn = @convention(c) (AnyObject?) -> Unmanaged<CFArray>?
    private typealias CopyPropertyFn = @convention(c) (AnyObject?, CFString?) -> Unmanaged<CFTypeRef>?
    private typealias CopyEventFn = @convention(c) (AnyObject?, Int64, Int32, Int32) -> Unmanaged<AnyObject>?
    private typealias EventGetFloatFn = @convention(c) (AnyObject?, Int64) -> Double

    private let create: CreateFn?
    private let setMatching: SetMatchingFn?
    private let copyServices: CopyServicesFn?
    private let copyProperty: CopyPropertyFn?
    private let copyEvent: CopyEventFn?
    private let getFloat: EventGetFloatFn?

    private let client: AnyObject?

    init() {
        // IOKit is already linked, but open a handle for symbol lookup regardless.
        let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY)

        func bind<T>(_ name: String, _ type: T.Type) -> T? {
            guard let sym = dlsym(handle, name) else { return nil }
            return unsafeBitCast(sym, to: T.self)
        }

        create = bind("IOHIDEventSystemClientCreate", CreateFn.self)
        setMatching = bind("IOHIDEventSystemClientSetMatching", SetMatchingFn.self)
        copyServices = bind("IOHIDEventSystemClientCopyServices", CopyServicesFn.self)
        copyProperty = bind("IOHIDServiceClientCopyProperty", CopyPropertyFn.self)
        copyEvent = bind("IOHIDServiceClientCopyEvent", CopyEventFn.self)
        getFloat = bind("IOHIDEventGetFloatValue", EventGetFloatFn.self)

        // Create the event system client once and reuse it across samples.
        client = create?(kCFAllocatorDefault)?.takeRetainedValue()
    }

    /// Read all temperature-sensor services and their current °C values.
    func readSensors() -> [TempReading] {
        guard let client,
              let setMatching, let copyServices,
              let copyProperty, let copyEvent, let getFloat else { return [] }

        // Match AppleVendor temperature sensors.
        let matching: [String: Any] = [
            "PrimaryUsagePage": kHIDPage_AppleVendor,
            "PrimaryUsage": kHIDUsage_AppleVendor_TemperatureSensor
        ]
        setMatching(client, matching as CFDictionary)

        guard let services = copyServices(client)?.takeRetainedValue() as? [AnyObject] else {
            return []
        }

        var results: [TempReading] = []
        for service in services {
            // Name via the "Product" property.
            let nameRef = copyProperty(service, "Product" as CFString)?.takeRetainedValue()
            let name = (nameRef as? String) ?? "Sensor \(results.count)"

            // Current temperature event; field selector is (type << 16).
            guard let event = copyEvent(service, kIOHIDEventTypeTemperature, 0, 0)?.takeRetainedValue() else {
                continue
            }
            let celsius = getFloat(event, kIOHIDEventTypeTemperature << 16)
            guard celsius.isFinite else { continue }

            results.append(TempReading(name: name, celsius: celsius))
        }
        return results
    }
}
