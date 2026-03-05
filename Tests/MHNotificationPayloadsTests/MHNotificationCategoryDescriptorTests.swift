import Foundation
import MHNotificationPayloads
import Testing
#if canImport(UserNotifications)
import UserNotifications
#endif

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

    #if canImport(UserNotifications)
    @Test
    func notification_action_bridge_maps_identifier_title_and_options() {
        let foregroundAction = MHNotificationActionDescriptor(
            identifier: "view-item",
            title: "View Item",
            opensApp: true
        )
        let passiveAction = MHNotificationActionDescriptor(
            identifier: "mark-done",
            title: "Mark Done",
            opensApp: false
        )

        let bridgedForeground = foregroundAction.makeUNNotificationAction()
        let bridgedPassive = passiveAction.makeUNNotificationAction()

        #expect(bridgedForeground.identifier == "view-item")
        #expect(bridgedForeground.title == "View Item")
        #expect(bridgedForeground.options.contains(.foreground))

        #expect(bridgedPassive.identifier == "mark-done")
        #expect(bridgedPassive.title == "Mark Done")
        #expect(bridgedPassive.options.contains(.foreground) == false)
    }

    @Test
    func notification_category_bridge_maps_identifier_and_actions() {
        let category = MHNotificationCategoryDescriptor(
            identifier: "upcoming-payment.actions",
            actions: [
                .init(identifier: "view-item", title: "View Item"),
                .init(
                    identifier: "view-month",
                    title: "View Month",
                    opensApp: false
                )
            ]
        )

        let bridgedCategory = category.makeUNNotificationCategory()

        #expect(bridgedCategory.identifier == "upcoming-payment.actions")
        #expect(bridgedCategory.actions.map(\.identifier) == [
            "view-item",
            "view-month"
        ])
        #expect(bridgedCategory.actions.map(\.title) == [
            "View Item",
            "View Month"
        ])
        #expect(bridgedCategory.actions[0].options.contains(.foreground))
        #expect(bridgedCategory.actions[1].options.contains(.foreground) == false)
    }
    #endif
}
