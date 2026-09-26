import Foundation
@testable import JevSimUseKit

/// Envelopes shaped after sim-use v0.14.0's own test fixtures.
enum Fixtures {
    static let simulator = """
    {"deviceId":"B34F0000-0000-0000-0000-000000000001","kind":"simulator",\
    "name":"iPhone 17 Pro","platform":"ios","runtime":"iOS 27.0","state":"Booted"}
    """
    static let emulator = """
    {"deviceId":"emulator-5554","kind":"emulator","name":"Pixel 9",\
    "platform":"android","runtime":"Android","state":"device"}
    """
    static let physicalIPhone = """
    {"deviceId":"00008110-000A1B2C3D4E5F60","kind":"physical","name":"iPhone","platform":"ios","state":"Booted"}
    """

    /// A 402x874 iPhone screen, in the points describe-ui reports.
    static let screen = ElementFrame(x: 0, y: 0, width: 402, height: 874)

    /// One of the device envelopes above, decoded.
    static func device(_ json: String) -> SimUseDevice {
        (try? JSONDecoder().decode(SimUseDevice.self, from: Data(json.utf8)))
            ?? SimUseDevice(deviceId: "undecodable", name: "", platform: "", kind: nil, state: "")
    }

    static func snapshot(outline: String = "App: Settings  402x874", entries: [UIEntry] = []) -> UISnapshot {
        UISnapshot(platform: "ios", outline: outline, appLabel: "Settings", entries: entries, crashDialog: nil)
    }

    static func entry(
        _ alias: Int,
        _ label: String,
        role: String = "Button",
        states: [String] = [],
        value: String? = nil,
        uniqueId: String? = nil,
        frame: ElementFrame? = nil,
        band: String? = nil,
        region: ElementRegion? = nil,
        depth: Int? = nil,
    ) -> UIEntry {
        var entry = UIEntry(
            aliases: ElementAliases(alias: alias), role: role, label: label, states: states, value: value, uniqueId: uniqueId,
            region: region ?? band.map { ElementRegion(kind: $0, label: nil) }, frame: frame,
        )
        entry.depth = depth
        return entry
    }
}
