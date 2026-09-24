import Foundation

/// Progress from a `RunGoalRunner`.
package enum RunGoalEvent: Sendable, Hashable, CustomStringConvertible {
    /// sim-use and the device are ready and Jev will be called at `endpoint`.
    case connected(device: SimUseDevice, endpoint: URL)
    /// The run works in session `id`; `resumed` when it continues an earlier one.
    case session(id: String, resumed: Bool)
    /// A non-fatal problem worth telling the user about.
    case warning(String)
    /// A step of the agent loop.
    case agent(AgentEvent)

    /// A single progress line for the console.
    package var description: String {
        switch self {
        case let .connected(device, endpoint): "Device: \(device.name) (\(device.deviceId)); Jev: \(endpoint)"
        case let .session(id, resumed):
            (resumed ? "Resuming session \(id)" : "Session: \(id)") + " (deleted when the goal is reached)"
        case let .warning(message): "Warning: \(message)"
        case let .agent(event): event.description
        }
    }
}
