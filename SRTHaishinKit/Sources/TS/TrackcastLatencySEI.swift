import Foundation

/// Trackcast ingest-latency SEI NAL (user_data_unregistered), emitted once per IDR.
/// Byte contract shared with the Android injector (RootEncoder fork
/// 2.7.0-trackcast-sei2) and the Rust receiver (trackcast crates/common/src/sei.rs):
/// start code + 06 05 18 | UUID b7c1f2a0-4e83-4d67-9b01-c3a5de120001 |
/// f64-BE epoch seconds | 80. Annex-B form only.
enum TrackcastLatencySEI {
    private static let uuid: [UInt8] = [
        0xb7, 0xc1, 0xf2, 0xa0, 0x4e, 0x83, 0x4d, 0x67,
        0x9b, 0x01, 0xc3, 0xa5, 0xde, 0x12, 0x00, 0x01
    ]

    /// Annex-B SEI NAL carrying the wall-clock time (epoch seconds, f64 BE).
    static func nal(at date: Date = Date()) -> Data {
        var body = uuid
        var secondsBE = date.timeIntervalSince1970.bitPattern.bigEndian
        withUnsafeBytes(of: &secondsBE) { body.append(contentsOf: $0) }
        var nal: [UInt8] = [0x00, 0x00, 0x00, 0x01, 0x06, 0x05, 0x18]
        nal.append(contentsOf: body)
        nal.append(0x80)
        return Data(nal)
    }
}
