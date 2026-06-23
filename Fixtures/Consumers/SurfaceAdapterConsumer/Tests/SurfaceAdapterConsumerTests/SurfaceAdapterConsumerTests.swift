import Foundation
@testable import SurfaceAdapterConsumer
import Testing

struct SurfaceAdapterConsumerTests {
    @Test
    func intent_route_store_round_trips_route_without_runtime_products() throws {
        let suiteName = "surface-adapter-consumer-tests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = SurfaceAdapterConsumer.makeRouteStore(
            userDefaults: userDefaults
        )

        let storedURL = try #require(
            SurfaceAdapterConsumer.storeIntentRoute(in: store)
        )

        #expect(storedURL.scheme == "surface-adapter-consumer")
        #expect(
            store.consumeLatest(
                using: SurfaceAdapterConsumer.makeCodec()
            ) == .item("surface-item")
        )
    }

    @Test
    func notification_payload_resolves_route_without_runtime_products() {
        #expect(
            SurfaceAdapterConsumer.resolveDefaultNotificationRoute()
                == .item("surface-item")
        )
    }

    @Test
    func notification_user_notifications_bridge_resolves_route_without_runtime_products() {
        let userInfo = SurfaceAdapterConsumer.makeNotificationUserInfo()

        #expect(
            SurfaceAdapterConsumer.resolveNotificationUserInfoRoute(
                userInfo: userInfo,
                actionIdentifier: "com.apple.UNNotificationDefaultActionIdentifier"
            ) == .item("surface-item")
        )
    }

    @Test
    func notification_deep_link_bridge_stores_route_without_runtime_products() async throws {
        let suiteName = "surface-adapter-notification-tests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = SurfaceAdapterConsumer.makeRouteStore(
            userDefaults: userDefaults
        )
        let outcome = try #require(
            await SurfaceAdapterConsumer.deliverDefaultNotificationRoute(to: store)
        )

        #expect(outcome.source == .payload)
        #expect(
            store.consumeLatest(
                using: SurfaceAdapterConsumer.makeCodec()
            ) == .item("surface-item")
        )
    }

    @Test
    func reminder_planning_uses_core_safe_notification_products() throws {
        let now = Date(timeIntervalSinceReferenceDate: .zero)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: .zero))

        let plans = SurfaceAdapterConsumer.makeReminderPlans(
            now: now,
            calendar: calendar
        )

        #expect(plans.count == 1)
        #expect(plans.first?.identifier == "surface-adapter-consumer:surface-item")
    }

    @Test
    func route_execution_runs_without_app_runtime() async throws {
        let route = try await SurfaceAdapterConsumer.executeRoute(.home)

        #expect(route == .home)
    }
}
