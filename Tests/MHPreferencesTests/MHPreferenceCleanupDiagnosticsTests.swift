import Foundation
import MHPreferences
import Testing

struct MHPreferenceCleanupDiagnosticsTests {
    @Test
    func lifecycle_scopes_raw_allowlists_and_diagnostics_to_each_domain() async throws {
        let firstSuite = "tests.cleanup.first.\(UUID())"
        let secondSuite = "tests.cleanup.second.\(UUID())"
        let firstDefaults = try #require(UserDefaults(suiteName: firstSuite))
        let secondDefaults = try #require(UserDefaults(suiteName: secondSuite))
        defer {
            firstDefaults.removePersistentDomain(forName: firstSuite)
            secondDefaults.removePersistentDomain(forName: secondSuite)
        }
        let externalDescriptor = MHRawStorageDescriptor(
            storageKey: "external.dynamic-record",
            defaultSelection: .suite(firstSuite)
        )
        let secondDescriptor = MHRawStorageDescriptor(
            storageKey: "second.current",
            defaultSelection: .suite(secondSuite)
        )
        let stateDescriptor = MHPreferenceMigrationStateDescriptor(
            storageKey: "migration-state",
            defaultSelection: .suite(firstSuite)
        )
        firstDefaults.set("keep", forKey: externalDescriptor.storageKey)
        secondDefaults.set("remove", forKey: externalDescriptor.storageKey)
        firstDefaults.set("remove", forKey: "unknown")

        let outcome = await MHPreferenceLifecycleService.run(
            descriptors: [externalDescriptor, secondDescriptor],
            migrationStateDescriptor: stateDescriptor
        )

        let firstReport = try #require(outcome.cleanupReports.first { report in
            report.domainName == firstSuite
        })
        let secondReport = try #require(outcome.cleanupReports.first { report in
            report.domainName == secondSuite
        })
        #expect(firstReport.report.knownStorageKeys == [
            externalDescriptor.storageKey,
            stateDescriptor.storageKey
        ])
        #expect(firstReport.report.removedStorageKeys == ["unknown"])
        #expect(secondReport.report.knownStorageKeys == [secondDescriptor.storageKey])
        #expect(secondReport.report.removedStorageKeys == [externalDescriptor.storageKey])
        #expect(firstDefaults.string(forKey: externalDescriptor.storageKey) == "keep")
        #expect(secondDefaults.object(forKey: externalDescriptor.storageKey) == nil)
    }
}
