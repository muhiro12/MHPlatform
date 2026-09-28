import Foundation
import MHPreferences
import Observation
import SwiftUI

/// Runtime entry point for startup side effects and shared app platform state.
@MainActor
@preconcurrency
@Observable
public final class MHAppRuntime {
    /// Main-actor startup bridge that reports the current purchased product identifiers.
    public typealias StartStore = @MainActor (
        @escaping @MainActor (Set<String>) -> Void
    ) -> Void
    /// Startup bridge for ads initialization.
    public typealias StartAds = () -> Void

    /// Immutable app runtime configuration.
    public let configuration: MHAppConfiguration

    /// Typed preferences helper that resolves `UserDefaults` from descriptors or injected stores.
    public let preferenceStore: MHPreferenceStore

    /// Indicates whether startup side effects have already been triggered.
    public private(set) var hasStarted = false

    /// Current premium subscription status.
    public private(set) var premiumStatus: MHPremiumStatus = .unknown

    /// Current ads availability computed from configuration and premium status.
    public var adsAvailability: MHAdsAvailability {
        guard isAdsFeatureConfigured else {
            return .notConfigured
        }

        if premiumStatus == .active {
            return .disabledByPremium
        }

        return .available
    }

    /// Current advertising consent status. Stays `.notManaged` without a consent bridge.
    public private(set) var adsConsentStatus: MHAdsConsentStatus

    /// Whether the app must offer a control that calls `presentAdsPrivacyOptions()`.
    public private(set) var adsPrivacyOptionsRequirement: MHAdsPrivacyOptionsRequirement = .unknown

    /// Whether native ads may be shown now, combining availability and consent.
    ///
    /// Prefer this over `adsAvailability` when deciding whether to reserve an
    /// ad placement, because it also reflects consent-managed eligibility.
    public var canDisplayAds: Bool {
        guard adsAvailability == .available else {
            return false
        }

        switch adsConsentStatus {
        case .notManaged,
             .canRequestAds:
            return true
        case .pending,
             .cannotRequestAds:
            return false
        }
    }

    private let subscriptionProductIDs: [String]
    private let subscriptionGroupID: String?
    private let nativeAdUnitID: String?

    private let startStore: StartStore
    private let subscriptionSectionFactory: MHRuntimeViewFactory
    private let startAds: StartAds?
    private let nativeAdFactory: MHRuntimeNativeAdViewFactory?
    private let licensesFactory: MHRuntimeViewFactory
    private let adsConsent: MHAdsConsentBridge?

    private var hasStartedAds = false
    private var hasEvaluatedAdsConsent = false
    private var isEvaluatingAdsConsent = false

    private var isAdsFeatureConfigured: Bool {
        nativeAdUnitID != nil && nativeAdFactory != nil
    }

    /// Creates a runtime with explicit bridges and runtime-owned view factories.
    ///
    /// Passing `adsConsent` defers `startAds` until the consent bridge reports
    /// that ads can be requested for a user without active premium status.
    public init(
        configuration: MHAppConfiguration,
        preferenceStore: MHPreferenceStore,
        startStore: @escaping StartStore,
        subscriptionSectionFactory: MHRuntimeViewFactory,
        startAds: StartAds?,
        nativeAdFactory: MHRuntimeNativeAdViewFactory?,
        licensesFactory: MHRuntimeViewFactory = .init {
            EmptyView()
        },
        adsConsent: MHAdsConsentBridge? = nil
    ) {
        self.configuration = configuration
        self.preferenceStore = preferenceStore
        self.subscriptionProductIDs = MHRuntimeTextNormalizer.uniqueTrimmedNonEmptyValues(
            configuration.subscriptionProductIDs
        )
        self.subscriptionGroupID = MHRuntimeTextNormalizer.trimmedNonEmpty(
            configuration.subscriptionGroupID
        )
        self.nativeAdUnitID = MHRuntimeTextNormalizer.trimmedNonEmpty(
            configuration.nativeAdUnitID
        )
        self.startStore = startStore
        self.subscriptionSectionFactory = subscriptionSectionFactory
        self.startAds = startAds
        self.nativeAdFactory = nativeAdFactory
        self.licensesFactory = licensesFactory

        let managesAdsConsent = adsConsent != nil
            && self.nativeAdUnitID != nil
            && nativeAdFactory != nil
        self.adsConsent = managesAdsConsent ? adsConsent : nil
        self.adsConsentStatus = managesAdsConsent ? .pending : .notManaged
    }

    /// Creates a runtime-only environment without StoreKit, ads, or licenses.
    public convenience init(
        runtimeOnly configuration: MHAppConfiguration
    ) {
        self.init(
            configuration: configuration,
            preferenceStore: .init(),
            startStore: { purchasedProductIDsDidSet in
                purchasedProductIDsDidSet([])
            },
            subscriptionSectionFactory: .init {
                EmptyView()
            },
            startAds: nil,
            nativeAdFactory: nil
        )
    }

    /// Starts runtime side effects if they have not already run.
    public func startIfNeeded() {
        guard hasStarted == false else {
            return
        }

        hasStarted = true

        if subscriptionProductIDs.isEmpty {
            premiumStatus = .inactive
        }

        startStore { [weak self] purchasedProductIDs in
            guard let self else {
                return
            }
            resolvePremiumStatus(purchasedProductIDs: purchasedProductIDs)
        }

        if adsConsent == nil {
            startAdsIfNeeded()
        } else {
            updateAdsForPremiumStatus()
        }
    }

    /// Starts runtime side effects. This method is idempotent.
    public func start() {
        startIfNeeded()
    }

    /// Builds the runtime-owned paywall section.
    public func subscriptionSectionView() -> some View {
        subscriptionSectionFactory.makeView()
    }

    /// Evaluates advertising consent again, for example after a failed request.
    ///
    /// Does nothing without a consent bridge, before premium status resolves
    /// as inactive, or while another evaluation is running.
    public func refreshAdsConsent() async {
        guard adsConsent != nil,
              premiumStatus == .inactive else {
            return
        }

        hasEvaluatedAdsConsent = true
        await evaluateAdsConsent()
    }

    /// Presents the consent SDK's privacy options in response to a user action.
    ///
    /// Ad eligibility is re-evaluated after completion and after failure.
    public func presentAdsPrivacyOptions() async throws {
        guard let adsConsent else {
            return
        }

        do {
            applyAdsConsent(try await adsConsent.presentPrivacyOptions())
        } catch {
            applyAdsConsent(adsConsent.currentSnapshot())
            throw error
        }
    }

    /// Builds a runtime-owned native ad view.
    @ViewBuilder
    public func nativeAdView(layout: MHNativeAdLayout) -> some View {
        if canDisplayAds,
           let nativeAdFactory {
            nativeAdFactory.makeView(layout: layout)
        } else {
            EmptyView()
        }
    }

    /// Builds a runtime-owned license view.
    public func licensesView() -> some View {
        licensesFactory.makeView()
    }

    private func resolvePremiumStatus(purchasedProductIDs: Set<String>) {
        let isPremiumActive = subscriptionProductIDs.contains { productID in
            purchasedProductIDs.contains(productID)
        }
        premiumStatus = isPremiumActive ? .active : .inactive

        if adsConsent != nil {
            updateAdsForPremiumStatus()
        }
    }
}

private extension MHAppRuntime {
    func startAdsIfNeeded() {
        guard hasStartedAds == false,
              let startAds else {
            return
        }

        hasStartedAds = true
        startAds()
    }

    /// Evaluates consent once per session after premium resolves as inactive,
    /// and starts ads deferred by an earlier premium state.
    func updateAdsForPremiumStatus() {
        guard hasStarted,
              premiumStatus == .inactive else {
            return
        }

        if adsConsentStatus == .canRequestAds {
            startAdsIfNeeded()
        }

        guard hasEvaluatedAdsConsent == false else {
            return
        }

        hasEvaluatedAdsConsent = true
        Task {
            await evaluateAdsConsent()
        }
    }

    func evaluateAdsConsent() async {
        guard let adsConsent,
              isEvaluatingAdsConsent == false else {
            return
        }

        isEvaluatingAdsConsent = true
        defer {
            isEvaluatingAdsConsent = false
        }

        // Consent stored by an earlier session can start ads while this
        // session's update runs, as the consent SDK recommends.
        let storedSnapshot = adsConsent.currentSnapshot()
        if storedSnapshot.canRequestAds {
            applyAdsConsent(storedSnapshot)
        }

        do {
            _ = try await adsConsent.requestUpdate()
            applyAdsConsent(try await adsConsent.presentFormIfRequired())
        } catch {
            // After a failure, the SDK state still reflects earlier consent.
            applyAdsConsent(adsConsent.currentSnapshot())
        }
    }

    func applyAdsConsent(_ snapshot: MHAdsConsentSnapshot) {
        adsPrivacyOptionsRequirement = snapshot.privacyOptionsRequirement
        adsConsentStatus = snapshot.canRequestAds ? .canRequestAds : .cannotRequestAds

        if snapshot.canRequestAds,
           premiumStatus == .inactive {
            startAdsIfNeeded()
        }
    }
}
