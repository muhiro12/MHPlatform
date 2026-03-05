import MHNotificationPayloads
#if canImport(UserNotifications)
import Foundation
import UserNotifications

final class NotificationCenterDouble: MHNotificationCentering {
    private static let authorizationDeniedCode = 1
    private static let addFailureCode = 2

    private var authorizationStatus: UNAuthorizationStatus
    private let authorizationStatusAfterRequest: UNAuthorizationStatus
    private var pendingRequests: [UNNotificationRequest]
    private let failingAddIdentifiers: Set<String>

    private var requestAuthorizationCallCount = 0
    private var categoryIdentifiers = [String]()
    private var addAttemptIdentifiers = [String]()

    init(
        authorizationStatus: UNAuthorizationStatus,
        pendingRequests: [UNNotificationRequest],
        authorizationStatusAfterRequest: UNAuthorizationStatus = .authorized,
        failingAddIdentifiers: Set<String> = []
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
        requestAuthorizationCallCount += 1
        authorizationStatus = authorizationStatusAfterRequest
        guard authorizationStatus != .denied else {
            throw NSError(
                domain: "NotificationCenterDouble",
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
        addAttemptIdentifiers.append(request.identifier)
        guard failingAddIdentifiers.contains(request.identifier) == false else {
            throw NSError(
                domain: "NotificationCenterDouble",
                code: Self.addFailureCode
            )
        }
        pendingRequests.removeAll { pendingRequest in
            pendingRequest.identifier == request.identifier
        }
        pendingRequests.append(request)
    }

    func registerNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        categoryIdentifiers = categories.map(\.identifier).sorted()
    }

    func requestAuthorizationCallCountValue() -> Int {
        requestAuthorizationCallCount
    }

    func pendingIdentifiers() -> [String] {
        pendingRequests.map(\.identifier).sorted()
    }

    func categoryIdentifiersValue() -> [String] {
        categoryIdentifiers
    }

    func addAttemptIdentifiersValue() -> [String] {
        addAttemptIdentifiers
    }
}
#endif
