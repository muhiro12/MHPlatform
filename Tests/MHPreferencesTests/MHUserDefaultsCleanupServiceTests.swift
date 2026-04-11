import Foundation
import MHPreferences
import Testing

struct MHUserDefaultsCleanupServiceTests {
    private enum Constants {
        static let domainPrefix = "MHUserDefaultsCleanupServiceTests"
        static let boolStorageKey = "tests.cleanup.bool"
        static let intStorageKey = "tests.cleanup.int"
        static let stringStorageKey = "tests.cleanup.string"
        static let codableStorageKey = "tests.cleanup.codable"
        static let rawStorageKey = "tests.cleanup.raw"
        static let unknownStorageKey = "tests.cleanup.unknown"
        static let anotherUnknownStorageKey = "tests.cleanup.another-unknown"
    }

    private struct DemoPayload: Codable, Equatable, Sendable {
        let title: String
    }

    private enum KnownStorageKey: CaseIterable, MHStorageKeyProtocol {
        case bool
        case raw

        var storageKey: String {
            switch self {
            case .bool:
                Constants.boolStorageKey
            case .raw:
                Constants.rawStorageKey
            }
        }
    }

    @Test
    func removeUnknownKeys_keeps_known_typed_keys_and_prunes_unknown_keys() throws {
        let domainName = makeDomainName(suffix: "typed-prune")
        let userDefaults = try makeSuiteUserDefaults(domainName: domainName)
        let boolKey = MHBoolPreferenceKey(
            storageKey: Constants.boolStorageKey,
            default: true
        )
        let intKey = MHIntPreferenceKey(
            storageKey: Constants.intStorageKey,
            default: 5
        )
        let stringKey = MHStringPreferenceKey(
            storageKey: Constants.stringStorageKey
        )
        let codableKey = MHCodablePreferenceKey<DemoPayload>(
            storageKey: Constants.codableStorageKey
        )
        let store = MHPreferenceStore(userDefaults: userDefaults)

        store.set(false, for: boolKey)
        store.set(7, for: intKey)
        store.set("value", for: stringKey)
        store.setCodable(.init(title: "payload"), for: codableKey)
        userDefaults.set("legacy", forKey: Constants.unknownStorageKey)

        let report = MHUserDefaultsCleanupService.removeUnknownKeys(
            from: userDefaults,
            domainName: domainName,
            knownKeys: [boolKey, intKey, stringKey, codableKey]
        )

        #expect(report.didRun)
        #expect(report.removedStorageKeys == [Constants.unknownStorageKey])
        #expect(userDefaults.object(forKey: boolKey.storageKey) != nil)
        #expect(userDefaults.object(forKey: intKey.storageKey) != nil)
        #expect(userDefaults.object(forKey: stringKey.storageKey) != nil)
        #expect(userDefaults.object(forKey: codableKey.storageKey) != nil)
        #expect(userDefaults.object(forKey: Constants.unknownStorageKey) == nil)
    }

    @Test
    func removeUnknownKeys_keeps_additional_raw_storage_keys() throws {
        let domainName = makeDomainName(suffix: "raw-key")
        let userDefaults = try makeSuiteUserDefaults(domainName: domainName)
        let boolKey = MHBoolPreferenceKey(
            storageKey: Constants.boolStorageKey,
            default: true
        )
        let rawKey = MHRawStorageKey(storageKey: Constants.rawStorageKey)

        userDefaults.set(true, forKey: boolKey.storageKey)
        userDefaults.set("keep", forKey: rawKey.storageKey)
        userDefaults.set("legacy", forKey: Constants.unknownStorageKey)

        let report = MHUserDefaultsCleanupService.removeUnknownKeys(
            from: userDefaults,
            domainName: domainName,
            knownKeys: [boolKey, rawKey]
        )

        #expect(report.removedStorageKeys == [Constants.unknownStorageKey])
        #expect(userDefaults.object(forKey: boolKey.storageKey) != nil)
        #expect(userDefaults.object(forKey: rawKey.storageKey) != nil)
        #expect(userDefaults.object(forKey: Constants.unknownStorageKey) == nil)
    }

    @Test
    func removeUnknownKeys_deduplicates_known_keys() throws {
        let domainName = makeDomainName(suffix: "dedupe")
        let userDefaults = try makeSuiteUserDefaults(domainName: domainName)
        let key = MHStringPreferenceKey(storageKey: Constants.stringStorageKey)
        let duplicateRawKey = MHRawStorageKey(storageKey: Constants.stringStorageKey)

        userDefaults.set("value", forKey: key.storageKey)
        userDefaults.set("legacy", forKey: Constants.unknownStorageKey)

        let report = MHUserDefaultsCleanupService.removeUnknownKeys(
            from: userDefaults,
            domainName: domainName,
            knownKeys: [key, duplicateRawKey, key]
        )

        #expect(report.removedStorageKeys == [Constants.unknownStorageKey])
        #expect(userDefaults.object(forKey: key.storageKey) != nil)
    }

    @Test
    func removeUnknownKeys_is_noop_for_empty_domain() throws {
        let domainName = makeDomainName(suffix: "empty-domain")
        let userDefaults = try makeSuiteUserDefaults(domainName: domainName)

        let report = MHUserDefaultsCleanupService.removeUnknownKeys(
            from: userDefaults,
            domainName: domainName,
            knownKeys: []
        )

        #expect(report.didRun)
        #expect(report.removedStorageKeys.isEmpty)
    }

    @Test
    func removeUnknownKeys_runs_for_standard_domain() {
        let domainName = makeDomainName(suffix: "standard-domain")
        let userDefaults = UserDefaults.standard
        let rawKey = MHRawStorageKey(storageKey: Constants.rawStorageKey)

        userDefaults.setPersistentDomain(
            [
                rawKey.storageKey: "keep",
                Constants.unknownStorageKey: "legacy",
                Constants.anotherUnknownStorageKey: "older"
            ],
            forName: domainName
        )
        defer {
            userDefaults.removePersistentDomain(forName: domainName)
        }

        let report = MHUserDefaultsCleanupService.removeUnknownKeys(
            from: userDefaults,
            domainName: domainName,
            knownKeys: [rawKey]
        )

        #expect(report.didRun)
        #expect(
            report.removedStorageKeys == [
                Constants.anotherUnknownStorageKey,
                Constants.unknownStorageKey
            ]
        )
        #expect(
            userDefaults.persistentDomain(forName: domainName)?[rawKey.storageKey]
                as? String == "keep"
        )
        #expect(
            userDefaults.persistentDomain(forName: domainName)?[Constants.unknownStorageKey]
                == nil
        )
    }

    @Test
    func removeUnknownKeys_accepts_case_iterable_known_key_sequences() throws {
        let domainName = makeDomainName(suffix: "case-iterable")
        let userDefaults = try makeSuiteUserDefaults(domainName: domainName)

        userDefaults.set(true, forKey: Constants.boolStorageKey)
        userDefaults.set("keep", forKey: Constants.rawStorageKey)
        userDefaults.set("legacy", forKey: Constants.unknownStorageKey)

        let report = MHUserDefaultsCleanupService.removeUnknownKeys(
            from: userDefaults,
            domainName: domainName,
            knownKeys: KnownStorageKey.allCases
        )

        #expect(report.didRun)
        #expect(report.removedStorageKeys == [Constants.unknownStorageKey])
        #expect(userDefaults.object(forKey: Constants.boolStorageKey) != nil)
        #expect(userDefaults.object(forKey: Constants.rawStorageKey) != nil)
    }
}

private extension MHUserDefaultsCleanupServiceTests {
    func makeDomainName(suffix: String) -> String {
        "\(Constants.domainPrefix).\(suffix).\(UUID().uuidString)"
    }

    func makeSuiteUserDefaults(
        domainName: String
    ) throws -> UserDefaults {
        let userDefaults = try #require(UserDefaults(suiteName: domainName))
        userDefaults.removePersistentDomain(forName: domainName)
        return userDefaults
    }
}
