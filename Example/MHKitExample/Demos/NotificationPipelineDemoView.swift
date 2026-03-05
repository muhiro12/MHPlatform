import MHNotificationPayloads
import MHNotificationPlans
import SwiftUI

struct NotificationPipelineDemoView: View {
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
                    amount: 900,
                    dueDate: date("2026-01-20T00:00:00Z"),
                    primaryRouteURL: url("mhkit://item?id=rent"),
                    secondaryRouteURL: url("mhkit://month?year=2026&month=1")
                )
            ],
            policy: .init(
                isEnabled: true,
                minimumAmount: 100,
                daysBeforeDueDate: 3,
                deliveryTime: deliveryTime,
                identifierPrefix: "upcoming-payment:"
            ),
            now: date("2026-01-01T10:00:00Z"),
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
                    "view-month": plan.secondaryRouteURL
                ]
            ),
            metadata: [
                "notificationKind": "upcoming-payment"
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
            return "com.apple.UNNotificationDefaultActionIdentifier"
        case .custom:
            return "view-month"
        case .dismiss:
            return "com.apple.UNNotificationDismissActionIdentifier"
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
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var deliveryTime: MHNotificationTime {
        guard let time = MHNotificationTime(hour: 20, minute: 0) else {
            preconditionFailure("Invalid delivery time")
        }
        return time
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Plans") {
                    ForEach(plans, id: \.identifier) { plan in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.title)
                                .font(.headline)
                            Text(plan.identifier)
                                .font(.caption.monospaced())
                        }
                    }
                }

                Section("Payload Encoding") {
                    ForEach(encodedUserInfoLines, id: \.self) { line in
                        Text(line)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }

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
            .navigationTitle("Plans + Payloads")
        }
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

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
