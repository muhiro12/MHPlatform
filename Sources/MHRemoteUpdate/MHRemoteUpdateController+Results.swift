import Foundation

public extension MHRemoteUpdateController {
    /// Invalid configuration, obsolete responses, and incompatible retained evidence.
    enum Failure: Error, Equatable, Sendable {
        /// App identity, storefront, or evidence lifetime is invalid.
        case invalidConfiguration
        /// A response belongs to an earlier refresh invocation.
        case superseded
        /// A revision moved backwards or an immutable revision changed content.
        case revisionConflict
        /// Retained evidence belongs to another app or storefront.
        case identityMismatch
    }

    /// Startup/foreground evidence and diagnostics without app-owned recovery sequencing.
    struct Preparation: Sendable {
        /// Re-evaluated evidence after restoration and the refresh attempt.
        public let evaluation: MHRemoteUpdateEvaluation
        /// A corrupt, incompatible, or unreadable cache; refresh is still attempted.
        public let restorationError: (any Error)?
        /// A fetch or save failure; still-valid retained evidence remains usable.
        public let refreshError: (any Error)?

        /// The ordinary decision from the same instant as the diagnostic evaluation.
        public var decision: MHRemoteUpdateDecision { evaluation.decision }
    }
}
