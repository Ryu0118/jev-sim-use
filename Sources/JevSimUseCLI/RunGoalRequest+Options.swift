import JevSimUseKit

extension RunGoalRequest {
    /// A request for `session` with the connection and per-run options `run` and `session resume` share.
    init(session: SessionStart, connection: ConnectionOptions, agent: AgentOptions) throws {
        try self.init(
            session: session, maxSteps: agent.maxSteps, minConfidence: agent.minConfidence,
            allowedOperations: agent.allowedOperations,
            deviceID: connection.device, baseURL: connection.baseURL, model: connection.model,
        )
    }
}
