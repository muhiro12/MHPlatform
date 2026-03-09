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
    /// Builder for the runtime-owned subscription section.
    public typealias SubscriptionSectionViewBuilder = () -> AnyView
    /// Startup bridge for ads initialization.
    public typealias StartAds = () -> Void
    /// Builder for runtime-owned native ad views.
    public typealias NativeAdViewBuilder = (MHNativeAdSize) -> AnyView
    /// Builder for the runtime-owned license view.
    public typealias LicensesViewBuilder = () -> AnyView

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
    private let licensesViewBuilder: LicensesViewBuilder

    private var isAdsFeatureConfigured: Bool {
        nativeAdUnitID != nil && nativeAdViewBuilder != nil
    }

    /// Creates a runtime with explicit bridges and runtime-owned view builders.
    public init(
        configuration: MHAppConfiguration,
        preferenceStore: MHPreferenceStore,
        startStore: @escaping StartStore,
        subscriptionSectionViewBuilder: @escaping SubscriptionSectionViewBuilder,
        startAds: StartAds?,
        nativeAdViewBuilder: NativeAdViewBuilder?,
        licensesViewBuilder: @escaping LicensesViewBuilder = {
            AnyView(EmptyView())
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
        self.subscriptionSectionViewBuilder = subscriptionSectionViewBuilder
        self.startAds = startAds
        self.nativeAdViewBuilder = nativeAdViewBuilder
        self.licensesViewBuilder = licensesViewBuilder
    }

    /// Creates a runtime-only environment without StoreKit, ads, or licenses.
    public convenience init(
        runtimeOnly configuration: MHAppConfiguration
    ) {
        self.init(
            configuration: configuration,
            preferenceStore: .init(
                userDefaults: Self.makeUserDefaults(
                    suiteName: configuration.preferencesSuiteName
                )
            ),
            startStore: { purchasedProductIDsDidSet in
                purchasedProductIDsDidSet([])
            },
            subscriptionSectionViewBuilder: {
                AnyView(EmptyView())
            },
            startAds: nil,
            nativeAdViewBuilder: nil
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
    public func licensesView() -> some View {
        licensesViewBuilder()
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

    static func makeUserDefaults(suiteName: String?) -> UserDefaults {
        guard let normalizedSuiteName = normalizeText(suiteName),
              let userDefaults = UserDefaults(suiteName: normalizedSuiteName) else {
            return .standard
        }

        return userDefaults
    }
}
