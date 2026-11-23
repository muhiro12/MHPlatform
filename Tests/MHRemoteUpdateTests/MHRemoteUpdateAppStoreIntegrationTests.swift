import Foundation
import MHAnnouncements
import MHRemoteUpdate
import Synchronization
import Testing

struct MHRemoteUpdateAppStoreIntegrationTests {
    private final class Requests: NSObject, URLSessionTaskDelegate {
        let urls = Mutex<[URL]>([])

        func urlSession(_: URLSession, didCreateTask task: URLSessionTask) {
            if let url = task.originalRequest?.url {
                urls.withLock { $0.append(url) }
            }
        }
    }

    @Test(arguments: [nil, "JP"] as [String?])
    func standardAssemblyPersistsEvidenceAndRestoresOfflineWithoutCustomProviders(_ storefront: String?) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let bundle = try makeBundle(in: directory)
        let policyURL = try #require(URL(string: "https://example.com/policy.json"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StandardUpdateURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Expected-Storefront": storefront?.lowercased() ?? "default"]
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
        }
        let updates = try MHRemoteUpdateController(
            appStoreID: 123,
            configurationURL: policyURL,
            storefront: storefront,
            bundle: bundle,
            storageDirectory: directory,
            session: session
        )
        let result = try await updates.prepare()
        #expect(result.restorationError == nil)
        #expect(result.refreshError == nil)
        #expect(result.decision == .updateRequired)
        let restarted = try MHRemoteUpdateController(
            appStoreID: 123,
            configurationURL: policyURL,
            storefront: storefront,
            bundle: bundle,
            storageDirectory: directory,
            session: session
        )
        session.invalidateAndCancel()
        await #expect(throws: MHRemoteUpdateOperationError.updateRequired) {
            try await restarted.checkOperationAllowed()
        }
        #expect(await restarted.decision() == .updateRequired)
        let otherEndpoint = try MHRemoteUpdateController(
            appStoreID: 123,
            configurationURL: #require(URL(string: "https://example.com/another-policy.json")),
            storefront: storefront,
            bundle: bundle,
            storageDirectory: directory,
            session: session
        )
        await #expect(throws: MHRemoteUpdateStore.Failure.sourceMismatch) {
            try await otherEndpoint.restore()
        }
        #expect(await otherEndpoint.decision() == .unavailable)
    }

    @Test(arguments: ["valid", "missing-announcements", "bad-announcements", "bad-update", "wrong-app", "offline"])
    func sharedRefreshHandsOffEachSectionIndependently(_ scenario: String) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let bundle = try makeBundle(in: directory)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StandardUpdateURLProtocol.self]
        let requests = Requests()
        let url = try #require(URL(string: "https://example.com/\(scenario)"))
        let session = URLSession(configuration: configuration, delegate: requests, delegateQueue: nil)
        defer {
            session.invalidateAndCancel()
        }
        let rejectsResponse = ["wrong-app", "offline"].contains(scenario)
        try await confirmation("Announcement handoff", expectedCount: rejectsResponse ? 0 : 1) { handoff in
            let updates = try MHRemoteUpdateController(
                appStoreID: 123,
                configurationURL: url,
                bundle: bundle,
                storageDirectory: directory,
                session: session
            ) { response in
                handoff()
                switch (scenario, response.value) {
                case ("missing-announcements", .missing), ("bad-announcements", .invalid):
                    break
                case let ("valid", .value(feed)), let ("bad-update", .value(feed)):
                    let visible = feed.visibleAnnouncements(installedVersion: nil, preferredLanguages: ["ja"])
                    #expect(visible.first?.id == "news")
                    #expect(visible.first?.title == "更新")
                default:
                    Issue.record("Unexpected announcement section for \(scenario)")
                }
            }
            let preparation = try await updates.prepare()
            let updateFailed = rejectsResponse || scenario == "bad-update"
            #expect(preparation.decision == (updateFailed ? .unavailable : .updateRequired))
            #expect((preparation.refreshError != nil) == updateFailed)
            #expect(requests.urls.withLock { $0.filter { $0 == url }.count } == 1)
        }
    }

    @Test
    func invalidStandardConfigurationFailsBeforeNetworkAccess() throws {
        #expect(throws: MHRemoteUpdateController.Failure.invalidConfiguration) {
            try MHRemoteUpdateController(
                appStoreID: 0, configurationURL: #require(URL(string: "https://example.com/policy.json"))
            )
        }
        #expect(throws: MHRemoteUpdateController.Failure.invalidConfiguration) {
            try MHRemoteUpdateController(
                appStoreID: 123, configurationURL: #require(URL(string: "http://example.com/policy.json"))
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
