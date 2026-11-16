import Foundation
import IOKit

// Private IOKit calls that reach the monitor's DDC/CI bus on Apple Silicon (same path m1ddc and MonitorControl use).
@_silgen_name("IOAVServiceCreateWithService")
private func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOAVServiceWriteI2C")
private func IOAVServiceWriteI2C(_ service: CFTypeRef, _ chipAddress: UInt32, _ dataAddress: UInt32, _ buffer: UnsafeMutableRawPointer, _ length: UInt32) -> IOReturn

/// MCCS VCP codes. `input` is LG's own input-select code, not the standard 0x60.
public enum VCP: UInt8, CaseIterable, Sendable {
    case brightness = 0x10
    case contrast = 0x12
    case colorPreset = 0x14
    case redGain = 0x16
    case greenGain = 0x18
    case blueGain = 0x1A
    case volume = 0x62
    case sharpness = 0x87
    case mute = 0x8D
    case power = 0xD6
    case input = 0xF4
}

public enum DDC {
    /// Set VCP Feature message for the I2C write, checksum included. LG's input code goes to source address 0x50.
    public static func setPacket(_ vcp: VCP, _ value: UInt16) -> (source: UInt8, bytes: [UInt8]) {
        let source: UInt8 = vcp == .input ? 0x50 : 0x51
        var bytes: [UInt8] = [0x84, 0x03, vcp.rawValue, UInt8(value >> 8), UInt8(value & 0xFF)]
        bytes.append(bytes.reduce(0x6E ^ source, ^))
        return (source, bytes)
    }

    /// Sends one setting to the first external display. Blocks for about 20 ms.
    /// The monitor's replies are unreadable on this Mac (M4 Pro, macOS 26), so success means the bus accepted the write.
    @discardableResult
    public static func set(_ vcp: VCP, _ value: UInt16) -> Bool {
        guard let service = externalService() else { return false }
        var (source, packet) = setPacket(vcp, value)
        var ok = false
        // Written twice, as m1ddc does: some monitors drop the first message.
        for _ in 0..<2 {
            usleep(10_000)
            ok = IOAVServiceWriteI2C(service, 0x37, UInt32(source), &packet, UInt32(packet.count)) == kIOReturnSuccess
        }
        return ok
    }

    // shortcut: drives the first external display only; add a display picker when a second monitor is attached.
    // Looked up on every write so sleep, wake and replugging never leave a stale handle.
    static func externalService() -> CFTypeRef? {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            let location = IORegistryEntryCreateCFProperty(entry, "Location" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
            if location == "External", let service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)?.takeRetainedValue() {
                return service
            }
        }
        return nil
    }
}

/// Sends settings off the main thread. While a write is in flight, newer values for the same code replace older ones,
/// so dragging a slider sends its latest position instead of queueing every step.
public final class DDCWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "ddc.writer")
    private let lock = NSLock()
    private var pending: [VCP: UInt16] = [:]
    private let send: (VCP, UInt16) -> Bool

    public init(send: @escaping (VCP, UInt16) -> Bool = DDC.set) {
        self.send = send
    }

    public func set(_ vcp: VCP, _ value: UInt16, done: (@Sendable (Bool) -> Void)? = nil) {
        lock.withLock { pending[vcp] = value }
        queue.async { [self] in
            guard let latest = lock.withLock({ pending.removeValue(forKey: vcp) }) else { return }
            let ok = send(vcp, latest)
            done?(ok)
        }
    }

    func waitUntilIdle() {
        queue.sync {}
    }
}
