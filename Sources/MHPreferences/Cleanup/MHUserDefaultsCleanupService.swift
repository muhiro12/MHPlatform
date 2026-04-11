import Foundation

/// Removes unknown keys from a caller-selected `UserDefaults` domain.
public enum MHUserDefaultsCleanupService {
    /// Prunes all keys not listed in `knownKeys` from the requested domain.
    public static func removeUnknownKeys<Descriptors: Sequence>(
        from userDefaults: UserDefaults,
        domainName: String,
        knownKeys: Descriptors
    ) -> MHUserDefaultsCleanupReport where Descriptors.Element: MHStorageDescriptorProtocol {
        removeUnknownKeys(
            from: userDefaults,
            domainName: domainName,
            knownStorageKeys: Set(knownKeys.map(\.storageKey))
        )
    }

    /// Prunes all keys not listed in `knownKeys` from the requested domain.
    public static func removeUnknownKeys(
        from userDefaults: UserDefaults,
        domainName: String,
        knownKeys: [any MHStorageDescriptorProtocol]
    ) -> MHUserDefaultsCleanupReport {
        removeUnknownKeys(
            from: userDefaults,
            domainName: domainName,
            knownStorageKeys: Set(knownKeys.map(\.storageKey))
        )
    }
}

private extension MHUserDefaultsCleanupService {
    static func removeUnknownKeys(
        from userDefaults: UserDefaults,
        domainName: String,
        knownStorageKeys: Set<String>
    ) -> MHUserDefaultsCleanupReport {
        let normalizedDomainName = domainName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        precondition(normalizedDomainName.isEmpty == false)

        let storedDomain = userDefaults.persistentDomain(
            forName: normalizedDomainName
        ) ?? [:]

        guard storedDomain.isEmpty == false else {
            return .init(
                removedStorageKeys: []
            )
        }

        var filteredDomain = storedDomain
        var removedStorageKeys = [String]()

        for storageKey in storedDomain.keys {
            guard knownStorageKeys.contains(storageKey) == false else {
                continue
            }

            filteredDomain.removeValue(forKey: storageKey)
            removedStorageKeys.append(storageKey)
        }

        if removedStorageKeys.isEmpty == false {
            userDefaults.setPersistentDomain(
                filteredDomain,
                forName: normalizedDomainName
            )
        }

        return .init(
            removedStorageKeys: removedStorageKeys.sorted()
        )
    }
}
