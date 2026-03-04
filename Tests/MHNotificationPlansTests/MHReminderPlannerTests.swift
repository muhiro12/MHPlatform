import MHNotificationPlans
import Testing

struct MHReminderPlannerTests {
    @Test
    func reminder_returns_empty_when_disabled() throws {
        let plans = MHReminderPlanner.build(
            candidates: [
                NotificationPlansTestFixture.reminderCandidate(
                    id: "rent",
                    title: "Rent",
                    amount: 900,
                    dueDate: "2026-01-20T00:00:00Z"
                )
            ],
            policy: MHReminderPolicy(
                isEnabled: false,
                minimumAmount: 500,
                daysBeforeDueDate: 3,
                deliveryTime: try NotificationPlansTestFixture.deliveryTime(),
                identifierPrefix: "upcoming-payment:"
            ),
            now: NotificationPlansTestFixture.date("2026-01-01T10:00:00Z"),
            calendar: NotificationPlansTestFixture.calendar
        )

        #expect(plans.isEmpty)
    }

    @Test
    func reminder_filters_candidates_below_minimum_amount() throws {
        let plans = MHReminderPlanner.build(
            candidates: [
                NotificationPlansTestFixture.reminderCandidate(
                    id: "coffee",
                    title: "Coffee",
                    amount: 20,
                    dueDate: "2026-01-20T00:00:00Z"
                ),
                NotificationPlansTestFixture.reminderCandidate(
                    id: "rent",
                    title: "Rent",
                    amount: 900,
                    dueDate: "2026-01-20T00:00:00Z"
                )
            ],
            policy: MHReminderPolicy(
                isEnabled: true,
                minimumAmount: 500,
                daysBeforeDueDate: 3,
                deliveryTime: try NotificationPlansTestFixture.deliveryTime(),
                identifierPrefix: "upcoming-payment:"
            ),
            now: NotificationPlansTestFixture.date("2026-01-01T10:00:00Z"),
            calendar: NotificationPlansTestFixture.calendar
        )

        #expect(plans.map(\.title) == ["Rent"])
    }

    @Test
    func reminder_filters_notify_dates_in_the_past() throws {
        let plans = MHReminderPlanner.build(
            candidates: [
                NotificationPlansTestFixture.reminderCandidate(
                    id: "tax",
                    title: "Tax",
                    amount: 1_200,
                    dueDate: "2026-01-02T00:00:00Z"
                )
            ],
            policy: MHReminderPolicy(
                isEnabled: true,
                minimumAmount: 500,
                daysBeforeDueDate: 3,
                deliveryTime: try NotificationPlansTestFixture.deliveryTime(),
                identifierPrefix: "upcoming-payment:"
            ),
            now: NotificationPlansTestFixture.date("2026-01-03T10:00:00Z"),
            calendar: NotificationPlansTestFixture.calendar
        )

        #expect(plans.isEmpty)
    }

    @Test
    func reminder_assigns_badges_after_sorting() throws {
        let plans = MHReminderPlanner.build(
            candidates: [
                NotificationPlansTestFixture.reminderCandidate(
                    id: "insurance",
                    title: "Insurance",
                    amount: 700,
                    dueDate: "2026-01-22T00:00:00Z"
                ),
                NotificationPlansTestFixture.reminderCandidate(
                    id: "rent",
                    title: "Rent",
                    amount: 900,
                    dueDate: "2026-01-20T00:00:00Z"
                )
            ],
            policy: MHReminderPolicy(
                isEnabled: true,
                minimumAmount: 500,
                daysBeforeDueDate: 3,
                deliveryTime: try NotificationPlansTestFixture.deliveryTime(),
                identifierPrefix: "upcoming-payment:"
            ),
            now: NotificationPlansTestFixture.date("2026-01-01T10:00:00Z"),
            calendar: NotificationPlansTestFixture.calendar
        )

        #expect(plans.map(\.badgeCount) == [1, 2])
        #expect(plans.map(\.identifier) == [
            "upcoming-payment:rent",
            "upcoming-payment:insurance"
        ])
    }

    @Test
    func reminder_clamps_relevance_score() throws {
        let lowUrgencyPlan = try #require(
            MHReminderPlanner.build(
                candidates: [
                    NotificationPlansTestFixture.reminderCandidate(
                        id: "storage",
                        title: "Storage",
                        amount: .zero,
                        dueDate: "2026-01-30T00:00:00Z"
                    )
                ],
                policy: MHReminderPolicy(
                    isEnabled: true,
                    minimumAmount: .zero,
                    daysBeforeDueDate: 10,
                    deliveryTime: try NotificationPlansTestFixture.deliveryTime(),
                    identifierPrefix: "upcoming-payment:"
                ),
                now: NotificationPlansTestFixture.date("2026-01-09T10:00:00Z"),
                calendar: NotificationPlansTestFixture.calendar
            ).first
        )
        let highUrgencyPlan = try #require(
            MHReminderPlanner.build(
                candidates: [
                    NotificationPlansTestFixture.reminderCandidate(
                        id: "mortgage",
                        title: "Mortgage",
                        amount: 10_000,
                        dueDate: "2026-01-10T00:00:00Z"
                    )
                ],
                policy: MHReminderPolicy(
                    isEnabled: true,
                    minimumAmount: 500,
                    daysBeforeDueDate: .zero,
                    deliveryTime: try NotificationPlansTestFixture.deliveryTime(),
                    identifierPrefix: "upcoming-payment:"
                ),
                now: NotificationPlansTestFixture.date("2026-01-09T10:00:00Z"),
                calendar: NotificationPlansTestFixture.calendar
            ).first
        )

        #expect(lowUrgencyPlan.relevanceScore == 0.40)
        #expect(highUrgencyPlan.relevanceScore == 1.0)
    }

    @Test
    func reminder_builds_month_thread_identifier() throws {
        let plan = try #require(
            MHReminderPlanner.build(
                candidates: [
                    NotificationPlansTestFixture.reminderCandidate(
                        id: "rent",
                        title: "Rent",
                        amount: 900,
                        dueDate: "2026-02-05T00:00:00Z"
                    )
                ],
                policy: MHReminderPolicy(
                    isEnabled: true,
                    minimumAmount: 500,
                    daysBeforeDueDate: 3,
                    deliveryTime: try NotificationPlansTestFixture.deliveryTime(),
                    identifierPrefix: "upcoming-payment:"
                ),
                now: NotificationPlansTestFixture.date("2026-01-01T10:00:00Z"),
                calendar: NotificationPlansTestFixture.calendar
            ).first
        )

        #expect(plan.threadIdentifier == "upcoming-payment:2026-02")
    }
}
