import Foundation
import MHAppRuntimeCore
import MHPreferences
import SwiftUI

#if canImport(StoreKitWrapper)
import StoreKitWrapper
#endif

#if canImport(GoogleMobileAdsWrapper)
import GoogleMobileAdsWrapper
#endif

public extension MHAppRuntime {
    /// Creates a runtime with the default StoreKit, ads, and license adapters.
    convenience init(
        configuration: MHAppConfiguration
    ) {
        let normalizedSubscriptionProductIDs = Self.normalizeTextSet(
            configuration.subscriptionProductIDs
        )
        let normalizedSubscriptionGroupID = Self.normalizeText(
            configuration.subscriptionGroupID
        )
        let normalizedNativeAdUnitID = Self.normalizeText(
            configuration.nativeAdUnitID
        )
        let preferenceStore = Self.makePreferenceStore(
            suiteName: configuration.preferencesSuiteName
        )
        let storeBridge = Self.makeStoreBridge()
        let adsBridge = Self.makeAdsBridge(
            nativeAdUnitID: normalizedNativeAdUnitID
        )
        let licensesViewBuilder: LicensesViewBuilder = {
            if configuration.showsLicenses {
                AnyView(MHRuntimeLicenseListView())
            } else {
                AnyView(EmptyView())
            }
        }

        self.init(
            configuration: configuration,
            preferenceStore: preferenceStore,
            startStore: { purchasedProductIDsDidSet in
                storeBridge.start(
                    normalizedSubscriptionGroupID,
                    normalizedSubscriptionProductIDs,
                    purchasedProductIDsDidSet
                )
            },
            subscriptionSectionViewBuilder: storeBridge.subscriptionSection,
            startAds: adsBridge.start,
            nativeAdViewBuilder: adsBridge.nativeAdView,
            licensesViewBuilder: licensesViewBuilder
        )
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

    static func normalizeTextSet(_ productIDs: [String]) -> [String] {
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

    static func makePreferenceStore(
        suiteName: String?
    ) -> MHPreferenceStore {
        guard let normalizedSuiteName = normalizeText(suiteName),
              let userDefaults = UserDefaults(suiteName: normalizedSuiteName) else {
            return .init()
        }

        return .init(userDefaults: userDefaults)
    }

    static func makeStoreBridge() -> (
        start: (
            _ groupID: String?,
            _ productIDs: [String],
            _ purchasedProductIDsDidSet: @escaping @MainActor (Set<String>) -> Void
        ) -> Void,
        subscriptionSection: SubscriptionSectionViewBuilder
    ) {
        #if canImport(StoreKitWrapper)
        let store = Store()

        func start(
            groupID: String?,
            productIDs: [String],
            purchasedProductIDsDidSet: @escaping @MainActor (Set<String>) -> Void
        ) {
            store.open(
                groupID: groupID,
                productIDs: productIDs
            ) { products in
                let purchasedProductIDs = Set(products.map(\.id))
                purchasedProductIDsDidSet(purchasedProductIDs)
            }
        }

        let subscriptionSection = {
            AnyView(store.buildSubscriptionSection())
        }

        return (
            start: start,
            subscriptionSection: subscriptionSection
        )
        #else
        return (
            start: { _, _, _ in
                // StoreKit is unavailable on this platform.
            },
            subscriptionSection: {
                AnyView(EmptyView())
            }
        )
        #endif
    }

    static func makeAdsBridge(nativeAdUnitID: String?) -> (
        start: StartAds?,
        nativeAdView: NativeAdViewBuilder?
    ) {
        #if canImport(GoogleMobileAdsWrapper)
        guard let nativeAdUnitID else {
            return (
                start: nil,
                nativeAdView: nil
            )
        }

        let controller = GoogleMobileAdsController(adUnitID: nativeAdUnitID)
        let start = {
            controller.start()
        }
        let nativeAdView = { (size: MHNativeAdSize) in
            AnyView(
                controller.buildNativeAd(size.wrapperSizeID)
            )
        }

        return (
            start: start,
            nativeAdView: nativeAdView
        )
        #else
        return (
            start: nil,
            nativeAdView: nil
        )
        #endif
    }
}
