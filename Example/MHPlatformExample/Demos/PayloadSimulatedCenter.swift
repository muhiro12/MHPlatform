import MHNotificationPayloads
#if canImport(UserNotifications)
import Foundation
import UserNotifications

nonisolated final class PayloadSimulatedCenter: MHNotificationCentering {
    private static let authorizationDeniedCode = 1
    private static let addFailureCode = 2

    private var authorizationStatus: UNAuthorizationStatus
    private let authorizationStatusAfterRequest: UNAuthorizationStatus
    private var pendingRequests: [UNNotificationRequest]
    private let failingAddIdentifiers: Set<String>
    private var categoryIdentifiers = [String]()

    init(
        authorizationStatus: UNAuthorizationStatus,
        authorizationStatusAfterRequest: UNAuthorizationStatus,
        pendingRequests: [UNNotificationRequest],
        failingAddIdentifiers: Set<String>
    ) {
        self.authorizationStatus = authorizationStatus
        self.authorizationStatusAfterRequest = authorizationStatusAfterRequest
        self.pendingRequests = pendingRequests
        self.failingAddIdentifiers = failingAddIdentifiers
    }

    func fetchAuthorizationStatus() async -> UNAuthorizationStatus {
        await Task.yield()
        return authorizationStatus
    }

    func requestAuthorization(options _: UNAuthorizationOptions) async throws -> Bool {
        await Task.yield()
        authorizationStatus = authorizationStatusAfterRequest
        guard authorizationStatus != .denied else {
            throw NSError(
                domain: "PayloadSimulatedCenter",
                code: Self.authorizationDeniedCode
            )
        }
        return authorizationStatus == .authorized
    }

    func fetchPendingNotificationRequests() async -> [UNNotificationRequest] {
        await Task.yield()
        return pendingRequests
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        let removedIdentifiers = Set(identifiers)
        pendingRequests.removeAll { request in
            removedIdentifiers.contains(request.identifier)
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
        await Task.yield()
        guard failingAddIdentifiers.contains(request.identifier) == false else {
            throw NSError(
                domain: "PayloadSimulatedCenter",
                code: Self.addFailureCode
            )
        }
        pendingRequests.append(request)
    }

    func registerNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        categoryIdentifiers = categories.map(\.identifier).sorted()
    }

    func snapshot() -> (pendingIdentifiers: [String], categoryIdentifiers: [String]) {
        (
            pendingRequests.map(\.identifier).sorted(),
            categoryIdentifiers
        )
    }
}
#endif
