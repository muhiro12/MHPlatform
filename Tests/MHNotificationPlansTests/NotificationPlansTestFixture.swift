import Foundation
import MHNotificationPlans
import Testing

enum NotificationPlansTestFixture {
    private enum Constants {
        static let deliveryHour = 20
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: .zero) ?? .gmt
        return calendar
    }

    static func deliveryTime() throws -> MHNotificationTime {
        try #require(
            MHNotificationTime(
                hour: Constants.deliveryHour,
                minute: .zero
            )
        )
    }

    static func reminderCandidate(
        id: String,
        title: String,
        amount: Decimal,
        dueDate: String
    ) -> MHReminderCandidate {
        MHReminderCandidate(
            stableIdentifier: id,
            title: title,
            amount: amount,
            dueDate: date(dueDate),
            primaryRouteURL: url("https://example.com/reminders/\(id)"),
            secondaryRouteURL: url("https://example.com/months/\(id)")
        )
    }

    static func suggestionCandidates() -> [MHSuggestionCandidate] {
        [
            MHSuggestionCandidate(
                title: "Alpha",
                stableIdentifier: "alpha",
                routeURL: url("https://example.com/recipes/alpha")
            ),
            MHSuggestionCandidate(
                title: "Beta",
                stableIdentifier: "beta",
                routeURL: url("https://example.com/recipes/beta")
            ),
            MHSuggestionCandidate(
                title: "Gamma",
                stableIdentifier: "gamma",
                routeURL: url("https://example.com/recipes/gamma")
            )
        ]
    }

    static func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: .zero)
        guard let parsedDate = formatter.date(from: value) else {
            Issue.record("Invalid ISO8601 value: \(value)")
            preconditionFailure("Invalid ISO8601 value: \(value)")
        }
        return parsedDate
    }

    static func url(_ value: String) -> URL {
        guard let parsedURL = URL(string: value) else {
            Issue.record("Invalid URL value: \(value)")
            preconditionFailure("Invalid URL value: \(value)")
        }
        return parsedURL
    }
}
