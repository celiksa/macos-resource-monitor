import Foundation
import IOKit
import IOKit.ps

final class BatterySampler: Sampler {
    func sample() -> BatterySample {
        var out = BatterySample()
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                      d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
                out.isPresent = true
                if let current = d[kIOPSCurrentCapacityKey] as? Double, let max = d[kIOPSMaxCapacityKey] as? Double, max > 0 {
                    out.level = (current / max).clamped(0, 1)
                }
                out.onAC = d[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
                out.isCharging = d[kIOPSIsChargingKey] as? Bool ?? false
                out.condition = d[kIOPSBatteryHealthKey] as? String ?? "Unavailable"
                let time = d[out.isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey] as? Int
                if let time, time > 0, time < 65535 { out.minutesRemaining = time }
            }
        }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return out }
        defer { IOObjectRelease(service) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let d = props?.takeRetainedValue() as? [String: Any] else { return out }
        out.isPresent = true
        let data = d["BatteryData"] as? [String: Any] ?? [:]
        out.cycleCount = (d["CycleCount"] as? NSNumber)?.intValue
        let full = (d["AppleRawMaxCapacity"] as? NSNumber)?.doubleValue ?? (data["FullChargeCapacity"] as? NSNumber)?.doubleValue
        let design = (d["DesignCapacity"] as? NSNumber)?.doubleValue ?? (data["DesignCapacity"] as? NSNumber)?.doubleValue
        if let full, let design, full > 0, design > 0 { out.health = (full / design).clamped(0, 1) }
        if let voltage = (d["Voltage"] as? NSNumber)?.doubleValue,
           let current = (d["Amperage"] as? NSNumber)?.int64Value {
            let watts = abs(Double(current) * voltage / 1_000_000)
            if watts < 500 { out.watts = watts }
        }
        return out
    }
}
