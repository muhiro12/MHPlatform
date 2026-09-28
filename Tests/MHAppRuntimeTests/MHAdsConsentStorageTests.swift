import Foundation
import MHAppRuntimeAds
import MHPreferences
import Testing

struct MHAdsConsentStorageTests {
    @Test
    func current_descriptors_keep_recorded_and_namespaced_consent_keys() throws {
        let suiteName = "MHAppRuntimeTests.ConsentStorage.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        userDefaults.set(
            ["ump_status", "UMP_consentModeValues", "IABTCF_TCString"],
            forKey: "ump_keys"
        )
        userDefaults.set(1, forKey: "ump_status")
        userDefaults.set("tc", forKey: "IABTCF_TCString")
        userDefaults.set("gpp", forKey: "IABGPP_HDR_GppString")
        userDefaults.set(true, forKey: "app.setting")

        let descriptors = MHAdsConsentStorage.currentDescriptors(in: .suite(suiteName))

        #expect(
            descriptors.map(\.storageKey) == [
                "IABGPP_HDR_GppString",
                "IABTCF_TCString",
                "UMP_consentModeValues",
                "ump_keys",
                "ump_status"
            ]
        )
        #expect(descriptors.allSatisfy { $0.defaultSelection == .suite(suiteName) })
    }

    @Test
    func current_descriptors_keep_the_record_key_before_consent_is_stored() throws {
        let suiteName = "MHAppRuntimeTests.ConsentStorage.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        userDefaults.set(true, forKey: "app.setting")

        #expect(
            MHAdsConsentStorage.currentDescriptors(in: .suite(suiteName)).map(\.storageKey) == [
                "ump_keys"
            ]
        )
    }
}
