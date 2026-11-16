import Foundation
import Testing
@testable import DDC

// Byte-for-byte the message that changed brightness on a real LG over USB-C.
@Test func brightnessPacket() {
    let packet = DDC.setPacket(.brightness, 70)
    #expect(packet.source == 0x51)
    #expect(packet.bytes == [0x84, 0x03, 0x10, 0x00, 0x46, 0xEE])
}

@Test func lgInputUsesAlternateSourceAddress() {
    let packet = DDC.setPacket(.input, 210)
    #expect(packet.source == 0x50)
    #expect(packet.bytes == [0x84, 0x03, 0xF4, 0x00, 0xD2, 0x9F])
}

@Test func valuesAboveOneByteSplitHighLow() {
    #expect(DDC.setPacket(.brightness, 0x0102).bytes[3...4] == [0x01, 0x02])
}

@Test func writerSendsOnlyTheLatestValueWhileBusy() {
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let lock = NSLock()
    var sent: [UInt16] = []
    let writer = DDCWriter { _, value in
        if value == 1 { started.signal(); release.wait() }
        lock.withLock { sent.append(value) }
        return true
    }

    writer.set(.brightness, 1)
    started.wait()
    for value: UInt16 in 2...5 { writer.set(.brightness, value) }
    writer.set(.contrast, 9)
    release.signal()
    writer.waitUntilIdle()

    #expect(sent == [1, 5, 9])
}
