/// Consent operations the runtime performs before it starts advertising.
///
/// `MHAppRuntimeAdsBundle` provides an SDK-backed bridge when the app
/// configuration includes `MHAdsConsentConfiguration`. Custom bridges let
/// tests and alternative adapters drive the same lifecycle.
public struct MHAdsConsentBridge {
    /// A consent operation that returns the SDK state after it completes.
    public typealias Operation = @MainActor () async throws -> MHAdsConsentSnapshot

    let currentSnapshot: @MainActor () -> MHAdsConsentSnapshot
    let requestUpdate: Operation
    let presentFormIfRequired: Operation
    let presentPrivacyOptions: Operation

    /// Creates a consent bridge from main-actor operations.
    ///
    /// - Parameters:
    ///   - currentSnapshot: Reads the SDK state now, including consent stored
    ///     by an earlier session.
    ///   - requestUpdate: Requests fresh consent information for this session.
    ///   - presentFormIfRequired: Loads and presents a consent form only when
    ///     the SDK requires one.
    ///   - presentPrivacyOptions: Presents privacy options in response to a
    ///     user action.
    @preconcurrency
    public init(
        currentSnapshot: @escaping @MainActor () -> MHAdsConsentSnapshot,
        requestUpdate: @escaping Operation,
        presentFormIfRequired: @escaping Operation,
        presentPrivacyOptions: @escaping Operation
    ) {
        self.currentSnapshot = currentSnapshot
        self.requestUpdate = requestUpdate
        self.presentFormIfRequired = presentFormIfRequired
        self.presentPrivacyOptions = presentPrivacyOptions
    }
}
