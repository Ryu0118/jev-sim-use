import Foundation
import IOSurface
@testable import JevSimUseKit
import Synchronization

/// Stands in for CoreSimulator's main display descriptor: the same selectors, answered in-process, over a real
/// in-memory IOSurface the test draws into. `draw` changes rows and reports a frame as the render server does.
/// ObjC calls the descriptor from any thread; every mutable field is behind `state`.
final class FakeDisplayDescriptor: NSObject, @unchecked Sendable {
    private struct State {
        var surface: IOSurface
        var damage: [UUID: @convention(block) @Sendable (NSArray) -> Void] = [:]
        var surfaces: [UUID: @convention(block) @Sendable (AnyObject?) -> Void] = [:]
        var registered: [String] = []
        var unregistered: [String] = []
    }

    static let width = 100
    static let height = 200

    private let state: Mutex<State>

    /// `register…` calls, as `<kind> <uuid>`.
    var registered: [String] {
        state.withLock { $0.registered }
    }

    /// `unregister…` calls, as `<kind> <uuid>`.
    var unregistered: [String] {
        state.withLock { $0.unregistered }
    }

    override init() {
        state = Mutex(State(surface: Self.makeSurface()))
    }

    static func makeSurface() -> IOSurface {
        IOSurface(properties: [
            .width: width, .height: height, .bytesPerElement: 4, .pixelFormat: 0x4247_5241,
        ])!
    }

    /// Fills `rows` with `value` and reports a frame to every damage callback.
    func draw(rows: Range<Int>, value: UInt8) {
        let (surface, callbacks) = state.withLock { ($0.surface, Array($0.damage.values)) }
        surface.lock(options: [], seed: nil)
        let base = surface.baseAddress
        for row in rows {
            memset(base + row * surface.bytesPerRow, Int32(value), surface.bytesPerRow)
        }
        surface.unlock(options: [], seed: nil)
        callbacks.forEach { $0(NSArray()) }
    }

    /// Replaces the surface with a new one filled with `value`, and reports it to every surface-change callback.
    func replaceSurface(filledWith value: UInt8) {
        let surface = Self.makeSurface()
        surface.lock(options: [], seed: nil)
        memset(surface.baseAddress, Int32(value), surface.allocationSize)
        surface.unlock(options: [], seed: nil)
        let callbacks = state.withLock { state in
            state.surface = surface
            return Array(state.surfaces.values)
        }
        callbacks.forEach { $0(surface) }
    }

    @objc func framebufferSurface() -> IOSurface {
        state.withLock { $0.surface }
    }

    @objc(registerCallbackWithUUID:damageRectanglesCallback:)
    func registerDamage(_ uuid: NSUUID, callback: @escaping @convention(block) @Sendable (NSArray) -> Void) {
        state.withLock {
            $0.damage[uuid as UUID] = callback
            $0.registered.append("damage \(uuid)")
        }
    }

    @objc(registerCallbackWithUUID:ioSurfacesChangeCallback:)
    func registerSurfaces(_ uuid: NSUUID, callback: @escaping @convention(block) @Sendable (AnyObject?) -> Void) {
        state.withLock {
            $0.surfaces[uuid as UUID] = callback
            $0.registered.append("surfaces \(uuid)")
        }
    }

    @objc(unregisterDamageRectanglesCallbackWithUUID:)
    func unregisterDamage(_ uuid: NSUUID) {
        state.withLock {
            $0.damage[uuid as UUID] = nil
            $0.unregistered.append("damage \(uuid)")
        }
    }

    @objc(unregisterIOSurfacesChangeCallbackWithUUID:)
    func unregisterSurfaces(_ uuid: NSUUID) {
        state.withLock {
            $0.surfaces[uuid as UUID] = nil
            $0.unregistered.append("surfaces \(uuid)")
        }
    }
}
