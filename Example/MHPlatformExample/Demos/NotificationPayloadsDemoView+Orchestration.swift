import MHNotificationPayloads
import SwiftUI
#if canImport(UserNotifications)
import UserNotifications

nonisolated private enum NotificationPayloadOrchestrationFixture {
    private static var codec: MHNotificationPayloadCodec {
        MHNotificationPayloadCodec(
            configuration: .init(
                decodableMetadataKeys: [
                    "notificationKind",
                    "contentKind",
                    "stableIdentifier"
                ]
            )
        )
    }

    static func makeSnapshot(
        scenario: NotificationPayloadsDemoView.Scenario,
        actionSelection: NotificationPayloadsDemoView.ActionSelection
    ) async -> PayloadOrchestrationSnapshot {
        let center = PayloadSimulatedCenter(
            authorizationStatus: simulatedAuthorizationStatus(for: scenario),
            authorizationStatusAfterRequest: .authorized,
            pendingRequests: simulatedPendingRequests(for: scenario),
            failingAddIdentifiers: failingAddIdentifiers(for: scenario)
        )
        let descriptor = categoryDescriptor(for: scenario)
        let payload = payload(for: scenario)
        let actionIdentifier = actionIdentifier(for: actionSelection, scenario: scenario)
        let isManagedIdentifier: @Sendable (String) -> Bool = { identifier in
            Self.isManagedIdentifier(identifier: identifier, for: scenario)
        }

        MHNotificationOrchestrator.registerCategories([descriptor], center: center)
        let authorizationStatus = await MHNotificationOrchestrator.requestAuthorizationIfNeeded(
            center: center,
            options: [.alert, .sound],
            requestIfNotDetermined: true
        )
        let syncResult = await MHNotificationOrchestrator.replaceManagedPendingRequests(
            center: center,
            requests: simulatedRequests(for: scenario),
            isManagedIdentifier: isManagedIdentifier
        )
        let resolvedRouteURL = MHNotificationOrchestrator.resolveRouteURL(
            userInfo: codec.encode(payload),
            actionIdentifier: actionIdentifier,
            codec: codec
        )
        let snapshot = center.snapshot()

        return .init(
            authorizationStatusDescription: String(describing: authorizationStatus),
            registeredCategoryIdentifiers: normalizedList(snapshot.categoryIdentifiers),
            removedPendingIdentifiers: normalizedList(syncResult.removedPendingIdentifiers),
            addedRequestIdentifiers: normalizedList(syncResult.addedRequestIdentifiers),
            failedRequestIdentifiers: normalizedList(syncResult.failedRequestIdentifiers),
            resolvedRouteURLString: resolvedRouteURL?.absoluteString ?? "nil",
            pendingIdentifiersAfterSync: normalizedList(snapshot.pendingIdentifiers)
        )
    }

    private static func simulatedAuthorizationStatus(
        for scenario: NotificationPayloadsDemoView.Scenario
    ) -> UNAuthorizationStatus {
        switch scenario {
        case .incomes:
            return .notDetermined
        case .cookle:
            return .authorized
        }
    }

    private static func simulatedPendingRequests(
        for scenario: NotificationPayloadsDemoView.Scenario
    ) -> [UNNotificationRequest] {
        let incomesPayload = payload(for: .incomes)
        let cooklePayload = payload(for: .cookle)

        switch scenario {
        case .incomes:
            return [
                notificationRequest(
                    identifier: "upcoming-payment:old-managed",
                    payload: incomesPayload
                ),
                notificationRequest(
                    identifier: "external.keep",
                    payload: cooklePayload
                )
            ]
        case .cookle:
            return [
                notificationRequest(
                    identifier: "daily-suggestion:old-managed",
                    payload: cooklePayload
                ),
                notificationRequest(
                    identifier: "upcoming-payment:foreign",
                    payload: incomesPayload
                )
            ]
        }
    }

    private static func simulatedRequests(
        for scenario: NotificationPayloadsDemoView.Scenario
    ) -> [UNNotificationRequest] {
        let incomesPayload = payload(for: .incomes)
        let cooklePayload = payload(for: .cookle)

        switch scenario {
        case .incomes:
            return [
                notificationRequest(
                    identifier: "upcoming-payment:new-primary",
                    payload: incomesPayload
                ),
                notificationRequest(
                    identifier: "upcoming-payment:new-fallback",
                    payload: incomesPayload
                )
            ]
        case .cookle:
            return [
                notificationRequest(
                    identifier: "daily-suggestion:new-primary",
                    payload: cooklePayload
                ),
                notificationRequest(
                    identifier: "daily-suggestion:fail",
                    payload: cooklePayload
                )
            ]
        }
    }

    private static func failingAddIdentifiers(
        for scenario: NotificationPayloadsDemoView.Scenario
    ) -> Set<String> {
        switch scenario {
        case .incomes:
            return []
        case .cookle:
            return ["daily-suggestion:fail"]
        }
    }

    private static func isManagedIdentifier(
        identifier: String,
        for scenario: NotificationPayloadsDemoView.Scenario
    ) -> Bool {
        switch scenario {
        case .incomes:
            return identifier.hasPrefix("upcoming-payment:")
        case .cookle:
            return identifier.hasPrefix("daily-suggestion:")
        }
    }

    private static func notificationRequest(
        identifier: String,
        payload: MHNotificationPayload
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Sample"
        content.body = identifier
        content.userInfo = codec.encode(payload)

        return .init(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
    }

    private static func normalizedList(_ values: [String]) -> [String] {
        let sortedValues = values.sorted()
        return sortedValues.isEmpty ? ["none"] : sortedValues
    }

    private static func payload(for scenario: NotificationPayloadsDemoView.Scenario) -> MHNotificationPayload {
        switch scenario {
        case .incomes:
            return .init(
                routes: .init(
                    defaultRouteURL: makeURL("incomes://item?id=item-001"),
                    fallbackRouteURL: makeURL("incomes://month?year=2026&month=1"),
                    actionRouteURLs: [
                        "upcoming-payment.view-month": makeURL("incomes://month?year=2026&month=1")
                    ]
                ),
                metadata: [
                    "notificationKind": "upcoming-payment"
                ]
            )
        case .cookle:
            return .init(
                routes: .init(
                    defaultRouteURL: makeURL("cookle://recipe?id=alpha"),
                    actionRouteURLs: [
                        "browse_recipes": makeURL("cookle://recipes")
                    ]
                ),
                metadata: [
                    "contentKind": "recipeSuggestion",
                    "stableIdentifier": "alpha"
                ]
            )
        }
    }

    private static func categoryDescriptor(
        for scenario: NotificationPayloadsDemoView.Scenario
    ) -> MHNotificationCategoryDescriptor {
        switch scenario {
        case .incomes:
            return .init(
                identifier: "upcoming-payment.actions",
                actions: [
                    .init(
                        identifier: "upcoming-payment.view-item",
                        title: "View Item"
                    ),
                    .init(
                        identifier: "upcoming-payment.view-month",
                        title: "View Month"
                    )
                ]
            )
        case .cookle:
            return .init(
                identifier: "daily_recipe_suggestion",
                actions: [
                    .init(
                        identifier: "browse_recipes",
                        title: "Browse Recipes"
                    )
                ]
            )
        }
    }

    private static func actionIdentifier(
        for selection: NotificationPayloadsDemoView.ActionSelection,
        scenario: NotificationPayloadsDemoView.Scenario
    ) -> String {
        switch selection {
        case .defaultTap:
            return "com.apple.UNNotificationDefaultActionIdentifier"
        case .custom:
            switch scenario {
            case .incomes:
                return "upcoming-payment.view-month"
            case .cookle:
                return "browse_recipes"
            }
        case .dismiss:
            return "com.apple.UNNotificationDismissActionIdentifier"
        case .unknown:
            return "unknown.action"
        }
    }

    private static func makeURL(_ value: String) -> URL {
        guard let parsedURL = URL(string: value) else {
            preconditionFailure("Invalid URL value: \(value)")
        }
        return parsedURL
    }
}

extension NotificationPayloadsDemoView {
    var orchestrationTaskID: String {
        "\(scenario.rawValue)|\(actionSelection.rawValue)"
    }

    var orchestrationSection: some View {
        Section("Orchestration (Simulated)") {
            ForEach(Array(orchestrationRows.enumerated()), id: \.offset) { _, row in
                Text("\(row.label): \(row.value)")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        }
    }

    private var orchestrationRows: [(label: String, value: String)] {
        [
            (
                "authorizationStatus",
                orchestrationSnapshot.authorizationStatusDescription
            ),
            (
                "registeredCategories",
                orchestrationSnapshot.registeredCategoryIdentifiers.joined(separator: ", ")
            ),
            (
                "removedPending",
                orchestrationSnapshot.removedPendingIdentifiers.joined(separator: ", ")
            ),
            (
                "addedRequests",
                orchestrationSnapshot.addedRequestIdentifiers.joined(separator: ", ")
            ),
            (
                "failedRequests",
                orchestrationSnapshot.failedRequestIdentifiers.joined(separator: ", ")
            ),
            (
                "resolvedRouteURL",
                orchestrationSnapshot.resolvedRouteURLString
            ),
            (
                "pendingAfterSync",
                orchestrationSnapshot.pendingIdentifiersAfterSync.joined(separator: ", ")
            )
        ]
    }

    nonisolated func runOrchestrationSimulation() async {
        let (currentScenario, currentActionSelection) = await MainActor.run {
            (scenario, actionSelection)
        }
        let updatedSnapshot = await NotificationPayloadOrchestrationFixture.makeSnapshot(
            scenario: currentScenario,
            actionSelection: currentActionSelection
        )

        await MainActor.run {
            orchestrationSnapshot = updatedSnapshot
        }
    }
}
#endif
