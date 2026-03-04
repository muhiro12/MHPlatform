import MHNotificationPlans
import Testing

struct MHSuggestionPlannerTests {
    @Test
    func suggestion_is_deterministic_for_fixed_inputs() throws {
        let candidates = NotificationPlansTestFixture.suggestionCandidates()
        let policy = MHSuggestionPolicy(
            deliveryTime: try NotificationPlansTestFixture.deliveryTime(),
            daysAhead: 4,
            identifierPrefix: "daily-suggestion:"
        )
        let now = NotificationPlansTestFixture.date("2026-01-01T10:00:00Z")

        let firstPlans = MHSuggestionPlanner.build(
            candidates: candidates,
            policy: MHSuggestionPolicy(
                deliveryTime: policy.deliveryTime,
                daysAhead: policy.daysAhead,
                identifierPrefix: policy.identifierPrefix
            ),
            now: now,
            calendar: NotificationPlansTestFixture.calendar
        )
        let secondPlans = MHSuggestionPlanner.build(
            candidates: candidates,
            policy: policy,
            now: now,
            calendar: NotificationPlansTestFixture.calendar
        )

        #expect(firstPlans.map(\.identifier) == secondPlans.map(\.identifier))
        #expect(firstPlans.map(\.title) == secondPlans.map(\.title))
    }

    @Test
    func suggestion_avoids_adjacent_duplicates_when_possible() throws {
        let plans = MHSuggestionPlanner.build(
            candidates: [
                MHSuggestionCandidate(
                    title: "Alpha",
                    stableIdentifier: "alpha",
                    routeURL: NotificationPlansTestFixture.url("https://example.com/alpha")
                ),
                MHSuggestionCandidate(
                    title: "Beta",
                    stableIdentifier: "beta",
                    routeURL: NotificationPlansTestFixture.url("https://example.com/beta")
                )
            ],
            policy: MHSuggestionPolicy(
                deliveryTime: try NotificationPlansTestFixture.deliveryTime(),
                daysAhead: 5,
                identifierPrefix: "daily-suggestion:"
            ),
            now: NotificationPlansTestFixture.date("2026-01-01T10:00:00Z"),
            calendar: NotificationPlansTestFixture.calendar
        )

        for index in plans.indices.dropFirst() {
            #expect(plans[index].stableIdentifier != plans[index - 1].stableIdentifier)
        }
    }

    @Test
    func suggestion_preserves_stable_identifier() throws {
        let plans = MHSuggestionPlanner.build(
            candidates: NotificationPlansTestFixture.suggestionCandidates(),
            policy: MHSuggestionPolicy(
                deliveryTime: try NotificationPlansTestFixture.deliveryTime(),
                daysAhead: 3,
                identifierPrefix: "daily-suggestion:"
            ),
            now: NotificationPlansTestFixture.date("2026-01-01T10:00:00Z"),
            calendar: NotificationPlansTestFixture.calendar
        )

        let lookup = Dictionary(
            uniqueKeysWithValues: NotificationPlansTestFixture.suggestionCandidates().map { candidate in
                (candidate.title, candidate.stableIdentifier)
            }
        )

        for plan in plans {
            #expect(plan.stableIdentifier == lookup[plan.title])
        }
    }
}
