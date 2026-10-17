import Foundation

/// App-owned update requirements expressed without a remote JSON schema.
public struct MHRemoteUpdatePolicy: Hashable, Sendable {
    /// The oldest installed version accepted by the policy.
    public let minimumVersion: MHAppVersion
    /// An optional activation interval; `nil` means no time restriction.
    public let activationWindow: MHUpdateActivationWindow?
    /// Whether the minimum version must be confirmed available in the chosen storefront.
    public let requiresPublicVersion: Bool

    /// Creates a policy from explicit app-owned activation and publication choices.
    public init(
        minimumVersion: MHAppVersion,
        activationWindow: MHUpdateActivationWindow?,
        requiresPublicVersion: Bool
    ) {
        self.minimumVersion = minimumVersion
        self.activationWindow = activationWindow
        self.requiresPublicVersion = requiresPublicVersion
    }

    /// Evaluates supplied evidence without fetching, storing, or presenting anything.
    ///
    /// An unpublished minimum does not require an update, matching a publication-gated
    /// policy. Missing required publication evidence is instead `unavailable`.
    public func evaluate(
        currentVersion: MHAppVersion,
        now: Date,
        publicVersion: MHAppVersion? = nil
    ) -> MHRemoteUpdateDecision {
        guard now.timeIntervalSinceReferenceDate.isFinite else {
            return .unavailable
        }
        guard activationWindow?.contains(now) != false,
              currentVersion < minimumVersion else {
            return .notRequired
        }
        if requiresPublicVersion {
            guard let publicVersion else {
                return .unavailable
            }
            guard minimumVersion <= publicVersion else {
                return .notRequired
            }
        }
        return .updateRequired
    }
}
