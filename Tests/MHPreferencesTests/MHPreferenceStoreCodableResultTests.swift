import Foundation
import MHPreferences
import Testing

struct MHPreferenceStoreCodableResultTests {
    private enum Constants {
        static let storageKeyPrefix = "tests.preference-store.codable-result"
        static let invalidDataByte0: UInt8 = 0x00
        static let invalidDataByte1: UInt8 = 0xFF
    }

    private struct DemoPayload: Codable, Equatable, Sendable {
        let title: String
        let count: Int
    }

    private struct FailingPayload: Codable, Sendable {
        let title: String

        init(title: String) {
            self.title = title
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.title = try container.decode(String.self)
        }

        func encode(to encoder: any Encoder) throws {
            _ = encoder
            throw CocoaError(.coderInvalidValue)
        }
    }

    @Test
    func codableResult_reports_non_data_storage() throws {
        let (store, userDefaults) = try makeStore(suiteName: "non-data")
        let key = makeCodableKey("non-data-key")
        userDefaults.set("not-data", forKey: key.storageKey)

        let result: Result<DemoPayload?, MHPreferenceStoreCodableError> = store.codableResult(
            for: key
        )

        #expect(result == .failure(.storedValueIsNotData(storageKey: key.storageKey)))
    }

    @Test
    func codableResult_reports_invalid_data() throws {
        let (store, userDefaults) = try makeStore(suiteName: "invalid-data")
        let key = makeCodableKey("invalid-data-key")
        userDefaults.set(
            Data([Constants.invalidDataByte0, Constants.invalidDataByte1]),
            forKey: key.storageKey
        )

        let result: Result<DemoPayload?, MHPreferenceStoreCodableError> = store.codableResult(
            for: key
        )

        switch result {
        case .success:
            Issue.record("Expected decoding failure")
        case let .failure(error):
            guard case let .decodingFailed(storageKey, description) = error else {
                Issue.record("Expected decoding failure, got \(error)")
                return
            }
            #expect(storageKey == key.storageKey)
            #expect(description.isEmpty == false)
        }
    }

    @Test
    func setCodableResult_reports_encoding_failure() throws {
        let (store, userDefaults) = try makeStore(suiteName: "encoding")
        let key = MHCodablePreferenceDescriptor<FailingPayload>(
            storageKey: "\(Constants.storageKeyPrefix).encoding-key",
            defaultSelection: .standard
        )

        let result = store.setCodableResult(
            FailingPayload(title: "unsupported"),
            for: key
        )

        switch result {
        case .success:
            Issue.record("Expected encoding failure")
        case let .failure(error):
            guard case let .encodingFailed(storageKey, description) = error else {
                Issue.record("Expected encoding failure, got \(error)")
                return
            }
            #expect(storageKey == key.storageKey)
            #expect(description.isEmpty == false)
        }
        #expect(userDefaults.object(forKey: key.storageKey) == nil)
    }

    private func makeStore(
        suiteName: String
    ) throws -> (MHPreferenceStore, UserDefaults) {
        let resolvedSuiteName = "MHPreferenceStoreCodableResultTests.\(suiteName)"
        let userDefaults = try #require(
            UserDefaults(suiteName: resolvedSuiteName)
        )
        userDefaults.removePersistentDomain(forName: resolvedSuiteName)
        let store = MHPreferenceStore(userDefaults: userDefaults)
        return (store, userDefaults)
    }

    private func makeCodableKey(
        _ name: String
    ) -> MHCodablePreferenceDescriptor<DemoPayload> {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: .standard
        )
    }
}
