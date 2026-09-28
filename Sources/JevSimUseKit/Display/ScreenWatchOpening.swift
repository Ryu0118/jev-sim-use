/// Opens a screen-change watcher on a simulator's display.
package protocol ScreenWatchOpening: Sendable {
    /// A watcher on the display of the booted iOS simulator `simulatorID`, which the caller closes.
    func open(simulatorID: String) async throws(ScreenWatchError) -> any ClosableScreenWatcher
}
