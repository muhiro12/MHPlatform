import Foundation
import MHNotificationPayloads
import Testing

struct MHNotificationCategoryDescriptorTests {
    @Test
    func action_order_is_preserved() {
        let category = MHNotificationCategoryDescriptor(
            identifier: "upcoming-payment.actions",
            actions: [
                .init(identifier: "view-item", title: "View Item"),
                .init(identifier: "view-month", title: "View Month")
            ]
        )

        #expect(category.actions.map(\.identifier) == [
            "view-item",
            "view-month"
        ])
    }

    @Test
    func equality_and_hash_are_consistent() {
        let lhs = MHNotificationCategoryDescriptor(
            identifier: "daily_recipe_suggestion",
            actions: [
                .init(identifier: "browse_recipes", title: "Browse Recipes")
            ]
        )
        let rhs = MHNotificationCategoryDescriptor(
            identifier: "daily_recipe_suggestion",
            actions: [
                .init(identifier: "browse_recipes", title: "Browse Recipes")
            ]
        )

        #expect(lhs == rhs)
        #expect(Set([lhs, rhs]).count == 1)
    }
}
