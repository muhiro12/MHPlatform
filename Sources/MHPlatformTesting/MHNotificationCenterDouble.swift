#if canImport(UserNotifications)
import Foundation
import MHNotificationPayloads
import UserNotifications

/// In-memory `MHNotificationCentering` double for notification orchestration tests.
@MainActor
@preconcurrency
public final class MHNotificationCenterDouble: MHNotificationCentering {
    private static let authorizationDeniedCode = 1
    private static let addFailureCode = 2

    private var authorizationStatus: UNAuthorizationStatus
    private let authorizationStatusAfterRequest: UNAuthorizationStatus
    private var pendingRequests: [UNNotificationRequest]
    private let failingAddIdentifiers: Set<String>

    private var requestAuthorizationCallCount = 0
    private var categoryIdentifiers = [String]()
    private var addAttemptIdentifiers = [String]()

    public init(
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

    public func fetchAuthorizationStatus() async -> UNAuthorizationStatus {
        await Task.yield()
        return authorizationStatus
    }

    public func requestAuthorization(
        options _: UNAuthorizationOptions
    ) async throws -> Bool {
        await Task.yield()
        requestAuthorizationCallCount += 1
        authorizationStatus = authorizationStatusAfterRequest

        guard authorizationStatus != .denied else {
            throw NSError(
                domain: "MHNotificationCenterDouble",
                code: Self.authorizationDeniedCode
            )
        }

        return authorizationStatus == .authorized
    }

    public func fetchPendingNotificationRequests() async -> [UNNotificationRequest] {
        await Task.yield()
        return pendingRequests
    }

    public func removePendingRequests(withIdentifiers identifiers: [String]) {
        let removedIdentifiers = Set(identifiers)
        pendingRequests.removeAll { request in
            removedIdentifiers.contains(request.identifier)
        }
    }

    public func add(_ request: UNNotificationRequest) async throws {
        await Task.yield()
        addAttemptIdentifiers.append(request.identifier)

        guard failingAddIdentifiers.contains(request.identifier) == false else {
            throw NSError(
                domain: "MHNotificationCenterDouble",
                code: Self.addFailureCode
            )
        }

        pendingRequests.removeAll { pendingRequest in
            pendingRequest.identifier == request.identifier
        }
        pendingRequests.append(request)
    }

    public func registerNotificationCategories(
        _ categories: Set<UNNotificationCategory>
    ) {
        categoryIdentifiers = categories.map(\.identifier).sorted()
    }

    public func requestAuthorizationCallCountValue() -> Int {
        requestAuthorizationCallCount
    }

    public func pendingIdentifiers() -> [String] {
        pendingRequests.map(\.identifier).sorted()
    }

    public func categoryIdentifiersValue() -> [String] {
        categoryIdentifiers
    }

    public func addAttemptIdentifiersValue() -> [String] {
        addAttemptIdentifiers
    }
}
#endif
