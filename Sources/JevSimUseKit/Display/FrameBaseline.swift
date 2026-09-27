import Foundation

/// The rows of the last frame below the status bar's band, to tell a frame that changed the app's content from one
/// that did not. CoreSimulator's damage callback no longer carries rectangles (always an empty array on Xcode 27) and
/// fires for frames that change no pixel, so the frames themselves are compared.
struct FrameBaseline: Sendable {
    /// The status bar's share of the portrait framebuffer's height, left out of the comparison so the clock ticking is
    /// not a change. On an 874 pt screen its items end at 51 pt (the Dynamic Island) and the app's own bar starts at
    /// 62 pt; 6.5 % is 57 pt there, and 43 pt on a 667 pt screen whose status bar is 20 pt. The framebuffer stays in
    /// portrait, so in landscape this band is a strip along one side, where the status bar is hidden anyway.
    static let statusBarFraction = 0.065

    /// Rows compared: every second one, since a point spans at least two rows at 2x and 3x, which halves the work.
    static let rowStride = 2

    private var rows: [UInt8] = []
    private var bytesPerRow = 0
    private var height = 0

    /// Compares `frame` with the last one and keeps it; whether a compared row changed. The first frame, and a frame of
    /// another size, starts over: the first only primes the comparison, a resized one counts as a change.
    mutating func absorb(_ frame: UnsafeRawBufferPointer, bytesPerRow: Int, height: Int) -> Bool {
        let first = Int((Double(height) * Self.statusBarFraction).rounded(.up))
        let compared = Array(stride(from: first, to: height, by: Self.rowStride))
        guard let source = frame.baseAddress, frame.count >= bytesPerRow * height else { return false }

        guard bytesPerRow == self.bytesPerRow, height == self.height else {
            let resized = !rows.isEmpty
            self.bytesPerRow = bytesPerRow
            self.height = height
            rows = [UInt8](repeating: 0, count: compared.count * bytesPerRow)
            rows.withUnsafeMutableBytes { stored in
                guard let base = stored.baseAddress else { return }
                for (index, row) in compared.enumerated() {
                    memcpy(base + index * bytesPerRow, source + row * bytesPerRow, bytesPerRow)
                }
            }
            return resized
        }

        var changed = false
        rows.withUnsafeMutableBytes { stored in
            guard let base = stored.baseAddress else { return }
            for (index, row) in compared.enumerated() {
                let target = base + index * bytesPerRow
                if memcmp(target, source + row * bytesPerRow, bytesPerRow) != 0 {
                    memcpy(target, source + row * bytesPerRow, bytesPerRow)
                    changed = true
                }
            }
        }
        return changed
    }
}
