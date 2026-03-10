import Foundation
import MHAppRuntimeCore
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
    /// Builder for the runtime-owned subscription section.
    public let subscriptionSectionViewBuilder: MHAppRuntime.SubscriptionSectionViewBuilder

    /// Creates package-owned preference and StoreKit runtime defaults.
    public init(configuration: MHAppConfiguration) {
        preferenceStore = Self.makePreferenceStore(
            suiteName: configuration.preferencesSuiteName
        )

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
        subscriptionSectionViewBuilder = {
            AnyView(store.buildSubscriptionSection())
        }
        #else
        startStore = { _ in
            // StoreKit is unavailable on this platform.
        }
        subscriptionSectionViewBuilder = {
            AnyView(EmptyView())
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

    static func makePreferenceStore(
        suiteName: String?
    ) -> MHPreferenceStore {
        guard let normalizedSuiteName = normalizeText(suiteName),
              let userDefaults = UserDefaults(suiteName: normalizedSuiteName) else {
            return .init()
        }

        return .init(userDefaults: userDefaults)
    }
}
