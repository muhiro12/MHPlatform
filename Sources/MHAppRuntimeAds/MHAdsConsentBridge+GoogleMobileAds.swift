#if canImport(GoogleMobileAdsWrapper)
import GoogleMobileAdsWrapper
import MHAppRuntime
import OSLog

extension MHAdsConsentBridge {
    /// Routes consent operations through the shared UMP controller.
    static func googleMobileAds(
        configuration: MHAdsConsentConfiguration
    ) -> Self {
        let request = GoogleMobileAdsConsentRequest(configuration)
        let logger = Logger(subsystem: "MHPlatform", category: "AdsConsent")

        return .init(
            currentSnapshot: {
                .init(GoogleMobileAdsConsentController.shared.state)
            },
            requestUpdate: {
                try await logged("Consent information update", logger: logger) {
                    try await GoogleMobileAdsConsentController.shared
                        .requestConsentInfoUpdate(request)
                }
            },
            presentFormIfRequired: {
                try await logged("Consent form", logger: logger) {
                    try await GoogleMobileAdsConsentController.shared
                        .loadAndPresentIfRequired()
                }
            },
            presentPrivacyOptions: {
                try await logged("Privacy options", logger: logger) {
                    try await GoogleMobileAdsConsentController.shared
                        .presentPrivacyOptions()
                }
            }
        )
    }
}

@MainActor
private func logged(
    _ operationName: String,
    logger: Logger,
    operation: @MainActor () async throws -> GoogleMobileAdsConsentState
) async throws -> MHAdsConsentSnapshot {
    do {
        return .init(try await operation())
    } catch {
        logger.error("\(operationName, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        throw error
    }
}

private extension MHAdsConsentSnapshot {
    init(_ state: GoogleMobileAdsConsentState) {
        self.init(
            canRequestAds: state.canRequestAds,
            privacyOptionsRequirement: .init(state.privacyOptionsRequirement)
        )
    }
}

private extension MHAdsPrivacyOptionsRequirement {
    init(_ requirement: GoogleMobileAdsConsentState.PrivacyOptionsRequirement) {
        switch requirement {
        case .unknown:
            self = .unknown
        case .required:
            self = .required
        case .notRequired:
            self = .notRequired
        }
    }
}

private extension GoogleMobileAdsConsentRequest {
    init(_ configuration: MHAdsConsentConfiguration) {
        self.init(
            isTaggedForUnderAgeOfConsent: configuration.isTaggedForUnderAgeOfConsent,
            debugSettings: configuration.debugGeography.map { geography in
                .init(
                    geography: .init(geography),
                    testDeviceIdentifiers: configuration.testDeviceIdentifiers
                )
            }
        )
    }
}

private extension GoogleMobileAdsConsentRequest.DebugSettings.Geography {
    init(_ geography: MHAdsConsentConfiguration.DebugGeography) {
        switch geography {
        case .eea:
            self = .eea
        case .regulatedUSState:
            self = .regulatedUSState
        case .other:
            self = .other
        }
    }
}
#endif
