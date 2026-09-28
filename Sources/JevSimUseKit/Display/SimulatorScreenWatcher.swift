import Foundation
import IOSurface
import Synchronization

/// Watches a simulator's screen image through its display descriptor, as idb's framebuffer does: the render server
/// reports each presented frame (`damageRectanglesCallback`) and vends the framebuffer as an IOSurface this process
/// maps. Frames are compared below the status bar (`FrameBaseline`), so neither the clock nor a frame that changed no
/// pixel counts. No Simulator window or screen-recording permission is involved.
///
/// The render server waits for each callback to return before presenting the next frame, so a callback only notes
/// the frame; one task compares at most every `sampleInterval`, which also bounds the work on a loaded Mac, where one
/// comparison of a 1206x2622 frame took up to 0.2 s.
final class SimulatorScreenWatcher: ClosableScreenWatcher {
    private struct Status {
        /// When the latest frame was reported.
        var lastFrame: ContinuousClock.Instant?
        /// The latest frame the comparison has covered.
        var compared: ContinuousClock.Instant?
        /// When the latest compared frame changed the content.
        var lastChange: ContinuousClock.Instant?
        var closed = false
        /// Whether the surface-change callback is registered, and so must be unregistered.
        var followsSurface = false

        /// Whether a reported frame still waits for its comparison.
        var pending: Bool {
            lastFrame.map { frame in compared.map { frame > $0 } ?? true } ?? false
        }
    }

    private struct Frames {
        var surface: IOSurface
        var baseline = FrameBaseline()
    }

    /// How often waits look at the status.
    static let pollInterval: Duration = .milliseconds(10)

    // Messaged only from init and, once, from `close`; the descriptor is an XPC proxy that any thread may message.
    private nonisolated(unsafe) let display: NSObject
    private let id = UUID()
    private let status = Mutex(Status())
    private let frames: Mutex<Frames>
    private let signal: AsyncStream<Void>.Continuation
    private let sampler = Mutex<Task<Void, Never>?>(nil)
    private let onChange: (@Sendable (ContinuousClock.Instant) -> Void)?

    /// Starts watching `display`, a main display descriptor (`CoreSimulatorLocator`). `onChange` receives the time of
    /// each frame that changed the content.
    init(
        display: NSObject,
        sampleInterval: Duration = .milliseconds(30),
        onChange: (@Sendable (ContinuousClock.Instant) -> Void)? = nil,
    ) throws(ScreenWatchError) {
        guard let surface = try PrivateMessage.object(display, "framebufferSurface") as? IOSurface else {
            throw .noResult("framebufferSurface")
        }
        var frames = Frames(surface: surface)
        _ = Self.compare(&frames)
        self.frames = Mutex(frames)
        let (stream, signal) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        self.signal = signal
        self.onChange = onChange
        self.display = display

        // The callbacks hold the watcher weakly: CoreSimulator keeps them until they are unregistered.
        let damage: @convention(block) (NSArray) -> Void = { [weak self] _ in self?.frameReported() }
        let surfaces: @convention(block) (AnyObject?) -> Void = { [weak self] surface in
            self?.surfaceReplaced(surface as? IOSurface)
        }
        try PrivateMessage.register(display, "registerCallbackWithUUID:damageRectanglesCallback:", id: id, block: damage as AnyObject)
        // Without it the surface is not followed through a rotation or resize; frames still are, so it is optional.
        let followsSurface = (try? PrivateMessage.register(
            display, "registerCallbackWithUUID:ioSurfacesChangeCallback:", id: id, block: surfaces as AnyObject,
        )) != nil
        status.withLock { $0.followsSurface = followsSurface }

        sampler.withLock { $0 = Task { [weak self] in
            for await _ in stream {
                self?.sample()
                try? await Task.sleep(for: sampleInterval)
            }
        } }
    }

    deinit {
        close()
    }

    func close() {
        let (open, followsSurface) = status.withLock { status in
            defer { status.closed = true }
            return (!status.closed, status.followsSurface)
        }
        guard open else { return }
        signal.finish()
        sampler.withLock { $0?.cancel() }
        // Best effort: a simulator that shut down has nothing left to unregister from.
        try? PrivateMessage.unregister(display, "unregisterDamageRectanglesCallbackWithUUID:", id: id)
        if followsSurface {
            try? PrivateMessage.unregister(display, "unregisterIOSurfacesChangeCallbackWithUUID:", id: id)
        }
    }

    func waitForChange(after instant: ContinuousClock.Instant, until deadline: ContinuousClock.Instant) async throws -> Bool {
        while true {
            let (lastChange, pending) = status.withLock { ($0.lastChange, $0.pending && !$0.closed) }
            if let lastChange, lastChange > instant {
                return true
            }
            // A frame reported before the deadline is compared before the answer is no.
            guard ContinuousClock.now < deadline || pending else { return false }
            try await Task.sleep(for: Self.pollInterval)
        }
    }

    func waitUntilStill(for quiet: Duration, until deadline: ContinuousClock.Instant) async throws -> Bool {
        while true {
            let (lastChange, pending) = status.withLock { ($0.lastChange, $0.pending && !$0.closed) }
            if !pending, lastChange.map({ ContinuousClock.now - $0 >= quiet }) ?? true {
                return true
            }
            guard ContinuousClock.now < deadline else { return false }
            try await Task.sleep(for: Self.pollInterval)
        }
    }

    private func frameReported() {
        let open = status.withLock { status in
            guard !status.closed else { return false }
            status.lastFrame = .now
            return true
        }
        if open {
            signal.yield()
        }
    }

    private func surfaceReplaced(_ surface: IOSurface?) {
        guard let surface else { return }
        frames.withLock { $0.surface = surface }
        frameReported()
    }

    /// Compares the surface as it is now; the change dates from the latest frame reported before the comparison began.
    private func sample() {
        guard let frame = status.withLock({ $0.lastFrame }) else { return }
        let changed = frames.withLock { Self.compare(&$0) }
        status.withLock { status in
            status.compared = max(status.compared ?? frame, frame)
            if changed {
                status.lastChange = max(status.lastChange ?? frame, frame)
            }
        }
        if changed {
            onChange?(frame)
        }
    }

    private static func compare(_ frames: inout Frames) -> Bool {
        let surface = frames.surface
        surface.lock(options: .readOnly, seed: nil)
        defer { surface.unlock(options: .readOnly, seed: nil) }
        return frames.baseline.absorb(
            UnsafeRawBufferPointer(start: surface.baseAddress, count: surface.allocationSize),
            bytesPerRow: surface.bytesPerRow, height: surface.height,
        )
    }
}
