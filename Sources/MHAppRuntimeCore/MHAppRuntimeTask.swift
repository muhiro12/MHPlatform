import Foundation

/// Ordered lifecycle task executed by `MHAppRuntimeLifecycle`.
public struct MHAppRuntimeTask: Sendable, Hashable {
    /// Main-actor task action.
    public typealias Action = @MainActor @Sendable () async -> Void

    /// Stable task name for debugging and test expectations.
    public let name: String

    private let action: Action

    /// Creates a runtime lifecycle task.
    @preconcurrency
    public init(
        name: String,
        action: @escaping Action
    ) {
        self.name = name
        self.action = action
    }

    public static func == (
        lhs: Self,
        rhs: Self
    ) -> Bool {
        lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    @MainActor
    func run() async {
        await action()
    }
}
