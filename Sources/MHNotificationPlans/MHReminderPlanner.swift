import Foundation

/// Builds deterministic reminder plans from candidates and policy.
public enum MHReminderPlanner {
    private struct ScheduledCandidate {
        let candidate: MHReminderCandidate
        let notifyDate: Date
    }

    private enum Constants {
        static let badgeOffset = 1
        static let twoDaysUntilDue = 2
        static let fiveDaysUntilDue = 5

        static let minimumRelevanceScore: Double = 0.40
        static let maximumRelevanceScore: Double = 1.0
        static let amountBoostCap: Double = 3.0
        static let amountBoostWeight: Double = 0.20
        static let dueDateBoostSameDay: Double = 0.40
        static let dueDateBoostNextDay: Double = 0.30
        static let dueDateBoostTwoDays: Double = 0.20
        static let dueDateBoostWithinFiveDays: Double = 0.10
    }

    /// Builds reminder plans sorted by notify date and stable identifier.
    public static func build(
        candidates: [MHReminderCandidate],
        policy: MHReminderPolicy,
        now: Date,
        calendar: Calendar
    ) -> [MHReminderPlan] {
        guard policy.isEnabled else {
            return []
        }

        let scheduledCandidates = scheduledCandidates(
            from: candidates,
            policy: policy,
            now: now,
            calendar: calendar
        )
        let limitedCandidates = limitedCandidates(
            from: scheduledCandidates,
            maximumCount: policy.maximumCount
        )

        return limitedCandidates.enumerated().map { index, scheduledCandidate in
            buildPlan(
                scheduledCandidate: scheduledCandidate,
                badgeCount: index + Constants.badgeOffset,
                policy: policy,
                now: now,
                calendar: calendar
            )
        }
    }

    private static func scheduledCandidates(
        from candidates: [MHReminderCandidate],
        policy: MHReminderPolicy,
        now: Date,
        calendar: Calendar
    ) -> [ScheduledCandidate] {
        candidates
            .compactMap { candidate in
                scheduledCandidate(
                    from: candidate,
                    policy: policy,
                    now: now,
                    calendar: calendar
                )
            }
            .sorted(by: compareScheduledCandidates(_:_:))
    }

    private static func scheduledCandidate(
        from candidate: MHReminderCandidate,
        policy: MHReminderPolicy,
        now: Date,
        calendar: Calendar
    ) -> ScheduledCandidate? {
        guard candidate.amount >= policy.minimumAmount else {
            return nil
        }

        let leadDays = max(policy.daysBeforeDueDate, .zero)
        guard let targetDate = calendar.date(
            byAdding: .day,
            value: -leadDays,
            to: candidate.dueDate
        ) else {
            return nil
        }

        guard let notifyDate = calendar.date(
            bySettingHour: policy.deliveryTime.hour,
            minute: policy.deliveryTime.minute,
            second: .zero,
            of: targetDate
        ) else {
            return nil
        }

        guard notifyDate > now else {
            return nil
        }

        return ScheduledCandidate(
            candidate: candidate,
            notifyDate: notifyDate
        )
    }

    private static func compareScheduledCandidates(
        _ lhs: ScheduledCandidate,
        _ rhs: ScheduledCandidate
    ) -> Bool {
        if lhs.notifyDate != rhs.notifyDate {
            return lhs.notifyDate < rhs.notifyDate
        }

        if lhs.candidate.stableIdentifier != rhs.candidate.stableIdentifier {
            return lhs.candidate.stableIdentifier < rhs.candidate.stableIdentifier
        }

        return lhs.candidate.title.localizedStandardCompare(
            rhs.candidate.title
        ) == .orderedAscending
    }

    private static func limitedCandidates(
        from candidates: [ScheduledCandidate],
        maximumCount: Int?
    ) -> ArraySlice<ScheduledCandidate> {
        guard let maximumCount else {
            return candidates[candidates.startIndex...]
        }

        return candidates.prefix(max(maximumCount, .zero))
    }

    private static func buildPlan(
        scheduledCandidate: ScheduledCandidate,
        badgeCount: Int,
        policy: MHReminderPolicy,
        now: Date,
        calendar: Calendar
    ) -> MHReminderPlan {
        let referenceDate = max(scheduledCandidate.notifyDate, now)
        let daysUntilDue = daysUntilDueDate(
            dueDate: scheduledCandidate.candidate.dueDate,
            referenceDate: referenceDate,
            calendar: calendar
        )

        return MHReminderPlan(
            identifier: policy.identifierPrefix + scheduledCandidate.candidate.stableIdentifier,
            notifyDate: scheduledCandidate.notifyDate,
            threadIdentifier: policy.identifierPrefix + threadSuffix(
                dueDate: scheduledCandidate.candidate.dueDate,
                calendar: calendar
            ),
            badgeCount: badgeCount,
            daysUntilDue: daysUntilDue,
            relevanceScore: relevanceScore(
                amount: scheduledCandidate.candidate.amount,
                minimumAmount: policy.minimumAmount,
                daysUntilDue: daysUntilDue
            ),
            title: scheduledCandidate.candidate.title,
            amount: scheduledCandidate.candidate.amount,
            dueDate: scheduledCandidate.candidate.dueDate,
            primaryRouteURL: scheduledCandidate.candidate.primaryRouteURL,
            secondaryRouteURL: scheduledCandidate.candidate.secondaryRouteURL
        )
    }

    private static func daysUntilDueDate(
        dueDate: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        max(
            .zero,
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: referenceDate),
                to: calendar.startOfDay(for: dueDate)
            ).day ?? .zero
        )
    }

    private static func threadSuffix(
        dueDate: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents(
            [.year, .month],
            from: dueDate
        )

        return String(
            format: "%04d-%02d",
            components.year ?? .zero,
            components.month ?? .zero
        )
    }

    private static func relevanceScore(
        amount: Decimal,
        minimumAmount: Decimal,
        daysUntilDue: Int
    ) -> Double {
        let dueDateBoost = dueDateBoost(daysUntilDue: daysUntilDue)
        let amountBoost = amountBoost(
            amount: amount,
            minimumAmount: minimumAmount
        )

        return min(
            max(
                Constants.minimumRelevanceScore + dueDateBoost + amountBoost,
                Constants.minimumRelevanceScore
            ),
            Constants.maximumRelevanceScore
        )
    }

    private static func dueDateBoost(daysUntilDue: Int) -> Double {
        switch daysUntilDue {
        case ...Int.zero:
            return Constants.dueDateBoostSameDay
        case Constants.badgeOffset:
            return Constants.dueDateBoostNextDay
        case Constants.twoDaysUntilDue:
            return Constants.dueDateBoostTwoDays
        case (Constants.twoDaysUntilDue + Constants.badgeOffset)...Constants.fiveDaysUntilDue:
            return Constants.dueDateBoostWithinFiveDays
        default:
            return .zero
        }
    }

    private static func amountBoost(
        amount: Decimal,
        minimumAmount: Decimal
    ) -> Double {
        guard minimumAmount > .zero else {
            return .zero
        }

        let amountValue = decimalToDouble(amount)
        let minimumValue = decimalToDouble(minimumAmount)

        guard minimumValue > .zero else {
            return .zero
        }

        let ratio = min(
            max(amountValue / minimumValue, .zero),
            Constants.amountBoostCap
        )
        return (ratio / Constants.amountBoostCap) * Constants.amountBoostWeight
    }

    private static func decimalToDouble(_ value: Decimal) -> Double {
        Double(String(describing: value)) ?? .zero
    }
}
