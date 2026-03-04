import Foundation

/// Builds deterministic daily suggestion plans from candidates and policy.
public enum MHSuggestionPlanner {
    private enum Constants {
        static let daySeconds = 86_400.0
        static let hashMultiplier: Int64 = 1_103_515_245
        static let hashIncrement: Int64 = 12_345
        static let duplicateAvoidanceOffset = 1
    }

    private struct PlanningState {
        let orderedCandidates: [MHSuggestionCandidate]
        let daysAhead: Int
        let startOfToday: Date
    }

    /// Builds suggestion plans for future days using deterministic candidate rotation.
    public static func build(
        candidates: [MHSuggestionCandidate],
        policy: MHSuggestionPolicy,
        now: Date,
        calendar: Calendar
    ) -> [MHSuggestionPlan] {
        guard let planningState = planningState(
            from: candidates,
            policy: policy,
            now: now,
            calendar: calendar
        ) else {
            return []
        }

        return buildPlans(
            planningState: planningState,
            policy: policy,
            now: now,
            calendar: calendar
        )
    }

    private static func planningState(
        from candidates: [MHSuggestionCandidate],
        policy: MHSuggestionPolicy,
        now: Date,
        calendar: Calendar
    ) -> PlanningState? {
        guard candidates.isEmpty == false else {
            return nil
        }

        let daysAhead = max(policy.daysAhead, .zero)
        guard daysAhead > .zero else {
            return nil
        }

        return PlanningState(
            orderedCandidates: orderedCandidates(from: candidates),
            daysAhead: daysAhead,
            startOfToday: calendar.startOfDay(for: now)
        )
    }

    private static func buildPlans(
        planningState: PlanningState,
        policy: MHSuggestionPolicy,
        now: Date,
        calendar: Calendar
    ) -> [MHSuggestionPlan] {
        var plans = [MHSuggestionPlan]()
        var previousIndex: Int?

        for dayOffset in .zero..<planningState.daysAhead {
            guard let targetDay = targetDay(
                dayOffset: dayOffset,
                startOfToday: planningState.startOfToday,
                calendar: calendar
            ),
            let notifyDate = notifyDate(
                targetDay: targetDay,
                policy: policy,
                calendar: calendar
            ),
            notifyDate > now else {
                continue
            }

            let selectedIndex = selectedCandidateIndex(
                targetDay: targetDay,
                candidateCount: planningState.orderedCandidates.count,
                previousIndex: previousIndex,
                calendar: calendar
            )
            previousIndex = selectedIndex
            let candidate = planningState.orderedCandidates[selectedIndex]

            plans.append(
                buildPlan(
                    candidate: candidate,
                    targetDay: targetDay,
                    notifyDate: notifyDate,
                    policy: policy,
                    calendar: calendar
                )
            )
        }

        return plans
    }

    private static func targetDay(
        dayOffset: Int,
        startOfToday: Date,
        calendar: Calendar
    ) -> Date? {
        calendar.date(
            byAdding: .day,
            value: dayOffset,
            to: startOfToday
        )
    }

    private static func notifyDate(
        targetDay: Date,
        policy: MHSuggestionPolicy,
        calendar: Calendar
    ) -> Date? {
        calendar.date(
            bySettingHour: policy.deliveryTime.hour,
            minute: policy.deliveryTime.minute,
            second: .zero,
            of: targetDay
        )
    }

    private static func buildPlan(
        candidate: MHSuggestionCandidate,
        targetDay: Date,
        notifyDate: Date,
        policy: MHSuggestionPolicy,
        calendar: Calendar
    ) -> MHSuggestionPlan {
        MHSuggestionPlan(
            identifier: policy.identifierPrefix + identifierDateStamp(
                for: targetDay,
                calendar: calendar
            ),
            title: candidate.title,
            stableIdentifier: candidate.stableIdentifier,
            notifyDate: notifyDate,
            routeURL: candidate.routeURL
        )
    }

    private static func orderedCandidates(
        from candidates: [MHSuggestionCandidate]
    ) -> [MHSuggestionCandidate] {
        candidates.sorted { lhs, rhs in
            if lhs.title != rhs.title {
                return lhs.title.localizedStandardCompare(
                    rhs.title
                ) == .orderedAscending
            }
            return lhs.stableIdentifier < rhs.stableIdentifier
        }
    }

    private static func selectedCandidateIndex(
        targetDay: Date,
        candidateCount: Int,
        previousIndex: Int?,
        calendar: Calendar
    ) -> Int {
        var candidateIndex = baseCandidateIndex(
            targetDay: targetDay,
            candidateCount: candidateCount,
            calendar: calendar
        )

        if candidateCount > Constants.duplicateAvoidanceOffset,
           let previousIndex,
           previousIndex == candidateIndex {
            candidateIndex =
                (candidateIndex + Constants.duplicateAvoidanceOffset) % candidateCount
        }

        return candidateIndex
    }

    private static func baseCandidateIndex(
        targetDay: Date,
        candidateCount: Int,
        calendar: Calendar
    ) -> Int {
        let dayNumber = Int(
            calendar.startOfDay(for: targetDay).timeIntervalSince1970 / Constants.daySeconds
        )
        let mixedHash =
            Int64(dayNumber) &* Constants.hashMultiplier &+ Constants.hashIncrement
        let absoluteMixedHash = mixedHash >= .zero ? mixedHash : -mixedHash
        return Int(absoluteMixedHash % Int64(candidateCount))
    }

    private static func identifierDateStamp(
        for day: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: day
        )
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? .zero,
            components.month ?? .zero,
            components.day ?? .zero
        )
    }
}
