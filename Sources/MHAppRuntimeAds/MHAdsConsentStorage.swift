import Foundation
import MHPreferences

/// Keys that the Google consent SDK keeps in an app's defaults domain.
///
/// Whole-domain preference cleanup must preserve these keys. Removing them
/// discards stored consent, so the consent form returns on every launch and
/// other SDKs lose the consent signals they read.
///
/// The SDK records the keys it writes under `ump_keys`. IAB TCF and GPP also
/// reserve their `IABTCF_`, `IABGPP_`, and `IABUSPrivacy_` namespaces for the
/// consent management platform, so current keys in those namespaces are kept
/// even when the SDK's record is unavailable.
public enum MHAdsConsentStorage {
    static let recordedKeysKey = "ump_keys"
    static let ownedKeyPrefixes = [
        "IABTCF_",
        "IABGPP_",
        "IABUSPrivacy_",
        "ump_",
        "UMP_"
    ]

    /// Returns raw descriptors for consent keys currently stored in the domain.
    ///
    /// Build the preference registry after calling this so that cleanup sees
    /// the keys present at launch.
    public static func currentDescriptors(
        in selection: MHUserDefaultsSelection = .standard
    ) -> [MHRawStorageDescriptor] {
        let userDefaults = selection.resolveUserDefaults()
        let recordedKeys = userDefaults.stringArray(forKey: recordedKeysKey) ?? []
        let namespacedKeys = userDefaults.dictionaryRepresentation().keys.filter { key in
            ownedKeyPrefixes.contains { prefix in
                key.hasPrefix(prefix)
            }
        }

        return Set(recordedKeys + namespacedKeys + [recordedKeysKey])
            .sorted()
            .map { storageKey in
                .init(
                    storageKey: storageKey,
                    defaultSelection: selection
                )
            }
    }
}
