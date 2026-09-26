import Foundation
import IOKit

/// Minimal, pure-Swift reader for Apple's `AppleSMC` (System Management Controller).
///
/// Talks to the SMC over a user-client connection using only public IOKit — no
/// private frameworks, no sudo. This is enough to read fan RPM and (where the
/// firmware exposes them) power rails. Temperatures on Apple Silicon are far more
/// reliably read from the HID thermal sensors (see `ThermalSampler`), so this type
/// focuses on numeric key decode + enumeration.
///
/// Usage:
/// ```
/// let smc = SMC()
/// guard smc.open() else { return }
/// defer { smc.close() }
/// let rpm = smc.readDouble("F0Ac")
/// ```
///
/// Everything degrades gracefully: an unavailable key or a closed connection just
/// yields `nil` rather than throwing or crashing.
final class SMC {

    // MARK: - Wire structures
    //
    // These mirror the C structs the AppleSMC user client expects for selector 2
    // (kSMCHandleYPCEvent). Layout must match byte-for-byte, hence the explicit
    // tuple-based fixed arrays.

    /// SMC keys are FourCC codes; their "info" describes the payload we get back.
    private struct SMCVersion {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    private struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    private struct SMCKeyInfoData {
        var dataSize: UInt32 = 0        // IOByteCount
        var dataType: UInt32 = 0        // FourCC of the value's type, e.g. 'flt '
        var dataAttributes: UInt8 = 0
        // Explicit tail padding. In C this struct is 12 bytes; without these bytes
        // Swift reuses the tail padding for the *next* field in `SMCKeyData`, which
        // shifts `result`/`data8`/`data32` and breaks the 80-byte ABI the kernel
        // expects (IOConnectCallStructMethod would return kIOReturnBadArgument).
        var reserved0: UInt8 = 0
        var reserved1: UInt8 = 0
        var reserved2: UInt8 = 0
    }

    /// 32-byte value buffer used by the user client. We over-provision and only
    /// read `dataSize` bytes back.
    private struct SMCBytes {
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    /// The top-level struct passed to `IOConnectCallStructMethod`. Field order and
    /// packing here are load-bearing — this matches the AppleSMC ABI.
    private struct SMCKeyData {
        var key: UInt32 = 0
        var vers = SMCVersion()
        var pLimitData = SMCPLimitData()
        var keyInfo = SMCKeyInfoData()
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0            // selector for the YPC event (5/8/9/…)
        var data32: UInt32 = 0         // used as the index for SMCKeyByIndex
        var bytes = SMCBytes()
    }

    // MARK: - Selectors (SMCKeyData.data8)

    private enum Selector {
        static let kSMCHandleYPCEvent: UInt32 = 2   // IOConnectCallStructMethod selector
        static let kSMCReadKey: UInt8 = 5
        static let kSMCGetKeyFromIndex: UInt8 = 8
        static let kSMCGetKeyInfo: UInt8 = 9
    }

    // MARK: - Decoded value

    /// A raw SMC value: its FourCC type plus the significant bytes.
    struct Value {
        let type: String            // e.g. "flt ", "ui8 ", "sp78"
        let bytes: [UInt8]

        /// Best-effort numeric decode across the SMC types we care about.
        var double: Double? {
            SMC.decode(type: type, bytes: bytes)
        }
    }

    // MARK: - Connection state

    private var connection: io_connect_t = 0
    private var isOpen = false

    // MARK: - Lifecycle

    /// Open a connection to `AppleSMC`. Returns `false` if the service is missing
    /// or the user client can't be created (both are non-fatal for the app).
    @discardableResult
    func open() -> Bool {
        guard !isOpen else { return true }

        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        let kr = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard kr == kIOReturnSuccess, connection != 0 else { return false }

        isOpen = true
        return true
    }

    func close() {
        guard isOpen else { return }
        IOServiceClose(connection)
        connection = 0
        isOpen = false
    }

    deinit { close() }

    // MARK: - FourCC helpers

    /// Pack a 4-character SMC key ("F0Ac") into its big-endian UInt32 code.
    static func fourCC(_ key: String) -> UInt32 {
        var result: UInt32 = 0
        for scalar in key.utf8.prefix(4) {
            result = (result << 8) | UInt32(scalar)
        }
        return result
    }

    /// Reverse of `fourCC` — used to render enumerated key indices back to names.
    static func string(fromFourCC code: UInt32) -> String {
        let chars = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        return String(bytes: chars, encoding: .ascii) ?? ""
    }

    // MARK: - Core call

    /// Issue one YPC event against the user client, filling `output` from the SMC.
    private func call(_ input: inout SMCKeyData) -> SMCKeyData? {
        guard isOpen else { return nil }

        var output = SMCKeyData()
        var outputSize = MemoryLayout<SMCKeyData>.stride

        let kr = withUnsafePointer(to: &input) { inPtr in
            IOConnectCallStructMethod(connection,
                                      Selector.kSMCHandleYPCEvent,
                                      inPtr,
                                      MemoryLayout<SMCKeyData>.stride,
                                      &output,
                                      &outputSize)
        }
        guard kr == kIOReturnSuccess, output.result == 0 else { return nil }
        return output
    }

    // MARK: - Key info

    /// Fetch the data type + size the SMC reports for `key`.
    private func keyInfo(_ key: UInt32) -> SMCKeyInfoData? {
        var input = SMCKeyData()
        input.key = key
        input.data8 = Selector.kSMCGetKeyInfo
        guard let out = call(&input) else { return nil }
        return out.keyInfo
    }

    // MARK: - Public reads

    /// Read the raw value for a 4-char key, or `nil` if the key doesn't exist.
    func read(_ key: String) -> Value? {
        read(SMC.fourCC(key))
    }

    func read(_ key: UInt32) -> Value? {
        guard let info = keyInfo(key), info.dataSize > 0 else { return nil }

        var input = SMCKeyData()
        input.key = key
        input.keyInfo = info
        input.data8 = Selector.kSMCReadKey
        guard let out = call(&input) else { return nil }

        let size = Int(info.dataSize)
        let bytes = SMC.extractBytes(out.bytes, count: size)
        let type = SMC.string(fromFourCC: info.dataType)
        return Value(type: type, bytes: bytes)
    }

    /// Convenience: decode a key straight to `Double`, or `nil`.
    func readDouble(_ key: String) -> Double? {
        read(key)?.double
    }

    // MARK: - Enumeration

    /// Total number of keys the SMC exposes (the `#KEY` count).
    func keyCount() -> Int {
        guard let value = read("#KEY"), let n = value.double else { return 0 }
        return Int(n)
    }

    /// The FourCC key name at `index` in the SMC's internal table.
    func key(atIndex index: Int) -> String? {
        var input = SMCKeyData()
        input.data8 = Selector.kSMCGetKeyFromIndex
        input.data32 = UInt32(index)
        guard let out = call(&input), out.key != 0 else { return nil }
        return SMC.string(fromFourCC: out.key)
    }

    /// Enumerate every key name. Handy for discovery on unfamiliar hardware where
    /// Apple Silicon key names differ from the classic Intel set.
    func allKeys() -> [String] {
        let count = keyCount()
        guard count > 0 else { return [] }
        var keys: [String] = []
        keys.reserveCapacity(count)
        for i in 0..<count {
            if let k = key(atIndex: i) { keys.append(k) }
        }
        return keys
    }

    // MARK: - Byte extraction & decoding

    /// Copy `count` bytes out of the fixed 32-byte SMC tuple.
    private static func extractBytes(_ tuple: SMCBytes, count: Int) -> [UInt8] {
        let n = min(max(count, 0), 32)
        var result = [UInt8]()
        result.reserveCapacity(n)
        withUnsafeBytes(of: tuple.bytes) { raw in
            for i in 0..<n { result.append(raw[i]) }
        }
        return result
    }

    /// Decode the SMC numeric types we encounter on Apple Silicon.
    ///
    /// - `flt ` : IEEE-754 Float32, little-endian.
    /// - `ui8 `/`ui16`/`ui32`/`ui64` : unsigned ints, big-endian.
    /// - `si8 `/`si16` : signed ints, big-endian.
    /// - `spXX`/`fpXX` : fixed-point, big-endian, where the trailing hex digits give
    ///   the integer/fraction bit split (e.g. `sp78` = 1 sign + 7 int + 8 frac).
    static func decode(type: String, bytes: [UInt8]) -> Double? {
        guard !bytes.isEmpty else { return nil }
        let t = type.trimmingCharacters(in: .whitespaces)

        switch t {
        case "flt":
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8)
                     | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
            return Double(Float(bitPattern: bits))

        case "ui8", "ui16", "ui32", "ui64":
            var value: UInt64 = 0
            for b in bytes { value = (value << 8) | UInt64(b) }   // big-endian
            return Double(value)

        case "si8", "si16", "si32":
            var value: Int64 = 0
            for b in bytes { value = (value << 8) | Int64(b) }
            // sign-extend from the top bit of the payload
            let bits = bytes.count * 8
            if bits < 64, (value & (1 << (bits - 1))) != 0 {
                value -= (Int64(1) << bits)
            }
            return Double(value)

        default:
            // Fixed-point: spXX (signed) or fpXX (unsigned), e.g. sp78 / fp88.
            if (t.hasPrefix("sp") || t.hasPrefix("fp")), t.count == 4 {
                let signed = t.hasPrefix("sp")
                let intBits = Int(String(t[t.index(t.startIndex, offsetBy: 2)]), radix: 16) ?? 0
                let fracBits = Int(String(t[t.index(t.startIndex, offsetBy: 3)]), radix: 16) ?? 0
                _ = intBits
                var raw: Int64 = 0
                for b in bytes { raw = (raw << 8) | Int64(b) }
                let totalBits = bytes.count * 8
                if signed, totalBits < 64, (raw & (1 << (totalBits - 1))) != 0 {
                    raw -= (Int64(1) << totalBits)
                }
                return Double(raw) / Double(1 << fracBits)
            }
            return nil
        }
    }
}
