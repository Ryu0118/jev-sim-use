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

    static func devices(_ items: String...) -> String {
        #"{"ok":true,"data":{"devices":["# + items.joined(separator: ",") + "]}}"
    }

    static func snapshot(outline: String = "App: Settings  402x874", entries: [UIEntry] = []) -> UISnapshot {
        UISnapshot(platform: "ios", outline: outline, appLabel: "Settings", entries: entries, crashDialog: nil)
    }

    static func entry(_ alias: Int, _ label: String, role: String = "Button", states: [String] = []) -> UIEntry {
        UIEntry(aliases: ElementAliases(alias: alias), role: role, label: label, states: states, value: nil, uniqueId: nil, region: nil)
    }
}
