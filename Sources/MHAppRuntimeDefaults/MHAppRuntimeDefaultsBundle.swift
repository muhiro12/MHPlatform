import Foundation
import MHAppRuntime
import MHPreferences
import SwiftUI

#if canImport(StoreKitWrapper)
import StoreKitWrapper
#endif

/// Bundle of package-owned preference and StoreKit runtime defaults.
public struct MHAppRuntimeDefaultsBundle {
    /// Preference store resolved from the runtime configuration.
    public let preferenceStore: MHPreferenceStore
    /// StoreKit-backed startup bridge for premium state updates.
    public let startStore: MHAppRuntime.StartStore
    /// Factory for the runtime-owned subscription section.
    public let subscriptionSectionFactory: MHRuntimeViewFactory

    /// Creates package-owned preference and StoreKit runtime defaults.
    public init(configuration: MHAppConfiguration) {
        preferenceStore = .init()

        #if canImport(StoreKitWrapper)
        let normalizedSubscriptionProductIDs = MHRuntimeTextNormalizer.uniqueTrimmedNonEmptyValues(
            configuration.subscriptionProductIDs
        )
        let normalizedSubscriptionGroupID = MHRuntimeTextNormalizer.trimmedNonEmpty(
            configuration.subscriptionGroupID
        )
        let store = Store()

        startStore = { purchasedProductIDsDidSet in
            store.open(
                groupID: normalizedSubscriptionGroupID,
                productIDs: normalizedSubscriptionProductIDs
            ) { products in
                let purchasedProductIDs = Set(products.map(\.id))
                Task { @MainActor in
                    purchasedProductIDsDidSet(purchasedProductIDs)
                }
            }
        }
        subscriptionSectionFactory = .init {
            store.buildSubscriptionSection()
        }
        #else
        startStore = { _ in
            // StoreKit is unavailable on this platform.
        }
        subscriptionSectionFactory = .init {
            EmptyView()
        }
        #endif
    }
}
