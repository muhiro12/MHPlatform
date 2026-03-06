import MHPreferences
import Observation
import SwiftUI

/// Runtime entry point for startup side effects and shared app platform state.
@MainActor
@preconcurrency
@Observable
public final class MHAppRuntime {
    typealias StartStore = (@escaping @MainActor (Set<String>) -> Void) -> Void
    typealias SubscriptionSectionViewBuilder = () -> AnyView
    typealias StartAds = () -> Void
    typealias NativeAdViewBuilder = (MHNativeAdSize) -> AnyView

    /// Immutable app runtime configuration.
    public let configuration: MHAppConfiguration

    /// Typed preferences helper backed by configured `UserDefaults`.
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

    private let subscriptionProductIDs: [String]
    private let subscriptionGroupID: String?
    private let nativeAdUnitID: String?

    private let startStore: StartStore
    private let subscriptionSectionViewBuilder: SubscriptionSectionViewBuilder
    private let startAds: StartAds?
    private let nativeAdViewBuilder: NativeAdViewBuilder?

    private var isAdsFeatureConfigured: Bool {
        nativeAdUnitID != nil && nativeAdViewBuilder != nil
    }

    /// Creates a runtime with default StoreKit/Ads/License adapters.
    public init(configuration: MHAppConfiguration) {
        let normalizedSubscriptionProductIDs = Self.normalizeProductIDs(
            configuration.subscriptionProductIDs
        )
        let normalizedSubscriptionGroupID = Self.normalizeText(
            configuration.subscriptionGroupID
        )
        let normalizedNativeAdUnitID = Self.normalizeText(
            configuration.nativeAdUnitID
        )
        let preferenceStore = MHPreferenceStore(
            userDefaults: Self.makeUserDefaults(
                suiteName: configuration.preferencesSuiteName
            )
        )
        let storeBridge = Self.makeStoreBridge()
        let adsBridge = Self.makeAdsBridge(nativeAdUnitID: normalizedNativeAdUnitID)

        self.configuration = configuration
        self.preferenceStore = preferenceStore
        self.subscriptionProductIDs = normalizedSubscriptionProductIDs
        self.subscriptionGroupID = normalizedSubscriptionGroupID
        self.nativeAdUnitID = normalizedNativeAdUnitID
        self.startStore = { purchasedProductIDsDidSet in
            storeBridge.start(
                normalizedSubscriptionGroupID,
                normalizedSubscriptionProductIDs,
                purchasedProductIDsDidSet
            )
        }
        self.subscriptionSectionViewBuilder = storeBridge.subscriptionSection
        self.startAds = adsBridge.start
        self.nativeAdViewBuilder = adsBridge.nativeAdView
    }

    init(
        configuration: MHAppConfiguration,
        preferenceStore: MHPreferenceStore,
        startStore: @escaping StartStore,
        subscriptionSectionViewBuilder: @escaping SubscriptionSectionViewBuilder,
        startAds: StartAds?,
        nativeAdViewBuilder: NativeAdViewBuilder?
    ) {
        self.configuration = configuration
        self.preferenceStore = preferenceStore
        self.subscriptionProductIDs = Self.normalizeProductIDs(
            configuration.subscriptionProductIDs
        )
        self.subscriptionGroupID = Self.normalizeText(
            configuration.subscriptionGroupID
        )
        self.nativeAdUnitID = Self.normalizeText(
            configuration.nativeAdUnitID
        )
        self.startStore = startStore
        self.subscriptionSectionViewBuilder = subscriptionSectionViewBuilder
        self.startAds = startAds
        self.nativeAdViewBuilder = nativeAdViewBuilder
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

        if let startAds {
            startAds()
        }
    }

    /// Starts runtime side effects. This method is idempotent.
    public func start() {
        startIfNeeded()
    }

    /// Builds the runtime-owned paywall section.
    public func subscriptionSectionView() -> some View {
        subscriptionSectionViewBuilder()
    }

    /// Builds a runtime-owned native ad view.
    @ViewBuilder
    public func nativeAdView(size: MHNativeAdSize) -> some View {
        if adsAvailability == .available,
           let nativeAdViewBuilder {
            nativeAdViewBuilder(size)
        } else {
            EmptyView()
        }
    }

    /// Builds a runtime-owned license view.
    @ViewBuilder
    public func licensesView() -> some View {
        if configuration.showsLicenses {
            MHRuntimeLicenseListView()
        } else {
            EmptyView()
        }
    }

    private func resolvePremiumStatus(purchasedProductIDs: Set<String>) {
        let isPremiumActive = subscriptionProductIDs.contains { productID in
            purchasedProductIDs.contains(productID)
        }
        premiumStatus = isPremiumActive ? .active : .inactive
    }
}
