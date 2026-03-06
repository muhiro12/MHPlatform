import Foundation
import StoreKitWrapper
import SwiftUI

#if canImport(GoogleMobileAdsWrapper)
import GoogleMobileAdsWrapper
#endif

extension MHAppRuntime {
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

    static func makeStoreBridge() -> (
        start: (
            _ groupID: String?,
            _ productIDs: [String],
            _ purchasedProductIDsDidSet: @escaping @MainActor (Set<String>) -> Void
        ) -> Void,
        subscriptionSection: SubscriptionSectionViewBuilder
    ) {
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
