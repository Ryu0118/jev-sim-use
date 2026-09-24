/// Failures specific to turning a screen into a Jev decision.
package enum PlanningError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Jev returned 422.
    case rejected(body: String)
    /// The response carried no choice answer for the next action.
    case missingChoice
    /// Jev chose an option name that was not offered.
    case unknownChoice(String)

    /// A message suitable for the console.
    package var description: String {
        switch self {
        case let .rejected(body):
            "Jev rejected the request (422). The screen may exceed Jev's 32k-token state limit: \(body)"
        case .missingChoice:
            "Jev's response had no answer for the next action."
        case let .unknownChoice(value):
            "Jev chose '\(value)', which was not one of the offered actions."
        }
    }
}
