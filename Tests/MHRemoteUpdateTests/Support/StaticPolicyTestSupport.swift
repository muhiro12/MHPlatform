import Foundation
import MHRemoteUpdate
import Synchronization
import Testing

enum StaticPolicyTestSupport {
    final class Clock: Sendable {
        private let value: Mutex<Date>

        init() {
            value = .init(StaticPolicyTestSupport.date(0))
        }

        func now() -> Date {
            value.withLock { $0 }
        }

        func set(day: Double) {
            value.withLock { $0 = StaticPolicyTestSupport.date(day) }
        }
    }

    enum Failure: Error {
        case offline
    }

    static let day: TimeInterval = 86_400

    static func date(_ day: Double) -> Date {
        .init(timeIntervalSinceReferenceDate: day * self.day)
    }
}
