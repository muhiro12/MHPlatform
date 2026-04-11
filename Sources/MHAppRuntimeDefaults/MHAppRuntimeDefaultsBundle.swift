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
        let normalizedSubscriptionProductIDs = Self.normalizeTextSet(
            configuration.subscriptionProductIDs
        )
        let normalizedSubscriptionGroupID = Self.normalizeText(
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

private extension MHAppRuntimeDefaultsBundle {
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

    static func normalizeTextSet(_ values: [String]) -> [String] {
        var normalizedValues: [String] = []
        var uniqueValues = Set<String>()

        for value in values {
            guard let normalizedValue = normalizeText(value) else {
                continue
            }
            guard uniqueValues.contains(normalizedValue) == false else {
                continue
            }

            uniqueValues.insert(normalizedValue)
            normalizedValues.append(normalizedValue)
        }

        return normalizedValues
    }
}
