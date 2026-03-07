import MHPlatform
import SwiftUI

struct NotificationPlansDemoView: View {
    private enum Constants {
        static let minimumReminderAmount: Decimal = 500
        static let reminderLeadDays = 3
        static let suggestionDaysAhead = 5
        static let deliveryHour = 20
        static let deliveryMinute = 0

        static let rentAmount: Decimal = 900
        static let insuranceAmount: Decimal = 700
        static let gymAmount: Decimal = 650
        static let taxAmount: Decimal = 1_500
        static let coffeeAmount: Decimal = 35

        static let rowSpacing = 6.0
        static let rowVerticalPadding = 4.0
        static let relevanceFractionDigits = 2
    }

    private var reminderPlans: [MHReminderPlan] {
        MHReminderPlanner.build(
            candidates: reminderCandidates,
            policy: MHReminderPolicy(
                isEnabled: true,
                minimumAmount: Constants.minimumReminderAmount,
                daysBeforeDueDate: Constants.reminderLeadDays,
                deliveryTime: deliveryTime,
                identifierPrefix: "upcoming-payment:"
            ),
            now: referenceDate,
            calendar: calendar
        )
    }

    private var suggestionPlans: [MHSuggestionPlan] {
        MHSuggestionPlanner.build(
            candidates: suggestionCandidates,
            policy: MHSuggestionPolicy(
                deliveryTime: deliveryTime,
                daysAhead: Constants.suggestionDaysAhead,
                identifierPrefix: "daily-suggestion:"
            ),
            now: referenceDate,
            calendar: calendar
        )
    }

    private var reminderCandidates: [MHReminderCandidate] {
        [
            MHReminderCandidate(
                stableIdentifier: "rent",
                title: "Rent",
                amount: Constants.rentAmount,
                dueDate: date("2026-01-20T00:00:00Z"),
                primaryRouteURL: url("https://example.com/items/rent"),
                secondaryRouteURL: url("https://example.com/month/2026-01")
            ),
            MHReminderCandidate(
                stableIdentifier: "insurance",
                title: "Insurance",
                amount: Constants.insuranceAmount,
                dueDate: date("2026-01-22T00:00:00Z"),
                primaryRouteURL: url("https://example.com/items/insurance"),
                secondaryRouteURL: url("https://example.com/month/2026-01")
            ),
            MHReminderCandidate(
                stableIdentifier: "gym",
                title: "Gym Membership",
                amount: Constants.gymAmount,
                dueDate: date("2026-02-05T00:00:00Z"),
                primaryRouteURL: url("https://example.com/items/gym"),
                secondaryRouteURL: url("https://example.com/month/2026-02")
            ),
            MHReminderCandidate(
                stableIdentifier: "tax",
                title: "Tax",
                amount: Constants.taxAmount,
                dueDate: date("2026-01-11T00:00:00Z"),
                primaryRouteURL: url("https://example.com/items/tax"),
                secondaryRouteURL: url("https://example.com/month/2026-01")
            ),
            MHReminderCandidate(
                stableIdentifier: "coffee",
                title: "Coffee Beans",
                amount: Constants.coffeeAmount,
                dueDate: date("2026-01-18T00:00:00Z"),
                primaryRouteURL: url("https://example.com/items/coffee"),
                secondaryRouteURL: url("https://example.com/month/2026-01")
            )
        ]
    }

    private var suggestionCandidates: [MHSuggestionCandidate] {
        [
            MHSuggestionCandidate(
                title: "Tomato Soup",
                stableIdentifier: "soup",
                routeURL: url("https://example.com/recipes/soup")
            ),
            MHSuggestionCandidate(
                title: "Pasta Primavera",
                stableIdentifier: "pasta",
                routeURL: url("https://example.com/recipes/pasta")
            ),
            MHSuggestionCandidate(
                title: "Chicken Curry",
                stableIdentifier: "curry",
                routeURL: url("https://example.com/recipes/curry")
            ),
            MHSuggestionCandidate(
                title: "Fruit Salad",
                stableIdentifier: "salad",
                routeURL: url("https://example.com/recipes/salad")
            )
        ]
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: .zero) ?? .gmt
        return calendar
    }

    private var deliveryTime: MHNotificationTime {
        guard let deliveryTime = MHNotificationTime(
            hour: Constants.deliveryHour,
            minute: Constants.deliveryMinute
        ) else {
            preconditionFailure("Invalid delivery time")
        }
        return deliveryTime
    }

    private var referenceDate: Date {
        date("2026-01-01T10:00:00Z")
    }

    var body: some View {
        NavigationStack {
            List {
                reminderSection
                suggestionSection
            }
            .navigationTitle("MHNotificationPlans")
        }
    }

    private var reminderSection: some View {
        Section("Reminder Plans") {
            ForEach(reminderPlans, id: \.identifier) { plan in
                VStack(alignment: .leading, spacing: Constants.rowSpacing) {
                    Text(plan.title)
                        .font(.headline)

                    Text(reminderDescription(for: plan))
                        .foregroundStyle(.secondary)

                    Text(
                        "Notify \(plan.notifyDate.formatted(date: .abbreviated, time: .shortened))"
                    )
                    .font(.caption)

                    Text(
                        reminderMetadataDescription(for: plan)
                    )
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                }
                .padding(.vertical, Constants.rowVerticalPadding)
            }
        }
    }

    private var suggestionSection: some View {
        Section("Suggestion Plans") {
            ForEach(suggestionPlans, id: \.identifier) { plan in
                VStack(alignment: .leading, spacing: Constants.rowSpacing) {
                    Text(plan.title)
                        .font(.headline)

                    Text(
                        "Notify \(plan.notifyDate.formatted(date: .abbreviated, time: .shortened))"
                    )
                    .foregroundStyle(.secondary)

                    Text("\(plan.identifier) · \(plan.stableIdentifier)")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                .padding(.vertical, Constants.rowVerticalPadding)
            }
        }
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        amount.formatted(
            .currency(code: "USD").precision(.fractionLength(.zero))
        )
    }

    private func formattedRelevance(_ relevanceScore: Double) -> String {
        relevanceScore.formatted(
            .number.precision(
                .fractionLength(Constants.relevanceFractionDigits)
            )
        )
    }

    private func reminderDescription(for plan: MHReminderPlan) -> String {
        "\(formattedAmount(plan.amount)) due \(plan.dueDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private func reminderMetadataDescription(for plan: MHReminderPlan) -> String {
        """
        thread \(plan.threadIdentifier) · badge \(plan.badgeCount) · \
        relevance \(formattedRelevance(plan.relevanceScore))
        """
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
