import Foundation
@testable import SharedLibraryConsumer
import Testing

struct SharedLibraryConsumerTests {
    @Test
    func codec_round_trips_item_route() throws {
        let codec = SharedLibraryConsumer.makeCodec()
        let route = SharedLibraryConsumer.Route.item("fixture-route")
        let url = try #require(codec.preferredURL(for: route))

        #expect(codec.parse(url) == route)
    }

    @Test
    func reminder_policy_matches_fixture_contract() {
        let policy = SharedLibraryConsumer.makeReminderPolicy()

        #expect(policy.isEnabled)
        #expect(policy.minimumAmount == Decimal(1))
        #expect(policy.daysBeforeDueDate == 1)
        #expect(policy.deliveryTime.hour == 9)
        #expect(policy.deliveryTime.minute == 0)
        #expect(policy.identifierPrefix == "shared-library-consumer")
    }
}
