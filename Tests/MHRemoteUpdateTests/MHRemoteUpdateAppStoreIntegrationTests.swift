import Foundation
import MHRemoteUpdate
import Testing

struct MHRemoteUpdateAppStoreIntegrationTests {
    @Test(arguments: [1, 2])
    func standardAssemblyPersistsEvidenceAndRestoresOfflineWithoutCustomProviders(_ schemaVersion: Int) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let bundle = try makeBundle(in: directory)
        let policyURL = try #require(URL(string: "https://example.com/policy.json"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StandardUpdateURLProtocol.self]
        configuration.httpAdditionalHeaders = ["PolicySchema": String(schemaVersion)]
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
        }
        let updates = try MHRemoteUpdateController(
            appStoreID: 123, policyURL: policyURL, bundle: bundle, storageDirectory: directory, session: session
        )
        let result = try await updates.prepare()
        #expect(result.restorationError == nil)
        #expect(result.refreshError == nil)
        #expect(result.decision == .updateRequired)
        let restarted = try MHRemoteUpdateController(
            appStoreID: 123, policyURL: policyURL, bundle: bundle, storageDirectory: directory, session: session
        )
        try await restarted.restore()
        #expect(await restarted.decision() == .updateRequired)
        let otherEndpoint = try MHRemoteUpdateController(
            appStoreID: 123,
            policyURL: #require(URL(string: "https://example.com/another-policy.json")),
            bundle: bundle,
            storageDirectory: directory,
            session: session
        )
        await #expect(throws: MHRemoteUpdateStore.Failure.sourceMismatch) {
            try await otherEndpoint.restore()
        }
        #expect(await otherEndpoint.decision() == .unavailable)
    }

    @Test
    func invalidStandardConfigurationFailsBeforeNetworkAccess() throws {
        #expect(throws: MHRemoteUpdateController.Failure.invalidConfiguration) {
            try MHRemoteUpdateController(
                appStoreID: 0, policyURL: #require(URL(string: "https://example.com/policy.json"))
            )
        }
        #expect(throws: MHRemoteUpdateController.Failure.invalidConfiguration) {
            try MHRemoteUpdateController(
                appStoreID: 123, policyURL: #require(URL(string: "http://example.com/policy.json"))
            )
        }
    }

    private func makeBundle(in directory: URL) throws -> Bundle {
        let bundleURL = directory.appendingPathComponent("Test.bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: [
            "CFBundleIdentifier": "example.app",
            "CFBundleShortVersionString": "1",
            "CFBundlePackageType": "BNDL"
        ],
        format: .xml,
        options: 0)
        try data.write(to: bundleURL.appendingPathComponent("Info.plist"))
        return try #require(Bundle(url: bundleURL))
    }
}
