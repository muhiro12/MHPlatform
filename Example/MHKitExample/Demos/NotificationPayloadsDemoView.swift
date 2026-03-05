import MHNotificationPayloads
import SwiftUI
#if canImport(UserNotifications)
import UserNotifications
#endif

struct NotificationPayloadsDemoView: View {
    private enum Constants {
        static let rowSpacing = 6.0
        static let rowVerticalPadding = 2.0
        static let defaultActionIdentifier = "com.apple.UNNotificationDefaultActionIdentifier"
        static let dismissActionIdentifier = "com.apple.UNNotificationDismissActionIdentifier"
    }

    private enum Scenario: String, CaseIterable, Identifiable {
        case incomes
        case cookle

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .incomes:
                return "Incomes-style"
            case .cookle:
                return "Cookle-style"
            }
        }

        var customActionIdentifier: String {
            switch self {
            case .incomes:
                return "upcoming-payment.view-month"
            case .cookle:
                return "browse_recipes"
            }
        }
    }

    private enum ActionSelection: String, CaseIterable, Identifiable {
        case defaultTap
        case custom
        case dismiss
        case unknown

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .defaultTap:
                return "default"
            case .custom:
                return "custom"
            case .dismiss:
                return "dismiss"
            case .unknown:
                return "unknown"
            }
        }
    }

    @State private var scenario: Scenario = .incomes
    @State private var actionSelection: ActionSelection = .defaultTap

    private let codec = MHNotificationPayloadCodec(
        configuration: .init(
            decodableMetadataKeys: [
                "notificationKind",
                "contentKind",
                "stableIdentifier"
            ]
        )
    )

    private var currentPayload: MHNotificationPayload {
        switch scenario {
        case .incomes:
            return incomesPayload
        case .cookle:
            return cooklePayload
        }
    }

    private var responseContext: MHNotificationResponseContext {
        MHNotificationResponseContext(
            actionIdentifier: selectedActionIdentifier
        )
    }

    private var selectedActionIdentifier: String {
        switch actionSelection {
        case .defaultTap:
            return Constants.defaultActionIdentifier
        case .custom:
            return scenario.customActionIdentifier
        case .dismiss:
            return Constants.dismissActionIdentifier
        case .unknown:
            return "unknown.action"
        }
    }

    private var resolvedRouteURL: URL? {
        MHNotificationRouteResolver.resolveRouteURL(
            payload: currentPayload,
            response: responseContext
        )
    }

    private var encodedUserInfoLines: [String] {
        let encoded = codec.encode(currentPayload)

        return encoded
            .compactMap { rawKey, rawValue in
                guard let key = rawKey as? String else {
                    return nil
                }
                return "\(key): \(stringify(rawValue))"
            }
            .sorted()
    }

    private var categoryDescriptor: MHNotificationCategoryDescriptor {
        switch scenario {
        case .incomes:
            return MHNotificationCategoryDescriptor(
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
            return MHNotificationCategoryDescriptor(
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

    var body: some View {
        NavigationStack {
            List {
                scenarioSection
                encodedPayloadSection
                resolverSection
                categorySection
            }
            .navigationTitle("MHNotificationPayloads")
        }
    }

    private var scenarioSection: some View {
        Section("Scenario") {
            Picker("Scenario", selection: $scenario) {
                ForEach(Scenario.allCases) { scenario in
                    Text(scenario.title).tag(scenario)
                }
            }
            .pickerStyle(.segmented)

            Text(description(for: scenario))
                .foregroundStyle(.secondary)
        }
    }

    private var encodedPayloadSection: some View {
        Section("Encoded userInfo (sorted keys)") {
            ForEach(encodedUserInfoLines, id: \.self) { line in
                Text(line)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .padding(.vertical, Constants.rowVerticalPadding)
            }
        }
    }

    private var resolverSection: some View {
        Section("Route Resolution") {
            Picker("Action", selection: $actionSelection) {
                ForEach(ActionSelection.allCases) { selection in
                    Text(selection.title).tag(selection)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: Constants.rowSpacing) {
                Text("actionIdentifier: \(selectedActionIdentifier)")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)

                Text(
                    "resolvedRouteURL: \(resolvedRouteURL?.absoluteString ?? "nil")"
                )
                .font(.caption.monospaced())
                .textSelection(.enabled)
            }
        }
    }

    private var categorySection: some View {
        Section("Category / Action Bridge") {
            Text("category.identifier: \(categoryDescriptor.identifier)")
                .font(.caption.monospaced())
                .textSelection(.enabled)

            ForEach(
                categoryDescriptor.actions,
                id: \.identifier
            ) { action in
                Text(verbatim:
                        "descriptor: \(action.identifier) | \(action.title) | opensApp=\(action.opensApp)"
                )
                .font(.caption.monospaced())
                .textSelection(.enabled)
            }

            #if canImport(UserNotifications)
            let bridgedCategory = categoryDescriptor.makeUNNotificationCategory()
            Text("bridge.identifier: \(bridgedCategory.identifier)")
                .font(.caption.monospaced())
                .textSelection(.enabled)

            ForEach(Array(bridgedCategory.actions.enumerated()), id: \.offset) { _, action in
                Text(
                    "bridge.action: \(action.identifier) | \(action.title) | options=\(stringify(action.options))"
                )
                .font(.caption.monospaced())
                .textSelection(.enabled)
            }
            #else
            Text("UserNotifications bridge is unavailable on this platform.")
                .foregroundStyle(.secondary)
            #endif
        }
    }
}

private extension NotificationPayloadsDemoView {
    var incomesPayload: MHNotificationPayload {
        MHNotificationPayload(
            routes: .init(
                defaultRouteURL: url("incomes://item?id=item-001"),
                fallbackRouteURL: url("incomes://month?year=2026&month=1"),
                actionRouteURLs: [
                    "upcoming-payment.view-month": url("incomes://month?year=2026&month=1")
                ]
            ),
            metadata: [
                "notificationKind": "upcoming-payment"
            ]
        )
    }

    var cooklePayload: MHNotificationPayload {
        MHNotificationPayload(
            routes: .init(
                defaultRouteURL: url("cookle://recipe?id=alpha"),
                actionRouteURLs: [
                    "browse_recipes": url("cookle://recipes")
                ]
            ),
            metadata: [
                "contentKind": "recipeSuggestion",
                "stableIdentifier": "alpha"
            ]
        )
    }

    private func description(for scenario: Scenario) -> String {
        switch scenario {
        case .incomes:
            return "default + fallback + viewMonth action route"
        case .cookle:
            return "default + browseRecipes action route"
        }
    }

    func stringify(_ value: Any) -> String {
        if let map = value as? [String: String] {
            return map
                .map { key, value in
                    "\(key)=\(value)"
                }
                .sorted()
                .joined(separator: ", ")
        }

        #if canImport(UserNotifications)
        if let options = value as? UNNotificationActionOptions {
            if options.contains(.foreground) {
                return "[foreground]"
            }
            return "[]"
        }
        #endif

        return String(describing: value)
    }

    func url(_ value: String) -> URL {
        guard let parsedURL = URL(string: value) else {
            preconditionFailure("Invalid URL value: \(value)")
        }
        return parsedURL
    }
}
