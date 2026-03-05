import MHNotificationPayloads
import MHNotificationPlans
import SwiftUI

struct NotificationPipelineDemoView: View {
    private enum Constants {
        static let amount: Decimal = 900
        static let minimumAmount: Decimal = 100
        static let daysBeforeDueDate = 3
        static let rowSpacing = 4.0
        static let deliveryHour = 20
        static let deliveryMinute = 0

        static let dueDateISO8601 = "2026-01-20T00:00:00Z"
        static let planningNowISO8601 = "2026-01-01T10:00:00Z"

        static let primaryRoute = "mhkit://item?id=rent"
        static let fallbackRoute = "mhkit://month?year=2026&month=1"

        static let actionRouteIdentifier = "view-month"
        static let metadataKey = "notificationKind"
        static let metadataValue = "upcoming-payment"

        static let defaultActionIdentifier =
            "com.apple.UNNotificationDefaultActionIdentifier"
        static let dismissActionIdentifier =
            "com.apple.UNNotificationDismissActionIdentifier"
    }

    enum Action: String, CaseIterable, Identifiable {
        case `default`
        case custom
        case dismiss

        var id: String {
            rawValue
        }
    }

    @State private var selectedAction: Action = .default

    private var plans: [MHReminderPlan] {
        MHReminderPlanner.build(
            candidates: [
                .init(
                    stableIdentifier: "rent",
                    title: "Rent",
                    amount: Constants.amount,
                    dueDate: date(Constants.dueDateISO8601),
                    primaryRouteURL: url(Constants.primaryRoute),
                    secondaryRouteURL: url(Constants.fallbackRoute)
                )
            ],
            policy: .init(
                isEnabled: true,
                minimumAmount: Constants.minimumAmount,
                daysBeforeDueDate: Constants.daysBeforeDueDate,
                deliveryTime: deliveryTime,
                identifierPrefix: "upcoming-payment:"
            ),
            now: date(Constants.planningNowISO8601),
            calendar: calendar
        )
    }

    private var payload: MHNotificationPayload {
        guard let plan = plans.first else {
            return .init(
                routes: .init(
                    defaultRouteURL: nil,
                    fallbackRouteURL: nil
                )
            )
        }

        return .init(
            routes: .init(
                defaultRouteURL: plan.primaryRouteURL,
                fallbackRouteURL: plan.secondaryRouteURL,
                actionRouteURLs: [
                    Constants.actionRouteIdentifier: plan.secondaryRouteURL
                ]
            ),
            metadata: [
                Constants.metadataKey: Constants.metadataValue
            ]
        )
    }

    private var resolvedRouteURL: URL? {
        MHNotificationRouteResolver.resolveRouteURL(
            payload: payload,
            response: .init(actionIdentifier: actionIdentifier)
        )
    }

    private var actionIdentifier: String {
        switch selectedAction {
        case .default:
            return Constants.defaultActionIdentifier
        case .custom:
            return Constants.actionRouteIdentifier
        case .dismiss:
            return Constants.dismissActionIdentifier
        }
    }

    private var encodedUserInfoLines: [String] {
        MHNotificationPayloadCodec()
            .encode(payload)
            .compactMap { key, value in
                guard let key = key as? String else {
                    return nil
                }
                return "\(key): \(value)"
            }
            .sorted()
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: .zero) ?? .gmt
        return calendar
    }

    private var deliveryTime: MHNotificationTime {
        guard let time = MHNotificationTime(
            hour: Constants.deliveryHour,
            minute: Constants.deliveryMinute
        ) else {
            preconditionFailure("Invalid delivery time")
        }
        return time
    }

    var body: some View {
        NavigationStack {
            List {
                plansSection
                payloadSection
                routeResolutionSection
            }
            .navigationTitle("Plans + Payloads")
        }
    }

    private var plansSection: some View {
        Section("Plans") {
            ForEach(plans, id: \.identifier) { plan in
                VStack(alignment: .leading, spacing: Constants.rowSpacing) {
                    Text(plan.title)
                        .font(.headline)
                    Text(plan.identifier)
                        .font(.caption.monospaced())
                }
            }
        }
    }

    private var payloadSection: some View {
        Section("Payload Encoding") {
            ForEach(encodedUserInfoLines, id: \.self) { line in
                Text(line)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        }
    }

    private var routeResolutionSection: some View {
        Section("Route Resolution") {
            Picker("Action", selection: $selectedAction) {
                ForEach(Action.allCases) { action in
                    Text(action.rawValue).tag(action)
                }
            }
            .pickerStyle(.segmented)

            Text(resolvedRouteURL?.absoluteString ?? "nil")
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: .zero)

        guard let parsedDate = formatter.date(from: value) else {
            preconditionFailure("Invalid date: \(value)")
        }
        return parsedDate
    }

    private func url(_ value: String) -> URL {
        guard let parsedURL = URL(string: value) else {
            preconditionFailure("Invalid URL: \(value)")
        }
        return parsedURL
    }
}
