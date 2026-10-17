public extension MHRemoteUpdateDecision {
    /// Throws before an app-owned operation when its update precondition is unsatisfied.
    ///
    /// Call immediately before the entire operation, including its success side effects.
    /// This checks a snapshot: the app owns freshness, refresh, and protected surfaces.
    /// It performs no operation, caches no permission, and requires no app-root runtime.
    func checkOperationAllowed(whenUnavailable behavior: MHRemoteUpdateUnavailableBehavior) throws {
        switch self {
        case .updateRequired:
            throw MHRemoteUpdateOperationError.updateRequired
        case .unavailable where behavior == .block:
            throw MHRemoteUpdateOperationError.policyUnavailable
        case .notRequired, .unavailable:
            return
        }
    }
}
