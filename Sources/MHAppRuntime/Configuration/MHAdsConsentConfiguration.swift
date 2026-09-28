/// App-owned request settings for the runtime's advertising consent lifecycle.
///
/// Supplying this configuration opts the runtime into consent-managed ads:
/// advertising starts only after the consent SDK reports that ads can be
/// requested. Regional policy, account messages, and presentation copy remain
/// app and publisher responsibilities.
public struct MHAdsConsentConfiguration: Sendable, Hashable {
    /// Test-only geography override applied to consent requests.
    public enum DebugGeography: String, Sendable, CaseIterable {
        /// Behaves as if the device were in the European Economic Area.
        case eea

        /// Behaves as if the device were in a regulated US state.
        case regulatedUSState

        /// Behaves as if the device were outside regulated regions.
        case other
    }

    /// Whether consent requests are tagged for users under the age of consent.
    public let isTaggedForUnderAgeOfConsent: Bool

    /// Test-only geography override. Leave `nil` in production builds.
    public let debugGeography: DebugGeography?

    /// Physical test-device identifiers for debug geography. Simulators are
    /// always treated as test devices.
    public let testDeviceIdentifiers: [String]

    /// Creates consent request settings.
    public init(
        isTaggedForUnderAgeOfConsent: Bool = false,
        debugGeography: DebugGeography? = nil,
        testDeviceIdentifiers: [String] = []
    ) {
        self.isTaggedForUnderAgeOfConsent = isTaggedForUnderAgeOfConsent
        self.debugGeography = debugGeography
        self.testDeviceIdentifiers = testDeviceIdentifiers
    }
}
