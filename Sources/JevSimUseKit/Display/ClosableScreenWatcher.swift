/// A screen-change watcher holding callbacks registered with the simulator, which its owner must close.
package protocol ClosableScreenWatcher: ScreenChangeWatching {
    /// Unregisters the callbacks; later calls do nothing, and waits then see no further change.
    func close()
}
