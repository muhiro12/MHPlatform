import MHAppRuntime

/// Scripted consent SDK for runtime lifecycle tests.
@MainActor
final class FakeAdsConsent {
    enum Failure: Error {
        case offline
    }

    var current = MHAdsConsentSnapshot.unknown
    var snapshotAfterForm: MHAdsConsentSnapshot
    var snapshotAfterPrivacyOptions = MHAdsConsentSnapshot.allowed
    var updateError: Failure?
    var privacyOptionsError: Failure?
    var onUpdate: @MainActor () async throws -> Void = { () }
    var onForm: @MainActor () -> Void = { () }

    private(set) var updateCount = 0
    private(set) var formCount = 0
    private(set) var privacyOptionsCount = 0

    var bridge: MHAdsConsentBridge {
        .init(
            currentSnapshot: { [self] in
                current
            },
            requestUpdate: { [self] in
                updateCount += 1
                try await onUpdate()
                if let updateError {
                    throw updateError
                }
                return current
            },
            presentFormIfRequired: { [self] in
                formCount += 1
                current = snapshotAfterForm
                onForm()
                return current
            },
            presentPrivacyOptions: { [self] in
                privacyOptionsCount += 1
                if let privacyOptionsError {
                    throw privacyOptionsError
                }
                current = snapshotAfterPrivacyOptions
                return current
            }
        )
    }

    init(snapshotAfterForm: MHAdsConsentSnapshot) {
        self.snapshotAfterForm = snapshotAfterForm
    }
}

extension MHAdsConsentSnapshot {
    static let unknown = Self(canRequestAds: false, privacyOptionsRequirement: .unknown)
    static let allowed = Self(canRequestAds: true, privacyOptionsRequirement: .required)
    static let denied = Self(canRequestAds: false, privacyOptionsRequirement: .required)
}
