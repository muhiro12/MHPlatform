import Observation

/// Observable foreground state plus a shared, network-free check for synchronous app-owned writes.
@preconcurrency
@MainActor
@Observable
public final class MHRemoteUpdateAdapter {
    /// Last observed evidence, for presentation only. Nil before preparation or in an isolated preview.
    public private(set) var evaluation: MHRemoteUpdateEvaluation?

    private let controller: MHRemoteUpdateController?

    /// Wraps the environment's controller; the controller remains the only evidence store.
    public init(controller: MHRemoteUpdateController) {
        self.controller = controller
    }

    private init() {
        controller = nil
    }

    /// Creates an isolated preview that neither fetches nor opens a retained store.
    public static func preview() -> MHRemoteUpdateAdapter {
        .init()
    }

    /// Prepare at startup and foreground entry. Call again for an explicit retry.
    @discardableResult
    public func prepare() async throws -> MHRemoteUpdateController.Preparation? {
        try Task.checkCancellation()
        guard let controller else {
            return nil
        }
        do {
            let result = try await controller.prepare()
            evaluation = result.evaluation
            try Task.checkCancellation()
            return result
        } catch {
            evaluation = await controller.evaluation()
            throw error
        }
    }

    /// Checks the current clock and retained evidence, then calls the mutation without suspending.
    /// Callers choose how to handle unavailable evidence on each operation, even before preparation.
    public func perform<Value>(
        policy: MHRemoteUpdateOperationPolicy,
        _ mutation: () throws -> Value
    ) async throws -> Value {
        if let controller {
            do {
                let current = try await controller.retainedEvaluation()
                evaluation = current
                try Task.checkCancellation()
                try current.decision.checkOperationAllowed(
                    whenUnavailable: policy == .allowWhenUnavailable ? .allow : .block
                )
            } catch {
                evaluation = await controller.evaluation()
                try Task.checkCancellation()
                throw error
            }
        }
        try Task.checkCancellation()
        return try mutation()
    }
}
