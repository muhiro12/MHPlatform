import Foundation
import MHPreferences
import Testing

struct MHPreferenceStoreSelectionTests {
    @Test
    func selection_override_keeps_descriptor_domain_unchanged() throws {
        let productionSuite = "tests.selection.production.\(UUID())"
        let overrideSuite = "tests.selection.override.\(UUID())"
        let productionDefaults = try #require(UserDefaults(suiteName: productionSuite))
        let overrideDefaults = try #require(UserDefaults(suiteName: overrideSuite))
        defer {
            productionDefaults.removePersistentDomain(forName: productionSuite)
            overrideDefaults.removePersistentDomain(forName: overrideSuite)
        }
        let descriptor = MHBoolPreferenceDescriptor(
            storageKey: "enabled",
            defaultSelection: .suite(productionSuite)
        )
        let store = MHPreferenceStore(selection: .suite(overrideSuite))

        store.set(true, for: descriptor)

        #expect(store.bool(for: descriptor))
        #expect(overrideDefaults.bool(forKey: descriptor.storageKey))
        #expect(MHPreferenceStore().bool(for: descriptor) == false)
        #expect(productionDefaults.object(forKey: descriptor.storageKey) == nil)
        store.remove(descriptor)
        #expect(overrideDefaults.object(forKey: descriptor.storageKey) == nil)
    }

    @Test
    func selection_preserves_injected_codable_configuration() throws {
        let suiteName = "tests.selection.codable.\(UUID())"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let store = MHPreferenceStore(
            selection: .suite(suiteName),
            encoder: encoder,
            decoder: decoder
        )
        let descriptor = MHCodablePreferenceDescriptor<Date>(
            storageKey: "date",
            defaultSelection: .suite(suiteName)
        )
        let date = Date(timeIntervalSince1970: .zero)

        try store.setCodableResult(date, for: descriptor).get()

        #expect(try store.codableResult(for: descriptor).get() == date)
        let data = try #require(userDefaults.data(forKey: descriptor.storageKey))
        #expect(try JSONDecoder().decode(String.self, from: data) == "1970-01-01T00:00:00Z")
    }
}
