import Foundation
import MHPreferences
import Observation
import SwiftUI

/// Runtime entry point for startup side effects and shared app platform state.
@MainActor
@preconcurrency
@Observable
public final class MHAppRuntime {
    /// Startup bridge that reports the current purchased product identifiers.
    public typealias StartStore = (
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

    private let subscriptionProductIDs: [String]
    private let subscriptionGroupID: String?
    private let nativeAdUnitID: String?

    private let startStore: StartStore
    private let subscriptionSectionFactory: MHRuntimeViewFactory
    private let startAds: StartAds?
    private let nativeAdFactory: MHRuntimeNativeAdViewFactory?
    private let licensesFactory: MHRuntimeViewFactory

    private var isAdsFeatureConfigured: Bool {
        nativeAdUnitID != nil && nativeAdFactory != nil
    }

    /// Creates a runtime with explicit bridges and runtime-owned view factories.
    public init(
        configuration: MHAppConfiguration,
        preferenceStore: MHPreferenceStore,
        startStore: @escaping StartStore,
        subscriptionSectionFactory: MHRuntimeViewFactory,
        startAds: StartAds?,
        nativeAdFactory: MHRuntimeNativeAdViewFactory?,
        licensesFactory: MHRuntimeViewFactory = .init {
            EmptyView()
        }
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
        self.subscriptionSectionFactory = subscriptionSectionFactory
        self.startAds = startAds
        self.nativeAdFactory = nativeAdFactory
        self.licensesFactory = licensesFactory
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
        subscriptionSectionFactory.makeView()
    }

    /// Builds a runtime-owned native ad view.
    @ViewBuilder
    public func nativeAdView(size: MHNativeAdSize) -> some View {
        if adsAvailability == .available,
           let nativeAdFactory {
            nativeAdFactory.makeView(size: size)
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
    }
}

private extension MHAppRuntime {
    static func normalizeText(_ text: String?) -> String? {
        guard let text else {
            return nil
        }

        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else {
            return nil
        }

        return normalized
    }

    static func normalizeProductIDs(_ productIDs: [String]) -> [String] {
        var normalizedProductIDs: [String] = []
        var uniqueProductIDs = Set<String>()

        for productID in productIDs {
            guard let normalizedProductID = normalizeText(productID) else {
                continue
            }
            guard uniqueProductIDs.contains(normalizedProductID) == false else {
                continue
            }

            uniqueProductIDs.insert(normalizedProductID)
            normalizedProductIDs.append(normalizedProductID)
        }

        return normalizedProductIDs
    }
}
